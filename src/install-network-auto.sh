#!/usr/bin/env bash
# Install NetForge Linux (systemd + NetworkManager dispatcher)
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

INSTALL_DIR="${INSTALL_DIR:-/opt/netforge}"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a "$REPO_ROOT/." "$INSTALL_DIR/"
rm -rf "$INSTALL_DIR/.git" "$INSTALL_DIR/dist" 2>/dev/null || true

chmod +x "$INSTALL_DIR/src/network-auto.sh"
chmod +x "$INSTALL_DIR/src/install-network-auto.sh"
chmod +x "$INSTALL_DIR/src/uninstall-network-auto.sh"
chmod +x "$INSTALL_DIR/src/lib/common.sh"

# systemd boot service
cat >/etc/systemd/system/netforge-network-auto.service <<EOF
[Unit]
Description=NetForge network optimization (boot)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=${INSTALL_DIR}/src/network-auto.sh --trigger boot --config ${INSTALL_DIR}/config/defaults.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# NetworkManager connect hook
mkdir -p /etc/NetworkManager/dispatcher.d
cat >/etc/NetworkManager/dispatcher.d/99-netforge <<EOF
#!/bin/bash
[[ "\$2" == "up" ]] || exit 0
sleep 10
${INSTALL_DIR}/src/network-auto.sh --trigger network-connect --config ${INSTALL_DIR}/config/defaults.conf
EOF
chmod +x /etc/NetworkManager/dispatcher.d/99-netforge

systemctl daemon-reload
systemctl enable netforge-network-auto.service
systemctl start netforge-network-auto.service || true

DATA_DIR="/root/.local/share/${APP_NAME}"
mkdir -p "$DATA_DIR"
printf '[%s] Installed systemd service + NM dispatcher -> %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$INSTALL_DIR" >>"$DATA_DIR/network-auto.log"

echo ""
echo "${APP_NAME} installed successfully."
echo "  Install dir:  $INSTALL_DIR"
echo "  Boot service: netforge-network-auto.service"
echo "  NM hook:      /etc/NetworkManager/dispatcher.d/99-netforge"
echo "  Log file:     ${DATA_DIR}/network-auto.log"
echo ""
echo "Run manually:  sudo ${INSTALL_DIR}/src/network-auto.sh --trigger manual"
echo ""