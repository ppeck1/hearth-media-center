extends SceneTree

const BrowserScene := preload("res://scenes/library/library_browser.tscn")

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
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
    _check(state.get("page_count") == 33, "large systems are paged")
    _check(state.get("instantiated_cards") == 24, "only one 24-card page is instantiated")
    browser.handle_input(&"page_next")
    _check(browser.debug_state().get("page") == 1, "page-next works from any selected card")
    browser.handle_input(&"page_prev")
    _check(browser.debug_state().get("page") == 0, "page-previous returns to the prior page")
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
    browser.queue_free()
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
