#!/usr/bin/env bash
# Bootstrap installer — clone repo and run install-network-auto.sh
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Pitchfork-and-Torch/netforge-linux.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/netforge}"
BRANCH="${BRANCH:-main}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "NetForge requires root. Run: sudo $0" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Git is required. Install git and re-run." >&2
  exit 1
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "Updating $INSTALL_DIR ..."
  if ! git -C "$INSTALL_DIR" fetch --depth 1 origin "$BRANCH"; then
    echo "WARN: fetch failed (offline?). Using existing tree." >&2
  else
    if ! git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH"; then
      echo "WARN: fast-forward pull failed (local edits?). Re-cloning clean copy." >&2
      rm -rf "$INSTALL_DIR"
      git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$INSTALL_DIR"
    fi
  fi
else
  rm -rf "$INSTALL_DIR"
  echo "Cloning $REPO_URL (branch $BRANCH) ..."
  git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$INSTALL_DIR"
fi

if [[ ! -x "$INSTALL_DIR/src/install-network-auto.sh" ]]; then
  chmod +x "$INSTALL_DIR/src/install-network-auto.sh" 2>/dev/null || true
fi
if [[ ! -f "$INSTALL_DIR/src/install-network-auto.sh" ]]; then
  echo "Installer missing after clone: $INSTALL_DIR/src/install-network-auto.sh" >&2
  exit 1
fi

exec "$INSTALL_DIR/src/install-network-auto.sh"
