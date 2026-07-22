# Personal ROM library

Hearth reads only the local directory `/srv/library/games/roms`. Add a folder per system, then copy your own files below it. The interface discovers ROMs when Games opens; no ROM names are stored in this repository and no files are uploaded.

Files with no profile remain visible so you can add any format now and configure it later. To make one launch, install a compatible Libretro core in `/usr/lib64/libretro`, then add the extension and core filename to `launcher/config/library-profiles.json`.

The game launcher resolves both paths and accepts only an installed `*_libretro.so` core plus a ROM below the personal library root. It cannot execute arbitrary programs.
