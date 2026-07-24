#!/usr/bin/env bash
# Temporarily relax NetForge DNS so captive portals can load. Re-run network-auto after login.
set -euo pipefail
echo "NetForge captive-portal recovery (temporary DNS relax)"
if command -v nmcli >/dev/null 2>&1; then
  CON=$(nmcli -t -f NAME,DEVICE connection show --active | head -1 | cut -d: -f1 || true)
  if [[ -n "${CON:-}" ]]; then
    echo "  active connection: $CON"
    nmcli connection modify "$CON" ipv4.dns "" ipv4.ignore-auto-dns no 2>/dev/null || true
    nmcli connection modify "$CON" ipv4.dns-over-tls no 2>/dev/null || true
    nmcli connection up "$CON" 2>/dev/null || true
    echo "  DNS left to auto/DHCP (DoT off if supported)"
  fi
elif command -v resolvectl >/dev/null 2>&1; then
  echo "  hint: sudo resolvectl revert <ifname>  then open the portal"
else
  echo "  no nmcli/resolvectl — clear DNS in Network settings, authenticate, re-run NetForge"
fi
echo "After portal login: sudo ./src/network-auto.sh"