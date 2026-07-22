class_name HearthInputManager
extends Node

signal devices_changed
signal profiles_changed

const Actions := preload("res://scripts/input/input_actions.gd")
const EventCodec := preload("res://scripts/input/input_event_codec.gd")
const ProfileStore := preload("res://scripts/input/input_profile_store.gd")

var store := ProfileStore.new()
var axis_armed: Dictionary = {}
var accepted_axis_events: Dictionary = {}

func _ready() -> void:
	store.load_profiles()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func action_pressed(event: InputEvent, action_id: String) -> bool:
	return action_pressed_for_profile(event, action_id, profile_id_for_event(event))

func action_pressed_for_profile(event: InputEvent, action_id: String, profile_id: String) -> bool:
	var recovery_action := _recovery_action_for_event(event)
	if not recovery_action.is_empty():
		return action_id == recovery_action
	if not _is_press_candidate(event):
		return false
	for binding in store.bindings(profile_id, action_id):
		if binding is Dictionary and EventCodec.matches(event, binding):
			if event is InputEventJoypadMotion and not _axis_event_allowed(event):
				return false
			return true
	return false

func actions_for_event(event: InputEvent, profile_id := "") -> Array[String]:
	var result: Array[String] = []
	var selected_profile := profile_id if not profile_id.is_empty() else profile_id_for_event(event)
	for action_id in Actions.ids():
		if action_pressed_for_profile(event, action_id, selected_profile):
			result.append(action_id)
	return result

func connected_devices() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{
		"key": "keyboard",
		"name": "Keyboard / remote",
		"device_id": -1,
		"guid": "",
		"keyboard_like": true,
		"device_kind": "keyboard",
	}]
	for device_id in Input.get_connected_joypads():
		var guid := Input.get_joy_guid(device_id)
		var name := Input.get_joy_name(device_id)
		result.append({
			"key": _joy_device_key(guid, name),
			"name": name if not name.is_empty() else "Game controller %d" % device_id,
			"device_id": device_id,
			"guid": guid,
			"keyboard_like": false,
			"device_kind": "gamepad",
		})
	return result

func suggested_profile_for_device(device: Dictionary) -> String:
	return store.profile_for_device(device)

func event_matches_device(event: InputEvent, device: Dictionary) -> bool:
	if bool(device.get("keyboard_like", false)):
		return event is InputEventKey
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return int(device.get("device_id", -1)) == event.device
	return false

func assign_profile(device: Dictionary, profile_id: String) -> bool:
	var changed := store.assign_profile(device, profile_id)
	if changed:
		profiles_changed.emit()
	return changed

func save_profiles() -> bool:
	var saved := store.save()
	if saved:
		profiles_changed.emit()
	return saved

func reload_profiles() -> bool:
	var loaded := store.reload()
	profiles_changed.emit()
	return loaded

func profile_id_for_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return store.profile_for_device({"key": "keyboard", "name": "Keyboard / remote", "guid": "", "keyboard_like": true, "device_kind": "keyboard"})
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var guid := Input.get_joy_guid(event.device)
		var name := Input.get_joy_name(event.device)
		return store.profile_for_device({"key": _joy_device_key(guid, name), "name": name, "guid": guid, "keyboard_like": false, "device_kind": "gamepad"})
	return str(store.data.get("default_profiles", {}).get("gamepad", "ps5"))

func _is_press_candidate(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) <= 0.35:
			axis_armed[_axis_key(event)] = true
			return false
		return true
	return false

func _joy_device_key(guid: String, name: String) -> String:
	if not guid.is_empty():
		return "joy:" + guid
	return "joy-name:" + name.to_lower().validate_filename()

func _recovery_action_for_event(event: InputEvent) -> String:
	if not event is InputEventKey:
		return ""
	for action_id in Actions.RECOVERY_UI_ACTIONS:
		if event.is_action_pressed(Actions.RECOVERY_UI_ACTIONS[action_id]):
			return str(action_id)
	return ""

func _axis_event_allowed(event: InputEventJoypadMotion) -> bool:
	var key := _axis_key(event)
	var event_id := event.get_instance_id()
	if int(accepted_axis_events.get(key, -1)) == event_id:
		return true
	if bool(axis_armed.get(key, true)):
		axis_armed[key] = false
		accepted_axis_events[key] = event_id
		return true
	return false

func _axis_key(event: InputEventJoypadMotion) -> String:
	return "%d:%d" % [event.device, event.axis]

func _on_joy_connection_changed(_device_id: int, _connected: bool) -> void:
	devices_changed.emit()
