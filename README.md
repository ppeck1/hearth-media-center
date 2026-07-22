# Hearth Media Center

Hearth Media Center is a controller-first, Linux-native interface for games, local media applications, PC gaming, and streaming services. It presents each destination as a cinematic floating carousel while leaving emulation and media playback to the applications designed for them.

![Hearth Media Center home screen](docs/images/home.png)

![Hearth Media Center streaming screen](docs/images/streaming.png)

## Highlights

- Controller-first navigation with keyboard recovery controls
- Floating, wrap-around carousel with transparent artwork and neon focus cues
- Automatic organization of locally configured game systems and collections
- Launch-and-return integration for RetroArch, Steam Big Picture, Plex HTPC, and browser-based streaming services
- Clear unavailable-state messages when an emulator core or launcher is not installed
- Local-only application and library configuration

## Controls

| Action | Controller | Keyboard |
| --- | --- | --- |
| Browse | D-pad or left stick | Arrow keys |
| Select | Cross / south face button | Enter |
| Back | Circle / east face button | Escape |

USB and Bluetooth controllers use the same standard gamepad mappings.

## Project structure

- `launcher/` — Godot interface, configuration, and visual assets
- `launchers/` — application and game-launch helper scripts
- `verify/` — static project and privacy checks
- `docs/` — project documentation and screenshots

## Development

The launcher targets Godot 4 on Linux. Open `launcher/project.godot` in Godot or run:

```bash
godot --path launcher
```

Run the repository checks before publishing or deploying changes:

```bash
./verify/verify-project.sh
```

On a Windows editing machine, run the equivalent local checks with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify\verify-project.ps1
```

## Privacy and repository boundaries

This repository intentionally contains no ROMs, media-library inventory, BIOS or save data, credentials, browser profiles, cookies, account details, or login data. Private storage locations and application access are configured only on the machine running Hearth Media Center.

Brand names and service marks belong to their respective owners and are used only to identify compatible destinations.
