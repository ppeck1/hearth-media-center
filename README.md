# Hearth Media Center

![Godot 4](https://img.shields.io/badge/Godot-4-478CBF?logo=godot-engine&logoColor=white)
![Fedora target](https://img.shields.io/badge/target-Fedora%20Linux-51A2DA?logo=fedora&logoColor=white)
![Controller first](https://img.shields.io/badge/input-controller%20first-F2A93B)

**A controller-first living-room launcher for personal games, local media, PC gaming, and streaming services.**

Hearth is a Godot 4 interface designed for a dedicated Fedora/Wayland media PC. It provides one cinematic, couch-friendly home screen while leaving emulation, media playback, PC gaming, and browser streaming to the applications built for them.

## Current interface

### Home

![Hearth Media Center home screen](docs/images/home.png)

The Home screen combines a live local clock with a clean, artwork-led carousel.

## What Hearth does

- Presents destinations in a wrap-around, controller-driven carousel.
- Discovers a personal ROM library and organizes known folder aliases into console families.
- Launches RetroArch games only through configured Libretro cores and validated library paths.
- Opens Steam Big Picture, Plex HTPC, and isolated Chrome app profiles for streaming services.
- Enables Chromium spatial navigation in streaming windows so translated D-pad arrows can move page focus.
- Keeps Netflix catalogue navigation tile-first; Select enters a tile's actions and Back returns to tile browsing.
- Keeps controller navigation active while Chrome streaming services or Plex are running.
- Returns focus to Hearth after a launched application exits.
- Provides editable PS5 DualSense and standard-remote input profiles.
- Keeps Arrow keys, Enter, and Escape available as recovery controls.
- Stores runtime profiles locally; no credentials, ROM inventory, or personal media data belongs in the repository.

## Interface

<table>
  <tr>
    <td width="50%"><img src="docs/images/streaming.png" alt="Streaming service carousel"></td>
    <td width="50%"><img src="docs/images/input-settings.png" alt="Editable controller and remote input settings"></td>
  </tr>
  <tr>
    <td align="center"><strong>Streaming destinations</strong></td>
    <td align="center"><strong>Controller and remote profiles</strong></td>
  </tr>
</table>

The screenshots are captured directly from the Godot project at 1920x1080 using [`capture_readme_screenshots.gd`](launcher/tests/capture_readme_screenshots.gd).

## Project status

| Area | Status |
| --- | --- |
| Godot launcher and carousel | Implemented and smoke-tested |
| ROM discovery and RetroArch launch validation | Implemented |
| PS5 / standard remote mapping UI | Implemented and smoke-tested |
| Backend-neutral translation core | Implemented with deterministic replay tests |
| Per-app `evdev` / `uinput` controller bridge | Implemented; requires target Fedora hardware QA |
| Turnkey Fedora installer | Not included; deployment contract is documented below |

Hearth is designed for the Fedora appliance described here, but the new controller profiles and cross-application bridge have not yet been validated with the final USB/Bluetooth hardware on that PC.

## Controls

| Action | PS5 default | Keyboard / remote default |
| --- | --- | --- |
| Browse | D-pad or left stick | Arrow keys |
| Select | Cross / south face button | Enter |
| Back | Circle / east face button | Escape |
| Previous / next page | L1 / R1, or L3 / R3 for fast tile paging | Page Up / Page Down |
| Menu | Options | Menu |
| Play / pause | Triangle while streaming; Touchpad inside Hearth | Media Play/Pause |
| Hearth home | PS / Guide, or Create + Options failsafe chord | Home |

Open **Settings**, choose an input source and profile, then select **Remap** beside an action. Profiles can be tested, reset, and saved without editing project files. Runtime settings are written to:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/hearth/input-profiles.json
```

Controllers of the same SDL type currently share their Godot-side profile. The Fedora bridge accepts joystick-capable event nodes and rejects keyboard-shaped and Hearth virtual devices; USB and Bluetooth identity pinning remains a target-hardware follow-up.

The live bridge is intentionally scoped to one DualSense-class controller for the first Fedora deployment. It matches the standard DualSense evdev vendor/product identity with SDL-name fallback, uses the saved PS5 profile, and leaves keyboard-style remotes directly connected to Chrome or Plex.

## Architecture

```mermaid
flowchart LR
    Menu["Menu and system registry"] --> Launcher["Godot launcher"]
    Library["Personal ROM library"] --> Launcher
    Profiles["Input profiles"] --> Launcher
    Launcher --> Scripts["Validated launch scripts"]
    Scripts --> Native["RetroArch / Steam"]
    Scripts --> Bridge["Per-app input bridge"]
    Profiles --> Bridge
    Bridge --> Stream["Plex / Chrome"]
```

The input implementation is intentionally split into small responsibilities:

- [`input_actions.gd`](launcher/scripts/input/input_actions.gd) defines semantic actions.
- [`input_event_codec.gd`](launcher/scripts/input/input_event_codec.gd) converts Godot events into canonical controls.
- [`input_profile_store.gd`](launcher/scripts/input/input_profile_store.gd) validates and persists profiles safely.
- [`input_manager.gd`](launcher/scripts/input/input_manager.gd) matches devices and routes actions.
- [`input_settings.gd`](launcher/scripts/settings/input_settings.gd) owns the settings and capture workflow.
- [`evdev_source.py`](input_bridge/hearth_input_bridge/evdev_source.py) discovers, filters, grabs, and decodes Linux controllers.
- [`uinput_sink.py`](input_bridge/hearth_input_bridge/uinput_sink.py) owns the allowlisted virtual keyboard.
- [`process_runner.py`](input_bridge/hearth_input_bridge/process_runner.py) supervises one Chrome or Plex session and guarantees cleanup.

## Quick start for development

Prerequisites:

- Godot 4
- Python 3.11 or newer
- `python3-evdev` for live Fedora controller translation
- Bash, `jq`, and `rg` for the complete Linux verification script

Clone the repository and start the launcher:

```bash
git clone https://github.com/ppeck1/hearth-media-center.git
cd hearth-media-center
godot --path launcher
```

The interface can be developed without ROMs, streaming credentials, or the production Fedora filesystem. Application launch commands will remain unavailable unless the `/opt/hearth` deployment contract is present.

## Fedora deployment contract

Hearth currently uses a deliberate fixed appliance layout rather than an installer:

| Purpose | Path |
| --- | --- |
| Installed project | `/opt/hearth` |
| Godot runtime | `/opt/hearth/runtime/godot` |
| Launch helpers | `/opt/hearth/launchers` |
| Personal ROM library | `/srv/library/games/roms` |
| Fedora Libretro cores | `/usr/lib64/libretro` |

A minimal manual deployment looks like:

```bash
sudo install -d /opt/hearth/runtime
sudo cp -a launcher launchers input_bridge browser_extension deploy /opt/hearth/
sudo install -m 0755 /path/to/godot /opt/hearth/runtime/godot
sudo chmod +x /opt/hearth/launchers/*.sh
sudo dnf install python3-evdev
sudo /opt/hearth/deploy/fedora/install-input-access.sh
/opt/hearth/launchers/hearth.sh
```

After logging out and back in, verify controller discovery and the active-user `/dev/uinput` permission without launching a streaming app:

```bash
PYTHONPATH=/opt/hearth/input_bridge python3 -m hearth_input_bridge probe
```

`hearth.sh` starts Godot with the Wayland display driver at 1920x1080. Optional destinations require their corresponding software:

| Destination | Runtime expectation |
| --- | --- |
| Browser streaming | `/usr/bin/google-chrome-stable` |
| Steam | `/usr/bin/steam` |
| RetroArch | `/usr/bin/retroarch` and compatible cores in `/usr/lib64/libretro` |
| Plex HTPC | Flatpak application `tv.plex.PlexHTPC` |
| Maintenance and power dialogs | `/usr/bin/zenity` |
| Restart / shutdown | `systemd` |

Streaming accounts, browser profiles, ROMs, BIOS files, cores, and application credentials are never bundled.

## Configuration

| File | Purpose |
| --- | --- |
| [`menu.json`](launcher/config/menu.json) | Home destinations and application commands |
| [`system-registry.json`](launcher/config/system-registry.json) | Console families, folder aliases, artwork, extensions, and Libretro cores |
| [`input-profiles-defaults.json`](launcher/config/input-profiles-defaults.json) | Built-in PS5 and remote mappings |
| [`app-input-policy.json`](launcher/config/app-input-policy.json) | Destination-to-adapter policy for the Fedora bridge |
| [`input-adapters.json`](launcher/config/input-adapters.json) | Semantic output definitions; contains no executable paths |
| [`personal-rom-library.md`](docs/personal-rom-library.md) | Library layout and launch-safety details |

## Verification

Run the complete Fedora/Linux checks:

```bash
./verify/verify-project.sh
```

That validates JSON schemas, artwork references, launcher syntax and executable modes, privacy boundaries, Python bridge behavior, and the Godot smoke test when `godot` is available.

Individual suites:

```bash
godot --headless --path launcher --import
godot --headless --path launcher --script res://tests/input_smoke.gd
python3 -m unittest discover -s input_bridge/tests
```

On the Windows editing machine, static checks are also available:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify\verify-project.ps1
```

## Input bridge boundary

Chrome streaming and Plex are launched through a short-lived, unprivileged Python supervisor. During that application session it:

- discovers joystick-capable `/dev/input/event*` nodes and rejects keyboard-shaped devices;
- exclusively grabs the controller to prevent duplicate browser Gamepad input;
- emits only configured, allowlisted keys through a temporary `uinput` keyboard;
- treats PS / Guide as a safe request to close the application and return to Hearth;
- releases the grab and virtual device on application exit, signal, disconnect, or bridge failure.

Steam and RetroArch bypass the bridge and keep native controller input. If `python3-evdev` or the `/dev/uinput` ACL is unavailable, the selected application still opens, but controller translation is disabled and a diagnostic is written to stderr. The bridge never runs as root; root is used only for the one-time, narrowly scoped udev rule. See the [bridge runtime notes](input_bridge/README.md).

## Known limitations

- Deployment is manual and assumes the fixed `/opt/hearth` and `/srv/library` paths.
- USB and Bluetooth identities for the final controller and remote still need target-hardware validation.
- Browser and Plex behavior depends on external applications and account setup.
- The controller bridge works without a visual HUD. GNOME Wayland cannot guarantee that a normal overlay window stays above a fullscreen application, so a visible cross-app HUD is not included in this phase.
- The active desktop user receives `/dev/uinput` access on this single-purpose appliance. That permission can create virtual input devices, so the media account should not run untrusted software.
- The maintenance destination is currently a supervised test dialog, not a full maintenance desktop.
- No software license file is currently included.

## Privacy, ownership, and trademarks

This repository intentionally excludes ROMs, media-library inventory, BIOS and save data, credentials, cookies, browser profiles, account details, and machine-specific configuration.

Brand names and service marks belong to their respective owners and are used only to identify compatible destinations. No software license has been published for this repository; copyright remains with the repository owner.
