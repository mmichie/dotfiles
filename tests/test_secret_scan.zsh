#!/usr/bin/env zsh
# Unit tests for tests/secret-scan.zsh — the pre-commit secret-hygiene gate.
# Exercises the real scanner end-to-end against a throwaway git index (it reads
# `git show :path`): stage a synthetic blob, assert BLOCK vs PASS. Locks in the
# pattern matchers, the high-entropy backstop, and the must-not-fire exclusions
# (SSH pubkeys, age recipients, SRI/hex hashes) calibrated from the live repo.

source "${0:A:h}/lib.zsh"

typeset SCANNER="$REPO_ROOT/tests/secret-scan.zsh"

if ! have git; then
    t_skip "secret-scan gate" "git unavailable"
    t_finish
fi

# Throwaway repo: the scanner reads the staged blob via `git show :path`, so a
# real index is required. No commit needed — `git add` populates the index.
typeset repo="$T_SCRATCH/scanrepo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.invalid
git -C "$repo" config user.name tester

typeset out
typeset -i rc
# stage_and_scan <relpath> <content> — sets $out and $rc.
stage_and_scan() {
    local rel="$1" body="$2"
    mkdir -p "$repo/${rel:h}"
    print -r -- "$body" >"$repo/$rel"
    git -C "$repo" add -f "$rel"
    # Disarm the nix set-environment PATH rewrite in the global zshenv (always
    # sourced even under --no-globalrcs) so git/grep stay on PATH for the scan.
    out=$(cd "$repo" && __NIX_DARWIN_SET_ENVIRONMENT_DONE=1 __NIXOS_SET_ENVIRONMENT_DONE=1 \
        zsh --no-globalrcs "$SCANNER" "$rel" 2>&1)
    rc=$?
}

# ── Must BLOCK ───────────────────────────────────────────────────────
# AKIAIOSFODNN7EXAMPLE is AWS's own documented example id (allowlisted by
# upstream scanners), so committing this test never trips real push protection.
stage_and_scan "notes.txt" "aws key AKIAIOSFODNN7EXAMPLE in here"
assert_eq "$rc" "1" "AWS access-key id is blocked (pattern)"

stage_and_scan "key.pem" "-----BEGIN OPENSSH PRIVATE KEY-----"
assert_eq "$rc" "1" "PEM private-key header is blocked (pattern)"

# A random base64-ish blob that matches NO pattern — caught by entropy alone.
stage_and_scan "blob.txt" "session_token = Hk9Tf2Qp7Wm4Rv8Xb1Nc6Zd3Hg5Js0Ay4Ue7Po2Lq"
assert_eq       "$rc"  "1"            "high-entropy random blob is blocked (entropy)"
assert_contains "$out" "high-entropy" "entropy finding is labelled as such"

stage_and_scan "secrets/new.yaml" "plaintext: this is not encrypted"
assert_eq "$rc" "1" "plaintext file under secrets/ is blocked"

# ── Must PASS — the calibrated exclusions, else the gate is unusable ──
stage_and_scan "id.pub" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUwxYQhqytNcE3C2yjofakefakefakefakefakefake user@host"
assert_eq "$rc" "0" "SSH public key is allowed (AAAA blob excluded)"

stage_and_scan "sopskeys.txt" "recipient: age16z6aaru0y89wpf0uzdcz6pc40tllx8sp7htvnmh0fakefakefakefake"
assert_eq "$rc" "0" "age recipient (public) is allowed"

stage_and_scan "dep.nix" 'hash = "sha256-B/qWMdLfQXqZE163F96MeFMRrDpuO8fWiD4ZfakeAAAA=";'
assert_eq "$rc" "0" "SRI sha256- hash is allowed"

stage_and_scan "rev.txt" "rev = 4e7a9c1d2b3f5a6e8c0d1f2a3b4c5d6e7f8a9b0c"
assert_eq "$rc" "0" "40-char git sha (hex) is allowed"

stage_and_scan "prose.md" "This is a perfectly ordinary sentence with several longish words in it."
assert_eq "$rc" "0" "ordinary prose is allowed"

t_finish
