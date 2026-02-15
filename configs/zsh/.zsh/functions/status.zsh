#!/bin/zsh

# Create secure temp directory for status files
_STATUS_TEMP_DIR=""
_init_status_temp_dir() {
    if [[ -z "$_STATUS_TEMP_DIR" ]] || [[ ! -d "$_STATUS_TEMP_DIR" ]]; then
        _STATUS_TEMP_DIR=$(mktemp -d -t shell_status.XXXXXX)
        # Ensure cleanup on exit
        trap '_cleanup_status_temp_dir' EXIT
    fi
}

_cleanup_status_temp_dir() {
    if [[ -n "$_STATUS_TEMP_DIR" ]] && [[ -d "$_STATUS_TEMP_DIR" ]]; then
        rm -rf "$_STATUS_TEMP_DIR"
    fi
}

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

# Status check functions
check_new_mail() {
    _init_status_temp_dir
    if [[ -n "$(find /var/mail -type f -newer ~/.last_mail_check 2>/dev/null)" ]]; then
        echo -e "  ${yellow}New Mail:${reset} Yes ${red}(Action: Check your mail)${reset}" > "$_STATUS_TEMP_DIR/mail"
    else
        echo -e "  ${yellow}New Mail:${reset} No" > "$_STATUS_TEMP_DIR/mail"
    fi
}

check_ssh_agent() {
    _init_status_temp_dir
    if [[ -n "$SSH_AGENT_PID" ]]; then
        echo -e "  ${yellow}SSH Agent:${reset} Running (PID: $SSH_AGENT_PID)" > "$_STATUS_TEMP_DIR/ssh"
    else
        echo -e "  ${yellow}SSH Agent:${reset} Not Running ${red}(Action: Start SSH agent)${reset}" > "$_STATUS_TEMP_DIR/ssh"
    fi
}

check_fzf_setup() {
    _init_status_temp_dir
    if [[ -x "$HOME/bin/fzf" ]]; then
        echo -e "  ${yellow}fzf Setup:${reset} Properly Set Up" > "$_STATUS_TEMP_DIR/fzf"
    else
        echo -e "  ${yellow}fzf Setup:${reset} Not Set Up ${red}(Action: Install fzf)${reset}" > "$_STATUS_TEMP_DIR/fzf"
    fi
}

check_cron_job() {
    _init_status_temp_dir
    if crontab -l 2>/dev/null | grep -Fq "backup_shell_history"; then
        echo -e "  ${yellow}History Backup Cron:${reset} Exists" > "$_STATUS_TEMP_DIR/cron"
    else
        echo -e "  ${yellow}History Backup Cron:${reset} Not Found ${red}(Action: Set up backup cron job)${reset}" > "$_STATUS_TEMP_DIR/cron"
    fi
}
