#!/bin/zsh

# Platform-specific notification functions
notify_mac() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\""
}

notify_linux() {
    local title="$1"
    local message="$2"
    notify-send "$title" "$message"
}

notify_windows() {
    local title="$1"
    local message="$2"
    powershell -Command "& {Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('$message', '$title')}"
}

notify_cross_platform() {
    local title="$1"
    local message="$2"
    if command -v zenity &> /dev/null; then
        zenity --info --title="$title" --text="$message"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        notify_mac "$title" "$message"
    elif command -v notify-send &> /dev/null; then
        notify_linux "$title" "$message"
    elif command -v powershell &> /dev/null; then
        notify_windows "$title" "$message"
    else
        echo "Notification not supported on this OS."
    fi
}

get_gum_path() {
    local gum_path

    # First check if gum exists in PATH
    if command -v gum >/dev/null 2>&1; then
        gum_path=$(command -v gum)
    # Then check Homebrew location on macOS
    elif [[ -x "/opt/homebrew/bin/gum" ]]; then
        gum_path="/opt/homebrew/bin/gum"
    # Finally check common Linux location
    elif [[ -x "/usr/bin/gum" ]]; then
        gum_path="/usr/bin/gum"
    else
        echo ""
        return 1
    fi

    echo "$gum_path"
}

# Status check functions
check_new_mail() {
    if [[ -n "$(find /var/mail -type f -newer ~/.last_mail_check 2>/dev/null)" ]]; then
        echo -e "  ${yellow}New Mail:${reset} Yes ${red}(Action: Check your mail)${reset}" > /tmp/shell_status_mail
    else
        echo -e "  ${yellow}New Mail:${reset} No" > /tmp/shell_status_mail
    fi
}

check_ssh_agent() {
    if [[ -n "$SSH_AGENT_PID" ]]; then
        echo -e "  ${yellow}SSH Agent:${reset} Running (PID: $SSH_AGENT_PID)" > /tmp/shell_status_ssh
    else
        echo -e "  ${yellow}SSH Agent:${reset} Not Running ${red}(Action: Start SSH agent)${reset}" > /tmp/shell_status_ssh
    fi
}

check_fzf_setup() {
    if [[ -x "$HOME/bin/fzf" ]]; then
        echo -e "  ${yellow}fzf Setup:${reset} Properly Set Up" > /tmp/shell_status_fzf
    else
        echo -e "  ${yellow}fzf Setup:${reset} Not Set Up ${red}(Action: Install fzf)${reset}" > /tmp/shell_status_fzf
    fi
}

check_cron_job() {
    if crontab -l 2>/dev/null | grep -Fq "backup_shell_history"; then
        echo -e "  ${yellow}History Backup Cron:${reset} Exists" > /tmp/shell_status_cron
    else
        echo -e "  ${yellow}History Backup Cron:${reset} Not Found ${red}(Action: Set up backup cron job)${reset}" > /tmp/shell_status_cron
    fi
}
