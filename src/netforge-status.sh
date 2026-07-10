#!/usr/bin/env bash
# Read-only NetForge health report for Linux (no system changes).
set -euo pipefail

echo "NetForge status (read-only) — $(date -Iseconds)"
echo

echo "=== NetworkManager devices ==="
if command -v nmcli >/dev/null 2>&1; then
  nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status || true
  echo
  echo "=== DNS (nmcli) ==="
  nmcli dev show 2>/dev/null | grep -E 'IP4\.DNS|IP4\.DOMAIN|GENERAL\.DEVICE|GENERAL\.CONNECTION' | head -n 40 || true
else
  echo "(nmcli not found)"
fi

echo
echo "=== systemd-resolved ==="
if command -v resolvectl >/dev/null 2>&1; then
  resolvectl status 2>/dev/null | head -n 50 || true
elif command -v systemd-resolve >/dev/null 2>&1; then
  systemd-resolve --status 2>/dev/null | head -n 50 || true
else
  echo "(resolved tools not found)"
fi

echo
echo "=== Default routes ==="
ip -4 route 2>/dev/null | head -n 20 || true

echo
echo "=== ufw (if present) ==="
if command -v ufw >/dev/null 2>&1; then
  ufw status verbose 2>/dev/null || true
else
  echo "(ufw not installed)"
fi

echo
echo "=== Log tail ==="
LOG="${HOME}/.local/share/NetForge/network-auto.log"
ROOTLOG="/root/.local/share/NetForge/network-auto.log"
if [[ -f "$LOG" ]]; then
  echo "Log: $LOG"
  tail -n 8 "$LOG" || true
elif [[ -f "$ROOTLOG" ]]; then
  echo "Log: $ROOTLOG"
  tail -n 8 "$ROOTLOG" || true
else
  echo "(no NetForge log yet)"
fi

echo
echo "No settings were changed."
