# obliviate

Delete every Chrome history entry for a domain — and its subdomains — by
operating directly on Chrome's SQLite `History` database.

Chrome stores history as SQLite. Removing a domain means finding the matching
`urls` rows and cascading by hand through every table that references them, then
optionally reclaiming the freed pages. This tool does that in one transaction,
with a dry-run preview, an automatic backup, and proper host matching.

## What it removes

For the given domain (and any subdomain):

- **History:** `urls`, `visits`, `visit_source`, `keyword_search_terms`,
  `segments`, `segment_usage`
- **Downloads:** `downloads`, `downloads_url_chains`, `downloads_slices` — a
  download matches if any URL in its redirect chain, or the tab it came from, is
  on the domain
- **Journeys / history clustering:** `content_annotations`,
  `context_annotations`, `clusters_and_visits` (cleaned defensively; these vary
  by Chrome version)
- **Omnibox / new-tab suggestions:** separate single-table databases next to
  `History` whose destination-URL column is host-matched the same way —
  `Shortcuts` (`omni_box_shortcuts`), `Network Action Predictor`
  (`network_action_predictor`), `Top Sites` (`top_sites`). Deleting history
  alone leaves these, so the address bar keeps autocompleting the domain; this
  is what clears that.

Tables absent in your Chrome version are skipped. History deletions run
child-before-parent so nothing is left dangling, and `VACUUM` afterward reclaims
(and overwrites) the freed pages in every database touched.

### Not touched

- `Favicons` — a shared cache keyed by page URL; not history.
- `Visited Links` — a binary hash file (not SQLite), so it cannot be edited in
  place; Chrome rebuilds it from the cleaned history over time.
- **Chrome Sync.** If history sync is on, your history also lives server-side,
  and an offline SQLite delete creates no sync tombstone — so synced entries can
  reappear after a restart. To remove synced data, delete via `chrome://history`
  or myactivity.google.com, or pause sync before running this.

## Build

```bash
cd bin/obliviate
cargo build --release
# binary at target/release/obliviate
```

`rusqlite` is built with the `bundled` feature, so it compiles its own SQLite
(needs a C compiler — clang on macOS, gcc on Linux) and has no runtime
dependency on a system libsqlite.

## Usage

Domain matching parses each stored URL and compares the **host**: `example.com`
matches `example.com` and `www.example.com`, but never `notexample.com` or
`example.com.evil.com`.

```bash
# Preview only — never writes:
obliviate example.com --dry-run

# Delete (prompts first; backs up the History file by default):
obliviate example.com

# A non-default profile:
obliviate example.com --profile "Profile 1"

# Point straight at a History file (e.g. Brave/Chromium/Edge, same schema):
obliviate example.com --history ~/path/to/History

# Let it quit and reopen Chrome for you (macOS) — no manual quit needed:
obliviate example.com --restart-chrome --yes
```

### Important

- **Quit Google Chrome completely first**, or pass `--restart-chrome`. Chrome
  holds the databases open; while it is running the delete fails fast with a
  "database is locked" message rather than fighting the lock.
- **`--restart-chrome` (macOS)** automates that: it gracefully quits Chrome
  (only if it's running), waits for the database to actually unlock, runs, then
  reopens Chrome — and is guaranteed to reopen it even if the prune errors. Your
  tabs come back via Chrome's session restore. There is no safe way to edit the
  database *without* Chrome releasing it: SQLite locks are held by the live
  process, so "forcing" them means killing or corrupting.
- A timestamped backup (`History.prune-backup-<unix>`, plus `-wal`/`-shm`
  sidecars) is written next to the original unless you pass `--no-backup`. The
  tool prints the exact `cp` command to restore it.

### Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Show what would be deleted, then exit. Reads only. |
| `-y, --yes` | Skip the confirmation prompt. |
| `--profile <name>` | Profile dir name (default `Default`). |
| `--user-data-dir <path>` | Override the parent of the profile dirs. |
| `--history <file>` | Use this History file directly. |
| `--no-backup` | Do not copy the History file first (irreversible). |
| `--no-vacuum` | Skip the post-delete `VACUUM`. |
| `--restart-chrome` | Gracefully quit Chrome first, then reopen it when done (macOS only). |

Default profile locations:

- macOS: `~/Library/Application Support/Google/Chrome/<profile>/History`
- Linux: `~/.config/google-chrome/<profile>/History`
- Windows: `%LOCALAPPDATA%\Google\Chrome\User Data\<profile>\History`
