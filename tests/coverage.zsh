#!/usr/bin/env zsh
# Line coverage of the zsh config under the test suite (`just coverage`).
#
# zsh ships no coverage tool. This script makes every zsh the suite starts
# report the file and line of each command it runs, runs the suite once, and
# prints which lines of configs/zsh ran.
#
# Usage: zsh tests/coverage.zsh [--uncovered [name ...]] [--keep | --reuse dir]
#                               [-- command ...]
#   --uncovered     also list the lines that never ran: for every file, or
#                   only for files whose path contains one of the names
#   --keep          keep the work directory (run.log, raw records, the shim)
#   --reuse dir     report from a kept work directory without running again
#   -- command ...  trace this instead of the suite
# COVERAGE_CONF=dir reports on another config tree.
#
# How it works:
#   - tests/lib.zsh puts $ZSH_TEST_COVERAGE/bin first on each test file's
#     PATH. The zsh there is a shim that starts the real zsh with a
#     TRAPDEBUG function installed. The trap fires before every command and
#     appends "file:line caller:line" to a private file descriptor.
#   - Why a trap and not xtrace: xtrace writes to whatever stderr is at that
#     moment. Code running inside `fn 2>/dev/null` went untraced, and a test
#     that captures stderr captured the trace with it. The trap's descriptor
#     is its own, so redirections cannot hide a line and the tests see
#     exactly the output they see without coverage. A trap FUNCTION, because
#     zsh drops `trap ... DEBUG` strings in subshells and keeps functions.
#   - Getting the trap into every shell takes three doors, because nothing
#     is sourced by all of them. Shells that read rc files get it from a
#     .zshenv in a ZDOTDIR the shim points them at; it puts ZDOTDIR back
#     before anything else runs, so zsh finds the real rc files. `zsh -f
#     script` is run as a stub that installs the trap and sources the script.
#     `zsh -c string` gets the install prepended to the string.
#   - Sourced files report absolute lines. An autoloaded function file
#     reports lines counted from the function's opening line; the two line
#     numbers in a record agree only in that case, and the report adds the
#     offset back.
#   - "Lines" are lines where a statement starts, which is what the trap
#     reports (`a && b` over two lines is one statement). Comments, blanks,
#     closers (fi, done, }, ;;), function headers, case patterns, heredoc
#     bodies and the continuation lines of multi-line statements and arrays
#     are left out by a classifier written for this config's style. It is
#     not a parser, so the percentages are approximate. A line the trap
#     reported always counts, whatever the classifier thought of it.
#
# Not named test_*.zsh: it runs the whole suite with a trap on every
# command, so it stays out of run.zsh, the pre-commit hook and CI.

emulate -R zsh
setopt extended_glob

typeset ROOT="${0:A:h}"
typeset CONF="${COVERAGE_CONF:-${ROOT:h}/configs/zsh}"
typeset -i want_uncovered=0 keep=0
typeset -a only cmd
typeset work=''
while (( $# )); do
    case "$1" in
        (--uncovered) want_uncovered=1 ;;
        (--keep)      keep=1 ;;
        (--reuse)
            shift
            work="$1"
            if [[ ! -d "$work/raw" ]]; then
                print -ru2 -- "coverage: --reuse needs a directory kept by --keep"
                exit 2
            fi ;;
        (--)          shift; cmd=("$@"); break ;;
        (-h|--help)
            print -r -- "usage: zsh tests/coverage.zsh [--uncovered [name ...]] [--keep | --reuse dir] [-- command ...]"
            exit 0 ;;
        (-*)          print -ru2 -- "coverage: unknown option: $1"; exit 2 ;;
        (*)           only+=("$1") ;;
    esac
    shift
done
(( ${#cmd} )) || cmd=(zsh --no-globalrcs "$ROOT/run.zsh")

typeset -i run_rc=0

# Write the trap, its three doors and the shim into $work, then run the
# command with them in place. Heredoc bodies are the generated files.
trace_run() {
    local real_zsh="${commands[zsh]}"
    if [[ -z "$real_zsh" ]]; then
        print -ru2 -- "coverage: zsh must be on PATH"
        return 1
    fi
    local qwork="${(q)work}" qzsh="${(q)real_zsh}"
    mkdir -p "$work/bin" "$work/raw" "$work/zdot"

    # The trap. Sourced first thing in every traced shell, sometimes twice
    # (rc file, then -c string), hence the guard. The path test keeps
    # compinit's tens of thousands of commands per cold boot out of the
    # record: everything under test lives below a dot-z name (.zshrc,
    # .zshenv, .zprofile, .zsh/). The record file is named per process,
    # since which numbering a function file uses is a per-process fact.
    cat > "$work/install.zsh" <<EOF
if (( \${+__COV_ZDOTDIR_SET} )); then
    if (( __COV_ZDOTDIR_SET )); then
        export ZDOTDIR="\$__COV_ZDOTDIR"
    else
        unset ZDOTDIR
    fi
    unset __COV_ZDOTDIR_SET __COV_ZDOTDIR
fi
if (( ! \${+functions[TRAPDEBUG]} )); then
    zmodload zsh/parameter
    exec {__cov_fd}>>$qwork/raw/\$\$.\$RANDOM\$RANDOM
    TRAPDEBUG() {
        [[ "\$funcfiletrace[1]" == */.z* ]] \\
            && print -ru \$__cov_fd -- "\$funcfiletrace[1] \$functrace[1]" 2>/dev/null
        return 0
    }
fi
EOF

    # The rc-file door. zsh looks ZDOTDIR up again for each later startup
    # file, so restoring it (install.zsh does) sends it back to the real ones.
    cat > "$work/zdot/.zshenv" <<EOF
source $qwork/install.zsh
[[ -f "\${ZDOTDIR:-\$HOME}/.zshenv" ]] && source "\${ZDOTDIR:-\$HOME}/.zshenv"
EOF

    # The script door. A sourced file sees its own name in \$0 and the
    # arguments after it in \$@, as the script would have.
    cat > "$work/run-script.zsh" <<EOF
source $qwork/install.zsh
__cov_script="\$1"
shift
source "\$__cov_script" "\$@"
EOF

    # The shim. Absolute paths throughout: sandboxed shells run it under
    # env -i. It walks zsh's own options to the first operand, which is the
    # command string when a -c was among them and the script otherwise; -n
    # (syntax check only) is left alone. exec -a keeps the name callers use,
    # which is what \$0 shows in a -c shell. (Not a symlink to the real zsh
    # under another name: zsh reads its own name, and one that starts with r
    # starts a restricted shell.)
    cat > "$work/bin/zsh" <<EOF
#!$real_zsh -f
# Generated by tests/coverage.zsh; see that script for what this does.
typeset -a args=("\$@")
typeset a='' norm=''
integer i=1 has_c=0 no_exec=0
while (( i <= \$#args )); do
    a="\$args[i]"
    case "\$a" in
        (-|--|-b|+b) (( i++ )); break ;;
        (--*)
            norm="\${\${a#--}:l}"
            [[ "\${norm//[-_]/}" == noexec ]] && no_exec=1
            ;;
        ([-+]*)
            [[ "\$a" == -*c* ]] && has_c=1
            [[ "\$a" == -*n* ]] && no_exec=1
            [[ "\$a" == *o ]] && (( i++ ))
            ;;
        (*) break ;;
    esac
    (( i++ ))
done
(( no_exec )) && exec -a zsh $qzsh "\$@"
if (( i <= \$#args )); then
    if (( has_c )); then
        args[i]="source $qwork/install.zsh"\$'\\n'"\$args[i]"
    else
        args[i,i-1]=($qwork/run-script.zsh)
    fi
fi
export __COV_ZDOTDIR_SET=\${+ZDOTDIR} __COV_ZDOTDIR="\$ZDOTDIR"
export ZDOTDIR=$qwork/zdot
exec -a zsh $qzsh "\${args[@]}"
EOF
    chmod +x "$work/bin/zsh"

    # The trap makes every shell heavier, so the run is given more room:
    #   - a longer per-file timeout;
    #   - half the CPUs' worth of test files at a time instead of all of
    #     them. With all 28 at once, a 100 ms "did it hang" probe in the
    #     suite failed one traced run in four;
    #   - no exported REPORTTIME: traced boots burn enough CPU to trip it,
    #     and its timing block lands in stderr the tests assert on.
    local -i ncpu=${$(getconf _NPROCESSORS_ONLN 2>/dev/null):-2}
    unset REPORTTIME
    print -r -- "coverage: tracing ${cmd[*]}"
    ZSH_TEST_COVERAGE="$work" TEST_TIMEOUT="${TEST_TIMEOUT:-600}" \
        TEST_JOBS="${TEST_JOBS:-$(( ncpu > 3 ? ncpu / 2 : 1 ))}" \
        "${cmd[@]}" > "$work/run.log" 2>&1
    run_rc=$?
    print -r -- $run_rc > "$work/run.rc"
}

if [[ -n "$work" ]]; then
    run_rc=$(<"$work/run.rc")
else
    work="$(mktemp -d "${${TMPDIR:-/tmp}%/}/zsh-coverage.XXXXXXXX")" || exit 1
    if (( keep )); then
        print -r -- "coverage: keeping $work (run.log, raw/, the shim)"
    else
        trap 'rm -rf "$work"' EXIT
    fi
    trace_run || exit 1
fi

# ── Collect hits ──────────────────────────────────────────────────────
# One pass per record file decides, per function file, whether that process
# autoloaded it (R: relative lines) or sourced it (A: absolute). hit keys are
# "<path relative to CONF>:<line>".
typeset -A hit opening
typeset f='' rel='' mode='' line='' base=''
typeset -i n=0 lineno=0
typeset -a raw
raw=("$work"/raw/*(N))
if (( ${#raw} )); then
    awk -v own="$work/" '
        function flush(   k, part) {
            for (k in hit) {
                split(k, part, "\t")
                print part[1] "\t" ((part[1] in autoloaded) ? "R" : "A") "\t" part[2]
            }
            split("", hit)
            split("", autoloaded)
        }
        FNR == 1 && NR > 1 { flush() }
        {
            if (index($1, own) == 1 || !match($1, /:[0-9]+$/)) next
            file = substr($1, 1, RSTART - 1)
            num = substr($1, RSTART + 1)
            if (!(match(file, /\/\.zsh\/(lib|functions)\/[^\/]+$/) ||
                  match(file, /\/\.(zshrc|zshenv|zprofile)$/))) next
            rel = substr(file, RSTART + 1)
            hit[rel "\t" num] = 1
            if (rel ~ /^\.zsh\/functions\// && match($2, /:[0-9]+$/)) {
                base = rel
                sub(/.*\//, "", base)
                if (substr($2, 1, RSTART - 1) == base && substr($2, RSTART + 1) == num)
                    autoloaded[rel] = 1
            }
        }
        END { flush() }
    ' "${raw[@]}" | sort -u > "$work/hits"
    while IFS=$'\t' read -r rel mode lineno; do
        if [[ "$mode" == R ]]; then
            if (( ! ${+opening[$rel]} )); then
                opening[$rel]=0
                base="${rel:t}"
                n=0
                while IFS= read -r line; do
                    (( n++ ))
                    if [[ "$line" == "$base"\(\)* ]]; then
                        opening[$rel]=$n
                        break
                    fi
                done < "$CONF/$rel"
            fi
            (( lineno += opening[$rel] ))
        fi
        hit[$rel:$lineno]=1
    done < "$work/hits"
fi
if (( ${#hit} == 0 )); then
    print -ru2 -- "coverage: no config line was reported. Does the command reach tests/lib.zsh?"
    tail -5 "$work/run.log" >&2
    exit 1
fi

# ── Which lines can the trap report? ──────────────────────────────────
# Prints the line numbers of $1 where a statement starts. See the header for
# what this is and is not.
coverable_lines() {
    local line='' code='' c='' heredoc=''
    local -i n=0 depth=0 cont=0 was_cont=0 opens=0 closes=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        (( n++ ))
        code="${line##[[:space:]]#}"
        if [[ -n "$heredoc" ]]; then
            [[ "$code" == "$heredoc" ]] && heredoc=''
            continue
        fi
        if [[ -z "$code" || "$code" == \#* ]]; then
            continue
        fi
        # Inside a multi-line array literal: elements, not statements.
        if (( depth > 0 )); then
            opens=${#${code//[^\(]/}} closes=${#${code//[^\)]/}}
            (( depth += opens - closes ))
            (( depth < 0 )) && depth=0
            continue
        fi
        # A statement runs on past a backslash-newline, and past a line that
        # ends in a list or pipe operator.
        c="${code%%[[:space:]]##\#*}"
        was_cont=$cont
        cont=0
        [[ "$line" == *\\ || "$c" == *(\||\&\&) ]] && cont=1
        (( was_cont )) && continue
        case "$c" in
            (\{|\}|\(|\)|fi|done|esac|else|then|do|\;\;|\;\&|'} always {') continue ;;
        esac
        # A closer followed only by redirections or a background marker.
        [[ "$c" == (\}|\)|fi|done|esac)[[:space:]]##[\<\>\&0-9]* && "$c" != *(\||\&\&|\;)* ]] && continue
        # A function header whose body starts on the next line.
        [[ "$c" == [^[:space:]\(\)]##\(\)[[:space:]]#[\{\(] ]] && continue
        [[ "$c" == function[[:space:]]##[^\{]##\{ ]] && continue
        # A case pattern on a line of its own.
        [[ "$c" == [^\(]##\) ]] && continue
        if [[ "$c" == *=\(* ]]; then
            opens=${#${c//[^\(]/}} closes=${#${c//[^\)]/}}
            (( opens > closes )) && depth=$(( opens - closes ))
        fi
        if [[ "$c" != *\<\<\<* && "$c" == (#b)*\<\<(-|)([\'\"]|)([A-Za-z_][A-Za-z0-9_]#)* ]]; then
            heredoc="$match[3]"
        fi
        print -r -- $n
    done < "$1"
}

# ── Report ────────────────────────────────────────────────────────────
typeset -a files lines missing uncovered_report
typeset -i total=0 covered=0 file_total=0 file_covered=0 want=0
typeset -A coverable
files=("$CONF"/.zshenv(N) "$CONF"/.zprofile(N) "$CONF"/.zshrc(N)
       "$CONF"/.zsh/lib/*.zsh(N) "$CONF"/.zsh/functions/*(N.))
print
printf '%-36s %6s %6s %7s\n' file lines run '%'
for f in "${files[@]}"; do
    rel="${f#$CONF/}"
    coverable=()
    for lineno in $(coverable_lines "$f"); do
        coverable[$lineno]=1
    done
    # A reported line is coverable by definition.
    for line in ${(k)hit[(I)$rel:*]}; do
        coverable[${line##*:}]=1
    done
    file_total=${#coverable}
    file_covered=0
    missing=()
    for lineno in ${(kn)coverable}; do
        if (( ${+hit[$rel:$lineno]} )); then
            (( file_covered++ ))
        else
            missing+=($lineno)
        fi
    done
    (( total += file_total, covered += file_covered ))
    printf '%-36s %6d %6d %6.1f%%\n' "$rel" $file_total $file_covered \
        $(( file_total ? 100.0 * file_covered / file_total : 100.0 ))
    want=$(( ${#only} == 0 ))
    for base in "${only[@]}"; do
        [[ "$rel" == *"$base"* ]] && want=1
    done
    if (( want_uncovered && want && ${#missing} )); then
        lines=("${(@f)$(<"$f")}")
        for lineno in $missing; do
            uncovered_report+=("$rel:$lineno: ${lines[lineno]##[[:space:]]#}")
        done
    fi
done
printf '%-36s %6d %6d %6.1f%%\n' total $total $covered $(( total ? 100.0 * covered / total : 0.0 ))

if (( want_uncovered )); then
    print
    print -r -- "lines that never ran:"
    print -rl -- "${uncovered_report[@]:-  (none)}"
fi

# A failing run still yields a report, but it may have stopped short.
if (( run_rc != 0 )); then
    print
    print -r -- "coverage: the traced command exited $run_rc, so the figures may be low:"
    grep -E '^[[:space:]]*not ok|^FAIL' "$work/run.log" | head -20
    exit 1
fi
