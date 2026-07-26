extends SceneTree

const BrowserScene := preload("res://scenes/library/library_browser.tscn")

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var temporary_art := "/tmp/hearth-library-browser-smoke.png"
    var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    _check(image.save_png(temporary_art) == OK, "temporary external cover is created")
    var browser = BrowserScene.instantiate()
    root.add_child(browser)
    await process_frame
    var games: Array = []
    for index in range(790):
        games.append({
            "id":"game-%d" % index,
            "label":"Game %03d" % index,
            "mark":"ROM",
            "type":"command"
        })
    games[0]["art"] = temporary_art
    games[12]["art"] = temporary_art
    var families := [{
        "id":"sega",
        "label":"Sega",
        "children":[{
            "id":"genesis",
            "label":"Genesis",
            "children":games
        }]
    }]
    browser.open_library(families, {
        "game-12":{"last_played":100, "play_count":4, "play_seconds":800},
        "game-30":{"last_played":200, "play_count":2, "rating":9}
    })
    await process_frame
    _check(browser.debug_total_games == 790, "catalog contains every supplied game")
    _check(browser.debug_instantiated_cards <= 18, "home creates at most three short rows")
    var home_external_card: Button
    for card in browser._card_buttons:
        if card.has_meta("external_art_path"):
            home_external_card = card
            break
    _check(
        home_external_card != null
        and (home_external_card.get_meta("art_node") as TextureRect).texture != null,
        "home rows load visible external covers"
    )
    browser.handle_input(&"ui_right")
    browser.handle_input(&"ui_down")
    var state: Dictionary = browser.debug_state()
    _check(
        state.get("content_index") == 2 and state.get("selected_row") == 1 and state.get("selected_column") == 0,
        "down follows sparse home-row geometry"
    )
    browser.handle_input(&"ui_right")
    _check(browser.debug_state().get("content_index") == 2, "right does not spill into the next sparse row")
    browser.handle_input(&"ui_down")
    state = browser.debug_state()
    _check(
        state.get("content_index") == 3 and state.get("selected_row") == 2 and state.get("selected_column") == 0,
        "down reaches a shorter third home row"
    )
    browser.handle_input(&"ui_left")
    browser.handle_input(&"ui_down")
    browser.handle_input(&"ui_accept") # enter Sega family
    _check(browser.debug_state().get("drawer_level") == 1, "family selection opens the system drawer")
    browser.handle_input(&"ui_cancel")
    _check(
        browser.visible and browser.debug_state().get("drawer_level") == 0,
        "back from the system drawer returns to family choices"
    )
    browser.handle_input(&"ui_accept") # reopen the selected Sega family
    browser.handle_input(&"ui_down")
    browser.handle_input(&"ui_accept") # open Genesis
    await process_frame
    state = browser.debug_state()
    _check(state.get("view") == "system", "system selection opens the game grid")
    _check(state.get("page_count") == 1, "each system uses one scrollable page")
    _check(state.get("instantiated_cards") == 790, "the scrollable grid contains every game")
    var first_art: TextureRect = browser._card_buttons[0].get_meta("art_node")
    var first_mark: Label = browser._card_buttons[0].get_meta("mark_node")
    _check(first_art.texture != null and not first_mark.visible, "system grid displays visible external covers")
    browser.handle_input(&"page_next")
    _check(browser.debug_state().get("content_index") == 24, "page-next moves down one visible screen")
    browser.handle_input(&"page_prev")
    _check(browser.debug_state().get("content_index") == 0, "page-previous moves up one visible screen")
    for index in range(70):
        browser._load_texture("/tmp/hearth-missing-art-%d.png" % index)
    _check(browser._texture_cache.size() == 64, "cover texture cache is capped at 64 entries")
    browser.handle_input(&"ui_cancel")
    state = browser.debug_state()
    _check(
        browser.debug_view == "home" and state.get("drawer_level") == 0,
        "back from a system returns home at the family drawer"
    )
    browser.handle_input(&"ui_cancel")
    _check(browser.debug_view == "closed", "back from home closes the overlay")

    var launched_ids: Array[String] = []
    browser.launch_requested.connect(func(item: Dictionary) -> void:
        launched_ids.append(str(item.get("id", "")))
    )
    var folder_game := {"id":"nested-game","label":"Nested Game","type":"command"}
    var nested_system := {
        "id":"nested-system",
        "label":"Nested System",
        "children":[{
            "id":"folder-rpg",
            "label":"Role Playing",
            "type":"folder",
            "wallpaper":temporary_art,
            "children":[folder_game]
        }]
    }
    browser.open_library([{
        "id":"nested-family",
        "label":"Nested Family",
        "children":[nested_system]
    }])
    browser._show_system(nested_system)
    _check(browser.debug_total_games == 1, "home totals count games inside folders without counting folders")
    browser.handle_input(&"ui_accept")
    _check(
        browser.debug_state().get("folder_depth") == 1
        and browser.debug_state().get("collection_id") == "folder-rpg",
        "selecting a folder opens its branch"
    )
    _check(
        browser.debug_state().get("wallpaper_path") == temporary_art,
        "a folder wallpaper becomes the active browsing background"
    )
    browser.handle_input(&"ui_accept")
    _check(launched_ids == ["nested-game"], "only a game, not its parent folder, requests launch")
    browser.handle_input(&"ui_cancel")
    _check(
        browser.debug_state().get("folder_depth") == 0
        and browser.debug_state().get("collection_id") == "nested-system",
        "back from a folder returns to its parent branch"
    )
    browser.queue_free()
    DirAccess.remove_absolute(temporary_art)
    if failures == 0:
        print("library_browser_smoke: PASS")
        quit(0)
    else:
        push_error("library_browser_smoke: %d failure(s)" % failures)
        quit(1)

func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)
