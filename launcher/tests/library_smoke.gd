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
    _check(
        launcher._clean_game_title("Example Game (USA).nkit.gcz") == "Example Game",
        "compound extensions and database tags are removed from captions"
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

    launcher.queue_free()
    await process_frame
    if failures == 0:
        print("Library smoke test passed.")
        quit(0)
    quit(1)

func _item_with_id(source_items: Array, item_id: String) -> Dictionary:
    for item in source_items:
        if item is Dictionary and str(item.get("id", "")) == item_id:
            return item
    return {}
