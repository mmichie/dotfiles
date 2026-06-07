#!/usr/bin/env zsh
# Fast pre-commit gate: scan staged files for plaintext secrets, and verify
# anything staged under secrets/ is actually sops-encrypted. Args are the
# staged file paths (lefthook {staged_files}). Exits nonzero on any finding.
#
# Scans the STAGED blob (git show :path), not the worktree, so it matches
# exactly what the commit would contain. Dependency-free (grep + git only).

emulate -R zsh
setopt extended_glob

# Declare loop-locals once: re-running `typeset hit` inside the loop echoes
# the variable at script scope ("hit=value") on later iterations.
typeset -i findings=0
typeset f content hit

# High-signal secret markers. The AGE marker is split so this scanner never
# trips on its own source. Pubkeys (age1...) and sops ENC[...] are NOT here.
typeset -a patterns
patterns=(
    'AGE-SECRET-'$'KEY''-1[0-9A-Z]{50,}'        # age X25519 private key
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'        # PEM private keys (RSA/EC/OPENSSH/PGP)
    'ya29\.[A-Za-z0-9_-]{20,}'                   # Google OAuth access token
    'AKIA[0-9A-Z]{16}'                           # AWS access key id
    'ASIA[0-9A-Z]{16}'                           # AWS temp key id
    'ghp_[A-Za-z0-9]{36}'                        # GitHub personal access token
    'github_pat_[A-Za-z0-9_]{50,}'              # GitHub fine-grained PAT
    'xox[baprs]-[0-9A-Za-z-]{10,}'              # Slack token
    'sk-[A-Za-z0-9]{32,}'                        # generic provider secret key
)
typeset PAT="${(j:|:)patterns}"

for f in "$@"; do
    # Skip the scanner sources (they contain marker literals), encrypted
    # secrets, lockfiles, and vendored submodule trees.
    case "$f" in
        tests/secret-scan.zsh|tests/test_secrets.zsh) continue ;;
        secrets/*) ;;   # handled below; also still plaintext-scanned
        *.lock|*.zwc) continue ;;
        configs/tmux/plugins/*) continue ;;
    esac

    content=$(git show ":$f" 2>/dev/null) || continue

    # 1. Plaintext secret markers anywhere in the staged content.
    hit=$(print -r -- "$content" | grep -noE "$PAT" 2>/dev/null | head -1)
    if [[ -n "$hit" ]]; then
        print -r -- "BLOCKED: $f looks like it contains a plaintext secret (line ${hit%%:*})" >&2
        (( findings++ ))
    fi

    # 2. Anything under secrets/ must be a sops envelope.
    if [[ "$f" == secrets/* ]]; then
        if ! print -r -- "$content" | grep -q 'ENC\[' || ! print -r -- "$content" | grep -q '"sops"\|sops_version\|lastmodified'; then
            print -r -- "BLOCKED: $f is under secrets/ but is not sops-encrypted" >&2
            (( findings++ ))
        fi
    fi
done

if (( findings )); then
    print -r -- "" >&2
    print -r -- "$findings secret-hygiene violation(s). Encrypt with sops, or remove the secret." >&2
    print -r -- "If this is a false positive, commit with --no-verify." >&2
    exit 1
fi
