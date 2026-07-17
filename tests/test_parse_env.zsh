#!/usr/bin/env zsh
# Unit tests for _parse_env_file (lib/10-environment.zsh).
#
# Regression: the key pattern was a ksh-ism (`*(...)`) that silently dropped
# single-character keys and let invalid names through to a failing `export`.

source "${0:A:h}/lib.zsh"

typeset fixture="$T_SCRATCH/fixture.env"
cat > "$fixture" <<'EOF'
A=1
FOO=bar
FOO-BAR=nope
NOT A VALID LINE
# COMMENT=ignored
B2=ok
DQ="hello world"
SQ='single'
EMPTY=
TRAIL=keep=this
EOF
# CRLF lines appended as raw bytes (a heredoc cannot carry a literal \r):
# a .env written on Windows must load with the \r stripped, not exported
# into values.
printf 'CRLF=windows\r\nCRLFQ="quoted value"\r\n' >> "$fixture"

# Inner script: source platform -> options -> environment (same order as
# .zshrc, so EXTENDED_GLOB is on), parse the fixture, dump results.
typeset inner="$T_SCRATCH/parse_env_inner.zsh"
cat > "$inner" <<'EOF'
zsh_conf="$1" fixture="$2"
source "$zsh_conf/.zsh/lib/00-platform.zsh"
source "$zsh_conf/.zsh/lib/05-options.zsh"
source "$zsh_conf/.zsh/lib/10-environment.zsh"
_parse_env_file "$fixture" 1
print -r -- "RC=$?"
print -r -- "A=${A-unset}"
print -r -- "FOO=${FOO-unset}"
print -r -- "B2=${B2-unset}"
print -r -- "DQ=${DQ-unset}"
print -r -- "SQ=${SQ-unset}"
print -r -- "EMPTY=${EMPTY-unset}"
print -r -- "TRAIL=${TRAIL-unset}"
print -r -- "CRLF_LEN=${#CRLF}"
print -r -- "CRLFQ_LEN=${#CRLFQ}"
print -r -- "MISSING_RC=$(_parse_env_file /nonexistent/file; print -rn -- $?)"
EOF

typeset sb out
sb="$(make_sandbox_home)"
out=$(HOME="$sb" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$fixture" 2>&1)

assert_contains "$out" $'\nA=1'         "single-char key loads (regression)"
assert_contains "$out" "Loaded: A"      "verbose mode reports single-char key"
assert_contains "$out" "FOO=bar"        "plain key=value loads"
assert_contains "$out" "B2=ok"          "alphanumeric key loads"
assert_contains "$out" "DQ=hello world" "matching double quotes stripped"
assert_contains "$out" "SQ=single"      "matching single quotes stripped"
assert_contains "$out" $'\nEMPTY='      "empty value allowed"
assert_contains "$out" "TRAIL=keep=this" "value may contain ="
assert_contains "$out" "RC=0"           "parse returns 0"
assert_contains "$out" "MISSING_RC=1"   "missing file returns 1"
assert_contains "$out" "CRLF_LEN=7"     "CRLF line loads without the trailing \\r (len of 'windows')"
assert_contains "$out" "CRLFQ_LEN=12"   "CRLF + quotes: \\r stripped before quote stripping"

assert_not_contains "$out" "Loaded: FOO-BAR"   "invalid key name skipped (regression)"
assert_not_contains "$out" "not valid"         "no export errors from invalid keys"
assert_not_contains "$out" "COMMENT"           "comments ignored"
assert_not_contains "$out" "NOT A VALID LINE"  "garbage lines ignored"

t_finish
