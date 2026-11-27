extends SceneTree
## Times the game's per-frame CPU work headless (#321), so a change can be
## compared before and after on the same machine:
##
##   godot --headless --path . --script res://tools/benchmark.gd -- [options]
##
## Options (all optional):
##   --frames=N    frames per drawing case (default 120)
##   --calls=N     calls per function case (default 2000)
##   --csv=PATH    also write the results as CSV to PATH
##   --only=a,b    run only these sections: sky, home_art, island, sky_view,
##                 snap, main (default all)
##
## Every row is one case: how many times it ran, and the average, 95th
## percentile and worst time of one run in microseconds. Headless has no GPU,
## so this only covers the CPU side; numbers from a desktop are several times
## lower than on a phone, so only compare runs on the same machine. See
## docs/performance.md.

const SkyBackdrop := preload("res://game/sky_backdrop.gd")
const SkyWeather := preload("res://game/sky_weather.gd")
const SkyView := preload("res://game/sky_view.gd")
const SkyClock := preload("res://core/sky_clock.gd")
const HomeTowerArt := preload("res://game/home_tower_art.gd")
const FloatingIsland := preload("res://game/floating_island.gd")
const PerfWindow := preload("res://game/perf_window.gd")
const Config := preload("res://core/config.gd")
const Game := preload("res://core/game.gd")
const Rules := preload("res://core/rules.gd")
const UI := preload("res://game/ui_style.gd")
const SmokeSaves := preload("res://tests/support/smoke_saves.gd")

const SECTIONS := ["sky", "home_art", "island", "sky_view", "snap", "main"]
## The phone's design size, which the sky and weather are laid out for.
const SCREEN := Vector2(390, 844)
## How far into a crossfade the fade cases hold the sky.
const FADE_HOLD_MSEC := 1500
## Random moves played to get a mid-game tower for the snap search.
const MID_GAME_MOVES := 25

## [name, runs, avg, p95, max], times in microseconds.
var results: Array = []
var opts := {}


## Times its _draw().
class TimedBackdrop:
	extends SkyBackdrop
	var times := PackedFloat32Array()

	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super()
		times.append(Time.get_ticks_usec() - t)


class TimedWeather:
	extends SkyWeather
	var times := PackedFloat32Array()

	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super()
		times.append(Time.get_ticks_usec() - t)


class TimedHomeArt:
	extends HomeTowerArt
	var times := PackedFloat32Array()

	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super()
		times.append(Time.get_ticks_usec() - t)


## Processed after every other node; times from start() to its _process.
class FrameTimer:
	extends Node
	var times := PackedFloat32Array()
	var _start := 0

	func _init() -> void:
		process_priority = 1000000

	func start() -> void:
		_start = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if _start > 0:
			times.append(Time.get_ticks_usec() - _start)


func _initialize() -> void:
	opts = _parse_args(OS.get_cmdline_user_args())
	UI.motion_override = 0
	SkyView.still = false
	_run()


func _run() -> void:
	var only: Array = opts.get("only", SECTIONS)
	print(
		"Benchmark on %s %s, Godot %s" % [OS.get_name(), _cpu(), Engine.get_version_info().string]
	)
	if "sky" in only:
		await _bench_sky()
	if "home_art" in only:
		await _bench_home_art()
	if "island" in only:
		_bench_island()
	if "sky_view" in only:
		_bench_sky_view()
	if "snap" in only:
		_bench_snap()
	if "main" in only:
		await _bench_main()
	_report()
	quit(0)


# --- Sections ---


## The sky backdrop and weather, drawn for every season and time of day, then
## mid-crossfade and with Santa.
func _bench_sky() -> void:
	var box := _screen_box()
	var backdrop := TimedBackdrop.new()
	var weather := TimedWeather.new()
	box.add_child(backdrop)
	box.add_child(weather)
	for season in SkyClock.SEASONS:
		for time in SkyClock.TIMES:
			SkyView.show(season, time, true)
			await _time_draws([backdrop, weather], "%s %s" % [season, time])
	SkyView.show("spring", "day", true)
	SkyView.show("winter", "night")
	await _time_draws([backdrop, weather], "crossfade", true)
	SkyView.show("winter", "night", true)
	SkyView.christmas = true
	await _time_draws([backdrop, weather], "christmas")
	SkyView.christmas = false
	box.queue_free()


## Home's tower art, building and crumbling its loop.
func _bench_home_art() -> void:
	SkyView.show("spring", "day", true)
	var box := _screen_box()
	var art := TimedHomeArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(art)
	art.play([])
	await _time_draws([art], "building")
	box.queue_free()


## The floating island's per-frame work, steady and mid-crossfade (when it
## repaints).
func _bench_island() -> void:
	var island := FloatingIsland.new()
	island.setup(Config.new().grid_size)
	root.add_child(island)
	var calls := int(opts.get("frames", 120))
	SkyView.show("spring", "day", true)
	_add_result("island process steady", _time_calls(calls, func(): island._process(0.016)))
	SkyView.show("winter", "night")
	_add_result("island process crossfade", _time_calls(calls, _faded_process.bind(island)))
	island.queue_free()


func _faded_process(island: FloatingIsland) -> void:
	_hold_fade()
	island._process(0.016)


## SkyView helpers the sky, weather and island call many times a frame.
func _bench_sky_view() -> void:
	var calls := int(opts.get("calls", 2000))
	var cases := {
		"layers": func(): SkyView.layers(),
		"features": func(): SkyView.features(SkyView.season, SkyView.time_of_day),
		"gradient_stops": func(): SkyView.gradient_stops(),
		"sky_color": func(): SkyView.sky_color(0.5),
		"tint": func(): SkyView.tint(),
		"island_color": func(): SkyView.island_color(Color("#7BC96F")),
	}
	SkyView.show("spring", "day", true)
	for key in cases:
		_add_result("sky_view %s steady" % key, _time_calls(calls, cases[key]))
	SkyView.show("winter", "night")
	_hold_fade()
	for key in cases:
		_add_result("sky_view %s crossfade" % key, _time_calls(calls, cases[key]))
	SkyView.show("winter", "night", true)


## The legal-spot search a drag runs on every touch-move (#316), for every
## piece, on an empty tower and a mid-game one.
func _bench_snap() -> void:
	var config := Config.new()
	var calls := maxi(int(opts.get("calls", 2000)) / 20, 10)
	var empty := Game.new(config, 1)
	empty.start()
	var mid := Game.new(config, 1)
	mid.start()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in MID_GAME_MOVES:
		var slots: Array = []
		for s in mid.tray.size():
			if mid.tray[s] != null and Rules.has_any_legal(mid.grid, mid.tray[s]):
				slots.append(s)
		if slots.is_empty() or mid.is_over:
			break
		var slot: int = slots[rng.randi() % slots.size()]
		var spots := Rules.legal_positions(mid.grid, mid.tray[slot])
		mid.place(slot, spots[rng.randi() % spots.size()])
	for entry in [["empty", empty], ["mid-game", mid]]:
		var grid = entry[1].grid
		var times := PackedFloat32Array()
		for piece in config.pieces:
			var run := _time_calls(calls, func(): Rules.legal_positions(grid, piece))
			times.append_array(run)
		_add_result("snap legal_positions %s (all pieces)" % entry[0], times)


## The whole game screen's process time per frame, on Home and in an idle
## game: every node's _process, from the start of the frame to the end of
## the last one. Headless never signals the end of drawing, so _draw time
## is left to the sky and home art cases.
func _bench_main() -> void:
	var saves := SmokeSaves.new("benchmark")
	saves.clear()
	var main = load("res://scenes/main.tscn").instantiate()
	saves.use_on(main)
	root.add_child(main)
	var frames := int(opts.get("frames", 120))
	for i in 10:
		await process_frame
	_add_result("main frame home (process)", await _process_times(frames))
	main._on_home_continue()
	for i in 10:
		await process_frame
	_add_result("main frame game idle (process)", await _process_times(frames))
	main.queue_free()
	await process_frame
	saves.clear()


# --- Timing helpers ---


## A Control the size of the phone screen, for the drawing cases.
func _screen_box() -> Control:
	var box := Control.new()
	box.size = SCREEN
	root.add_child(box)
	return box


## Runs the frames option's worth of frames, in which each of `nodes`
## redraws itself as in the game (they time their own _draw), and adds a row
## per node named after its class and `label`.
func _time_draws(nodes: Array, label: String, hold_fade := false) -> void:
	for node in nodes:
		node.times = PackedFloat32Array()
	for i in int(opts.get("frames", 120)):
		if hold_fade:
			_hold_fade()
		await process_frame
	for node in nodes:
		_add_result("%s draw %s" % [_kind(node), label], node.times)


## Microseconds from the start of each frame to the end of the last
## node's _process.
func _process_times(frames: int) -> PackedFloat32Array:
	var timer := FrameTimer.new()
	root.add_child(timer)
	process_frame.connect(timer.start)
	while timer.times.size() < frames:
		await process_frame
	process_frame.disconnect(timer.start)
	timer.queue_free()
	return timer.times


func _time_calls(calls: int, call: Callable) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	for i in calls:
		var t := Time.get_ticks_usec()
		call.call()
		times.append(Time.get_ticks_usec() - t)
	return times


## Keeps the current crossfade halfway through.
func _hold_fade() -> void:
	SkyView._changed_msec = Time.get_ticks_msec() - FADE_HOLD_MSEC


func _kind(node: Node) -> String:
	if node is TimedBackdrop:
		return "sky backdrop"
	if node is TimedWeather:
		return "sky weather"
	return "home art"


# --- Output ---


func _add_result(label: String, times: PackedFloat32Array) -> void:
	var total := 0.0
	for t in times:
		total += t
	var avg := total / times.size() if times.size() > 0 else 0.0
	results.append(
		[
			label,
			times.size(),
			avg,
			PerfWindow.percentile(times, 0.95),
			PerfWindow.percentile(times, 1.0)
		]
	)


func _report() -> void:
	print("")
	print("%-48s %6s %10s %10s %10s" % ["case", "runs", "avg us", "p95 us", "max us"])
	for r in results:
		print("%-48s %6d %10.1f %10.1f %10.1f" % r)
	var path: String = opts.get("csv", "")
	if path == "":
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_csv_line(PackedStringArray(["case", "runs", "avg_us", "p95_us", "max_us"]))
	for r in results:
		file.store_csv_line(
			PackedStringArray([r[0], str(r[1]), "%.1f" % r[2], "%.1f" % r[3], "%.1f" % r[4]])
		)
	print("\nWrote %s" % path)


func _cpu() -> String:
	return "%s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()]


func _parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		if key == "only":
			out[key] = Array(value.split(","))
		elif key in ["frames", "calls", "csv"]:
			out[key] = value
		else:
			push_warning("Unknown option --%s" % key)
	return out
