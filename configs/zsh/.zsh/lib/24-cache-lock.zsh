#!/bin/zsh

# Keep source, wordcode, and dependency metadata in one transaction. Readers
# participate too: atomic replacement of one file cannot protect the set.
# Persistent lock files must never be unlinked (waiters lock the same inode).
# fcntl locks are released by the kernel on process death, with no stale-PID
# cleanup. Default close-on-exec prevents external tools retaining the fd.
_with_cache_lock() {
    local cache="$1"; shift
    local lock_file="${cache:h}/.cache-lock-${cache:t}" lock_fd
    zmodload zsh/system 2>/dev/null || return 75
    # `command true` invokes the PATH binary in zsh (~2-3ms per lock).
    # The explicit builtin remains alias-immune without a fork/exec.
    { builtin true >> "$lock_file" } 2>/dev/null || return 75
    zsystem flock -t 5 -i 0.02 -f lock_fd "$lock_file" 2>/dev/null || return 75
    {
        "$@"
    } always {
        zsystem flock -u "$lock_fd"
    }
}
