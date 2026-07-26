class_name HearthStreamingServiceStore
extends RefCounted

const SCHEMA_VERSION := 1

var enabled_ids: Array[String] = []
var available_ids: Array[String] = []
var last_error := ""


func load(default_ids: Array[String]) -> bool:
	last_error = ""
	available_ids = _unique_ids(default_ids)
	enabled_ids = available_ids.duplicate()
	var path := config_path()
	if not FileAccess.file_exists(path):
		return true
	var document := _read_json(path)
	if document.get("schema_version", 0) != SCHEMA_VERSION or not document.get("enabled_services", null) is Array:
		last_error = "Saved Movies & TV services were invalid; all services are visible."
		return false
	var saved: Array[String] = []
	for value in document.get("enabled_services", []):
		var service_id := str(value)
		if service_id in available_ids and service_id not in saved:
			saved.append(service_id)
	enabled_ids = saved
	return true


func save(next_enabled_ids: Array[String]) -> bool:
	last_error = ""
	enabled_ids.clear()
	for service_id in available_ids:
		if service_id in next_enabled_ids:
			enabled_ids.append(service_id)
	var path := config_path()
	var parent := path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		last_error = "Hearth could not create its Movies & TV settings folder."
		return false
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Hearth could not write the Movies & TV service settings."
		return false
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"enabled_services": enabled_ids,
	}, "  ") + "\n")
	file.close()
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK and FileAccess.file_exists(path):
		var backup_path := path + ".backup"
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(path, backup_path) != OK:
			last_error = "Hearth could not replace the Movies & TV settings safely."
			return false
		rename_error = DirAccess.rename_absolute(temporary_path, path)
		if rename_error == OK:
			DirAccess.remove_absolute(backup_path)
		else:
			DirAccess.rename_absolute(backup_path, path)
	if rename_error != OK:
		last_error = "Hearth could not finish saving the Movies & TV settings."
		return false
	return true


static func config_path() -> String:
	var config_root := OS.get_environment("XDG_CONFIG_HOME")
	if config_root.is_empty():
		var home := OS.get_environment("HOME")
		if not home.is_empty():
			config_root = home.path_join(".config")
	if config_root.is_empty():
		return ProjectSettings.globalize_path("user://streaming-services.json")
	return config_root.path_join("hearth").path_join("streaming-services.json")


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}


func _unique_ids(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not value.is_empty() and value not in result:
			result.append(value)
	return result
