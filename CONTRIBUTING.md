# Contributing to NetForge for Linux

Thanks for helping improve NetForge.

## Before you start

- Test on a disposable VM or spare machine when possible (NetworkManager + systemd-resolved)
- Do **not** commit personal network data (IPs, SSIDs, MACs, hostnames, usernames in paths)
- Keep scripts idempotent — safe to run repeatedly
- Prefer read-only checks first: `./src/netforge-status.sh`

## Development setup

```bash
git clone https://github.com/Pitchfork-and-Torch/netforge-linux.git
cd netforge-linux
# status only (no changes)
./src/netforge-status.sh
# apply (requires root)
sudo ./src/install-network-auto.sh
```

Logs: `/root/.local/share/NetForge/network-auto.log` (or path documented in README).

## Pull requests

1. Fork and create a feature branch
2. Test install, manual run, status, and uninstall paths
3. Run ShellCheck locally if available: `shellcheck -S error -x src/*.sh install.sh`
4. Describe security/compat tradeoffs
5. One logical change per PR when possible

## Reporting issues

Include:

- Distro and version
- NetworkManager / systemd-resolved presence
- Ethernet, Wi-Fi, or VPN involved
- Redacted log lines from the NetForge log

## Code style

- `bash` with `set -euo pipefail`
- Use config under `config/` — never hardcode user paths
- Optional features gated by config flags
