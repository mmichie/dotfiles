#!/usr/bin/env zsh
# Static pattern invariants over the zsh config source. These pin the
# repo's own conventions — the ones whose loss is invisible at runtime
# until a slow shell or a subtle bug shows up:
#
#   - no `eval "$(tool init)"` at source time (must go through the
#     _refresh_cache/_init_from_cache layer; a stray eval re-adds the
#     50-100ms per-shell fork the cache exists to remove)
#   - no `$(command -v ...)` output used as a value (resolves to wrapper
#     FUNCTION names, not paths — the JAVA_HOME bug class; use
#     $commands[...] or whence -p)
#   - no hardcoded cache paths outside .zshrc ($SHELL_CACHE_DIR is the
#     single source of truth; hardcoded paths escape test sandboxes)
#   - lib modules keep the two-digit ordering prefix (a one-digit prefix
#     sorts lexically after 10-, silently scrambling load order)
#   - functions/ contains only autoloadable files (a stray *.zsh there is
#     skipped by the autoloader without a sound)
#   - every `zle -N <name>` widget resolves to an autoload file or an
#     in-module function (a rename leaves the binding pointing at nothing,
#     which only explodes when the key is pressed)
#   - GitHub Actions are pinned by commit, not tag (a tag can be repointed;
#     dependabot moves the pin and its version comment together)
#   - no installer blocks in the config (~/.zshrc and friends are symlinks
#     into this repo, so an installer's append lands in the working tree;
#     Docker Desktop's slipped through until only the sandboxed suite caught
#     it)

source "${0:A:h}/lib.zsh"
setopt extended_glob   # run.zsh's emulate -R turns it off; the ## patterns below need it

typeset -a cfg_files
cfg_files=(
    "$ZSH_CONF"/.zshrc
    "$ZSH_CONF"/.zshenv
    "$ZSH_CONF"/.zprofile
    "$ZSH_CONF"/.zsh/lib/*.zsh(N)
    "$ZSH_CONF"/.zsh/functions/*(N.)
)

# lint_absent <name> <pattern> [allowed-file ...]
# Fail if any non-comment line in the config matches $pattern, except in
# explicitly allowlisted files.
lint_absent() {
    local name="$1" pattern="$2"
    shift 2
    local -a allowed hits
    allowed=("$@")
    local f line
    local -i lineno
    for f in "${cfg_files[@]}"; do
        (( ${allowed[(Ie)${f:t}]} )) && continue
        lineno=0
        while IFS= read -r line; do
            (( lineno++ ))
            [[ "${line##[[:space:]]#}" == \#* ]] && continue
            [[ "$line" == *${~pattern}* ]] && hits+=("${f:t}:$lineno")
        done < "$f"
    done
    if (( ${#hits} == 0 )); then
        t_pass "$name"
    else
        t_fail "$name" "${(j:, :)hits}"
    fi
}

lint_absent 'no source-time eval "$(...)" (init output must be cached)' \
    'eval[[:space:]]#\"\$\('
lint_absent 'no source-time eval $(...)' \
    'eval[[:space:]]#\$\('
lint_absent 'no $(command -v ...) value captures (function-shadow trap)' \
    '\$\(command -v'
lint_absent 'no hardcoded cache dir outside .zshrc' \
    '.cache/zsh' .zshrc

# ── no installer blocks ───────────────────────────────────────────────
# Installers append to the rc file they find, and here that file is this
# repo's: Docker Desktop added a PATH line to .zprofile and a second,
# unfingerprinted compinit to .zshrc. Their blocks give themselves away two
# ways: marker comments ("added by ...", conda's ">>> ... >>>", "End of ...
# section", Amazon Q's "keep at the top of this file") and the installing
# user's home written out literally, where this config always says $HOME.
# Comments are scanned too, since the markers are comments. Matching is
# case-insensitive.
typeset -g foreign_re='added by|>>> .* >>>|<<< .* <<<|end of .* section'
foreign_re+='|keep at the (top|bottom) of this file|/(Users|home)/[A-Za-z0-9._-]'

# foreign_lines <file ...> — print file:line for each line matching foreign_re.
foreign_lines() {
    local f hit
    for f in "$@"; do
        for hit in ${(f)"$(grep -inE "$foreign_re" "$f")"}; do
            print -r -- "${f:t}:${hit%%:*}"
        done
    done
}

# The detector must flag the blocks that prompted it, verbatim, or a clean
# result below means nothing.
cat > "$T_SCRATCH/docker-zprofile" <<'EOF'
# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/mim/.docker/bin"
# End of Docker Desktop section.
EOF
cat > "$T_SCRATCH/docker-zshrc" <<'EOF'
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/mim/.docker/completions $fpath)
autoload -Uz compinit
(( ${+_comps[docker]} )) || compinit
# End of Docker CLI completions
EOF
typeset -a foreign
foreign=(${(f)"$(foreign_lines "$T_SCRATCH/docker-zprofile")"})
assert_eq "${foreign[*]}" 'docker-zprofile:1 docker-zprofile:2 docker-zprofile:3' \
    "installer detector flags Docker Desktop's .zprofile PATH block"
foreign=(${(f)"$(foreign_lines "$T_SCRATCH/docker-zshrc")"})
assert_eq "${foreign[*]}" 'docker-zshrc:1 docker-zshrc:2' \
    "installer detector flags Docker Desktop's .zshrc completions block"

foreign=(${(f)"$(foreign_lines "${cfg_files[@]}")"})
if (( ${#foreign} == 0 )); then
    t_pass "no installer blocks or literal home paths in the config"
else
    t_fail "no installer blocks or literal home paths in the config" \
        "${(j:, :)foreign} (remove the block, or use \$HOME)"
fi

# ── lib module naming: two-digit prefix, lowercase, .zsh ──────────────
typeset -a badnames
typeset f=''
for f in "$ZSH_CONF"/.zsh/lib/*(N); do
    [[ "${f:t}" == [0-9][0-9]-[a-z0-9-]##.zsh ]] || badnames+=("${f:t}")
done
if (( ${#badnames} == 0 )); then
    t_pass "lib modules keep the NN-name.zsh ordering contract"
else
    t_fail "lib modules keep the NN-name.zsh ordering contract" "${(j:, :)badnames}"
fi

# ── functions dir: autoloadable, plain names, no dead .zsh files ──────
badnames=()
for f in "$ZSH_CONF"/.zsh/functions/*(N); do
    [[ "${f:t}" == *.zsh ]] && badnames+=("${f:t} (.zsh files are never autoloaded)")
    [[ "${f:t}" == [a-zA-Z0-9_-]## ]] || badnames+=("${f:t} (not a plain function name)")
    [[ -d "$f" ]] && badnames+=("${f:t} (directory)")
done
if (( ${#badnames} == 0 )); then
    t_pass "functions dir contains only autoloadable function files"
else
    t_fail "functions dir contains only autoloadable function files" "${(j:, :)badnames}"
fi

# ── zle -N widgets resolve somewhere ──────────────────────────────────
# A widget's function may live in our functions dir, be defined inline in
# a module, or be a zsh-shipped function pulled in with `autoload` — any
# of these counts as resolved. A name matching none of them is a binding
# that errors on first keypress.
typeset -a widgets_declared unresolved
typeset line='' name='' rest=''
for f in "$ZSH_CONF"/.zsh/lib/*.zsh(N) "$ZSH_CONF"/.zshrc; do
    while IFS= read -r line; do
        [[ "${line##[[:space:]]#}" == \#* ]] && continue
        [[ "$line" == *"zle -N "* ]] || continue
        rest="${line##*zle -N[[:space:]]}"
        name="${rest%%[[:space:]]*}"
        # Two-arg form (zle -N widget func) names its function explicitly;
        # check that instead.
        rest="${rest#$name}"
        rest="${rest##[[:space:]]#}"
        [[ -n "$rest" && "$rest" != \#* ]] && name="${rest%%[[:space:]]*}"
        widgets_declared+=("$name")
    done < "$f"
done
for name in "${widgets_declared[@]}"; do
    [[ -f "$ZSH_CONF/.zsh/functions/$name" ]] && continue
    grep -qE "^[[:space:]]*(function[[:space:]]+)?${name}[[:space:]]*\(\)" \
        "$ZSH_CONF"/.zsh/lib/*.zsh && continue
    grep -qE "^[[:space:]]*autoload\b.*[[:space:]]${name}(\$|[[:space:]])" \
        "$ZSH_CONF"/.zsh/lib/*.zsh "$ZSH_CONF"/.zshrc && continue
    unresolved+=("$name")
done
if (( ${#widgets_declared} > 0 )); then
    if (( ${#unresolved} == 0 )); then
        t_pass "all ${#widgets_declared} zle -N widget(s) resolve to a function source"
    else
        t_fail "all ${#widgets_declared} zle -N widget(s) resolve to a function source" \
            "${(j:, :)unresolved}"
    fi
else
    t_fail "all zle -N widgets resolve to a function source" \
        "lint found no zle -N declarations at all — extraction pattern broke"
fi

# ── GitHub Actions pinned by commit ──────────────────────────────────
# A tag such as @v5 is a moving pointer the action's maintainers, or anyone
# holding their credentials, can repoint; a 40-hex commit is not. Dependabot
# keeps the pin current and bumps the version comment with it.
typeset -a wf_uses unpinned
typeset wf_line=''
for f in "$REPO_ROOT"/.github/workflows/*.yml(N); do
    while IFS= read -r wf_line; do
        [[ "$wf_line" == *'uses:'* ]] || continue
        wf_uses+=("$wf_line")
        [[ "$wf_line" == *'@'[0-9a-f](#c40)' #'* ]] || unpinned+=("${f:t}: ${wf_line##*uses: }")
    done < "$f"
done
if (( ${#wf_uses} > 0 )); then
    if (( ${#unpinned} == 0 )); then
        t_pass "all ${#wf_uses} workflow action(s) pinned by commit with a version comment"
    else
        t_fail "all ${#wf_uses} workflow action(s) pinned by commit with a version comment" \
            "${(j:, :)unpinned}"
    fi
else
    t_fail "all workflow actions pinned by commit" \
        "lint found no uses: lines in .github/workflows — extraction pattern broke"
fi

t_finish
