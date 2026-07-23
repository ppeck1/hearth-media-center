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
    await hearth._show_menu(families, "My Library", "HEARTH  ›  MY LIBRARY")
    await _settle()
    _save("families.png")

    var nintendo: Dictionary = _item_with_id(families, "nintendo")
    var nintendo_systems: Array = nintendo.get("children", [])
    await hearth._show_menu(nintendo_systems, "Nintendo", "HEARTH  ›  MY LIBRARY  ›  NINTENDO", 3)
    await _settle()
    _save("systems.png")

    var n64: Dictionary = _item_with_id(nintendo_systems, "n64")
    await hearth._show_menu(
        n64.get("children", []),
        str(n64.get("label", "Nintendo 64")),
        "HEARTH  ›  MY LIBRARY  ›  NINTENDO  ›  NINTENDO 64"
    )
    await _settle()
    _save("games.png")

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
