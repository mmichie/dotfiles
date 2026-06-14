#!/usr/bin/env zsh
# Unit tests for tests/sops-check.zsh — the sops-envelope pre-commit gate (the
# non-commodity half of the old secret-scan, kept after gitleaks took over
# pattern/entropy detection). Stages blobs into a throwaway git index and
# asserts BLOCK vs PASS.

source "${0:A:h}/lib.zsh"

typeset CHECK="$REPO_ROOT/tests/sops-check.zsh"

if ! have git; then
    t_skip "sops-check gate" "git unavailable"
    t_finish
fi

typeset repo="$T_SCRATCH/sopsrepo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.invalid
git -C "$repo" config user.name tester

typeset out
typeset -i rc
stage_and_scan() {
    local rel="$1" body="$2"
    mkdir -p "$repo/${rel:h}"
    print -r -- "$body" >"$repo/$rel"
    git -C "$repo" add -f "$rel"
    out=$(cd "$repo" && __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 __NIXOS_SET_ENVIRONMENT_DONE=1 \
        zsh --no-globalrcs "$CHECK" "$rel" 2>&1)
    rc=$?
}

# A minimal but well-formed sops envelope (has ENC[ and the sops/lastmodified marker).
typeset ENVELOPE='{"data":"ENC[AES256_GCM,data:Zm9v,iv:YmFy,tag:YmF6,type:str]","sops":{"lastmodified":"2026-01-01T00:00:00Z","version":"3.9.0"}}'

# ── Must BLOCK ───────────────────────────────────────────────────────
stage_and_scan "secrets/plain.yaml" "token: this is plaintext, not encrypted"
assert_eq "$rc" "1" "plaintext file under secrets/ is blocked"

stage_and_scan "secrets/half.yaml" 'data: ENC[AES256_GCM,data:xx] but no sops metadata block'
assert_eq "$rc" "1" "ENC[ without sops metadata is blocked"

# ── Must PASS ────────────────────────────────────────────────────────
stage_and_scan "secrets/real.json" "$ENVELOPE"
assert_eq "$rc" "0" "valid sops envelope under secrets/ passes"

stage_and_scan "notes.md" "token: this is plaintext but NOT under secrets/"
assert_eq "$rc" "0" "plaintext outside secrets/ is ignored (gitleaks' job, not this gate)"

t_finish
