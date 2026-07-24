class_name HearthLibraryActivityStore
extends RefCounted

## Privacy-local library activity reader.
##
## This store reads only RetroArch's files on disk plus Hearth's optional local
## ratings file. It never performs network requests or publishes catalog data.

const RATINGS_SCHEMA_VERSION := 1

var history_path: String
var runtime_logs_path: String
var ratings_path: String
var last_error := ""

var _loaded := false
var _history_paths: Array[String] = []
var _runtime_entries: Array[Dictionary] = []
var _rating_entries: Array[Dictionary] = []
var _local_activity_entries: Array[Dictionary] = []
var _local_document: Dictionary = {}
var _active_selector := ""
var _active_started_msec := 0


func _init(
		history_path_override: String = "",
		runtime_logs_path_override: String = "",
		ratings_path_override: String = ""
) -> void:
	history_path = history_path_override if not history_path_override.is_empty() else default_history_path()
	runtime_logs_path = runtime_logs_path_override if not runtime_logs_path_override.is_empty() else default_runtime_logs_path()
	ratings_path = ratings_path_override if not ratings_path_override.is_empty() else "user://library-activity.json"


func reload() -> bool:
	last_error = ""
	_history_paths.clear()
	_runtime_entries.clear()
	_rating_entries.clear()
	_local_activity_entries.clear()
	_local_document = {
		"schema_version": RATINGS_SCHEMA_VERSION,
		"ratings": {},
		"games": {},
	}

	var errors: Array[String] = []
	if FileAccess.file_exists(history_path):
		var history = _read_json(history_path)
		if not history is Dictionary:
			errors.append("RetroArch history is not valid JSON.")
		else:
			for item in history.get("items", []):
				if not item is Dictionary:
					continue
				var content_path := str(item.get("path", "")).strip_edges()
				if not content_path.is_empty():
					_history_paths.append(content_path)

	if DirAccess.dir_exists_absolute(runtime_logs_path):
		var log_paths: Array[String] = []
		_collect_files_recursive(runtime_logs_path, ".lrtl", log_paths)
		for log_path in log_paths:
			var log = _read_json(log_path)
			if not log is Dictionary:
				errors.append("Skipped invalid runtime log: %s" % log_path.get_file())
				continue
			var selector := _remove_last_extension(log_path.get_file())
			if selector.is_empty():
				continue
			_runtime_entries.append({
				"selector": selector,
				"runtime_seconds": _runtime_to_seconds(str(log.get("runtime", ""))),
				"play_count": maxi(0, int(str(log.get("play_count", "0")))),
				"last_played": str(log.get("last_played", "")).strip_edges(),
			})

	if FileAccess.file_exists(ratings_path):
		var ratings_document = _read_json(ratings_path)
		if not ratings_document is Dictionary:
			errors.append("Hearth's local ratings file is not valid JSON.")
		else:
			_local_document = ratings_document
			_load_ratings(ratings_document)
			_load_local_activity(ratings_document)

	_loaded = true
	last_error = " ".join(errors)
	return errors.is_empty()


func begin_session(game: Dictionary) -> bool:
	if not _loaded:
		reload()
	var selector := _selector_for_game(game)
	if selector.is_empty():
		last_error = "This library item has no stable local activity identifier."
		return false
	if not _active_selector.is_empty():
		end_session()
	_active_selector = selector
	_active_started_msec = Time.get_ticks_msec()
	var entry := _local_game_entry(selector)
	entry["play_count"] = int(entry.get("play_count", 0)) + 1
	entry["last_played"] = _now_string()
	_set_local_game_entry(selector, entry)
	return _save_local_document()


func end_session(elapsed_seconds_override: int = -1) -> bool:
	if _active_selector.is_empty():
		return false
	var selector := _active_selector
	var elapsed_seconds := elapsed_seconds_override
	if elapsed_seconds < 0:
		elapsed_seconds = maxi(0, int((Time.get_ticks_msec() - _active_started_msec) / 1000))
	_active_selector = ""
	_active_started_msec = 0
	var entry := _local_game_entry(selector)
	entry["runtime_seconds"] = int(entry.get("runtime_seconds", 0)) + elapsed_seconds
	_set_local_game_entry(selector, entry)
	return _save_local_document()


func record_launch(game: Dictionary) -> bool:
	if not begin_session(game):
		return false
	return end_session(0)


func recent_games(catalog: Array, limit: int = 12) -> Array:
	var activity := _activity_for_catalog(catalog)
	var ranked: Array[Dictionary] = []
	for index in activity:
		var stats: Dictionary = activity[index]
		if int(stats.get("history_rank", -1)) < 0 and str(stats.get("last_played", "")).is_empty():
			continue
		ranked.append({"index": int(index), "stats": stats})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_stats: Dictionary = left["stats"]
		var right_stats: Dictionary = right["stats"]
		var left_date := str(left_stats.get("last_played", ""))
		var right_date := str(right_stats.get("last_played", ""))
		if left_date != right_date and (not left_date.is_empty() or not right_date.is_empty()):
			if left_date.is_empty():
				return false
			if right_date.is_empty():
				return true
			return left_date > right_date
		var left_rank := int(left_stats.get("history_rank", -1))
		var right_rank := int(right_stats.get("history_rank", -1))
		if left_rank >= 0 or right_rank >= 0:
			if left_rank < 0:
				return false
			if right_rank < 0:
				return true
			if left_rank != right_rank:
				return left_rank < right_rank
		return int(left["index"]) < int(right["index"])
	)
	return _catalog_results(catalog, ranked, limit)


func most_played_games(catalog: Array, limit: int = 12) -> Array:
	var activity := _activity_for_catalog(catalog)
	var ranked: Array[Dictionary] = []
	for index in activity:
		var stats: Dictionary = activity[index]
		if int(stats.get("runtime_seconds", 0)) <= 0 and int(stats.get("play_count", 0)) <= 0:
			continue
		ranked.append({"index": int(index), "stats": stats})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_stats: Dictionary = left["stats"]
		var right_stats: Dictionary = right["stats"]
		var left_runtime := int(left_stats.get("runtime_seconds", 0))
		var right_runtime := int(right_stats.get("runtime_seconds", 0))
		if left_runtime != right_runtime:
			return left_runtime > right_runtime
		var left_count := int(left_stats.get("play_count", 0))
		var right_count := int(right_stats.get("play_count", 0))
		if left_count != right_count:
			return left_count > right_count
		return str(left_stats.get("last_played", "")) > str(right_stats.get("last_played", ""))
	)
	return _catalog_results(catalog, ranked, limit)


func top_rated(catalog: Array, limit: int = 12) -> Array:
	var activity := _activity_for_catalog(catalog)
	var ranked: Array[Dictionary] = []
	for index in activity:
		var stats: Dictionary = activity[index]
		if float(stats.get("rating", 0.0)) <= 0.0:
			continue
		ranked.append({"index": int(index), "stats": stats})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_stats: Dictionary = left["stats"]
		var right_stats: Dictionary = right["stats"]
		var left_rating := float(left_stats.get("rating", 0.0))
		var right_rating := float(right_stats.get("rating", 0.0))
		if not is_equal_approx(left_rating, right_rating):
			return left_rating > right_rating
		return int(left_stats.get("runtime_seconds", 0)) > int(right_stats.get("runtime_seconds", 0))
	)
	return _catalog_results(catalog, ranked, limit)


static func default_history_path() -> String:
	return _retroarch_config_root().path_join("playlists").path_join("builtin").path_join("content_history.lpl")


static func default_runtime_logs_path() -> String:
	return _retroarch_config_root().path_join("playlists").path_join("logs")


static func _retroarch_config_root() -> String:
	var config_root := OS.get_environment("XDG_CONFIG_HOME")
	if config_root.is_empty():
		var home := OS.get_environment("HOME")
		if not home.is_empty():
			config_root = home.path_join(".config")
	if config_root.is_empty():
		config_root = ProjectSettings.globalize_path("user://")
	return config_root.path_join("retroarch")


func _activity_for_catalog(catalog: Array) -> Dictionary:
	if not _loaded:
		reload()
	var indexes := _catalog_indexes(catalog)
	var activity: Dictionary = {}

	for history_rank in range(_history_paths.size()):
		var catalog_index := _match_catalog_index(_history_paths[history_rank], indexes)
		if catalog_index < 0:
			continue
		var stats := _stats_for(activity, catalog_index)
		var existing_rank := int(stats.get("history_rank", -1))
		if existing_rank < 0 or history_rank < existing_rank:
			stats["history_rank"] = history_rank
		activity[catalog_index] = stats

	for runtime_entry in _runtime_entries:
		var catalog_index := _match_catalog_index(str(runtime_entry.get("selector", "")), indexes)
		if catalog_index < 0:
			continue
		var stats := _stats_for(activity, catalog_index)
		stats["runtime_seconds"] = int(stats.get("runtime_seconds", 0)) + int(runtime_entry.get("runtime_seconds", 0))
		stats["play_count"] = int(stats.get("play_count", 0)) + int(runtime_entry.get("play_count", 0))
		var last_played := str(runtime_entry.get("last_played", ""))
		if last_played > str(stats.get("last_played", "")):
			stats["last_played"] = last_played
		activity[catalog_index] = stats

	for local_entry in _local_activity_entries:
		var catalog_index := _match_catalog_index(str(local_entry.get("selector", "")), indexes)
		if catalog_index < 0:
			continue
		var stats := _stats_for(activity, catalog_index)
		# RetroArch and Hearth observe the same console session. These are
		# cumulative fallback counters, so using the greater total avoids
		# double-counting while still covering native PC games.
		stats["runtime_seconds"] = maxi(
			int(stats.get("runtime_seconds", 0)),
			int(local_entry.get("runtime_seconds", 0))
		)
		stats["play_count"] = maxi(
			int(stats.get("play_count", 0)),
			int(local_entry.get("play_count", 0))
		)
		var last_played := str(local_entry.get("last_played", ""))
		if last_played > str(stats.get("last_played", "")):
			stats["last_played"] = last_played
		activity[catalog_index] = stats

	for rating_entry in _rating_entries:
		var catalog_index := _match_catalog_index(str(rating_entry.get("selector", "")), indexes)
		if catalog_index < 0:
			continue
		var stats := _stats_for(activity, catalog_index)
		stats["rating"] = float(rating_entry.get("rating", 0.0))
		activity[catalog_index] = stats

	return activity


func _catalog_indexes(catalog: Array) -> Dictionary:
	var exact_path: Dictionary = {}
	var exact_id: Dictionary = {}
	var basenames: Dictionary = {}
	var stems: Dictionary = {}
	for index in range(catalog.size()):
		if not catalog[index] is Dictionary:
			continue
		var game: Dictionary = catalog[index]
		var rom_path := str(game.get("rom_path", "")).strip_edges()
		var game_id := str(game.get("id", "")).strip_edges()
		if not rom_path.is_empty():
			exact_path[rom_path] = index
			_add_index(basenames, rom_path.get_file(), index)
			_add_index(stems, _remove_last_extension(rom_path.get_file()), index)
		if not game_id.is_empty():
			exact_id[game_id] = index
	return {
		"exact_path": exact_path,
		"exact_id": exact_id,
		"basenames": basenames,
		"stems": stems,
	}


func _match_catalog_index(selector: String, indexes: Dictionary) -> int:
	if selector.is_empty():
		return -1
	var exact_path: Dictionary = indexes["exact_path"]
	if exact_path.has(selector):
		return int(exact_path[selector])
	var exact_id: Dictionary = indexes["exact_id"]
	if exact_id.has(selector):
		return int(exact_id[selector])

	var filename := selector.get_file()
	var basenames: Dictionary = indexes["basenames"]
	var basename_matches: Array = basenames.get(filename, [])
	if basename_matches.size() == 1:
		return int(basename_matches[0])

	var stems: Dictionary = indexes["stems"]
	var direct_stem_matches: Array = stems.get(filename, [])
	if direct_stem_matches.size() == 1:
		return int(direct_stem_matches[0])

	var stem := _remove_last_extension(filename)
	var stem_matches: Array = stems.get(stem, [])
	if stem_matches.size() == 1:
		return int(stem_matches[0])
	return -1


func _catalog_results(catalog: Array, ranked: Array[Dictionary], limit: int) -> Array:
	var results: Array = []
	if limit <= 0:
		return results
	for ranked_item in ranked:
		if results.size() >= limit:
			break
		var index := int(ranked_item.get("index", -1))
		if index < 0 or index >= catalog.size() or not catalog[index] is Dictionary:
			continue
		var game: Dictionary = catalog[index].duplicate(true)
		var stats: Dictionary = ranked_item.get("stats", {}).duplicate(true)
		game["activity"] = stats
		game["runtime_seconds"] = int(stats.get("runtime_seconds", 0))
		game["play_count"] = int(stats.get("play_count", 0))
		game["last_played"] = str(stats.get("last_played", ""))
		if stats.has("rating"):
			game["rating"] = float(stats["rating"])
		results.append(game)
	return results


func _stats_for(activity: Dictionary, catalog_index: int) -> Dictionary:
	return activity.get(catalog_index, {
		"history_rank": -1,
		"runtime_seconds": 0,
		"play_count": 0,
		"last_played": "",
	})


func _load_ratings(document: Dictionary) -> void:
	var ratings = document.get("ratings", {})
	if ratings is Dictionary:
		for selector in ratings:
			var rating_value = ratings[selector]
			if rating_value is Dictionary:
				rating_value = rating_value.get("rating", 0.0)
			_append_rating(str(selector), rating_value)
	elif ratings is Array:
		for item in ratings:
			if not item is Dictionary:
				continue
			var selector := str(item.get("rom_path", item.get("path", item.get("id", ""))))
			_append_rating(selector, item.get("rating", 0.0))


func _load_local_activity(document: Dictionary) -> void:
	var games = document.get("games", {})
	if not games is Dictionary:
		return
	for selector in games:
		var value = games[selector]
		if not value is Dictionary:
			continue
		_local_activity_entries.append({
			"selector": str(selector),
			"runtime_seconds": maxi(0, int(value.get("runtime_seconds", 0))),
			"play_count": maxi(0, int(value.get("play_count", 0))),
			"last_played": str(value.get("last_played", "")).strip_edges(),
		})


func _selector_for_game(game: Dictionary) -> String:
	var rom_path := str(game.get("rom_path", "")).strip_edges()
	if not rom_path.is_empty():
		return rom_path
	return str(game.get("id", "")).strip_edges()


func _local_game_entry(selector: String) -> Dictionary:
	var games = _local_document.get("games", {})
	if not games is Dictionary:
		return {}
	var entry = games.get(selector, {})
	return entry.duplicate(true) if entry is Dictionary else {}


func _set_local_game_entry(selector: String, entry: Dictionary) -> void:
	var games = _local_document.get("games", {})
	if not games is Dictionary:
		games = {}
	games[selector] = entry
	_local_document["schema_version"] = RATINGS_SCHEMA_VERSION
	_local_document["games"] = games
	_load_local_activity(_local_document)
	_deduplicate_local_activity()


func _deduplicate_local_activity() -> void:
	var by_selector: Dictionary = {}
	for entry in _local_activity_entries:
		by_selector[str(entry.get("selector", ""))] = entry
	_local_activity_entries.clear()
	for selector in by_selector:
		_local_activity_entries.append(by_selector[selector])


func _save_local_document() -> bool:
	var absolute_path := ProjectSettings.globalize_path(ratings_path)
	var parent := absolute_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		last_error = "Hearth could not create its local activity folder."
		return false
	var temporary_path := absolute_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Hearth could not write its local activity file."
		return false
	file.store_string(JSON.stringify(_local_document, "  ") + "\n")
	file.close()
	if FileAccess.file_exists(absolute_path):
		var backup_path := absolute_path + ".backup"
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(absolute_path, backup_path) != OK:
			last_error = "Hearth could not safely replace its local activity file."
			DirAccess.remove_absolute(temporary_path)
			return false
		if DirAccess.rename_absolute(temporary_path, absolute_path) == OK:
			DirAccess.remove_absolute(backup_path)
			last_error = ""
			return true
		DirAccess.rename_absolute(backup_path, absolute_path)
		last_error = "Hearth could not finish saving its local activity file."
		return false
	if DirAccess.rename_absolute(temporary_path, absolute_path) != OK:
		last_error = "Hearth could not finish saving its local activity file."
		return false
	last_error = ""
	return true


func _now_string() -> String:
	return Time.get_datetime_string_from_system(false, true).replace("T", " ")


func _append_rating(selector: String, value) -> void:
	selector = selector.strip_edges()
	if selector.is_empty():
		return
	var rating := clampf(float(value), 0.0, 5.0)
	_rating_entries.append({"selector": selector, "rating": rating})


func _collect_files_recursive(folder: String, suffix: String, output: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if filename != "." and filename != "..":
			var full_path := folder.path_join(filename)
			if directory.current_is_dir():
				_collect_files_recursive(full_path, suffix, output)
			elif filename.ends_with(suffix):
				output.append(full_path)
		filename = directory.get_next()
	directory.list_dir_end()


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data


func _runtime_to_seconds(runtime: String) -> int:
	var parts := runtime.strip_edges().split(":")
	if parts.size() == 3:
		return maxi(0, int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2]))
	if parts.size() == 2:
		return maxi(0, int(parts[0]) * 60 + int(parts[1]))
	if parts.size() == 1:
		return maxi(0, int(parts[0]))
	return 0


func _remove_last_extension(filename: String) -> String:
	var extension := filename.get_extension()
	if extension.is_empty():
		return filename
	return filename.left(filename.length() - extension.length() - 1)


func _add_index(index: Dictionary, key: String, catalog_index: int) -> void:
	if key.is_empty():
		return
	var matches: Array = index.get(key, [])
	matches.append(catalog_index)
	index[key] = matches
