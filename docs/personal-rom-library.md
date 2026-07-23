# Personal ROM library

Hearth reads only the local directory `/srv/library/games/roms`. Add a folder per system, then copy your own files below it. The interface discovers ROMs when Games opens; no ROM names are stored in this repository and no files are uploaded. Folder aliases are consolidated into families: `gb`, `gbc`, and `gba` appear under **Nintendo → Game Boy**; `md`, `segacd`, and related folders appear under **Sega**.

All defined systems from the Dreamcast/GameCube era and earlier appear as placeholders even before ROMs are added. Files in an unmapped folder still appear under **Unmapped Library** so nothing is hidden. Hearth accepts configured Libretro cores from `~/.config/retroarch/cores` and `/usr/lib64/libretro`; core and folder assignments live in `launcher/config/system-registry.json`. `tools/install-retroarch-cores.sh` installs missing generic cores from Libretro's official HTTPS buildbot without reading the ROM library.

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

The game launcher resolves both paths and accepts only an installed `*_libretro.so` core plus a ROM below the personal library root. It cannot execute arbitrary programs.
