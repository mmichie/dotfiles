#!/usr/bin/env zsh
# Self-test for tests/coverage.zsh against a small fixture config, so the
# report can be checked line by line. What it pins:
#   - all three ways the trap gets into a shell: rc files (an interactive
#     boot under env -i), `zsh -f script`, and `zsh -fc string`
#   - lines that run under a stderr redirect, in a subshell and inside a
#     command substitution are reported (xtrace lost the first of these)
#   - an autoloaded function file's lines are mapped back past its leading
#     comments, and a nested function defined at run time keeps its file
#   - the classifier leaves closers, array elements and continuation lines
#     out of the count, including a group's `} | cmd` line and an empty case
#     arm, neither of which the trap can ever report
# The whole run takes well under a second: no sandbox boots of the real
# config are involved.

source "${0:A:h}/lib.zsh"

# Under `just coverage` this file is traced too. The inner run must find the
# real zsh, not the outer run's shim.
if [[ -n "$ZSH_TEST_COVERAGE" ]]; then
    path=(${path:#$ZSH_TEST_COVERAGE/bin})
    unset ZSH_TEST_COVERAGE
fi

typeset fix="$T_SCRATCH/fixture" driver="$T_SCRATCH/driver.zsh" inner="$T_SCRATCH/inner.zsh"
mkdir -p "$fix/.zsh/lib" "$fix/.zsh/functions"

# Line numbers matter below; keep the fixtures as they are.
cat > "$fix/.zshrc" <<'EOF'
if [[ -n "$FIXTURE_FLAG" ]]; then
    typeset -g fixture_flag_branch=1
else
    typeset -g fixture_else_branch=1
fi
source "$HOME/.zsh/lib/10-mod.zsh"
EOF
cat > "$fix/.zsh/lib/10-mod.zsh" <<'EOF'
typeset -ga fixture_list=(
    one
    two
)
mod_fn() {
    local in_mod=1
    lazy_fn() {
        local in_lazy=1
    }
    print -r -- "long" \
        "statement" >/dev/null
}
never_called() {
    local never=1
}
mod_fn
EOF
cat > "$fix/.zsh/lib/20-cdoor.zsh" <<'EOF'
typeset -g only_the_c_string_sources_this=1
EOF
cat > "$fix/.zsh/functions/outer" <<'EOF'
# An autoloaded function with leading comments,
# so its opening line is not line 1.
outer() {
    local a=1
    if [[ "$1" == x ]]; then
        local never_branch=1
    fi
    ( local in_subshell=1 )
    local captured=$(
        print -r -- inside
    )
}
EOF
cat > "$fix/.zsh/functions/unused" <<'EOF'
unused() {
    print -r -- "never loaded"
}
EOF
# Every line of shapes runs. Two of them are statement-shaped but can never
# be reported: the trap reports the piped group at its `{` line, and the
# empty `other) ;;` arm runs no command at all.
cat > "$fix/.zsh/functions/shapes" <<'EOF'
shapes() {
    local piped=''
    {
        print -r -- in-group
    } | read -r piped
    case "$piped" in
        other) ;;
        in-group) local matched=1 ;;
    esac
}
EOF

# The traced "suite": one shell per door.
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz outer shapes
outer 2>/dev/null
shapes
EOF
cat > "$driver" <<EOF
source ${(q)T_LIB_DIR}/lib.zsh
env -i HOME=${(q)fix} PATH="\$PATH" zsh --no-globalrcs -i -c lazy_fn </dev/null
zsh --no-globalrcs -f ${(q)inner} ${(q)fix}
zsh --no-globalrcs -fc 'source "\$1/.zsh/lib/20-cdoor.zsh"' zsh ${(q)fix}
EOF

typeset out='' row=''
typeset -a words never
out=$(COVERAGE_CONF="$fix" zsh --no-globalrcs "$T_LIB_DIR/coverage.zsh" --uncovered \
    -- zsh --no-globalrcs "$driver" 2>&1)
assert_eq "$?" 0 "coverage run of the fixture succeeds"

# row <file>: "<lines> <run>" from the report table
row() {
    words=(${=${(M)${(f)out}:#$1 *}[1]})
    print -r -- "${words[2]} ${words[3]}"
}
assert_eq "$(row .zshrc)" "4 3" \
    "rc-file door: an interactive boot under env -i reports its .zshrc (the if branch is the one line missed)"
assert_eq "$(row .zsh/lib/10-mod.zsh)" "9 8" \
    "sourced module: array elements, closers and the continuation line are not counted"
assert_eq "$(row .zsh/lib/20-cdoor.zsh)" "1 1" \
    "-c door: a file only a zsh -fc string sources is reported"
assert_eq "$(row .zsh/functions/outer)" "6 5" \
    "script door: an autoloaded function called with 2>/dev/null is reported, subshell and substitution included"
assert_eq "$(row .zsh/functions/unused)" "1 0" "a function file nothing loads counts as not run"
assert_eq "$(row .zsh/functions/shapes)" "5 5" \
    "a group's \`} | cmd\` line and an empty case arm are not counted (the trap can never report them)"
assert_eq "$(row total)" "26 22" "totals add up"

# The never-ran list names exactly the dead lines, by their real file lines:
# outer's line 6 sits 3 lines into the function and 6 into the file.
never=(${${(M)${(f)out}:#.z*:<->:*}%:*})
never=(${never%:})
assert_eq "${(j:,:)never}" ".zshrc:2,.zsh/lib/10-mod.zsh:14,.zsh/functions/outer:6,.zsh/functions/unused:2" \
    "the never-ran list is the four dead lines, autoload offset applied"

# --uncovered takes file-name filters.
out=$(COVERAGE_CONF="$fix" zsh --no-globalrcs "$T_LIB_DIR/coverage.zsh" --uncovered outer \
    -- zsh --no-globalrcs "$driver" 2>&1)
never=(${${(M)${(f)out}:#.z*:<->:*}%:*})
assert_eq "${(j:,:)never%:}" ".zsh/functions/outer:6" "--uncovered NAME lists only the matching files"

# A command that fails still gets its report, and the run says so.
print -r -- 'exit 3' >> "$driver"
out=$(COVERAGE_CONF="$fix" zsh --no-globalrcs "$T_LIB_DIR/coverage.zsh" -- zsh --no-globalrcs "$driver" 2>&1)
assert_eq "$?" 1 "a failing traced command fails the coverage run"
assert_contains "$out" "exited 3" "and the report says why its figures may be low"

t_finish
