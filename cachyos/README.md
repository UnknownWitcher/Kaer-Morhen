# cachyos

Personal configuration files, scripts, and system utilities for my [CachyOS](https://cachyos.org/) setup.

## Structure

```
cachyos/
├── scripts/        # Shell scripts and automation utilities
├── config/         # Dotfiles and application config snippets
├── udev/           # udev rules and hwdb overrides
└── notes/          # Setup notes, troubleshooting logs, gotchas
```

## System

| | |
|---|---|
| **OS** | CachyOS x86_64 |
| **Kernel** | Linux 6.19.10-1-cachyos |
| **DE** | KDE Plasma 6.6.3 |
| **WM** | KWin (Wayland) |
| **Terminal** | Konsole 25.12.3 |
| **Shell** | fish 4.6.0 (interactive) / Bash (scripts) |
| **CPU** | AMD Ryzen 5 5600X |
| **GPU** | NVIDIA GeForce RTX 3070 |
| **RAM** | 15.52 GiB |
| **Root (`/`)** | btrfs |
| **Home (`/home`)** | ext4 |
| **Locale** | en_GB.UTF-8 |
| **Display** | Dual MSI G241, 1920×1080 24" @ 144Hz |
| **Homelab** | Unraid (*Asgard*) |
| **Network** | Pi-hole (*Pi 4 Model B*), Nginx Proxy Manager |

## Highlights

TBD

## Notes

I like to keep as much of my setup as portable and predictable as I can, with that said:

- This repo is personal and opinionated — things here work for my specific setup and may need tweaking for yours.
- Apps and scripts that interact with my main system (*Homelab*, *Pi-hole* etc.) will live in a separate folder.
- Scripts are written in Bash even though fish is the interactive shell.
- Scripts assume a CachyOS / Arch-based environment with `systemd`.
- Script dependencies and usage will be noted at the top of each file or bundled with a readme.

YMMV on other distros.

---

*This is part of a broader personal infrastructure setup.More stuff to come.*
