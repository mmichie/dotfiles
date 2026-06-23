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

# ── Tier 1: parse gates (no plugins required) ────────────────────────
typeset f out
for f in "$NVIM_CONF/init.lua" "$NVIM_CONF/lua/plugins.lua"; do
    out=$(nvim --clean --headless \
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
typeset n
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
out=$(nvim --headless +q 2>&1 | grep -vE '^\[nvim-treesitter\]')
if [[ -z "$out" ]]; then
    t_pass "headless boot emits no errors"
else
    t_fail "headless boot emits no errors" "${out:0:200}"
fi

# Lockfile orphan gate: lazy's managed-plugin count must match the lock
# (regression: 12 stale entries had accumulated from removed plugins).
typeset managed lockn
managed=$(nvim --headless +'lua io.write(#require("lazy").plugins())' +q 2>/dev/null)
lockn=$(grep -c '": {' "$NVIM_CONF/lazy-lock.json")
assert_eq "$managed" "$lockn" "lazy-lock.json matches the managed plugin set (no orphans)"

# Treesitter highlighting must actually attach (regression: the master
# branch needs nvim-treesitter.configs + highlight.enable — the old setup
# call was silently ignored and Go files fell back to regex syntax).
typeset gofile probe
gofile="$T_SCRATCH/probe.go"
printf 'package main\n\nfunc main() {}\n' > "$gofile"
probe=$(nvim --headless "$gofile" +'lua vim.defer_fn(function()
  local hl = vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil
  io.write("TS_HL=" .. tostring(hl))
  vim.cmd("qa!")
end, 800)' 2>/dev/null)
assert_contains "$probe" "TS_HL=true" "treesitter highlighter attaches to Go buffers (regression)"

# LSP servers enabled in the config should have their binaries available.
typeset srv
for srv in gopls pyright; do
    if have "$srv"; then
        t_pass "$srv binary present for vim.lsp.enable"
    else
        t_skip "$srv binary present for vim.lsp.enable" "not in PATH on this machine"
    fi
done

t_finish
