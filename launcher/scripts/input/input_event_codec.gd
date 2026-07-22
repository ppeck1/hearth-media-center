class_name HearthInputEventCodec
extends RefCounted

const BUTTON_NAMES := {
	JOY_BUTTON_A: "south",
	JOY_BUTTON_B: "east",
	JOY_BUTTON_X: "west",
	JOY_BUTTON_Y: "north",
	JOY_BUTTON_BACK: "back",
	JOY_BUTTON_GUIDE: "guide",
	JOY_BUTTON_START: "start",
	JOY_BUTTON_LEFT_STICK: "left_stick",
	JOY_BUTTON_RIGHT_STICK: "right_stick",
	JOY_BUTTON_LEFT_SHOULDER: "left_shoulder",
	JOY_BUTTON_RIGHT_SHOULDER: "right_shoulder",
	JOY_BUTTON_DPAD_UP: "dpad_up",
	JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left",
	JOY_BUTTON_DPAD_RIGHT: "dpad_right",
	JOY_BUTTON_MISC1: "misc1",
	JOY_BUTTON_PADDLE1: "paddle1",
	JOY_BUTTON_PADDLE2: "paddle2",
	JOY_BUTTON_PADDLE3: "paddle3",
	JOY_BUTTON_PADDLE4: "paddle4",
	JOY_BUTTON_TOUCHPAD: "touchpad",
}

const AXIS_NAMES := {
	JOY_AXIS_LEFT_X: "left_x",
	JOY_AXIS_LEFT_Y: "left_y",
	JOY_AXIS_RIGHT_X: "right_x",
	JOY_AXIS_RIGHT_Y: "right_y",
	JOY_AXIS_TRIGGER_LEFT: "trigger_left",
	JOY_AXIS_TRIGGER_RIGHT: "trigger_right",
}

const KEY_ALIASES := {
	"up": "arrow_up",
	"down": "arrow_down",
	"left": "arrow_left",
	"right": "arrow_right",
	"pageup": "page_up",
	"pagedown": "page_down",
	"media_play": "media_play_pause",
	"mediaplay": "media_play_pause",
	"media_play_pause": "media_play_pause",
	"mediaplaypause": "media_play_pause",
	"volumeup": "volume_up",
	"volumedown": "volume_down",
	"volumemute": "volume_mute",
	"back": "browser_back",
	"browserback": "browser_back",
	"forward": "browser_forward",
	"browserforward": "browser_forward",
	"mediastop": "media_stop",
	"media_stop": "media_stop",
	"medianext": "media_next",
	"media_next": "media_next",
	"mediaprevious": "media_previous",
	"media_previous": "media_previous",
	"mediarecord": "media_record",
	"channelup": "channel_up",
	"channeldown": "channel_down",
}

const CANONICAL_KEYS := [
	"arrow_up", "arrow_down", "arrow_left", "arrow_right",
	"enter", "escape", "home", "menu", "space", "tab", "backspace",
	"page_up", "page_down", "media_play_pause", "volume_up", "volume_down", "volume_mute",
	"browser_back", "browser_forward", "media_stop", "media_next", "media_previous", "media_record", "channel_up", "channel_down",
]

static func encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return {}
		var code: Key = event.physical_keycode
		if code == 0:
			code = event.keycode
		var display_name := OS.get_keycode_string(code)
		var key_name := _canonical_key_name(display_name)
		if key_name.is_empty():
			return {}
		return {"control": "key:" + key_name}
	if event is InputEventJoypadButton:
		if not event.pressed or not BUTTON_NAMES.has(event.button_index):
			return {}
		return {"control": "gamepad_button:" + str(BUTTON_NAMES[event.button_index])}
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.72 or not AXIS_NAMES.has(event.axis):
			return {}
		return {
			"control": "gamepad_axis:" + str(AXIS_NAMES[event.axis]),
			"direction": -1 if event.axis_value < 0.0 else 1,
			"threshold": 0.72,
		}
	return {}

static func matches(event: InputEvent, binding: Dictionary) -> bool:
	var control := str(binding.get("control", ""))
	if control.begins_with("gamepad_axis:"):
		if not event is InputEventJoypadMotion or not AXIS_NAMES.has(event.axis):
			return false
		if control != "gamepad_axis:" + str(AXIS_NAMES[event.axis]):
			return false
		var threshold := float(binding.get("threshold", 0.72))
		var direction := -1 if event.axis_value < 0.0 else 1
		return absf(event.axis_value) >= threshold and direction == int(binding.get("direction", 0))
	var encoded := encode(event)
	if encoded.is_empty() or encoded.get("control", "") != binding.get("control", ""):
		return false
	return true

static func describe(binding: Dictionary) -> String:
	var control := str(binding.get("control", ""))
	if control.begins_with("key:"):
		return control.trim_prefix("key:").replace("_", " ").capitalize()
	if control.begins_with("gamepad_button:"):
		return control.trim_prefix("gamepad_button:").replace("_", " ").capitalize()
	if control.begins_with("gamepad_axis:"):
		var direction := "−" if int(binding.get("direction", 1)) < 0 else "+"
		return "%s %s" % [control.trim_prefix("gamepad_axis:").replace("_", " ").capitalize(), direction]
	return "Not assigned"

static func is_valid_binding(binding: Dictionary) -> bool:
	var control := str(binding.get("control", ""))
	if control.begins_with("key:"):
		return _is_canonical_key(control.trim_prefix("key:"))
	if control.begins_with("gamepad_button:"):
		return BUTTON_NAMES.values().has(control.trim_prefix("gamepad_button:"))
	if control.begins_with("gamepad_axis:"):
		var threshold := float(binding.get("threshold", 0.0))
		return AXIS_NAMES.values().has(control.trim_prefix("gamepad_axis:")) and int(binding.get("direction", 0)) in [-1, 1] and threshold > 0.0 and threshold <= 1.0
	return false

static func _normalize_key_name(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("+", "_plus_")

static func _canonical_key_name(value: String) -> String:
	var normalized := _normalize_key_name(value)
	var canonical := str(KEY_ALIASES.get(normalized, normalized))
	return canonical if _is_canonical_key(canonical) else ""

static func _is_canonical_key(value: String) -> bool:
	if value in CANONICAL_KEYS:
		return true
	if value.length() != 1:
		return false
	var codepoint := value.unicode_at(0)
	return (codepoint >= 48 and codepoint <= 57) or (codepoint >= 97 and codepoint <= 122)
