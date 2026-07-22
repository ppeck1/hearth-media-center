extends Control

const INK := Color("101827")
const SLATE := Color("31445f")
const AMBER := Color("f2a93b")
const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const MENU_PATH := "res://config/menu.json"
const PROFILE_PATH := "res://config/library-profiles.json"
const LIBRARY_ROOT := "/srv/library/games/roms"

var stage: Control
var heading: Label
var breadcrumb: Label
var detail: Label
var footer: Label
var modal: PanelContainer
var modal_label: Label
var items: Array = []
var buttons: Array[Button] = []
var stack: Array = []
var profiles: Dictionary = {}
var selected := 0
var child_pid := -1
var last_button: Button

func _ready() -> void:
    _build_ui()
    _load_profiles()
    _load_home()

func _build_ui() -> void:
    var background := TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.texture = load("res://assets/backgrounds/arcade-living-room-v1.png")
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(INK, 0.60)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(veil)
    breadcrumb = _label(Vector2(92, 52), Vector2(1700, 32), 21, AMBER)
    add_child(breadcrumb)
    heading = _label(Vector2(88, 84), Vector2(1740, 80), 58, PAPER)
    add_child(heading)
    heading.add_theme_constant_override("outline_size", 8)
    heading.add_theme_color_override("font_outline_color", Color(INK, 0.85))
    detail = _label(Vector2(92, 176), Vector2(1736, 44), 23, MUTED)
    add_child(detail)
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stage = Control.new()
    stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(stage)
    footer = _label(Vector2(92, 1000), Vector2(1736, 34), 20, PAPER)
    add_child(footer)
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_constant_override("outline_size", 5)
    footer.add_theme_color_override("font_outline_color", Color(INK, 0.9))
    modal = PanelContainer.new()
    modal.visible = false
    modal.position = Vector2(500, 350)
    modal.size = Vector2(920, 380)
    modal.add_theme_stylebox_override("panel", _box(INK, AMBER, 4, 20))
    add_child(modal)
    modal_label = _label(Vector2.ZERO, Vector2.ZERO, 28, PAPER)
    modal_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    modal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    modal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modal.add_child(modal_label)

func _label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = position_value
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _load_profiles() -> void:
    var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY and parsed.get("schema_version", 0) == 1 and typeof(parsed.get("extensions")) == TYPE_DICTIONARY:
        profiles = parsed["extensions"]

func _load_home() -> void:
    var file := FileAccess.open(MENU_PATH, FileAccess.READ)
    if file == null:
        _show_error("Hearth menu configuration could not be opened.")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema_version", 0) != 2:
        _show_error("Hearth menu configuration is invalid.")
        return
    _show_menu(parsed["items"], str(parsed.get("title", "Welcome home")), "HEARTH  •  LIVING ROOM")

func _show_menu(next_items: Array, title: String, path: String, focus_index := 0) -> void:
    for child in stage.get_children():
        child.queue_free()
    items = next_items
    buttons.clear()
    selected = 0
    heading.text = title
    breadcrumb.text = path
    for item in items:
        if typeof(item) == TYPE_DICTIONARY:
            _add_card(item)
    await get_tree().process_frame
    _select(clampi(focus_index, 0, maxi(0, buttons.size() - 1)), true)

func _add_card(item: Dictionary) -> void:
    var card := Button.new()
    card.set_meta("index", buttons.size())
    card.set_meta("item", item)
    card.focus_mode = Control.FOCUS_ALL
    card.disabled = not bool(item.get("enabled", true))
    card.add_theme_stylebox_override("normal", _box(Color(SLATE, 0.92), Color(SLATE, 0.75), 2, 22))
    card.add_theme_stylebox_override("focus", _box(Color(SLATE, 1.0), AMBER, 6, 22))
    card.add_theme_stylebox_override("hover", _box(Color(SLATE, 1.0), AMBER, 5, 22))
    card.pressed.connect(_activate.bind(item, card))
    card.focus_entered.connect(_focus_card.bind(card))
    stage.add_child(card)
    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    box.add_theme_constant_override("separation", 10)
    card.add_child(box)
    var mark := Label.new()
    mark.text = str(item.get("mark", "•"))
    mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
    mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mark.add_theme_font_size_override("font_size", 86)
    mark.add_theme_color_override("font_color", PAPER)
    box.add_child(mark)
    var name := Label.new()
    name.text = str(item.get("label", "Item"))
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name.add_theme_font_size_override("font_size", 30)
    name.add_theme_color_override("font_color", PAPER)
    box.add_child(name)
    buttons.append(card)

func _focus_card(card: Button) -> void:
    _select(int(card.get_meta("index", 0)))

func _select(index: int, immediate := false) -> void:
    if buttons.is_empty():
        return
    selected = clampi(index, 0, buttons.size() - 1)
    var focus_item: Dictionary = buttons[selected].get_meta("item", {})
    detail.text = str(focus_item.get("subtitle", ""))
    footer.text = "D-pad / left stick: browse     ✕: select     ○: back     %s" % str(focus_item.get("hint", ""))
    for card in buttons:
        var offset: int = int(card.get_meta("index", 0)) - selected
        var distance: int = absi(offset)
        card.visible = distance <= 3
        if not card.visible:
            continue
        var selected_card: bool = offset == 0
        var size_value: Vector2 = Vector2(560, 390) if selected_card else Vector2(330 - mini(distance - 1, 2) * 34, 246 - mini(distance - 1, 2) * 28)
        var position_value := Vector2(960 + offset * 312 - size_value.x * 0.5, 560 - size_value.y * 0.5)
        card.z_index = 10 - distance
        if immediate:
            card.position = position_value
            card.size = size_value
            card.modulate.a = 1.0 if selected_card else 0.64
        else:
            var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            tween.tween_property(card, "position", position_value, 0.16)
            tween.tween_property(card, "size", size_value, 0.16)
            tween.tween_property(card, "modulate:a", 1.0 if selected_card else 0.64, 0.14)
    buttons[selected].grab_focus()

func _activate(item: Dictionary, card: Button) -> void:
    last_button = card
    var kind := str(item.get("type", ""))
    if kind == "library":
        var systems := _library_systems()
        if systems.is_empty():
            _show_error("No ROM folders found. Add a system folder under /srv/library/games/roms, then reopen Games.")
            return
        stack.append({"items":items,"title":heading.text,"path":breadcrumb.text,"index":selected})
        _show_menu(systems, "My Library", breadcrumb.text + "  ›  MY LIBRARY")
        return
    if kind == "submenu":
        var children: Array = item.get("children", [])
        stack.append({"items":items,"title":heading.text,"path":breadcrumb.text,"index":selected})
        _show_menu(children, str(item.get("label", "Menu")), breadcrumb.text + "  ›  " + str(item.get("label", "Menu")))
        return
    if kind == "unavailable":
        _show_error(str(item.get("error", "Install and map a compatible RetroArch core first.")))
        return
    if kind != "command" or child_pid > 0:
        return
    var executable := str(item.get("executable", ""))
    if not executable.begins_with("/opt/hearth/launchers/") or not FileAccess.file_exists(executable):
        _show_error("The launcher is missing. Deploy this source version before starting applications.")
        return
    child_pid = OS.create_process(executable, item.get("args", []))
    if child_pid <= 0:
        _show_error("The selected application could not start.")
        return
    footer.text = "%s is running…" % str(item.get("label", "Application"))

func _library_systems() -> Array:
    var systems: Array = []
    if not DirAccess.dir_exists_absolute(LIBRARY_ROOT):
        return systems
    var folders: PackedStringArray = DirAccess.get_directories_at(LIBRARY_ROOT)
    folders.sort()
    for folder in folders:
        if folder.begins_with("."):
            continue
        var games: Array = []
        _scan_roms(LIBRARY_ROOT.path_join(folder), games)
        if not games.is_empty():
            systems.append({"id":"system-" + folder,"label":folder.replace("_", " ").replace("-", " ").capitalize(),"subtitle":"%d ROM%s" % [games.size(), "" if games.size() == 1 else "s"],"hint":"Your personal library","mark":folder.to_upper().left(4),"color":"426d8d","type":"submenu","children":games,"enabled":true})
    return systems

func _scan_roms(folder_path: String, games: Array, depth := 0) -> void:
    if depth > 3:
        return
    var files: PackedStringArray = DirAccess.get_files_at(folder_path)
    files.sort()
    for filename in files:
        if filename.begins_with("."):
            continue
        var extension := filename.get_extension().to_lower()
        var profile: Dictionary = profiles.get(extension, {})
        var full_path := folder_path.path_join(filename)
        var supported := not profile.is_empty()
        var game: Dictionary = {"id":"rom-" + full_path.sha256_text().left(12),"label":filename.get_basename().replace("_", " "),"subtitle":"%s • .%s" % [str(profile.get("system", "Unconfigured")), extension],"hint":"Cross launches this game" if supported else "Add an emulator profile to launch this ROM","mark":str(profile.get("mark", extension.to_upper().left(4))),"color":str(profile.get("color", "5e6470")),"type":"command" if supported else "unavailable","enabled":true}
        if supported:
            game["executable"] = "/opt/hearth/launchers/retroarch-game.sh"
            game["args"] = [str(profile.get("core", "")), full_path]
        else:
            game["error"] = "Hearth found %s, but .%s needs an emulator profile in launcher/config/library-profiles.json before it can launch." % [filename, extension]
        games.append(game)
    var folders: PackedStringArray = DirAccess.get_directories_at(folder_path)
    folders.sort()
    for child in folders:
        if not child.begins_with("."):
            _scan_roms(folder_path.path_join(child), games, depth + 1)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
        if modal.visible:
            modal.visible = false
        elif not stack.is_empty():
            var previous: Dictionary = stack.pop_back()
            _show_menu(previous["items"], previous["title"], previous["path"], int(previous["index"]))
        return
    var left: bool = event.is_action_pressed("ui_left") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_LEFT) or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and event.axis_value < -0.72)
    var right: bool = event.is_action_pressed("ui_right") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_RIGHT) or (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and event.axis_value > 0.72)
    if left:
        _select(selected - 1)
    elif right:
        _select(selected + 1)

func _process(_delta: float) -> void:
    if child_pid > 0 and not OS.is_process_running(child_pid):
        child_pid = -1
        footer.text = "Returned home safely"
        if is_instance_valid(last_button):
            last_button.grab_focus()

func _show_error(message: String) -> void:
    modal_label.text = message + "\n\nPress ○ / Esc to return."
    modal.visible = true

func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = border
    box.set_border_width_all(width)
    box.set_corner_radius_all(radius)
    return box
