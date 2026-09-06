#!/usr/bin/env zsh
# ssh client config (configs/ssh/config), evaluated with `ssh -G`, which
# resolves the effective options for a host without connecting. Pinned:
#   - the file parses under the installed ssh
#   - no password or keyboard-interactive authentication anywhere: with the
#     agent holding every key, a spoofed or compromised host can never
#     prompt for a password
#   - agent forwarding only on the named hosts, never by default
#   - every named host's key is pinned in known_hosts.pinned and that file is
#     read, so a first connection from a fresh machine cannot be answered by
#     an impostor; new keys still land in the regular known_hosts
#   - no account-specific literal path: the agent socket uses ~
#
# ssh expands ~ from the passwd entry, not $HOME, so a scratch HOME cannot
# isolate the evaluation; instead the config is copied with its `Include
# config.local` line removed, so a Linux host's own overrides (IdentityAgent,
# IdentitiesOnly) cannot leak into the assertions. The Include itself is
# asserted as text.

source "${0:A:h}/lib.zsh"

typeset SSHCONF="$REPO_ROOT/configs/ssh/config"
typeset PINNED="$REPO_ROOT/configs/ssh/known_hosts.pinned"

if ! have ssh; then
    t_skip "ssh config" "ssh not in PATH"
    t_finish
fi

typeset CONF="$T_SCRATCH/ssh_config"
sed '/^Include /d' "$SSHCONF" > "$CONF"
chmod 600 "$CONF"

# sg <host> <option>: effective value of option for host (lowercased keys).
sg() {
    ssh -F "$CONF" -G "$1" 2>/dev/null \
        | awk -v k="$2" '$1 == k { $1 = ""; sub(/^ /, ""); print; exit }'
}

typeset -a named_hosts
named_hosts=(${${(M)${(f)"$(<$SSHCONF)"}:#Host *}#Host })
named_hosts=(${named_hosts:#\*})

if ssh -F "$CONF" -G example.invalid >/dev/null 2>&1; then
    t_pass "configs/ssh/config parses"
else
    t_fail "configs/ssh/config parses" "$(ssh -F "$CONF" -G example.invalid 2>&1 | head -n 2)"
fi
if grep -q '^Include config.local$' "$SSHCONF"; then
    t_pass "Include config.local is present (Linux agent overrides)"
else
    t_fail "Include config.local is present (Linux agent overrides)" "missing"
fi
assert_eq "$(grep -c '/Users/' "$SSHCONF")" "0" "no account-specific literal path (/Users/...) in the config"

# ── Authentication: keys only, everywhere ────────────────────────────
typeset h
for h in "${named_hosts[@]}" example.invalid; do
    assert_eq "$(sg "$h" passwordauthentication)" "no" "$h: password authentication off"
    assert_eq "$(sg "$h" kbdinteractiveauthentication)" "no" "$h: keyboard-interactive authentication off"
    assert_eq "$(sg "$h" identitiesonly)" "yes" "$h: IdentitiesOnly (only the configured key is offered)"
done

# ── Agent forwarding: named hosts only ───────────────────────────────
assert_eq "$(sg example.invalid forwardagent)" "no" "unnamed host: no agent forwarding by default"
assert_eq "$(sg wintermute forwardagent)" "yes"     "wintermute: agent forwarding on (git over ssh from the box)"
assert_eq "$(sg vm forwardagent)" "no"              "vm: no agent forwarding"

# ── Host key pinning ─────────────────────────────────────────────────
typeset -a ukhf
ukhf=(${=$(sg wintermute userknownhostsfile)})
if (( ${ukhf[(I)*/.ssh/known_hosts.pinned]} )); then
    t_pass "known_hosts.pinned is read for host keys"
else
    t_fail "known_hosts.pinned is read for host keys" "UserKnownHostsFile: ${ukhf[*]}"
fi
if [[ "${ukhf[1]}" == */.ssh/known_hosts ]]; then
    t_pass "new host keys still go to the regular known_hosts (first file listed)"
else
    t_fail "new host keys still go to the regular known_hosts (first file listed)" "first: ${ukhf[1]:-none}"
fi
if [[ -f "$PINNED" ]]; then
    if have ssh-keygen; then
        if ssh-keygen -l -f "$PINNED" >/dev/null 2>&1; then
            t_pass "known_hosts.pinned parses (ssh-keygen -l)"
        else
            t_fail "known_hosts.pinned parses (ssh-keygen -l)" "$(ssh-keygen -l -f "$PINNED" 2>&1 | head -n 1)"
        fi
    fi
    typeset hn
    for h in "${named_hosts[@]}"; do
        hn="$(sg "$h" hostname)"
        # Field match, not a regex on the line: the hostname field may be a
        # comma-separated list, and the key type is the second field.
        if awk -v h="$hn" '{ n = split($1, a, ","); for (k = 1; k <= n; k++) if (a[k] == h && $2 == "ssh-ed25519") found = 1 } END { exit !found }' "$PINNED"; then
            t_pass "$h ($hn) has a pinned ed25519 host key"
        else
            t_fail "$h ($hn) has a pinned ed25519 host key" "no entry for $hn"
        fi
    done
else
    t_fail "configs/ssh/known_hosts.pinned exists" "missing: first connections are trust-on-first-use"
fi

# ── Agent socket resolves under the same home ssh uses for ~ ─────────
typeset pwdir="${ukhf[1]%/.ssh/known_hosts}"
assert_eq "$(sg wintermute identityagent)" \
    "$pwdir/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" \
    "IdentityAgent resolves to the 1Password socket under ~"

t_finish
