# Personal ROM library

Hearth reads only the local directory `/srv/library/games/roms`. Add a folder per system, then copy your own files below it. The interface discovers ROMs when Games opens; no ROM names are stored in this repository and no files are uploaded. Folder aliases are consolidated into families: `gb`, `gbc`, and `gba` appear under **Nintendo → Game Boy**; `md`, `segacd`, and related folders appear under **Sega**.

All defined systems from the Dreamcast/GameCube era and earlier appear as placeholders even before ROMs are added. Files in an unmapped folder still appear under **Unmapped Library** so nothing is hidden. To make a system launch, install its configured Libretro core in `/usr/lib64/libretro`; core and folder assignments live in `launcher/config/system-registry.json`.

The game launcher resolves both paths and accepts only an installed `*_libretro.so` core plus a ROM below the personal library root. It cannot execute arbitrary programs.
