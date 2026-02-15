use git2::{Repository, StatusOptions, StatusShow};
use std::env;
use std::fmt::Write as FmtWrite;

// Powerline characters
const ARROW: &str = "\u{E0B0}";
const THIN: &str = "\u{E0B1}";
const BRANCH_ICON: &str = "\u{E0A0}";

// ANSI color helpers
fn fg(color: u8) -> String {
    format!("\x1b[38;5;{}m", color)
}

fn bg(color: u8) -> String {
    format!("\x1b[48;5;{}m", color)
}

const RST: &str = "\x1b[0m";

fn render_path() {
    let home = env::var("HOME").unwrap_or_default();
    let pwd = env::current_dir()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();

    // Replace HOME with ~
    let path = if pwd.starts_with(&home) {
        format!("~{}", &pwd[home.len()..])
    } else {
        pwd
    };

    // Split into components
    let mut parts: Vec<&str> = path.split('/').filter(|s| !s.is_empty()).collect();

    // Handle root /
    if parts.is_empty() {
        parts = vec!["/"];
    }

    // Truncate to 5 components
    let n = parts.len();
    let truncated;
    let parts = if n > 5 {
        truncated = [&["…"][..], &parts[n - 4..]].concat();
        &truncated
    } else {
        &parts
    };
    let n = parts.len();

    let mut out = String::with_capacity(256);

    if n <= 1 {
        // Single component: hostname(238) -> cwd(31), then transition to 237
        let _ = write!(
            out,
            "{}{}{} {}{} {}{}{}",
            fg(238), bg(31), ARROW,
            fg(15), parts.first().unwrap_or(&""),
            fg(31), bg(237), ARROW
        );
    } else {
        // First component on bg:31 (blue)
        let _ = write!(
            out,
            "{}{}{} {}{} {}{}{}",
            fg(238), bg(31), ARROW,
            fg(15), parts[0],
            fg(31), bg(237), ARROW
        );

        // Remaining components on bg:237
        for i in 1..n {
            if i > 1 {
                let _ = write!(out, " {}{}", fg(245), THIN);
            }
            let _ = write!(out, " {}{}", fg(254), parts[i]);
        }
        let _ = write!(out, " ");
    }

    print!("{}", out);
}

fn render_git() {
    let mut repo = match Repository::discover(".") {
        Ok(r) => r,
        Err(_) => return,
    };

    // Get branch name
    let branch = if repo.head_detached().unwrap_or(false) {
        repo.head()
            .ok()
            .and_then(|h| h.peel_to_commit().ok())
            .map(|c| c.id().to_string()[..7].to_string())
            .unwrap_or_else(|| "HEAD".to_string())
    } else {
        repo.head()
            .ok()
            .and_then(|h| h.shorthand().map(|s| s.to_string()))
            .unwrap_or_else(|| "HEAD".to_string())
    };

    // Get file status counts
    let mut staged = 0u32;
    let mut modified = 0u32;
    let mut untracked = 0u32;
    let mut conflicted = 0u32;

    let mut opts = StatusOptions::new();
    opts.show(StatusShow::IndexAndWorkdir);
    opts.include_untracked(true);

    if let Ok(statuses) = repo.statuses(Some(&mut opts)) {
        for entry in statuses.iter() {
            let s = entry.status();
            if s.is_conflicted() {
                conflicted += 1;
            } else {
                if s.is_index_new()
                    || s.is_index_modified()
                    || s.is_index_deleted()
                    || s.is_index_renamed()
                    || s.is_index_typechange()
                {
                    staged += 1;
                }
                if s.is_wt_modified() || s.is_wt_deleted() || s.is_wt_typechange() {
                    modified += 1;
                }
                if s.is_wt_new() {
                    untracked += 1;
                }
            }
        }
    }

    // Ahead/behind
    let (ahead, behind) = get_ahead_behind(&repo);

    // Stash count
    let mut stashed = 0u32;
    let _ = repo.stash_foreach(|_, _, _| {
        stashed += 1;
        true
    });

    // Git state
    let state = match repo.state() {
        git2::RepositoryState::Rebase
        | git2::RepositoryState::RebaseInteractive
        | git2::RepositoryState::RebaseMerge => Some("REBASING"),
        git2::RepositoryState::Merge => Some("MERGING"),
        git2::RepositoryState::CherryPick | git2::RepositoryState::CherryPickSequence => {
            Some("CHERRY")
        }
        git2::RepositoryState::Bisect => Some("BISECT"),
        _ => None,
    };

    // Determine if dirty
    let dirty = staged + modified + untracked + conflicted + stashed + ahead + behind > 0
        || state.is_some();

    let mut out = String::with_capacity(512);

    if dirty {
        // Pink branch: arrow from path(237) to 161
        let _ = write!(
            out,
            "{}{}{} {}{} {} ",
            fg(237), bg(161), ARROW,
            fg(15), BRANCH_ICON, branch
        );
        let mut prev: u8 = 161;

        // Git state
        if let Some(st) = state {
            let _ = write!(
                out,
                "{}{}{} {}{} ",
                fg(prev), bg(220), ARROW,
                fg(0), st
            );
            prev = 220;
        }

        // Status segments: (bg_color, text)
        let mut segs: Vec<(u8, String)> = Vec::new();
        if ahead > 0 {
            segs.push((240, format!("{}⬆", ahead)));
        }
        if behind > 0 {
            segs.push((240, format!("{}⬇", behind)));
        }
        if staged > 0 {
            segs.push((22, format!("{}✔", staged)));
        }
        if modified > 0 {
            segs.push((130, format!("{}✎", modified)));
        }
        if untracked > 0 {
            segs.push((52, format!("{}+", untracked)));
        }
        if conflicted > 0 {
            segs.push((9, format!("{}✼", conflicted)));
        }
        if stashed > 0 {
            segs.push((20, format!("{}⚑", stashed)));
        }

        for (seg_bg, seg_text) in &segs {
            let _ = write!(
                out,
                "{}{}{} {}{} ",
                fg(prev), bg(*seg_bg), ARROW,
                fg(15), seg_text
            );
            prev = *seg_bg;
        }

        // Final arrow to terminal bg (236)
        let _ = write!(out, "{}{}{}{}", fg(prev), bg(236), ARROW, RST);
    } else {
        // Green branch (clean): arrow from path(237) to 148
        let _ = write!(
            out,
            "{}{}{} {}{} {} {}{}{}{}",
            fg(237), bg(148), ARROW,
            fg(0), BRANCH_ICON, branch,
            fg(148), bg(236), ARROW, RST
        );
    }

    print!("{}", out);
}

fn get_ahead_behind(repo: &Repository) -> (u32, u32) {
    let head = match repo.head() {
        Ok(h) => h,
        Err(_) => return (0, 0),
    };

    let local_oid = match head.target() {
        Some(oid) => oid,
        None => return (0, 0),
    };

    // Get upstream
    let branch_name = match head.shorthand() {
        Some(name) => name.to_string(),
        None => return (0, 0),
    };

    let branch = match repo.find_branch(&branch_name, git2::BranchType::Local) {
        Ok(b) => b,
        Err(_) => return (0, 0),
    };

    let upstream = match branch.upstream() {
        Ok(u) => u,
        Err(_) => return (0, 0),
    };

    let upstream_oid = match upstream.get().target() {
        Some(oid) => oid,
        None => return (0, 0),
    };

    repo.graph_ahead_behind(local_oid, upstream_oid)
        .map(|(a, b)| (a as u32, b as u32))
        .unwrap_or((0, 0))
}

// Font Awesome pencil icon
const PENCIL_ICON: &str = "\u{F040}";

fn render_tmux_title() {
    let home = env::var("HOME").unwrap_or_default();
    let pwd = env::current_dir()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();

    // Home directory
    if pwd == home {
        println!("\u{1F3E0} ~");
        return;
    }

    let dir_name = std::path::Path::new(&pwd)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| pwd.clone());

    // Try to open git repo
    let repo = match Repository::discover(".") {
        Ok(r) => r,
        Err(_) => {
            println!("\u{1F4C1} {}", dir_name);
            return;
        }
    };

    // Get branch name
    let branch = if repo.head_detached().unwrap_or(false) {
        repo.head()
            .ok()
            .and_then(|h| h.peel_to_commit().ok())
            .map(|c| c.id().to_string()[..7].to_string())
            .unwrap_or_else(|| "HEAD".to_string())
    } else {
        repo.head()
            .ok()
            .and_then(|h| h.shorthand().map(|s| s.to_string()))
            .unwrap_or_else(|| "HEAD".to_string())
    };

    // Get repo name from workdir
    let repo_name = repo
        .workdir()
        .and_then(|p| p.file_name())
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| dir_name);

    // Check if dirty (any status entries = dirty)
    let mut opts = StatusOptions::new();
    opts.show(StatusShow::IndexAndWorkdir);
    opts.include_untracked(true);

    let dirty = repo
        .statuses(Some(&mut opts))
        .map(|statuses| !statuses.is_empty())
        .unwrap_or(false);

    if dirty {
        println!(
            "#[fg=colour67]{}#[default] {} {} #[fg=colour245]{}#[default]",
            BRANCH_ICON, repo_name, branch, PENCIL_ICON
        );
    } else {
        println!(
            "#[fg=colour39]{}#[default] {} {}",
            BRANCH_ICON, repo_name, branch
        );
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    match args.get(1).map(|s| s.as_str()) {
        Some("path") => render_path(),
        Some("git") => render_git(),
        Some("tmux-title") => render_tmux_title(),
        _ => {
            eprintln!("Usage: starship-segments <path|git|tmux-title>");
            std::process::exit(1);
        }
    }
}
