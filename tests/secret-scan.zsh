#!/usr/bin/env zsh
# Fast pre-commit gate: scan staged files for plaintext secrets, and verify
# anything staged under secrets/ is actually sops-encrypted. Args are the
# staged file paths (lefthook {staged_files}). Exits nonzero on any finding.
#
# Three checks per file: (1) known secret-marker patterns, (2) a generic
# high-entropy backstop for blobs that match no pattern, (3) secrets/ must be
# sops-encrypted. Scans the STAGED blob (git show :path), not the worktree, so
# it matches exactly what the commit would contain. Dependency-free: grep, git,
# and zsh builtins only (entropy uses zsh/mathfunc, no external tool).

emulate -R zsh
setopt extended_glob

# zsh's math library powers the entropy gate; degrade gracefully if absent.
typeset -i HAVE_MATH=0
zmodload -F zsh/mathfunc f:log 2>/dev/null && HAVE_MATH=1

# Declare loop-locals once: re-running `typeset hit` inside the loop echoes
# the variable at script scope ("hit=value") on later iterations.
typeset -i findings=0
typeset f content hit tok

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

# ── Generic high-entropy detector ────────────────────────────────────
# Backstops the fixed pattern list. Calibrated against the live repo (see
# tests/test_secret_scan.zsh): minlen + threshold sit in the gap between
# benign tokens (longest is a ~4.46-bit path) and real base64 secrets
# (~5.5 bits/char).
typeset -i ENT_MINLEN=25
typeset -F ENT_THRESHOLD=4.5

# Shannon entropy (bits/char) of $1 into $REPLY. Pure zsh, no subprocess.
_token_entropy() {
    local s=$1
    local -i n=${#s}
    (( n == 0 )) && { REPLY=0; return }
    local -A freq
    local ch cnt
    for ch in ${(s::)s}; do
        freq[$ch]=$(( ${freq[$ch]:-0} + 1 ))
    done
    local -F ent=0 p
    for ch in ${(k)freq}; do
        cnt=${freq[$ch]}
        (( p = cnt * 1.0 / n ))
        (( ent += - p * (log(p) / log(2)) ))
    done
    REPLY=$ent
}

for f in "$@"; do
    # Skip the scanner sources (they contain marker literals), encrypted
    # secrets, lockfiles, and vendored submodule trees.
    case "$f" in
        tests/secret-scan.zsh|tests/test_secrets.zsh|tests/test_secret_scan.zsh) continue ;;
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

    # 3. Generic high-entropy backstop: a random secret blob that matches no
    #    pattern still trips on Shannon entropy. Skips encrypted envelopes and
    #    the charset demo (high-entropy by construction) and binary blobs;
    #    shape-excludes the high-entropy strings the repo legitimately commits
    #    (SSH pubkeys, age recipients, SRI + hex hashes) before the math.
    if (( HAVE_MATH )) && [[ "$f" != secrets/* && "$f" != configs/system/UTF-8-demo.txt ]] \
        && git show ":$f" 2>/dev/null | grep -Iq .; then
        for tok in ${(f)"$(print -r -- "$content" | grep -aoE '[A-Za-z0-9+/=_-]{'"$ENT_MINLEN"',}')"}; do
            [[ -z "$tok" ]] && continue
            [[ "$tok" == [0-9a-fA-F]## ]] && continue            # hex: git/sha/store hashes
            [[ "$tok" == AAAA* ]] && continue                    # SSH public-key blob
            [[ "$tok" == age1* ]] && continue                    # age recipient (public)
            [[ "$tok" == (sha256|sha384|sha512)-* ]] && continue # SRI hash
            _token_entropy "$tok"
            if (( REPLY >= ENT_THRESHOLD )); then
                print -r -- "BLOCKED: $f contains a high-entropy string (possible unencrypted secret): ${REPLY[1,4]} bits/char over ${#tok} chars" >&2
                (( findings++ ))
                break
            fi
        done
    fi
done

if (( findings )); then
    print -r -- "" >&2
    print -r -- "$findings secret-hygiene violation(s). Encrypt with sops, or remove the secret." >&2
    print -r -- "If this is a false positive, commit with --no-verify." >&2
    exit 1
fi
