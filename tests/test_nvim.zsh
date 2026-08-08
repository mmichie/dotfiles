#!/usr/bin/env zsh
# nvim config tests. Two tiers:
#   - parse/coherence checks that need only the nvim binary (CI-safe)
#   - behavioral probes against the real install (plugins on disk), local
#     only — gated on the lazy.nvim data dir existing.

source "${0:A:h}/lib.zsh"

if ! have nvim; then
    t_skip "nvim config" "nvim not in PATH"
    t_finish
fi

typeset NVIM_CONF="$REPO_ROOT/configs/nvim"

# Keep probes independent of the caller's ShaDa, logs, and compiled-Lua cache.
# XDG_DATA_HOME is deliberately left alone: tier 2 exercises the installed
# plugin revisions under ~/.local/share/nvim.
typeset NVIM_TEST_STATE="$T_SCRATCH/state"
typeset NVIM_TEST_CACHE="$T_SCRATCH/cache"
mkdir -p "$NVIM_TEST_STATE" "$NVIM_TEST_CACHE"

run_nvim() {
    XDG_STATE_HOME="$NVIM_TEST_STATE" XDG_CACHE_HOME="$NVIM_TEST_CACHE" \
        command nvim -i NONE "$@"
}

# ── Tier 1: parse gates (no plugins required) ────────────────────────
typeset f='' out=''
for f in "$NVIM_CONF/init.lua" "$NVIM_CONF/lua/plugins.lua"; do
    out=$(run_nvim --clean --headless \
        +"lua local f,e = loadfile('$f'); print(f and 'PARSE_OK' or 'PARSE_ERR: '..tostring(e))" \
        +q 2>&1)
    assert_contains "$out" "PARSE_OK" "lua parses: ${f:t}"
done

# Spec/lock coherence: every plugin repo declared in plugins.lua must have a
# lockfile entry (catches typos and never-installed declarations).
typeset -a spec_names missing
spec_names=(${(f)"$(grep -oE '"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"' "$NVIM_CONF/lua/plugins.lua" \
    | sed -E 's|.*/||; s|"||g' | sort -u)"})
missing=()
typeset n=''
for n in "${spec_names[@]}"; do
    grep -q "\"$n\"" "$NVIM_CONF/lazy-lock.json" || missing+=("$n")
done
if (( ${#missing} == 0 )); then
    t_pass "every declared plugin is in lazy-lock.json (${#spec_names} declared)"
else
    t_fail "every declared plugin is in lazy-lock.json" "missing: ${(j:, :)missing}"
fi

# ── Tier 2: behavioral probes (real install) ─────────────────────────
if [[ ! -d ~/.local/share/nvim/lazy/lazy.nvim ]]; then
    t_skip "nvim behavioral probes" "plugins not installed (lazy data dir absent)"
    t_finish
fi

# Headless boot must be clean — genuine config errors (Lua tracebacks,
# E### messages) surface on stderr. nvim-treesitter also writes async
# parser-install progress ("[nvim-treesitter] [n/m] Downloading ...") to
# stderr when an ensure_installed parser is not on disk yet: benign on a
# fresh machine, and abandoned anyway when +q quits before it finishes.
# Drop those notifier lines so the check still fails on real errors, which
# never carry the plugin-name prefix. The TS_HL probe below guards
# treesitter health functionally.
out=$(run_nvim --headless +q 2>&1 | grep -vE '^\[nvim-treesitter\]')
if [[ -z "$out" ]]; then
    t_pass "headless boot emits no errors"
else
    t_fail "headless boot emits no errors" "${out:0:200}"
fi

# Lockfile orphan gate: lazy's managed-plugin count must match the lock
# (regression: 12 stale entries had accumulated from removed plugins).
typeset managed='' lockn=''
managed=$(run_nvim --headless +'lua io.write(#require("lazy").plugins())' +q 2>/dev/null)
lockn=$(grep -c '": {' "$NVIM_CONF/lazy-lock.json")
assert_eq "$managed" "$lockn" "lazy-lock.json matches the managed plugin set (no orphans)"

# Treesitter highlighting must actually attach (regression: the master
# branch needs nvim-treesitter.configs + highlight.enable — the old setup
# call was silently ignored and Go files fell back to regex syntax).
typeset gofile='' probe=''
gofile="$T_SCRATCH/probe.go"
printf 'package main\n\nfunc main() {}\n' > "$gofile"
probe=$(run_nvim --headless "$gofile" +'lua vim.defer_fn(function()
  local hl = vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil
  io.write("TS_HL=" .. tostring(hl))
  vim.cmd("qa!")
end, 800)' 2>/dev/null)
assert_contains "$probe" "TS_HL=true" "treesitter highlighter attaches to Go buffers (regression)"

# Go formatting in BufWritePre must finish before :write returns. An async
# formatter appears to work during a long editing session but loses its edits
# on :wq, and can mutate the buffer after the user has moved elsewhere.
if have gopls && have goimports; then
    gofile="$T_SCRATCH/format.go"
    printf 'package main\nimport "fmt"\nfunc main(){fmt.Println("x")}\n' > "$gofile"
    probe=$(run_nvim --headless \
        +'set noswapfile' +'set noundofile' +"edit $gofile" \
        +"lua vim.defer_fn(function()
          vim.cmd('write')
          local expected = {
            'package main', '', 'import \"fmt\"', '',
            'func main() { fmt.Println(\"x\") }',
          }
          local finished = vim.deep_equal(vim.fn.readfile('$gofile'), expected)
          io.write('GO_FORMAT_SYNC=' .. tostring(finished))
          vim.cmd('qa!')
        end, 800)" 2>&1)
    assert_contains "$probe" "GO_FORMAT_SYNC=true" "Go format-on-save finishes before write returns"
    assert_not_contains "$probe" "deprecated" "Go format-on-save uses no deprecated Neovim APIs"
else
    t_skip "Go format-on-save finishes before write returns" "gopls or goimports not in PATH"
    t_skip "Go format-on-save uses no deprecated Neovim APIs" "gopls or goimports not in PATH"
fi

# Completion wiring: every configured source must be registered, Tab must
# know how to advance snippets, and Copilot must not overwrite that mapping.
typeset pyfile="$T_SCRATCH/completion.py"
touch "$pyfile"
probe=$(run_nvim --headless \
    +'set noswapfile' +'set noundofile' +"edit $pyfile" \
    +'lua vim.api.nvim_exec_autocmds("InsertEnter", {}); local cmp = require("cmp"); local source = false; for _, s in pairs(cmp.get_registered_sources()) do source = source or s.name == "luasnip" end; local has_tab = cmp.get_config().mapping["<Tab>"] ~= nil; local tab = vim.fn.maparg("<Tab>", "i", false, true); local overridden = tab.desc == "Accept Copilot suggestion or insert Tab"; io.write("LUASNIP_SOURCE=" .. tostring(source) .. " CMP_TAB=" .. tostring(has_tab) .. " COPILOT_TAB_OVERRIDE=" .. tostring(overridden)); vim.cmd("qa!")' \
    2>/dev/null)
assert_contains "$probe" "LUASNIP_SOURCE=true" "LuaSnip completion source is registered"
assert_contains "$probe" "CMP_TAB=true" "completion mapping can advance snippet fields"
assert_contains "$probe" "COPILOT_TAB_OVERRIDE=false" "Copilot does not overwrite completion Tab mapping"

# Error, warning, and info signs should not be invisible whitespace.
probe=$(run_nvim --headless \
    +'lua local text = vim.diagnostic.config().signs.text; local visible = true; for _, severity in ipairs({ vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN, vim.diagnostic.severity.INFO }) do visible = visible and text[severity]:match("%S") ~= nil end; io.write("DIAGNOSTIC_SIGNS_VISIBLE=" .. tostring(visible)); vim.cmd("qa!")' \
    2>/dev/null)
assert_contains "$probe" "DIAGNOSTIC_SIGNS_VISIBLE=true" "error, warning, and info signs are visible"

# LSP servers enabled in the config should have their binaries available.
typeset srv=''
for srv in gopls pyright; do
    if have "$srv"; then
        t_pass "$srv binary present for vim.lsp.enable"
    else
        t_skip "$srv binary present for vim.lsp.enable" "not in PATH on this machine"
    fi
done

t_finish
