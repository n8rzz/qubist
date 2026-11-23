extends Control
## Loading view (#69), the app's first scene. Shows the sky, the island with
## cubes dropping onto it, the Qubist wordmark, a progress bar and a tip,
## while the game screen loads in the background. Once the game screen is up
## (it opens on Home) and at least `min_seconds` have passed, the bar fills,
## the view fades out and frees itself, leaving the game screen as the
## current scene.

const SkyBackdrop := preload("res://game/sky_backdrop.gd")
const LoadingArt := preload("res://game/loading_art.gd")
const UI := preload("res://game/ui_style.gd")

signal finished

const MAIN_SCENE := "res://scenes/main.tscn"
## The view stays up at least this long, even when the game is ready sooner.
const MIN_SECONDS := 3.0
const FADE_SECONDS := 0.3
## Frames the game screen draws under the cover before it's revealed, so its
## first-frame setup doesn't show.
const SETTLE_FRAMES := 2
## The bar never passes this until the game screen is ready.
const WAITING_PROGRESS := 0.9
## Where the bar starts, as in the design.
const START_PROGRESS := 0.06

const INK := Color("#22313F")
const MUTED := Color("#3D5568")
const ACCENT := Color("#1F5E7A")
const BAR_TRACK := Color(1, 1, 1, 0.75)
const BAR_SIZE := Vector2(160, 8)
## The art box, wordmark and bar sit centered, nudged up by this much.
const CENTER_LIFT := 40

const TIPS := [
	"Tip: rotate the tower or slice it with the swiper to find hidden gaps.",
	"Tip: a line clears when it's full side to side, front to back or straight up.",
	"Tip: vertical lines hold twice the cubes, so they're worth double.",
	"Tip: clear lines on back-to-back moves to build a streak bonus.",
	"Tip: a piece only needs one cube resting on something; the rest can overhang.",
]

## Shorter in tests, so they don't wait.
var min_seconds := MIN_SECONDS
## Called with the game screen before it enters the tree; tests use it to
## point the saves somewhere safe.
var prepare_main := Callable()
## The game screen, once loaded.
var main: Node
## Seconds since the view appeared.
var elapsed := 0.0
## The bar's fill, 0 to 1; it never goes back.
var progress := START_PROGRESS

var art: LoadingArt
var bar_fill: Panel
var tip_label: Label

var _settled_frames := 0
var _fading := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallow taps until the view is gone, so nothing reaches Home early.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	if ResourceLoader.load_threaded_request(MAIN_SCENE) != OK:
		push_warning("Couldn't start loading %s in the background; loading it now." % MAIN_SCENE)
		_start_main(load(MAIN_SCENE))


func _process(delta: float) -> void:
	elapsed += delta
	art.time = elapsed
	art.queue_redraw()

	var loaded := 0.0
	if main == null:
		var status_progress := []
		var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, status_progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_start_main(ResourceLoader.load_threaded_get(MAIN_SCENE))
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loaded = status_progress[0] if not status_progress.is_empty() else 0.0
		else:
			push_warning("Background load of %s failed; loading it now." % MAIN_SCENE)
			_start_main(load(MAIN_SCENE))
	else:
		_settled_frames += 1
	var game_ready := is_ready()

	# The bar follows the clock toward full over `min_seconds`, held short of
	# the end until the game is ready, and never behind the real load.
	var t := clampf(elapsed / maxf(min_seconds, 0.001), 0.0, 1.0)
	var target := lerpf(START_PROGRESS, 1.0, 1.0 - pow(1.0 - t, 1.5))
	if not game_ready:
		target = minf(target, WAITING_PROGRESS)
	target = maxf(target, lerpf(START_PROGRESS, WAITING_PROGRESS, loaded))
	progress = maxf(progress, target)
	bar_fill.size.x = BAR_SIZE.x * progress

	if game_ready and elapsed >= min_seconds and not _fading:
		_finish()


## True once the game screen is in the tree and has drawn under the cover.
func is_ready() -> bool:
	return main != null and _settled_frames >= SETTLE_FRAMES


## Puts the game screen in the tree under this view and makes it the current
## scene.
func _start_main(packed: PackedScene) -> void:
	if packed == null:
		push_error("Couldn't load %s." % MAIN_SCENE)
		set_process(false)
		return
	main = packed.instantiate()
	if prepare_main.is_valid():
		prepare_main.call(main)
	var root := get_tree().root
	root.add_child(main)
	root.move_child(main, get_index())
	get_tree().current_scene = main


func _finish() -> void:
	_fading = true
	progress = 1.0
	bar_fill.size.x = BAR_SIZE.x
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(func():
		finished.emit()
		queue_free())


func _build() -> void:
	add_child(SkyBackdrop.new())

	var center := MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_bottom", CENTER_LIFT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	art = LoadingArt.new()
	art.custom_minimum_size = Vector2(300, 330)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.still = DisplayServer.accessibility_should_reduce_animation()
	column.add_child(art)

	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wordmark := UI.label("Qubist", 56, INK, HORIZONTAL_ALIGNMENT_CENTER)
	wordmark.add_theme_font_override("font", UI.title_font(600))
	title.add_child(wordmark)
	title.add_child(_build_bar())
	column.add_child(title)

	tip_label = UI.label(TIPS[randi() % TIPS.size()], 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip_label.offset_left = 32
	tip_label.offset_right = -32
	tip_label.offset_top = -58 - 40
	tip_label.offset_bottom = -58
	tip_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(tip_label)


func _build_bar() -> Control:
	var track := Panel.new()
	track.custom_minimum_size = BAR_SIZE
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", UI.box(BAR_TRACK, Color(0, 0, 0, 0), 4, 0))
	bar_fill = Panel.new()
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.size = Vector2(BAR_SIZE.x * progress, BAR_SIZE.y)
	bar_fill.add_theme_stylebox_override("panel", UI.box(ACCENT, Color(0, 0, 0, 0), 4, 0))
	track.add_child(bar_fill)
	return track
