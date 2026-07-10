# Security

NetForge modifies **local** Linux network settings. No telemetry, no cloud, no router access.

## Permissions

- **root** required for install, sysctl, resolved, NetworkManager, systemd

## Defaults to review

| Setting | Impact |
|---------|--------|
| `DISABLE_FILE_SHARE=true` | Stops Samba/NFS/Avahi services |
| `DISABLE_SSHD=true` | Disables SSH server |
| `DISABLE_MDNS=false` | Leaving Avahi on preserves printer/AirPlay-style discovery |

## Safe install

Clone and read `src/network-auto.sh` before running. Install only from [github.com/Pitchfork-and-Torch/netforge-linux](https://github.com/Pitchfork-and-Torch/netforge-linux). Prefer `./src/netforge-status.sh` (read-only) before elevating.

## Edge cases

| Situation | Guidance |
|-----------|----------|
| Captive portal (hotel/airport Wi-Fi) | Encrypted DNS (DoT) can block the portal page. Temporarily set `DNS_OVER_TLS=false` or pause automation, connect, then re-enable. |
| Corporate / always-on VPN | VPN metrics may override NetForge routing preference. Disable NetForge or raise Wi-Fi/Ethernet metrics in config if breaks. |
| Offline install | Bootstrap needs git clone once; later runs only touch local settings. |
| Multi-user machines | Install as root; logs under root or configured path — do not commit logs. |

## Uninstall

`sudo ./src/uninstall-network-auto.sh` — removes automation only.
