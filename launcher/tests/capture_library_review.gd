extends SceneTree

const OUTPUT_DIRECTORY := "/tmp/hearth-library-review"

func _initialize() -> void:
    _capture_all.call_deferred()

func _capture_all() -> void:
    root.size = Vector2i(1920, 1080)
    var main_scene: PackedScene = load("res://main.tscn")
    var hearth = main_scene.instantiate()
    root.add_child(hearth)
    hearth.set_process_input(false)
    hearth.set_process_unhandled_input(false)
    hearth.input_manager.set_process_input(false)
    hearth.input_manager.set_process_unhandled_input(false)
    await _settle()

    var settings: Dictionary = _item_with_id(hearth.items, "settings")
    await hearth._show_menu(settings.get("children", []), "Settings", "HEARTH  ›  SETTINGS")
    await _settle()
    _save("settings.png")

    var families: Array = hearth._library_systems()
    hearth.library_activity_store.reload()
    hearth.library_browser.open_library(families, hearth.library_activity_store)
    await _settle()
    _save("library-home.png")

    var nintendo: Dictionary = _item_with_id(families, "nintendo")
    var nintendo_systems: Array = nintendo.get("children", [])
    hearth.library_browser._current_family = nintendo
    hearth.library_browser._drawer_level = 1
    hearth.library_browser._drawer_index = 0
    hearth.library_browser._build_drawer()
    await _settle()
    _save("nintendo-drawer.png")

    var n64: Dictionary = _item_with_id(nintendo_systems, "n64")
    hearth.library_browser._show_system(n64)
    await _settle()
    _save("n64-games.png")

    var pc: Dictionary = _item_with_id(families, "pc")
    var pc_games: Dictionary = _item_with_id(pc.get("children", []), "pc-games")
    hearth.library_browser._current_family = pc
    hearth.library_browser._drawer_level = 1
    hearth.library_browser._drawer_index = 1
    hearth.library_browser._build_drawer()
    hearth.library_browser._show_system(pc_games)
    await _settle()
    _save("pc-games.png")

    print("Library review screenshots captured in " + OUTPUT_DIRECTORY)
    quit(0)

func _settle() -> void:
    await process_frame
    await process_frame
    await create_timer(0.5).timeout
    await process_frame

func _save(filename: String) -> void:
    if DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY) != OK:
        printerr("Could not create screenshot directory.")
        quit(1)
        return
    var image := root.get_texture().get_image()
    if image.save_png(OUTPUT_DIRECTORY.path_join(filename)) != OK:
        printerr("Could not save screenshot: " + filename)
        quit(1)

func _item_with_id(source_items: Array, item_id: String) -> Dictionary:
    for item in source_items:
        if item is Dictionary and str(item.get("id", "")) == item_id:
            return item
    return {}
