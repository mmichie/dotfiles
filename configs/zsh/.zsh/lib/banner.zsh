#!/bin/zsh

# BBS-style random login banner generator
# Uses toilet/figlet to render "INFLUX" in various fonts with
# programmatic decorations and ANSI color gradients

generate_login_banner() {
    local ESC=$'\033'
    local RESET="${ESC}[0m"

    # ── Taglines pool ────────────────────────────────────────────────
    local -a taglines=(
        "proudly serving the scene since 1993"
        "where the elstrEEt meet"
        "another fine release from the underground"
        "cracked by the best, spread by the rest"
        "quality not quantity"
        "the future is now, old man"
        "10 nodes / USR Courier V.Everything"
        "call our WHQ for the latest warez"
        "greets to all groups worldwide"
        "the underground never sleeps"
    )

    # ── Color palettes ───────────────────────────────────────────────
    # Each palette is a space-separated string of 256-color codes
    local -a palettes=(
        "213 212 177 141 105 99"    # hot pink -> purple
        "51 45 39 33 27 21"         # cyan -> blue
        "196 202 208 214 220 226"   # red -> yellow fire
        "46 47 48 49 50 51"         # green -> cyan matrix
        "255 252 249 246 243 240"   # white -> grey steel
        "198 199 164 129 93 57"     # magenta -> indigo
    )

    # ── Style definitions ────────────────────────────────────────────
    local -a style_names=(mono12 pagga future slant block doom)

    # Pick random style, palette, and tagline
    local style_idx=$(( RANDOM % ${#style_names[@]} + 1 ))
    local palette_idx=$(( RANDOM % ${#palettes[@]} + 1 ))
    local tag_idx=$(( RANDOM % ${#taglines[@]} + 1 ))

    local style="${style_names[$style_idx]}"
    local palette="${palettes[$palette_idx]}"
    local tagline="${taglines[$tag_idx]}"

    # Parse palette into array
    local -a colors=( ${=palette} )

    # ── Render the text ──────────────────────────────────────────────
    local rendered=""
    local render_cmd=""

    # Determine which tool to use
    if [[ "$style" == "mono12" || "$style" == "pagga" || "$style" == "future" ]]; then
        render_cmd="toilet"
    else
        render_cmd="figlet"
    fi

    # Check tool availability with fallback
    if ! command -v "$render_cmd" &>/dev/null; then
        if command -v figlet &>/dev/null; then
            render_cmd="figlet"
            style="slant"
        elif command -v toilet &>/dev/null; then
            render_cmd="toilet"
            style="mono12"
        else
            # Ultimate fallback: plain text
            printf '%s\n' ""
            printf '%s\n' "  ═══════════════════════════════════"
            printf '%s\n' "   I N F L U X   T E R M I N A L"
            printf '%s\n' "  ═══════════════════════════════════"
            printf '%s\n' "   ${tagline}"
            printf '%s\n' "   node: 4:920/35"
            printf '%s\n' ""
            return 0
        fi
    fi

    rendered=$("$render_cmd" -f "$style" "INFLUX" 2>/dev/null)
    if [[ -z "$rendered" ]]; then
        rendered=$("$render_cmd" "INFLUX" 2>/dev/null)
    fi

    # ── Measure rendered text width ──────────────────────────────────
    local max_width=0
    local line
    while IFS= read -r line; do
        local stripped="${line}"
        (( ${#stripped} > max_width )) && max_width=${#stripped}
    done <<< "$rendered"

    # Ensure minimum width for decorations
    (( max_width < 40 )) && max_width=40

    # ── Helper: apply color gradient to a line ───────────────────────
    # $1 = line text, $2 = color code
    _color_line() {
        printf '%s%s%s\n' "${ESC}[38;5;${2}m" "$1" "$RESET"
    }

    # ── Helper: build gradient bar ───────────────────────────────────
    # $1 = width, $2 = pattern (e.g. light-to-dark or dark-to-light)
    _gradient_bar() {
        local w=$1 direction=$2
        local bar=""
        local i
        if [[ "$direction" == "light" ]]; then
            # ░▒▓█ repeating
            for (( i=0; i<w; i++ )); do
                case $(( i % 4 )) in
                    0) bar+="░" ;; 1) bar+="▒" ;; 2) bar+="▓" ;; 3) bar+="█" ;;
                esac
            done
        elif [[ "$direction" == "dark" ]]; then
            # █▓▒░ repeating
            for (( i=0; i<w; i++ )); do
                case $(( i % 4 )) in
                    0) bar+="█" ;; 1) bar+="▓" ;; 2) bar+="▒" ;; 3) bar+="░" ;;
                esac
            done
        elif [[ "$direction" == "solid" ]]; then
            for (( i=0; i<w; i++ )); do bar+="█"; done
        elif [[ "$direction" == "thin" ]]; then
            for (( i=0; i<w; i++ )); do bar+="─"; done
        elif [[ "$direction" == "double" ]]; then
            for (( i=0; i<w; i++ )); do bar+="═"; done
        fi
        printf '%s' "$bar"
    }

    # ── Helper: pad string to width ──────────────────────────────────
    _pad_right() {
        local str="$1" target_width=$2
        local pad_len=$(( target_width - ${#str} ))
        (( pad_len < 0 )) && pad_len=0
        printf '%s%*s' "$str" "$pad_len" ""
    }

    # ── Helper: center string within width ─────────────────────────────
    _center() {
        local str="$1" target_width=$2
        local pad_total=$(( target_width - ${#str} ))
        (( pad_total < 0 )) && pad_total=0
        local pad_left=$(( pad_total / 2 ))
        local pad_right=$(( pad_total - pad_left ))
        printf '%*s%s%*s' "$pad_left" "" "$str" "$pad_right" ""
    }

    # ── Build output per style ───────────────────────────────────────
    local -a output_lines=()
    local total_width=$(( max_width + 4 ))  # padding for frames

    case "$style" in
        mono12)
            # Gradient ░▒▓ top/bottom bars
            local bar_top=$(_gradient_bar "$total_width" "light")
            local bar_bot=$(_gradient_bar "$total_width" "dark")
            output_lines+=("$bar_top")
            output_lines+=("")
            while IFS= read -r line; do
                output_lines+=("  $(_pad_right "$line" "$max_width")")
            done <<< "$rendered"
            output_lines+=("")
            output_lines+=("$bar_bot")
            ;;
        pagga)
            # Concentric gradient frame
            local outer=$(_gradient_bar "$total_width" "light")
            local inner=$(_gradient_bar $(( total_width - 4 )) "dark")
            output_lines+=("$outer")
            output_lines+=("█ ${inner} █")
            while IFS= read -r line; do
                output_lines+=("█ $(_center "$line" $(( total_width - 2 ))) █")
            done <<< "$rendered"
            output_lines+=("█ ${inner} █")
            output_lines+=("$outer")
            ;;
        future)
            # Minimal box-drawing decoration
            local hline=$(_gradient_bar $(( total_width - 2 )) "thin")
            output_lines+=("┌${hline}┐")
            output_lines+=("│$(_pad_right "" $(( total_width - 2 )))│")
            while IFS= read -r line; do
                output_lines+=("│$(_center "$line" $(( total_width - 2 )))│")
            done <<< "$rendered"
            output_lines+=("│$(_pad_right "" $(( total_width - 2 )))│")
            output_lines+=("└${hline}┘")
            ;;
        slant)
            # Asymmetric gradient sidebar
            output_lines+=("")
            while IFS= read -r line; do
                output_lines+=("  ▐ $(_pad_right "$line" "$max_width")")
            done <<< "$rendered"
            output_lines+=("  ▐ $(_gradient_bar "$max_width" "light")")
            output_lines+=("")
            ;;
        block)
            # Solid frame
            local dline=$(_gradient_bar $(( total_width - 2 )) "double")
            output_lines+=("╔${dline}╗")
            output_lines+=("║$(_pad_right "" $(( total_width - 2 )))║")
            while IFS= read -r line; do
                output_lines+=("║$(_center "$line" $(( total_width - 2 )))║")
            done <<< "$rendered"
            output_lines+=("║$(_pad_right "" $(( total_width - 2 )))║")
            output_lines+=("╚${dline}╝")
            ;;
        doom)
            # Shadow line underneath
            local shadow=""
            local i
            for (( i=0; i<total_width; i++ )); do shadow+="▄"; done
            output_lines+=("")
            while IFS= read -r line; do
                output_lines+=("  $(_pad_right "$line" "$max_width")")
            done <<< "$rendered"
            output_lines+=("  ${shadow}")
            output_lines+=("")
            ;;
    esac

    # ── Add tagline and node info ────────────────────────────────────
    output_lines+=("  ╔═─» [ Terminal Underground Division ] «─═╗")
    output_lines+=("  ║    [×] ${tagline} [×]")
    output_lines+=("  ╚════─» [ DISTRIBUTION NODE: 4:920/35 ] «─═══╝")

    # ── Print with color gradient ────────────────────────────────────
    local total_lines=${#output_lines[@]}
    local num_colors=${#colors[@]}
    local line_idx=0

    for line in "${output_lines[@]}"; do
        # Map line index to color index
        local color_idx=$(( line_idx * num_colors / total_lines + 1 ))
        (( color_idx > num_colors )) && color_idx=$num_colors
        (( color_idx < 1 )) && color_idx=1
        local color="${colors[$color_idx]}"

        printf '%s%s%s\n' "${ESC}[38;5;${color}m" "$line" "$RESET"
        (( line_idx++ ))
    done
}
