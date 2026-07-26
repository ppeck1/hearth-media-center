# Hearth variable matrix

This is the complete customization map for Hearth. Use the UI for ordinary changes and edit source-controlled JSON only when adding a new platform, destination, or launcher.

## Which file should I change?

| Goal | Preferred place |
| --- | --- |
| Show or hide an existing streaming service | **Movies & TV → Manage Services** |
| Change game artwork fit, folder icons, wallpapers, hierarchy, fullscreen mode, or RetroArch core | **Settings → Library & Launchers** |
| Remap a controller or remote | **Settings → Controllers and Remotes** |
| Inspect appliance status and remediation | **Settings → System Health** |
| Add a ROM system or folder alias | [`system-registry.json`](../launcher/config/system-registry.json) |
| Add a native PC game | `/srv/library/games/pc/hearth-manifest.json` plus an allowlisted launch helper |
| Add a top-level destination or streaming provider | [`menu.json`](../launcher/config/menu.json) |
| Change cross-application controller behavior | [`app-input-policy.json`](../launcher/config/app-input-policy.json) and [`input-adapters.json`](../launcher/config/input-adapters.json) |

## Local runtime settings

All three UI-managed documents are stored below:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/hearth/
```

Writes use a temporary file and atomic rename. Invalid documents fall back to safe defaults.

### `library-settings.json`

| Variable | Type | Default | Allowed values | Effect |
| --- | --- | --- | --- | --- |
| `schema_version` | integer | `1` | `1` | Settings document compatibility version |
| `artwork_fit` | string | `smart` | `smart`, `contain`, `cover` | Automatically avoids harsh cropping, always shows the full image, or fills the tile by cropping edges |
| `folder_art_mode` | string | `named_or_first` | `disabled`, `named`, `named_or_first` | Disables folder tiles, uses named tiles only, or falls back to the first non-wallpaper image |
| `folder_wallpapers` | boolean | `true` | `true`, `false` | Enables automatic `wallpaper.*` backgrounds and inheritance |
| `preserve_folders` | boolean | `true` | `true`, `false` | Shows physical subfolders as branches or flattens them into the system page |
| `retroarch_fullscreen` | boolean | `true` | `true`, `false` | Passes `fullscreen` or `windowed` to the RetroArch helper |
| `core_overrides` | object | `{}` | `{system_id: "*_libretro.so"}` | Overrides the automatic core for selected systems |

Core overrides are accepted only when the value is a filename ending in `_libretro.so`. The UI enables only cores found in an approved core directory.

### `streaming-services.json`

| Variable | Type | Default | Allowed values | Effect |
| --- | --- | --- | --- | --- |
| `schema_version` | integer | `1` | `1` | Service-selection document compatibility version |
| `enabled_services` | array of strings | all manageable services | IDs defined in `menu.json` | Controls which services appear before the permanent **Manage Services** tile |

Current manageable IDs are `netflix`, `prime`, `apple-tv`, `disney-plus`, `hulu`, `max`, `paramount-plus`, and `peacock`. Plex is always available and is not removed by this list.

### `input-profiles.json`

| Variable | Type | Default | Effect |
| --- | --- | --- | --- |
| `schema_version` | integer | `2` | Input-profile compatibility version |
| `default_profiles.keyboard` | string | `standard_remote` | Fallback profile for keyboard-shaped input |
| `default_profiles.gamepad` | string | `ps5` | Fallback profile for gamepads |
| `device_assignments` | array | `[]` | Pins a saved profile to one or more Godot/evdev selectors |
| `profiles` | array | built-in PS5 and standard remote | Stores labels, device matching, and semantic bindings |

#### Profile object

| Variable | Required | Type | Meaning |
| --- | --- | --- | --- |
| `id` | yes | string | Stable profile identifier |
| `label` | yes | string | Human-readable UI name |
| `match.keyboard_like` | no | boolean | Matches remotes that arrive as keyboard input |
| `match.name_contains` | no | string array | Case-insensitive SDL device-name fragments |
| `match.evdev.vendor_id` | no | integer | Linux USB/Bluetooth vendor ID |
| `match.evdev.product_ids` | no | integer array | Accepted Linux product IDs |
| `bindings` | yes | object | One non-empty binding array for every semantic action |

#### Binding object

| Variable | Required | Type | Example | Meaning |
| --- | --- | --- | --- | --- |
| `control` | yes | string | `gamepad_button:south` | Canonical key, gamepad button, or gamepad axis |
| `direction` | for axes | `-1` or `1` | `-1` | Negative or positive axis direction |
| `threshold` | for axes | number | `0.72` | Minimum absolute axis value |

Canonical actions are `navigate_up`, `navigate_down`, `navigate_left`, `navigate_right`, `select`, `back`, `home`, `menu`, `play_pause`, `page_left`, and `page_right`.

## Library folder media

Hearth recognizes image extensions `png`, `jpg`, `jpeg`, and `webp`, without regard to filename capitalization.

| Filename stem | Priority | Purpose |
| --- | --- | --- |
| `icon` | 1 | Canonical folder or native-game tile |
| `folder` | 2 | Legacy XBMC-compatible tile |
| `cover` | 3 | Legacy tile |
| `poster` | 4 | Legacy tile |
| first naturally sorted image | 5 | Tile fallback only in `named_or_first` mode; `wallpaper` is excluded |
| `wallpaper` | separate | Full-screen selected-item/folder background |

Wallpaper resolution is unconstrained. Hearth preserves aspect ratio, fills the 16:9 background, and downsizes images larger than 1920×1080 before creating the texture. A folder without a wallpaper inherits the closest ancestor wallpaper.

ROM sidecar cover matching uses the ROM filename stem and checks:

1. the ROM directory;
2. `covers`;
3. `media`;
4. `artwork`;
5. RetroArch thumbnails;
6. Hearth whole-system artwork packs;
7. the system fallback image.

## `menu.json`

Root fields:

| Variable | Required | Type | Current value | Meaning |
| --- | --- | --- | --- | --- |
| `schema_version` | yes | integer | `2` | Menu schema |
| `title` | yes | string | `Home` | Root heading |
| `items` | yes | array | four items | Games, Movies & TV, Settings, and Power |

Menu item fields:

| Variable | Required | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| `id` | yes | string | — | Stable item/destination identifier |
| `label` | yes | string | — | Main title |
| `caption` | no | string | `label` | Caption beneath artwork |
| `subtitle` | no | string | empty | Selection description |
| `hint` | no | string | empty | Footer instruction |
| `mark` | no | string | `•` | Text fallback when artwork is unavailable |
| `color` | no | six-digit hex string | neutral slate | Accent color |
| `art` | no | path | mark fallback | `res://` packaged image or supported local image |
| `type` | yes | string | — | `submenu`, `command`, `panel`, or `library` |
| `enabled` | no | boolean | `true` | Makes the item selectable |
| `children` | for submenu | array | `[]` | Nested item definitions |
| `menu_layout` | no | string | `carousel` | `carousel` or `tile_grid` |
| `executable` | for command | absolute path | — | Must resolve below `/opt/hearth/launchers` at runtime |
| `args` | no | string array | `[]` | Arguments passed without shell evaluation |
| `detached` | no | boolean | `false` | Records a launch and returns immediately |
| `panel_id` | for panel | string | — | `library_settings`, `input_settings`, `streaming_services`, or bounded `system_health` |
| `manageable_service` | no | boolean | `false` | Includes the destination in Movies & TV service management |

## `system-registry.json`

Root fields:

| Variable | Required | Type | Current value |
| --- | --- | --- | --- |
| `schema_version` | yes | integer | `1` |
| `families` | yes | array | Nintendo, Sega, Sony, NEC, Atari, SNK, Arcade, PC, Other |
| `systems` | yes | array | Registered ROM and native-PC systems |

Family object:

| Variable | Required | Type | Meaning |
| --- | --- | --- | --- |
| `id` | yes | string | Stable family identifier used by systems |
| `label` | yes | string | Drawer/card name |
| `brand` | no | string | Long-form brand metadata |
| `art` | yes | path | Packaged family artwork |
| `mark` | no | string | Text fallback |
| `color` | no | hex string | Accent |

System object:

| Variable | Required | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| `id` | yes | string | — | Stable system identifier |
| `family` | yes | string | — | Parent family ID |
| `label` | yes | string | — | Human-readable system name |
| `aliases` | ROM systems | string array | `[]` | Top-level folder names mapped to this system |
| `extensions` | no | string array | unrestricted non-metadata files | Optional extension allowlist without leading periods |
| `core` | ROM systems | string | — | Automatic Libretro core filename |
| `core_options` | no | array | automatic core only | Safe alternate `{core, label}` choices shown in Settings |
| `emulator_label` | no | string | core filename | Human-readable automatic launcher |
| `thumbnail_db` | no | string | empty | One RetroArch thumbnail database |
| `thumbnail_dbs` | no | string array | empty | Multiple thumbnail databases |
| `art` | no | path | text mark | System fallback artwork |
| `mark` | no | string | `•` | Text fallback |
| `color` | no | hex string | neutral slate | Accent |
| `backend` | no | string | RetroArch scan | Set to `manifest` for native PC entries |
| `manifest_path` | manifest backend | absolute path | — | Local native-game catalog |

Installed core lookup order:

1. `${XDG_CONFIG_HOME:-$HOME/.config}/retroarch/cores`;
2. `/usr/lib64/libretro`.

## Native PC manifest

Location: `/srv/library/games/pc/hearth-manifest.json`

Root fields:

| Variable | Required | Type | Value |
| --- | --- | --- | --- |
| `schema_version` | yes | integer | `1` |
| `entries` | yes | array | Native game entries |

Entry fields:

| Variable | Required | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| `id` | yes | string | — | Stable local game identifier |
| `label` | yes | string | `PC Game` | Display title |
| `folder` | recommended | path | empty | Absolute folder or path relative to the manifest directory |
| `executable` | yes | absolute path | — | Dedicated helper below `/opt/hearth/launchers` |
| `args` | no | string array | `[]` | Allowlisted helper arguments |
| `art` | legacy | absolute path | system art | Explicit image fallback when the folder has no `icon.*` |

Recommended layout:

```text
/srv/library/games/pc/
├── hearth-manifest.json
└── library/
    └── game-id/
        ├── icon.jpg
        └── wallpaper.jpg
```

## Environment variables

| Variable | Read by | Default | Effect |
| --- | --- | --- | --- |
| `HOME` | Godot, launchers, tools | process home | Base fallback for XDG paths |
| `XDG_CONFIG_HOME` | settings, RetroArch, browser launchers, bridge | `$HOME/.config` | Moves Hearth settings, RetroArch user cores, and per-service browser profiles |
| `XDG_DATA_HOME` | artwork tool and lookup | `$HOME/.local/share` | Base for downloaded Hearth artwork packs |
| `HEARTH_ARTWORK_PACK_ROOT` | artwork sync tool | `$XDG_DATA_HOME/hearth/artwork-packs` | Overrides the whole-system artwork-pack root |
| `XDG_STATE_HOME` | maintenance and diagnostic helpers | `$HOME/.local/state` | Base for appliance state and the atomic System Health report |
| `PYTHONPATH` | input bridge launcher | existing value, if any | Existing value is preserved after prepending `/opt/hearth/input_bridge` |
| `HEARTH_GODOT` | verifier and doctor | `godot` on `PATH`, then Fedora installed runtime | Selects a specific Godot executable for verification/diagnostics; not read by the Godot UI |
| `HEARTH_DIAGNOSTIC_REPORT` | Godot diagnostic tests | XDG state report | Test-only fixture path used by the headless System Health smoke test |

These variables change storage roots only. They do not broaden the executable, ROM-path, core-path, or input-output allowlists.

## Launcher command matrix

| Helper | Arguments | Validation | Result |
| --- | --- | --- | --- |
| `hearth.sh` | none | deployment-relative runtime/project | Starts Godot on Wayland at 1920×1080 |
| `retroarch-game.sh` | `CORE_FILE ROM_PATH [fullscreen\|windowed]` | core filename and approved roots; ROM below personal library | Starts one game |
| `pc-game.sh` | one allowlisted game ID | shell `case` allowlist | Starts one native/DOS/ScummVM/source-port title |
| `devilutionx-game.sh` | `diablo` or `hellfire` | exact mode allowlist | Starts the matching DevilutionX mode |
| `browser-service.sh` | `SERVICE_ID URL [DESTINATION_ID]` | fixed Chrome binary and deployed extension | Starts an isolated fullscreen service profile |
| `run-with-input-bridge.sh` | `DESTINATION_ID COMMAND...` | destination policy and adapter config | Supervises one external application session |
| `system-health-refresh.sh` | none | fixed doctor path and fixed XDG state output | Atomically refreshes the privacy-bounded health report |

## Input policy matrix

| Policy ID | Adapter | Destinations | Behavior |
| --- | --- | --- | --- |
| `hearth` | `internal` | Hearth | Godot consumes semantic navigation directly |
| `browser_streaming` | `keyboard_navigation` | Eight browser services | Controller becomes an allowlisted temporary keyboard |
| `plex` | `keyboard_navigation` | Plex | Same navigation bridge |
| `steam` | `native` | Steam | Application receives the controller directly |
| `retroarch` | `native` | RetroArch menu and games | Application receives the controller directly |
| `maintenance` | `native` | Maintenance | Native input behavior |

The definitive mappings live in [`app-input-policy.json`](../launcher/config/app-input-policy.json); output definitions live in [`input-adapters.json`](../launcher/config/input-adapters.json).

## Fixed application constants

These are code constants rather than user variables:

| Constant | Value | Source |
| --- | --- | --- |
| ROM root | `/srv/library/games/roms` | [`main.gd`](../launcher/scripts/main.gd) |
| System core root | `/usr/lib64/libretro` | [`main.gd`](../launcher/scripts/main.gd) |
| Movies & TV columns | `3` | [`main.gd`](../launcher/scripts/main.gd) |
| Visible Movies & TV rows | `3` | [`main.gd`](../launcher/scripts/main.gd) |
| Visible Movies & TV page size | `9` | [`main.gd`](../launcher/scripts/main.gd) |
| Library grid columns | `6` | [`library_browser.gd`](../launcher/scripts/library/library_browser.gd) |
| Folder recursion limit | 8 nested levels below a system root | [`main.gd`](../launcher/scripts/main.gd) |
| External cover texture cache | 64 images | [`library_browser.gd`](../launcher/scripts/library/library_browser.gd) |
| Screenshot/reference resolution | 1920×1080 | [`hearth.sh`](../launchers/hearth.sh) |
| Diagnostic helper | `/opt/hearth/launchers/system-health-refresh.sh` | [`system_health.gd`](../launcher/scripts/diagnostics/system_health.gd) |
| Diagnostic report | `${XDG_STATE_HOME:-$HOME/.local/state}/hearth/system-health.json` | [`health_report.gd`](../launcher/scripts/diagnostics/health_report.gd) |
