# Hearth Media Center

Hearth is a simple, controller-first home screen for a living-room PC. It brings games, Steam, Plex, streaming services, settings, and power controls together in one place.

![Hearth home screen](docs/images/home.png)

> **Early software:** Hearth is an alpha for Fedora Linux. Controller support has been fully tested only with Netflix so far. Other services, Plex, Steam, RetroArch, controllers, and remotes may need adjustment; controller navigation is not yet perfect.

## What you need to know

You normally do **not** need to edit settings files or use a terminal. From Hearth:

1. Open **Games → My Library** to see your games.
2. Open **Movies & TV → Manage Services** to show or hide streaming services.
3. Open **Settings → Library & Launchers** to change artwork, folders, and game-launch options.
4. Open **Settings → Controllers and Remotes** to select or remap a controller or remote.

Use the arrows (or controller D-pad) to move, **Enter** (or the controller’s bottom face button) to choose, and **Escape** (or the right face button) to go back. Press **F11** if you need to switch Hearth between fullscreen and windowed mode.

## Screens at a glance

<table>
  <tr>
    <td width="50%"><img src="docs/images/games.png" alt="Games menu"></td>
    <td width="50%"><img src="docs/images/library-overview.png" alt="Sample game library overview"></td>
  </tr>
  <tr><td align="center">Games</td><td align="center">Sample library</td></tr>
  <tr>
    <td><img src="docs/images/streaming.png" alt="Movies and TV menu"></td>
    <td><img src="docs/images/settings.png" alt="Settings menu"></td>
  </tr>
  <tr><td align="center">Movies &amp; TV</td><td align="center">Settings</td></tr>
</table>

The library images below are freshly captured from a built-in sample collection. They contain no ROM names, game files, account details, or other personal-library information.

<table>
  <tr>
    <td width="50%"><img src="docs/images/library-system.png" alt="Sample system library"></td>
    <td width="50%"><img src="docs/images/library-folder.png" alt="Sample library folder with wallpaper"></td>
  </tr>
  <tr><td align="center">Folders stay browsable</td><td align="center">Folder wallpaper</td></tr>
  <tr>
    <td><img src="docs/images/library-settings.png" alt="Library settings"></td>
    <td><img src="docs/images/input-settings.png" alt="Controller and remote settings"></td>
  </tr>
  <tr><td align="center">Library &amp; launcher settings</td><td align="center">Controller &amp; remote settings</td></tr>
</table>

## Add games to your library

Hearth looks in one place: `/srv/library/games/roms`. Make a folder for each system, then put your own game files inside it. Open **Games → My Library** after copying files; Hearth scans automatically. Use **Refresh Library** in the library drawer if Hearth is already open.

For example:

```text
/srv/library/games/roms/
├── nes/
│   └── My Game.nes
├── n64/
│   └── My Game.z64
└── genesis/
    └── My Game.bin
```

Use names Hearth recognizes for the system folder. Common examples are `nes`, `snes`, `n64`, `gamecube`, `genesis`, `dreamcast`, `ps1`, `ps2`, `mame`, and `arcade`. A folder with an unfamiliar name is still shown under **Unmapped Library**; nothing is silently deleted or moved.

You can make subfolders for collections, such as `Multiplayer`, `Favorites`, or `Kids`. Hearth preserves those folders on screen.

```text
/srv/library/games/roms/n64/
├── Multiplayer/
│   ├── Mario Kart 64.z64
│   └── icon.png
├── Favorites/
│   └── Star Fox 64.z64
└── icon.jpg
```

Hearth only reads this folder. It does not upload games, rename them, or keep an online list of what you own.

### Add icons and game covers

Hearth supports `.png`, `.jpg`, `.jpeg`, and `.webp` pictures. Capital letters do not matter.

- To give a **folder** its own tile image, place `icon.png` (or `icon.jpg`, `.jpeg`, or `.webp`) in that folder.
- To give a **game** its own cover, put an image beside the game with the same name. For example, `Mario Kart 64.z64` uses `Mario Kart 64.png`.
- If you have older artwork named `folder`, `cover`, or `poster`, Hearth will use it too.
- Without a named image, the default setting can use the first normal picture it finds in the folder.

### Add wallpapers

Put `wallpaper.png`, `wallpaper.jpg`, `wallpaper.jpeg`, or `wallpaper.webp` in a system folder or any subfolder. Hearth uses it as the background when that folder is selected.

```text
/srv/library/games/roms/n64/
├── icon.png
├── wallpaper.jpg
└── Multiplayer/
    ├── icon.png
    ├── wallpaper.webp
    └── Mario Kart 64.z64
```

If a subfolder has no wallpaper, it inherits the closest wallpaper above it. A wide 16:9 image usually looks best, but any supported image works.

For native PC games, use `/srv/library/games/pc/hearth-manifest.json`; the full, cautious setup is in [Personal PC and ROM library details](docs/personal-rom-library.md). The manifest may only call a dedicated Hearth launcher, not any arbitrary program.

## Settings, explained simply

### Library & Launchers

Open **Settings → Library & Launchers**.

- **Game artwork:** `Smart` is the recommended default. It avoids harsh cropping when possible. Choose **Show full image** to never crop, or **Fill tile** to fill every card.
- **Folder artwork:** turn it off, use only named `icon.*`/legacy names, or use named artwork and then the first picture found. The last option is the default.
- **Folder wallpapers:** turn this off if you do not want `wallpaper.*` files to change the background.
- **Keep subfolders:** keep this on to browse folders as folders. Turn it off for one long list within each system.
- **RetroArch fullscreen:** choose whether games open fullscreen or in a window.
- **Emulator/core choice:** leave a system on **Automatic** unless a game needs a different installed core. Hearth only offers compatible cores it can find.

### Controllers and remotes

Open **Settings → Controllers and Remotes**. Choose the active controller or remote profile, test buttons, then save it. You can remap navigation, Select, Back, Home, Menu, Play/Pause, and page movement. Keyboard recovery controls always remain available: arrow keys, Enter, Escape, Home, and F11.

Netflix is the only streaming destination whose controller support has been fully tested. Treat every other external app as a work in progress, especially when using a different controller or a keyboard-style infrared remote.

### Movies & TV

Open **Movies & TV → Manage Services**, check the services you want to see, and save. Plex is always displayed. Signing in happens in the service’s own app or browser profile; Hearth never asks for or stores your streaming password.

### Other settings

- **Fullscreen / Windowed:** changes Hearth itself. F11 does the same thing.
- **System Health:** shows a privacy-safe checklist for the installed launcher, game runtime, browser, controller bridge, and library access. It does not show personal filenames or passwords.
- **Power:** restart or shut down from the home screen.

## Advanced reference

Most homes can stop here. The complete [variable matrix](docs/variable-matrix.md) explains every setting, configuration field, path, and environment variable, including where it is implemented and whether it is safe to change. The [troubleshooting guide](docs/troubleshooting.md) is the best next stop when something does not open.

## Install and update (Fedora)

Hearth is currently intended for Fedora Linux.

```bash
sudo ./deploy/fedora/install.sh --dry-run --godot /path/to/godot
sudo ./deploy/fedora/install.sh --godot /path/to/godot
```

After logging out and back in, check the installation:

```bash
/opt/hearth/deploy/fedora/doctor.sh
```

To update or remove Hearth:

```bash
sudo ./deploy/fedora/update.sh --godot /path/to/godot
sudo ./deploy/fedora/uninstall.sh
```

Uninstall keeps your library, settings, browser profiles, and backups unless you explicitly request otherwise. See [Fedora installation and rollback](docs/deployment.md) for the exact process.

## For maintainers

- [Variable matrix and implementation notes](docs/variable-matrix.md)
- [Personal PC and ROM library details](docs/personal-rom-library.md)
- [Architecture and safety boundaries](docs/architecture.md)
- [Hardware validation](docs/hardware-validation.md)
- [Contributing](CONTRIBUTING.md)

Brand names and service marks belong to their respective owners and are used only to identify compatible destinations.
