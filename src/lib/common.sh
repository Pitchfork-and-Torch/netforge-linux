#!/usr/bin/env bash
# Shared helpers for NetForge Linux

set -euo pipefail

netforge_load_config() {
  local config_file="${1:-}"
  APP_NAME="NetForge"
  DNS_SERVERS="1.1.1.1 1.0.0.1 8.8.8.8"
  DNS_OVER_TLS="yes"
  ETHERNET_METRIC=100
  WIFI_METRIC_ALONE=600
  WIFI_METRIC_WITH_ETH=700
  LOCK_SECONDS=90
  MAX_LOG_LINES=2000
  DISABLE_SSHD=true
  DISABLE_FILE_SHARE=true
  DISABLE_LLMNR=true
  DISABLE_MDNS=false
  HIGH_PERFORMANCE_POWER=true

  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi

  DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/${APP_NAME}"
  LOG_FILE="${DATA_DIR}/network-auto.log"
  LOCK_FILE="${DATA_DIR}/network-auto.lock"
}

netforge_log() {
  local msg="$1"
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" >>"$LOG_FILE"
}

netforge_rotate_log() {
  [[ -f "$LOG_FILE" ]] || return 0
  local count
  count=$(wc -l <"$LOG_FILE" | tr -d ' ')
  if (( count > MAX_LOG_LINES )); then
    tail -n "$MAX_LOG_LINES" "$LOG_FILE" >"${LOG_FILE}.tmp"
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
  fi
}

netforge_acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local age now mtime
    now=$(date +%s)
    mtime=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || stat -f %m "$LOCK_FILE")
    age=$((now - mtime))
    if (( age < LOCK_SECONDS )); then
      exit 0
    fi
  fi
  mkdir -p "$(dirname "$LOCK_FILE")"
  : >"$LOCK_FILE"
}

netforge_release_lock() {
  rm -f "$LOCK_FILE"
}

netforge_require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "NetForge requires root. Re-run with: sudo $0 $*" >&2
    exit 1
  fi
}