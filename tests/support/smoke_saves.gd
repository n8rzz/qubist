extends RefCounted
## Shared by the smoke tests: the save files they point the game screen at,
## so a run never touches the real ones, and how they report and quit.

const SaveFile := preload("res://core/save_file.gd")

## This run's own folder. Every worktree of the project shares one user://
## folder, so the process ID keeps two smoke runs at the same time from
## overwriting each other's saves.
var dir: String
var stats_path: String
var game_path: String
var settings_path: String
var onboarding_path: String


## Save paths under user://test_saves/<prefix>_<process id>/.
func _init(prefix: String) -> void:
	dir = "user://test_saves/%s_%d" % [prefix, OS.get_process_id()]
	stats_path = dir.path_join("stats.json")
	game_path = dir.path_join("game.json")
	settings_path = dir.path_join("settings.json")
	onboarding_path = dir.path_join("onboarding.json")


## Points a game screen (scenes/main.tscn) at these save files.
func use_on(screen) -> void:
	screen.stats_path = stats_path
	screen.game_save_path = game_path
	screen.settings_path = settings_path
	screen.onboarding_path = onboarding_path


## Removes this run's save files and its folder.
func clear() -> void:
	for path in [stats_path, game_path, settings_path, onboarding_path]:
		SaveFile.remove(path)
		SaveFile.remove(path + ".tmp")
	if DirAccess.dir_exists_absolute(dir):
		DirAccess.remove_absolute(dir)


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
