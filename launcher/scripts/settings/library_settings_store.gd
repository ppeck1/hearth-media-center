class_name HearthLibrarySettingsStore
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULTS := {
	"schema_version": SCHEMA_VERSION,
	"artwork_fit": "smart",
	"folder_art_mode": "named_or_first",
	"folder_wallpapers": true,
	"preserve_folders": true,
	"retroarch_fullscreen": true,
	"core_overrides": {},
}

var data: Dictionary = DEFAULTS.duplicate(true)
var last_error := ""


func load_settings() -> bool:
	last_error = ""
	data = DEFAULTS.duplicate(true)
	var path := config_path()
	if not FileAccess.file_exists(path):
		return true
	var saved := _read_json(path)
	if saved.get("schema_version", 0) != SCHEMA_VERSION:
		last_error = "Saved library settings were invalid; beginner-friendly defaults are active."
		return false
	var normalized := _normalized(saved)
	if not _is_valid(normalized):
		last_error = "Saved library settings were invalid; beginner-friendly defaults are active."
		return false
	data = normalized
	return true


func save_settings(next_data: Dictionary) -> bool:
	last_error = ""
	var normalized := _normalized(next_data)
	if not _is_valid(normalized):
		last_error = "Library settings could not be saved because their format is invalid."
		return false
	var path := config_path()
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		last_error = "Hearth could not create its library settings folder."
		return false
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Hearth could not write the library settings."
		return false
	file.store_string(JSON.stringify(normalized, "  ") + "\n")
	file.close()
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK and FileAccess.file_exists(path):
		var backup_path := path + ".backup"
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(path, backup_path) != OK:
			last_error = "Hearth could not replace the library settings safely."
			return false
		rename_error = DirAccess.rename_absolute(temporary_path, path)
		if rename_error == OK:
			DirAccess.remove_absolute(backup_path)
		else:
			DirAccess.rename_absolute(backup_path, path)
	if rename_error != OK:
		last_error = "Hearth could not finish saving the library settings."
		return false
	data = normalized
	return true


func reset_defaults() -> void:
	data = DEFAULTS.duplicate(true)


func folder_art_mode() -> String:
	return str(data.get("folder_art_mode", "named_or_first"))


func artwork_fit() -> String:
	return str(data.get("artwork_fit", "smart"))


func preserve_folders() -> bool:
	return bool(data.get("preserve_folders", true))


func folder_wallpapers() -> bool:
	return bool(data.get("folder_wallpapers", true))


func retroarch_fullscreen() -> bool:
	return bool(data.get("retroarch_fullscreen", true))


func core_for(system: Dictionary) -> String:
	var system_id := str(system.get("id", ""))
	var overrides: Dictionary = data.get("core_overrides", {})
	var override := str(overrides.get(system_id, ""))
	return override if not override.is_empty() else str(system.get("core", ""))


static func config_path() -> String:
	var config_root := OS.get_environment("XDG_CONFIG_HOME")
	if config_root.is_empty():
		var home := OS.get_environment("HOME")
		if not home.is_empty():
			config_root = home.path_join(".config")
	if config_root.is_empty():
		return ProjectSettings.globalize_path("user://library-settings.json")
	return config_root.path_join("hearth").path_join("library-settings.json")


func _normalized(candidate: Dictionary) -> Dictionary:
	var overrides: Dictionary = {}
	if candidate.get("core_overrides", null) is Dictionary:
		for system_id in candidate.get("core_overrides", {}):
			var core_file := str(candidate["core_overrides"][system_id])
			if not str(system_id).is_empty() and _is_core_filename(core_file):
				overrides[str(system_id)] = core_file
	return {
		"schema_version": SCHEMA_VERSION,
		"artwork_fit": str(candidate.get("artwork_fit", "smart")),
		"folder_art_mode": str(candidate.get("folder_art_mode", "named_or_first")),
		"folder_wallpapers": bool(candidate.get("folder_wallpapers", true)),
		"preserve_folders": bool(candidate.get("preserve_folders", true)),
		"retroarch_fullscreen": bool(candidate.get("retroarch_fullscreen", true)),
		"core_overrides": overrides,
	}


func _is_valid(candidate: Dictionary) -> bool:
	if candidate.get("schema_version", 0) != SCHEMA_VERSION:
		return false
	if str(candidate.get("artwork_fit", "")) not in ["smart", "contain", "cover"]:
		return false
	if str(candidate.get("folder_art_mode", "")) not in ["disabled", "named", "named_or_first"]:
		return false
	if not candidate.get("folder_wallpapers", null) is bool:
		return false
	if not candidate.get("preserve_folders", null) is bool:
		return false
	if not candidate.get("retroarch_fullscreen", null) is bool:
		return false
	if not candidate.get("core_overrides", null) is Dictionary:
		return false
	for system_id in candidate.get("core_overrides", {}):
		if str(system_id).is_empty() or not _is_core_filename(str(candidate["core_overrides"][system_id])):
			return false
	return true


func _is_core_filename(value: String) -> bool:
	return value.ends_with("_libretro.so") and value.get_file() == value


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}
