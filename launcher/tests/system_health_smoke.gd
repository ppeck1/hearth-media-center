extends SceneTree

const HealthReport := preload("res://scripts/diagnostics/health_report.gd")

var failures := 0
var fixture_root := "/tmp/hearth-system-health-smoke"
var fixture_path := fixture_root.path_join("system-health.json")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(fixture_root)
	var fixture := {
		"schema_version": 1,
		"generated_at": "2026-07-26T12:00:00Z",
		"checks": [
			{
				"id": "installation",
				"label": "Hearth installation",
				"status": "PASS",
				"explanation": "Project installed",
				"remediation": "",
			},
			{
				"id": "rom_library",
				"label": "ROM library",
				"status": "WARNING",
				"explanation": "Readable; 0 game files detected",
				"remediation": "Add personal files under the configured root.",
			},
			{
				"id": "configuration",
				"label": "Configuration directory",
				"status": "PASS",
				"explanation": "/" + "home" + "/private-account/.config/hearth",
				"remediation": "",
			},
			{
				"id": "arbitrary_command",
				"label": "Unsafe",
				"status": "PASS",
				"explanation": "Must never render",
				"remediation": "",
			},
		],
	}
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture, "  ") + "\n")
	file.close()
	OS.set_environment("HEARTH_DIAGNOSTIC_REPORT", fixture_path)

	var document := HealthReport.load_report()
	_check(document.get("checks", []).size() == 3, "diagnostic model accepts only allowlisted check identifiers")
	var configuration := _check_with_id(document.get("checks", []), "configuration")
	_check(configuration.get("explanation") == "Private detail withheld", "diagnostic model redacts private home paths")
	document = HealthReport.with_runtime_context(document, "Standard Remote • keyboard fallback")
	_check(_check_with_id(document.get("checks", []), "active_profile").get("status") == "PASS", "runtime context adds the active input profile")

	var main_scene: PackedScene = load("res://main.tscn")
	var hearth = main_scene.instantiate()
	root.add_child(hearth)
	await process_frame
	await process_frame
	var panel = hearth.get_node("SystemHealth")
	panel.open_panel("Standard Remote • keyboard fallback")
	await process_frame
	_check(panel.visible, "System Health opens as a controller-accessible panel")
	_check(panel.debug_check_count == 4, "System Health renders sanitized report checks and runtime profile")
	_check(panel.debug_last_error.is_empty(), "valid diagnostic fixture has no UI error")
	var remote := InputEventKey.new()
	remote.pressed = true
	remote.physical_keycode = KEY_RIGHT
	_check(panel.handle_unhandled_input(remote, hearth.input_manager), "keyboard arrows move the System Health action focus")
	var home := InputEventKey.new()
	home.pressed = true
	home.physical_keycode = KEY_HOME
	_check(panel.handle_unhandled_input(home, hearth.input_manager), "Home is handled by System Health")
	_check(not panel.visible, "Home closes System Health and returns to Hearth")

	hearth.queue_free()
	await process_frame
	DirAccess.remove_absolute(fixture_path)
	DirAccess.remove_absolute(fixture_root)
	OS.set_environment("HEARTH_DIAGNOSTIC_REPORT", "")
	if failures == 0:
		print("system_health_smoke: PASS")
		quit(0)
	else:
		push_error("system_health_smoke: %d failure(s)" % failures)
		quit(1)


func _check_with_id(checks: Array, check_id: String) -> Dictionary:
	for check_value in checks:
		if check_value is Dictionary and str(check_value.get("id", "")) == check_id:
			return check_value
	return {}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
