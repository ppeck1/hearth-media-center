extends SceneTree

var failures: Array[String] = []
var fixture_root := "/tmp/hearth-menu-smoke"


func _initialize() -> void:
	OS.set_environment("XDG_CONFIG_HOME", fixture_root)
	_run.call_deferred()


func _run() -> void:
	_remove_tree(fixture_root)
	var main_scene: PackedScene = load("res://main.tscn")
	var hearth = main_scene.instantiate()
	root.add_child(hearth)
	await process_frame
	await process_frame

	_check(
		_item_ids(hearth.items) == ["games", "movies-tv", "settings", "power"],
		"home is simplified to Games, Movies & TV, Settings, and Power"
	)
	var games: Dictionary = _item_with_id(hearth.items, "games")
	_check(
		_item_ids(games.get("children", [])) == ["my-library", "steam"],
		"Games contains My Library and Steam Big Picture"
	)
	var settings: Dictionary = _item_with_id(hearth.items, "settings")
	_check(
		_item_ids(settings.get("children", [])).has("toggle-fullscreen"),
		"Settings exposes a controller-accessible fullscreen toggle"
	)
	_check(
		hearth.WINDOW_TITLE == "Hearth",
		"the runtime window identity omits the debug suffix"
	)
	var movies_tv: Dictionary = _item_with_id(hearth.items, "movies-tv")
	_check(movies_tv.get("menu_layout") == "tile_grid", "Movies & TV requests the tile-grid layout")
	await hearth._show_menu(
		hearth._movies_tv_items(),
		"Movies & TV",
		"HEARTH  ›  MOVIES & TV",
		0,
		"tile_grid"
	)
	await process_frame
	_check(hearth.buttons.size() == 10, "Plex, eight services, and management are available")
	_check(_visible_button_count(hearth.buttons) == 9, "the first screen shows exactly nine tiles")
	hearth._move_tile_grid(0, 1)
	hearth._move_tile_grid(0, 1)
	hearth._move_tile_grid(0, 1)
	_check(hearth.selected == 9, "down navigation reaches Manage Services")
	_check(hearth.buttons[9].visible, "the management tile scrolls into view")

	hearth.streaming_services.open_panel(
		hearth._manageable_streaming_services(),
		hearth.streaming_service_store.enabled_ids
	)
	await process_frame
	_check(hearth.streaming_services.service_buttons.size() == 8, "service manager lists all optional web services")
	hearth.streaming_services._close_without_saving()
	var enabled_services: Array[String] = ["netflix", "hulu"]
	hearth._on_streaming_services_save_requested(enabled_services)
	await process_frame
	await process_frame
	_check(
		_item_ids(hearth.items) == ["plex", "netflix", "hulu", "manage-services"],
		"saving hides removed services while keeping Plex and management"
	)
	_check(FileAccess.file_exists(hearth.streaming_service_store.config_path()), "service choices persist locally")

	hearth.queue_free()
	await process_frame
	_remove_tree(fixture_root)
	_finish()


func _visible_button_count(buttons: Array[Button]) -> int:
	var count := 0
	for button in buttons:
		if button.visible:
			count += 1
	return count


func _item_ids(source_items: Array) -> Array[String]:
	var result: Array[String] = []
	for item in source_items:
		if item is Dictionary:
			result.append(str(item.get("id", "")))
	return result


func _item_with_id(source_items: Array, item_id: String) -> Dictionary:
	for item in source_items:
		if item is Dictionary and str(item.get("id", "")) == item_id:
			return item
	return {}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		var full_path := path.path_join(filename)
		if directory.current_is_dir():
			_remove_tree(full_path)
		else:
			DirAccess.remove_absolute(full_path)
		filename = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


func _finish() -> void:
	if failures.is_empty():
		print("Menu smoke test passed.")
		quit(0)
	else:
		printerr("Menu smoke test failed: " + "; ".join(failures))
		quit(1)
