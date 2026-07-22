extends SceneTree

const Actions := preload("res://scripts/input/input_actions.gd")
const EventCodec := preload("res://scripts/input/input_event_codec.gd")

var failures: Array[String] = []

func _initialize() -> void:
	OS.set_environment("XDG_CONFIG_HOME", ProjectSettings.globalize_path("user://input-smoke-%d" % Time.get_ticks_msec()))
	_run.call_deferred()

func _run() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	_check(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return
	var hearth := main_scene.instantiate()
	root.add_child(hearth)
	await process_frame
	await process_frame
	_check(hearth.get_script() != null, "main script loads without parse errors")

	var input_manager = hearth.get_node_or_null("InputManager")
	var input_settings = hearth.get_node_or_null("InputSettings")
	_check(input_manager != null, "input manager is composed into the main scene")
	_check(input_settings != null, "input settings scene is composed into the main scene")
	if input_manager == null or input_settings == null:
		_finish()
		return

	_check(input_manager.store.profile_ids() == ["ps5", "standard_remote"], "built-in profiles load in a stable order")
	var up_event := InputEventKey.new()
	up_event.pressed = true
	up_event.physical_keycode = KEY_UP
	_check(EventCodec.encode(up_event).get("control", "") == "key:arrow_up", "key events use backend-neutral names")
	_check(input_manager.action_pressed(up_event, Actions.NAVIGATE_UP), "standard remote profile routes Up to Navigate Up")

	input_settings.open_panel()
	await process_frame
	var rows = input_settings.get_node("Panel/Margin/Content/BindingScroll/BindingRows")
	_check(input_settings.visible, "input settings panel opens")
	_check(rows.get_child_count() == Actions.DEFINITIONS.size(), "one remapping row is shown for every semantic action")
	var wrong_device_event := InputEventJoypadButton.new()
	wrong_device_event.device = 0
	wrong_device_event.button_index = JOY_BUTTON_A
	wrong_device_event.pressed = true
	_check(not input_manager.event_matches_device(wrong_device_event, input_settings._selected_device()), "capture filters events from unselected devices")

	var replacement := {"control": "key:space"}
	input_settings._begin_capture(Actions.SELECT)
	input_settings.capture_started_ms = 0
	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.physical_keycode = KEY_SPACE
	input_settings._handle_capture_event(space_event)
	_check(input_manager.store.bindings("standard_remote", Actions.SELECT)[0] == replacement, "the capture UI can replace an action")
	_check(input_manager.store.bindings("standard_remote", Actions.SELECT)[0] == replacement, "the replacement remains backend-neutral")
	_check(input_manager.assign_profile(input_settings._selected_device(), "standard_remote"), "a profile can be assigned to an input source")
	_check(input_manager.save_profiles(), "profiles can be saved to the isolated test config")
	_check(FileAccess.file_exists(input_manager.store.config_path()), "the saved profile file exists")
	_check(input_manager.reload_profiles(), "saved profiles can be reloaded")
	_check(input_manager.store.bindings("standard_remote", Actions.SELECT)[0] == replacement, "saved bindings survive reload")
	_check(input_manager.store.reset_profile("standard_remote"), "a profile can be reset")
	_check(input_manager.store.bindings("standard_remote", Actions.SELECT)[0].get("control", "") == "key:enter", "reset restores the built-in binding")
	_check(not input_manager.store.replace_binding("standard_remote", Actions.HOME, {"control": "key:enter"}), "recovery keys cannot be assigned to conflicting actions")
	_check(not input_manager.store.replace_binding("standard_remote", Actions.BACK, {"control": "key:enter"}), "duplicate controls cannot make Select unreachable")
	var axis_event := InputEventJoypadMotion.new()
	axis_event.axis = JOY_AXIS_LEFT_X
	axis_event.axis_value = 0.75
	_check(not EventCodec.matches(axis_event, {"control": "gamepad_axis:left_x", "direction": 1, "threshold": 0.8}), "axis matching honors the saved threshold")
	_check(EventCodec.matches(axis_event, {"control": "gamepad_axis:left_x", "direction": 1, "threshold": 0.7}), "axis matching accepts values above the saved threshold")
	var malformed := FileAccess.open(input_manager.store.config_path(), FileAccess.WRITE)
	malformed.store_string("{not valid json")
	malformed.close()
	_check(not input_manager.reload_profiles(), "malformed saved profiles fall back safely")
	_check(input_manager.store.bindings("standard_remote", Actions.SELECT)[0].get("control", "") == "key:enter", "malformed config fallback restores defaults")
	var invalid_shape := FileAccess.open(input_manager.store.config_path(), FileAccess.WRITE)
	invalid_shape.store_string(JSON.stringify({
		"schema_version": 2,
		"default_profiles": {"keyboard": "standard_remote", "gamepad": "ps5"},
		"device_assignments": [],
		"profiles": [{"id": "ps5", "bindings": []}],
	}))
	invalid_shape.close()
	_check(not input_manager.reload_profiles(), "structurally invalid saved profiles fall back safely")
	_check(input_manager.store.bindings("standard_remote", Actions.SELECT)[0].get("control", "") == "key:enter", "invalid profile shape restores defaults")
	DirAccess.remove_absolute(input_manager.store.config_path())

	hearth.queue_free()
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		printerr("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("Input smoke test passed.")
		quit(0)
	else:
		printerr("Input smoke test failed: " + "; ".join(failures))
		quit(1)
