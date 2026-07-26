# Hearth Media Center

![Godot 4](https://img.shields.io/badge/Godot-4-478CBF?logo=godot-engine&logoColor=white)
![Fedora target](https://img.shields.io/badge/target-Fedora%20Linux-51A2DA?logo=fedora&logoColor=white)
![Controller first](https://img.shields.io/badge/input-controller%20first-F2A93B)

Hearth is a controller-first home screen for a living-room PC. It puts personal games, Steam Big Picture, Plex, streaming services, settings, and power controls behind one simple interface.

![Hearth home screen](docs/images/home.png)

## Start here

The Home screen has four destinations:

1. **Games** — browse the local library or open Steam Big Picture.
2. **Movies & TV** — open Plex or a streaming service from a scrollable 3×3 grid.
3. **Settings** — customize library folders, launchers, controllers, remotes, and desktop settings.
4. **Power** — restart or shut down the appliance.

Hearth is designed to work from a controller or ordinary remote. Arrow keys, Enter, Escape, and Home remain available as recovery controls.

## Interface tour

### Games

<table>
  <tr>
    <td width="50%"><img src="docs/images/games.png" alt="Games menu with My Library and Steam Big Picture"></td>
    <td width="50%"><img src="docs/images/library-overview.png" alt="Library overview showing recent and available games"></td>
  </tr>
  <tr>
    <td align="center"><strong>Choose My Library or Steam</strong></td>
    <td align="center"><strong>One-page library overview</strong></td>
  </tr>
  <tr>
    <td><img src="docs/images/library-system.png" alt="Scrollable game system grid with a folder tile"></td>
    <td><img src="docs/images/library-folder.png" alt="An opened library folder using its own wallpaper"></td>
  </tr>
  <tr>
    <td align="center"><strong>Systems remain one scrollable page</strong></td>
    <td align="center"><strong>Physical folders become browsable branches</strong></td>
  </tr>
</table>

The screenshot catalog uses fictional entries. Personal ROM names and local media inventories are never stored in this repository.

### Movies & TV

<table>
  <tr>
    <td width="50%"><img src="docs/images/streaming.png" alt="Movies and TV grid with nine visible destinations"></td>
    <td width="50%"><img src="docs/images/streaming-services.png" alt="Movies and TV service manager"></td>
  </tr>
  <tr>
    <td align="center"><strong>Nine destinations visible at once</strong></td>
    <td align="center"><strong>Add or remove services without editing files</strong></td>
  </tr>
</table>

### Settings and power

<table>
  <tr>
    <td width="50%"><img src="docs/images/settings.png" alt="Hearth Settings menu"></td>
    <td width="50%"><img src="docs/images/library-settings.png" alt="Library folder artwork wallpaper and launcher settings"></td>
  </tr>
  <tr>
    <td align="center"><strong>All configuration starts in Settings</strong></td>
    <td align="center"><strong>Folder and launcher choices</strong></td>
  </tr>
  <tr>
    <td><img src="docs/images/input-settings.png" alt="Editable controller and remote bindings"></td>
    <td><img src="docs/images/power.png" alt="Restart and shutdown menu"></td>
  </tr>
  <tr>
    <td align="center"><strong>Editable controller and remote profiles</strong></td>
    <td align="center"><strong>Power controls stay on the main screen</strong></td>
  </tr>
</table>

All screenshots are rendered directly from the Godot project at 1920×1080 by [`capture_readme_screenshots.gd`](launcher/tests/capture_readme_screenshots.gd). The library screenshots use a privacy-safe fixture.

## Add a personal game library

Hearth scans `/srv/library/games/roms` whenever **Games → My Library** opens. There is no import database or rescan command.

Create one top-level folder per system:

```text
/srv/library/games/roms/
├── n64/
├── nes/
├── snes/
├── genesis/
└── gamecube/
```

Subfolders are preserved:

```text
/srv/library/games/roms/n64/
├── icon.png
├── wallpaper.jpg
├── Multiplayer/
│   ├── icon.webp
│   ├── wallpaper.png
│   └── Example Game.z64
└── Example Adventure.z64
```

The two canonical media files are:

| File | Purpose |
| --- | --- |
| `icon.png`, `icon.jpg`, `icon.jpeg`, or `icon.webp` | Tile for that folder or native PC game |
| `wallpaper.png`, `wallpaper.jpg`, `wallpaper.jpeg`, or `wallpaper.webp` | Background while the item or folder is selected |

Names are case-insensitive. Child folders inherit the closest parent wallpaper. Legacy `folder`, `cover`, and `poster` tile names remain compatible.

Game-specific cover art can sit beside a ROM with the same filename stem:

```text
Example Adventure.z64
Example Adventure.png
```

See [Personal ROM library](docs/personal-rom-library.md) for aliases, artwork matching, RetroArch cores, and the native PC manifest.

## Customize Hearth from the couch

Open **Settings → Library & Launchers** to control:

- automatic folder icons;
- automatic `wallpaper.*` backgrounds;
- hierarchical or flat library browsing;
- fullscreen or windowed RetroArch launch;
- installed RetroArch core selection per system.

Open **Settings → Controllers and Remotes** to:

- choose the active input source;
- choose a PS5 or standard-remote profile;
- remap every semantic action;
- test, reset, and save the profile.

Movies & TV has its own **Manage Services** tile. It changes the grid immediately and saves the selection locally.

## Controls

| Action | PS5 default | Keyboard or remote default |
| --- | --- | --- |
| Browse | D-pad or left stick | Arrow keys |
| Select | Cross / south face button | Enter |
| Back | Circle / east face button | Escape |
| Previous / next screen | L1 / R1 or L3 / R3 | Page Up / Page Down |
| Menu | Options | Menu |
| Play / pause | Triangle or touchpad | Media Play/Pause |
| Return to Hearth | PS / Guide | Home |

## Run for development

Requirements:

- Godot 4;
- Python 3.11 or newer;
- Bash, `jq`, and `rg` for complete verification;
- `python3-evdev` only for the live Fedora controller bridge.

```bash
git clone https://github.com/OWNER/hearth-media-center.git
cd hearth-media-center
godot --path launcher
```

The interface runs without ROMs, credentials, or the production filesystem. External applications stay unavailable until their `/opt/hearth/launchers` helpers exist.

## Fedora appliance layout

| Purpose | Path |
| --- | --- |
| Installed project | `/opt/hearth` |
| Godot runtime | `/opt/hearth/runtime/godot` |
| Launch helpers | `/opt/hearth/launchers` |
| Personal ROM library | `/srv/library/games/roms` |
| Native PC catalog | `/srv/library/games/pc/hearth-manifest.json` |
| System Libretro cores | `/usr/lib64/libretro` |

A minimal manual deployment is:

```bash
sudo install -d /opt/hearth/runtime
sudo cp -a launcher launchers input_bridge browser_extension deploy /opt/hearth/
sudo install -m 0755 /path/to/godot /opt/hearth/runtime/godot
sudo chmod +x /opt/hearth/launchers/*.sh
sudo dnf install python3-evdev
sudo /opt/hearth/deploy/fedora/install-input-access.sh
/opt/hearth/launchers/hearth.sh
```

Optional destinations expect:

| Destination | Runtime |
| --- | --- |
| Browser streaming | `/usr/bin/google-chrome-stable` |
| Steam Big Picture | `/usr/bin/steam` |
| RetroArch games | `/usr/bin/retroarch` and installed Libretro cores |
| Plex | Flatpak `tv.plex.PlexHTPC` |
| Desktop and power dialogs | `/usr/bin/zenity` and `systemd` |

## Configuration reference

Start with the [Variable matrix](docs/variable-matrix.md). It lists every supported runtime setting, environment variable, menu field, system-registry field, PC manifest field, input-profile field, default, and storage path.

Primary source-controlled configuration:

| File | Purpose |
| --- | --- |
| [`menu.json`](launcher/config/menu.json) | Home sections, service destinations, settings, and power commands |
| [`system-registry.json`](launcher/config/system-registry.json) | Families, folder aliases, extensions, artwork, and Libretro cores |
| [`input-profiles-defaults.json`](launcher/config/input-profiles-defaults.json) | Built-in PS5 and remote mappings |
| [`app-input-policy.json`](launcher/config/app-input-policy.json) | Destination-to-input-adapter policy |
| [`input-adapters.json`](launcher/config/input-adapters.json) | Allowlisted semantic outputs |

Local UI settings are stored below `${XDG_CONFIG_HOME:-$HOME/.config}/hearth` and are written atomically.

## How application launching stays bounded

- RetroArch receives only an installed `*_libretro.so` filename and a ROM below `/srv/library/games/roms`.
- Native PC manifest entries may call only helpers below `/opt/hearth/launchers`.
- Streaming and Plex run through a short-lived input bridge that releases devices on exit, failure, or disconnect.
- The bridge emits only configured, allowlisted keys and never runs as root.
- Browser profiles, credentials, ROMs, BIOS files, saves, and media inventory stay outside the repository.

## Verify a change

Run everything:

```bash
PATH="/opt/hearth/runtime:$PATH" ./verify/verify-project.sh
```

Or run individual suites:

```bash
godot --headless --path launcher --import
godot --headless --path launcher --script res://tests/input_smoke.gd
godot --headless --path launcher --script res://tests/library_smoke.gd
godot --headless --path launcher --script res://tests/library_browser_smoke.gd
godot --headless --path launcher --script res://tests/library_settings_smoke.gd
python3 -m unittest discover -s input_bridge/tests
```

The complete verifier checks JSON schemas, artwork references, executable permissions, launcher syntax, privacy boundaries, bridge behavior, settings persistence, folder media discovery, and Godot scene parsing.

## Current limitations

- Deployment is manual and assumes the fixed `/opt/hearth` and `/srv/library` appliance paths.
- USB and Bluetooth identities still require validation on each target controller/remote combination.
- Streaming behavior depends on external sites, applications, and active subscriptions.
- GNOME Wayland cannot guarantee a persistent overlay above every fullscreen application.
- No software license has been published yet; copyright remains with the repository owner.

Brand names and service marks belong to their respective owners and are used only to identify compatible destinations.
