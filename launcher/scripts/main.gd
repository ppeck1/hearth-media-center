extends Control

const INK := Color("101827")
const SLATE := Color("31445f")
const AMBER := Color("f2a93b")
const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const MENU_PATH := "res://config/menu.json"
const REGISTRY_PATH := "res://config/system-registry.json"
const LIBRARY_ROOT := "/srv/library/games/roms"
const HOME_MENU_PATH := "HEARTH  •  LIVING ROOM"
const HOME_BACKGROUND := preload("res://assets/backgrounds/arcade-living-room-v4.png")
const ARCADE_BACKGROUND_PATH := "res://assets/backgrounds/arcade-attract-v1.png"
const VIDEO_CLUB_BACKGROUND_PATH := "res://assets/backgrounds/video-club-aisle-v1.png"
const CONSOLE_GALLERY_BACKGROUND_PATH := "res://assets/backgrounds/console-gallery-v1.png"
const ArcadeFx := preload("res://scripts/arcade_fx.gd")
const ART_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.95, 0.66, 0.23, 1.0);
uniform float outline_strength : hint_range(0.0, 1.5) = 0.75;
uniform float glow_strength : hint_range(0.0, 1.5) = 0.45;
uniform float outline_width : hint_range(1.0, 12.0) = 3.0;
uniform float glow_width : hint_range(3.0, 28.0) = 10.0;
uniform float tint_dark_shapes : hint_range(0.0, 1.0) = 0.0;
uniform int cutout_mode = 0;

float visible_alpha(vec4 pixel, vec3 background_key) {
    if (cutout_mode == 0) {
        return pixel.a;
    }
    if (cutout_mode == 2) {
        float lightness = max(pixel.r, max(pixel.g, pixel.b));
        return pixel.a * smoothstep(0.42, 0.76, lightness);
    }
    float color_distance = distance(pixel.rgb, background_key);
    return pixel.a * smoothstep(0.09, 0.24, color_distance);
}

void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    vec3 background_key = (
        texture(TEXTURE, vec2(0.015, 0.015)).rgb +
        texture(TEXTURE, vec2(0.985, 0.015)).rgb +
        texture(TEXTURE, vec2(0.015, 0.985)).rgb +
        texture(TEXTURE, vec2(0.985, 0.985)).rgb
    ) * 0.25;
    float alpha = visible_alpha(pixel, background_key);
    vec2 outline_step = TEXTURE_PIXEL_SIZE * outline_width;
    vec2 glow_step = TEXTURE_PIXEL_SIZE * glow_width;
    float outline_neighbour = 0.0;
    float glow_neighbour = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            if (x == 0 && y == 0) {
                continue;
            }
            vec2 direction = vec2(float(x), float(y));
            vec4 outline_pixel = texture(TEXTURE, clamp(UV + outline_step * direction, vec2(0.0), vec2(1.0)));
            vec4 glow_pixel = texture(TEXTURE, clamp(UV + glow_step * direction, vec2(0.0), vec2(1.0)));
            outline_neighbour = max(outline_neighbour, visible_alpha(outline_pixel, background_key));
            glow_neighbour = max(glow_neighbour, visible_alpha(glow_pixel, background_key));
        }
    }
    float outline_alpha = max(0.0, outline_neighbour - alpha);
    float glow_alpha = max(0.0, glow_neighbour - alpha);
    float neon_alpha = max(outline_alpha * outline_strength, glow_alpha * glow_strength * 0.42);
    vec3 neon_rgb = outline_color.rgb * (1.1 + glow_strength * 0.25);
    float dark_shape = alpha * (1.0 - max(pixel.r, max(pixel.g, pixel.b))) * tint_dark_shapes;
    vec3 result_rgb = mix(pixel.rgb, neon_rgb, clamp(neon_alpha * 1.7 + dark_shape * 0.92, 0.0, 1.0));
    float result_alpha = max(alpha, neon_alpha);
    COLOR = vec4(result_rgb, result_alpha * COLOR.a);
}
"""

var background: TextureRect
var veil: ColorRect
var arcade_fx: Control
var stage: Control
var heading: Label
var detail: Label
var footer: Label
var collection_label: Label
var selection_label: Label
var modal: PanelContainer
var modal_label: Label
var items: Array = []
var buttons: Array[Button] = []
var stack: Array = []
var families: Array = []
var systems: Array = []
var folder_aliases: Dictionary = {}
var selected := 0
var child_pid := -1
var last_button: Button
var card_phase := 0.0
var card_tweens: Dictionary = {}
var art_shader: Shader
var current_menu_title := ""
var current_menu_path := ""
@onready var input_manager = $InputManager
@onready var input_settings = $InputSettings

func _ready() -> void:
    input_settings.closed.connect(_on_input_settings_closed)
    _build_ui()
    _load_registry()
    _load_home()

func _build_ui() -> void:
    art_shader = Shader.new()
    art_shader.code = ART_SHADER_CODE
    background = TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.texture = HOME_BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    veil = ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(INK, 0.60)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(veil)
    arcade_fx = ArcadeFx.new()
    add_child(arcade_fx)
    collection_label = _label(Vector2(1240, 28), Vector2(580, 30), 18, PAPER)
    collection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    collection_label.visible = false
    collection_label.add_theme_constant_override("outline_size", 4)
    collection_label.add_theme_color_override("font_outline_color", Color(INK, 0.92))
    add_child(collection_label)
    heading = _label(Vector2(88, 86), Vector2(760, 72), 58, PAPER)
    add_child(heading)
    heading.add_theme_constant_override("outline_size", 8)
    heading.add_theme_color_override("font_outline_color", Color(INK, 0.85))
    _start_clock()
    detail = _label(Vector2(92, 166), Vector2(1736, 38), 22, MUTED)
    add_child(detail)
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selection_label = _label(Vector2(92, 210), Vector2(1736, 30), 16, PAPER)
    selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selection_label.add_theme_color_override("font_color", Color(PAPER, 0.78))
    add_child(selection_label)
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

func _start_clock() -> void:
    _update_clock()
    var clock_timer := Timer.new()
    clock_timer.wait_time = 1.0
    clock_timer.autostart = true
    clock_timer.timeout.connect(_update_clock)
    add_child(clock_timer)

func _update_clock() -> void:
    if not current_menu_path.is_empty() and current_menu_path != HOME_MENU_PATH:
        return
    var now := Time.get_time_dict_from_system()
    var hour: int = int(now.hour)
    var period := "AM" if hour < 12 else "PM"
    var display_hour := hour % 12
    if display_hour == 0:
        display_hour = 12
    heading.text = "%02d:%02d:%02d %s" % [display_hour, int(now.minute), int(now.second), period]

func _load_registry() -> void:
    var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema_version", 0) != 1 or typeof(parsed.get("families")) != TYPE_ARRAY or typeof(parsed.get("systems")) != TYPE_ARRAY:
        return
    families = parsed["families"]
    systems = parsed["systems"]
    for system in systems:
        if typeof(system) != TYPE_DICTIONARY:
            continue
        for alias in system.get("aliases", []):
            folder_aliases[str(alias).to_lower()] = system

func _load_home() -> void:
    var file := FileAccess.open(MENU_PATH, FileAccess.READ)
    if file == null:
        _show_error("Hearth menu configuration could not be opened.")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema_version", 0) != 2:
        _show_error("Hearth menu configuration is invalid.")
        return
    _show_menu(parsed["items"], str(parsed.get("title", "Home")), HOME_MENU_PATH)

func _show_menu(next_items: Array, title: String, path: String, focus_index := 0) -> void:
    for tween in card_tweens.values():
        if tween is Tween and tween.is_valid():
            tween.kill()
    card_tweens.clear()
    for child in stage.get_children():
        child.queue_free()
    items = next_items
    buttons.clear()
    selected = 0
    current_menu_title = title
    current_menu_path = path
    if current_menu_path == HOME_MENU_PATH:
        _update_clock()
    else:
        heading.text = current_menu_title
    _set_visual_mode(path.contains("MY LIBRARY"), next_items)
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
    card.clip_contents = false
    var accent := Color(str(item.get("color", "426d8d")))
    var empty_style := StyleBoxEmpty.new()
    card.add_theme_stylebox_override("normal", empty_style)
    card.add_theme_stylebox_override("focus", empty_style)
    card.add_theme_stylebox_override("hover", empty_style)
    card.add_theme_stylebox_override("pressed", empty_style)
    card.add_theme_stylebox_override("disabled", empty_style)
    card.pressed.connect(_activate.bind(item, card))
    card.focus_entered.connect(_focus_card.bind(card))
    stage.add_child(card)
    var visual_root := Control.new()
    visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual_root.clip_contents = false
    card.add_child(visual_root)
    card.set_meta("visual_root", visual_root)

    var inset := MarginContainer.new()
    inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    inset.add_theme_constant_override("margin_left", 22)
    inset.add_theme_constant_override("margin_top", 18)
    inset.add_theme_constant_override("margin_right", 22)
    inset.add_theme_constant_override("margin_bottom", 18)
    inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual_root.add_child(inset)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    inset.add_child(box)
    var brand := str(item.get("brand", ""))
    if not brand.is_empty():
        var brand_label := Label.new()
        brand_label.text = brand
        brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        brand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        brand_label.add_theme_font_size_override("font_size", 16)
        brand_label.add_theme_color_override("font_color", Color(accent, 1.0))
        brand_label.add_theme_constant_override("outline_size", 3)
        brand_label.add_theme_color_override("font_outline_color", Color(INK, 0.92))
        box.add_child(brand_label)
        card.set_meta("brand_label", brand_label)
    var art_path := str(item.get("art", ""))
    var art_texture: Texture2D = load(art_path) if not art_path.is_empty() else null
    if art_texture != null:
        var art_region: Array = item.get("art_region", [])
        if art_region.size() == 4:
            var atlas_texture := AtlasTexture.new()
            atlas_texture.atlas = art_texture
            atlas_texture.region = Rect2(float(art_region[0]), float(art_region[1]), float(art_region[2]), float(art_region[3]))
            art_texture = atlas_texture
        var art := TextureRect.new()
        art.texture = art_texture
        art.custom_minimum_size = Vector2(0, 118)
        art.size_flags_vertical = Control.SIZE_EXPAND_FILL
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.modulate = Color(1.0, 1.0, 1.0, 1.0)
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var art_material := ShaderMaterial.new()
        art_material.shader = art_shader
        art_material.set_shader_parameter("outline_color", accent)
        art_material.set_shader_parameter("cutout_mode", _cutout_mode_for_art(art_path))
        art_material.set_shader_parameter("tint_dark_shapes", 1.0 if art_path.ends_with(".svg") else 0.0)
        art_material.set_shader_parameter("outline_width", 8.0 if art_path.contains("cutout") else 3.0)
        art_material.set_shader_parameter("glow_width", 20.0 if art_path.contains("cutout") else 9.0)
        art.material = art_material
        box.add_child(art)
        card.set_meta("art_node", art)
        card.set_meta("art_material", art_material)
        card.set_meta("is_cutout", art_path.contains("cutout"))
    else:
        var mark := Label.new()
        mark.text = str(item.get("mark", "•"))
        mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
        mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        mark.add_theme_font_size_override("font_size", 86)
        mark.add_theme_color_override("font_color", Color(accent, 1.0))
        mark.add_theme_constant_override("outline_size", 12)
        mark.add_theme_color_override("font_outline_color", Color(accent, 0.34))
        box.add_child(mark)
        card.set_meta("art_node", mark)
        card.set_meta("mark_node", mark)
    if item.has("count_label"):
        var count := Label.new()
        count.text = str(item.get("count_label", ""))
        count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        count.add_theme_font_size_override("font_size", 20)
        count.add_theme_color_override("font_color", AMBER)
        box.add_child(count)
        card.set_meta("count_label_node", count)

    card.set_meta("accent", accent)
    buttons.append(card)

func _cutout_mode_for_art(art_path: String) -> int:
    if art_path.contains("cutout"):
        return 0
    if art_path.ends_with("disneyplus.png"):
        return 2
    if art_path.ends_with(".png"):
        return 1
    return 0

func _focus_card(card: Button) -> void:
    _select(int(card.get_meta("index", 0)))

func _select(index: int, immediate := false) -> void:
    if buttons.is_empty():
        return
    selected = posmod(index, buttons.size())
    var focus_item: Dictionary = buttons[selected].get_meta("item", {})
    detail.text = str(focus_item.get("subtitle", ""))
    selection_label.text = "—  %s  —" % str(focus_item.get("hint", "Choose your next adventure"))
    arcade_fx.set_accent(Color(str(focus_item.get("color", "f2a93b"))))
    footer.text = "BROWSE     SELECT     BACK     %s" % str(focus_item.get("hint", ""))
    for card in buttons:
        var offset := _carousel_offset(int(card.get_meta("index", 0)), selected, buttons.size())
        var distance: int = absi(offset)
        var previous_tween: Tween = card_tweens.get(card)
        if previous_tween != null and previous_tween.is_valid():
            previous_tween.kill()
        var show_card := distance <= 2
        if not show_card:
            # Stage hidden cards just beyond the screen. A newly revealed
            # neighbour now glides in from the rail instead of expanding from
            # Godot's zero-size, top-left default state.
            var staged_size := Vector2(210.0, 176.0)
            var staged_center_x := -160.0 if offset < 0 else 2080.0
            card.size = staged_size
            card.position = Vector2(staged_center_x - staged_size.x * 0.5, 600.0 - staged_size.y * 0.5)
            card.pivot_offset = staged_size * 0.5
            card.rotation = 0.0
            card.modulate.a = 0.0
            card.visible = false
            _set_card_typography(card, false, distance)
            continue
        card.visible = true
        var selected_card: bool = offset == 0
        var size_value: Vector2
        var center_x := 960.0
        if selected_card:
            size_value = Vector2(520, 370)
        elif distance == 1:
            size_value = Vector2(300, 238)
            center_x += float(offset) * 480.0
        else:
            size_value = Vector2(210, 176)
            center_x += float(offset) * 392.5
        var center_y := 575.0 + float(distance) * 12.0
        var position_value := Vector2(center_x - size_value.x * 0.5, center_y - size_value.y * 0.5)
        var rotation_value := 0.0 if selected_card else float(offset) * -0.018
        card.pivot_offset = size_value * 0.5
        card.z_index = 10 - distance
        _set_card_typography(card, selected_card, distance)
        if immediate:
            card.position = position_value
            card.size = size_value
            card.rotation = rotation_value
            card.modulate.a = 1.0 if selected_card else 0.70 if distance == 1 else 0.42
        else:
            var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            card_tweens[card] = tween
            tween.tween_property(card, "position", position_value, 0.24)
            tween.tween_property(card, "size", size_value, 0.24)
            tween.tween_property(card, "rotation", rotation_value, 0.22)
            tween.tween_property(card, "modulate:a", 1.0 if selected_card else 0.70 if distance == 1 else 0.42, 0.18)
    buttons[selected].grab_focus()

func _carousel_offset(card_index: int, focus_index: int, item_count: int) -> int:
    var offset := card_index - focus_index
    if item_count <= 1:
        return offset
    var half := item_count / 2.0
    if float(offset) > half:
        offset -= item_count
    elif float(offset) < -half:
        offset += item_count
    return offset

func _set_card_typography(card: Button, selected_card: bool, distance: int) -> void:
    var brand_label: Label = card.get_meta("brand_label") if card.has_meta("brand_label") else null
    if brand_label != null:
        brand_label.visible = selected_card
        brand_label.add_theme_font_size_override("font_size", 16 if selected_card else 12)
    var count_label_node: Label = card.get_meta("count_label_node") if card.has_meta("count_label_node") else null
    if count_label_node != null:
        count_label_node.add_theme_font_size_override("font_size", 18 if selected_card else 14 if distance == 1 else 12)
    var art_node: Control = card.get_meta("art_node", null)
    if art_node != null:
        var is_cutout := bool(card.get_meta("is_cutout", false))
        art_node.custom_minimum_size.y = 270.0 if selected_card and is_cutout else 205.0 if selected_card else 160.0 if distance == 1 and is_cutout else 130.0 if distance == 1 else 110.0 if is_cutout else 88.0
        art_node.modulate.a = 1.0 if selected_card else 0.90 if distance == 1 else 0.72
    var accent: Color = card.get_meta("accent", AMBER)
    var art_material: ShaderMaterial = card.get_meta("art_material") if card.has_meta("art_material") else null
    if art_material != null:
        art_material.set_shader_parameter("outline_color", AMBER if selected_card else accent)
        art_material.set_shader_parameter("outline_strength", 1.05 if selected_card else 0.62 if distance == 1 else 0.38)
        art_material.set_shader_parameter("glow_strength", 0.38 if selected_card else 0.18 if distance == 1 else 0.08)
    var mark_node: Label = card.get_meta("mark_node") if card.has_meta("mark_node") else null
    if mark_node != null:
        var long_mark := mark_node.text.length() > 2
        mark_node.add_theme_font_size_override("font_size", 58 if selected_card and long_mark else 108 if selected_card else 42 if distance == 1 and long_mark else 72 if distance == 1 else 30 if long_mark else 50)
        mark_node.add_theme_constant_override("outline_size", 18 if selected_card else 11 if distance == 1 else 7)
        mark_node.add_theme_color_override("font_outline_color", Color(AMBER if selected_card else accent, 0.78 if selected_card else 0.42))

func _set_visual_mode(in_library: bool, next_items: Array) -> void:
    var in_streaming := current_menu_path.to_upper().contains("STREAMING")
    var showcase_mode := in_library or in_streaming
    if in_streaming:
        background.texture = load(VIDEO_CLUB_BACKGROUND_PATH)
    elif in_library:
        background.texture = load(ARCADE_BACKGROUND_PATH) if current_menu_path.ends_with("MY LIBRARY") else load(CONSOLE_GALLERY_BACKGROUND_PATH)
    else:
        background.texture = HOME_BACKGROUND
    veil.color = Color(INK, 0.42 if showcase_mode else 0.34)
    arcade_fx.set_arcade_mode(showcase_mode)
    collection_label.visible = showcase_mode
    selection_label.visible = showcase_mode
    if in_streaming:
        collection_label.text = "%d SERVICES READY" % next_items.size()
    elif in_library:
        var total_games := 0
        for item in next_items:
            if typeof(item) == TYPE_DICTIONARY:
                total_games += int(item.get("game_count", 0))
        if total_games == 0:
            for item in next_items:
                if typeof(item) == TYPE_DICTIONARY and str(item.get("type", "")) in ["command", "unavailable"]:
                    total_games += 1
        collection_label.text = "%d GAMES ONLINE" % total_games if total_games > 0 else "ARCADE LINK ACTIVE"

func _activate(item: Dictionary, card: Button) -> void:
    last_button = card
    var kind := str(item.get("type", ""))
    if kind == "panel":
        if str(item.get("panel_id", "")) == "input_settings":
            input_settings.open_panel()
            footer.text = "Input settings"
        else:
            _show_error("This settings panel is not available yet.")
        return
    if kind == "library":
        var systems := _library_systems()
        if systems.is_empty():
            _show_error("No ROMs found. Add game files under /srv/library/games/roms, then reopen Games.")
            return
        stack.append({"items":items,"title":current_menu_title,"path":current_menu_path,"index":selected})
        _show_menu(systems, "My Library", current_menu_path + "  ›  MY LIBRARY")
        return
    if kind == "submenu":
        var children: Array = item.get("children", [])
        stack.append({"items":items,"title":current_menu_title,"path":current_menu_path,"index":selected})
        _show_menu(children, str(item.get("label", "Menu")), current_menu_path + "  ›  " + str(item.get("label", "Menu")))
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
    var buckets: Dictionary = {}
    for system in systems:
        if typeof(system) == TYPE_DICTIONARY:
            buckets[str(system.get("id", ""))] = []
    var unknown: Dictionary = {}
    if DirAccess.dir_exists_absolute(LIBRARY_ROOT):
        var loose_files: Array = []
        _scan_system_folder(LIBRARY_ROOT, {}, loose_files, 0, false)
        if not loose_files.is_empty():
            unknown["Loose Files"] = loose_files
        var folders: PackedStringArray = DirAccess.get_directories_at(LIBRARY_ROOT)
        folders.sort()
        for folder in folders:
            if folder.begins_with("."):
                continue
            var mapped: Dictionary = folder_aliases.get(folder.to_lower(), {})
            if mapped.is_empty():
                var unknown_games: Array = []
                _scan_system_folder(LIBRARY_ROOT.path_join(folder), {}, unknown_games)
                if not unknown_games.is_empty():
                    unknown[folder] = unknown_games
            else:
                _scan_system_folder(LIBRARY_ROOT.path_join(folder), mapped, buckets[str(mapped.get("id", ""))])
    var family_items: Array = []
    for family in families:
        if typeof(family) != TYPE_DICTIONARY:
            continue
        var family_systems: Array = []
        var family_game_count := 0
        for system in systems:
            if typeof(system) == TYPE_DICTIONARY and str(system.get("family", "")) == str(family.get("id", "")):
                var games: Array = buckets.get(str(system.get("id", "")), [])
                if games.is_empty():
                    continue
                family_systems.append(_system_item(system, games))
                family_game_count += games.size()
        if not family_systems.is_empty():
            family_items.append({"id":str(family.get("id", "family")),"label":str(family.get("label", "Systems")),"brand":str(family.get("brand", "")),"art":str(family.get("art", "")),"subtitle":"%d systems • %d game%s" % [family_systems.size(), family_game_count, "" if family_game_count == 1 else "s"],"count_label":"%d game%s" % [family_game_count, "" if family_game_count == 1 else "s"],"game_count":family_game_count,"hint":"Choose a system","mark":str(family.get("mark", "•")),"color":str(family.get("color", "426d8d")),"type":"submenu","children":family_systems,"enabled":true})
    if not unknown.is_empty():
        var unknown_systems: Array = []
        var unmapped_game_count := 0
        for folder in unknown:
            var unknown_game_count: int = unknown[folder].size()
            unmapped_game_count += unknown_game_count
            unknown_systems.append({"id":"unmapped-" + str(folder),"label":str(folder).replace("_", " ").replace("-", " ").capitalize(),"subtitle":"%d game%s • emulator not assigned" % [unknown_game_count, "" if unknown_game_count == 1 else "s"],"count_label":"%d game%s" % [unknown_game_count, "" if unknown_game_count == 1 else "s"],"hint":"Add this folder to system-registry.json","mark":"?","color":"5e6470","type":"submenu","children":unknown[folder],"enabled":true})
        family_items.append({"id":"unmapped","label":"Unmapped Library","subtitle":"%d folders • %d game%s" % [unknown_systems.size(), unmapped_game_count, "" if unmapped_game_count == 1 else "s"],"count_label":"%d game%s" % [unmapped_game_count, "" if unmapped_game_count == 1 else "s"],"game_count":unmapped_game_count,"hint":"Nothing is hidden","mark":"?","color":"5e6470","type":"submenu","children":unknown_systems,"enabled":true})
    return family_items

func _system_item(system: Dictionary, games: Array) -> Dictionary:
    var count := games.size()
    var art_path := str(system.get("art", ""))
    return {"id":str(system.get("id", "system")),"label":str(system.get("label", "System")),"subtitle":"%d game%s • %s" % [count, "" if count == 1 else "s", str(system.get("emulator_label", "RetroArch"))],"count_label":"%d game%s" % [count, "" if count == 1 else "s"],"game_count":count,"art":art_path,"art_fit":"contain","hint":"Choose a game","mark":str(system.get("mark", "•")),"color":str(system.get("color", "426d8d")),"type":"submenu","children":games,"enabled":true}

func _scan_system_folder(folder_path: String, system: Dictionary, games: Array, depth := 0, scan_children := true) -> void:
    if depth > 3:
        return
    var files: PackedStringArray = DirAccess.get_files_at(folder_path)
    files.sort()
    for filename in files:
        if filename.begins_with(".") or _is_library_metadata(filename):
            continue
        var extension := filename.get_extension().to_lower()
        var full_path := folder_path.path_join(filename)
        var core := str(system.get("core", ""))
        var core_available := not core.is_empty() and FileAccess.file_exists("/usr/lib64/libretro/" + core)
        var supported := not system.is_empty() and core_available
        var game: Dictionary = {"id":"rom-" + full_path.sha256_text().left(12),"label":filename.get_basename().replace("_", " "),"subtitle":"%s • .%s" % [str(system.get("label", "Unmapped ROM")), extension],"hint":"Cross launches this game" if supported else "This system's emulator is not installed yet","mark":str(system.get("mark", extension.to_upper().left(4))),"color":str(system.get("color", "5e6470")),"type":"command" if supported else "unavailable","enabled":true}
        if supported:
            game["executable"] = "/opt/hearth/launchers/retroarch-game.sh"
            game["args"] = [core, full_path]
        else:
            game["error"] = "Hearth found %s. %s is configured for %s, but the required core (%s) is not installed in /usr/lib64/libretro yet." % [filename, str(system.get("label", "this folder")), str(system.get("emulator_label", "RetroArch")), core if not core.is_empty() else "none"]
        games.append(game)
    if not scan_children:
        return
    var folders: PackedStringArray = DirAccess.get_directories_at(folder_path)
    folders.sort()
    for child in folders:
        if not child.begins_with("."):
            _scan_system_folder(folder_path.path_join(child), system, games, depth + 1)

func _is_library_metadata(filename: String) -> bool:
    return filename.get_extension().to_lower() in ["md", "txt", "nfo", "json", "xml", "jpg", "jpeg", "png", "webp"]

func _unhandled_input(event: InputEvent) -> void:
    if input_settings.visible:
        input_settings.handle_unhandled_input(event)
        get_viewport().set_input_as_handled()
        return
    if input_manager.action_pressed(event, "home") and not stack.is_empty():
        stack.clear()
        _load_home()
        return
    if input_manager.action_pressed(event, "back"):
        if modal.visible:
            modal.visible = false
        elif not stack.is_empty():
            var previous: Dictionary = stack.pop_back()
            _show_menu(previous["items"], previous["title"], previous["path"], int(previous["index"]))
        return
    var left: bool = input_manager.action_pressed(event, "navigate_left") or input_manager.action_pressed(event, "page_left")
    var right: bool = input_manager.action_pressed(event, "navigate_right") or input_manager.action_pressed(event, "page_right")
    if left:
        _select(selected - 1)
    elif right:
        _select(selected + 1)
    elif input_manager.action_pressed(event, "select") and selected >= 0 and selected < buttons.size():
        _activate(buttons[selected].get_meta("item", {}), buttons[selected])

func _on_input_settings_closed() -> void:
    footer.text = "Returned to Hearth"
    if is_instance_valid(last_button):
        last_button.grab_focus()

func _process(delta: float) -> void:
    card_phase += delta
    for card in buttons:
        if not is_instance_valid(card) or not card.visible:
            continue
        var visual_root: Control = card.get_meta("visual_root", null)
        if visual_root == null:
            continue
        visual_root.pivot_offset = card.size * 0.5
        var is_selected := int(card.get_meta("index", -1)) == selected
        if is_selected:
            var breathe := 1.0 + sin(card_phase * 2.25) * 0.008
            visual_root.scale = Vector2.ONE * breathe
            visual_root.rotation = sin(card_phase * 1.35) * 0.0035
            visual_root.position.y = sin(card_phase * 1.75) * 2.5
        else:
            visual_root.scale = visual_root.scale.lerp(Vector2.ONE, minf(1.0, delta * 9.0))
            visual_root.rotation = lerpf(visual_root.rotation, 0.0, minf(1.0, delta * 9.0))
            visual_root.position.y = lerpf(visual_root.position.y, 0.0, minf(1.0, delta * 9.0))
    if child_pid > 0 and not OS.is_process_running(child_pid):
        child_pid = -1
        footer.text = "Returned home safely"
        if is_instance_valid(last_button):
            last_button.grab_focus()

func _show_error(message: String) -> void:
    modal_label.text = message + "\n\nPress ○ / Esc to return."
    modal.visible = true

func _box(fill: Color, border: Color, width: int, radius: int, shadow := Color(0, 0, 0, 0), shadow_size := 0) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = border
    box.set_border_width_all(width)
    box.set_corner_radius_all(radius)
    box.shadow_color = shadow
    box.shadow_size = shadow_size
    return box
