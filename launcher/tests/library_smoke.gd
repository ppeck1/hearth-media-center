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
    var scene: PackedScene = load("res://main.tscn")
    var launcher = scene.instantiate()
    root.add_child(launcher)
    await process_frame

    launcher.input_rearm_at_msec = Time.get_ticks_msec() + 10000
    _check(not launcher._can_accept_navigation_input(), "headless background window rejects navigation input")
    var steam_item: Dictionary = _item_with_id(launcher.items, "steam")
    launcher._activate(steam_item, launcher.buttons[1])
    _check(launcher.child_pid == -1, "background activation cannot launch Steam")

    var family_items: Array = launcher._library_systems()
    var nintendo: Dictionary = {}
    for family_item in family_items:
        if str(family_item.get("id", "")) == "nintendo":
            nintendo = family_item
            break
    _check(not nintendo.is_empty(), "Nintendo family is discovered")
    _check(not nintendo.has("brand"), "family cards omit redundant text above artwork")
    _check(nintendo.get("header_hint") == "Choose a family", "family selection uses family wording")
    for family_item in family_items:
        if str(family_item.get("id", "")) == "unmapped":
            continue
        _check(
            family_item.get("header_hint") == "Choose a family",
            "%s family uses family-level wording" % family_item.get("label", "Family")
        )

    for registered_system in launcher.systems:
        if str(registered_system.get("backend", "")) == "manifest":
            var native_games: Array = launcher._manifest_games(registered_system)
            _check(
                str(registered_system.get("manifest_path", "")).begins_with("/srv/library/"),
                "PC catalog is loaded from a machine-local manifest"
            )
            if not native_games.is_empty():
                _check(native_games[0].get("type") == "command", "PC manifest uses a native command backend")
            continue
        var core_file := str(registered_system.get("core", ""))
        _check(
            not launcher._retroarch_core_path(core_file).is_empty(),
            "%s core resolves from an approved directory" % registered_system.get("label", "System")
        )
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

    var n64: Dictionary = {}
    for system_item in nintendo.get("children", []):
        if str(system_item.get("id", "")) == "n64":
            n64 = system_item
            break
    _check(not n64.is_empty(), "Nintendo 64 system is discovered")
    _check(str(n64.get("subtitle", "")).ends_with("available"), "system header shows only games available")
    _check(not str(n64.get("subtitle", "")).contains("RetroArch"), "system header omits bridge and emulator")
    _check(n64.get("caption") == n64.get("label"), "system name appears under system artwork")
    _check(str(n64.get("header_hint", "")).is_empty(), "system header does not repeat the system name")

    var games: Array = n64.get("children", [])
    _check(not games.is_empty(), "Nintendo 64 games are discovered")
    if not games.is_empty():
        _check(not str(games[0].get("caption", "")).is_empty(), "game title appears under the game icon")
        _check(str(games[0].get("subtitle", "")).is_empty(), "game header omits system and extension")
        _check(str(games[0].get("header_hint", "")).is_empty(), "game header omits launch boilerplate")
        var all_games_have_art := true
        for game in games:
            if str(game.get("art", "")).is_empty():
                all_games_have_art = false
        _check(all_games_have_art, "missing title art receives a system fallback")
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
