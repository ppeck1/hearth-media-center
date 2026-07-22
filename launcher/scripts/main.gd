extends Control

const INK := Color("101827")
const SLATE := Color("31445f")
const AMBER := Color("f2a93b")
const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const MENU_PATH := "res://config/menu.json"
const REGISTRY_PATH := "res://config/system-registry.json"
const LIBRARY_ROOT := "/srv/library/games/roms"
const HOME_BACKGROUND := preload("res://assets/backgrounds/arcade-living-room-v1.png")
const ARCADE_BACKGROUND_PATH := "res://assets/backgrounds/arcade-attract-v1.png"
const VIDEO_CLUB_BACKGROUND_PATH := "res://assets/backgrounds/video-club-aisle-v1.png"
const CONSOLE_GALLERY_BACKGROUND_PATH := "res://assets/backgrounds/console-gallery-v1.png"
const ArcadeFx := preload("res://scripts/arcade_fx.gd")

var background: TextureRect
var veil: ColorRect
var arcade_fx: Control
var stage: Control
var heading: Label
var breadcrumb: Label
var detail: Label
var footer: Label
var marquee: Label
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

func _ready() -> void:
    _build_ui()
    _load_registry()
    _load_home()

func _build_ui() -> void:
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
    marquee = _label(Vector2(92, 28), Vector2(1120, 30), 18, AMBER)
    marquee.text = "HEARTH  //  LIVING ROOM"
    marquee.add_theme_constant_override("outline_size", 4)
    marquee.add_theme_color_override("font_outline_color", Color(INK, 0.92))
    add_child(marquee)
    collection_label = _label(Vector2(1240, 28), Vector2(580, 30), 18, PAPER)
    collection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    collection_label.visible = false
    collection_label.add_theme_constant_override("outline_size", 4)
    collection_label.add_theme_color_override("font_outline_color", Color(INK, 0.92))
    add_child(collection_label)
    breadcrumb = _label(Vector2(92, 58), Vector2(1700, 28), 18, AMBER)
    add_child(breadcrumb)
    heading = _label(Vector2(88, 86), Vector2(1740, 72), 58, PAPER)
    add_child(heading)
    heading.add_theme_constant_override("outline_size", 8)
    heading.add_theme_color_override("font_outline_color", Color(INK, 0.85))
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
    _show_menu(parsed["items"], str(parsed.get("title", "Welcome home")), "HEARTH  •  LIVING ROOM")

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
    heading.text = title
    breadcrumb.text = path
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
    var base := Color(SLATE, 0.93).lerp(Color(accent, 0.94), 0.32)
    card.add_theme_stylebox_override("normal", _box(base, Color(accent, 0.78), 2, 22, Color(accent, 0.20), 15))
    card.add_theme_stylebox_override("focus", _box(Color(base, 1.0), AMBER, 6, 22, Color(accent, 0.52), 34))
    card.add_theme_stylebox_override("hover", _box(Color(base, 1.0), Color(accent, 1.0), 5, 22, Color(accent, 0.42), 26))
    card.pressed.connect(_activate.bind(item, card))
    card.focus_entered.connect(_focus_card.bind(card))
    stage.add_child(card)
    var visual_root := Control.new()
    visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual_root.clip_contents = true
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
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if str(item.get("art_fit", "contain")) == "cover" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.modulate = Color(1.0, 1.0, 1.0, 0.96)
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        box.add_child(art)
        card.set_meta("art_node", art)
    else:
        var mark := Label.new()
        mark.text = str(item.get("mark", "•"))
        mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
        mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        mark.add_theme_font_size_override("font_size", 86)
        mark.add_theme_color_override("font_color", Color(accent, 1.0))
        mark.add_theme_constant_override("outline_size", 5)
        mark.add_theme_color_override("font_outline_color", Color(INK, 0.95))
        box.add_child(mark)
        card.set_meta("art_node", mark)
    var name := Label.new()
    name.text = str(item.get("label", "Item"))
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name.add_theme_font_size_override("font_size", 30)
    name.add_theme_color_override("font_color", PAPER)
    name.add_theme_constant_override("outline_size", 3)
    name.add_theme_color_override("font_outline_color", Color(INK, 0.88))
    box.add_child(name)
    card.set_meta("name_label", name)
    if item.has("count_label"):
        var count := Label.new()
        count.text = str(item.get("count_label", ""))
        count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        count.add_theme_font_size_override("font_size", 20)
        count.add_theme_color_override("font_color", AMBER)
        box.add_child(count)
        card.set_meta("count_label_node", count)

    # Fine horizontal phosphor lines give every card a shared CRT-era finish.
    # They are deliberately subtle so logos and game art remain legible.
    for line_index in range(9):
        var scanline := ColorRect.new()
        scanline.color = Color(0.20, 0.90, 1.0, 0.030)
        scanline.set_anchors_preset(Control.PRESET_TOP_WIDE)
        scanline.anchor_top = 0.10 + float(line_index) * 0.105
        scanline.anchor_bottom = scanline.anchor_top
        scanline.offset_bottom = 1.0
        scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
        visual_root.add_child(scanline)

    var neon_rail := ColorRect.new()
    neon_rail.color = Color(accent, 0.72)
    neon_rail.set_anchors_preset(Control.PRESET_TOP_WIDE)
    neon_rail.offset_left = 20
    neon_rail.offset_right = -20
    neon_rail.offset_top = 8
    neon_rail.offset_bottom = 11
    neon_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual_root.add_child(neon_rail)
    buttons.append(card)

func _focus_card(card: Button) -> void:
    _select(int(card.get_meta("index", 0)))

func _select(index: int, immediate := false) -> void:
    if buttons.is_empty():
        return
    selected = clampi(index, 0, buttons.size() - 1)
    var focus_item: Dictionary = buttons[selected].get_meta("item", {})
    detail.text = str(focus_item.get("subtitle", ""))
    selection_label.text = "—  %s  —" % str(focus_item.get("hint", "Choose your next adventure"))
    arcade_fx.set_accent(Color(str(focus_item.get("color", "f2a93b"))))
    footer.text = "D-PAD / LEFT STICK: BROWSE     X: SELECT     O: BACK     %s" % str(focus_item.get("hint", ""))
    for card in buttons:
        var offset: int = int(card.get_meta("index", 0)) - selected
        var distance: int = absi(offset)
        var previous_tween: Tween = card_tweens.get(card)
        if previous_tween != null and previous_tween.is_valid():
            previous_tween.kill()
        var show_card := distance <= 1
        if not show_card:
            # Stage hidden cards just beyond the screen. A newly revealed
            # neighbour now glides in from the rail instead of expanding from
            # Godot's zero-size, top-left default state.
            var staged_size := Vector2(226.0, 172.0)
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
            size_value = Vector2(520, 352)
        elif distance == 1:
            size_value = Vector2(292, 220)
            center_x += float(offset) * 490.0
        else:
            size_value = Vector2(226, 172)
            center_x += float(offset) * 800.0
        var center_y := 572.0 + float(distance) * 14.0
        var position_value := Vector2(center_x - size_value.x * 0.5, center_y - size_value.y * 0.5)
        var rotation_value := 0.0 if selected_card else float(offset) * -0.018
        card.pivot_offset = size_value * 0.5
        card.z_index = 10 - distance
        _set_card_typography(card, selected_card, distance)
        if immediate:
            card.position = position_value
            card.size = size_value
            card.rotation = rotation_value
            card.modulate.a = 1.0 if selected_card else 0.64
        else:
            var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            card_tweens[card] = tween
            tween.tween_property(card, "position", position_value, 0.24)
            tween.tween_property(card, "size", size_value, 0.24)
            tween.tween_property(card, "rotation", rotation_value, 0.22)
            tween.tween_property(card, "modulate:a", 1.0 if selected_card else 0.58 if distance == 1 else 0.36, 0.18)
    buttons[selected].grab_focus()

func _set_card_typography(card: Button, selected_card: bool, distance: int) -> void:
    var name_label: Label = card.get_meta("name_label", null)
    if name_label != null:
        name_label.add_theme_font_size_override("font_size", 28 if selected_card else 22 if distance == 1 else 17)
    var brand_label: Label = card.get_meta("brand_label") if card.has_meta("brand_label") else null
    if brand_label != null:
        brand_label.visible = selected_card
        brand_label.add_theme_font_size_override("font_size", 16 if selected_card else 12)
    var count_label_node: Label = card.get_meta("count_label_node") if card.has_meta("count_label_node") else null
    if count_label_node != null:
        count_label_node.add_theme_font_size_override("font_size", 18 if selected_card else 14 if distance == 1 else 12)
    var art_node: Control = card.get_meta("art_node", null)
    if art_node != null:
        art_node.custom_minimum_size.y = 180.0 if selected_card and brand_label != null else 205.0 if selected_card else 105.0 if distance == 1 else 74.0
        art_node.modulate.a = 1.0 if selected_card else 0.86 if distance == 1 else 0.64

func _set_visual_mode(in_library: bool, next_items: Array) -> void:
    var in_streaming := breadcrumb.text.to_upper().contains("STREAMING")
    var showcase_mode := in_library or in_streaming
    if in_streaming:
        background.texture = load(VIDEO_CLUB_BACKGROUND_PATH)
    elif in_library:
        background.texture = load(ARCADE_BACKGROUND_PATH) if breadcrumb.text.ends_with("MY LIBRARY") else load(CONSOLE_GALLERY_BACKGROUND_PATH)
    else:
        background.texture = HOME_BACKGROUND
    veil.color = Color(INK, 0.47 if showcase_mode else 0.60)
    arcade_fx.set_arcade_mode(showcase_mode)
    collection_label.visible = showcase_mode
    selection_label.visible = showcase_mode
    if in_streaming:
        marquee.text = "HEARTH  //  VIDEO CLUB"
        collection_label.text = "%d SERVICES READY" % next_items.size()
    elif in_library:
        marquee.text = "HEARTH  //  ARCADE VAULT"
        var total_games := 0
        for item in next_items:
            if typeof(item) == TYPE_DICTIONARY:
                total_games += int(item.get("game_count", 0))
        if total_games == 0:
            for item in next_items:
                if typeof(item) == TYPE_DICTIONARY and str(item.get("type", "")) in ["command", "unavailable"]:
                    total_games += 1
        collection_label.text = "%d GAMES ONLINE" % total_games if total_games > 0 else "ARCADE LINK ACTIVE"
    else:
        marquee.text = "HEARTH  //  LIVING ROOM"

func _activate(item: Dictionary, card: Button) -> void:
    last_button = card
    var kind := str(item.get("type", ""))
    if kind == "library":
        var systems := _library_systems()
        if systems.is_empty():
            _show_error("No ROMs found. Add game files under /srv/library/games/roms, then reopen Games.")
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
    return {"id":str(system.get("id", "system")),"label":str(system.get("label", "System")),"subtitle":"%d game%s • %s" % [count, "" if count == 1 else "s", str(system.get("emulator_label", "RetroArch"))],"count_label":"%d game%s" % [count, "" if count == 1 else "s"],"game_count":count,"art":art_path,"art_fit":"cover" if not art_path.is_empty() else "contain","hint":"Choose a game","mark":str(system.get("mark", "•")),"color":str(system.get("color", "426d8d")),"type":"submenu","children":games,"enabled":true}

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
