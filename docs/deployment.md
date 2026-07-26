# Fedora deployment and recovery

These commands target a dedicated Fedora Workstation living-room PC. Review each script before running it. The installer does not silently install optional applications or copy personal media.

## Prerequisites

- Fedora Workstation with a graphical media user.
- A trusted Hearth checkout.
- Godot 4.6.3 available as `godot`, `godot4`, or an explicit path.
- `git`, Bash, Python 3, `install`, `realpath`, and `systemd`.
- `python3-evdev` for translated controller destinations.

Steam, RetroArch, Plex HTPC, Chrome, and Zenity are optional by destination. The installer reports them but does not install them.

## Support boundary

| Classification | Scope |
| --- | --- |
| Production target | x86_64 Fedora Workstation, GNOME Wayland, 1920×1080, one local graphical media user |
| Automated | Source/configuration behavior, mocked Fedora lifecycle, Godot headless UI/data behavior, bridge cleanup models |
| Requires target validation | GPU/driver, television scaling, HDMI audio, USB/Bluetooth controller identity and reconnect, real application fullscreen/focus/exit |
| Unsupported for this alpha | Non-Fedora production installs, root-run input bridge, arbitrary manifest commands, database/cloud library replacement |

“Production target” describes engineering scope, not completed hardware certification. The target remains unvalidated until its [hardware matrix](hardware-validation.md) is signed.

## Install

Preview without changing the machine:

```bash
sudo ./deploy/fedora/install.sh --dry-run --godot /path/to/godot
```

Install:

```bash
sudo ./deploy/fedora/install.sh --godot /path/to/godot
```

The command creates `/opt/hearth`, `/srv/library/games/roms`, and `/srv/library/games/pc`; installs the active-user uinput rule; and installs a systemd user service for the media account. It does not overwrite an existing installation. Log out and back in after installation so the `/dev/uinput` ACL can refresh, then run:

```bash
/opt/hearth/deploy/fedora/doctor.sh
```

## Update and rollback

From the new trusted checkout:

```bash
sudo ./deploy/fedora/update.sh --godot /path/to/godot
```

The updater stages a complete source-controlled tree, copies the existing application into a timestamped `/opt/hearth-backups/` directory, swaps the staged tree into place, and runs diagnostics. It never writes the personal library or local XDG configuration.

If diagnostics reveal a regression:

```bash
systemctl --user stop hearth.service
sudo mv /opt/hearth /opt/hearth.failed
sudo cp -a /opt/hearth-backups/TIMESTAMP /opt/hearth
systemctl --user start hearth.service
```

Replace `TIMESTAMP` with the backup printed by `update.sh`. Keep `/opt/hearth.failed` until the rollback is confirmed, then remove it deliberately.

## Uninstall

Preview:

```bash
sudo ./deploy/fedora/uninstall.sh --dry-run
```

Remove the application, uinput files, and user service while preserving personal state:

```bash
sudo ./deploy/fedora/uninstall.sh
```

This preserves `/srv/library`, `~/.config/hearth`, `~/.config/media-kiosk`, and `/opt/hearth-backups`. Remove only Hearth’s local UI settings with the explicit option:

```bash
sudo ./deploy/fedora/uninstall.sh --remove-settings
```

The flag still preserves ROMs, BIOS files, saves, browser profiles, credentials, and media.

## Verification classes

| Class | Command or document | Meaning |
| --- | --- | --- |
| CI-safe | `HEARTH_GODOT=/path ./verify/verify-project.sh --ci` | Portable source, Python, Godot, docs, and privacy checks |
| Fedora-only | `/opt/hearth/verify/verify-project.sh --fedora` | CI-safe checks plus live `doctor.sh`; may fail until appliance dependencies are configured |
| Hardware-only | `./verify/verify-project.sh --hardware` and [hardware validation](hardware-validation.md) | Manual controller, TV, audio, suspend, fullscreen, app, and power evidence; never auto-passed |
