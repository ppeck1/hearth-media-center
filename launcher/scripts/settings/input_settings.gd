class_name HearthInputSettings
extends Control

signal closed

const Actions := preload("res://scripts/input/input_actions.gd")
const EventCodec := preload("res://scripts/input/input_event_codec.gd")

@onready var device_selector: OptionButton = $Panel/Margin/Content/Selectors/Device
@onready var profile_selector: OptionButton = $Panel/Margin/Content/Selectors/Profile
@onready var status_label: Label = $Panel/Margin/Content/Status
@onready var binding_rows: VBoxContainer = $Panel/Margin/Content/BindingScroll/BindingRows
@onready var test_button: Button = $Panel/Margin/Content/Actions/Test
@onready var reset_button: Button = $Panel/Margin/Content/Actions/Reset
@onready var save_button: Button = $Panel/Margin/Content/Actions/Save
@onready var close_button: Button = $Panel/Margin/Content/Actions/Close
@onready var capture_overlay: ColorRect = $CaptureOverlay
@onready var capture_text: Label = $CaptureOverlay/CapturePanel/CaptureText

var input_manager
var devices: Array[Dictionary] = []
var profile_ids: Array[String] = []
var capture_action := ""
var capture_started_ms := 0
var capture_axis_armed := false
var testing := false
var dirty := false

func _ready() -> void:
	input_manager = get_parent().get_node("InputManager")
	device_selector.item_selected.connect(_on_device_selected)
	profile_selector.item_selected.connect(_on_profile_selected)
	test_button.pressed.connect(_start_test)
	reset_button.pressed.connect(_reset_profile)
	save_button.pressed.connect(_save)
	close_button.pressed.connect(_close_and_discard)
	input_manager.devices_changed.connect(_refresh_devices)
	visible = false

func open_panel() -> void:
	dirty = false
	testing = false
	capture_action = ""
	capture_overlay.visible = false
	visible = true
	_refresh_profiles()
	_refresh_devices()
	status_label.text = input_manager.store.last_error if not input_manager.store.last_error.is_empty() else "Select Remap, then press the desired button."
	device_selector.grab_focus()

func handle_unhandled_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if not capture_action.is_empty() or testing:
		return true
	if input_manager.action_pressed(event, Actions.BACK) or input_manager.action_pressed(event, Actions.HOME):
		_close_and_discard()
		return true
	if input_manager.action_pressed(event, Actions.NAVIGATE_UP):
		_move_focus(-1)
		return true
	if input_manager.action_pressed(event, Actions.NAVIGATE_DOWN):
		_move_focus(1)
		return true
	if input_manager.action_pressed(event, Actions.NAVIGATE_LEFT):
		_adjust_focused_option(-1)
		return true
	if input_manager.action_pressed(event, Actions.NAVIGATE_RIGHT):
		_adjust_focused_option(1)
		return true
	if input_manager.action_pressed(event, Actions.SELECT):
		_activate_focused_control()
		return true
	return false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not capture_action.is_empty():
		_handle_capture_event(event)
	elif testing:
		_handle_test_event(event)

func _refresh_devices() -> void:
	if not visible:
		return
	var previous_key := _selected_device_key()
	devices = input_manager.connected_devices()
	device_selector.clear()
	var selected_index := 0
	for index in range(devices.size()):
		var device := devices[index]
		device_selector.add_item(str(device.get("name", "Input device")))
		device_selector.set_item_metadata(index, str(device.get("key", "keyboard")))
		if str(device.get("key", "")) == previous_key:
			selected_index = index
	device_selector.select(selected_index)
	_sync_profile_to_device()

func _refresh_profiles() -> void:
	profile_ids = input_manager.store.profile_ids()
	profile_selector.clear()
	for profile_id in profile_ids:
		profile_selector.add_item(input_manager.store.profile_label(profile_id))
		profile_selector.set_item_metadata(profile_selector.item_count - 1, profile_id)

func _sync_profile_to_device() -> void:
	if devices.is_empty() or profile_ids.is_empty():
		return
	var device := devices[device_selector.selected]
	var suggested: String = input_manager.suggested_profile_for_device(device)
	var profile_index := profile_ids.find(suggested)
	profile_selector.select(maxi(0, profile_index))
	_rebuild_binding_rows()

func _rebuild_binding_rows() -> void:
	for child in binding_rows.get_children():
		child.queue_free()
	var profile_id := _selected_profile_id()
	for definition in Actions.DEFINITIONS:
		var action_id: String = definition["id"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		binding_rows.add_child(row)
		var action_label := Label.new()
		action_label.text = str(definition["label"])
		action_label.custom_minimum_size = Vector2(285, 46)
		action_label.add_theme_font_size_override("font_size", 19)
		row.add_child(action_label)
		var binding_label := Label.new()
		binding_label.text = _binding_summary(input_manager.store.bindings(profile_id, action_id))
		binding_label.custom_minimum_size = Vector2(520, 46)
		binding_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding_label.add_theme_font_size_override("font_size", 18)
		binding_label.add_theme_color_override("font_color", Color("aeb9c8"))
		row.add_child(binding_label)
		var remap := Button.new()
		remap.text = "Remap"
		remap.custom_minimum_size = Vector2(150, 46)
		remap.add_theme_font_size_override("font_size", 17)
		remap.pressed.connect(_begin_capture.bind(action_id))
		row.add_child(remap)

func _begin_capture(action_id: String) -> void:
	testing = false
	capture_action = action_id
	capture_started_ms = Time.get_ticks_msec()
	capture_axis_armed = false
	capture_text.text = "Press a button for %s\n\nEsc cancels" % Actions.label_for(action_id)
	capture_overlay.visible = true

func _handle_capture_event(event: InputEvent) -> void:
	if Time.get_ticks_msec() - capture_started_ms < 250:
		return
	var selected_device := _selected_device()
	var escape_pressed: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	if escape_pressed and (capture_action != Actions.BACK or not input_manager.event_matches_device(event, selected_device)):
		_cancel_capture("Remapping cancelled.")
		return
	if not input_manager.event_matches_device(event, selected_device):
		capture_text.text = "Waiting for input from %s\n\nEsc cancels" % str(selected_device.get("name", "the selected device"))
		return
	if event is InputEventJoypadMotion and not capture_axis_armed:
		if absf(event.axis_value) <= 0.35:
			capture_axis_armed = true
		return
	var selected_profile := _selected_profile_id()
	var existing_actions: Array[String] = input_manager.actions_for_event(event, selected_profile)
	var cancel_with_mapped_action: bool = (Actions.BACK in existing_actions and capture_action != Actions.BACK) or (Actions.HOME in existing_actions and capture_action != Actions.HOME)
	if cancel_with_mapped_action:
		_cancel_capture("Remapping cancelled.")
		return
	var binding := EventCodec.encode(event)
	if binding.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			capture_text.text = "That key does not have a portable mapping yet.\nPress another button for %s\n\nEsc cancels" % Actions.label_for(capture_action)
		return
	var action_id := capture_action
	var conflict_action: String = input_manager.store.binding_conflict(selected_profile, action_id, binding)
	capture_action = ""
	capture_overlay.visible = false
	if not conflict_action.is_empty():
		status_label.text = "%s is already assigned to %s. Choose a different control." % [EventCodec.describe(binding), Actions.label_for(conflict_action)]
	elif input_manager.store.replace_binding(selected_profile, action_id, binding):
		dirty = true
		status_label.text = "%s is now %s. Select Save to keep it." % [Actions.label_for(action_id), EventCodec.describe(binding)]
		_rebuild_binding_rows()
	else:
		status_label.text = "Arrow keys, Enter, and Escape are reserved for their recovery actions. Choose another control."
	get_viewport().set_input_as_handled()

func _start_test() -> void:
	testing = true
	status_label.text = "Testing: press a mapped control. Press Esc to finish."

func _handle_test_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		testing = false
		status_label.text = "Control test finished."
		get_viewport().set_input_as_handled()
		return
	if not input_manager.event_matches_device(event, _selected_device()):
		return
	var is_candidate: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.01)
	if not is_candidate:
		return
	var matched: Array[String] = input_manager.actions_for_event(event, _selected_profile_id())
	if Actions.BACK in matched or Actions.HOME in matched:
		testing = false
		var exit_action := Actions.BACK if Actions.BACK in matched else Actions.HOME
		status_label.text = "%s detected. Control test finished." % Actions.label_for(exit_action)
	else:
		status_label.text = "Testing: %s" % (Actions.label_for(matched[0]) if not matched.is_empty() else "input received, but it is not mapped in this profile")
	get_viewport().set_input_as_handled()

func _reset_profile() -> void:
	if input_manager.store.reset_profile(_selected_profile_id()):
		dirty = true
		status_label.text = "Built-in defaults restored for this profile. Select Save to keep them."
		_rebuild_binding_rows()

func _save() -> void:
	input_manager.assign_profile(_selected_device(), _selected_profile_id())
	if input_manager.save_profiles():
		dirty = false
		status_label.text = "Input profile saved to %s" % input_manager.store.config_path()
	else:
		status_label.text = input_manager.store.last_error

func _close_and_discard() -> void:
	if dirty:
		input_manager.reload_profiles()
	visible = false
	capture_overlay.visible = false
	testing = false
	capture_action = ""
	closed.emit()

func _on_device_selected(_index: int) -> void:
	_sync_profile_to_device()

func _on_profile_selected(_index: int) -> void:
	dirty = true
	_rebuild_binding_rows()
	status_label.text = "Select Save to assign this profile to the chosen device."

func _selected_device_key() -> String:
	if device_selector.item_count == 0 or device_selector.selected < 0:
		return "keyboard"
	return str(device_selector.get_item_metadata(device_selector.selected))

func _selected_device() -> Dictionary:
	if devices.is_empty() or device_selector.selected < 0 or device_selector.selected >= devices.size():
		return {"key": "keyboard", "name": "Keyboard / remote", "guid": "", "keyboard_like": true, "device_kind": "keyboard"}
	return devices[device_selector.selected]

func _cancel_capture(message: String) -> void:
	capture_action = ""
	capture_overlay.visible = false
	status_label.text = message
	get_viewport().set_input_as_handled()

func _selected_profile_id() -> String:
	if profile_selector.item_count == 0 or profile_selector.selected < 0:
		return "ps5"
	return str(profile_selector.get_item_metadata(profile_selector.selected))

func _binding_summary(bindings: Array) -> String:
	if bindings.is_empty():
		return "Not assigned"
	var descriptions: Array[String] = []
	for binding in bindings:
		if binding is Dictionary:
			descriptions.append(EventCodec.describe(binding))
	return " / ".join(descriptions)

func _focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	for candidate in find_children("*", "Control", true, false):
		if candidate is Control and candidate.visible and candidate.focus_mode != Control.FOCUS_NONE:
			result.append(candidate)
	return result

func _move_focus(direction: int) -> void:
	var controls := _focusable_controls()
	if controls.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var index := controls.find(owner)
	controls[posmod(index + direction, controls.size())].grab_focus()

func _adjust_focused_option(direction: int) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is OptionButton and owner.item_count > 0:
		owner.select(posmod(owner.selected + direction, owner.item_count))
		owner.item_selected.emit(owner.selected)
	else:
		_move_focus(direction)

func _activate_focused_control() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is OptionButton:
		owner.select(posmod(owner.selected + 1, owner.item_count))
		owner.item_selected.emit(owner.selected)
	elif owner is BaseButton:
		owner.pressed.emit()
