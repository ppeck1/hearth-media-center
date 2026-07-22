class_name HearthInputProfileStore
extends RefCounted

const DEFAULTS_PATH := "res://config/input-profiles-defaults.json"
const SCHEMA_VERSION := 2
const Actions := preload("res://scripts/input/input_actions.gd")
const EventCodec := preload("res://scripts/input/input_event_codec.gd")

const RECOVERY_CONTROLS := {
	"key:arrow_up": Actions.NAVIGATE_UP,
	"key:arrow_down": Actions.NAVIGATE_DOWN,
	"key:arrow_left": Actions.NAVIGATE_LEFT,
	"key:arrow_right": Actions.NAVIGATE_RIGHT,
	"key:enter": Actions.SELECT,
	"key:escape": Actions.BACK,
}

var data: Dictionary = {}
var defaults: Dictionary = {}
var last_error := ""

func load_profiles() -> bool:
	last_error = ""
	defaults = _read_json(DEFAULTS_PATH)
	if not _is_valid(defaults):
		data = {}
		last_error = "The built-in input profiles are invalid."
		return false
	data = defaults.duplicate(true)
	var path := config_path()
	if not FileAccess.file_exists(path):
		return true
	var saved := _merge_with_defaults(_read_json(path))
	if not _is_valid(saved):
		last_error = "Saved input profiles were invalid; built-in defaults are active."
		return false
	data = saved
	return true

func reload() -> bool:
	return load_profiles()

func save() -> bool:
	last_error = ""
	if not _is_valid(data):
		last_error = "Input profiles could not be saved because their format is invalid."
		return false
	var path := config_path()
	var parent := path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		last_error = "Hearth could not create its input settings folder."
		return false
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Hearth could not write the input settings file."
		return false
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK and FileAccess.file_exists(path):
		var backup_path := path + ".backup"
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var backup_error := DirAccess.rename_absolute(path, backup_path)
		if backup_error != OK:
			last_error = "Hearth could not replace the existing input settings safely."
			return false
		rename_error = DirAccess.rename_absolute(temporary_path, path)
		if rename_error == OK:
			DirAccess.remove_absolute(backup_path)
		else:
			DirAccess.rename_absolute(backup_path, path)
	if rename_error != OK:
		last_error = "Hearth could not finish saving the input settings file."
		return false
	return true

func profile_ids() -> Array[String]:
	var result: Array[String] = []
	for profile in data.get("profiles", []):
		if profile is Dictionary:
			result.append(str(profile.get("id", "")))
	return result

func profile(profile_id: String) -> Dictionary:
	for candidate in data.get("profiles", []):
		if candidate is Dictionary and candidate.get("id", "") == profile_id:
			return candidate
	return {}

func profile_label(profile_id: String) -> String:
	return str(profile(profile_id).get("label", profile_id.replace("_", " ").capitalize()))

func bindings(profile_id: String, action_id: String) -> Array:
	var selected := profile(profile_id)
	var profile_bindings: Dictionary = selected.get("bindings", {})
	return profile_bindings.get(action_id, [])

func replace_binding(profile_id: String, action_id: String, binding: Dictionary) -> bool:
	var selected := profile(profile_id)
	var reserved_action := str(RECOVERY_CONTROLS.get(binding.get("control", ""), ""))
	if selected.is_empty() or not _is_valid_binding(binding) or (not reserved_action.is_empty() and reserved_action != action_id) or not binding_conflict(profile_id, action_id, binding).is_empty():
		return false
	var profile_bindings: Dictionary = selected.get("bindings", {})
	profile_bindings[action_id] = [binding.duplicate(true)]
	selected["bindings"] = profile_bindings
	return true

func binding_conflict(profile_id: String, action_id: String, binding: Dictionary) -> String:
	var selected := profile(profile_id)
	var candidate_control := str(binding.get("control", ""))
	var candidate_direction := int(binding.get("direction", 0))
	for existing_action in selected.get("bindings", {}):
		if existing_action == action_id:
			continue
		for existing in selected["bindings"][existing_action]:
			if not existing is Dictionary or existing.get("control", "") != candidate_control:
				continue
			if candidate_control.begins_with("gamepad_axis:") and int(existing.get("direction", 0)) != candidate_direction:
				continue
			return str(existing_action)
	return ""

func reset_profile(profile_id: String) -> bool:
	var default_profile := _profile_in(defaults, profile_id)
	if default_profile.is_empty():
		return false
	var profiles: Array = data.get("profiles", [])
	for index in range(profiles.size()):
		if profiles[index] is Dictionary and profiles[index].get("id", "") == profile_id:
			profiles[index] = default_profile.duplicate(true)
			return true
	return false

func assign_profile(device: Dictionary, profile_id: String) -> bool:
	if profile(profile_id).is_empty():
		return false
	var selector := _godot_selector_for_device(device)
	var assignments: Array = data.get("device_assignments", [])
	for assignment in assignments:
		if assignment is Dictionary and _assignment_matches_device(assignment, device):
			assignment["profile_id"] = profile_id
			return true
	assignments.append({"profile_id": profile_id, "selectors": [selector]})
	data["device_assignments"] = assignments
	return true

func profile_for_device(device: Dictionary) -> String:
	for assignment in data.get("device_assignments", []):
		if assignment is Dictionary and _assignment_matches_device(assignment, device):
			return str(assignment.get("profile_id", ""))
	var keyboard_like := bool(device.get("keyboard_like", false))
	var lowered_name := str(device.get("name", "")).to_lower()
	for candidate in data.get("profiles", []):
		if not candidate is Dictionary:
			continue
		var matcher: Dictionary = candidate.get("match", {})
		if keyboard_like and bool(matcher.get("keyboard_like", false)):
			return str(candidate.get("id", ""))
		for fragment in matcher.get("name_contains", []):
			if lowered_name.contains(str(fragment).to_lower()):
				return str(candidate.get("id", ""))
	var device_class := "keyboard" if keyboard_like else "gamepad"
	return str(data.get("default_profiles", {}).get(device_class, "standard_remote" if keyboard_like else "ps5"))

static func config_path() -> String:
	var config_root := OS.get_environment("XDG_CONFIG_HOME")
	if config_root.is_empty():
		var home := OS.get_environment("HOME")
		if not home.is_empty():
			config_root = home.path_join(".config")
	if config_root.is_empty():
		return ProjectSettings.globalize_path("user://input-profiles.json")
	return config_root.path_join("hearth").path_join("input-profiles.json")

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}

func _is_valid(candidate: Dictionary) -> bool:
	if candidate.get("schema_version", 0) != SCHEMA_VERSION:
		return false
	if not candidate.get("profiles", null) is Array or candidate.get("profiles", []).is_empty():
		return false
	if not candidate.get("device_assignments", null) is Array or not candidate.get("default_profiles", null) is Dictionary:
		return false
	var profile_id_set: Dictionary = {}
	for candidate_profile in candidate.get("profiles", []):
		if not candidate_profile is Dictionary:
			return false
		var candidate_id := str(candidate_profile.get("id", ""))
		if candidate_id.is_empty() or profile_id_set.has(candidate_id) or not candidate_profile.get("bindings", null) is Dictionary:
			return false
		profile_id_set[candidate_id] = true
		var candidate_bindings: Dictionary = candidate_profile.get("bindings", {})
		for action_id in Actions.ids():
			if not candidate_bindings.has(action_id):
				return false
		for action_id in candidate_bindings:
			if not action_id in Actions.ids():
				return false
			var action_bindings = candidate_bindings[action_id]
			if not action_bindings is Array or action_bindings.is_empty():
				return false
			for binding in action_bindings:
				if not binding is Dictionary or not _is_valid_binding(binding):
					return false
	for default_id in candidate.get("default_profiles", {}).values():
		if not profile_id_set.has(str(default_id)):
			return false
	for assignment in candidate.get("device_assignments", []):
		if not assignment is Dictionary or not profile_id_set.has(str(assignment.get("profile_id", ""))) or not assignment.get("selectors", null) is Array or assignment.get("selectors", []).is_empty():
			return false
		for selector in assignment.get("selectors", []):
			if not selector is Dictionary or not str(selector.get("backend", "")) in ["godot", "evdev"]:
				return false
			if selector.get("backend", "") == "godot" and str(selector.get("device_kind", "")).is_empty() and str(selector.get("guid", "")).is_empty() and str(selector.get("name", "")).is_empty():
				return false
			if selector.get("backend", "") == "evdev" and str(selector.get("vendor_id", "")).is_empty() and str(selector.get("product_id", "")).is_empty() and str(selector.get("capability_fingerprint", "")).is_empty() and str(selector.get("uniq", "")).is_empty():
				return false
	return true

func _is_valid_binding(binding: Dictionary) -> bool:
	return EventCodec.is_valid_binding(binding)

func _profile_in(container: Dictionary, profile_id: String) -> Dictionary:
	for candidate in container.get("profiles", []):
		if candidate is Dictionary and candidate.get("id", "") == profile_id:
			return candidate
	return {}

func _merge_with_defaults(saved: Dictionary) -> Dictionary:
	if saved.get("schema_version", 0) != SCHEMA_VERSION:
		return saved
	if not saved.get("profiles", null) is Array or not saved.get("default_profiles", null) is Dictionary or not saved.get("device_assignments", null) is Array:
		return saved
	for saved_profile_shape in saved.get("profiles", []):
		if not saved_profile_shape is Dictionary or not saved_profile_shape.get("bindings", null) is Dictionary:
			return saved
	var merged := saved.duplicate(true)
	var saved_profiles: Array = merged.get("profiles", [])
	for default_profile in defaults.get("profiles", []):
		if not default_profile is Dictionary:
			continue
		var saved_profile := _profile_in(merged, str(default_profile.get("id", "")))
		if saved_profile.is_empty():
			saved_profiles.append(default_profile.duplicate(true))
			continue
		var saved_bindings: Dictionary = saved_profile.get("bindings", {})
		for action_id in default_profile.get("bindings", {}):
			if not saved_bindings.has(action_id):
				saved_bindings[action_id] = default_profile["bindings"][action_id].duplicate(true)
	merged["profiles"] = saved_profiles
	var merged_defaults: Dictionary = defaults.get("default_profiles", {}).duplicate(true)
	for device_class in merged.get("default_profiles", {}):
		merged_defaults[device_class] = merged["default_profiles"][device_class]
	merged["default_profiles"] = merged_defaults
	return merged

func _godot_selector_for_device(device: Dictionary) -> Dictionary:
	if bool(device.get("keyboard_like", false)):
		return {"backend": "godot", "device_kind": "keyboard"}
	var guid := str(device.get("guid", ""))
	if not guid.is_empty():
		return {"backend": "godot", "guid": guid}
	return {"backend": "godot", "name": str(device.get("name", ""))}

func _assignment_matches_device(assignment: Dictionary, device: Dictionary) -> bool:
	for selector in assignment.get("selectors", []):
		if not selector is Dictionary or selector.get("backend", "") != "godot":
			continue
		if selector.get("device_kind", "") == "keyboard" and bool(device.get("keyboard_like", false)):
			return true
		if not str(selector.get("guid", "")).is_empty() and selector.get("guid", "") == device.get("guid", ""):
			return true
		if not str(selector.get("name", "")).is_empty() and selector.get("name", "") == device.get("name", ""):
			return true
	return false
