extends SceneTree

const OUTPUT_DIRECTORY := "res://../docs/images"

func _initialize() -> void:
	_capture_all.call_deferred()

func _capture_all() -> void:
	root.size = Vector2i(1920, 1080)
	var main_scene: PackedScene = load("res://main.tscn")
	if main_scene == null:
		printerr("Could not load Hearth's main scene.")
		quit(1)
		return
	var hearth = main_scene.instantiate()
	root.add_child(hearth)
	await _settle(0.8)
	if not _save("home.png"):
		return

	var streaming_index := _item_index(hearth.items, "streaming")
	if streaming_index < 0:
		printerr("Could not find the Streaming menu item.")
		quit(1)
		return
	hearth._activate(hearth.items[streaming_index], hearth.buttons[streaming_index])
	await _settle(0.8)
	if not _save("streaming.png"):
		return

	hearth.stack.clear()
	hearth._load_home()
	await _settle(0.4)
	hearth.input_settings.open_panel()
	await _settle(0.4)
	if not _save("input-settings.png"):
		return

	print("README screenshots captured in " + ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	quit(0)

func _settle(seconds: float) -> void:
	await process_frame
	await process_frame
	await create_timer(seconds).timeout
	await process_frame

func _save(filename: String) -> bool:
	var directory := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		printerr("Could not create screenshot directory: " + directory)
		quit(1)
		return false
	var texture := root.get_texture()
	if texture == null:
		printerr("Screenshot capture requires a graphical display driver.")
		quit(1)
		return false
	var image := texture.get_image()
	var error := image.save_png(directory.path_join(filename))
	if error != OK:
		printerr("Could not save screenshot: " + filename)
		quit(1)
		return false
	return true

func _item_index(items: Array, item_id: String) -> int:
	for index in range(items.size()):
		if items[index] is Dictionary and items[index].get("id", "") == item_id:
			return index
	return -1
