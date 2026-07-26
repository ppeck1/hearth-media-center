# Troubleshooting Hearth

Start with:

```bash
/opt/hearth/deploy/fedora/doctor.sh
```

For machine-readable output:

```bash
/opt/hearth/deploy/fedora/doctor.sh --json > hearth-doctor.json
```

The report contains status, counts, and remediations—not credentials or personal filenames. A nonzero exit means at least one required appliance component failed.

## Startup and display

### Hearth does not start

Run `systemctl --user status hearth.service` and confirm `/opt/hearth/runtime/godot` and `/opt/hearth/launcher/project.godot` exist. Then inspect the redacted journal procedure below. Use `update.sh` to restore missing source-controlled files or roll back to its printed backup.

### Black screen or wrong resolution

Confirm a Wayland graphical session and 1920×1080 in GNOME Displays. Test with the TV’s overscan disabled. Run `/opt/hearth/launchers/hearth.sh` from the graphical media account only long enough to capture the error; do not run Godot as root.

### Wayland overlay limitations

Hearth intentionally does not force a privileged overlay above other applications. Use Home or Create+Options to close a translated destination. Steam and RetroArch own native controller exit behavior. A compositor may briefly expose the desktop during focus transitions.

## Controllers and the input bridge

### Controller not detected

Reconnect by cable, open System Health, and run `doctor.sh`. Check that the device appears to the active media user. Do not solve this with a root bridge or world-writable event devices.

### Bluetooth controller does not reconnect

Remove and re-pair it in GNOME Settings, confirm reconnection after reboot and sleep separately, and record both hardware rows. Bluetooth names and product IDs can differ from USB; keep match selectors specific.

### Duplicate controller inputs

Ensure only one Hearth/bridge process exists. Streaming and Plex should receive the temporary virtual keyboard; Steam and RetroArch should receive the physical controller natively. Stop any unrelated controller remapper before retesting.

### Controller remains captured after application exit

Use a keyboard Home key if available, then check `pgrep -af hearth_input_bridge` without sharing unredacted output. Stop the affected user process, not a system-wide root daemon. Reproduce with the bridge cleanup hardware rows.

### `/dev/uinput` permission failure

Run `sudo /opt/hearth/deploy/fedora/install-input-access.sh`, then log out and back in. `getfacl /dev/uinput` should grant the active local user access through `uaccess`; do not add a broad `input` group or mode `0666`.

## Destinations

### Netflix navigation fails

Confirm Chrome loaded `/opt/hearth/browser_extension`, reload Netflix, and retry from the browse page. Netflix can change its DOM without notice; record the page behavior and date without capturing account content.

### Streaming site changes break focus behavior

Test keyboard arrows first. If keyboard navigation also fails, the site changed independently of the controller bridge. Keep any selector fix limited to that destination and preserve the output allowlist.

### Plex does not start

Run `flatpak info tv.plex.PlexHTPC`, then launch the Flatpak directly as the media user. Reinstall or configure Plex outside Hearth; do not store its credentials in the repository.

### Steam does not start

Run `steam -gamepadui` in the graphical media session. Resolve package, sign-in, or GPU failures in Steam, then retry Hearth. Steam remains native input and should not use the bridge.

### RetroArch core missing

Open **Settings → Library & Launchers**. Uninstalled alternatives are disabled. Install the allowlisted core under `~/.config/retroarch/cores` or `/usr/lib64/libretro`; do not point the registry at an arbitrary shared object.

### Application does not return to Hearth

For browser/Plex, use Home or Create+Options. For Steam/RetroArch, use their native exit command. If a process hangs, the bridge escalates from TERM to KILL only for the supervised destination. Record the hang-recovery hardware test.

### Power commands fail

Confirm Zenity exists and the media user’s normal systemd/logind policy permits restart and poweroff. Do not make Hearth setuid and do not run its UI as root.

## Library and manifests

### ROM does not appear

Put it under a registered top-level alias in `/srv/library/games/roms`, confirm the media user can read it, then choose **Refresh Library** in the library drawer or reopen My Library. Check extension restrictions in `system-registry.json`.

### Empty or inaccessible library

An empty readable library produces a friendly empty state; an inaccessible library is a required diagnostic failure. Fix ownership for the media account without making private content world-readable.

### Artwork does not appear

Use `icon.png`/JPG/WebP for a folder tile, `wallpaper.*` for its background, or a same-stem image beside a ROM. Names are case-insensitive. Confirm the relevant setting is enabled and refresh the library.

### Invalid native PC manifest

Validate `/srv/library/games/pc/hearth-manifest.json` as JSON with schema version `1` and an `entries` array. Each executable must be an approved helper below `/opt/hearth/launchers`; JSON is not a command line.

## Collect useful logs safely

Capture only the current boot’s user service:

```bash
journalctl --user -u hearth.service -b --no-pager --output=short-iso > hearth-journal.txt
```

Before sharing:

1. Search for home paths, account names, URLs, network names, device serials, browser-profile paths, tokens, and personal filenames.
2. Replace private values with categories such as `[HOME]`, `[ROM]`, or `[ACCOUNT]`; do not merely blur screenshots.
3. Do not share browser logs, cookies, authentication databases, ROM inventories, or full `/dev/input/by-id` values.
4. Include the Hearth commit, Fedora version, session type, relevant diagnostic statuses, and exact reproduction steps.
5. Run the repository privacy checker on any fixture proposed for commit.
