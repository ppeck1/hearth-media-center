extends Control

const INK := Color("101827")
const SLATE := Color("31445f")
const AMBER := Color("f2a93b")
const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const MENU_PATH := "res://config/menu.json"
const REGISTRY_PATH := "res://config/system-registry.json"
const LIBRARY_ROOT := "/srv/library/games/roms"
const SYSTEM_CORE_ROOT := "/usr/lib64/libretro"
const HOME_MENU_PATH := "HEARTH  •  LIVING ROOM"
const HOME_BACKGROUND := preload("res://assets/backgrounds/arcade-living-room-v4.png")
const ARCADE_BACKGROUND_PATH := "res://assets/backgrounds/arcade-attract-v1.png"
const VIDEO_CLUB_BACKGROUND_PATH := "res://assets/backgrounds/video-club-aisle-v1.png"
const CONSOLE_GALLERY_BACKGROUND_PATH := "res://assets/backgrounds/console-gallery-v1.png"
const ArcadeFx := preload("res://scripts/arcade_fx.gd")
const LibraryActivityStore := preload("res://scripts/library/library_activity_store.gd")
const StreamingServiceStore := preload("res://scripts/settings/streaming_service_store.gd")
const LibrarySettingsStore := preload("res://scripts/settings/library_settings_store.gd")
const TILE_GRID_COLUMNS := 3
const TILE_GRID_VISIBLE_ROWS := 3
const TILE_GRID_PAGE_SIZE := TILE_GRID_COLUMNS * TILE_GRID_VISIBLE_ROWS
const TILE_GRID_CARD_SIZE := Vector2(480, 208)
const TILE_GRID_ORIGIN := Vector2(216, 255)
const TILE_GRID_STEP := Vector2(504, 224)
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
var artwork_indexes: Dictionary = {}
var system_folder_art: Dictionary = {}
var system_folder_wallpapers: Dictionary = {}
var library_activity_store
var streaming_service_store
var library_settings_store
var menu_root_items: Array = []
var movies_tv_catalog: Array = []
var current_menu_title := ""
var current_menu_path := ""
var current_menu_layout := "carousel"
var input_rearm_at_msec := 0
@onready var input_manager = $InputManager
@onready var input_settings = $InputSettings
@onready var library_browser = $LibraryBrowser
@onready var streaming_services = $StreamingServices
@onready var library_settings = $LibrarySettings

func _ready() -> void:
    input_rearm_at_msec = Time.get_ticks_msec() + 450
    input_settings.closed.connect(_on_input_settings_closed)
    library_browser.launch_requested.connect(_on_library_launch_requested)
    library_browser.closed.connect(_on_library_closed)
    streaming_services.save_requested.connect(_on_streaming_services_save_requested)
    streaming_services.closed.connect(_on_streaming_services_closed)
    library_settings.save_requested.connect(_on_library_settings_save_requested)
    library_settings.closed.connect(_on_library_settings_closed)
    library_activity_store = LibraryActivityStore.new()
    library_activity_store.reload()
    streaming_service_store = StreamingServiceStore.new()
    library_settings_store = LibrarySettingsStore.new()
    library_settings_store.load_settings()
    _build_ui()
    library_browser.z_index = 100
    input_settings.z_index = 100
    streaming_services.z_index = 110
    library_settings.z_index = 110
    modal.z_index = 200
    move_child(library_browser, get_child_count() - 1)
    move_child(input_settings, get_child_count() - 1)
    move_child(streaming_services, get_child_count() - 1)
    move_child(library_settings, get_child_count() - 1)
    move_child(modal, get_child_count() - 1)
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
    menu_root_items = parsed["items"].duplicate(true)
    var movies_tv := _item_with_id(menu_root_items, "movies-tv")
    movies_tv_catalog = movies_tv.get("children", []).duplicate(true)
    var default_service_ids: Array[String] = []
    for child_value in movies_tv_catalog:
        if child_value is Dictionary and bool(child_value.get("manageable_service", false)):
            default_service_ids.append(str(child_value.get("id", "")))
    streaming_service_store.load(default_service_ids)
    _show_menu(menu_root_items, str(parsed.get("title", "Home")), HOME_MENU_PATH)

func _show_menu(next_items: Array, title: String, path: String, focus_index := 0, layout := "carousel") -> void:
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
    current_menu_layout = layout
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

func _movies_tv_items() -> Array:
    var result: Array = []
    for child_value in movies_tv_catalog:
        if not child_value is Dictionary:
            continue
        var child: Dictionary = child_value
        if bool(child.get("manageable_service", false)) and str(child.get("id", "")) not in streaming_service_store.enabled_ids:
            continue
        result.append(child.duplicate(true))
    return result

func _manageable_streaming_services() -> Array:
    var result: Array = []
    for child_value in movies_tv_catalog:
        if child_value is Dictionary and bool(child_value.get("manageable_service", false)):
            result.append(child_value.duplicate(true))
    return result

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
    var external_art := not art_path.is_empty() and not art_path.begins_with("res://") and FileAccess.file_exists(art_path)
    var art_texture := _load_art_texture(art_path) if not external_art else null
    if art_texture != null or external_art:
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
        if external_art:
            card.set_meta("external_art_path", art_path)
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
    if item.has("caption"):
        var caption := Label.new()
        caption.text = str(item.get("caption", ""))
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        caption.max_lines_visible = 2
        caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        caption.add_theme_font_size_override("font_size", 20)
        caption.add_theme_color_override("font_color", PAPER)
        caption.add_theme_constant_override("outline_size", 4)
        caption.add_theme_color_override("font_outline_color", Color(INK, 0.92))
        box.add_child(caption)
        card.set_meta("caption_node", caption)

    card.set_meta("accent", accent)
    buttons.append(card)

func _load_art_texture(art_path: String) -> Texture2D:
    if art_path.is_empty():
        return null
    if art_path.begins_with("res://"):
        return load(art_path)
    if not FileAccess.file_exists(art_path):
        return null
    var image := Image.load_from_file(art_path)
    if image == null or image.is_empty():
        return null
    return ImageTexture.create_from_image(image)

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
    if current_menu_layout == "tile_grid":
        _select_tile_grid(index, immediate)
        return
    selected = posmod(index, buttons.size())
    var focus_item: Dictionary = buttons[selected].get_meta("item", {})
    var subtitle := str(focus_item.get("subtitle", ""))
    var hint := str(focus_item.get("hint", ""))
    var header_hint := str(focus_item.get("header_hint", hint))
    detail.text = subtitle
    detail.visible = not subtitle.is_empty()
    selection_label.text = "" if header_hint.is_empty() else "—  %s  —" % header_hint
    selection_label.visible = collection_label.visible and not header_hint.is_empty()
    arcade_fx.set_accent(Color(str(focus_item.get("color", "f2a93b"))))
    footer.text = "BROWSE     SELECT     BACK" if hint.is_empty() else "BROWSE     SELECT     BACK     %s" % hint
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

func _select_tile_grid(index: int, immediate := false) -> void:
    selected = clampi(index, 0, buttons.size() - 1)
    var focus_item: Dictionary = buttons[selected].get_meta("item", {})
    var subtitle := str(focus_item.get("subtitle", ""))
    var hint := str(focus_item.get("hint", ""))
    detail.text = subtitle
    detail.visible = not subtitle.is_empty()
    selection_label.text = "—  %s  —" % hint if not hint.is_empty() else ""
    selection_label.visible = not hint.is_empty()
    arcade_fx.set_accent(Color(str(focus_item.get("color", "f2a93b"))))
    var selected_row := selected / TILE_GRID_COLUMNS
    var first_visible_row := maxi(0, selected_row - (TILE_GRID_VISIBLE_ROWS - 1))
    var first_visible_index := first_visible_row * TILE_GRID_COLUMNS
    var last_visible_index := mini(buttons.size(), first_visible_index + TILE_GRID_PAGE_SIZE)
    footer.text = "D-PAD  Browse    SELECT  Open    BACK  Home    %d–%d of %d" % [
        first_visible_index + 1,
        last_visible_index,
        buttons.size(),
    ]
    for card in buttons:
        var card_index := int(card.get_meta("index", 0))
        var row := card_index / TILE_GRID_COLUMNS
        var column := card_index % TILE_GRID_COLUMNS
        var visible_row := row - first_visible_row
        var visible_card := visible_row >= 0 and visible_row < TILE_GRID_VISIBLE_ROWS
        var previous_tween: Tween = card_tweens.get(card)
        if previous_tween != null and previous_tween.is_valid():
            previous_tween.kill()
        card.visible = visible_card
        if not visible_card:
            continue
        var selected_card := card_index == selected
        var target_position := TILE_GRID_ORIGIN + Vector2(column * TILE_GRID_STEP.x, visible_row * TILE_GRID_STEP.y)
        card.size = TILE_GRID_CARD_SIZE
        card.pivot_offset = TILE_GRID_CARD_SIZE * 0.5
        card.rotation = 0.0
        card.z_index = 10 if selected_card else 1
        card.clip_contents = true
        var accent: Color = card.get_meta("accent", AMBER)
        var tile_style := _box(
            Color("1c2b42") if selected_card else Color("162235"),
            AMBER if selected_card else Color(accent, 0.78),
            4 if selected_card else 2,
            12
        )
        card.add_theme_stylebox_override("normal", tile_style)
        card.add_theme_stylebox_override("focus", tile_style)
        card.add_theme_stylebox_override("hover", _box(Color("1c2b42"), AMBER, 4, 12))
        card.add_theme_stylebox_override("pressed", _box(Color("23344d"), AMBER, 4, 12))
        var art_node: Control = card.get_meta("art_node", null)
        if art_node != null:
            _update_external_card_art(card, 0)
            art_node.custom_minimum_size.y = 126.0
            art_node.modulate.a = 1.0 if selected_card else 0.88
        var caption_node: Label = card.get_meta("caption_node") if card.has_meta("caption_node") else null
        if caption_node != null:
            caption_node.visible = true
            caption_node.add_theme_font_size_override("font_size", 19 if selected_card else 17)
        var mark_node: Label = card.get_meta("mark_node") if card.has_meta("mark_node") else null
        if mark_node != null:
            var long_mark := mark_node.text.length() > 2
            mark_node.add_theme_font_size_override("font_size", 58 if long_mark else 78)
            mark_node.add_theme_constant_override("outline_size", 10)
            mark_node.add_theme_color_override("font_outline_color", Color(AMBER if selected_card else accent, 0.62))
        var art_material: ShaderMaterial = card.get_meta("art_material") if card.has_meta("art_material") else null
        if art_material != null:
            art_material.set_shader_parameter("outline_color", AMBER if selected_card else accent)
            art_material.set_shader_parameter("outline_strength", 0.92 if selected_card else 0.46)
            art_material.set_shader_parameter("glow_strength", 0.30 if selected_card else 0.10)
        if immediate:
            card.position = target_position
            card.modulate.a = 1.0 if selected_card else 0.84
        else:
            var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            card_tweens[card] = tween
            tween.tween_property(card, "position", target_position, 0.18)
            tween.tween_property(card, "modulate:a", 1.0 if selected_card else 0.84, 0.14)
    buttons[selected].grab_focus()

func _move_tile_grid(horizontal: int, vertical: int) -> void:
    if buttons.is_empty():
        return
    var row := selected / TILE_GRID_COLUMNS
    var column := selected % TILE_GRID_COLUMNS
    var target := selected
    if vertical != 0:
        var target_row := row + vertical
        var row_start := target_row * TILE_GRID_COLUMNS
        if target_row >= 0 and row_start < buttons.size():
            target = mini(row_start + column, buttons.size() - 1)
    elif horizontal < 0 and column > 0:
        target -= 1
    elif horizontal > 0 and column < TILE_GRID_COLUMNS - 1 and target + 1 < buttons.size():
        target += 1
    _select(target)

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
    var caption_node: Label = card.get_meta("caption_node") if card.has_meta("caption_node") else null
    if caption_node != null:
        caption_node.visible = selected_card or distance == 1
        caption_node.add_theme_font_size_override("font_size", 20 if selected_card else 14)
    var art_node: Control = card.get_meta("art_node", null)
    if art_node != null:
        _update_external_card_art(card, distance)
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

func _update_external_card_art(card: Button, distance: int) -> void:
    if not card.has_meta("external_art_path"):
        return
    var art_node: TextureRect = card.get_meta("art_node")
    if distance <= 2 and art_node.texture == null:
        art_node.texture = _load_art_texture(str(card.get_meta("external_art_path")))
    elif distance > 2 and art_node.texture != null:
        art_node.texture = null

func _set_visual_mode(in_library: bool, next_items: Array) -> void:
    var in_movies_tv := current_menu_path.to_upper().contains("MOVIES & TV")
    var showcase_mode := in_library or in_movies_tv
    if in_movies_tv:
        background.texture = load(VIDEO_CLUB_BACKGROUND_PATH)
    elif in_library:
        background.texture = load(ARCADE_BACKGROUND_PATH) if current_menu_path.ends_with("MY LIBRARY") else load(CONSOLE_GALLERY_BACKGROUND_PATH)
    else:
        background.texture = HOME_BACKGROUND
    veil.color = Color(INK, 0.42 if showcase_mode else 0.34)
    arcade_fx.set_arcade_mode(showcase_mode)
    collection_label.visible = showcase_mode
    selection_label.visible = showcase_mode
    if in_movies_tv:
        var destination_count := 0
        for item in next_items:
            if item is Dictionary and str(item.get("id", "")) != "manage-services":
                destination_count += 1
        collection_label.text = "%d DESTINATIONS READY" % destination_count
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
    if not _can_accept_navigation_input():
        return
    last_button = card
    var kind := str(item.get("type", ""))
    if kind == "panel":
        var panel_id := str(item.get("panel_id", ""))
        if panel_id == "input_settings":
            input_settings.open_panel()
            footer.text = "Input settings"
        elif panel_id == "library_settings":
            library_settings.open_panel(library_settings_store.data, _launcher_system_options())
            footer.text = "Library & launchers"
        elif panel_id == "streaming_services":
            streaming_services.open_panel(_manageable_streaming_services(), streaming_service_store.enabled_ids)
            footer.text = "Movies & TV services"
        else:
            _show_error("This settings panel is not available yet.")
        return
    if kind == "library":
        var library_families := _library_systems()
        if library_families.is_empty():
            _show_error("No ROMs found. Add game files under /srv/library/games/roms, then reopen Games.")
            return
        library_activity_store.reload()
        library_browser.open_library(library_families, library_activity_store)
        return
    if kind == "submenu":
        var children: Array = item.get("children", [])
        if str(item.get("id", "")) == "movies-tv":
            children = _movies_tv_items()
        stack.append({
            "items":items,
            "title":current_menu_title,
            "path":current_menu_path,
            "index":selected,
            "layout":current_menu_layout,
        })
        _show_menu(
            children,
            str(item.get("label", "Menu")),
            current_menu_path + "  ›  " + str(item.get("label", "Menu")),
            0,
            str(item.get("menu_layout", "carousel"))
        )
        return
    if kind == "unavailable":
        _show_error(str(item.get("error", "Install and map a compatible RetroArch core first.")))
        return
    if kind != "command":
        return
    _launch_command(item)

func _launch_command(item: Dictionary) -> void:
    if child_pid > 0:
        return
    var executable := str(item.get("executable", ""))
    if not executable.begins_with("/opt/hearth/launchers/") or not FileAccess.file_exists(executable):
        _show_error("The launcher is missing. Deploy this source version before starting applications.")
        return
    var launched_pid := OS.create_process(executable, item.get("args", []))
    if launched_pid <= 0:
        _show_error("The selected application could not start.")
        return
    if bool(item.get("detached", false)):
        library_activity_store.record_launch(item)
        footer.text = "%s opened" % str(item.get("label", "Application"))
        return
    library_activity_store.begin_session(item)
    child_pid = launched_pid
    footer.text = "%s is running…" % str(item.get("label", "Application"))

func _on_library_launch_requested(item: Dictionary) -> void:
    if str(item.get("type", "")) == "unavailable":
        _show_error(str(item.get("error", "This game does not have a compatible launcher yet.")))
        return
    _launch_command(item)

func _on_library_closed() -> void:
    if is_instance_valid(last_button):
        last_button.grab_focus()

func _library_systems() -> Array:
    system_folder_art.clear()
    system_folder_wallpapers.clear()
    var buckets: Dictionary = {}
    for system in systems:
        if typeof(system) == TYPE_DICTIONARY:
            buckets[str(system.get("id", ""))] = _manifest_games(system)
    var unknown: Dictionary = {}
    var unknown_art: Dictionary = {}
    var unknown_wallpapers: Dictionary = {}
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
                    var unknown_folder_path := LIBRARY_ROOT.path_join(folder)
                    unknown_art[folder] = _find_folder_art(unknown_folder_path)
                    unknown_wallpapers[folder] = _find_folder_wallpaper(unknown_folder_path)
            else:
                var mapped_folder_path := LIBRARY_ROOT.path_join(folder)
                var mapped_system_id := str(mapped.get("id", ""))
                var folder_art := _find_folder_art(mapped_folder_path)
                if not folder_art.is_empty() and not system_folder_art.has(mapped_system_id):
                    system_folder_art[mapped_system_id] = folder_art
                var folder_wallpaper := _find_folder_wallpaper(mapped_folder_path)
                if not folder_wallpaper.is_empty() and not system_folder_wallpapers.has(mapped_system_id):
                    system_folder_wallpapers[mapped_system_id] = folder_wallpaper
                _scan_system_folder(mapped_folder_path, mapped, buckets[mapped_system_id])
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
                family_game_count += _game_count(games)
        if not family_systems.is_empty():
            family_items.append({"id":str(family.get("id", "family")),"label":str(family.get("label", "Systems")),"art":str(family.get("art", "")),"subtitle":"%d systems • %d game%s" % [family_systems.size(), family_game_count, "" if family_game_count == 1 else "s"],"count_label":"%d game%s" % [family_game_count, "" if family_game_count == 1 else "s"],"game_count":family_game_count,"hint":"Choose a family","header_hint":"Choose a family","mark":str(family.get("mark", "•")),"color":str(family.get("color", "426d8d")),"type":"submenu","children":family_systems,"enabled":true})
    if not unknown.is_empty():
        var unknown_systems: Array = []
        var unmapped_game_count := 0
        for folder in unknown:
            var unknown_game_count := _game_count(unknown[folder])
            unmapped_game_count += unknown_game_count
            var unknown_system := {"id":"unmapped-" + str(folder),"label":str(folder).replace("_", " ").replace("-", " ").capitalize(),"subtitle":"%d game%s • emulator not assigned" % [unknown_game_count, "" if unknown_game_count == 1 else "s"],"count_label":"%d game%s" % [unknown_game_count, "" if unknown_game_count == 1 else "s"],"game_count":unknown_game_count,"hint":"Add this folder to system-registry.json","mark":"?","color":"5e6470","type":"submenu","children":unknown[folder],"enabled":true}
            var unknown_folder_art := str(unknown_art.get(folder, ""))
            if not unknown_folder_art.is_empty():
                unknown_system["art"] = unknown_folder_art
            var unknown_folder_wallpaper := str(unknown_wallpapers.get(folder, ""))
            if not unknown_folder_wallpaper.is_empty():
                unknown_system["wallpaper"] = unknown_folder_wallpaper
            unknown_systems.append(unknown_system)
        family_items.append({"id":"unmapped","label":"Unmapped Library","subtitle":"%d folders • %d game%s" % [unknown_systems.size(), unmapped_game_count, "" if unmapped_game_count == 1 else "s"],"count_label":"%d game%s" % [unmapped_game_count, "" if unmapped_game_count == 1 else "s"],"game_count":unmapped_game_count,"hint":"Choose a family","header_hint":"Choose a family","mark":"?","color":"5e6470","type":"submenu","children":unknown_systems,"enabled":true})
    return family_items

func _manifest_games(system: Dictionary) -> Array:
    if str(system.get("backend", "")) != "manifest":
        return []
    var manifest_games: Array = []
    var entries: Array = system.get("entries", []).duplicate(true)
    var manifest_path := str(system.get("manifest_path", ""))
    if not manifest_path.is_empty():
        var manifest_folder := manifest_path.get_base_dir()
        var system_id := str(system.get("id", ""))
        var manifest_icon := _find_folder_art(manifest_folder)
        if not manifest_icon.is_empty():
            system_folder_art[system_id] = manifest_icon
        var manifest_wallpaper := _find_folder_wallpaper(manifest_folder)
        if not manifest_wallpaper.is_empty():
            system_folder_wallpapers[system_id] = manifest_wallpaper
    if not manifest_path.is_empty() and FileAccess.file_exists(manifest_path):
        var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
        if manifest_file != null:
            var manifest_value = JSON.parse_string(manifest_file.get_as_text())
            manifest_file.close()
            if typeof(manifest_value) == TYPE_DICTIONARY:
                var local_entries = manifest_value.get("entries", [])
                if typeof(local_entries) == TYPE_ARRAY:
                    entries.append_array(local_entries)
    for entry_value in entries:
        if typeof(entry_value) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = entry_value
        var executable := str(entry.get("executable", ""))
        var game_id := str(entry.get("id", "pc-game"))
        var label := str(entry.get("label", "PC Game"))
        var game: Dictionary = {
            "id":"native-" + game_id,
            "label":label,
            "caption":label,
            "subtitle":"",
            "hint":"",
            "header_hint":"",
            "mark":str(system.get("mark", "PC")),
            "color":str(system.get("color", "5e6470")),
            "type":"command",
            "enabled":true,
            "executable":executable,
            "args":entry.get("args", []),
            "system_id":str(system.get("id", "")),
            "system_label":str(system.get("label", "PC Games")),
            "family_id":str(system.get("family", "pc"))
        }
        var entry_folder := str(entry.get("folder", entry.get("source_folder", "")))
        if not entry_folder.is_empty() and not entry_folder.is_absolute_path() and not manifest_path.is_empty():
            entry_folder = manifest_path.get_base_dir().path_join(entry_folder)
        if not entry_folder.is_empty() and DirAccess.dir_exists_absolute(entry_folder):
            game["source_folder"] = entry_folder
            var entry_wallpaper := _find_folder_wallpaper(entry_folder)
            if not entry_wallpaper.is_empty():
                game["wallpaper"] = entry_wallpaper
        var art_path := _find_folder_art(entry_folder) if not entry_folder.is_empty() else ""
        if art_path.is_empty():
            art_path = str(entry.get("art", ""))
        if not art_path.is_empty() and FileAccess.file_exists(art_path):
            game["art"] = art_path
            game["art_mode"] = "cover"
        else:
            var fallback_art := str(system.get("art", ""))
            if not fallback_art.is_empty():
                game["art"] = fallback_art
                game["art_fit"] = "contain"
        manifest_games.append(game)
    return manifest_games

func _system_item(system: Dictionary, games: Array) -> Dictionary:
    var count := _game_count(games)
    var system_id := str(system.get("id", "system"))
    var art_path := str(system_folder_art.get(system_id, system.get("art", "")))
    var system_label := str(system.get("label", "System"))
    var item := {"id":system_id,"label":system_label,"subtitle":"%d game%s available" % [count, "" if count == 1 else "s"],"caption":system_label,"game_count":count,"art":art_path,"hint":"Choose a game","header_hint":"","mark":str(system.get("mark", "•")),"color":str(system.get("color", "426d8d")),"type":"submenu","children":games,"enabled":true}
    var wallpaper_path := str(system_folder_wallpapers.get(system_id, ""))
    if not wallpaper_path.is_empty():
        item["wallpaper"] = wallpaper_path
    if not system_folder_art.has(system_id):
        item["art_fit"] = "contain"
    return item

func _scan_system_folder(folder_path: String, system: Dictionary, games: Array, depth := 0, scan_children := true) -> void:
    if depth > 8:
        return
    var files: PackedStringArray = DirAccess.get_files_at(folder_path)
    files.sort()
    for filename in files:
        if filename.begins_with(".") or _is_library_metadata(filename):
            continue
        var extension := filename.get_extension().to_lower()
        var full_path := folder_path.path_join(filename)
        var allowed_extensions: Array = system.get("extensions", [])
        if not system.is_empty() and not allowed_extensions.is_empty() and not extension in allowed_extensions:
            continue
        var core := _core_for_system(system)
        var core_available := not _retroarch_core_path(core).is_empty()
        var supported := not system.is_empty() and core_available
        var game_title := _clean_game_title(filename)
        var game: Dictionary = {"id":"rom-" + full_path.sha256_text().left(12),"label":game_title,"caption":game_title,"subtitle":"","hint":"","header_hint":"","mark":str(system.get("mark", extension.to_upper().left(4))),"color":str(system.get("color", "5e6470")),"type":"command" if supported else "unavailable","enabled":true,"rom_path":full_path,"system_id":str(system.get("id", "")),"system_label":str(system.get("label", "")),"family_id":str(system.get("family", "")),"core":core}
        var game_art := _find_game_art(folder_path, filename, system)
        if not game_art.is_empty():
            game["art"] = game_art
            game["art_mode"] = "cover"
        else:
            var fallback_art := str(system.get("art", ""))
            if not fallback_art.is_empty():
                game["art"] = fallback_art
                game["art_fit"] = "contain"
        if supported:
            game["executable"] = "/opt/hearth/launchers/retroarch-game.sh"
            game["args"] = [
                core,
                full_path,
                "fullscreen" if library_settings_store.retroarch_fullscreen() else "windowed",
            ]
        else:
            game["error"] = "Hearth found %s. %s is configured for %s, but the required core (%s) is not installed yet." % [filename, str(system.get("label", "this folder")), str(system.get("emulator_label", "RetroArch")), core if not core.is_empty() else "none"]
        games.append(game)
    if not scan_children:
        return
    var folders: PackedStringArray = DirAccess.get_directories_at(folder_path)
    folders.sort()
    for child in folders:
        if not child.begins_with("."):
            var child_path := folder_path.path_join(child)
            var child_items: Array = []
            _scan_system_folder(child_path, system, child_items, depth + 1)
            if child_items.is_empty():
                continue
            if library_settings_store.preserve_folders():
                games.append(_folder_item(child_path, child, system, child_items))
            else:
                games.append_array(child_items)

func _folder_item(folder_path: String, folder_name: String, system: Dictionary, children: Array) -> Dictionary:
    var count := _game_count(children)
    var label := folder_name.replace("_", " ").replace("-", " ").capitalize()
    var item := {
        "id": "folder-" + folder_path.sha256_text().left(12),
        "label": label,
        "caption": label,
        "subtitle": "%d game%s" % [count, "" if count == 1 else "s"],
        "count_label": "%d" % count,
        "game_count": count,
        "hint": "Open folder",
        "header_hint": "",
        "mark": "DIR",
        "color": str(system.get("color", "5e6470")),
        "type": "folder",
        "children": children,
        "source_folder": folder_path,
        "enabled": true,
    }
    var folder_art := _find_folder_art(folder_path)
    if not folder_art.is_empty():
        item["art"] = folder_art
    else:
        var fallback_art := str(system.get("art", ""))
        if not fallback_art.is_empty():
            item["art"] = fallback_art
            item["art_fit"] = "contain"
    var folder_wallpaper := _find_folder_wallpaper(folder_path)
    if not folder_wallpaper.is_empty():
        item["wallpaper"] = folder_wallpaper
    return item

func _game_count(items_value: Array) -> int:
    var count := 0
    for item_value in items_value:
        if not item_value is Dictionary:
            continue
        if str(item_value.get("type", "")) == "folder":
            count += _game_count(item_value.get("children", []))
        else:
            count += 1
    return count

func _clean_game_title(filename: String) -> String:
    var title := filename.get_basename()
    for compound_suffix in [".nkit", ".rvz", ".iso"]:
        if title.to_lower().ends_with(compound_suffix):
            title = title.substr(0, title.length() - compound_suffix.length())
    title = title.replace("_", " ").strip_edges()
    var tag_start := title.find(" (")
    var bracket_start := title.find(" [")
    if bracket_start >= 0 and (tag_start < 0 or bracket_start < tag_start):
        tag_start = bracket_start
    if tag_start > 0:
        title = title.left(tag_start)
    return title.strip_edges()

func _retroarch_core_path(core_file: String) -> String:
    if core_file.is_empty() or not core_file.ends_with("_libretro.so") or core_file.get_file() != core_file:
        return ""
    for core_root: String in [_user_retroarch_core_root(), SYSTEM_CORE_ROOT]:
        if not core_root.is_empty():
            var candidate: String = core_root.path_join(core_file)
            if FileAccess.file_exists(candidate):
                return candidate
    return ""

func _user_retroarch_core_root() -> String:
    var config_home := OS.get_environment("XDG_CONFIG_HOME")
    if config_home.is_empty():
        var home_dir := OS.get_environment("HOME")
        if home_dir.is_empty():
            return ""
        config_home = home_dir.path_join(".config")
    return config_home.path_join("retroarch").path_join("cores")

func _find_game_art(folder_path: String, filename: String, system: Dictionary) -> String:
    var raw_stem := filename.get_basename()
    var compound_stem := raw_stem
    for compound_suffix in [".nkit", ".rvz", ".iso"]:
        if compound_stem.to_lower().ends_with(compound_suffix):
            compound_stem = compound_stem.substr(0, compound_stem.length() - compound_suffix.length())
    var stems: Array[String] = [raw_stem]
    if compound_stem != raw_stem:
        stems.append(compound_stem)
    for subfolder in ["", "covers", "media", "artwork"]:
        var art_folder := folder_path if subfolder.is_empty() else folder_path.path_join(subfolder)
        for stem in stems:
            var sidecar := _first_image_with_stem(art_folder, stem)
            if not sidecar.is_empty():
                return sidecar
    var thumbnail_dbs: Array = system.get("thumbnail_dbs", [])
    var single_thumbnail_db := str(system.get("thumbnail_db", ""))
    if thumbnail_dbs.is_empty() and not single_thumbnail_db.is_empty():
        thumbnail_dbs = [single_thumbnail_db]
    if thumbnail_dbs.is_empty():
        return ""
    var thumbnail_roots: Array[String] = []
    var thumbnail_root := _retroarch_thumbnail_root()
    if not thumbnail_root.is_empty():
        thumbnail_roots.append(thumbnail_root)
    var artwork_pack_root := _artwork_pack_root()
    if not artwork_pack_root.is_empty():
        thumbnail_roots.append(artwork_pack_root)
    var thumbnail_stems: Array[String] = []
    for stem in stems:
        var safe_stem := _safe_thumbnail_name(stem)
        if not thumbnail_stems.has(safe_stem):
            thumbnail_stems.append(safe_stem)
    var short_title := _safe_thumbnail_name(_clean_game_title(filename))
    if not short_title.is_empty() and not thumbnail_stems.has(short_title):
        thumbnail_stems.append(short_title)
    var normalized_title := _artwork_lookup_title(filename)
    for thumbnail_db_value in thumbnail_dbs:
        var database_name := str(thumbnail_db_value)
        for root_path in thumbnail_roots:
            var database_folder := database_name if root_path == thumbnail_root else database_name.replace(" ", "_")
            for thumbnail_type in ["Named_Boxarts", "Named_Titles", "Named_Snaps"]:
                var art_folder := root_path.path_join(database_folder).path_join(thumbnail_type)
                for stem in thumbnail_stems:
                    var cached_art := _first_image_with_stem(art_folder, stem)
                    if not cached_art.is_empty():
                        return cached_art
                var normalized_art := _find_normalized_image(art_folder, normalized_title)
                if not normalized_art.is_empty():
                    return normalized_art
    return ""

func _first_image_with_stem(folder_path: String, stem: String) -> String:
    for image_extension in ["png", "jpg", "jpeg", "webp"]:
        var candidate := folder_path.path_join(stem + "." + image_extension)
        if FileAccess.file_exists(candidate):
            return candidate
    return ""

func _find_folder_art(folder_path: String) -> String:
    if library_settings_store == null or library_settings_store.folder_art_mode() == "disabled":
        return ""
    if not DirAccess.dir_exists_absolute(folder_path):
        return ""
    var image_files: Array[String] = []
    for filename in DirAccess.get_files_at(folder_path):
        if (
            filename.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]
            and filename.get_basename().to_lower() != "wallpaper"
        ):
            image_files.append(filename)
    image_files.sort_custom(func(a: String, b: String) -> bool:
        return a.naturalnocasecmp_to(b) < 0
    )
    for preferred_stem in ["icon", "folder", "cover", "poster"]:
        for filename in image_files:
            if filename.get_basename().to_lower() == preferred_stem:
                return folder_path.path_join(filename)
    if library_settings_store.folder_art_mode() == "named_or_first" and not image_files.is_empty():
        return folder_path.path_join(image_files[0])
    return ""

func _find_folder_wallpaper(folder_path: String) -> String:
    if (
        library_settings_store == null
        or not library_settings_store.folder_wallpapers()
        or not DirAccess.dir_exists_absolute(folder_path)
    ):
        return ""
    var image_files: Array[String] = []
    for filename in DirAccess.get_files_at(folder_path):
        if (
            filename.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]
            and filename.get_basename().to_lower() == "wallpaper"
        ):
            image_files.append(filename)
    image_files.sort_custom(func(a: String, b: String) -> bool:
        return a.naturalnocasecmp_to(b) < 0
    )
    return folder_path.path_join(image_files[0]) if not image_files.is_empty() else ""

func _artwork_lookup_title(filename: String) -> String:
    var title := _clean_game_title(filename)
    var dreamcast_version := title.to_lower().find(" v1.")
    if dreamcast_version < 0:
        dreamcast_version = title.to_lower().find(" v2.")
    if dreamcast_version > 0:
        title = title.left(dreamcast_version)
    return title.strip_edges()

func _find_normalized_image(folder_path: String, title: String) -> String:
    if title.is_empty() or not DirAccess.dir_exists_absolute(folder_path):
        return ""
    var key := _normalized_art_key(title)
    if key.is_empty():
        return ""
    if not artwork_indexes.has(folder_path):
        artwork_indexes[folder_path] = _build_artwork_index(folder_path)
    var index: Dictionary = artwork_indexes[folder_path]
    return str(index.get(key, ""))

func _build_artwork_index(folder_path: String) -> Dictionary:
    var index := {}
    var scores := {}
    var filenames := DirAccess.get_files_at(folder_path)
    for filename in filenames:
        if not filename.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
            continue
        var key := _normalized_art_key(filename.get_basename())
        if key.is_empty():
            continue
        var full_path := folder_path.path_join(filename)
        var score := _artwork_candidate_score(filename)
        if (
            not index.has(key)
            or score < int(scores.get(key, 100000))
            or (
                score == int(scores.get(key, 100000))
                and full_path.naturalnocasecmp_to(str(index[key])) < 0
            )
        ):
            index[key] = full_path
            scores[key] = score
    return index

func _artwork_candidate_score(filename: String) -> int:
    var lower := filename.to_lower()
    var score := 50
    if lower.contains("(usa)"):
        score = 0
    elif lower.contains("(world)"):
        score = 10
    elif lower.contains("(usa,") or lower.contains(", usa)"):
        score = 20
    elif lower.contains("(europe)"):
        score = 30
    elif lower.contains("(japan)"):
        score = 40
    if lower.contains("rev ") or lower.contains("(rev"):
        score += 2
    for less_preferred in [
        "virtual console",
        "gamecube edition",
        "e-reader edition",
        "prototype",
        "demo",
        "[p]",
        "[h",
        "[b",
        "[tr "
    ]:
        if lower.contains(less_preferred):
            score += 100
    return score

func _normalized_art_key(value: String) -> String:
    var stripped := value.strip_edges()
    var tag_start := stripped.find(" (")
    var bracket_start := stripped.find(" [")
    if bracket_start >= 0 and (tag_start < 0 or bracket_start < tag_start):
        tag_start = bracket_start
    if tag_start > 0:
        stripped = stripped.left(tag_start)
    var normalized := ""
    for character in stripped.to_lower():
        var code := character.unicode_at(0)
        if (code >= 48 and code <= 57) or (code >= 97 and code <= 122):
            normalized += character
    return normalized

func _retroarch_thumbnail_root() -> String:
    var config_home := OS.get_environment("XDG_CONFIG_HOME")
    if config_home.is_empty():
        var home_dir := OS.get_environment("HOME")
        if home_dir.is_empty():
            return ""
        config_home = home_dir.path_join(".config")
    return config_home.path_join("retroarch").path_join("thumbnails")

func _artwork_pack_root() -> String:
    var data_home := OS.get_environment("XDG_DATA_HOME")
    if data_home.is_empty():
        var home_dir := OS.get_environment("HOME")
        if home_dir.is_empty():
            return ""
        data_home = home_dir.path_join(".local").path_join("share")
    return data_home.path_join("hearth").path_join("artwork-packs")

func _safe_thumbnail_name(value: String) -> String:
    var safe := value
    for invalid_character in ["&", "*", "/", ":", "\"", "<", ">", "?", "\\", "|"]:
        safe = safe.replace(invalid_character, "_")
    return safe

func _is_library_metadata(filename: String) -> bool:
    return filename.get_extension().to_lower() in ["md", "txt", "nfo", "json", "xml", "jpg", "jpeg", "png", "webp"]

func _unhandled_input(event: InputEvent) -> void:
    if not _can_accept_navigation_input():
        return
    if modal.visible:
        if input_manager.action_pressed(event, "back"):
            modal.visible = false
        get_viewport().set_input_as_handled()
        return
    if library_browser.visible:
        var browser_action := StringName()
        if input_manager.action_pressed(event, "back"):
            browser_action = &"ui_cancel"
        elif input_manager.action_pressed(event, "navigate_up"):
            browser_action = &"ui_up"
        elif input_manager.action_pressed(event, "navigate_down"):
            browser_action = &"ui_down"
        elif input_manager.action_pressed(event, "page_left"):
            browser_action = &"page_prev"
        elif input_manager.action_pressed(event, "page_right"):
            browser_action = &"page_next"
        elif input_manager.action_pressed(event, "navigate_left"):
            browser_action = &"ui_left"
        elif input_manager.action_pressed(event, "navigate_right"):
            browser_action = &"ui_right"
        elif input_manager.action_pressed(event, "select"):
            browser_action = &"ui_accept"
        elif input_manager.action_pressed(event, "home"):
            library_browser.handle_input(&"ui_cancel")
            if library_browser.visible:
                library_browser.handle_input(&"ui_cancel")
            get_viewport().set_input_as_handled()
            return
        if not browser_action.is_empty():
            library_browser.handle_input(browser_action)
            get_viewport().set_input_as_handled()
        return
    if input_settings.visible:
        input_settings.handle_unhandled_input(event)
        get_viewport().set_input_as_handled()
        return
    if library_settings.visible:
        library_settings.handle_unhandled_input(event, input_manager)
        get_viewport().set_input_as_handled()
        return
    if streaming_services.visible:
        streaming_services.handle_unhandled_input(event, input_manager)
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
            _show_menu(
                previous["items"],
                previous["title"],
                previous["path"],
                int(previous["index"]),
                str(previous.get("layout", "carousel"))
            )
        return
    if current_menu_layout == "tile_grid":
        if input_manager.action_pressed(event, "navigate_up"):
            _move_tile_grid(0, -1)
        elif input_manager.action_pressed(event, "navigate_down"):
            _move_tile_grid(0, 1)
        elif input_manager.action_pressed(event, "navigate_left"):
            _move_tile_grid(-1, 0)
        elif input_manager.action_pressed(event, "navigate_right"):
            _move_tile_grid(1, 0)
        elif input_manager.action_pressed(event, "page_left"):
            _select(selected - TILE_GRID_PAGE_SIZE)
        elif input_manager.action_pressed(event, "page_right"):
            _select(selected + TILE_GRID_PAGE_SIZE)
        elif input_manager.action_pressed(event, "select") and selected >= 0 and selected < buttons.size():
            _activate(buttons[selected].get_meta("item", {}), buttons[selected])
        return
    var left: bool = input_manager.action_pressed(event, "navigate_left") or input_manager.action_pressed(event, "page_left")
    var right: bool = input_manager.action_pressed(event, "navigate_right") or input_manager.action_pressed(event, "page_right")
    if left:
        _select(selected - 1)
    elif right:
        _select(selected + 1)
    elif input_manager.action_pressed(event, "select") and selected >= 0 and selected < buttons.size():
        _activate(buttons[selected].get_meta("item", {}), buttons[selected])

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_IN:
        input_rearm_at_msec = Time.get_ticks_msec() + 450

func _can_accept_navigation_input() -> bool:
    return DisplayServer.window_is_focused() and Time.get_ticks_msec() >= input_rearm_at_msec

func _on_input_settings_closed() -> void:
    footer.text = "Returned to Hearth"
    if is_instance_valid(last_button):
        last_button.grab_focus()

func _on_streaming_services_save_requested(enabled_ids: Array[String]) -> void:
    if streaming_service_store.save(enabled_ids):
        call_deferred("_refresh_movies_tv_menu")
    else:
        _show_error(streaming_service_store.last_error)

func _refresh_movies_tv_menu() -> void:
    if not current_menu_path.to_upper().contains("MOVIES & TV"):
        return
    var next_items := _movies_tv_items()
    var manage_index := maxi(0, next_items.size() - 1)
    _show_menu(next_items, "Movies & TV", current_menu_path, manage_index, "tile_grid")

func _on_streaming_services_closed() -> void:
    footer.text = "Returned to Movies & TV"
    if is_instance_valid(last_button):
        last_button.grab_focus()

func _on_library_settings_save_requested(settings: Dictionary) -> void:
    if library_settings_store.save_settings(settings):
        artwork_indexes.clear()
        system_folder_art.clear()
        system_folder_wallpapers.clear()
        footer.text = "Library settings saved"
    else:
        _show_error(library_settings_store.last_error)

func _on_library_settings_closed() -> void:
    if footer.text != "Library settings saved":
        footer.text = "Returned to Hearth"
    if is_instance_valid(last_button):
        last_button.grab_focus()

func _launcher_system_options() -> Array:
    var result: Array = []
    for system_value in systems:
        if not system_value is Dictionary:
            continue
        var system: Dictionary = system_value
        if str(system.get("backend", "")) == "manifest" or str(system.get("core", "")).is_empty():
            continue
        var options: Array = []
        for option_value in _core_options_for_system(system):
            var core_file := str(option_value.get("core", ""))
            options.append({
                "core": core_file,
                "label": str(option_value.get("label", core_file.trim_suffix("_libretro.so"))),
                "installed": not _retroarch_core_path(core_file).is_empty(),
            })
        result.append({
            "id": str(system.get("id", "")),
            "label": str(system.get("label", "System")),
            "default_core": str(system.get("core", "")),
            "default_label": str(system.get("emulator_label", system.get("core", ""))),
            "options": options,
        })
    return result

func _core_options_for_system(system: Dictionary) -> Array:
    var result: Array = []
    var seen: Dictionary = {}
    var configured_options: Array = system.get("core_options", [])
    for option_value in configured_options:
        var option: Dictionary
        if option_value is Dictionary:
            option = option_value
        else:
            option = {"core":str(option_value), "label":str(option_value).trim_suffix("_libretro.so")}
        var core_file := str(option.get("core", ""))
        if core_file.is_empty() or seen.has(core_file):
            continue
        seen[core_file] = true
        result.append(option)
    var default_core := str(system.get("core", ""))
    if not default_core.is_empty() and not seen.has(default_core):
        result.push_front({
            "core": default_core,
            "label": str(system.get("emulator_label", default_core)).trim_prefix("RetroArch • "),
        })
    return result

func _core_for_system(system: Dictionary) -> String:
    var configured_core: String = library_settings_store.core_for(system)
    for option in _core_options_for_system(system):
        if str(option.get("core", "")) == configured_core:
            return configured_core
    return str(system.get("core", ""))

func _item_with_id(source_items: Array, item_id: String) -> Dictionary:
    for item in source_items:
        if item is Dictionary and str(item.get("id", "")) == item_id:
            return item
    return {}

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
        library_activity_store.end_session()
        child_pid = -1
        footer.text = "Returned to Hearth"
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
