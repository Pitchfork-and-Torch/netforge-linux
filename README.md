# NetForge for Linux

**Automatic network performance tuning and optional hardening for Linux.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/Linux-NetworkManager-FCC624)](https://github.com/Pitchfork-and-Torch/netforge-linux)

Part of the **NetForge suite** — same philosophy as [Windows](https://github.com/Pitchfork-and-Torch/netforge-windows) and [macOS](https://github.com/Pitchfork-and-Torch/netforge-macos). See [SUITE.md](SUITE.md) for platform differences and related tools.

---

## Quick install

```bash
git clone https://github.com/Pitchfork-and-Torch/netforge-linux.git
cd netforge-linux
sudo ./src/install-network-auto.sh
```

Bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/Pitchfork-and-Torch/netforge-linux/main/install.sh | sudo bash
```

Review `install.sh` before piping to `bash`.

---

## What it does

| Area | Action |
|------|--------|
| **DNS** | Cloudflare + Google via NetworkManager + DNS-over-TLS via `systemd-resolved` |
| **Routing** | Lower route metric on Ethernet; higher on Wi-Fi when Ethernet is connected |
| **TCP** | BBR (or cubic fallback), fq, fast open, MTU probing |
| **Privacy** | Optional LLMNR off in resolved |
| **Firewall** | Tightens `ufw` defaults if ufw is already active |
| **Power** | Performance profile via `powerprofilesctl` or `tuned` |
| **Optional** | Disable `sshd`, Samba/NFS; Avahi only if `DISABLE_MDNS=true` |

**Triggers:** systemd on boot (30s delay) + NetworkManager dispatcher on interface `up`.

Logs: `/root/.local/share/NetForge/network-auto.log`

See [SECURITY.md](SECURITY.md).

### Status (read-only doctor)

```bash
./src/netforge-status.sh
```

Reports NetworkManager devices, DNS, routes, ufw, and recent log lines **without changing anything**.

---

## Suite

| Platform | Repo |
|----------|------|
| Windows | [netforge-windows](https://github.com/Pitchfork-and-Torch/netforge-windows) |
| Linux | [netforge-linux](https://github.com/Pitchfork-and-Torch/netforge-linux) |
| macOS | [netforge-macos](https://github.com/Pitchfork-and-Torch/netforge-macos) |

**Related:** [trench-coat](https://github.com/Pitchfork-and-Torch/trench-coat) (privacy routing) · [ghost-continuum](https://github.com/Pitchfork-and-Torch/ghost-continuum) (defense plane)

---

## Requirements

- NetworkManager (`nmcli`) recommended
- `systemd-resolved` for DNS-over-TLS
- root/sudo

---

## Configuration

Edit `config/defaults.conf` before install. See `config/defaults.example.conf`.

---

## Uninstall

```bash
sudo ./src/uninstall-network-auto.sh
```

---


## FAQ

### Will this break hotel / airport captive portals?

Encrypted DNS (DoT via systemd-resolved) can hide the portal page. Temporarily set `DNS_OVER_TLS=false` in config, pause automation, connect to the portal, then re-enable. See [SECURITY.md](SECURITY.md).

### Do I need NetworkManager?

Recommended. The scripts expect `nmcli` for adapter/DNS work. Other stacks may need manual adaptation.

### Can I inspect settings before elevating?

Yes:

```bash
./src/netforge-status.sh
```

### Is there telemetry?

No. Logs stay under `/var/log/netforge/` (or as documented in the scripts).

### Where do I report bugs?

[GitHub Issues](https://github.com/Pitchfork-and-Torch/netforge-linux/issues).

---
## License

MIT — see [LICENSE](LICENSE).

---

## Support the work

NetForge is **free and open source**. Bug reports and feature requests are welcome via [GitHub Issues](https://github.com/Pitchfork-and-Torch/netforge-linux/issues).