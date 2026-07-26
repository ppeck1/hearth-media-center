class_name HearthHealthReport
extends RefCounted

const SCHEMA_VERSION := 1
const STATUSES := ["PASS", "WARNING", "FAIL", "NOT CONFIGURED", "NOT APPLICABLE"]
const ALLOWED_IDS := [
	"installation",
	"godot",
	"retroarch",
	"libretro_cores",
	"steam",
	"plex",
	"browser",
	"rom_library",
	"game_count",
	"native_manifest",
	"active_profile",
	"controller",
	"input_bridge",
	"uinput",
	"session",
	"display",
	"configuration",
	"autostart",
]


static func report_path() -> String:
	var override := OS.get_environment("HEARTH_DIAGNOSTIC_REPORT")
	if not override.is_empty():
		return override
	var state_root := OS.get_environment("XDG_STATE_HOME")
	if state_root.is_empty():
		var home := OS.get_environment("HOME")
		if not home.is_empty():
			state_root = home.path_join(".local").path_join("state")
	if state_root.is_empty():
		return ProjectSettings.globalize_path("user://system-health.json")
	return state_root.path_join("hearth").path_join("system-health.json")


static func load_report(path := "") -> Dictionary:
	var selected_path := report_path() if path.is_empty() else path
	var file := FileAccess.open(selected_path, FileAccess.READ)
	if file == null:
		return {
			"schema_version": SCHEMA_VERSION,
			"checks": [],
			"error": "No diagnostic report is available yet.",
		}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {
			"schema_version": SCHEMA_VERSION,
			"checks": [],
			"error": "The diagnostic report could not be read safely.",
		}
	var document: Dictionary = parser.data
	if int(document.get("schema_version", 0)) != SCHEMA_VERSION:
		return {
			"schema_version": SCHEMA_VERSION,
			"checks": [],
			"error": "The diagnostic report version is not supported.",
		}
	var checks: Array[Dictionary] = []
	for check_value in document.get("checks", []):
		if not check_value is Dictionary:
			continue
		var check_id := str(check_value.get("id", ""))
		var status := str(check_value.get("status", ""))
		if check_id not in ALLOWED_IDS or status not in STATUSES:
			continue
		checks.append({
			"id": check_id,
			"label": _safe_text(str(check_value.get("label", check_id.replace("_", " ").capitalize())), 80),
			"status": status,
			"explanation": _safe_text(str(check_value.get("explanation", "")), 180),
			"remediation": _safe_text(str(check_value.get("remediation", "")), 220),
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"generated_at": _safe_text(str(document.get("generated_at", "")), 48),
		"checks": checks,
		"error": "",
	}


static func with_runtime_context(document: Dictionary, profile_label: String) -> Dictionary:
	var result := document.duplicate(true)
	var checks: Array = result.get("checks", [])
	checks = checks.filter(func(value) -> bool:
		return value is Dictionary and str(value.get("id", "")) != "active_profile"
	)
	checks.append({
		"id": "active_profile",
		"label": "Active controller profile",
		"status": "PASS" if not profile_label.is_empty() else "NOT CONFIGURED",
		"explanation": _safe_text(profile_label if not profile_label.is_empty() else "No active profile", 80),
		"remediation": "Choose a profile in Controllers and Remotes." if profile_label.is_empty() else "",
	})
	checks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ALLOWED_IDS.find(str(a.get("id", ""))) < ALLOWED_IDS.find(str(b.get("id", "")))
	)
	result["checks"] = checks
	return result


static func _safe_text(value: String, maximum: int) -> String:
	var text := value.replace("\r", " ").replace("\n", " ").strip_edges()
	for marker in ["/" + "home" + "/", "C:" + "\\Users\\", "BEGIN " + "PRIVATE KEY", "sk" + "-"]:
		if text.contains(marker):
			return "Private detail withheld"
	return text.left(maximum)
