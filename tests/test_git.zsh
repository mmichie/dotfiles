#!/usr/bin/env zsh
# Git configuration (configs/git). The file is deployed by symlink, so a
# mistake reaches every repository at once. Pinned:
#   - the file parses, and no include target sits outside an include
#     section (a commented-out section header leaves its keys attached to
#     whatever section precedes it)
#   - no alias shadows a builtin: git silently ignores those, so a safety
#     alias such as `pull = pull --ff-only` never ran
#   - the safety settings are present with the expected values
#   - every signing identity has an allowed_signers entry, so signatures
#     made with the shipped config can also be verified with it
#   - ssh signing round-trips: a commit signed through this config verifies
#     against an allowed_signers naming the key and fails against one
#     without it

source "${0:A:h}/lib.zsh"

typeset GITCONF="$REPO_ROOT/configs/git/.gitconfig"
typeset SIGNERS="$REPO_ROOT/configs/git/allowed_signers"

if ! have git; then
    t_skip "git config" "git not in PATH"
    t_finish
fi

# gc: read the repo's file only, never this machine's ~/.gitconfig.
gc() { git config --file "$GITCONF" "$@"; }

# ── Parses; include targets only inside include sections ─────────────
if gc --list >/dev/null 2>&1; then
    t_pass "configs/git/.gitconfig parses"
else
    t_fail "configs/git/.gitconfig parses" "$(gc --list 2>&1 | head -n 2)"
fi
typeset -a stray
stray=(${(f)"$(gc --get-regexp '\.path$' 2>/dev/null)"})
stray=(${(M)stray:#* *gitconfig*})
stray=(${stray:#include.*})
stray=(${stray:#includeif.*})
if (( ${#stray} == 0 )); then
    t_pass "no include target attached to a non-include section"
else
    t_fail "no include target attached to a non-include section" \
        "leftover of a commented-out header: ${(j: | :)stray}"
fi

# ── No alias shadows a builtin ───────────────────────────────────────
typeset -a git_builtins git_aliases shadowed
git_builtins=(${(f)"$(git --list-cmds=builtins)"})
git_aliases=(${${(f)"$(gc --get-regexp '^alias\.')"}%% *})
git_aliases=(${git_aliases#alias.})
shadowed=(${git_aliases:*git_builtins})
if (( ${#shadowed} == 0 )); then
    t_pass "no alias shadows a git builtin"
else
    t_fail "no alias shadows a git builtin (git ignores such aliases)" "${(j:, :)shadowed}"
fi

# ── Safety settings ──────────────────────────────────────────────────
typeset -A want=(
    pull.ff                    only
    push.useForceIfIncludes    true
    push.recurseSubmodules     no
    rebase.missingCommitsCheck error
    rebase.updateRefs          true
    rebase.autoSquash          true
    transfer.fsckObjects       true
    fetch.prune                true
    fetch.recurseSubmodules    on-demand
    rerere.enabled             true
    rerere.autoUpdate          true
    commit.verbose             true
    submodule.recurse          true
)
typeset k
for k in ${(ko)want}; do
    assert_eq "$(gc --get "$k" 2>/dev/null)" "$want[$k]" "$k = $want[$k]"
done
assert_eq "$(gc --get gpg.ssh.allowedSignersFile 2>/dev/null)" "~/.config/git/allowed_signers" \
    "gpg.ssh.allowedSignersFile points at the deployed allowed_signers"

# ── Every signing identity is verifiable with the shipped signers ────
typeset f email key
if [[ -f "$SIGNERS" ]]; then
    for f in "$GITCONF" "$REPO_ROOT/configs/git/.gitconfig-kyusu-local"; do
        email="$(git config --file "$f" --get user.email 2>/dev/null)"
        key="$(git config --file "$f" --get user.signingkey 2>/dev/null)"
        [[ -n "$email" && -n "$key" ]] || continue
        if grep -qF -- "$email namespaces=\"git\" $key" "$SIGNERS"; then
            t_pass "allowed_signers lists $email with its signing key"
        else
            t_fail "allowed_signers lists $email with its signing key" \
                "no line: $email namespaces=\"git\" $key"
        fi
    done
else
    t_fail "configs/git/allowed_signers exists" \
        "missing: signatures made with this config cannot be verified with it"
fi

# ── ssh signing round trip through this config ───────────────────────
# GIT_CONFIG_GLOBAL swaps the repo's file in for ~/.gitconfig and HOME
# points at scratch, so its ~/... includes resolve to nothing. Overrides:
# a throwaway key (a private-key PATH is a valid signingkey), ssh-keygen as
# the signer (the file names 1Password's op-ssh-sign, which is macOS-only),
# and a signers file naming that key. hooksPath is global in this config
# and would otherwise run this machine's lefthook shims.
if have ssh-keygen; then
    typeset kd="$T_SCRATCH/sigkey" repo="$T_SCRATCH/sigrepo" nohooks="$T_SCRATCH/nohooks"
    mkdir -p "$kd" "$repo" "$nohooks"
    ssh-keygen -q -t ed25519 -N '' -C probe -f "$kd/id" </dev/null
    print -r -- "probe@example.invalid namespaces=\"git\" $(cut -d' ' -f1,2 "$kd/id.pub")" > "$kd/signers"
    : > "$kd/nobody"
    g() {
        GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_NOSYSTEM=1 HOME="$kd" \
        git -c user.name=Probe -c user.email=probe@example.invalid \
            -c user.signingkey="$kd/id" -c gpg.ssh.program=ssh-keygen \
            -c gpg.ssh.allowedSignersFile="$kd/signers" \
            -c core.hooksPath="$nohooks" -c core.pager=cat "$@"
    }
    g init -q "$repo" 2>/dev/null
    if g -C "$repo" commit -q --allow-empty -m "sign probe" 2>"$T_SCRATCH/sign.err"; then
        t_pass "commit signs through the shipped config (commit.gpgsign, gpg.format=ssh)"
    else
        t_fail "commit signs through the shipped config (commit.gpgsign, gpg.format=ssh)" \
            "$(head -n 2 "$T_SCRATCH/sign.err")"
    fi
    if g -C "$repo" verify-commit HEAD >/dev/null 2>&1; then
        t_pass "signed commit verifies against an allowed_signers naming the key"
    else
        t_fail "signed commit verifies against an allowed_signers naming the key" \
            "$(g -C "$repo" verify-commit HEAD 2>&1 | head -n 2)"
    fi
    if g -C "$repo" -c gpg.ssh.allowedSignersFile="$kd/nobody" verify-commit HEAD >/dev/null 2>&1; then
        t_fail "verification fails against an allowed_signers without the key" "verified anyway"
    else
        t_pass "verification fails against an allowed_signers without the key"
    fi
else
    t_skip "ssh signing round trip" "ssh-keygen not in PATH"
fi

t_finish
