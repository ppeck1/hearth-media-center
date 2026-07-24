extends Control

## A lightweight, paged library browser. The launcher owns catalog discovery and
## launching; this overlay only presents the supplied dictionaries.

signal launch_requested(item: Dictionary)
signal closed

const INK := Color("101827")
const PAPER := Color("f3f5f7")
const MUTED := Color("aeb9c8")
const AMBER := Color("f2a93b")
const DRAWER_WIDTH := 320.0
const PAGE_SIZE := 24
const GRID_COLUMNS := 6
const HOME_COLUMNS := 6
const HOME_CARD_LIMIT := 6
const BACKGROUND := preload("res://assets/backgrounds/arcade-attract-v1.png")

var _families: Array = []
var _activity_store: Variant = {}
var _all_games: Array = []
var _current_family: Dictionary = {}
var _current_system: Dictionary = {}
var _drawer_level := 0
var _drawer_items: Array = []
var _drawer_index := 0
var _content_index := 0
var _focus_area := 0 # 0 = drawer, 1 = content
var _page := 0
var _visible_items: Array = []
var _home_rows: Array = []
var _is_open := false
var _built := false
var _texture_cache: Dictionary = {}
var _texture_order: Array[String] = []
var _card_coordinates: Array[Vector2i] = []

var _drawer: PanelContainer
var _drawer_title: Label
var _drawer_list: VBoxContainer
var _content: Control
var _heading: Label
var _subheading: Label
var _cards: Control
var _page_label: Label
var _drawer_buttons: Array[Button] = []
var _card_buttons: Array[Button] = []

## Public test/diagnostic values. These count data and live card nodes, not every
## game in the catalog.
var debug_total_games := 0
var debug_instantiated_cards := 0
var debug_page_count := 0
var debug_view := "closed"

func _ready() -> void:
    _build_ui()
    _built = true
    if _is_open:
        _show_home()
    else:
        visible = false

func open_library(families: Array, activity_store: Variant = {}) -> void:
    _families = families.duplicate(true)
    _activity_store = activity_store
    _all_games = _flatten_games(_families)
    debug_total_games = _all_games.size()
    _is_open = true
    visible = true
    _drawer_level = 0
    _drawer_index = 0
    _focus_area = 0
    if _built:
        _show_home()

func handle_input(action_id: StringName) -> bool:
    if not _is_open or not visible:
        return false
    match String(action_id):
        "ui_cancel":
            if not _current_system.is_empty():
                _drawer_level = 0
                _drawer_index = 0
                _show_home()
            elif _drawer_level == 1:
                _drawer_level = 0
                _drawer_index = _family_drawer_index(_current_family)
                _build_drawer()
                _refresh_focus()
            else:
                _close()
        "ui_up":
            _move_vertical(-1)
        "ui_down":
            _move_vertical(1)
        "ui_left":
            _move_horizontal(-1)
        "ui_right":
            _move_horizontal(1)
        "ui_accept":
            _accept_selection()
        "page_prev":
            _change_page(-1)
        "page_next":
            _change_page(1)
        _:
            return false
    return true

func debug_state() -> Dictionary:
    return {
        "view": debug_view,
        "total_games": debug_total_games,
        "instantiated_cards": debug_instantiated_cards,
        "page": _page,
        "page_count": debug_page_count,
        "texture_cache_size": _texture_cache.size(),
        "drawer_level": _drawer_level,
        "visible_item_count": _visible_items.size(),
        "focus_area": _focus_area,
        "content_index": _content_index,
        "selected_row": _selected_card_coordinate().x,
        "selected_column": _selected_card_coordinate().y,
        "system_id": str(_current_system.get("id", ""))
    }

func _build_ui() -> void:
    var background := TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.texture = BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(INK, 0.76)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(veil)

    _drawer = PanelContainer.new()
    _drawer.position = Vector2.ZERO
    _drawer.size = Vector2(DRAWER_WIDTH, 1080)
    _drawer.add_theme_stylebox_override("panel", _box(Color("111827"), Color("27364c"), 0, 0))
    add_child(_drawer)
    var drawer_margin := MarginContainer.new()
    drawer_margin.add_theme_constant_override("margin_left", 28)
    drawer_margin.add_theme_constant_override("margin_right", 22)
    drawer_margin.add_theme_constant_override("margin_top", 44)
    drawer_margin.add_theme_constant_override("margin_bottom", 34)
    _drawer.add_child(drawer_margin)
    var drawer_column := VBoxContainer.new()
    drawer_column.add_theme_constant_override("separation", 12)
    drawer_margin.add_child(drawer_column)
    var brand := _label("HEARTH", 30, PAPER)
    brand.add_theme_color_override("font_color", AMBER)
    drawer_column.add_child(brand)
    _drawer_title = _label("Library", 18, MUTED)
    drawer_column.add_child(_drawer_title)
    var separator := HSeparator.new()
    separator.custom_minimum_size.y = 16
    drawer_column.add_child(separator)
    _drawer_list = VBoxContainer.new()
    _drawer_list.add_theme_constant_override("separation", 7)
    drawer_column.add_child(_drawer_list)

    _content = Control.new()
    _content.position = Vector2(DRAWER_WIDTH, 0)
    _content.size = Vector2(1600, 1080)
    add_child(_content)
    _heading = _label("My Library", 46, PAPER)
    _heading.position = Vector2(58, 42)
    _heading.size = Vector2(1100, 62)
    _heading.add_theme_constant_override("outline_size", 6)
    _heading.add_theme_color_override("font_outline_color", Color(INK, 0.9))
    _content.add_child(_heading)
    _subheading = _label("", 18, MUTED)
    _subheading.position = Vector2(61, 105)
    _subheading.size = Vector2(1160, 30)
    _content.add_child(_subheading)
    _cards = Control.new()
    _cards.position = Vector2(50, 150)
    _cards.size = Vector2(1500, 850)
    _content.add_child(_cards)
    _page_label = _label("", 17, MUTED)
    _page_label.position = Vector2(1030, 1010)
    _page_label.size = Vector2(500, 28)
    _page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _content.add_child(_page_label)

func _show_home() -> void:
    _current_system = {}
    _page = 0
    _content_index = 0
    debug_view = "home"
    _heading.text = "My Library"
    _subheading.text = "%d games • choose a family, system, or pick up where you left off" % debug_total_games
    _page_label.text = "SELECT  Open    BACK  Close"
    _build_drawer()
    _home_rows = _make_home_rows()
    _visible_items.clear()
    _clear_cards()
    var y := 0.0
    var visible_row := 0
    for row_value in _home_rows:
        var row: Dictionary = row_value
        var row_items: Array = row.get("items", [])
        if row_items.is_empty():
            continue
        var title := _label(str(row.get("title", "Games")), 22, PAPER)
        title.position = Vector2(6, y)
        title.size = Vector2(800, 32)
        _cards.add_child(title)
        y += 38.0
        for column in range(min(HOME_CARD_LIMIT, row_items.size())):
            var item: Dictionary = row_items[column]
            _visible_items.append(item)
            _card_coordinates.append(Vector2i(visible_row, column))
            var card := _make_card(item, Vector2(column * 240.0, y), Vector2(222, 206), _visible_items.size() - 1)
            _cards.add_child(card)
        y += 244.0
        visible_row += 1
    debug_instantiated_cards = _card_buttons.size()
    debug_page_count = 1
    _refresh_focus()

func _show_system(system: Dictionary) -> void:
    _current_system = system
    _page = 0
    _content_index = 0
    _focus_area = 1
    debug_view = "system"
    _heading.text = str(system.get("label", "Games"))
    var games: Array = system.get("children", [])
    _subheading.text = "%d game%s available" % [games.size(), "" if games.size() == 1 else "s"]
    _render_system_page()

func _render_system_page() -> void:
    var games: Array = _current_system.get("children", [])
    debug_page_count = maxi(1, int(ceil(float(games.size()) / float(PAGE_SIZE))))
    _page = clampi(_page, 0, debug_page_count - 1)
    var first := _page * PAGE_SIZE
    var last := mini(first + PAGE_SIZE, games.size())
    _visible_items = games.slice(first, last)
    _content_index = clampi(_content_index, 0, maxi(0, _visible_items.size() - 1))
    _clear_cards()
    for index in range(_visible_items.size()):
        var column := index % GRID_COLUMNS
        var row := index / GRID_COLUMNS
        _card_coordinates.append(Vector2i(row, column))
        var card := _make_card(
            _visible_items[index],
            Vector2(column * 240.0, row * 208.0),
            Vector2(222, 190),
            index
        )
        _cards.add_child(card)
    debug_instantiated_cards = _card_buttons.size()
    _page_label.text = "Page %d of %d    •    SELECT  Play    BACK  Home" % [_page + 1, debug_page_count]
    _refresh_focus()

func _make_home_rows() -> Array:
    var recent: Array = []
    var most_played: Array = []
    var rated: Array = []
    if _activity_store is Object:
        if _activity_store.has_method("recent_games"):
            recent = _activity_store.call("recent_games", _all_games, HOME_CARD_LIMIT)
        if _activity_store.has_method("most_played_games"):
            most_played = _activity_store.call("most_played_games", _all_games, HOME_CARD_LIMIT)
        if _activity_store.has_method("top_rated"):
            rated = _activity_store.call("top_rated", _all_games, HOME_CARD_LIMIT)
    else:
        recent = _ranked_games("last_played", true)
        most_played = _ranked_games("play_seconds", true)
        if most_played.is_empty():
            most_played = _ranked_games("play_count", true)
        rated = _ranked_games("rating", true)
    var rows: Array = []
    if not recent.is_empty():
        rows.append({"title":"Recently Played", "items":recent.slice(0, mini(HOME_CARD_LIMIT, recent.size()))})
    if not most_played.is_empty():
        rows.append({"title":"Most Played", "items":most_played.slice(0, mini(HOME_CARD_LIMIT, most_played.size()))})
    if not rated.is_empty():
        rows.append({"title":"Top Rated", "items":rated.slice(0, mini(HOME_CARD_LIMIT, rated.size()))})
    var already: Dictionary = {}
    for row_value in rows:
        for item_value in row_value.get("items", []):
            already[_item_key(item_value)] = true
    var all_games: Array = []
    for game_value in _all_games:
        if not already.has(_item_key(game_value)):
            all_games.append(game_value)
        if all_games.size() >= HOME_CARD_LIMIT:
            break
    if not all_games.is_empty() or rows.is_empty():
        if all_games.is_empty():
            all_games = _all_games.slice(0, mini(HOME_CARD_LIMIT, _all_games.size()))
        rows.append({"title":"All Games", "items":all_games})
    # Three rows fit the 1080p content area without scrolling.
    return rows.slice(0, mini(3, rows.size()))

func _ranked_games(field: String, descending: bool) -> Array:
    var ranked: Array = []
    for game_value in _all_games:
        var game: Dictionary = game_value
        var activity := _activity_for(game)
        var value := float(activity.get(field, 0))
        if value <= 0.0 and field == "play_seconds":
            value = float(activity.get("playtime", activity.get("seconds_played", 0)))
        if value <= 0.0:
            continue
        ranked.append({"item":game, "score":value})
    ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a.get("score", 0)) > float(b.get("score", 0)) if descending else float(a.get("score", 0)) < float(b.get("score", 0))
    )
    var result: Array = []
    for value in ranked:
        result.append(value["item"])
    return result

func _activity_for(item: Dictionary) -> Dictionary:
    var key := _item_key(item)
    if typeof(_activity_store) == TYPE_DICTIONARY:
        var store: Dictionary = _activity_store
        var value: Variant = store.get(key, store.get(str(item.get("id", "")), {}))
        return value if typeof(value) == TYPE_DICTIONARY else {}
    if _activity_store is Object:
        if _activity_store.has_method("activity_for"):
            var value: Variant = _activity_store.call("activity_for", item)
            return value if typeof(value) == TYPE_DICTIONARY else {}
        if _activity_store.has_method("get_game_activity"):
            var value: Variant = _activity_store.call("get_game_activity", key)
            return value if typeof(value) == TYPE_DICTIONARY else {}
    return {}

func _build_drawer() -> void:
    _drawer_items.clear()
    for child in _drawer_list.get_children():
        child.queue_free()
    _drawer_buttons.clear()
    if _drawer_level == 0:
        _drawer_title.text = "SYSTEM FAMILIES"
        _drawer_items.append({"kind":"home", "label":"Home"})
        for family_value in _families:
            var family: Dictionary = family_value
            _drawer_items.append({"kind":"family", "label":str(family.get("label", "Systems")), "item":family})
    else:
        _drawer_title.text = str(_current_family.get("label", "SYSTEMS")).to_upper()
        _drawer_items.append({"kind":"families", "label":"‹ All families"})
        for system_value in _current_family.get("children", []):
            var system: Dictionary = system_value
            _drawer_items.append({"kind":"system", "label":str(system.get("label", "System")), "item":system})
    _drawer_index = clampi(_drawer_index, 0, maxi(0, _drawer_items.size() - 1))
    for index in range(_drawer_items.size()):
        var entry: Dictionary = _drawer_items[index]
        var button := Button.new()
        button.text = str(entry.get("label", ""))
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size = Vector2(266, 54)
        button.add_theme_font_size_override("font_size", 18)
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_entered.connect(_on_drawer_hover.bind(index))
        button.pressed.connect(_on_drawer_pressed.bind(index))
        _drawer_list.add_child(button)
        _drawer_buttons.append(button)

func _make_card(item: Dictionary, card_position: Vector2, card_size: Vector2, index: int) -> Button:
    var button := Button.new()
    button.position = card_position
    button.size = card_size
    button.focus_mode = Control.FOCUS_NONE
    button.clip_contents = true
    button.add_theme_stylebox_override("normal", _box(Color("162235"), Color("31445f"), 2, 10))
    button.add_theme_stylebox_override("hover", _box(Color("1c2b42"), AMBER, 3, 10))
    button.add_theme_stylebox_override("pressed", _box(Color("23344d"), AMBER, 3, 10))
    button.mouse_entered.connect(_on_card_hover.bind(index))
    button.pressed.connect(_on_card_pressed.bind(index))

    var art := TextureRect.new()
    art.position = Vector2(8, 8)
    art.size = Vector2(card_size.x - 16, card_size.y - 52)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if str(item.get("art_fit", "")) == "contain" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.texture = _load_texture(str(item.get("art", "")))
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(art)
    if art.texture == null:
        var mark := _label(str(item.get("mark", "•")), 34, AMBER)
        mark.position = art.position
        mark.size = art.size
        mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_child(mark)
    var caption := _label(str(item.get("label", "Game")), 15, PAPER)
    caption.position = Vector2(9, card_size.y - 40)
    caption.size = Vector2(card_size.x - 18, 34)
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(caption)
    _card_buttons.append(button)
    return button

func _load_texture(path: String) -> Texture2D:
    if path.is_empty():
        return null
    if _texture_cache.has(path):
        _texture_order.erase(path)
        _texture_order.append(path)
        return _texture_cache[path]
    var texture: Texture2D
    if path.begins_with("res://"):
        texture = load(path) as Texture2D
    elif FileAccess.file_exists(path):
        var image := Image.load_from_file(path)
        if not image.is_empty():
            var longest_side := maxi(image.get_width(), image.get_height())
            if longest_side > 512:
                var scale := 512.0 / float(longest_side)
                image.resize(
                    maxi(1, int(round(image.get_width() * scale))),
                    maxi(1, int(round(image.get_height() * scale))),
                    Image.INTERPOLATE_LANCZOS
                )
            texture = ImageTexture.create_from_image(image)
    _texture_cache[path] = texture
    _texture_order.append(path)
    while _texture_order.size() > 64:
        var oldest: String = _texture_order.pop_front()
        _texture_cache.erase(oldest)
    return texture

func _clear_cards() -> void:
    for child in _cards.get_children():
        child.queue_free()
    _card_buttons.clear()
    _card_coordinates.clear()

func _move_vertical(direction: int) -> void:
    if _focus_area == 0:
        _drawer_index = clampi(_drawer_index + direction, 0, maxi(0, _drawer_items.size() - 1))
    elif debug_view == "home":
        var coordinate := _selected_card_coordinate()
        var target_index := _home_index_nearest_column(coordinate.x + direction, coordinate.y)
        if target_index >= 0:
            _content_index = target_index
    else:
        var next := _content_index + direction * GRID_COLUMNS
        if next >= 0 and next < _visible_items.size():
            _content_index = next
    _refresh_focus()

func _move_horizontal(direction: int) -> void:
    if _focus_area == 0:
        if direction > 0 and not _visible_items.is_empty():
            _focus_area = 1
            _content_index = clampi(_content_index, 0, _visible_items.size() - 1)
    else:
        var columns := HOME_COLUMNS if debug_view == "home" else GRID_COLUMNS
        var column := _selected_card_coordinate().y if debug_view == "home" else _content_index % columns
        if direction < 0 and column == 0:
            if debug_view == "system" and _page > 0:
                _page -= 1
                _content_index = PAGE_SIZE - 1
                _render_system_page()
                return
            _focus_area = 0
        elif direction > 0 and _content_index == _visible_items.size() - 1 and debug_view == "system" and _page + 1 < debug_page_count:
            _page += 1
            _content_index = 0
            _render_system_page()
            return
        elif debug_view == "home":
            var target_index := _home_index_at(_selected_card_coordinate().x, column + direction)
            if target_index >= 0:
                _content_index = target_index
        elif direction > 0 and column < columns - 1 and _content_index + 1 < _visible_items.size():
            _content_index += 1
        elif direction < 0 and column > 0:
            _content_index -= 1
    _refresh_focus()

func _change_page(direction: int) -> void:
    if debug_view != "system" or direction == 0:
        return
    var next_page := clampi(_page + direction, 0, debug_page_count - 1)
    if next_page == _page:
        return
    _page = next_page
    _render_system_page()

func _selected_card_coordinate() -> Vector2i:
    if _content_index < 0 or _content_index >= _card_coordinates.size():
        return Vector2i.ZERO
    return _card_coordinates[_content_index]

func _home_index_at(row: int, column: int) -> int:
    for index in range(_card_coordinates.size()):
        if _card_coordinates[index] == Vector2i(row, column):
            return index
    return -1

func _home_index_nearest_column(row: int, column: int) -> int:
    var best_index := -1
    var best_distance := 1000000
    for index in range(_card_coordinates.size()):
        var coordinate := _card_coordinates[index]
        if coordinate.x != row:
            continue
        var distance := absi(coordinate.y - column)
        if distance < best_distance:
            best_distance = distance
            best_index = index
    return best_index

func _family_drawer_index(family: Dictionary) -> int:
    var family_id := str(family.get("id", ""))
    for index in range(_families.size()):
        if str(_families[index].get("id", "")) == family_id:
            return index + 1 # Home occupies drawer index zero.
    return 0

func _accept_selection() -> void:
    if _focus_area == 1:
        if not _visible_items.is_empty():
            launch_requested.emit(_visible_items[clampi(_content_index, 0, _visible_items.size() - 1)])
        return
    if _drawer_items.is_empty():
        return
    var entry: Dictionary = _drawer_items[_drawer_index]
    match str(entry.get("kind", "")):
        "home":
            _show_home()
        "family":
            _current_family = entry.get("item", {})
            _drawer_level = 1
            _drawer_index = 0
            _build_drawer()
            _refresh_focus()
        "families":
            _drawer_level = 0
            _drawer_index = 0
            _build_drawer()
            _refresh_focus()
        "system":
            _show_system(entry.get("item", {}))

func _refresh_focus() -> void:
    for index in range(_drawer_buttons.size()):
        var selected := _focus_area == 0 and index == _drawer_index
        _drawer_buttons[index].add_theme_stylebox_override(
            "normal",
            _box(Color("f3f5f7") if selected else Color("111827"), AMBER if selected else Color("27364c"), 2 if selected else 0, 8)
        )
        _drawer_buttons[index].add_theme_color_override("font_color", INK if selected else MUTED)
    for index in range(_card_buttons.size()):
        var selected := _focus_area == 1 and index == _content_index
        _card_buttons[index].add_theme_stylebox_override(
            "normal",
            _box(Color("1c2b42"), AMBER if selected else Color("31445f"), 4 if selected else 2, 10)
        )

func _on_drawer_hover(index: int) -> void:
    _focus_area = 0
    _drawer_index = index
    _refresh_focus()

func _on_drawer_pressed(index: int) -> void:
    _on_drawer_hover(index)
    _accept_selection()

func _on_card_hover(index: int) -> void:
    _focus_area = 1
    _content_index = index
    _refresh_focus()

func _on_card_pressed(index: int) -> void:
    _on_card_hover(index)
    _accept_selection()

func _close() -> void:
    _is_open = false
    visible = false
    debug_view = "closed"
    closed.emit()

func _flatten_games(family_values: Array) -> Array:
    var result: Array = []
    for family_value in family_values:
        if typeof(family_value) != TYPE_DICTIONARY:
            continue
        for system_value in family_value.get("children", []):
            if typeof(system_value) != TYPE_DICTIONARY:
                continue
            for game_value in system_value.get("children", []):
                if typeof(game_value) == TYPE_DICTIONARY:
                    result.append(game_value)
    return result

func _item_key(item: Dictionary) -> String:
    var rom_path := str(item.get("rom_path", ""))
    if not rom_path.is_empty():
        return rom_path
    return str(item.get("id", item.get("label", "")))

func _label(text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = border
    box.set_border_width_all(width)
    box.set_corner_radius_all(radius)
    return box
