extends SceneTree

const Store := preload("res://scripts/settings/library_settings_store.gd")
const PanelScene := preload("res://scenes/settings/library_settings.tscn")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_config_home := OS.get_environment("XDG_CONFIG_HOME")
	var fixture_root := "/tmp/hearth-library-settings-smoke"
	DirAccess.make_dir_recursive_absolute(fixture_root)
	OS.set_environment("XDG_CONFIG_HOME", fixture_root)

	var store = Store.new()
	_check(store.load_settings(), "missing settings use beginner-friendly defaults")
	_check(store.folder_art_mode() == "named_or_first", "folder images are automatic by default")
	_check(store.folder_wallpapers(), "folder wallpapers are automatic by default")
	_check(store.preserve_folders(), "physical library branches are preserved by default")
	_check(store.retroarch_fullscreen(), "RetroArch launches fullscreen by default")
	_check(store.save_settings({
		"schema_version": 1,
		"folder_art_mode": "named",
		"folder_wallpapers": false,
		"preserve_folders": false,
		"retroarch_fullscreen": false,
		"core_overrides": {"n64":"parallel_n64_libretro.so"},
	}), "custom library settings save atomically")

	var reloaded = Store.new()
	_check(reloaded.load_settings(), "saved library settings reload")
	_check(reloaded.folder_art_mode() == "named", "folder artwork mode persists")
	_check(not reloaded.folder_wallpapers(), "folder wallpaper preference persists")
	_check(not reloaded.preserve_folders(), "flattened-folder preference persists")
	_check(not reloaded.retroarch_fullscreen(), "windowed launch preference persists")
	_check(
		reloaded.core_for({"id":"n64","core":"mupen64plus_next_libretro.so"}) == "parallel_n64_libretro.so",
		"per-system launcher override persists"
	)

	var panel = PanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	panel.open_panel(reloaded.data, [{
		"id":"n64",
		"label":"Nintendo 64",
		"default_core":"mupen64plus_next_libretro.so",
		"default_label":"Mupen64Plus-Next",
		"options":[
			{"core":"mupen64plus_next_libretro.so","label":"Mupen64Plus-Next","installed":true},
			{"core":"parallel_n64_libretro.so","label":"ParaLLEl N64","installed":false},
		]
	}])
	_check(panel.visible, "library settings panel opens")
	var selector: OptionButton = panel.launcher_selectors.get("n64")
	_check(selector != null and selector.item_count == 3, "launcher choices include automatic and compatible cores")
	if selector != null:
		_check(selector.is_item_disabled(2), "cores that are not installed cannot be selected")
	panel.queue_free()
	await process_frame

	var settings_path := Store.config_path()
	var backup_path := settings_path + ".backup"
	var temporary_path := settings_path + ".tmp"
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)
	DirAccess.remove_absolute(settings_path.get_base_dir())
	DirAccess.remove_absolute(fixture_root)
	OS.set_environment("XDG_CONFIG_HOME", previous_config_home)

	if failures == 0:
		print("library_settings_smoke: PASS")
		quit(0)
	else:
		push_error("library_settings_smoke: %d failure(s)" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
