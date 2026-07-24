#!/usr/bin/env bash
# Virtual tests — no root, no network changes. Run: bash tests/virtual-test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

ok() { echo "  OK: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "NetForge Linux virtual tests"
echo "Root: $ROOT"

# --- syntax ---
for f in install.sh src/network-auto.sh src/install-network-auto.sh src/uninstall-network-auto.sh src/lib/common.sh; do
  if bash -n "$ROOT/$f" 2>/dev/null; then ok "syntax $f"; else bad "syntax $f"; fi
done

# --- required files ---
for f in config/defaults.conf config/defaults.example.conf README.md SECURITY.md LICENSE VERSION; do
  [[ -f "$ROOT/$f" ]] && ok "exists $f" || bad "missing $f"
done

# --- config load ---
# shellcheck source=src/lib/common.sh
source "$ROOT/src/lib/common.sh"
netforge_load_config "$ROOT/config/defaults.conf"
[[ "$APP_NAME" == "NetForge" ]] && ok "APP_NAME" || bad "APP_NAME"
[[ "$DNS_SERVERS" == *"1.1.1.1"* ]] && ok "DNS_SERVERS" || bad "DNS_SERVERS"
[[ "$ETHERNET_METRIC" -lt "$WIFI_METRIC_ALONE" ]] && ok "metrics order" || bad "metrics order"

# --- congestion control helper (inline copy for unit test) ---
pick_cc() {
  if [[ -r /proc/sys/net/ipv4/tcp_available_congestion_control ]] \
    && grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    echo bbr
  else
    echo cubic
  fi
}
cc=$(pick_cc)
[[ "$cc" == "bbr" || "$cc" == "cubic" ]] && ok "pick_cc=$cc" || bad "pick_cc"

# --- nm_connection_type logic (mocked) ---
nm_connection_type() {
  case "$1" in
    802-3-ethernet|ethernet) echo ethernet ;;
    802-11-wireless|wifi) echo wifi ;;
    *) echo other ;;
  esac
}
[[ "$(nm_connection_type 802-11-wireless)" == "wifi" ]] && ok "nm wifi type" || bad "nm wifi type"
[[ "$(nm_connection_type 802-3-ethernet)" == "ethernet" ]] && ok "nm eth type" || bad "nm eth type"

# --- no personal data in repo ---
if grep -rEi 'knock|jonbailey|gmail|192\.168\.|password\s*=|api[_-]?key' \
  --include='*.sh' --include='*.conf' --include='*.md' "$ROOT" \
  --exclude-dir=tests --exclude-dir=.git 2>/dev/null; then
  bad "personal/secret pattern found"
else
  ok "no personal/secret patterns"
fi

# --- install paths ---
grep -q 'Pitchfork-and-Torch/netforge-linux' "$ROOT/install.sh" && ok "install.sh repo URL" || bad "install.sh repo URL"
grep -q 'netforge-network-auto' "$ROOT/src/install-network-auto.sh" && ok "systemd unit name" || bad "systemd unit"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]