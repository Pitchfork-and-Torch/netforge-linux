#!/usr/bin/env bash
# NetForge Linux v2 - dry-run, RESPECT_VPN, metrics/DNS/sysctl
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_PATH=""; DRY_RUN=false; TRIGGER="manual"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --trigger) TRIGGER="${2:-manual}"; shift 2 ;;
    --config) CONFIG_PATH="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) echo "Usage: $0 [--dry-run] [--config path] [--trigger name]"; exit 0 ;;
    *) shift ;;
  esac
done
CONFIG_FILE="${CONFIG_PATH:-$REPO_ROOT/config/defaults.conf}"
netforge_load_config "$CONFIG_FILE"
plan() { echo "  [would] $*"; }
if [[ "$DRY_RUN" == true ]]; then
  echo "NetForge dry-run (no changes) - config: $CONFIG_FILE"
else
  netforge_require_root
  netforge_acquire_lock
  trap netforge_release_lock EXIT
  netforge_rotate_log
  netforge_log "=== ${APP_NAME} v2 trigger=${TRIGGER} ==="
fi
pick_cc() {
  if [[ -r /proc/sys/net/ipv4/tcp_available_congestion_control ]] && grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control; then echo bbr; else echo cubic; fi
}
apply_sysctl() {
  local cc; cc=$(pick_cc)
  if [[ "$DRY_RUN" == true ]]; then plan "sysctl qdisc=fq cc=$cc fastopen"; return 0; fi
  sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
  sysctl -w "net.ipv4.tcp_congestion_control=${cc}" >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_mtu_probing=1 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true
  mkdir -p /etc/sysctl.d
  cat >/etc/sysctl.d/99-netforge.conf <<EOF
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
  if [[ "$DRY_RUN" == true ]]; then plan "resolved DNS=${DNS_SERVERS} DNSOverTLS=${DNS_OVER_TLS}"; return 0; fi
  mkdir -p /etc/systemd/resolved.conf.d
  cat >/etc/systemd/resolved.conf.d/netforge.conf <<EOF
[Resolve]
DNS=${DNS_SERVERS}
FallbackDNS=1.0.0.1 8.8.4.4
DNSOverTLS=${DNS_OVER_TLS}
DNSSEC=no
LLMNR=$([[ "${DISABLE_LLMNR:-true}" == true ]] && echo no || echo yes)
MulticastDNS=$([[ "${DISABLE_MDNS:-false}" == true ]] && echo no || echo yes)
EOF
  systemctl restart systemd-resolved 2>/dev/null || true
  netforge_log "systemd-resolved configured"
}
nm_type() {
  local dtype; dtype=$(nmcli -g connection.type connection show "$1" 2>/dev/null || true)
  case "$dtype" in
    802-3-ethernet|ethernet) echo ethernet ;;
    802-11-wireless|wifi) echo wifi ;;
    vpn|wireguard|wg-quick|tun|tap|pptp|l2tp|ipsec|openvpn) echo vpn ;;
    *) echo other ;;
  esac
}
apply_nm() {
  command -v nmcli >/dev/null 2>&1 || return 0
  local -a connections=()
  mapfile -t connections < <(nmcli -g NAME connection show --active 2>/dev/null | sort -u)
  [[ ${#connections[@]} -eq 0 ]] && mapfile -t connections < <(nmcli -g NAME connection show 2>/dev/null | sort -u)
  local has_eth=false
  nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -qE '^(ethernet|802-3-ethernet):connected' && has_eth=true
  local dns_csv conn ctype metric
  dns_csv="$(echo "$DNS_SERVERS" | tr ' ' ',')"
  for conn in "${connections[@]}"; do
    [[ -n "$conn" ]] || continue
    ctype=$(nm_type "$conn")
    if [[ "$ctype" == vpn && "${RESPECT_VPN:-true}" == true ]]; then
      if [[ "$DRY_RUN" == true ]]; then plan "skip VPN [$conn]"; else netforge_log "RespectVpn: skip [$conn]"; fi
      continue
    fi
    case "$ctype" in
      ethernet) metric=$ETHERNET_METRIC ;;
      wifi) if [[ "$has_eth" == true ]]; then metric=$WIFI_METRIC_WITH_ETH; else metric=$WIFI_METRIC_ALONE; fi ;;
      *) metric="" ;;
    esac
    if [[ "$DRY_RUN" == true ]]; then plan "NM [$conn] type=$ctype metric=${metric:-n/a} dns=$dns_csv"; continue; fi
    if [[ -n "$metric" ]]; then
      nmcli connection modify "$conn" ipv4.dns "$dns_csv" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes \
        ipv4.route-metric "$metric" ipv6.route-metric "$metric" 2>/dev/null || true
    else
      nmcli connection modify "$conn" ipv4.dns "$dns_csv" ipv4.ignore-auto-dns yes 2>/dev/null || true
    fi
    netforge_log "NM [$conn] type=$ctype"
  done
  if [[ "$DRY_RUN" != true ]]; then
    while IFS= read -r dev; do [[ -n "$dev" ]] && nmcli device reapply "$dev" 2>/dev/null || true
    done < <(nmcli -g DEVICE device status 2>/dev/null | sort -u)
  fi
}
apply_services() {
  if [[ "${DISABLE_SSHD:-true}" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then plan "disable ssh/sshd"; else for s in ssh sshd; do systemctl disable --now "$s" 2>/dev/null || true; done; fi
  fi
  if [[ "${DISABLE_FILE_SHARE:-true}" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then plan "disable smbd/nmbd/nfs"; else for s in smbd nmbd nfs-server; do systemctl disable --now "$s" 2>/dev/null || true; done; fi
  fi
}
apply_sysctl; apply_resolved; apply_nm; apply_services
if [[ "$DRY_RUN" == true ]]; then echo "Dry-run complete. No settings changed."; exit 0; fi
resolvectl flush-caches 2>/dev/null || true
netforge_write_last_run "$TRIGGER"
netforge_log "=== complete ==="