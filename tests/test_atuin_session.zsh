#!/usr/bin/env zsh
# The atuin session mint is the one tool-init line rewritten rather than
# cached verbatim: _atuin_session_uuid must be a format-faithful, fork-free
# stand-in for `atuin uuid` (dashless lowercase UUIDv7), and
# _atuin_filter_init must rewrite exactly that line of atuin's emitted
# init and pass everything else through untouched (fail-open: an
# unrecognized init keeps upstream's fork — slow, never wrong).
source "${0:A:h}/lib.zsh"

# Sourcing 50-integrations.zsh runs setup_integrations/setup_zoxide at the
# bottom; point their cache writes at scratch so a test run never touches
# the real ~/.cache/zsh. zle noise on stderr is expected non-interactively.
typeset -g SHELL_CACHE_DIR="$T_SCRATCH/cache"
mkdir -p "$SHELL_CACHE_DIR"
source "$ZSH_CONF/.zsh/lib/50-integrations.zsh" 2>/dev/null

# ── generator format ──────────────────────────────────────────────
zmodload zsh/datetime
REPLY=''
if _atuin_session_uuid; then
    t_pass "generator returns success"
else
    t_fail "generator returns success"
fi
typeset u="$REPLY"

if [[ "$u" =~ '^[0-9a-f]{32}$' ]]; then
    t_pass "output is 32 lowercase hex chars (dashless uuid)"
else
    t_fail "output is 32 lowercase hex chars (dashless uuid)" "got ${(qq)u}"
fi
assert_eq "${u[13]}" "7" "version nibble is 7 (UUIDv7)"
if [[ "${u[17]}" == [89ab] ]]; then
    t_pass "variant nibble is RFC 4122 (8/9/a/b)"
else
    t_fail "variant nibble is RFC 4122 (8/9/a/b)" "got ${(qq)u[17]}"
fi

# First 12 hex chars are a unix-ms timestamp — must sit within a minute
# of now, exactly like the real atuin uuid's prefix.
typeset -i ts_ms=$(( 16#${u[1,12]} ))
typeset -i now_ms=$(( ${EPOCHREALTIME%.*} * 1000 ))
if (( ts_ms > now_ms - 60000 && ts_ms < now_ms + 60000 )); then
    t_pass "timestamp prefix is current unix-ms"
else
    t_fail "timestamp prefix is current unix-ms" "ts=$ts_ms now=$now_ms"
fi

# ── uniqueness under burst (tmux restoring many panes at once) ─────
typeset -A _seen
typeset -i dups=0 malformed=0
repeat 500; do
    _atuin_session_uuid
    [[ "$REPLY" =~ '^[0-9a-f]{32}$' ]] || (( malformed++ ))
    (( ${+_seen[$REPLY]} )) && (( dups++ ))
    _seen[$REPLY]=1
done
assert_eq "$malformed" "0" "500 consecutive mints all well-formed"
assert_eq "$dups" "0" "500 consecutive mints all unique"

# ── filter rewrites the mint line, preserves everything else ───────
typeset upstream='	export ATUIN_SESSION=$(atuin uuid)'
typeset rewritten
rewritten="$(print -r -- "$upstream" | _atuin_filter_init)"
assert_contains "$rewritten" '_atuin_session_uuid && export ATUIN_SESSION="$REPLY"' \
    "mint line calls the fork-free generator"
assert_not_contains "$rewritten" 'atuin uuid' \
    "mint line no longer forks atuin"
assert_eq "${rewritten%%_atuin*}" "${upstream%%export*}" \
    "rewrite preserves the line's indentation"

typeset -a passthrough
passthrough=(
    'export ATUIN_SHLVL=$SHLVL'
    '_atuin_preexec() {'
    'if [[ -z "${ATUIN_SESSION:-}" || "${ATUIN_SHLVL:-}" != "$SHLVL" ]]; then'
)
# Assignments, not bare declarations: zsh prints an already-set parameter
# (env noise like $out under nix) when typeset names it with no value.
typeset line='' out=''
for line in "${passthrough[@]}"; do
    out="$(print -r -- "$line" | _atuin_filter_init)"
    assert_eq "$out" "$line" "passthrough untouched: ${line[1,40]}"
done

# Rewritten line must still be valid zsh in an if-body.
if print -r -- "if true; then
$(print -r -- "$upstream" | _atuin_filter_init)
fi" | zsh -n 2>/dev/null; then
    t_pass "rewritten line parses as zsh"
else
    t_fail "rewritten line parses as zsh"
fi

# ── live cache on machines that have atuin ─────────────────────────
if have atuin; then
    typeset cache="$SHELL_CACHE_DIR/atuin-init.zsh"
    if [[ -f "$cache" ]]; then
        typeset cache_body="$(<"$cache")"
        assert_not_contains "$cache_body" '$(atuin uuid)' \
            "generated cache carries no per-shell atuin fork"
        assert_contains "$cache_body" '_atuin_session_uuid' \
            "generated cache mints via the generator"
    else
        t_fail "atuin cache generated into scratch" "missing: $cache"
    fi
    # Format parity with the real thing, so a session id from either
    # source is interchangeable in atuin's history records.
    typeset real="$(atuin uuid)"
    if [[ "$real" =~ '^[0-9a-f]{32}$' ]]; then
        t_pass "real atuin uuid still matches the format we emit"
    else
        t_fail "real atuin uuid still matches the format we emit" \
            "atuin changed its uuid shape: ${(qq)real} — revisit _atuin_session_uuid"
    fi
else
    t_skip "cache and format-parity checks" "atuin not installed"
fi

t_finish
