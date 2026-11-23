extends RefCounted
## Shared by the smoke tests: the save files they point the game screen at,
## so a run never touches the real ones, and how they report and quit.

const SaveFile := preload("res://core/save_file.gd")

var stats_path: String
var game_path: String
var settings_path: String


## Save paths under user://test_saves/, named `<prefix>_stats.json` and so on.
func _init(prefix: String) -> void:
	stats_path = "user://test_saves/%s_stats.json" % prefix
	game_path = "user://test_saves/%s_game.json" % prefix
	settings_path = "user://test_saves/%s_settings.json" % prefix


## Points a game screen (scenes/main.tscn) at these save files.
func use_on(screen) -> void:
	screen.stats_path = stats_path
	screen.game_save_path = game_path
	screen.settings_path = settings_path


func clear() -> void:
	for path in [stats_path, game_path, settings_path]:
		SaveFile.remove(path)


## Clears the save files, prints PASS or FAIL with each failure, and quits
## with code 0 or 1. Returns true so a SceneTree's _process can return it.
func finish(tree: SceneTree, failures: Array[String], what: String) -> bool:
	clear()
	if failures.is_empty():
		print("PASS " + what)
		tree.quit(0)
	else:
		print("FAIL %s:" % what)
		for f in failures:
			print("  - " + f)
		tree.quit(1)
	return true
