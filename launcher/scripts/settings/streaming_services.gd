class_name HearthStreamingServices
extends Control

signal save_requested(enabled_ids: Array[String])
signal closed

const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const AMBER := Color("f2a93b")

@onready var status_label: Label = $Panel/Margin/Content/Status
@onready var service_rows: VBoxContainer = $Panel/Margin/Content/ServiceScroll/ServiceRows
@onready var enable_all_button: Button = $Panel/Margin/Content/Actions/EnableAll
@onready var clear_button: Button = $Panel/Margin/Content/Actions/Clear
@onready var save_button: Button = $Panel/Margin/Content/Actions/Save
@onready var close_button: Button = $Panel/Margin/Content/Actions/Close

var service_buttons: Array[CheckButton] = []
var service_definitions: Array = []
var original_enabled_ids: Array[String] = []


func _ready() -> void:
	enable_all_button.pressed.connect(_set_all.bind(true))
	clear_button.pressed.connect(_set_all.bind(false))
	save_button.pressed.connect(_save)
	close_button.pressed.connect(_close_without_saving)
	visible = false


func open_panel(definitions: Array, enabled_values: Array[String]) -> void:
	service_definitions = definitions.duplicate(true)
	original_enabled_ids = enabled_values.duplicate()
	_rebuild_rows()
	status_label.text = "Checked services appear in Movies & TV. Plex always stays available."
	visible = true
	if not service_buttons.is_empty():
		service_buttons[0].grab_focus()
	else:
		save_button.grab_focus()


func handle_unhandled_input(event: InputEvent, input_manager) -> bool:
	if not visible:
		return false
	if input_manager.action_pressed(event, "back") or input_manager.action_pressed(event, "home"):
		_close_without_saving()
		return true
	if input_manager.action_pressed(event, "navigate_up"):
		_move_focus(-1)
		return true
	if input_manager.action_pressed(event, "navigate_down"):
		_move_focus(1)
		return true
	if input_manager.action_pressed(event, "navigate_left"):
		_move_focus(-1)
		return true
	if input_manager.action_pressed(event, "navigate_right"):
		_move_focus(1)
		return true
	if input_manager.action_pressed(event, "select"):
		_activate_focused_control()
		return true
	return false


func _rebuild_rows() -> void:
	for child in service_rows.get_children():
		child.queue_free()
	service_buttons.clear()
	for service_value in service_definitions:
		if not service_value is Dictionary:
			continue
		var service: Dictionary = service_value
		var button := CheckButton.new()
		button.text = str(service.get("label", "Streaming service"))
		button.button_pressed = str(service.get("id", "")) in original_enabled_ids
		button.custom_minimum_size = Vector2(0, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", PAPER)
		button.add_theme_color_override("font_hover_color", AMBER)
		button.add_theme_color_override("font_focus_color", AMBER)
		button.set_meta("service_id", str(service.get("id", "")))
		button.toggled.connect(_on_service_toggled.bind(str(service.get("label", "Service"))))
		service_rows.add_child(button)
		service_buttons.append(button)


func _on_service_toggled(enabled: bool, label: String) -> void:
	status_label.text = "%s will be %s after you save." % [label, "shown" if enabled else "hidden"]


func _set_all(enabled: bool) -> void:
	for button in service_buttons:
		button.button_pressed = enabled
	status_label.text = "All streaming services will be %s after you save." % ("shown" if enabled else "hidden")


func _save() -> void:
	var enabled: Array[String] = []
	for button in service_buttons:
		if button.button_pressed:
			enabled.append(str(button.get_meta("service_id", "")))
	save_requested.emit(enabled)
	visible = false
	closed.emit()


func _close_without_saving() -> void:
	visible = false
	closed.emit()


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


func _activate_focused_control() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is CheckButton:
		owner.button_pressed = not owner.button_pressed
	elif owner is BaseButton:
		owner.pressed.emit()
