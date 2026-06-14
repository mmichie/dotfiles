#!/usr/bin/env zsh
# Pre-commit gate: every file staged under secrets/ MUST be a sops envelope.
#
# This is the one secret-hygiene check no general scanner (gitleaks/trufflehog/
# detect-secrets) performs — they detect leaked secrets; this asserts that
# encryption is PRESENT on files designated as secret. Commodity secret
# detection (provider patterns + entropy) is delegated to gitleaks (.gitleaks.toml).
#
# Args are the staged paths (lefthook {staged_files}). Scans the STAGED blob
# (git show :path), not the worktree, so it matches what the commit contains.
# Dependency-free: grep + git only.

emulate -R zsh
setopt extended_glob

typeset -i findings=0
typeset f content
for f in "$@"; do
    [[ "$f" == secrets/* ]] || continue
    # Skip the test fixture, which stages deliberately-unencrypted secrets/ files.
    [[ "$f" == tests/* ]] && continue
    content=$(git show ":$f" 2>/dev/null) || continue
    if ! print -r -- "$content" | grep -q 'ENC\[' \
        || ! print -r -- "$content" | grep -q '"sops"\|sops_version\|lastmodified'; then
        print -r -- "BLOCKED: $f is under secrets/ but is not sops-encrypted" >&2
        (( findings++ ))
    fi
done

if (( findings )); then
    print -r -- "" >&2
    print -r -- "$findings file(s) under secrets/ are not sops envelopes. Encrypt with sops, or remove." >&2
    exit 1
fi
