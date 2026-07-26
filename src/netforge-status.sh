#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
JSON=false; HTML_PATH=""; SKIP_DNS=false; CONFIG_FILE="${REPO_ROOT}/config/defaults.conf"
while [[ $# -gt 0 ]]; do case "$1" in --json) JSON=true; shift;; --html) HTML_PATH="$2"; shift 2;; --skip-dns-probe) SKIP_DNS=true; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) shift;; esac; done
netforge_load_config "$CONFIG_FILE"
VERSION=$(tr -d '\r' <"$REPO_ROOT/VERSION" 2>/dev/null || echo unknown)
TS=$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
if [[ "$JSON" == true ]]; then
  last="{}"; [[ -f "$LAST_RUN_FILE" ]] && last=$(cat "$LAST_RUN_FILE")
  printf '{"tool":"NetForge","version":"%s","timestamp":"%s","lastRun":%s}\n' "$VERSION" "$TS" "$last"; exit 0
fi
echo "NetForge status (read-only) - $TS"
echo "Version: $VERSION"
[[ -f "$LAST_RUN_FILE" ]] && { echo; echo "=== Last apply ==="; cat "$LAST_RUN_FILE"; echo; }
if command -v nmcli >/dev/null 2>&1; then echo "=== NM devices ==="; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status || true
elif command -v networksetup >/dev/null 2>&1; then echo "=== Services ==="; networksetup -listallnetworkservices 2>/dev/null || true
fi
echo; echo "=== DNS probes ==="
if [[ "$SKIP_DNS" == true ]]; then echo "(skipped)"; else
  for ip in $DNS_SERVERS; do
    if dig @"$ip" example.com +time=2 +tries=1 >/dev/null 2>&1; then echo "  $ip ok"; else echo "  $ip FAIL"; fi
  done
fi
echo; echo "=== Log ==="
[[ -f "$LOG_FILE" ]] && tail -n 8 "$LOG_FILE" || echo "(no log yet)"
if [[ -n "$HTML_PATH" ]]; then
  printf '<!DOCTYPE html><html><body style="background:#0b0f14;color:#e6edf3;font-family:sans-serif"><h1>NetForge</h1><p>%s %s</p></body></html>\n' "$VERSION" "$TS" >"$HTML_PATH"
  echo "HTML: $HTML_PATH"
fi
echo; echo "No settings were changed."