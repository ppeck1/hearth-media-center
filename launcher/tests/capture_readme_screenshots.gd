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

	await _show_section(hearth, "games", "Games")
	await _settle(0.6)
	if not _save("games.png"):
		return

	var demo_library := _demo_library()
	hearth.library_browser.open_library(demo_library)
	await _settle(0.6)
	if not _save("library-overview.png"):
		return
	var demo_system: Dictionary = demo_library[0]["children"][0]
	hearth.library_browser._show_system(demo_system)
	await _settle(0.6)
	if not _save("library-system.png"):
		return
	hearth.library_browser.handle_input(&"ui_accept")
	await _settle(0.6)
	if not _save("library-folder.png"):
		return
	hearth.library_browser._close()

	hearth.stack.clear()
	hearth._load_home()
	await _show_section(hearth, "settings", "Settings")
	await _settle(0.6)
	if not _save("settings.png"):
		return
	hearth.stack.clear()
	hearth._load_home()
	await _show_section(hearth, "power", "Power")
	await _settle(0.6)
	if not _save("power.png"):
		return

	hearth.stack.clear()
	hearth._load_home()
	var movies_tv_index := _item_index(hearth.items, "movies-tv")
	if movies_tv_index < 0:
		printerr("Could not find the Movies & TV menu item.")
		quit(1)
		return
	var movies_tv: Dictionary = hearth.items[movies_tv_index]
	hearth.stack.append({
		"items": hearth.items,
		"title": hearth.current_menu_title,
		"path": hearth.current_menu_path,
		"index": movies_tv_index,
		"layout": hearth.current_menu_layout,
	})
	await hearth._show_menu(
		hearth._movies_tv_items(),
		"Movies & TV",
		hearth.current_menu_path + "  ›  Movies & TV",
		0,
		"tile_grid"
	)
	await _settle(0.8)
	if not _save("streaming.png"):
		return
	hearth.streaming_services.open_panel(
		hearth._manageable_streaming_services(),
		hearth.streaming_service_store.enabled_ids
	)
	await _settle(0.4)
	if not _save("streaming-services.png"):
		return
	hearth.streaming_services._close_without_saving()

	hearth.stack.clear()
	hearth._load_home()
	await _settle(0.4)
	hearth.input_settings.open_panel()
	await _settle(0.4)
	if not _save("input-settings.png"):
		return
	hearth.input_settings._close_and_discard()
	hearth.library_settings.open_panel(
		hearth.library_settings_store.data,
		hearth._launcher_system_options()
	)
	await _settle(0.4)
	if not _save("library-settings.png"):
		return
	hearth.library_settings._close_without_saving()

	var diagnostic_fixture := "/tmp/hearth-readme-system-health.json"
	var diagnostic_file := FileAccess.open(diagnostic_fixture, FileAccess.WRITE)
	if diagnostic_file == null:
		printerr("Could not create the System Health screenshot fixture.")
		quit(1)
		return
	diagnostic_file.store_string(JSON.stringify(_demo_health_report(), "  ") + "\n")
	diagnostic_file.close()
	OS.set_environment("HEARTH_DIAGNOSTIC_REPORT", diagnostic_fixture)
	hearth.system_health.open_panel("Standard Remote • demo fixture")
	await _settle(0.5)
	if not _save("system-health.png"):
		return
	hearth.system_health._close()
	OS.set_environment("HEARTH_DIAGNOSTIC_REPORT", "")
	DirAccess.remove_absolute(diagnostic_fixture)

	print("README screenshots captured in " + ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	quit(0)

func _show_section(hearth, item_id: String, title: String) -> void:
	var item_index := _item_index(hearth.items, item_id)
	if item_index < 0:
		printerr("Could not find the %s menu item." % title)
		quit(1)
		return
	var item: Dictionary = hearth.items[item_index]
	await hearth._show_menu(
		item.get("children", []),
		title,
		"HOME  ›  " + title.to_upper(),
		0,
		str(item.get("layout", "carousel"))
	)

func _demo_library() -> Array:
	var wallpaper := "res://assets/backgrounds/arcade-attract-v1.png"
	var folder := {
		"id":"folder-shareware",
		"label":"Freeware & Shareware",
		"subtitle":"3 games",
		"mark":"DIR",
		"color":"426d8d",
		"type":"folder",
		"art":"res://assets/nav/games-panel-v1.svg",
		"art_fit":"contain",
		"wallpaper":wallpaper,
		"children":[
			{"id":"demo-adventure","label":"Adventure Demo","mark":"GAME","color":"5b8f78","type":"unavailable","art":"res://assets/systems/game-boy-cutout-v3.png","art_fit":"contain"},
			{"id":"demo-arcade","label":"Arcade Classic","mark":"GAME","color":"9a6b35","type":"unavailable","art":"res://assets/systems/mame-cutout-v3.png","art_fit":"contain"},
			{"id":"demo-puzzle","label":"Puzzle Collection","mark":"GAME","color":"6d5e9f","type":"unavailable","art":"res://assets/systems/snes-cutout-v3.png","art_fit":"contain"},
		]
	}
	var system := {
		"id":"demo-system",
		"label":"Demo System",
		"subtitle":"6 games available",
		"mark":"DEMO",
		"color":"426d8d",
		"type":"submenu",
		"art":"res://assets/systems/n64-cutout-v3.png",
		"art_fit":"contain",
		"wallpaper":"res://assets/backgrounds/console-gallery-v1.png",
		"children":[
			folder,
			{"id":"demo-racer","label":"Open Racer","mark":"GAME","color":"4d8b5e","type":"unavailable","art":"res://assets/systems/n64-cutout-v3.png","art_fit":"contain"},
			{"id":"demo-platformer","label":"Community Platformer","mark":"GAME","color":"b85b4f","type":"unavailable","art":"res://assets/systems/nes-cutout-v3.png","art_fit":"contain"},
			{"id":"demo-source-port","label":"Source Port Demo","mark":"GAME","color":"8d5948","type":"unavailable","art":"res://assets/systems/pc-engine-cutout-v3.png","art_fit":"contain"},
		]
	}
	return [{
		"id":"demo-family",
		"label":"Demo Collection",
		"mark":"DEMO",
		"color":"426d8d",
		"type":"submenu",
		"art":"res://assets/brands/classics-wordmark-v1.svg",
		"children":[system]
	}]

func _demo_health_report() -> Dictionary:
	return {
		"schema_version": 1,
		"generated_at": "2026-07-26T12:00:00Z",
		"summary": {"exit_code": 0},
		"checks": [
			{"id":"installation","label":"Hearth installation","status":"PASS","explanation":"Project and bounded helpers are installed","remediation":""},
			{"id":"godot","label":"Godot runtime","status":"PASS","explanation":"Godot 4 runtime is available","remediation":""},
			{"id":"retroarch","label":"RetroArch","status":"PASS","explanation":"RetroArch is available","remediation":""},
			{"id":"libretro_cores","label":"Libretro cores","status":"PASS","explanation":"6 compatible core files detected","remediation":""},
			{"id":"steam","label":"Steam","status":"PASS","explanation":"Steam is available","remediation":""},
			{"id":"plex","label":"Plex HTPC","status":"WARNING","explanation":"Plex HTPC Flatpak is not installed","remediation":"Install Plex HTPC only if this destination is required."},
			{"id":"browser","label":"Supported browser","status":"PASS","explanation":"Supported browser is available","remediation":""},
			{"id":"rom_library","label":"ROM library","status":"PASS","explanation":"Readable; 12 fictional fixture games detected","remediation":""},
			{"id":"input_bridge","label":"Input bridge","status":"NOT APPLICABLE","explanation":"Idle until a translated destination opens","remediation":""},
			{"id":"uinput","label":"/dev/uinput","status":"PASS","explanation":"Active user can create the bounded virtual keyboard","remediation":""},
			{"id":"session","label":"Display session","status":"PASS","explanation":"Wayland session detected","remediation":""},
			{"id":"autostart","label":"Launch at login","status":"PASS","explanation":"systemd user service enabled","remediation":""},
		],
	}

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
