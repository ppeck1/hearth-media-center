extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://main.tscn")
    var launcher = scene.instantiate()
    root.add_child(launcher)
    await process_frame

    var total_games := 0
    var total_art := 0
    var total_exact := 0
    for family in launcher._library_systems():
        for system in family.get("children", []):
            var games: Array = system.get("children", [])
            var covered := 0
            var exact := 0
            for game in games:
                if not str(game.get("art", "")).is_empty():
                    covered += 1
                    if str(game.get("art_mode", "")) == "cover":
                        exact += 1
                else:
                    print("MISSING\t%s\t%s" % [system.get("label", "Unknown"), game.get("label", "Unknown")])
            total_games += games.size()
            total_art += covered
            total_exact += exact
            print(
                "%s\t%d games\t%d title covers\t%d system fallbacks\t%d missing" % [
                    system.get("label", "Unknown"),
                    games.size(),
                    exact,
                    covered - exact,
                    games.size() - covered
                ]
            )
    print(
        "TOTAL\t%d games\t%d title covers\t%d system fallbacks\t%d missing" % [
            total_games,
            total_exact,
            total_art - total_exact,
            total_games - total_art
        ]
    )
    launcher.queue_free()
    await process_frame
    quit(0)
