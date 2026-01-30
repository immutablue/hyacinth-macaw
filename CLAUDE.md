# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hyacinth Macaw is Zach's personal custom build of [Immutablue](https://gitlab.com/immutablue/immutablue). It's based on the [immutablue-custom](https://gitlab.com/immutablue/immutablue-custom) template and adds personalized packages, configurations, and customizations.

**Key Features:**
- Based on Immutablue (Fedora Silverblue with sane defaults)
- Custom GNOME extensions and keybindings
- Window managers: dwm, qtile (source included for dwm/st)
- Terminal: kitty (replaces ptyxis)
- Home Assistant integration via keybindings
- ProtonVPN integration

## Build Commands

### Basic Build

```bash
make build                    # Build default image (based on Immutablue)
make all                      # Build and push
make check                    # Run shellcheck on post_install.sh
```

### Variant Flags

Inherit Immutablue variants by passing flags:

| Flag | Description | Base Image |
|------|-------------|------------|
| `CYAN=1` | NVIDIA GPU support | `immutablue:43-cyan` |
| `ASAHI=1` | Apple Silicon | `immutablue:43-asahi` |
| `KUBERBLUE=1` | Kubernetes | `kuberblue:43` |
| `TRUEBLUE=1` | ZFS support | `trueblue:43` |
| `LTS=1` | LTS kernel | `immutablue:43-lts` |
| `NIX=1` | Nix package manager | `immutablue:43-nix` |
| `KINOITE=1` | KDE Plasma | `immutablue:43-kinoite` |
| `SERICEA=1` | Sway | `immutablue:43-sericea` |
| `NUCLEUS=1` | Minimal (no GUI) | `immutablue:43-nucleus` |

**Examples:**
```bash
make CYAN=1 build             # NVIDIA variant
make ASAHI=1 build            # Apple Silicon variant
make LTS=1 build              # LTS kernel
make CYAN=1 LTS=1 build       # NVIDIA + LTS
```

### Other Commands

```bash
make VERSION=42 build         # Build for Fedora 42
make SET_AS_LATEST=1 build    # Also tag as :latest
make push                     # Push to registry
make iso                      # Build installation ISO
make rebase                   # Rebase current system to this image
make upgrade                  # Run rpm-ostree update
make clean                    # Clean build artifacts
```

## Directory Structure

```
hyacinth-macaw/
├── Containerfile             # Container build definition
├── Makefile                  # Build system
├── post_install.sh           # Post-install script (legacy, now in build/)
├── packages/
│   ├── packages.custom-50-hyacinth-macaw.yaml  # Custom packages
│   └── template.packages.custom-00-template.yaml
├── build/                    # Build scripts (run in order)
│   ├── 00-pre.sh
│   ├── 10-copy.sh            # Copy overlay files
│   ├── 20-add-repos.sh       # Add package repositories
│   ├── 30-install-packages.sh
│   ├── 40-uninstall-packages.sh
│   ├── 50-remove-files.sh
│   ├── 60-services.sh
│   ├── 90-post.sh            # Final customizations (dconf update, etc.)
│   └── 99-common.sh          # Shared functions
└── artifacts/
    └── overrides/            # Files copied to image root
        ├── etc/
        │   ├── dconf/db/local.d/hyacinth-macaw.conf  # GNOME settings
        │   ├── dconf/profile/user
        │   ├── sysctl.d/50-hyacinth-macaw.conf
        │   └── fuse.conf
        └── usr/
            ├── bin/dwm-start
            ├── libexec/immutablue/just/50-hyacinth-macaw.justfile
            ├── share/xsessions/dwm.desktop
            └── src/gitlab/
                ├── dwm/      # Patched dwm source
                ├── st/       # Patched st terminal source
                └── trayer-srg/
```

## Package Configuration

Packages are defined in `packages/packages.custom-50-hyacinth-macaw.yaml`:

### Key Sections

- `immutablue.repo_urls` - Additional RPM repositories
- `immutablue.rpm_gui.all` - GUI packages (GNOME extensions, kitty, rofi, etc.)
- `immutablue.rpm_cli.all` - CLI tools
- `immutablue.flatpak_user` - User Flatpak apps
- `immutablue.distrobox` - Distrobox container definitions

### Notable Packages

**GUI:**
- `kitty` - Terminal emulator (replaces ptyxis)
- `gnome-shell-extension-*` - Various GNOME extensions
- `proton-vpn-gnome-desktop` - ProtonVPN
- `qtile-wayland` - Qtile window manager
- `rofi` - Application launcher
- `picom` - Compositor for X11

**Included Source (for compilation):**
- `dwm` - Dynamic window manager (patched)
- `st` - Simple terminal (patched)
- `trayer-srg` - System tray

## dconf Settings

GNOME settings in `artifacts/overrides/etc/dconf/db/local.d/hyacinth-macaw.conf`:

- Custom keybindings (Ctrl+Alt+1-9 for Home Assistant switches)
- Screenshot binding (Print → Flameshot)
- Ctrl+Alt+H → htop in kitty

The dconf database is compiled during build via `dconf update` in `90-post.sh`.

## Custom Justfile Commands

Located at `/usr/libexec/immutablue/just/50-hyacinth-macaw.justfile`:

```bash
immutablue hyacinth_run_post_install   # Run post-install script
immutablue hyacinth_full_update        # Update immutablue + hyacinth-macaw
immutablue hyacinth_full_update_asahi  # Full update for Asahi
```

## Build Script Notes

### 90-post.sh

- Registers the custom justfile
- Replaces ptyxis with kitty symlink
- Builds Hugo docs
- Runs `dconf update` to compile GNOME settings

### Build Script Template

```bash
#!/bin/bash
set -euxo pipefail
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then
    source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"
fi
if [ -f "./99-common.sh" ]; then
    source "./99-common.sh"
fi

# Your build logic here
```

## Common Tasks

### Adding a Package

1. Edit `packages/packages.custom-50-hyacinth-macaw.yaml`
2. Add to appropriate section (`rpm_gui.all`, `rpm_cli.all`, etc.)
3. Rebuild: `make build`

### Adding a GNOME Setting

1. Edit `artifacts/overrides/etc/dconf/db/local.d/hyacinth-macaw.conf`
2. Use dconf path format: `[org/gnome/path/to/setting]`
3. Rebuild (dconf update runs automatically in 90-post.sh)

### Adding an Override File

1. Place file in `artifacts/overrides/` mirroring target path
2. Example: `artifacts/overrides/etc/myconfig.conf` → `/etc/myconfig.conf`

### Modifying dwm/st

Source is in `artifacts/overrides/usr/src/gitlab/`:
- Edit `dwm/config.h` or `st/config.h`
- Rebuild image
- Compile on target: `cd /usr/src/gitlab/dwm && sudo make clean install`

## Registry

Images are pushed to:
```
quay.io/immutablue/hyacinth-macaw:<tag>
```

Tags follow pattern: `<version>[-variant...]` (e.g., `43`, `43-asahi`, `43-cyan-lts`)
