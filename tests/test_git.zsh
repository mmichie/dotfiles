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
#   - identity is per tree and never guessed: no global user.*, ~/src gets
#     the personal identity by includeIf with the work trees overriding it,
#     and useConfigOnly refuses a commit anywhere unmatched
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

# ── Identity: per tree, never guessed ────────────────────────────────
# No global user.*; ~/src/ gets the personal identity via includeIf, the
# work trees after it override, and useConfigOnly turns a commit anywhere
# unmatched into "no email was given" instead of a silent user@host guess.
# Include order is precedence: the personal default must come first.
typeset PERSONAL="$REPO_ROOT/configs/git/.gitconfig-personal"
typeset KYUSU="$REPO_ROOT/configs/git/.gitconfig-kyusu-local"
assert_eq "$(gc --get user.useConfigOnly 2>/dev/null)" "true" "user.useConfigOnly = true"
typeset -a global_ident
global_ident=(${(f)"$(gc --get-regexp '^user\.(name|email|signingkey)$' 2>/dev/null)"})
if (( ${#global_ident} == 0 )); then
    t_pass "no global user.name/email/signingkey (identity comes from includes)"
else
    t_fail "no global user.name/email/signingkey (identity comes from includes)" "${(j: | :)global_ident}"
fi
typeset -a incl
incl=(${(f)"$(gc --get-regexp '^includeif\.gitdir:.*\.path$' 2>/dev/null)"})
if [[ "${incl[1]}" == 'includeif.gitdir:~/src/.path ~/.gitconfig-personal' ]]; then
    t_pass "first includeIf is the personal default for ~/src/"
else
    t_fail "first includeIf is the personal default for ~/src/" "first: ${incl[1]:-none}"
fi
if [[ -f "$PERSONAL" ]]; then
    t_pass "configs/git/.gitconfig-personal exists"
else
    t_fail "configs/git/.gitconfig-personal exists" "missing"
fi

# Behavioral: a scratch HOME laid out like the real one. HOME is realpath'd
# (:A) because includeIf compares the pattern's expanded ~ against the
# discovered .git path, and macOS's /var -> /private/var symlink would
# otherwise defeat the match. env -i: a GIT_AUTHOR_EMAIL or
# GIT_COMMITTER_EMAIL inherited from the caller counts as a configured
# identity and would mask useConfigOnly.
typeset H="${T_SCRATCH:A}/identhome"
mkdir -p "$H/src/personal" "$H/src/moab/core" "$H/elsewhere" "$H/nohooks"
[[ -f "$PERSONAL" ]] && cp "$PERSONAL" "$H/.gitconfig-personal"
cp "$KYUSU" "$H/.gitconfig-kyusu-local"
gi() {
    env -i PATH="$PATH" HOME="$H" GIT_CONFIG_GLOBAL="$GITCONF" GIT_CONFIG_NOSYSTEM=1 \
        git -c commit.gpgsign=false -c core.hooksPath="$H/nohooks" "$@"
}
typeset d
for d in src/personal src/moab/core elsewhere; do gi init -q "$H/$d" 2>/dev/null; done
assert_eq "$(gi -C "$H/src/personal" config --get user.email 2>/dev/null)" "mmichie@gmail.com" \
    "a ~/src tree resolves the personal identity"
assert_eq "$(gi -C "$H/src/moab/core" config --get user.email 2>/dev/null)" "matt@trymoab.com" \
    "a ~/src/moab tree resolves the work identity"
assert_eq "$(gi -C "$H/src/moab/core" config --get user.signingkey 2>/dev/null)" \
    "$(git config --file "$KYUSU" --get user.signingkey)" "the work tree signs with the work key"
assert_eq "$(gi -C "$H/elsewhere" config --get user.email 2>/dev/null)" "" "an unmatched tree has no identity"
if gi -C "$H/src/personal" commit -q --allow-empty -m probe 2>/dev/null; then
    t_pass "commit in a ~/src tree succeeds on the included identity"
else
    t_fail "commit in a ~/src tree succeeds on the included identity" \
        "$(gi -C "$H/src/personal" commit -q --allow-empty -m probe 2>&1 | head -n 1)"
fi
typeset ident_err=''
ident_err="$(gi -C "$H/elsewhere" commit -q --allow-empty -m probe 2>&1)"
typeset -i ident_rc=$?
if (( ident_rc != 0 )) && [[ "$ident_err" == *"auto-detection is disabled"* ]]; then
    t_pass "commit in an unmatched tree is refused (useConfigOnly)"
else
    t_fail "commit in an unmatched tree is refused (useConfigOnly)" "rc=$ident_rc: ${ident_err//$'\n'/ | }"
fi

# ── Every signing identity is verifiable with the shipped signers ────
typeset f email key
if [[ -f "$SIGNERS" ]]; then
    for f in "$GITCONF" "$PERSONAL" "$KYUSU"; do
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
