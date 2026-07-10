#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/defaults.conf"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
netforge_load_config "$CONFIG_FILE"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

systemctl disable --now netforge-network-auto.service 2>/dev/null || true
rm -f /etc/systemd/system/netforge-network-auto.service
rm -f /etc/NetworkManager/dispatcher.d/99-netforge
systemctl daemon-reload

echo "${APP_NAME} systemd service and NM dispatcher removed."
echo "Files in ${INSTALL_DIR:-/opt/netforge}, sysctl, resolved, and NM settings were not reverted."
echo "Remove /etc/sysctl.d/99-netforge.conf and /etc/systemd/resolved.conf.d/netforge.conf manually if desired."