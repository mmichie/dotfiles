#!/usr/bin/env zsh
# bin/bin/sops-age-key: each host's sops age identity (root of trust for the
# secrets encrypted to it in .sops.yaml) lives in 1Password as a Document,
# "<host> sops-nix age key (DO NOT DELETE)" in the Private vault, holding the
# keys.txt file itself. The script moves that file in and out of
# ~/.config/sops/age/keys.txt. Driven through a stub `op` that serves
# documents from a directory and captures uploads.
#   - pull writes the document verbatim (0600, dir 0700)
#   - pull is a no-op when the file already holds the same key
#   - pull refuses to replace a different key, and leaves it untouched
#   - pull rejects a document without exactly one age secret, writing nothing
#   - push uploads the file when the item is absent; the secret never in argv
#   - push is a no-op when the item already holds the key
#   - push refuses when the item holds a different key

source "${0:A:h}/lib.zsh"
zmodload -F zsh/stat b:zstat

typeset SCRIPT="$REPO_ROOT/bin/bin/sops-age-key"
typeset opdir="$T_SCRATCH/opbin" docs="$T_SCRATCH/docs" home="$T_SCRATCH/home"
mkdir -p "$docs" "$home"
make_stub "$opdir" op 'printf "%s\n" "$*" >> "$OP_CALL_LOG"
# global --account flag precedes the subcommand
[ "$1" = --account ] && shift 2
case "$1 $2" in
    "document get") [ -f "$OP_DOCS/$3" ] && cat "$OP_DOCS/$3" || { echo "[ERROR] not found" >&2; exit 1; } ;;
    "item get")     [ -f "$OP_DOCS/$3" ] ;;
    "document create") cp "$3" "$OP_CREATE_LOG"; echo created ;;
    *) echo "[ERROR] stub: unexpected $*" >&2; exit 64 ;;
esac'

# Fake keys, deliberately too short for gitleaks' age-secret-key rule (58
# bech32 chars); the script only checks the prefix and character class.
typeset SECRET="AGE-SECRET-KEY-1TESTONLYNOTAREALKEYQ"
typeset OTHER="AGE-SECRET-KEY-1OTHERFAKEKEYQ"
typeset PUBLIC="age1testtesttesttesttesttesttesttesttesttesttesttesttesttestq"
typeset ITEM="testhost sops-nix age key (DO NOT DELETE)"
typeset keyfile="$home/.config/sops/age/keys.txt"
typeset calls="$T_SCRATCH/op-calls.log" uploaded="$T_SCRATCH/op-upload.txt"
typeset DOC=$'# created: 2026-01-01T00:00:00Z\n# public key: '"$PUBLIC"$'\n'"$SECRET"

typeset RUN_OUT=''
typeset -i RUN_RC=0
run() {
    RUN_OUT="$(env -i PATH="$opdir:$PATH" HOME="$home" OP_DOCS="$docs" OP_CALL_LOG="$calls" \
        OP_CREATE_LOG="$uploaded" SOPS_AGE_KEY_FILE="$keyfile" SOPS_AGE_1P_HOST=testhost \
        bash "$SCRIPT" "$@" 2>&1)"
    RUN_RC=$?
}
seed_doc() { print -r -- "$1" > "$docs/$ITEM"; }

# ── pull ─────────────────────────────────────────────────────────────
seed_doc "$DOC"
run pull
assert_eq "$RUN_RC" "0" "pull into an empty home succeeds"
assert_eq "$(<"$keyfile" 2>/dev/null)" "$DOC" "pull writes the document verbatim (created, public key, secret)"
assert_eq "${$(zstat -o +mode "$keyfile" 2>/dev/null)[-3,-1]}" "600" "key file is 0600"
assert_eq "${$(zstat -o +mode "${keyfile:h}" 2>/dev/null)[-3,-1]}" "700" "key directory is 0700"
assert_contains "$(<"$calls")" "--account famfam.1password.com document get $ITEM --vault Private" \
    "pull fetches the host's document from the Private vault of the personal account"

run pull
assert_eq "$RUN_RC" "0" "pull is a no-op when the file already holds the key"
assert_contains "$RUN_OUT" "already holds" "no-op pull says so"

seed_doc "${DOC/$SECRET/$OTHER}"
run pull
assert_eq "$RUN_RC" "1" "pull refuses to replace a different key"
assert_eq "$(<"$keyfile")" "$DOC" "the existing key file is untouched"

rm -f "$keyfile"
seed_doc $'# public key: '"$PUBLIC"$'\nnot a key at all'
run pull
assert_eq "$RUN_RC" "1" "pull rejects a document without an age secret"
[[ -e "$keyfile" ]] && t_fail "rejected pull writes nothing" "key file exists" || t_pass "rejected pull writes nothing"

# ── push ─────────────────────────────────────────────────────────────
rm -f "$docs/$ITEM" "$uploaded"; : > "$calls"
mkdir -p "${keyfile:h}"; print -r -- "$DOC" > "$keyfile"
run push
assert_eq "$RUN_RC" "0" "push uploads the file when the item is absent"
assert_contains "$(<"$calls")" "document create $keyfile --title $ITEM --vault Private --file-name keys.txt" \
    "push creates the host's document in the Private vault"
assert_eq "$(<"$uploaded" 2>/dev/null)" "$DOC" "the uploaded document is the key file"
assert_not_contains "$(<"$calls")" "$SECRET" "the secret never appears in op's argv"

seed_doc "$DOC"; : > "$calls"
run push
assert_eq "$RUN_RC" "0" "push is a no-op when the item already holds the key"
assert_not_contains "$(<"$calls")" "document create" "no-op push uploads nothing"

seed_doc "${DOC/$SECRET/$OTHER}"; : > "$calls"
run push
assert_eq "$RUN_RC" "1" "push refuses when the item holds a different key"
assert_not_contains "$(<"$calls")" "document create" "refused push uploads nothing"

t_finish
