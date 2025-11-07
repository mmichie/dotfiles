#!/usr/bin/env zsh

# Location Service Test Suite
# Run this to verify location service works before committing

set -e

echo "=== Location Service Test Suite ==="
echo

# Color helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo "${GREEN}✓${NC} $1"
}

fail() {
    echo "${RED}✗${NC} $1"
    exit 1
}

warn() {
    echo "${YELLOW}⚠${NC} $1"
}

# Test 1: Check files exist
echo "Test 1: Checking files exist..."
[[ -f "zsh/.zsh/lib/location_service.zsh" ]] || fail "location_service.zsh not found"
[[ -f "zsh/.zsh/lib/wifi_location.zsh" ]] || fail "wifi_location.zsh not found"
[[ -f "zsh/.zsh/functions/location_cli.zsh" ]] || fail "location_cli.zsh not found"
[[ -f "system/.config/location/schema.sql" ]] || fail "schema.sql not found"
pass "All files exist"
echo

# Test 2: Check SQL syntax
echo "Test 2: Validating SQL schema..."
sqlite3 /tmp/test_location.db < system/.config/location/schema.sql 2>/dev/null || fail "SQL schema has errors"
rm -f /tmp/test_location.db
pass "SQL schema is valid"
echo

# Test 3: Source the modules
echo "Test 3: Loading location service modules..."

# Disable automatic location updates during testing
export DISABLE_WIFI_LOCATION=1

# Load platform detection first (required for is_osx, is_linux functions)
if [[ -f "zsh/.zsh/lib/platform_detection.zsh" ]]; then
    source zsh/.zsh/lib/platform_detection.zsh || warn "Failed to source platform_detection.zsh"
else
    # Provide fallback functions if platform_detection doesn't exist
    is_osx() { [[ "$OSTYPE" == darwin* ]]; }
    is_linux() { [[ "$OSTYPE" == linux* ]]; }
fi

source zsh/.zsh/lib/location_service.zsh || fail "Failed to source location_service.zsh"
source zsh/.zsh/lib/wifi_location.zsh || fail "Failed to source wifi_location.zsh"
source zsh/.zsh/functions/location_cli.zsh || fail "Failed to source location_cli.zsh"
pass "All modules loaded successfully"
echo

# Test 4: Check database initialization
echo "Test 4: Testing database initialization..."
export LOCATION_DB="/tmp/test_location_service.db"
export LOCATION_SCHEMA="$(pwd)/system/.config/location/schema.sql"
rm -f "$LOCATION_DB"
_location_init || fail "Database initialization failed"
[[ -f "$LOCATION_DB" ]] || fail "Database file not created"

# Verify tables exist
sqlite3 "$LOCATION_DB" "SELECT name FROM sqlite_master WHERE type='table';" > /tmp/tables.txt
grep -q "current_location" /tmp/tables.txt || fail "current_location table not found"
grep -q "location_history" /tmp/tables.txt || fail "location_history table not found"
grep -q "known_networks" /tmp/tables.txt || fail "known_networks table not found"
grep -q "config" /tmp/tables.txt || fail "config table not found"
pass "Database initialized with correct schema"
echo

# Test 5: Test WiFi detection (non-fatal)
echo "Test 5: Testing WiFi detection..."
wifi_info=$(_location_get_wifi)
if [[ -n "$wifi_info" ]]; then
    IFS='|' read -r ssid bssid interface <<< "$wifi_info"
    if [[ -n "$ssid" ]]; then
        pass "WiFi detected: $ssid (interface: $interface)"
    else
        warn "Not connected to WiFi (this is OK for testing)"
    fi
else
    warn "WiFi detection returned nothing (you might not be on WiFi)"
fi
echo

# Test 6: Test IP detection
echo "Test 6: Testing IP detection..."
ip=$(_location_get_ip)
if [[ -n "$ip" && "$ip" != "" ]]; then
    pass "IP detected: $ip"
else
    warn "IP detection failed (might be offline)"
fi
echo

# Test 7: Test network lookup (should fail with empty DB)
echo "Test 7: Testing network lookup..."
result=$(_location_lookup_network "TestSSID" "00:11:22:33:44:55") || true
if [[ -z "$result" ]]; then
    pass "Network lookup correctly returns nothing for unknown network"
else
    fail "Network lookup should have returned nothing"
fi
echo

# Test 8: Add test network and lookup
echo "Test 8: Testing network storage and retrieval..."
sqlite3 "$LOCATION_DB" <<EOF
INSERT INTO known_networks (ssid, bssid, lat, lon, source, first_seen, last_seen)
VALUES ('TestNetwork', '00:11:22:33:44:55', 37.7749, -122.4194, 'test', strftime('%s','now'), strftime('%s','now'));
EOF

result=$(_location_lookup_network "TestNetwork" "00:11:22:33:44:55")
if [[ -n "$result" ]]; then
    pass "Network stored and retrieved successfully"
else
    fail "Failed to retrieve stored network"
fi
echo

# Test 9: Test location_get and location_export
echo "Test 9: Testing location API..."
# Insert test location
sqlite3 "$LOCATION_DB" <<EOF
INSERT OR REPLACE INTO current_location (
  id, updated_at, ssid, lat, lon, hostname, source, source_detail, confidence
) VALUES (
  1, strftime('%s','now'), 'TestSSID', 37.7749, -122.4194, 'testhost', 'test', 'test:suite', 'high'
);
EOF

result=$(location_get)
if [[ -n "$result" ]]; then
    pass "location_get returned: $result"
else
    fail "location_get returned nothing"
fi

location_export >/dev/null
if [[ -n "$CLIMA_LAT" && -n "$CLIMA_LON" ]]; then
    pass "Environment variables exported: CLIMA_LAT=$CLIMA_LAT, CLIMA_LON=$CLIMA_LON"
else
    fail "Environment variables not exported"
fi
echo

# Test 10: Test CLI commands
echo "Test 10: Testing CLI commands..."
location status >/dev/null 2>&1 || fail "location status failed"
pass "location status works"

location networks >/dev/null 2>&1 || fail "location networks failed"
pass "location networks works"

location info >/dev/null 2>&1 || fail "location info failed"
pass "location info works"
echo

# Test 11: Test config import
echo "Test 11: Testing config import..."
cat > /tmp/test_wifi.conf <<EOF
# Test config
TestHome,37.7749,-122.4194
TestOffice,40.7128,-74.0060
EOF

export LOCATION_CONFIG_FILE=/tmp/test_wifi.conf
_location_import_config || fail "Config import failed"

count=$(sqlite3 "$LOCATION_DB" "SELECT COUNT(*) FROM known_networks WHERE source='config';")
if [[ "$count" -ge 2 ]]; then
    pass "Config imported successfully ($count networks)"
else
    fail "Config import didn't create networks (count: $count)"
fi
echo

# Test 12: Test staleness check
echo "Test 12: Testing staleness detection..."
# Set old timestamp
sqlite3 "$LOCATION_DB" "UPDATE current_location SET updated_at = strftime('%s','now') - 1000 WHERE id = 1;"
if location_is_stale; then
    pass "Correctly detected stale location"
else
    fail "Failed to detect stale location"
fi

# Set fresh timestamp
sqlite3 "$LOCATION_DB" "UPDATE current_location SET updated_at = strftime('%s','now') WHERE id = 1;"
if ! location_is_stale; then
    pass "Correctly detected fresh location"
else
    fail "Incorrectly marked fresh location as stale"
fi
echo

# Cleanup
echo "Cleaning up test database..."
rm -f "$LOCATION_DB" /tmp/tables.txt /tmp/test_wifi.conf
unset LOCATION_DB LOCATION_CONFIG_FILE
pass "Cleanup complete"
echo

echo "${GREEN}=== All Tests Passed! ===${NC}"
echo
echo "The location service is ready to commit."
echo
echo "Next steps:"
echo "  1. Reload your shell: source ~/.zshrc"
echo "  2. Check status: location status"
echo "  3. Test with real network: location force"
echo "  4. Commit the code"
