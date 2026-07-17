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

# ── lib module naming: two-digit prefix, lowercase, .zsh ──────────────
typeset -a badnames
typeset f
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

t_finish
