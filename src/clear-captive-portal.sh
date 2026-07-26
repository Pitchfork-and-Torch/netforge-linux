#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
CONFIG_FILE="${REPO_ROOT}/config/defaults.conf"; RESTORE=false; PROBE_ONLY=false
while [[ $# -gt 0 ]]; do case "$1" in --restore) RESTORE=true; shift;; --probe-only) PROBE_ONLY=true; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) shift;; esac; done
netforge_load_config "$CONFIG_FILE"
echo "NetForge captive-portal recovery"
for u in http://captive.apple.com/hotspot-detect.html http://connectivitycheck.gstatic.com/generate_204 http://www.msftconnecttest.com/connecttest.txt; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 -L --max-redirs 0 "$u" 2>/dev/null || echo 000)
  echo "  [$code] $u"
done
if [[ "$RESTORE" == true ]]; then
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "Need sudo --restore" >&2; exit 1; }
  "$SCRIPT_DIR/network-auto.sh" --trigger captive-restore --config "$CONFIG_FILE"; exit 0
fi
[[ "$PROBE_ONLY" == true ]] && { echo "Probe-only"; exit 0; }
[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "Need sudo (or --probe-only)" >&2; exit 1; }
if command -v nmcli >/dev/null 2>&1; then
  while IFS= read -r CON; do
    [[ -z "$CON" ]] && continue
    nmcli connection modify "$CON" ipv4.dns "" ipv4.ignore-auto-dns no 2>/dev/null || true
    nmcli connection modify "$CON" ipv4.dns-over-tls no 2>/dev/null || true
    nmcli connection up "$CON" 2>/dev/null || true
    echo "  relaxed: $CON"
  done < <(nmcli -g NAME connection show --active 2>/dev/null)
fi
if command -v resolvectl >/dev/null 2>&1; then
  mkdir -p /etc/systemd/resolved.conf.d
  printf '[Resolve]\nDNSOverTLS=no\nDNS=%s\n' "${CAPTIVE_PORTAL_DNS:-1.1.1.1 8.8.8.8}" >/etc/systemd/resolved.conf.d/netforge-captive.conf
  systemctl restart systemd-resolved 2>/dev/null || true
fi
echo "After portal login: sudo $0 --restore"