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
//!
//! Beyond SQLite, the domain's fetched bytes persist in Chrome's Simple Cache
//! directories (the HTTP cache and the compiled-code caches). Every entry file
//! embeds its own key — the request URL, plus the partition site for
//! split-cache entries — so entries are matched by parsing the URLs out of
//! that key and deleted by removing their files; Chrome's cache index treats
//! the missing files as evictions and heals itself on the next start.

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{self, IsTerminal, Read, Write};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[cfg(target_os = "macos")]
use std::process::Command;
#[cfg(target_os = "macos")]
use std::time::Instant;

use anyhow::{anyhow, bail, Context, Result};
use clap::Parser;
use rusqlite::{Connection, OpenFlags, OptionalExtension, TransactionBehavior};
use url::Url;

/// Delete all Chrome history, downloads, and cached content for a given domain.
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

    /// Gracefully quit Chrome first, then reopen it when done (macOS only)
    #[arg(long)]
    restart_chrome: bool,
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

    // With --restart-chrome we close Chrome (only if it's actually running) so
    // the databases unlock, then guarantee a relaunch afterward — even if the
    // prune fails partway — so we never leave the browser unexpectedly shut.
    if cli.restart_chrome && quit_chrome(&history)? {
        let outcome = prune_all(&cli, &domain, &history);
        relaunch_chrome();
        return outcome;
    }

    prune_all(&cli, &domain, &history)
}

fn prune_all(cli: &Cli, domain: &str, history: &Path) -> Result<()> {
    let mut conn = Connection::open_with_flags(history, OpenFlags::SQLITE_OPEN_READ_WRITE)
        .with_context(|| format!("opening {}", history.display()))?;
    conn.busy_timeout(Duration::from_secs(5))?;

    // Build connection-scoped scratch tables of the ids we intend to remove.
    build_scratch_tables(&conn, domain)?;

    let ops = delete_ops();
    let history_counts = count_matches(&conn, &ops)?;

    // The omnibox/new-tab suggestion databases sit alongside History in the
    // same profile dir; each is a single table with a destination-URL column.
    let profile_dir = history.parent().unwrap_or_else(|| Path::new("."));
    let mut satellites: Vec<(&'static Satellite, PathBuf, usize)> = Vec::new();
    for s in SATELLITES {
        let path = profile_dir.join(s.file);
        match scan_satellite(&path, s, domain) {
            Ok(Some(n)) => satellites.push((s, path, n)),
            Ok(None) => {}
            Err(e) => eprintln!("warning: could not read {} ({e}); skipping in preview", s.file),
        }
    }

    // The disk caches (HTTP responses, compiled JS/wasm) key every entry by
    // URL, so the domain's fetched bytes outlive a history-only prune. Scan
    // them for the preview the same way. Cache entries are refetchable, so
    // unlike the databases they are deleted without a backup.
    let default_layout = cli.user_data_dir.is_none() && cli.history.is_none();
    let mut caches: Vec<(CacheDir, usize, u64)> = Vec::new();
    for dir in cache_dirs(history, default_layout) {
        match scan_cache_dir(&dir, domain) {
            // Keep zero-count dirs so the preview shows they were scanned,
            // like the suggestion databases above.
            Ok(hits) => {
                let bytes = hits.iter().map(|h| h.bytes).sum();
                caches.push((dir, hits.len(), bytes));
            }
            Err(e) => eprintln!(
                "warning: could not scan {} ({e}); skipping in preview",
                dir.path.display()
            ),
        }
    }

    print_preview(&history_counts, &ops, &satellites, &caches);

    let history_total: usize = history_counts.values().sum();
    let sat_total: usize = satellites.iter().map(|(_, _, n)| *n).sum();
    let cache_total: usize = caches.iter().map(|(_, n, _)| *n).sum();
    if history_total == 0 && sat_total == 0 && cache_total == 0 {
        println!("\nnothing matches {domain}; no changes made.");
        return Ok(());
    }
    if cli.dry_run {
        println!("\ndry run: no changes made.");
        return Ok(());
    }

    if !cli.restart_chrome {
        println!("\nQuit Google Chrome completely first, or the databases will be locked.");
    }
    if !cli.yes && !confirm(&format!("Delete everything listed above for {domain}? [y/N] "))? {
        println!("aborted; no changes made.");
        return Ok(());
    }

    let mut removed = 0usize;

    if history_total > 0 {
        println!("\nHistory:");
        if !cli.no_backup {
            announce_backup(history)?;
        }
        // Fold any write-ahead log into the main file before mutating.
        let _ = conn.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);");
        let deleted = execute_deletes(&mut conn, &ops, history)?;
        if !cli.no_vacuum {
            if let Err(e) = conn.execute_batch("VACUUM;") {
                eprintln!("warning: VACUUM failed on History ({e}); freed space not reclaimed");
            }
        }
        removed += deleted.values().sum::<usize>();
    }
    drop(conn);

    for (s, path, _) in &satellites {
        match prune_satellite(path, s, domain, cli.no_backup, cli.no_vacuum) {
            Ok(n) => removed += n,
            Err(e) => eprintln!("warning: {} ({e:#})", s.file),
        }
    }

    let mut cache_removed = 0usize;
    let mut cache_bytes = 0u64;
    for (dir, matched, _) in &caches {
        if *matched == 0 {
            continue;
        }
        match prune_cache_dir(dir, domain) {
            Ok((n, bytes)) => {
                println!("\n{}:", dir.label);
                println!("removed {n} entries ({})", human_bytes(bytes));
                cache_removed += n;
                cache_bytes += bytes;
            }
            Err(e) => eprintln!("warning: {} ({e:#})", dir.label),
        }
    }

    if cache_removed > 0 {
        println!(
            "\ndone: removed {removed} rows and {cache_removed} cache entries ({}) for {domain}.",
            human_bytes(cache_bytes)
        );
    } else {
        println!("\ndone: removed {removed} rows for {domain}.");
    }
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
    caches: &[(CacheDir, usize, u64)],
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
    if !caches.is_empty() {
        println!("entries matched in disk caches:");
        for (dir, n, bytes) in caches {
            println!("  {:<26} {:>8}  ({})", dir.label, n, human_bytes(*bytes));
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

// ── Disk caches (Simple Cache backend) ─────────────────────────────────────
//
// The HTTP cache and the compiled-code caches store one entry per file
// (`<64-bit hash as hex>_0`, with optional `_1`/`_s` siblings), each starting
// with a fixed header followed by the entry's key. The key contains the
// request URL — and, for partitioned entries (`1/0/_dk_ <top-frame site>
// <frame site> <url>`), the sites it was fetched under — so reading it is
// enough to host-match an entry without Chrome's cache index. Deleting the
// entry's files is safe with Chrome closed: the index is a hint, and missing
// files are treated as evictions on the next start.

const SIMPLE_CACHE_MAGIC: u64 = 0xfcfb_6d1b_a772_5c30;

/// One cache directory to sweep, with a human label for the preview.
struct CacheDir {
    label: &'static str,
    path: PathBuf,
}

/// A matching entry: the hash stem its files share, and their total size.
struct CacheHit {
    stem: String,
    bytes: u64,
}

/// Locate the profile's cache directories. They sit inside the profile dir on
/// Linux/Windows (and under any custom --user-data-dir), but the default macOS
/// layout splits them out under ~/Library/Caches. The platform location is
/// keyed by profile-directory name and only probed for the default layout, so
/// pointing --history at a copied file can never sweep the live profile's
/// caches. Only directories that exist are returned.
fn cache_dirs(history: &Path, default_layout: bool) -> Vec<CacheDir> {
    let Some(profile_dir) = history.parent() else {
        return Vec::new();
    };
    let mut roots: Vec<PathBuf> = vec![profile_dir.to_path_buf()];
    if default_layout {
        if let (Some(base), Some(name)) = (platform_cache_base(), profile_dir.file_name()) {
            roots.push(base.join(name));
        }
    }

    let mut seen: BTreeSet<PathBuf> = BTreeSet::new();
    let mut out = Vec::new();
    for root in roots {
        for (label, rel) in [
            ("HTTP cache", "Cache/Cache_Data"),
            ("Code Cache/js", "Code Cache/js"),
            ("Code Cache/wasm", "Code Cache/wasm"),
        ] {
            let path = root.join(rel);
            if !path.is_dir() {
                continue;
            }
            // Dedupe via the canonical path in case both roots are the same.
            let canon = fs::canonicalize(&path).unwrap_or_else(|_| path.clone());
            if seen.insert(canon) {
                out.push(CacheDir { label, path });
            }
        }
    }
    out
}

/// Where the default Chrome install keeps per-profile caches when they live
/// outside the user-data dir. Windows keeps them inside it, so: nothing extra.
fn platform_cache_base() -> Option<PathBuf> {
    #[cfg(target_os = "macos")]
    {
        dirs::home_dir().map(|h| h.join("Library/Caches/Google/Chrome"))
    }
    #[cfg(target_os = "linux")]
    {
        dirs::cache_dir().map(|c| c.join("google-chrome"))
    }
    #[cfg(not(any(target_os = "macos", target_os = "linux")))]
    {
        None
    }
}

/// In-place progress line for a long scan. Prints only to a terminal and
/// erases itself when done, so piped output and the preview table stay clean.
struct ScanProgress {
    label: &'static str,
    total: usize,
    shown: bool,
}

impl ScanProgress {
    fn new(label: &'static str, total: usize) -> Self {
        Self { label, total, shown: false }
    }

    fn tick(&mut self, done: usize) {
        if !io::stdout().is_terminal() {
            return;
        }
        print!("\r  {:<26} {:>8}/{} scanned", self.label, done, self.total);
        let _ = io::stdout().flush();
        self.shown = true;
    }

    fn finish(&mut self) {
        if self.shown {
            print!("\r{:70}\r", "");
            let _ = io::stdout().flush();
            self.shown = false;
        }
    }
}

/// Scan one cache directory for entries whose key URLs match the domain. The
/// HTTP cache normally holds tens of thousands of entry files and every key
/// gets read, so a progress line shows while this runs. Individual unreadable
/// or foreign files are skipped: caches legitimately contain index files, and
/// Chrome may race us on entries if it is running.
fn scan_cache_dir(dir: &CacheDir, domain: &str) -> Result<Vec<CacheHit>> {
    let mut stems: Vec<String> = Vec::new();
    for entry in
        fs::read_dir(&dir.path).with_context(|| format!("reading {}", dir.path.display()))?
    {
        let Ok(entry) = entry else { continue };
        let name = entry.file_name();
        let name = name.to_string_lossy();
        let Some(stem) = name.strip_suffix("_0") else {
            continue;
        };
        if stem.len() == 16 && stem.bytes().all(|b| b.is_ascii_hexdigit()) {
            stems.push(stem.to_string());
        }
    }

    let mut progress = ScanProgress::new(dir.label, stems.len());
    let mut hits = Vec::new();
    for (i, stem) in stems.iter().enumerate() {
        if i % 1024 == 0 {
            progress.tick(i);
        }
        let Ok(Some(key)) = simple_cache_key(&dir.path.join(format!("{stem}_0"))) else {
            continue;
        };
        if key_hosts(&key).iter().any(|h| host_matches(h, domain)) {
            hits.push(CacheHit { stem: stem.clone(), bytes: entry_bytes(&dir.path, stem) });
        }
    }
    progress.finish();
    Ok(hits)
}

/// Read the key out of one `<hash>_0` entry file. Returns None when the file
/// is not a Simple Cache entry we understand (wrong magic, unknown version, or
/// truncated) — never guesses.
fn simple_cache_key(path: &Path) -> io::Result<Option<String>> {
    let mut f = fs::File::open(path)?;
    // SimpleFileHeader: u64 magic, u32 version, u32 key_length, u32 key_hash,
    // padded to 24 bytes; the key follows immediately.
    let mut header = [0u8; 24];
    if f.read_exact(&mut header).is_err() {
        return Ok(None);
    }
    let magic = u64::from_le_bytes(header[0..8].try_into().unwrap());
    let version = u32::from_le_bytes(header[8..12].try_into().unwrap());
    let key_len = u32::from_le_bytes(header[12..16].try_into().unwrap());
    if magic != SIMPLE_CACHE_MAGIC || !(5..=9).contains(&version) || key_len > 64 * 1024 {
        return Ok(None);
    }
    let mut key = vec![0u8; key_len as usize];
    if f.read_exact(&mut key).is_err() {
        return Ok(None);
    }
    Ok(Some(String::from_utf8_lossy(&key).into_owned()))
}

/// Extract the hosts of the http(s) URLs in a cache key. Keys come in several
/// shapes — a bare URL, `1/0/<url>`, the partitioned `1/0/_dk_ <site> <site>
/// <url>`, or the code cache's `_key<url>\n<origin>` — so split on the
/// separators (whitespace) and parse from the first scheme occurrence in each
/// piece. A URL embedded in another URL's query stays inside that parse and
/// never matches on its own, preserving the tool's host-only guarantee.
fn key_hosts(key: &str) -> Vec<String> {
    let mut hosts = Vec::new();
    for token in key.split_whitespace() {
        let start = match (token.find("https://"), token.find("http://")) {
            (Some(a), Some(b)) => a.min(b),
            (Some(a), None) | (None, Some(a)) => a,
            (None, None) => continue,
        };
        if let Ok(u) = Url::parse(&token[start..]) {
            if let Some(h) = u.host_str() {
                hosts.push(h.to_string());
            }
        }
    }
    hosts
}

/// Total size of all files belonging to an entry stem.
fn entry_bytes(dir: &Path, stem: &str) -> u64 {
    ["_0", "_1", "_s"]
        .iter()
        .filter_map(|s| fs::metadata(dir.join(format!("{stem}{s}"))).ok())
        .map(|m| m.len())
        .sum()
}

/// Delete every file of every matching entry in one cache directory. Re-scans
/// first (like the satellites) so the deletion reflects current state, and
/// counts an entry as removed only if at least one of its files existed.
fn prune_cache_dir(dir: &CacheDir, domain: &str) -> Result<(usize, u64)> {
    let mut removed = 0usize;
    let mut bytes = 0u64;
    for hit in scan_cache_dir(dir, domain)? {
        let mut any = false;
        for suffix in ["_0", "_1", "_s"] {
            let path = dir.path.join(format!("{}{suffix}", hit.stem));
            match fs::remove_file(&path) {
                Ok(()) => any = true,
                Err(e) if e.kind() == io::ErrorKind::NotFound => {}
                Err(e) => {
                    return Err(e).with_context(|| format!("deleting {}", path.display()))
                }
            }
        }
        if any {
            removed += 1;
            bytes += hit.bytes;
        }
    }
    Ok((removed, bytes))
}

fn human_bytes(n: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut value = n as f64;
    let mut unit = 0;
    while value >= 1024.0 && unit < UNITS.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{n} B")
    } else {
        format!("{value:.1} {}", UNITS[unit])
    }
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
            "database is locked: {}\n  Quit Google Chrome completely and try again (or pass --restart-chrome).",
            history.display()
        )
    } else {
        anyhow::Error::new(e)
    }
}

// ── Chrome process control (--restart-chrome) ─────────────────────────────
//
// SQLite locks are held by the live process that has the file open; they can't
// be "forced" off without killing or corrupting. The safe path is to ask Chrome
// to quit, wait for it to genuinely let go of the database, then reopen it.

/// Gracefully quit Chrome if it's running, then wait for the History database
/// to unlock. Returns whether a running instance was actually told to quit — so
/// the caller knows whether to reopen it afterward.
#[cfg(target_os = "macos")]
fn quit_chrome(history: &Path) -> Result<bool> {
    if !chrome_is_running() {
        return Ok(false);
    }
    print!("quitting Google Chrome and waiting for the database to unlock... ");
    io::stdout().flush().ok();
    let status = Command::new("osascript")
        .args(["-e", "tell application \"Google Chrome\" to quit"])
        .status()
        .context("running osascript to quit Chrome")?;
    if !status.success() {
        bail!("osascript could not quit Chrome");
    }
    if wait_for_unlock(history) {
        println!("ok");
    } else {
        println!("timed out");
        eprintln!(
            "warning: Chrome has not released {} after 20s; if \"Continue running\n  \
             background apps\" is enabled, quit it from the menu-bar icon.",
            history.display()
        );
    }
    Ok(true)
}

/// True if Chrome is up. AppleScript's `is running` — unlike `tell application …
/// to quit` — never launches Chrome as a side effect.
#[cfg(target_os = "macos")]
fn chrome_is_running() -> bool {
    Command::new("osascript")
        .args(["-e", "application \"Google Chrome\" is running"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "true")
        .unwrap_or(false)
}

/// Reopen Chrome (best-effort; a failure here is non-fatal).
#[cfg(target_os = "macos")]
fn relaunch_chrome() {
    println!("reopening Google Chrome...");
    if let Err(e) = Command::new("open").args(["-a", "Google Chrome"]).status() {
        eprintln!("warning: could not reopen Chrome ({e}); open it manually");
    }
}

/// Poll until a write lock on `history` is available (Chrome has let go), or give
/// up after 20s. Each probe opens the DB and tries to begin an exclusive write
/// transaction, which rolls back on drop.
#[cfg(target_os = "macos")]
fn wait_for_unlock(history: &Path) -> bool {
    let deadline = Instant::now() + Duration::from_secs(20);
    loop {
        if db_is_writable(history) {
            return true;
        }
        if Instant::now() >= deadline {
            return false;
        }
        std::thread::sleep(Duration::from_millis(250));
    }
}

#[cfg(target_os = "macos")]
fn db_is_writable(history: &Path) -> bool {
    let Ok(mut conn) = Connection::open_with_flags(history, OpenFlags::SQLITE_OPEN_READ_WRITE)
    else {
        return false;
    };
    if conn.busy_timeout(Duration::from_millis(100)).is_err() {
        return false;
    }
    // Bind before returning so the probe transaction (which borrows conn) is
    // dropped — and the lock released — before conn itself goes out of scope.
    let writable = conn
        .transaction_with_behavior(TransactionBehavior::Immediate)
        .is_ok();
    writable
}

#[cfg(not(target_os = "macos"))]
fn quit_chrome(_history: &Path) -> Result<bool> {
    eprintln!("warning: --restart-chrome is only implemented on macOS; quit Chrome yourself");
    Ok(false)
}

#[cfg(not(target_os = "macos"))]
fn relaunch_chrome() {}

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

    #[test]
    fn extracts_hosts_from_every_cache_key_shape() {
        assert_eq!(key_hosts("https://example.com/a.js"), ["example.com"]);
        assert_eq!(key_hosts("1/0/https://example.com/a"), ["example.com"]);
        assert_eq!(
            key_hosts("1/0/_dk_ https://top.com https://frame.com https://cdn.com/x"),
            ["top.com", "frame.com", "cdn.com"]
        );
        // Code cache: `_key` glued to the URL, origin lock after a newline.
        assert_eq!(
            key_hosts("_keyhttps://example.com/app.js\nhttps://example.com"),
            ["example.com", "example.com"]
        );
    }

    #[test]
    fn cache_key_urls_inside_queries_never_match() {
        assert_eq!(
            key_hosts("1/0/https://tracker.com/r?u=https://example.com/x"),
            ["tracker.com"]
        );
        assert!(key_hosts("no urls in this key").is_empty());
    }

    /// Fresh scratch dir under the system temp dir, unique per test.
    fn temp_cache_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("obliviate-test-{}-{tag}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    /// Write a minimal Simple Cache entry (`_0` header+key, `_1` body).
    fn write_simple_entry(dir: &Path, stem: &str, key: &str) {
        let mut buf = Vec::new();
        buf.extend_from_slice(&SIMPLE_CACHE_MAGIC.to_le_bytes());
        buf.extend_from_slice(&5u32.to_le_bytes()); // version
        buf.extend_from_slice(&(key.len() as u32).to_le_bytes());
        buf.extend_from_slice(&[0u8; 8]); // key hash + struct padding
        buf.extend_from_slice(key.as_bytes());
        fs::write(dir.join(format!("{stem}_0")), &buf).unwrap();
        fs::write(dir.join(format!("{stem}_1")), b"body bytes").unwrap();
    }

    #[test]
    fn scans_and_prunes_simple_cache_entries() {
        let dir = temp_cache_dir("prune");
        write_simple_entry(
            &dir,
            "00000000000000aa",
            "1/0/_dk_ https://example.com https://example.com https://cdn.example.com/x.css",
        );
        write_simple_entry(&dir, "00000000000000bb", "1/0/https://other.org/page");
        fs::write(dir.join("not-an-entry"), b"junk").unwrap();

        let cache = CacheDir { label: "test cache", path: dir.clone() };
        let hits = scan_cache_dir(&cache, "example.com").unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].stem, "00000000000000aa");
        assert!(hits[0].bytes > 0);

        let (removed, bytes) = prune_cache_dir(&cache, "example.com").unwrap();
        assert_eq!(removed, 1);
        assert!(bytes > 0);
        assert!(!dir.join("00000000000000aa_0").exists());
        assert!(!dir.join("00000000000000aa_1").exists());
        assert!(dir.join("00000000000000bb_0").exists());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn skips_cache_files_with_bad_magic_or_short_headers() {
        let dir = temp_cache_dir("junk");
        fs::write(dir.join("00000000000000cc_0"), b"short").unwrap();
        let mut bad = vec![0u8; 64];
        bad[..8].copy_from_slice(&0x1122_3344_5566_7788u64.to_le_bytes());
        fs::write(dir.join("00000000000000dd_0"), &bad).unwrap();
        let cache = CacheDir { label: "test cache", path: dir.clone() };
        assert!(scan_cache_dir(&cache, "example.com").unwrap().is_empty());
        let _ = fs::remove_dir_all(&dir);
    }
}
