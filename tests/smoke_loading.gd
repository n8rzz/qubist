extends SceneTree
## Smoke test for the loading view (#69). Loads the app's first scene
## headless and checks that it stays up for its minimum time even though the
## game is ready sooner, then hands off to the game screen on Home and frees
## itself.
##
##   godot --headless --path . --script res://tests/smoke_loading.gd
##
## Exits with code 0 if the hand-off went through, 1 otherwise.

const SaveFile := preload("res://core/save_file.gd")
const LoadingArt := preload("res://game/loading_art.gd")
const STATS_PATH := "user://test_saves/loading_stats.json"
const GAME_PATH := "user://test_saves/loading_game.json"
const SETTINGS_PATH := "user://test_saves/loading_settings.json"
## Shorter than the real minimum so the test doesn't wait 3 s, but long
## enough that the game is ready well before it.
const MIN_SECONDS := 0.6
const TIMEOUT_MSEC := 15000

var loading
var started_msec := 0
var ready_before_min := false
var failures: Array[String] = []


func _initialize() -> void:
	_check_keyframes()
	for path in [STATS_PATH, GAME_PATH, SETTINGS_PATH]:
		SaveFile.remove(path)
	var first_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	if first_scene != "res://scenes/loading.tscn":
		failures.append("the app starts on %s, not the loading view" % first_scene)
	loading = load("res://scenes/loading.tscn").instantiate()
	loading.min_seconds = MIN_SECONDS
	loading.prepare_main = func(screen):
		screen.stats_path = STATS_PATH
		screen.game_save_path = GAME_PATH
		screen.settings_path = SETTINGS_PATH
	root.add_child(loading)
	current_scene = loading
	started_msec = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var waited := Time.get_ticks_msec() - started_msec
	if is_instance_valid(loading) and not loading.is_queued_for_deletion():
		if loading.is_ready() and loading.elapsed < MIN_SECONDS:
			ready_before_min = true
		if loading.main != null and loading.elapsed < MIN_SECONDS and loading.modulate.a < 1.0:
			failures.append("the loading view started fading before its minimum time")
		if waited > TIMEOUT_MSEC:
			failures.append("the loading view never handed off (%d ms)" % waited)
			return _finish()
		return false
	if waited < MIN_SECONDS * 1000:
		failures.append("the loading view left after %d ms, before its %d ms minimum" % [waited, MIN_SECONDS * 1000])
	if not ready_before_min:
		failures.append("the game wasn't ready before the minimum, so the minimum went untested")
	var main = current_scene
	if main == null or main.get("home") == null:
		failures.append("the game screen is not the current scene after loading")
	elif not main.home.visible:
		failures.append("the game screen did not open on Home after loading")
	if root.get_child_count() != 1:
		failures.append("expected only the game screen under root, found %d nodes" % root.get_child_count())
	return _finish()


## The drop keyframes start high and clear, land, bounce and rest.
func _check_keyframes() -> void:
	var lift := LoadingArt.LIFT_KEYS
	var alpha := LoadingArt.ALPHA_KEYS
	if not is_equal_approx(LoadingArt.keyframe(lift, 0.0), 140.0) or LoadingArt.keyframe(alpha, 0.0) != 0.0:
		failures.append("a cube should start 140 up and invisible")
	if not is_zero_approx(LoadingArt.keyframe(lift, 0.2)) or not is_equal_approx(LoadingArt.keyframe(alpha, 0.5), 1.0):
		failures.append("a cube should be landed and opaque mid-loop")
	if not is_equal_approx(LoadingArt.keyframe(lift, 0.24), 8.0):
		failures.append("a cube should bounce 8 up after landing")
	if not is_zero_approx(LoadingArt.keyframe(alpha, 1.0)):
		failures.append("a cube should fade out by the end of the loop")


func _finish() -> bool:
	for path in [STATS_PATH, GAME_PATH, SETTINGS_PATH]:
		SaveFile.remove(path)
	if failures.is_empty():
		print("PASS loading view hands off to Home after its minimum time")
		quit(0)
	else:
		print("FAIL loading view:")
		for f in failures:
			print("  - " + f)
		quit(1)
	return true
