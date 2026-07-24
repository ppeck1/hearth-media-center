extends SceneTree

const ActivityStore := preload("res://scripts/library/library_activity_store.gd")

var failures := 0
var fixture_root := "/tmp/hearth-activity-store-smoke"


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_remove_tree(fixture_root)
	var logs_path := fixture_root.path_join("logs")
	DirAccess.make_dir_recursive_absolute(logs_path.path_join("Core A"))
	DirAccess.make_dir_recursive_absolute(logs_path.path_join("Core B"))

	var alpha_path := fixture_root.path_join("roms/system-a/Alpha (USA).rom")
	var beta_path := fixture_root.path_join("roms/system-a/Beta.disc.iso")
	var duplicate_a_path := fixture_root.path_join("roms/system-a/Duplicate.rom")
	var duplicate_b_path := fixture_root.path_join("roms/system-b/Duplicate.rom")
	var history_path := fixture_root.path_join("content_history.lpl")
	var ratings_path := fixture_root.path_join("library-activity.json")

	_write_json(history_path, {
		"items": [
			{"path": beta_path},
			{"path": alpha_path},
			{"path": fixture_root.path_join("missing.rom")},
		],
	})
	_write_json(logs_path.path_join("Core A/Alpha (USA).lrtl"), {
		"runtime": "1:02:03",
		"last_played": "2026-07-22 10:00:00",
		"play_count": "4",
	})
	_write_json(logs_path.path_join("Core B/Beta.disc.lrtl"), {
		"runtime": "0:20:00",
		"last_played": "2026-07-23 11:00:00",
		"play_count": "2",
	})
	_write_json(logs_path.path_join("Core B/Duplicate.lrtl"), {
		"runtime": "9:00:00",
		"last_played": "2026-07-23 12:00:00",
		"play_count": "99",
	})
	_write_json(ratings_path, {
		"schema_version": 1,
		"ratings": {
			alpha_path: 4.0,
			"Beta.disc": 5.0,
			"Duplicate": 5.0,
		},
	})

	var catalog: Array = [
		{"id": "alpha", "label": "Alpha", "rom_path": alpha_path},
		{"id": "beta", "label": "Beta", "rom_path": beta_path},
		{"id": "duplicate-a", "label": "Duplicate A", "rom_path": duplicate_a_path},
		{"id": "duplicate-b", "label": "Duplicate B", "rom_path": duplicate_b_path},
		{"id": "native-local-game", "label": "Local Game"},
	]
	var store = ActivityStore.new(history_path, logs_path, ratings_path)
	_check(store.reload(), "local activity fixtures load without errors")

	var recent: Array = store.recent_games(catalog, 2)
	_check(recent.size() == 2, "recent list obeys its limit")
	_check(recent[0].get("id") == "beta", "RetroArch history order controls recency")
	_check(recent[1].get("id") == "alpha", "second history entry maps by exact ROM path")

	var most_played: Array = store.most_played_games(catalog, 5)
	_check(most_played.size() == 2, "ambiguous duplicate stems are not attributed")
	_check(most_played[0].get("id") == "alpha", "runtime duration controls most-played order")
	_check(most_played[0].get("runtime_seconds") == 3723, "hour runtime is converted to seconds")
	_check(most_played[0].get("play_count") == 4, "play count is exposed on catalog results")
	_check(most_played[1].get("id") == "beta", "compound ROM stem matches a unique runtime log")

	var top_rated: Array = store.top_rated(catalog, 5)
	_check(top_rated.size() == 2, "only unambiguous locally rated games are returned")
	_check(top_rated[0].get("id") == "beta", "highest local rating sorts first")
	_check(is_equal_approx(float(top_rated[0].get("rating")), 5.0), "local rating is exposed")
	_check(top_rated[1].get("id") == "alpha", "exact-path rating maps to its game")

	_check(store.begin_session(catalog[4]), "native PC session starts with its stable manifest id")
	_check(store.end_session(125), "native PC session duration is saved locally")
	_check(store.reload(), "activity file remains valid after recording a PC session")
	recent = store.recent_games(catalog, 5)
	_check(recent[0].get("id") == "native-local-game", "locally launched PC game appears in Recently Played")
	most_played = store.most_played_games(catalog, 5)
	var pc_activity := _item_with_id(most_played, "native-local-game")
	_check(not pc_activity.is_empty(), "locally launched PC game appears in Most Played")
	_check(pc_activity.get("runtime_seconds") == 125, "PC runtime is restored from local activity")
	_check(pc_activity.get("play_count") == 1, "PC launch count is restored from local activity")
	top_rated = store.top_rated(catalog, 5)
	_check(top_rated.size() == 2, "recording activity preserves all local ratings")

	_remove_tree(fixture_root)
	if failures == 0:
		print("Library activity store smoke test passed.")
		quit(0)
		return
	quit(1)


func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "  ") + "\n")
		file.close()


func _item_with_id(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if item is Dictionary and item.get("id") == item_id:
			return item
	return {}


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if filename != "." and filename != "..":
			var full_path := path.path_join(filename)
			if directory.current_is_dir():
				_remove_tree(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		filename = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
