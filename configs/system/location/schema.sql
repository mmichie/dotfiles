-- Shell Location Service Database Schema
-- Tracks network and geographic location for shell/tmux weather and services

-- Current location (single row, always up to date)
CREATE TABLE IF NOT EXISTS current_location (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  updated_at INTEGER NOT NULL,

  -- Network info (now)
  ssid TEXT,
  bssid TEXT,
  ip_address TEXT,
  network_type TEXT,  -- 'wifi', 'ethernet', 'cellular', 'unknown'
  network_interface TEXT,

  -- Location (now)
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  city TEXT,
  region TEXT,
  country_code TEXT,

  -- Machine context (now)
  hostname TEXT NOT NULL,

  -- Metadata (now)
  source TEXT NOT NULL,        -- 'wifi', 'ip', 'manual', 'home_radius'
  source_detail TEXT,           -- 'wifi:config', 'wifi:learned', 'ip:api.com'
  confidence TEXT DEFAULT 'medium',  -- 'high', 'medium', 'low'

  -- Future fields (placeholders)
  vpn_active INTEGER DEFAULT 0,
  timezone TEXT,
  altitude REAL,
  accuracy_meters REAL,

  -- Change tracking
  previous_lat REAL,
  previous_lon REAL,
  location_changed INTEGER DEFAULT 0
);

-- Location history (append-only log)
CREATE TABLE IF NOT EXISTS location_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,

  -- Network
  ssid TEXT,
  bssid TEXT,
  ip_address TEXT,
  network_type TEXT,
  network_interface TEXT,

  -- Location
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  city TEXT,
  region TEXT,
  country_code TEXT,

  -- Machine context
  hostname TEXT NOT NULL,

  -- Metadata
  source TEXT NOT NULL,
  source_detail TEXT,
  confidence TEXT,

  -- Future fields
  vpn_active INTEGER DEFAULT 0,
  timezone TEXT,
  altitude REAL,
  accuracy_meters REAL,

  -- Duration tracking
  duration_seconds INTEGER,
  departure_timestamp INTEGER
);

-- Known WiFi networks (learned or configured)
CREATE TABLE IF NOT EXISTS known_networks (
  ssid TEXT NOT NULL,
  bssid TEXT NOT NULL DEFAULT '',  -- Empty string means "any BSSID for this SSID"

  -- Location
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  city TEXT,
  region TEXT,
  country_code TEXT,

  -- Metadata
  confidence REAL DEFAULT 1.0,  -- 0-1, decreases if location varies
  location_variance_meters REAL DEFAULT 0,
  source TEXT DEFAULT 'learned',  -- 'config', 'learned', 'manual'

  -- Tracking
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  times_seen INTEGER DEFAULT 1,

  -- Multi-location detection
  is_portable INTEGER DEFAULT 0,  -- 1 if same SSID appears at different locations

  PRIMARY KEY (ssid, bssid)
);

-- Configuration key-value store
CREATE TABLE IF NOT EXISTS config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_history_time ON location_history(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_history_ssid ON location_history(ssid);
CREATE INDEX IF NOT EXISTS idx_history_hostname ON location_history(hostname);
CREATE INDEX IF NOT EXISTS idx_history_location ON location_history(lat, lon);
CREATE INDEX IF NOT EXISTS idx_known_networks_ssid ON known_networks(ssid);
CREATE INDEX IF NOT EXISTS idx_known_networks_last_seen ON known_networks(last_seen DESC);

-- Insert default config values
INSERT OR IGNORE INTO config (key, value) VALUES
  ('version', '1.0'),
  ('update_interval', '300'),        -- 5 minutes
  ('stale_threshold', '900'),        -- 15 minutes
  ('history_retention_days', '90'),  -- Keep 90 days of history
  ('reverse_geocode', '1'),          -- Enable city lookup
  ('auto_learn_networks', '1');      -- Auto-learn WiFi networks
