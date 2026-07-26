class_name HearthSystemHealth
extends Control

signal closed

const HealthReport := preload("res://scripts/diagnostics/health_report.gd")
const HELPER := "/opt/hearth/launchers/system-health-refresh.sh"
const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const AMBER := Color("f2a93b")
const INK := Color("101827")

var _built := false
var _profile_label := ""
var _helper_pid := -1
var _selected_action := 0
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _status: Label
var _refresh_button: Button
var _close_button: Button
var debug_check_count := 0
var debug_last_error := ""


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func open_panel(profile_label: String) -> void:
	_profile_label = profile_label
	if not _built:
		_build_ui()
	visible = true
	_selected_action = 0
	_load_report()
	_refresh_focus()
	if FileAccess.file_exists(HELPER):
		_helper_pid = OS.create_process(HELPER, [])
		if _helper_pid > 0:
			_status.text = "Refreshing bounded appliance diagnostics…"


func handle_unhandled_input(event: InputEvent, input_manager) -> bool:
	if not visible:
		return false
	if input_manager.action_pressed(event, "back") or input_manager.action_pressed(event, "home"):
		_close()
	elif input_manager.action_pressed(event, "navigate_left"):
		_selected_action = 0
		_refresh_focus()
	elif input_manager.action_pressed(event, "navigate_right"):
		_selected_action = 1
		_refresh_focus()
	elif input_manager.action_pressed(event, "navigate_up"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - 92)
	elif input_manager.action_pressed(event, "navigate_down"):
		_scroll.scroll_vertical += 92
	elif input_manager.action_pressed(event, "page_left"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - 520)
	elif input_manager.action_pressed(event, "page_right"):
		_scroll.scroll_vertical += 520
	elif input_manager.action_pressed(event, "select"):
		if _selected_action == 0:
			_refresh()
		else:
			_close()
	else:
		return false
	return true


func _process(_delta: float) -> void:
	if _helper_pid > 0 and not OS.is_process_running(_helper_pid):
		_helper_pid = -1
		_load_report()


func _build_ui() -> void:
	_built = true
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(INK, 0.97)
	add_child(veil)
	var title := _label("SYSTEM HEALTH", 42, PAPER)
	title.position = Vector2(84, 56)
	title.size = Vector2(1750, 60)
	add_child(title)
	_status = _label("Read-only, privacy-bounded appliance diagnostics", 18, MUTED)
	_status.position = Vector2(86, 120)
	_status.size = Vector2(1740, 34)
	add_child(_status)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(82, 174)
	_scroll.size = Vector2(1756, 742)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(1710, 0)
	_rows.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows)
	_refresh_button = _action_button("Refresh", 0)
	_refresh_button.position = Vector2(650, 944)
	add_child(_refresh_button)
	_close_button = _action_button("Close", 1)
	_close_button.position = Vector2(990, 944)
	add_child(_close_button)
	var footer := _label("↑↓ Scroll    L3/R3 Page    ←→ Action    SELECT    BACK / HOME Close", 18, MUTED)
	footer.position = Vector2(84, 1024)
	footer.size = Vector2(1750, 30)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)


func _load_report() -> void:
	var document := HealthReport.with_runtime_context(HealthReport.load_report(), _profile_label)
	debug_last_error = str(document.get("error", ""))
	var checks: Array = document.get("checks", [])
	debug_check_count = checks.size()
	for child in _rows.get_children():
		child.queue_free()
	if not debug_last_error.is_empty():
		_rows.add_child(_message_row(debug_last_error))
	else:
		for check_value in checks:
			if check_value is Dictionary:
				_rows.add_child(_check_row(check_value))
	_status.text = (
		"%d bounded checks • report contains no credentials or personal inventory" % debug_check_count
		if debug_last_error.is_empty()
		else debug_last_error
	)


func _refresh() -> void:
	if _helper_pid > 0:
		return
	if not FileAccess.file_exists(HELPER):
		_load_report()
		_status.text = "Refresh helper is available after Fedora installation."
		return
	_helper_pid = OS.create_process(HELPER, [])
	_status.text = "Refreshing bounded appliance diagnostics…"


func _check_row(check: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(1690, 92)
	var status := str(check.get("status", "WARNING"))
	var accent := Color("5b8f78") if status == "PASS" else (Color("b85b4f") if status == "FAIL" else AMBER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("162235")
	box.border_color = accent
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	row.add_theme_stylebox_override("panel", box)
	var text := _label(
		"%s  •  %s\n%s%s" % [
			status,
			str(check.get("label", "")),
			str(check.get("explanation", "")),
			("\nFix: " + str(check.get("remediation", ""))) if not str(check.get("remediation", "")).is_empty() and status != "PASS" else "",
		],
		16,
		PAPER
	)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(1640, 84)
	row.add_child(text)
	return row


func _message_row(message: String) -> Control:
	var label := _label(message + "\nSelect Refresh after installing Hearth.", 20, PAPER)
	label.custom_minimum_size = Vector2(1600, 110)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _action_button(caption: String, index: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.size = Vector2(280, 60)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func() -> void:
		_selected_action = index
		if index == 0:
			_refresh()
		else:
			_close()
	)
	return button


func _refresh_focus() -> void:
	_refresh_button.modulate = Color.WHITE if _selected_action == 0 else Color(0.68, 0.72, 0.78)
	_close_button.modulate = Color.WHITE if _selected_action == 1 else Color(0.68, 0.72, 0.78)


func _close() -> void:
	visible = false
	closed.emit()


func _label(value: String, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label
