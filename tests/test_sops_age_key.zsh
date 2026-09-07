#!/usr/bin/env zsh
# bin/bin/sops-age-key: the sops age identity (root of trust for every sops
# secret) lives in 1Password, op://Private/dotfiles-sops-age-key, and this
# script moves it in and out of ~/.config/sops/age/keys.txt. Driven through
# a stub `op` that serves fields from a directory and records item creation.
#   - pull writes the key file (0600, dir 0700) with the public-key header
#   - pull is a no-op when the file already holds the same key
#   - pull refuses to replace a different key, and leaves it untouched
#   - pull rejects a field that is not an age key, writing nothing
#   - push creates the item from the file when it is absent, secret via stdin
#   - push is a no-op when the item already holds the key
#   - push refuses when the item holds a different key

source "${0:A:h}/lib.zsh"
zmodload -F zsh/stat b:zstat

typeset SCRIPT="$REPO_ROOT/bin/bin/sops-age-key"
typeset opdir="$T_SCRATCH/opbin" fields="$T_SCRATCH/fields" home="$T_SCRATCH/home"
mkdir -p "$fields" "$home"
make_stub "$opdir" op 'printf "%s\n" "$*" >> "$OP_CALL_LOG"
# global --account flag precedes the subcommand
[ "$1" = --account ] && shift 2
case "$1 $2" in
    "read "*)
        for a in "$@"; do last="$a"; done
        p="${last#op://}"; p="${p#*/}"; item="${p%%/*}"; field="${p#*/}"
        [ -f "$OP_FIELDS/$item/$field" ] && cat "$OP_FIELDS/$item/$field" || { echo "[ERROR] not found" >&2; exit 1; }
        ;;
    "item get")  [ -d "$OP_FIELDS/$3" ] ;;
    "item create") cat > "$OP_CREATE_LOG"; echo created ;;
    *) echo "[ERROR] stub: unexpected $*" >&2; exit 64 ;;
esac'

# Fake keys, deliberately too short for gitleaks' age-secret-key rule (58 bech32
# chars); the script only checks the prefix and character class.
typeset SECRET="AGE-SECRET-KEY-1TESTONLYNOTAREALKEYQ"
typeset PUBLIC="age1testtesttesttesttesttesttesttesttesttesttesttesttesttestq"
typeset keyfile="$home/.config/sops/age/keys.txt"
typeset calls="$T_SCRATCH/op-calls.log" created="$T_SCRATCH/op-create.json"

# run <pull|push>: the script under a controlled env; stdout+stderr in RUN_OUT.
typeset RUN_OUT=''
typeset -i RUN_RC=0
run() {
    RUN_OUT="$(env -i PATH="$opdir:$PATH" HOME="$home" OP_FIELDS="$fields" OP_CALL_LOG="$calls" \
        OP_CREATE_LOG="$created" SOPS_AGE_KEY_FILE="$keyfile" bash "$SCRIPT" "$@" 2>&1)"
    RUN_RC=$?
}
seed_item() { mkdir -p "$fields/dotfiles-sops-age-key"; print -r -- "$1" > "$fields/dotfiles-sops-age-key/private-key"; print -r -- "$PUBLIC" > "$fields/dotfiles-sops-age-key/public-key"; }

# ── pull ─────────────────────────────────────────────────────────────
seed_item "$SECRET"
run pull
assert_eq "$RUN_RC" "0" "pull into an empty home succeeds"
assert_eq "$(sed -n '1p' "$keyfile" 2>/dev/null)" "# public key: $PUBLIC" "pull writes the public-key header"
assert_eq "$(sed -n '2p' "$keyfile" 2>/dev/null)" "$SECRET" "pull writes the secret key"
assert_eq "${$(zstat -o +mode "$keyfile" 2>/dev/null)[-3,-1]}" "600" "key file is 0600"
assert_eq "${$(zstat -o +mode "${keyfile:h}" 2>/dev/null)[-3,-1]}" "700" "key directory is 0700"
assert_contains "$(<"$calls")" "--account famfam.1password.com read op://Private/dotfiles-sops-age-key/private-key" \
    "pull reads the private-key field from the personal account"

run pull
assert_eq "$RUN_RC" "0" "pull is a no-op when the file already holds the key"
assert_contains "$RUN_OUT" "already holds" "no-op pull says so"

seed_item "AGE-SECRET-KEY-1OTHERFAKEKEYQ"
run pull
assert_eq "$RUN_RC" "1" "pull refuses to replace a different key"
assert_eq "$(sed -n '2p' "$keyfile")" "$SECRET" "the existing key is untouched"

rm -f "$keyfile"
print -r -- "not a key at all" > "$fields/dotfiles-sops-age-key/private-key"
run pull
assert_eq "$RUN_RC" "1" "pull rejects a field that is not an age secret key"
[[ -e "$keyfile" ]] && t_fail "rejected pull writes nothing" "key file exists" || t_pass "rejected pull writes nothing"

# ── push ─────────────────────────────────────────────────────────────
rm -rf "$fields/dotfiles-sops-age-key"; : > "$calls"; rm -f "$created"
mkdir -p "${keyfile:h}"; print -rl -- "# created: 2026-01-01T00:00:00Z" "# public key: $PUBLIC" "$SECRET" > "$keyfile"
run push
assert_eq "$RUN_RC" "0" "push creates the item when it is absent"
assert_contains "$(<"$calls")" "item create --vault Private" "push creates in the Private vault"
assert_contains "$(<"$created" 2>/dev/null)" "\"value\":\"$SECRET\"" "the secret travels in the stdin template"
assert_contains "$(<"$created" 2>/dev/null)" "\"value\":\"$PUBLIC\"" "the public key travels in the stdin template"
assert_not_contains "$(<"$calls")" "$SECRET" "the secret never appears in op's argv"

seed_item "$SECRET"; : > "$calls"
run push
assert_eq "$RUN_RC" "0" "push is a no-op when the item already holds the key"
assert_not_contains "$(<"$calls")" "item create" "no-op push creates nothing"

seed_item "AGE-SECRET-KEY-1OTHERFAKEKEYQ"; : > "$calls"
run push
assert_eq "$RUN_RC" "1" "push refuses when the item holds a different key"
assert_not_contains "$(<"$calls")" "item create" "refused push creates nothing"

t_finish
