extends SceneTree

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: ", message)
    else:
        failures += 1
        push_error("FAIL: " + message)

func _run() -> void:
    var original_config_home := OS.get_environment("XDG_CONFIG_HOME")
    var fixture_config_home := "/tmp/hearth-library-smoke-config-%d" % OS.get_process_id()
    var fixture_core_root := fixture_config_home.path_join("retroarch").path_join("cores")
    DirAccess.make_dir_recursive_absolute(fixture_core_root)
    for core_name in ["mupen64plus_next_libretro.so", "parallel_n64_libretro.so"]:
        var core_file := FileAccess.open(fixture_core_root.path_join(core_name), FileAccess.WRITE)
        _check(core_file != null, "isolated RetroArch core fixture is created")
        if core_file != null:
            core_file.store_8(0)
            core_file.close()
    OS.set_environment("XDG_CONFIG_HOME", fixture_config_home)

    var scene: PackedScene = load("res://main.tscn")
    var launcher = scene.instantiate()
    root.add_child(launcher)
    await process_frame

    launcher.input_rearm_at_msec = Time.get_ticks_msec() + 10000
    _check(not launcher._can_accept_navigation_input(), "headless background window rejects navigation input")
    var games_menu: Dictionary = _item_with_id(launcher.items, "games")
    var steam_item: Dictionary = _item_with_id(games_menu.get("children", []), "steam")
    launcher._activate(steam_item, launcher.buttons[0])
    _check(launcher.child_pid == -1, "background activation cannot launch Steam")

    for registered_system in launcher.systems:
        if str(registered_system.get("backend", "")) == "manifest":
            _check(
                str(registered_system.get("manifest_path", "")).begins_with("/srv/library/"),
                "PC catalog is configured outside the repository"
            )
            continue
        var sample_system: Dictionary = launcher._system_item(
            registered_system,
            [{"caption":"Sample Game"}]
        )
        _check(
            sample_system.get("subtitle") == "1 game available",
            "%s system header contains only the available count" % registered_system.get("label", "System")
        )
        _check(
            str(sample_system.get("header_hint", "")).is_empty(),
            "%s system header does not repeat its name" % registered_system.get("label", "System")
        )
    _check(
        launcher._clean_game_title("Example Game (USA).nkit.gcz") == "Example Game",
        "compound extensions and database tags are removed from captions"
    )
    _check(
        launcher._artwork_lookup_title("Crazy Taxi v1.004 (1999)(Sega)(US)[!].chd") == "Crazy Taxi",
        "Dreamcast release metadata is removed for local artwork matching"
    )

    var temporary_art := "/tmp/hearth-library-smoke.png"
    var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    _check(image.save_png(temporary_art) == OK, "temporary sidecar artwork is created")
    var sidecar: String = launcher._find_game_art(
        "/tmp",
        "hearth-library-smoke.z64",
        {"thumbnail_db":"Nintendo - Nintendo 64"}
    )
    _check(sidecar == temporary_art, "same-name sidecar artwork is discovered automatically")
    var normalized_art_folder := "/tmp/hearth-library-normalized-art"
    DirAccess.make_dir_recursive_absolute(normalized_art_folder)
    var normalized_art := normalized_art_folder.path_join("Example Game (USA).png")
    var alternate_art := normalized_art_folder.path_join("Example Game (Europe).png")
    _check(image.save_png(normalized_art) == OK, "normalized artwork fixture is created")
    _check(image.save_png(alternate_art) == OK, "alternate-region artwork fixture is created")
    _check(
        launcher._find_normalized_image(normalized_art_folder, "Example-Game") == normalized_art,
        "local artwork matching prefers the standard USA cover"
    )

    var folder_fixture := "/tmp/hearth-folder-library-smoke"
    var nested_fixture := folder_fixture.path_join("Role Playing")
    DirAccess.make_dir_recursive_absolute(nested_fixture)
    var folder_icon := nested_fixture.path_join("Folder.PNG")
    var canonical_icon := nested_fixture.path_join("icon.jpg")
    var folder_wallpaper := nested_fixture.path_join("Wallpaper.PNG")
    var first_image := folder_fixture.path_join("00-first.jpg")
    var rom_fixture := nested_fixture.path_join("Example Quest.z64")
    _check(image.save_png(folder_icon) == OK, "mixed-case folder artwork fixture is created")
    _check(image.save_jpg(canonical_icon) == OK, "canonical icon fixture is created")
    _check(image.save_png(folder_wallpaper) == OK, "canonical wallpaper fixture is created")
    _check(image.save_jpg(first_image) == OK, "first-image fallback fixture is created")
    var rom_file := FileAccess.open(rom_fixture, FileAccess.WRITE)
    rom_file.store_8(1)
    rom_file.close()
    launcher.library_settings_store.data["folder_art_mode"] = "named_or_first"
    launcher.library_settings_store.data["preserve_folders"] = true
    _check(
        launcher._find_folder_art(nested_fixture) == canonical_icon,
        "icon images are the primary folder tile convention"
    )
    _check(
        launcher._find_folder_wallpaper(nested_fixture) == folder_wallpaper,
        "wallpaper images are discovered case-insensitively"
    )
    _check(
        launcher._find_folder_art(folder_fixture) == first_image,
        "the first local image becomes folder art when fallback is enabled"
    )
    launcher.library_settings_store.data["folder_art_mode"] = "named"
    _check(
        launcher._find_folder_art(folder_fixture).is_empty(),
        "named-only mode ignores unrelated images"
    )
    launcher.library_settings_store.data["folder_art_mode"] = "disabled"
    _check(
        launcher._find_folder_art(nested_fixture).is_empty(),
        "folder artwork can be disabled"
    )
    launcher.library_settings_store.data["folder_art_mode"] = "named_or_first"
    var scanned_items: Array = []
    launcher._scan_system_folder(folder_fixture, {
        "id":"n64",
        "family":"nintendo",
        "label":"Nintendo 64",
        "extensions":["z64"],
        "core":"mupen64plus_next_libretro.so",
        "core_options":[
            {"core":"mupen64plus_next_libretro.so","label":"Mupen64Plus-Next"},
            {"core":"parallel_n64_libretro.so","label":"ParaLLEl N64"}
        ]
    }, scanned_items)
    _check(scanned_items.size() == 1, "nested files remain in their physical library branch")
    if not scanned_items.is_empty():
        var scanned_folder: Dictionary = scanned_items[0]
        _check(scanned_folder.get("type") == "folder", "nested directory becomes a browsable folder")
        _check(scanned_folder.get("art") == canonical_icon, "folder tile receives its local icon image")
        _check(scanned_folder.get("wallpaper") == folder_wallpaper, "folder branch receives its local wallpaper")
        _check(launcher._game_count(scanned_items) == 1, "recursive game counts exclude folder nodes")
        var nested_games: Array = scanned_folder.get("children", [])
        if not nested_games.is_empty():
            var launch_args: Array = nested_games[0].get("args", [])
            _check(launch_args.size() == 3, "RetroArch launch includes a display-mode setting")
            if launch_args.size() == 3:
                _check(launch_args[2] == "fullscreen", "fullscreen is the default launch mode")

    var n64_registry: Dictionary = {}
    for system_value in launcher.systems:
        if str(system_value.get("id", "")) == "n64":
            n64_registry = system_value
            break
    launcher.library_settings_store.data["core_overrides"] = {"n64":"parallel_n64_libretro.so"}
    _check(
        launcher._core_for_system(n64_registry) == "parallel_n64_libretro.so",
        "a configured system launcher overrides the automatic core"
    )
    launcher.library_settings_store.data["core_overrides"] = {}
    launcher.library_settings_store.data["retroarch_fullscreen"] = false
    var windowed_items: Array = []
    launcher._scan_system_folder(nested_fixture, n64_registry, windowed_items, 0, false)
    if not windowed_items.is_empty():
        var windowed_args: Array = windowed_items[0].get("args", [])
        _check(windowed_args.size() == 3, "windowed launch includes a display-mode setting")
        if windowed_args.size() == 3:
            _check(windowed_args[2] == "windowed", "windowed launch mode reaches the launcher")
    launcher.library_settings_store.reset_defaults()

    var native_items: Array = launcher._manifest_games({
        "id":"pc-games",
        "family":"pc",
        "label":"PC Games",
        "backend":"manifest",
        "entries":[{
            "id":"folder-convention",
            "label":"Folder Convention",
            "folder":nested_fixture,
            "executable":"/opt/hearth/launchers/pc-game.sh",
            "args":["folder-convention"]
        }]
    })
    _check(not native_items.is_empty(), "native game folder convention produces a manifest item")
    if not native_items.is_empty():
        _check(native_items[0].get("art") == canonical_icon, "native game icon is read from its folder")
        _check(native_items[0].get("wallpaper") == folder_wallpaper, "native game wallpaper is read from its folder")

    launcher._add_card({
        "id":"artwork-test",
        "label":"Artwork Test",
        "caption":"Artwork Test",
        "art":sidecar,
        "type":"unavailable"
    })
    var artwork_card: Button = launcher.buttons[-1]
    var artwork_node: TextureRect = artwork_card.get_meta("art_node")
    _check(artwork_node.texture == null, "external artwork starts unloaded")
    launcher._set_card_typography(artwork_card, true, 0)
    _check(artwork_node.texture != null, "visible external artwork loads on demand")
    launcher._set_card_typography(artwork_card, false, 3)
    _check(artwork_node.texture == null, "off-screen external artwork is released")
    DirAccess.remove_absolute(temporary_art)
    DirAccess.remove_absolute(normalized_art)
    DirAccess.remove_absolute(alternate_art)
    DirAccess.remove_absolute(normalized_art_folder)
    DirAccess.remove_absolute(rom_fixture)
    DirAccess.remove_absolute(folder_icon)
    DirAccess.remove_absolute(canonical_icon)
    DirAccess.remove_absolute(folder_wallpaper)
    DirAccess.remove_absolute(first_image)
    DirAccess.remove_absolute(nested_fixture)
    DirAccess.remove_absolute(folder_fixture)
    for core_name in ["mupen64plus_next_libretro.so", "parallel_n64_libretro.so"]:
        DirAccess.remove_absolute(fixture_core_root.path_join(core_name))
    DirAccess.remove_absolute(fixture_core_root)
    DirAccess.remove_absolute(fixture_config_home.path_join("retroarch"))
    DirAccess.remove_absolute(fixture_config_home)
    OS.set_environment("XDG_CONFIG_HOME", original_config_home)

    launcher.queue_free()
    await process_frame
    if failures == 0:
        print("Library smoke test passed.")
        quit(0)
        return
    quit(1)

func _item_with_id(source_items: Array, item_id: String) -> Dictionary:
    for item in source_items:
        if item is Dictionary and str(item.get("id", "")) == item_id:
            return item
    return {}
