extends SceneTree
## Smoke test for the loading view (#69). Loads the app's first scene
## headless and checks that it stays up for its minimum time even though the
## game is ready sooner, then hands off to the game screen on Home and frees
## itself.
##
##   godot --headless --path . --script res://tests/smoke_loading.gd
##
## Exits with code 0 if the hand-off went through, 1 otherwise.

const SmokeSaves := preload("res://tests/support/smoke_saves.gd")
## Shorter than the real minimum so the test doesn't wait 3 s, but long
## enough that the game is ready well before it.
const MIN_SECONDS := 0.6
const TIMEOUT_MSEC := 15000
const WHAT := "loading view hands off to Home after its minimum time"

var loading
var started_msec := 0
var ready_before_min := false
## The checks have run; waiting for the screen to free before quitting.
var finishing := false
var failures: Array[String] = []
var saves := SmokeSaves.new("loading")


func _initialize() -> void:
	saves.clear()
	var first_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	if first_scene != "res://scenes/loading.tscn":
		failures.append("the app starts on %s, not the loading view" % first_scene)
	loading = load("res://scenes/loading.tscn").instantiate()
	loading.min_seconds = MIN_SECONDS
	loading.prepare_main = saves.use_on
	root.add_child(loading)
	current_scene = loading
	started_msec = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if finishing:
		return false
	var waited := Time.get_ticks_msec() - started_msec
	if is_instance_valid(loading) and not loading.is_queued_for_deletion():
		if loading.is_ready() and loading.elapsed < MIN_SECONDS:
			ready_before_min = true
		if loading.main != null and loading.elapsed < MIN_SECONDS and loading.modulate.a < 1.0:
			failures.append("the loading view started fading before its minimum time")
		if waited > TIMEOUT_MSEC:
			failures.append("the loading view never handed off (%d ms)" % waited)
			return saves.finish(self, failures, WHAT)
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
	# Free the screen and give the audio thread a moment to drop its sounds
	# (#26) before quitting, or they show up as leaks at exit.
	finishing = true
	if main != null:
		main.queue_free()
	create_timer(0.25).timeout.connect(saves.finish.bind(self, failures, WHAT))
	return false

