# dwm-chips: publishes the chips dwm's bar draws for a terminal
# (dwm/chips.diff), as _DWM_CHIPS on its st window: its directory, its git
# branch and status as chevron's prompt shows them, and an agent's state.
#
#   dwm-chips
#       a shell outside tmux: $PWD, on the window in $WINDOWID (st sets it)
#   dwm-chips --tmux SOCKET [PANE STATE]
#       every client of the tmux server at SOCKET that runs in an st: its
#       active pane's directory and @claude_state. PANE STATE stands in for
#       that pane's state: an agent hook runs before bin/bin/claude-tmux-state
#       records it.
#
# The zsh prompt (configs/zsh/.zsh/lib/60-prompt.zsh), tmux's focus hooks
# (configs/tmux/tmux.conf) and the agent hook (hosts/vm-aarch64/home.nix) run
# it in the background.

# chevron's git status marks (its src/segments/git.rs)
ahead=$'\xe2\xac\x86' behind=$'\xe2\xac\x87' staged=$'\xe2\x9c\x94'
modified=$'\xe2\x9c\x8e' conflicted=$'\xe2\x9c\xbc' stashed=$'\xe2\x9a\x91'

# chips DIR [STATE]: the property's value, tab-separated "kind|text" chips
chips() {
	local dir=$1 state=${2:-} out status line head='' oid='' text ab_a ab_b
	local -i a=0 b=0 s=0 m=0 u=0 c=0 st=0
	if [[ $dir == "$HOME" ]]; then
		out='dir|~'
	elif [[ $dir == / ]]; then
		out='dir|/'
	else
		out="dir|${dir##*/}"
	fi
	# --no-optional-locks: a status in the background never rewrites the
	# index, which would contend with git run by hand
	if status=$(git --no-optional-locks -C "$dir" status --porcelain=v2 --branch --show-stash 2>/dev/null); then
		while IFS= read -r line; do
			case $line in
			'# branch.oid '*) oid=${line#'# branch.oid '} ;;
			'# branch.head '*) head=${line#'# branch.head '} ;;
			'# branch.ab '*)
				read -r _ _ ab_a ab_b <<<"$line"
				a=${ab_a#+}
				b=${ab_b#-}
				;;
			'# stash '*) st=${line#'# stash '} ;;
			'1 '* | '2 '*)
				# XY: the index's status, then the worktree's; . is unchanged
				if [[ ${line:2:1} != . ]]; then s+=1; fi
				if [[ ${line:3:1} != . ]]; then m+=1; fi
				;;
			'u '*) c+=1 ;;
			'? '*) u+=1 ;;
			esac
		done <<<"$status"
		if [[ $head == '(detached)' ]]; then head=${oid:0:7}; fi
		text=$head
		if ((a)); then text+=" $a$ahead"; fi
		if ((b)); then text+=" $b$behind"; fi
		if ((s)); then text+=" $s$staged"; fi
		if ((m)); then text+=" $m$modified"; fi
		if ((u)); then text+=" $u+"; fi
		if ((c)); then text+=" $c$conflicted"; fi
		if ((st)); then text+=" $st$stashed"; fi
		out+=$'\t'"branch|$text"
	fi
	case $state in
	waiting) out+=$'\t''waiting|waiting on you' ;;
	working) out+=$'\t''working|working' ;;
	done) out+=$'\t''done|done' ;;
	esac
	printf '%s' "$out"
}

# publish WINDOW VALUE
publish() {
	xprop -id "$1" -f _DWM_CHIPS 8u -set _DWM_CHIPS "$2"
}

if [[ ${1:-} == --tmux ]]; then
	socket=$2 pane=${3:-} pstate=${4:-}
	while IFS=$'\t' read -r pid p dir state; do
		if [[ $p == "$pane" ]]; then state=$pstate; fi
		# the client's st window: st puts it in its child's environment,
		# and the client is that child (tmux-attach-or-new execs tmux)
		[[ -r /proc/$pid/environ ]] || continue
		win=''
		while IFS= read -r -d '' kv; do
			if [[ $kv == WINDOWID=* ]]; then win=${kv#WINDOWID=}; fi
		done <"/proc/$pid/environ"
		[[ -n $win ]] || continue
		publish "$win" "$(chips "$dir" "$state")" || true
	done < <(tmux -S "$socket" list-clients -F $'#{client_pid}\t#{pane_id}\t#{pane_current_path}\t#{@claude_state}')
elif [[ -n ${WINDOWID:-} ]]; then
	publish "$WINDOWID" "$(chips "$PWD")"
fi
