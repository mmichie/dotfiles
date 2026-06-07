#!/usr/bin/env zsh
# sops/age secret-hygiene invariants — the static half of the 2026-06
# security audit, as a permanent regression gate. Pure JSON/grep parsing of
# the committed envelopes; no sops/age binary or private key required, so it
# runs anywhere (CI, nix sandbox).

source "${0:A:h}/lib.zsh"

typeset SOPS_YAML="$REPO_ROOT/.sops.yaml"
typeset -a secret_files
secret_files=("$REPO_ROOT"/secrets/*(N.))

if (( ${#secret_files} == 0 )); then
    t_skip "sops secrets" "no secrets/ files"
    t_finish
fi

# Expected recipient policy, read from .sops.yaml (not hardcoded): the full
# keyset, and the work-only key. New machines added to .sops.yaml flow in
# automatically; the only coupling is the work-only filename below.
typeset -a all_keys
all_keys=(${(f)"$(grep -oE 'age1[0-9a-z]{58,}' "$SOPS_YAML" | sort -u)"})
typeset moab_key
moab_key=$(grep -oE '&mim_moab age1[0-9a-z]+' "$SOPS_YAML" | awk '{print $2}')
typeset WORK_ONLY="zshrc-work-local"   # matches the work creation_rule in .sops.yaml

assert_eq "${#all_keys}" "3" "sops.yaml declares the expected recipient count"

# Per-file checks via one python pass (envelope shape + recipients + nonces).
typeset report
report=$(python3 - "$WORK_ONLY" "$moab_key" "${(j:,:)all_keys}" "${secret_files[@]}" <<'PY'
import json, base64, sys
work_only, moab_key, all_keys_csv = sys.argv[1], sys.argv[2], sys.argv[3]
all_keys = set(all_keys_csv.split(','))
files = sys.argv[4:]
ivs, ephem = [], []

def deramor_shares(enc):
    body = "".join(l for l in enc.splitlines() if l and not l.startswith('-----'))
    raw = base64.b64decode(body)
    head = raw.split(b'\n--- ', 1)[0].decode('latin1')
    return [ln.split()[2] for ln in head.splitlines() if ln.startswith('-> X25519 ')]

for path in files:
    name = path.rsplit('/', 1)[-1]
    try:
        d = json.load(open(path))
    except Exception as e:
        print(f"FAIL {name} not-json {e}"); continue
    s = d.get('sops', {})
    enc_ok = isinstance(d.get('data'), str) and d['data'].startswith('ENC[')
    print(f"{'OK' if enc_ok else 'FAIL'} {name} encrypted")
    recips = {a.get('recipient', '') for a in s.get('age', [])}
    expected = {moab_key} if name == work_only else all_keys
    print(f"{'OK' if recips == expected else 'FAIL'} {name} recipients "
          f"(got {len(recips)} want {len(expected)})")
    # collect nonces + ephemeral shares for the global uniqueness check
    import re
    for m in re.finditer(r'ENC\[AES256_GCM,([^\]]*)\]', json.dumps(d)):
        kv = dict(p.split(':', 1) for p in m.group(1).split(',') if ':' in p)
        if 'iv' in kv: ivs.append(kv['iv'])
    for a in s.get('age', []):
        ephem += deramor_shares(a['enc'])

def uniq(label, vals):
    print(f"{'OK' if len(set(vals)) == len(vals) else 'FAIL'} {label} "
          f"({len(vals)} total {len(set(vals))} unique)")
uniq("nonce-unique", ivs)
uniq("ephemeral-unique", ephem)
PY
)

typeset line
for line in ${(f)report}; do
    if [[ "$line" == OK* ]]; then
        t_pass "${line#OK }"
    else
        t_fail "${line#FAIL }" "$line"
    fi
done

t_finish
