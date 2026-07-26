# Personal ROM library

Hearth reads only the local directory `/srv/library/games/roms`. Add a folder per system, then copy your own files below it. The interface discovers ROMs every time **Games → My Library** opens and when **Refresh Library** is selected in the drawer; there is no import database to maintain, no ROM names are stored in this repository, and no files are uploaded. Folder aliases are consolidated into families: `gb`, `gbc`, and `gba` appear under **Nintendo → Game Boy**; `md`, `segacd`, and related folders appear under **Sega**.

All defined systems from the Dreamcast/GameCube era and earlier appear as placeholders even before ROMs are added. Files in an unmapped folder still appear under **Unmapped Library** so nothing is hidden. Hearth accepts configured Libretro cores from `~/.config/retroarch/cores` and `/usr/lib64/libretro`; core and folder assignments live in `launcher/config/system-registry.json`. `tools/install-retroarch-cores.sh` installs missing generic cores from Libretro's official HTTPS buildbot without reading the ROM library.

## Folder branches and folder icons

Subfolders remain subfolders in Hearth, much like an old-school XBMC library. Hearth does not move, rename, or reorganize personal files behind the user's back. Organize the filesystem once and the same branches appear on screen:

```text
/srv/library/games/roms/
└── n64/
    ├── icon.jpg
    ├── wallpaper.jpg
    ├── Multiplayer/
    │   ├── icon.png
    │   ├── wallpaper.webp
    │   ├── Mario Kart 64 (USA).z64
    │   └── Mario Kart 64 (USA).png
    └── Role Playing/
        ├── icon.webp
        └── Paper Mario (USA).z64
```

The canonical files in each directory are:

- `icon.*` — the tile shown for that folder or native game.
- `wallpaper.*` — the full-screen background shown while that item or folder is selected.

PNG, JPG, JPEG, and WebP are supported, and names are matched without regard to capitalization. A child folder inherits its closest parent wallpaper when it has no wallpaper of its own. Hearth still recognizes the legacy tile names `folder`, `cover`, and `poster` after checking for `icon`. With the default **Named images, then first image** setting, the first naturally sorted non-wallpaper image becomes the icon when no named icon exists.

Open **Settings → Library & Launchers** to choose:

- **Off** — never use local folder images.
- **Named images** — use `icon`, with `folder`, `cover`, and `poster` retained as compatible alternatives.
- **Named images, then first image** — XBMC-style automatic behavior and the default.
- **Use wallpaper images from library folders** — automatically apply `wallpaper.*`; enabled by default.
- **Keep subfolders as browsable folders** — preserve physical branches; turn it off for one flat system list.

These machine-local choices are saved in:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/hearth/library-settings.json
```

## Game artwork

Hearth always shows a cleaned game title beneath each game card. It looks for artwork automatically in this order:

1. A same-name PNG, JPG, or WebP beside the ROM, or in a nearby `covers`, `media`, or `artwork` folder.
2. RetroArch's standard thumbnail cache under `~/.config/retroarch/thumbnails`.
3. A private whole-system pack under `~/.local/share/hearth/artwork-packs`.
4. The system mark and title as an offline fallback.

The artwork tool never reads the ROM library and never makes title-by-title requests. Run `tools/sync-game-artwork.sh --list` to see the available generic packs, then pass one or more system IDs, for example:

```sh
tools/sync-game-artwork.sh n64 gamecube
```

It downloads each selected system's complete `Named_Boxarts` directory, after which Hearth matches filenames locally. The remote host sees the generic system repository and the computer's network address, but it does not receive ROM filenames or game titles. These packs are large: the currently populated Nintendo systems total about 10.4 GiB of uncompressed box art. Keep downloaded artwork as a personal local cache; it is not bundled with Hearth.

## Choosing how games launch

Open **Settings → Library & Launchers** to leave each system on **Automatic** or select another compatible RetroArch core. Hearth only enables choices that are installed in `~/.config/retroarch/cores` or `/usr/lib64/libretro`. The same panel controls whether RetroArch starts fullscreen or windowed.

Available alternatives are declared as `core_options` in `launcher/config/system-registry.json`, so a distributor can add another safe core without changing application code. The game launcher resolves both paths and accepts only an installed `*_libretro.so` core plus a ROM below the personal library root. It cannot execute arbitrary programs.

Native PC games use `/srv/library/games/pc/hearth-manifest.json`. Each entry points to a dedicated helper below `/opt/hearth/launchers`; arguments can be customized in the manifest, but Hearth will not run an arbitrary path. Use a relative `folder` value to keep the manifest portable:

```json
{
  "id": "doom",
  "label": "Doom",
  "folder": "library/doom",
  "executable": "/opt/hearth/launchers/pc-game.sh",
  "args": ["doom"]
}
```

Place `icon.jpg` and, optionally, `wallpaper.jpg` inside `/srv/library/games/pc/library/doom`. The extensions may differ and do not need to be recorded in the manifest. This keeps plug-in launchers simple while preserving the appliance safety boundary.
