# Hearth variable matrix

This is the complete reference for Hearth’s choices and configuration. It is written in two layers:

1. Use the first tables for ordinary setup. They identify the setting, what it changes, and where to change it.
2. Use the later tables only when maintaining an installation or adding a new platform. They include the implementation point and validation rules, so a change does not accidentally make Hearth less safe.

## Start with the safe option

| If you want to… | Change it here | Saved in / implemented by |
| --- | --- | --- |
| Add games, icons, or wallpaper | Your library folders | `/srv/library/games/roms`; scanned by `main.gd` and `library_browser.gd` |
| Show or hide a streaming service | **Movies & TV → Manage Services** | `streaming-services.json` |
| Change artwork, folder, or emulator behavior | **Settings → Library & Launchers** | `library-settings.json` |
| Choose or remap a controller/remote | **Settings → Controllers and Remotes** | `input-profiles.json` |
| Change fullscreen mode | **Settings → Fullscreen / Windowed**, or F11 | Hearth’s running window; not a permanent JSON setting |
| Add a new system or folder alias | `launcher/config/system-registry.json` | Loaded by `main.gd` at startup |
| Add a new built-in destination | `launcher/config/menu.json` and a reviewed launcher helper | Loaded by `main.gd`; helper must be below `/opt/hearth/launchers` |

## Everyday settings

All settings changed through the screen are private to the current Linux user. They are stored under `${XDG_CONFIG_HOME:-$HOME/.config}/hearth/`. Hearth writes a temporary file first, then replaces the old file, so an interrupted save does not normally leave a half-written setting.

### Library & Launchers — `library-settings.json`

| Setting / variable | Default | What it does | Implementation notes |
| --- | --- | --- | --- |
| `schema_version` | `1` | Identifies this file format. | Do not change it. `HearthLibrarySettingsStore` rejects another version and uses friendly defaults. |
| `artwork_fit` | `smart` | Chooses artwork framing: `smart`, `contain`, or `cover`. | `smart` measures the image; `contain` never crops; `cover` fills the card and may crop edges. Used by `library_browser.gd`. |
| `folder_art_mode` | `named_or_first` | Chooses folder icon behavior: `disabled`, `named`, or `named_or_first`. | Named means `icon.*`, then compatible `folder.*`, `cover.*`, or `poster.*`. The last mode falls back to the first non-wallpaper image. |
| `folder_wallpapers` | `true` | Enables `wallpaper.*` backgrounds and inheritance. | A child without a wallpaper uses its nearest parent wallpaper. |
| `preserve_folders` | `true` | Keeps physical subfolders as browsable folders. | `false` flattens games into the system view; files are never moved. |
| `retroarch_fullscreen` | `true` | Opens RetroArch games fullscreen. | Passed as `fullscreen` or `windowed` to the bounded `retroarch-game.sh` helper. |
| `core_overrides` | `{}` | Selects an installed RetroArch core for one system. | Keys are system IDs and values must be a bare `*_libretro.so` filename. The UI only offers detected compatible cores. |

### Movies & TV — `streaming-services.json`

| Setting / variable | Default | What it does | Implementation notes |
| --- | --- | --- | --- |
| `schema_version` | `1` | Identifies this file format. | Do not change it. Invalid data shows all available services. |
| `enabled_services` | All manageable services | List of service IDs that appear in Movies & TV. | IDs must exist in `menu.json`. Plex is permanent and is not controlled by this list. Unknown or duplicate IDs are ignored. |

Current manageable IDs: `netflix`, `prime`, `apple-tv`, `disney-plus`, `hulu`, `max`, `paramount-plus`, and `peacock`.

### Controllers and remotes — `input-profiles.json`

| Setting / variable | Default | What it does | Implementation notes |
| --- | --- | --- | --- |
| `schema_version` | `2` | Identifies input-profile format. | Do not change it. Invalid files fall back to the built-in profiles. |
| `default_profiles.keyboard` | `standard_remote` | Profile used for keyboard-style remotes. | Used if no device-specific assignment matches. |
| `default_profiles.gamepad` | `ps5` | Profile used for ordinary gamepads. | Used if no device-specific assignment matches. |
| `device_assignments` | `[]` | Pins a saved profile to a detected device. | Created by the Settings screen. Selectors use Godot or evdev device information. |
| `profiles` | Built-in PS5 and remote profiles | The list of named profiles and their bindings. | Every profile must have every Hearth action; saved profiles are merged with new built-in actions on load. |

Each profile has `id`, `label`, optional `match`, and `bindings`. A binding uses `control` such as `gamepad_button:south` or `key:enter`; axis bindings also use `direction` (`-1` or `1`) and may use `threshold` (for example `0.72`). The supported actions are `navigate_up`, `navigate_down`, `navigate_left`, `navigate_right`, `select`, `back`, `home`, `menu`, `play_pause`, `page_left`, and `page_right`.

## Library pictures and layout

Hearth accepts `png`, `jpg`, `jpeg`, and `webp`, regardless of capital letters in the extension.

| File name | Use | How Hearth implements it |
| --- | --- | --- |
| `icon.*` | Preferred folder or PC-game tile | First choice for a folder’s image. |
| `folder.*`, `cover.*`, `poster.*` | Compatible older tile names | Checked after `icon.*`. |
| First ordinary image | Optional automatic folder tile | Used only with `folder_art_mode: named_or_first`; `wallpaper.*` is excluded. |
| `wallpaper.*` | Selected-folder background | Fills the background while keeping its aspect ratio; large images are reduced before texture creation. |
| `Game Name.*` beside a ROM | Game cover | Matches the ROM filename stem, e.g. `Game Name.z64` and `Game Name.png`. |

For a game cover, Hearth searches the ROM folder, then nearby `covers`, `media`, and `artwork` folders, then RetroArch thumbnails, a locally downloaded whole-system artwork pack, and finally the system fallback art. It never uploads game names to perform this lookup.

## Source-controlled menu — `menu.json`

Edit this only when building a new delivered destination. Regular users should use the on-screen service manager instead.

| Field | Required | Meaning | Implementation / guardrail |
| --- | --- | --- | --- |
| `schema_version` | yes | Menu format (`2`). | Checked when Hearth loads the menu. |
| `title` | yes | Home heading. | Displayed by `main.gd`. |
| `items` | yes | Top-level menu items. | Current installation uses Games, Movies & TV, Settings, and Power. |
| `id` | yes | Stable item identifier. | Referenced by saved service settings and input policies. Do not casually rename it. |
| `label`, `caption`, `subtitle`, `hint` | label required | Text shown to the person using Hearth. | `caption`, `subtitle`, and `hint` have friendly fallbacks. |
| `mark`, `color`, `art` | no | Fallback mark, accent, and packaged artwork. | `art` must be a bundled `res://` asset or supported local image. |
| `type` | yes | `submenu`, `command`, `panel`, `library`, or `action`. | Determines which safe code path is used. |
| `enabled` | no | Selectability; defaults to `true`. | Disabled items remain non-launchable. |
| `children` | submenu | Nested items. | Used for Home sections and Movies & TV. |
| `menu_layout` | no | `carousel` or `tile_grid`. | Controls visual arrangement only. |
| `executable`, `args`, `detached` | command | Helper path, literal arguments, and whether launch returns immediately. | The executable must resolve below `/opt/hearth/launchers`; arguments are not passed to a shell. |
| `panel_id` | panel | Settings panel name. | Limited to built-in panels such as `library_settings`, `input_settings`, `streaming_services`, and `system_health`. |
| `action_id` | action | Built-in action name. | Currently only `toggle_fullscreen`; no arbitrary code is evaluated. |
| `manageable_service` | no | Makes a service appear in the service manager. | Plex intentionally does not use this field and always remains visible. |

## System registry — `system-registry.json`

This file tells Hearth which folder names belong to which system and which safe RetroArch core to use.

| Field | Required | Meaning | Implementation / guardrail |
| --- | --- | --- | --- |
| `schema_version` | yes | Registry format (`1`). | Do not change without a matching code migration. |
| `families` | yes | Brand/system groups, e.g. Nintendo or Sega. | Family fields are `id`, `label`, plus optional `brand`, `art`, `mark`, and `color`. |
| `systems` | yes | Registered system definitions. | A system is placed under its matching family. |
| `id`, `family`, `label` | yes | Stable system ID, parent family, and displayed name. | `id` is also used by `core_overrides`; preserve it after release. |
| `aliases` | ROM systems | Folder names recognized for the system. | Example: `n64` and `nintendo64` can map to one Nintendo 64 page. |
| `extensions` | no | Allowed game file extensions, without dots. | When omitted, Hearth accepts non-metadata files for that system. |
| `core` | ROM systems | Default Libretro core filename. | Must be an installed bare `*_libretro.so` file; never a path. |
| `core_options` | no | Alternate `{core, label}` choices. | These are the only alternates presented in Settings. |
| `emulator_label` | no | Friendly core/launcher description. | Display-only. |
| `thumbnail_db`, `thumbnail_dbs` | no | RetroArch thumbnail database name(s). | Used for local artwork lookup only. |
| `art`, `mark`, `color` | no | Packaged fallback art and appearance. | Used when no personal artwork is found. |
| `backend` | no | Launch source; `manifest` is for native PC games. | ROM systems use the RetroArch scan behavior by default. |
| `manifest_path` | manifest backend | PC-game manifest location. | Current path is `/srv/library/games/pc/hearth-manifest.json`. |

Core lookup checks `${XDG_CONFIG_HOME:-$HOME/.config}/retroarch/cores` first, then `/usr/lib64/libretro`.

## Native PC game manifest

Location: `/srv/library/games/pc/hearth-manifest.json`.

| Field | Required | Meaning | Implementation / guardrail |
| --- | --- | --- | --- |
| `schema_version` | yes | Manifest format (`1`). | Kept separate from the ROM scanner. |
| `entries` | yes | List of PC games. | Each item is rendered as one library entry. |
| `id` | yes | Stable local game ID. | Used by a helper’s allowlist. |
| `label` | yes | Game title shown in Hearth. | Defaults to `PC Game` only if omitted by older data. |
| `folder` | recommended | Game folder; absolute or relative to manifest. | Place `icon.*` and `wallpaper.*` here. |
| `executable` | yes | Dedicated Hearth launcher helper. | Must be under `/opt/hearth/launchers`; arbitrary executables are refused. |
| `args` | no | Literal helper arguments. | No shell interpretation. |
| `art` | no | Legacy explicit art fallback. | Used only when folder artwork is unavailable. |

## Environment variables and deployment overrides

These are for an installer, tester, or maintainer—not normal couch setup.

| Variable | Default | Used by | What it changes / caution |
| --- | --- | --- | --- |
| `HOME` | Process home | Godot and helpers | Fallback base for XDG paths. Usually leave it alone. |
| `XDG_CONFIG_HOME` | `$HOME/.config` | UI settings, RetroArch, browser helpers | Moves Hearth settings, user RetroArch cores, and browser profiles. |
| `XDG_DATA_HOME` | `$HOME/.local/share` | Artwork lookup/tool | Moves locally downloaded artwork packs. |
| `XDG_STATE_HOME` | `$HOME/.local/state` | System Health and maintenance | Moves private state and the System Health report. |
| `HEARTH_ARTWORK_PACK_ROOT` | `$XDG_DATA_HOME/hearth/artwork-packs` | Artwork tool/lookup | Overrides only the generic artwork-pack cache. |
| `HEARTH_GODOT` | `godot` on `PATH`, then installed runtime | Verification and doctor scripts | Chooses Godot for maintenance; the UI does not read it. |
| `HEARTH_DIAGNOSTIC_REPORT` | XDG state report | System Health tests | Test-only report fixture override. Do not set in everyday use. |
| `PYTHONPATH` | Existing value | Input-bridge launcher | Hearth prepends its bridge module while preserving an existing value. |
| `HEARTH_INSTALL_ROOT` | `/opt/hearth` | Fedora install/update/uninstall | Test/deployment override, constrained by deployment validation. |
| `HEARTH_LIBRARY_ROOT` | `/srv/library` | Fedora install/update/uninstall | Test/deployment override; the running Godot launcher still reads its fixed library paths. |
| `HEARTH_TARGET_USER`, `HEARTH_TARGET_HOME` | Detected login user/home | Fedora deployment | Chooses the target account during scripted deployment. |
| `HEARTH_ETC_ROOT`, `HEARTH_OS_RELEASE` | `/etc`, `/etc/os-release` | Fedora deployment | Test/deployment paths only. |
| `HEARTH_DRY_RUN` | `0` | Fedora deployment | Reports planned changes without making them; installer flags set it for you. |
| `HEARTH_TEST_MODE` | `0` | Fedora deployment tests | Enables controlled test behavior; never set for a real appliance. |
| `HEARTH_SKIP_DOCTOR` | `0` | Fedora update | Skips the post-update diagnostic check; use only while diagnosing the updater itself. |

## Fixed limits and helpers

These are intentionally code constants, not owner settings.

| Constant | Value | Why it is fixed |
| --- | --- | --- |
| ROM root | `/srv/library/games/roms` | Keeps game launches within the personal library boundary. |
| System core root | `/usr/lib64/libretro` | Standard Fedora location for system Libretro cores. |
| Native manifest | `/srv/library/games/pc/hearth-manifest.json` | Separates reviewed PC-game launch entries from ROM scanning. |
| Launcher helper root | `/opt/hearth/launchers` | Prevents menus/manifests from launching an arbitrary program. |
| Folder recursion | 8 levels | Avoids accidental very deep scans. |
| Movie grid | 3 columns × 3 rows | Nine services fit on one screen before scrolling. |
| Library grid | 6 columns | Keeps cards readable at 1920×1080. |
| External artwork cache | 64 images | Bounds memory use while browsing. |

## External-input policy

The input bridge is deliberately allowlisted. `app-input-policy.json` assigns a destination to one policy; `input-adapters.json` specifies which harmless keyboard-like actions that policy may emit.

| Policy | Destinations | Behavior |
| --- | --- | --- |
| `hearth` | Hearth itself | Godot receives semantic navigation directly. |
| `browser_streaming` | Browser streaming services | Controller becomes a temporary, allowlisted keyboard. Netflix is the only fully tested service. |
| `plex` | Plex | Uses the same limited keyboard-navigation bridge. |
| `steam` | Steam Big Picture | Steam receives native controller input. |
| `retroarch` | RetroArch and games | RetroArch receives native controller input. |
| `maintenance` | Maintenance tools | Keeps native input behavior. |

The bridge releases input devices when the external app exits, fails, or disconnects. It does not run as root and cannot execute commands based on controller input.
