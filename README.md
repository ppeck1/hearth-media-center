# Hearth Living Room

Hearth is a controller-first, Linux-native living-room launcher. It provides a cinematic system wheel for games, Plex, Steam, and streaming; RetroArch remains the emulator behind the interface rather than the interface itself.

## Personal ROM library

Add ROMs you are authorized to use under `/srv/library/games/roms/<system-folder>/`. Hearth scans system folders and three nested levels every time you open **Games**. It consolidates Game Boy variants and Sega branches, shows all era-appropriate system placeholders, and uses `launcher/config/system-registry.json` to bind each system to a Libretro core. A game launches only when that core is installed in `/usr/lib64/libretro`.

ROMs, BIOS files, saves, personal media, credentials, logs, and Godot cache are ignored by Git and must never be committed.

## DualSense controls

- D-pad or left stick: browse
- Cross: select
- Circle: go back or dismiss a dialog

USB and Bluetooth use the same standard gamepad mapping. Keyboard arrows, Enter, and Escape remain recovery controls.

## Status

This source tree is a review build. Do not deploy to the appliance until the failing system HDD is replaced with an SSD and launch/return testing is repeated.
