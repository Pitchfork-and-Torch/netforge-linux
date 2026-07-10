#!/usr/bin/env bash
# NetForge Linux — network performance tuning and optional hardening
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_PATH=""

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

TRIGGER="manual"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --trigger) TRIGGER="${2:-manual}"; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

CONFIG_FILE="${CONFIG_PATH:-$REPO_ROOT/config/defaults.conf}"
netforge_load_config "$CONFIG_FILE"
netforge_require_root

netforge_acquire_lock
trap netforge_release_lock EXIT

netforge_rotate_log
netforge_log "=== ${APP_NAME} trigger=${TRIGGER} ==="

pick_congestion_control() {
  if [[ -r /proc/sys/net/ipv4/tcp_available_congestion_control ]] \
    && grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control; then
    echo bbr
  else
    echo cubic
  fi
}

apply_sysctl() {
  local cc kv
  cc=$(pick_congestion_control)
  local -a tunings=(
    "net.core.default_qdisc=fq"
    "net.ipv4.tcp_congestion_control=${cc}"
    "net.ipv4.tcp_fastopen=3"
    "net.ipv4.tcp_mtu_probing=1"
    "net.ipv4.tcp_slow_start_after_idle=0"
  )
  for kv in "${tunings[@]}"; do
    sysctl -w "$kv" >/dev/null 2>&1 || true
  done
  mkdir -p /etc/sysctl.d
  cat >/etc/sysctl.d/99-netforge.conf <<EOF
# NetForge — safe to remove if uninstalling
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = ${cc}
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
EOF
  netforge_log "sysctl applied (cc=${cc})"
}

apply_resolved() {
  command -v resolvectl >/dev/null 2>&1 || return 0
  mkdir -p /etc/systemd/resolved.conf.d
  cat >/etc/systemd/resolved.conf.d/netforge.conf <<EOF
[Resolve]
DNS=${DNS_SERVERS}
FallbackDNS=1.0.0.1 8.8.4.4
DNSOverTLS=${DNS_OVER_TLS}
DNSSEC=no
LLMNR=$([[ "$DISABLE_LLMNR" == true ]] && echo no || echo yes)
MulticastDNS=$([[ "$DISABLE_MDNS" == true ]] && echo no || echo yes)
EOF
  systemctl restart systemd-resolved 2>/dev/null || true
  netforge_log "systemd-resolved configured"
}

nm_connection_type() {
  local conn="$1"
  local dtype
  dtype=$(nmcli -g connection.type connection show "$conn" 2>/dev/null || true)
  case "$dtype" in
    802-3-ethernet|ethernet) echo ethernet ;;
    802-11-wireless|wifi) echo wifi ;;
    *) echo other ;;
  esac
}

nm_has_active_ethernet() {
  nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -qE '^(ethernet|802-3-ethernet):connected'
}

apply_networkmanager() {
  command -v nmcli >/dev/null 2>&1 || return 0

  local -a connections=()
  mapfile -t connections < <(nmcli -g NAME connection show --active 2>/dev/null | sort -u)
  if [[ ${#connections[@]} -eq 0 ]]; then
    mapfile -t connections < <(nmcli -g NAME connection show 2>/dev/null | sort -u)
  fi

  local has_eth=false
  nm_has_active_ethernet && has_eth=true

  local dns_csv conn ctype metric
  dns_csv="$(echo "$DNS_SERVERS" | tr ' ' ',')"

  for conn in "${connections[@]}"; do
    [[ -n "$conn" ]] || continue
    ctype=$(nm_connection_type "$conn")
    case "$ctype" in
      ethernet)
        metric=$ETHERNET_METRIC
        nmcli connection modify "$conn" ipv4.dns "$dns_csv" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes \
          ipv4.route-metric "$metric" ipv6.route-metric "$metric" 2>/dev/null || true
        netforge_log "Ethernet [$conn] metric=$metric"
        ;;
      wifi)
        if [[ "$has_eth" == true ]]; then
          metric=$WIFI_METRIC_WITH_ETH
        else
          metric=$WIFI_METRIC_ALONE
        fi
        nmcli connection modify "$conn" ipv4.dns "$dns_csv" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes \
          ipv4.route-metric "$metric" ipv6.route-metric "$metric" 2>/dev/null || true
        netforge_log "Wi-Fi [$conn] metric=$metric"
        ;;
      *)
        nmcli connection modify "$conn" ipv4.dns "$dns_csv" ipv4.ignore-auto-dns yes 2>/dev/null || true
        netforge_log "Other [$conn] DNS applied"
        ;;
    esac
  done

  local dev
  while IFS= read -r dev; do
    [[ -n "$dev" ]] || continue
    nmcli device reapply "$dev" 2>/dev/null || true
  done < <(nmcli -g DEVICE device status 2>/dev/null | sort -u)
}

apply_firewall() {
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q 'Status: active'; then
    ufw default deny incoming 2>/dev/null || true
    ufw default allow outgoing 2>/dev/null || true
    netforge_log "ufw defaults tightened (already active)"
  fi
}

apply_services() {
  if [[ "$DISABLE_SSHD" == true ]]; then
    for svc in ssh sshd; do
      systemctl disable --now "$svc" 2>/dev/null || true
    done
  fi
  if [[ "$DISABLE_FILE_SHARE" == true ]]; then
    for svc in smbd nmbd nfs-server; do
      systemctl disable --now "$svc" 2>/dev/null || true
    done
  fi
  if [[ "$DISABLE_MDNS" == true ]]; then
    systemctl disable --now avahi-daemon 2>/dev/null || true
  fi
}

apply_power() {
  [[ "$HIGH_PERFORMANCE_POWER" == true ]] || return 0
  if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl set performance 2>/dev/null || true
    netforge_log "power profile: performance"
  elif command -v tuned-adm >/dev/null 2>&1; then
    tuned-adm profile throughput-performance 2>/dev/null || true
    netforge_log "tuned: throughput-performance"
  fi
}

apply_sysctl
apply_resolved
apply_networkmanager
apply_firewall
apply_services
apply_power

resolvectl flush-caches 2>/dev/null || true
netforge_log "=== complete ==="