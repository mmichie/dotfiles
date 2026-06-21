//! obliviate — make Chrome forget a domain, completely.
//!
//! Chrome's history is a SQLite database. Removing a domain means finding the
//! matching `urls` rows and cascading by hand through every table that
//! references them (visits, search terms, segments, downloads, Journeys
//! clustering), because Chrome does not declare foreign keys.
//!
//! Domain matching parses each stored URL with a real URL parser and compares
//! the host — `example.com` matches `example.com` and any subdomain, but never
//! `notexample.com` or `example.com.evil.com`.

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{anyhow, bail, Context, Result};
use clap::Parser;
use rusqlite::{Connection, OpenFlags, OptionalExtension, TransactionBehavior};
use url::Url;

/// Delete all Chrome history (and downloads) for a given domain.
#[derive(Parser, Debug)]
#[command(name = "obliviate", version, about)]
struct Cli {
    /// Domain to purge, e.g. example.com (also matches *.example.com)
    domain: String,

    /// Chrome profile directory name (under the user-data dir)
    #[arg(long, default_value = "Default")]
    profile: String,

    /// Override the Chrome user-data dir (the parent of the profile dirs)
    #[arg(long)]
    user_data_dir: Option<PathBuf>,

    /// Point directly at a History sqlite file (ignores --profile/--user-data-dir)
    #[arg(long)]
    history: Option<PathBuf>,

    /// Preview what would be deleted, then exit without changing anything
    #[arg(long)]
    dry_run: bool,

    /// Skip the confirmation prompt
    #[arg(short, long)]
    yes: bool,

    /// Do not write a backup copy of the History file first
    #[arg(long)]
    no_backup: bool,

    /// Do not VACUUM the database after deleting
    #[arg(long)]
    no_vacuum: bool,
}

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {e:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    let domain = normalize_domain(&cli.domain)?;
    let history = resolve_history_path(&cli)?;

    if !history.exists() {
        bail!(
            "no History database at {}\n  (try --profile <name>, --user-data-dir <path>, or --history <file>)",
            history.display()
        );
    }

    println!("profile history : {}", history.display());
    println!("target domain   : {domain}  (+ subdomains)\n");

    let mut conn = Connection::open_with_flags(&history, OpenFlags::SQLITE_OPEN_READ_WRITE)
        .with_context(|| format!("opening {}", history.display()))?;
    conn.busy_timeout(Duration::from_secs(5))?;

    // Build connection-scoped scratch tables of the ids we intend to remove.
    build_scratch_tables(&conn, &domain)?;

    let ops = delete_ops();
    let history_counts = count_matches(&conn, &ops)?;

    // The omnibox/new-tab suggestion databases sit alongside History in the
    // same profile dir; each is a single table with a destination-URL column.
    let profile_dir = history.parent().unwrap_or_else(|| Path::new("."));
    let mut satellites: Vec<(&'static Satellite, PathBuf, usize)> = Vec::new();
    for s in SATELLITES {
        let path = profile_dir.join(s.file);
        match scan_satellite(&path, s, &domain) {
            Ok(Some(n)) => satellites.push((s, path, n)),
            Ok(None) => {}
            Err(e) => eprintln!("warning: could not read {} ({e}); skipping in preview", s.file),
        }
    }

    print_preview(&history_counts, &ops, &satellites);

    let history_total: usize = history_counts.values().sum();
    let sat_total: usize = satellites.iter().map(|(_, _, n)| *n).sum();
    if history_total == 0 && sat_total == 0 {
        println!("\nnothing matches {domain}; no changes made.");
        return Ok(());
    }
    if cli.dry_run {
        println!("\ndry run: no changes made.");
        return Ok(());
    }

    println!("\nQuit Google Chrome completely first, or the databases will be locked.");
    if !cli.yes && !confirm(&format!("Delete these rows for {domain}? [y/N] "))? {
        println!("aborted; no changes made.");
        return Ok(());
    }

    let mut removed = 0usize;

    if history_total > 0 {
        println!("\nHistory:");
        if !cli.no_backup {
            announce_backup(&history)?;
        }
        // Fold any write-ahead log into the main file before mutating.
        let _ = conn.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);");
        let deleted = execute_deletes(&mut conn, &ops, &history)?;
        if !cli.no_vacuum {
            if let Err(e) = conn.execute_batch("VACUUM;") {
                eprintln!("warning: VACUUM failed on History ({e}); freed space not reclaimed");
            }
        }
        removed += deleted.values().sum::<usize>();
    }
    drop(conn);

    for (s, path, _) in &satellites {
        match prune_satellite(path, s, &domain, cli.no_backup, cli.no_vacuum) {
            Ok(n) => removed += n,
            Err(e) => eprintln!("warning: {} ({e:#})", s.file),
        }
    }

    println!("\ndone: removed {removed} rows for {domain}.");
    Ok(())
}

/// One table to clean, with the predicate selecting the doomed rows.
struct Op {
    table: &'static str,
    where_clause: &'static str,
}

/// Deletions in child-before-parent order so no row outlives something that
/// references it. Tables absent in a given Chrome version are skipped.
fn delete_ops() -> Vec<Op> {
    const BY_VISIT: &str = "visit_id IN (SELECT id FROM _prune_visits)";
    const BY_URL: &str = "url_id IN (SELECT id FROM _prune_urls)";
    vec![
        // Journeys / history-clustering annotations keyed off visit id.
        Op { table: "content_annotations", where_clause: BY_VISIT },
        Op { table: "context_annotations", where_clause: BY_VISIT },
        Op { table: "clusters_and_visits", where_clause: BY_VISIT },
        // Core visit graph.
        Op { table: "visit_source", where_clause: "id IN (SELECT id FROM _prune_visits)" },
        Op { table: "visits", where_clause: "id IN (SELECT id FROM _prune_visits)" },
        Op { table: "keyword_search_terms", where_clause: BY_URL },
        Op {
            table: "segment_usage",
            where_clause: "segment_id IN (SELECT id FROM segments WHERE url_id IN (SELECT id FROM _prune_urls))",
        },
        Op { table: "segments", where_clause: BY_URL },
        // Downloads (independent of the urls table).
        Op { table: "downloads_slices", where_clause: "download_id IN (SELECT id FROM _prune_downloads)" },
        Op { table: "downloads_url_chains", where_clause: "id IN (SELECT id FROM _prune_downloads)" },
        Op { table: "downloads", where_clause: "id IN (SELECT id FROM _prune_downloads)" },
        // Parent last.
        Op { table: "urls", where_clause: "id IN (SELECT id FROM _prune_urls)" },
    ]
}

/// Populate `_prune_urls`, `_prune_visits`, and `_prune_downloads` with the ids
/// whose host matches `domain`. Host comparison happens in Rust, not in SQL,
/// so a domain in a path or query string never causes a false match.
fn build_scratch_tables(conn: &Connection, domain: &str) -> Result<()> {
    conn.execute_batch(
        "CREATE TEMP TABLE _prune_urls(id INTEGER PRIMARY KEY);
         CREATE TEMP TABLE _prune_visits(id INTEGER PRIMARY KEY);
         CREATE TEMP TABLE _prune_downloads(id INTEGER PRIMARY KEY);",
    )?;

    let url_ids = matching_ids(conn, "SELECT id, url FROM urls", domain)?;
    insert_ids(conn, "_prune_urls", &url_ids)?;

    conn.execute_batch(
        "INSERT INTO _prune_visits(id)
           SELECT id FROM visits WHERE url IN (SELECT id FROM _prune_urls);",
    )?;

    // A download matches if any URL in its redirect chain — or the tab it came
    // from — is on the domain.
    let mut downloads: BTreeSet<i64> = BTreeSet::new();
    if table_exists(conn, "downloads_url_chains")? {
        for id in matching_ids(conn, "SELECT id, url FROM downloads_url_chains", domain)? {
            downloads.insert(id);
        }
    }
    if table_exists(conn, "downloads")? {
        for id in matching_ids(conn, "SELECT id, tab_url FROM downloads", domain)? {
            downloads.insert(id);
        }
    }
    let downloads: Vec<i64> = downloads.into_iter().collect();
    insert_ids(conn, "_prune_downloads", &downloads)?;

    Ok(())
}

/// Run `sql` (which must yield `(id, url)` pairs) and return the ids whose URL
/// host matches `domain`.
fn matching_ids(conn: &Connection, sql: &str, domain: &str) -> Result<Vec<i64>> {
    let mut stmt = conn.prepare(sql)?;
    let rows = stmt.query_map([], |r| {
        Ok((r.get::<_, i64>(0)?, r.get::<_, Option<String>>(1)?))
    })?;
    let mut ids = Vec::new();
    for row in rows {
        let (id, maybe_url) = row?;
        let Some(raw) = maybe_url else { continue };
        if let Ok(parsed) = Url::parse(&raw) {
            if let Some(host) = parsed.host_str() {
                if host_matches(host, domain) {
                    ids.push(id);
                }
            }
        }
    }
    Ok(ids)
}

fn insert_ids(conn: &Connection, table: &str, ids: &[i64]) -> Result<()> {
    if ids.is_empty() {
        return Ok(());
    }
    let mut stmt = conn.prepare(&format!("INSERT OR IGNORE INTO {table}(id) VALUES (?1)"))?;
    for id in ids {
        stmt.execute([id])?;
    }
    Ok(())
}

/// Count, per existing table, how many rows the predicate would remove.
fn count_matches(conn: &Connection, ops: &[Op]) -> Result<BTreeMap<String, usize>> {
    let mut out = BTreeMap::new();
    for op in ops {
        if !table_exists(conn, op.table)? {
            continue;
        }
        let sql = format!("SELECT COUNT(*) FROM {} WHERE {}", op.table, op.where_clause);
        let n: i64 = conn.query_row(&sql, [], |r| r.get(0))?;
        out.insert(op.table.to_string(), n as usize);
    }
    Ok(out)
}

/// Execute the deletes inside one IMMEDIATE transaction so a locked database
/// (Chrome still running) fails fast and nothing is partially removed.
fn execute_deletes(
    conn: &mut Connection,
    ops: &[Op],
    history: &Path,
) -> Result<BTreeMap<String, usize>> {
    let tx = conn
        .transaction_with_behavior(TransactionBehavior::Immediate)
        .map_err(|e| busy_hint(e, history))?;
    let mut deleted = BTreeMap::new();
    for op in ops {
        if !table_exists(&tx, op.table)? {
            continue;
        }
        let n = tx.execute(&format!("DELETE FROM {} WHERE {}", op.table, op.where_clause), [])?;
        deleted.insert(op.table.to_string(), n);
    }
    tx.commit()?;
    Ok(deleted)
}

fn print_preview(
    history: &BTreeMap<String, usize>,
    ops: &[Op],
    satellites: &[(&'static Satellite, PathBuf, usize)],
) {
    println!("rows matched in History:");
    for op in ops {
        if let Some(n) = history.get(op.table) {
            println!("  {:<26} {:>8}", op.table, n);
        }
    }
    if !satellites.is_empty() {
        println!("rows matched in suggestion databases:");
        for (s, _, n) in satellites {
            println!("  {:<26} {:>8}", s.file, n);
        }
    }
}

/// A standalone suggestion database: one table with one destination-URL column.
/// These feed omnibox autocomplete and the new-tab page, and are separate files
/// from History.
struct Satellite {
    file: &'static str,
    table: &'static str,
    url_col: &'static str,
}

const SATELLITES: &[Satellite] = &[
    Satellite { file: "Shortcuts", table: "omni_box_shortcuts", url_col: "url" },
    Satellite { file: "Network Action Predictor", table: "network_action_predictor", url_col: "url" },
    Satellite { file: "Top Sites", table: "top_sites", url_col: "url" },
];

/// Read-only preview: how many rows in this suggestion DB match the domain.
/// Returns `None` when the file or its table is absent (nothing to do).
fn scan_satellite(path: &Path, s: &Satellite, domain: &str) -> Result<Option<usize>> {
    if !path.exists() {
        return Ok(None);
    }
    let conn = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY)
        .with_context(|| format!("opening {}", path.display()))?;
    conn.busy_timeout(Duration::from_secs(5))?;
    if !table_exists(&conn, s.table)? {
        return Ok(None);
    }
    let (count, _) = scan_url_column(&conn, s.table, s.url_col, domain)?;
    Ok(Some(count))
}

/// Delete the matching rows from one suggestion DB. Re-scans with Chrome closed
/// so the deletion reflects the authoritative current state, then backs up,
/// deletes inside an IMMEDIATE transaction, and vacuums.
fn prune_satellite(
    path: &Path,
    s: &Satellite,
    domain: &str,
    no_backup: bool,
    no_vacuum: bool,
) -> Result<usize> {
    let mut conn = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_WRITE)
        .with_context(|| format!("opening {}", path.display()))?;
    conn.busy_timeout(Duration::from_secs(5))?;
    if !table_exists(&conn, s.table)? {
        return Ok(0);
    }
    let (_, urls) = scan_url_column(&conn, s.table, s.url_col, domain)?;
    if urls.is_empty() {
        return Ok(0);
    }

    println!("\n{}:", s.file);
    if !no_backup {
        announce_backup(path)?;
    }

    let tx = conn
        .transaction_with_behavior(TransactionBehavior::Immediate)
        .map_err(|e| busy_hint(e, path))?;
    let mut removed = 0usize;
    {
        let mut stmt = tx.prepare(&format!("DELETE FROM {} WHERE {} = ?1", s.table, s.url_col))?;
        for u in &urls {
            removed += stmt.execute([u])?;
        }
    }
    tx.commit()?;

    if !no_vacuum {
        let _ = conn.execute_batch("VACUUM;");
    }
    println!("removed {removed} rows from {}", s.table);
    Ok(removed)
}

/// Scan a table that holds URLs in `url_col`, returning how many rows match the
/// domain and the distinct matching URL strings (for the DELETE). Matching
/// parses each URL and compares the host, never the raw string.
fn scan_url_column(
    conn: &Connection,
    table: &str,
    url_col: &str,
    domain: &str,
) -> Result<(usize, Vec<String>)> {
    let mut stmt = conn.prepare(&format!("SELECT {url_col} FROM {table}"))?;
    let rows = stmt.query_map([], |r| r.get::<_, Option<String>>(0))?;
    let mut count = 0usize;
    let mut urls: BTreeSet<String> = BTreeSet::new();
    for row in rows {
        let Some(raw) = row? else { continue };
        if let Ok(parsed) = Url::parse(&raw) {
            if let Some(host) = parsed.host_str() {
                if host_matches(host, domain) {
                    count += 1;
                    urls.insert(raw);
                }
            }
        }
    }
    Ok((count, urls.into_iter().collect()))
}

/// Copy a database file (plus any `-wal`/`-shm` sidecars) and print the backup
/// path and the command to restore it.
fn announce_backup(path: &Path) -> Result<()> {
    let backups = backup_files(path)?;
    for b in &backups {
        println!("backup          : {}", b.display());
    }
    if let Some(main) = backups.first() {
        println!("restore with    : cp \"{}\" \"{}\"", main.display(), path.display());
    }
    Ok(())
}

fn confirm(prompt: &str) -> Result<bool> {
    print!("{prompt}");
    io::stdout().flush()?;
    let mut line = String::new();
    io::stdin().read_line(&mut line)?;
    Ok(matches!(line.trim().to_ascii_lowercase().as_str(), "y" | "yes"))
}

/// Copy the History file and any WAL/SHM sidecars next to the originals,
/// returning the paths written (the main file first).
fn backup_files(history: &Path) -> Result<Vec<PathBuf>> {
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let mut made = Vec::new();
    for suffix in ["", "-wal", "-shm"] {
        let src = sidecar(history, suffix);
        if src.exists() {
            let dst = sidecar(history, &format!("{suffix}.prune-backup-{ts}"));
            fs::copy(&src, &dst).with_context(|| format!("backing up {}", src.display()))?;
            made.push(dst);
        }
    }
    Ok(made)
}

/// `History` + `-wal` => `History-wal`, etc., preserving the full filename.
fn sidecar(history: &Path, suffix: &str) -> PathBuf {
    if suffix.is_empty() {
        return history.to_path_buf();
    }
    let mut name = history.as_os_str().to_os_string();
    name.push(suffix);
    PathBuf::from(name)
}

fn table_exists(conn: &Connection, name: &str) -> Result<bool> {
    Ok(conn
        .query_row(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1",
            [name],
            |_| Ok(()),
        )
        .optional()?
        .is_some())
}

fn busy_hint(e: rusqlite::Error, history: &Path) -> anyhow::Error {
    let msg = e.to_string().to_lowercase();
    if msg.contains("lock") || msg.contains("busy") {
        anyhow!(
            "database is locked: {}\n  Quit Google Chrome completely and try again.",
            history.display()
        )
    } else {
        anyhow::Error::new(e)
    }
}

/// Normalize user input to a bare lowercase host. Accepts a bare domain, a full
/// URL, or `host:port`.
fn normalize_domain(input: &str) -> Result<String> {
    let trimmed = input.trim().trim_end_matches('.').to_ascii_lowercase();
    if trimmed.is_empty() {
        bail!("empty domain");
    }
    if let Ok(u) = Url::parse(&trimmed) {
        if let Some(host) = u.host_str() {
            return Ok(host.trim_end_matches('.').to_ascii_lowercase());
        }
    }
    let host = trimmed.split('/').next().unwrap_or(&trimmed);
    let host = host.rsplit('@').next().unwrap_or(host); // drop any user:pass@
    let host = host.split(':').next().unwrap_or(host); // drop :port
    if host.is_empty() {
        bail!("could not parse a host out of '{input}'");
    }
    Ok(host.to_string())
}

/// True when `host` is `domain` itself or a subdomain of it.
fn host_matches(host: &str, domain: &str) -> bool {
    let host = host.trim_end_matches('.').to_ascii_lowercase();
    host == domain || host.ends_with(&format!(".{domain}"))
}

fn resolve_history_path(cli: &Cli) -> Result<PathBuf> {
    if let Some(h) = &cli.history {
        return Ok(h.clone());
    }
    let base = match &cli.user_data_dir {
        Some(p) => p.clone(),
        None => default_user_data_dir()
            .ok_or_else(|| anyhow!("could not locate Chrome's user-data dir; pass --user-data-dir or --history"))?,
    };
    Ok(base.join(&cli.profile).join("History"))
}

fn default_user_data_dir() -> Option<PathBuf> {
    #[cfg(target_os = "macos")]
    {
        dirs::home_dir().map(|h| h.join("Library/Application Support/Google/Chrome"))
    }
    #[cfg(target_os = "linux")]
    {
        dirs::config_dir().map(|c| c.join("google-chrome"))
    }
    #[cfg(target_os = "windows")]
    {
        dirs::data_local_dir().map(|d| d.join("Google").join("Chrome").join("User Data"))
    }
    #[cfg(not(any(target_os = "macos", target_os = "linux", target_os = "windows")))]
    {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_domain_and_subdomains() {
        assert!(host_matches("example.com", "example.com"));
        assert!(host_matches("www.example.com", "example.com"));
        assert!(host_matches("a.b.example.com", "example.com"));
        assert!(host_matches("EXAMPLE.com", "example.com"));
    }

    #[test]
    fn rejects_lookalikes() {
        assert!(!host_matches("notexample.com", "example.com"));
        assert!(!host_matches("example.com.evil.com", "example.com"));
        assert!(!host_matches("example.org", "example.com"));
    }

    #[test]
    fn normalizes_urls_and_ports() {
        assert_eq!(normalize_domain("example.com").unwrap(), "example.com");
        assert_eq!(normalize_domain("https://www.example.com/x?y").unwrap(), "www.example.com");
        assert_eq!(normalize_domain("Example.COM:8080").unwrap(), "example.com");
        assert_eq!(normalize_domain("  example.com.  ").unwrap(), "example.com");
    }
}
