# Linux packaging notes (NetForge v2)

## systemd

`install-network-auto.sh` installs NetworkManager dispatcher / systemd units as designed in v1. Prefer that path for end users.

## Distribution packages (guidance)

| Format | Notes |
|--------|--------|
| **deb** | Package scripts under `/usr/lib/netforge`, config under `/etc/netforge/defaults.conf`, postinst call install |
| **rpm** | Same layout; use `%post` for unit enable |
| **AUR** | `PKGBUILD` that clones tagged release and runs install as optional |

Core apply path must remain **offline-capable** after install. No package should add telemetry.

## Checksums

```bash
sha256sum netforge-linux-2.0.0.tar.gz
```
