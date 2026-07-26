class_name HearthLibrarySettings
extends Control

signal save_requested(settings: Dictionary)
signal closed

const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const AMBER := Color("f2a93b")
const FOLDER_ART_VALUES: Array[String] = ["disabled", "named", "named_or_first"]

@onready var folder_art: OptionButton = $Panel/Margin/Content/General/FolderArt
@onready var folder_wallpapers: CheckButton = $Panel/Margin/Content/General/FolderWallpapers
@onready var preserve_folders: CheckButton = $Panel/Margin/Content/General/PreserveFolders
@onready var fullscreen: CheckButton = $Panel/Margin/Content/General/Fullscreen
@onready var status_label: Label = $Panel/Margin/Content/Status
@onready var launcher_rows: VBoxContainer = $Panel/Margin/Content/LauncherScroll/LauncherRows
@onready var reset_button: Button = $Panel/Margin/Content/Actions/Reset
@onready var save_button: Button = $Panel/Margin/Content/Actions/Save
@onready var close_button: Button = $Panel/Margin/Content/Actions/Close

var launcher_selectors: Dictionary = {}
var launcher_systems: Array = []


func _ready() -> void:
	folder_art.add_item("Off")
	folder_art.add_item("Named images: icon, folder, cover, or poster")
	folder_art.add_item("Named images, then the first image in the folder")
	folder_art.item_selected.connect(_on_setting_changed.unbind(1))
	folder_wallpapers.toggled.connect(_on_setting_changed.unbind(1))
	preserve_folders.toggled.connect(_on_setting_changed.unbind(1))
	fullscreen.toggled.connect(_on_setting_changed.unbind(1))
	reset_button.pressed.connect(_reset)
	save_button.pressed.connect(_save)
	close_button.pressed.connect(_close_without_saving)
	visible = false


func open_panel(settings: Dictionary, system_options: Array) -> void:
	launcher_systems = system_options.duplicate(true)
	folder_art.select(maxi(0, FOLDER_ART_VALUES.find(str(settings.get("folder_art_mode", "named_or_first")))))
	folder_wallpapers.button_pressed = bool(settings.get("folder_wallpapers", true))
	preserve_folders.button_pressed = bool(settings.get("preserve_folders", true))
	fullscreen.button_pressed = bool(settings.get("retroarch_fullscreen", true))
	_rebuild_launcher_rows(settings.get("core_overrides", {}))
	status_label.text = "Defaults work automatically. Change only what you want to customize."
	visible = true
	folder_art.grab_focus()


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
		_adjust_focused_option(-1)
		return true
	if input_manager.action_pressed(event, "navigate_right"):
		_adjust_focused_option(1)
		return true
	if input_manager.action_pressed(event, "select"):
		_activate_focused_control()
		return true
	return false


func _rebuild_launcher_rows(overrides: Dictionary) -> void:
	for child in launcher_rows.get_children():
		child.queue_free()
	launcher_selectors.clear()
	for system_value in launcher_systems:
		if not system_value is Dictionary:
			continue
		var system: Dictionary = system_value
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		launcher_rows.add_child(row)
		var label := Label.new()
		label.text = str(system.get("label", "System"))
		label.custom_minimum_size = Vector2(390, 54)
		label.add_theme_font_size_override("font_size", 19)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var selector := OptionButton.new()
		selector.custom_minimum_size = Vector2(620, 54)
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.add_theme_font_size_override("font_size", 17)
		selector.add_item("Automatic — %s" % str(system.get("default_label", system.get("default_core", ""))))
		selector.set_item_metadata(0, "")
		var selected_core := str(overrides.get(str(system.get("id", "")), ""))
		var selected_index := 0
		for option_value in system.get("options", []):
			if not option_value is Dictionary:
				continue
			var option: Dictionary = option_value
			var suffix := "" if bool(option.get("installed", false)) else " — not installed"
			selector.add_item(str(option.get("label", option.get("core", ""))) + suffix)
			var option_index := selector.item_count - 1
			selector.set_item_metadata(option_index, str(option.get("core", "")))
			selector.set_item_disabled(option_index, not bool(option.get("installed", false)))
			if str(option.get("core", "")) == selected_core:
				selected_index = option_index
		selector.select(selected_index)
		selector.item_selected.connect(_on_setting_changed.unbind(1))
		row.add_child(selector)
		launcher_selectors[str(system.get("id", ""))] = selector


func _on_setting_changed() -> void:
	status_label.text = "Select Save to apply these library settings."


func _reset() -> void:
	folder_art.select(2)
	folder_wallpapers.button_pressed = true
	preserve_folders.button_pressed = true
	fullscreen.button_pressed = true
	for selector in launcher_selectors.values():
		selector.select(0)
	status_label.text = "Beginner-friendly defaults restored. Select Save to apply them."


func _save() -> void:
	var overrides: Dictionary = {}
	for system_id in launcher_selectors:
		var selector: OptionButton = launcher_selectors[system_id]
		var core_file := str(selector.get_item_metadata(selector.selected))
		if not core_file.is_empty():
			overrides[system_id] = core_file
	save_requested.emit({
		"schema_version": 1,
		"folder_art_mode": FOLDER_ART_VALUES[folder_art.selected],
		"folder_wallpapers": folder_wallpapers.button_pressed,
		"preserve_folders": preserve_folders.button_pressed,
		"retroarch_fullscreen": fullscreen.button_pressed,
		"core_overrides": overrides,
	})
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


func _adjust_focused_option(direction: int) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is OptionButton and owner.item_count > 0:
		var next_index: int = owner.selected
		for _attempt in range(owner.item_count):
			next_index = posmod(next_index + direction, owner.item_count)
			if not owner.is_item_disabled(next_index):
				owner.select(next_index)
				_on_setting_changed()
				return
	elif owner is CheckButton:
		owner.button_pressed = not owner.button_pressed
	else:
		_move_focus(direction)


func _activate_focused_control() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is OptionButton:
		_adjust_focused_option(1)
	elif owner is CheckButton:
		owner.button_pressed = not owner.button_pressed
	elif owner is BaseButton:
		owner.pressed.emit()
