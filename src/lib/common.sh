#!/usr/bin/env bash
set -euo pipefail
netforge_load_config() {
  local config_file="${1:-}"
  APP_NAME="NetForge"; DNS_SERVERS="1.1.1.1 1.0.0.1 8.8.8.8"; DNS_OVER_TLS="yes"
  ETHERNET_METRIC=100; WIFI_METRIC_ALONE=600; WIFI_METRIC_WITH_ETH=700
  LOCK_SECONDS=90; MAX_LOG_LINES=2000; DISABLE_SSHD=true; DISABLE_FILE_SHARE=true
  DISABLE_LLMNR=true; DISABLE_MDNS=false; HIGH_PERFORMANCE_POWER=true
  RESPECT_VPN=true; CAPTIVE_PORTAL_DNS="1.1.1.1 8.8.8.8"; CAPTIVE_AUTO_RESTORE_SECONDS=900
  if [[ -n "$config_file" && -f "$config_file" ]]; then source "$config_file"; fi
  DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/${APP_NAME}"
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && DATA_DIR="/var/lib/netforge"
  LOG_FILE="${DATA_DIR}/network-auto.log"; LOCK_FILE="${DATA_DIR}/network-auto.lock"; LAST_RUN_FILE="${DATA_DIR}/last-run.json"
}
netforge_log() { mkdir -p "$(dirname "$LOG_FILE")"; printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG_FILE"; }
netforge_rotate_log() {
  [[ -f "$LOG_FILE" ]] || return 0
  local count; count=$(wc -l <"$LOG_FILE" | tr -d ' ')
  (( count > MAX_LOG_LINES )) && { tail -n "$MAX_LOG_LINES" "$LOG_FILE" >"${LOG_FILE}.tmp"; mv "${LOG_FILE}.tmp" "$LOG_FILE"; }
}
netforge_acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local now mtime age; now=$(date +%s); mtime=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || stat -f %m "$LOCK_FILE"); age=$((now-mtime))
    (( age < LOCK_SECONDS )) && exit 0
  fi
  mkdir -p "$(dirname "$LOCK_FILE")"; : >"$LOCK_FILE"
}
netforge_release_lock() { rm -f "$LOCK_FILE"; }
netforge_require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then echo "Need root (or --dry-run): sudo $0 $*" >&2; exit 1; fi
}
netforge_is_vpn_type() { case "${1:-}" in vpn|wireguard|tun|tap|wg|openvpn|pptp|l2tp|ipsec) return 0;; esac; return 1; }
netforge_write_last_run() {
  local trigger="${1:-manual}" ver="unknown"
  mkdir -p "$(dirname "$LAST_RUN_FILE")"
  [[ -n "${REPO_ROOT:-}" && -f "$REPO_ROOT/VERSION" ]] && ver=$(tr -d '\r\n' <"$REPO_ROOT/VERSION")
  printf '{"timestamp":"%s","trigger":"%s","version":"%s"}\n' "$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" "$trigger" "$ver" >"$LAST_RUN_FILE"
}