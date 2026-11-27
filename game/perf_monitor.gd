extends Node
## Measures how hard the game works the device (#321), in debug builds only.
##
## Every frame it samples the frame time, the process and busy time, draw
## calls and primitives, and the CPU and GPU render time of the root and the
## tower viewports. It files each sample under the screen `scene_name`
## returns (home, game_idle, drag…). Every WINDOW_SECONDS it sums up each
## screen it saw, prints one "[perf]" line per screen (Xcode's console shows
## them) and appends a row to LOG_PATH.
##
## F3, or a three-finger tap, shows or hides a small overlay with the latest
## numbers. See docs/performance.md for how to use the log.

const PerfWindow := preload("res://game/perf_window.gd")

const WINDOW_SECONDS := 5.0
const LOG_PATH := "user://perf.csv"
const OVERLAY_FONT_SIZE := 10
const OVERLAY_COLOR := Color(0, 0, 0, 0.6)

## Returns the current screen's name as a String.
var scene_name: Callable
## The tower's SubViewport, measured on its own. May be null.
var tower_viewport: Viewport
## Where the log goes; empty to only print.
var log_path := LOG_PATH
## Seconds since the monitor started, for the log's t column.
var elapsed := 0.0

var _windows := {}
var _window_left := WINDOW_SECONDS
## Session start, so rows from different runs in one log can be told apart.
var _session := ""
var _device := ""
var _overlay: CanvasLayer
var _overlay_label: Label
var _measured: Array[RID] = []
## When this frame started, and the last frame's busy time, in microseconds.
var _frame_start_usec := 0
var _last_busy_usec := 0


func _init(p_scene_name: Callable, p_tower_viewport: Viewport = null) -> void:
	scene_name = p_scene_name
	tower_viewport = p_tower_viewport
	name = "PerfMonitor"
	# Last of all the nodes, so process_ms covers everyone's _process.
	process_priority = 1000000


func _ready() -> void:
	_session = Time.get_datetime_string_from_system()
	_device = "%s %s" % [OS.get_name(), OS.get_model_name()]
	for viewport in [get_viewport(), tower_viewport]:
		if viewport != null:
			RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
			_measured.append(viewport.get_viewport_rid())
	_build_overlay()
	# Performance.TIME_PROCESS only updates about once a second, so frames
	# are timed here: from the start of the frame (process_frame comes before
	# any node's _process) to the end of the last _process and to the end of
	# drawing.
	get_tree().process_frame.connect(_on_frame_start)
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	print("[perf] monitor on: %s, logging to %s" % [_device, _log_file()])


func _exit_tree() -> void:
	flush()
	if get_tree().process_frame.is_connected(_on_frame_start):
		get_tree().process_frame.disconnect(_on_frame_start)
	if RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_frame_drawn)
	for rid in _measured:
		RenderingServer.viewport_set_measure_render_time(rid, false)


func _process(delta: float) -> void:
	elapsed += delta
	record(str(scene_name.call()), sample(delta))
	_window_left -= delta
	if _window_left <= 0.0:
		_window_left = WINDOW_SECONDS
		flush()


func _input(event: InputEvent) -> void:
	var toggle := false
	if event is InputEventKey and event.pressed and not event.echo:
		toggle = event.keycode == KEY_F3
	elif event is InputEventScreenTouch and event.pressed:
		# The third finger down.
		toggle = event.index == 2
	if toggle:
		set_overlay_visible(not overlay_visible())


## This frame's numbers, as PerfWindow.FIELDS.
func sample(delta: float) -> Dictionary:
	var out := {
		"frame_ms": delta * 1000.0,
		"process_ms": (Time.get_ticks_usec() - _frame_start_usec) / 1000.0,
		"busy_ms": _last_busy_usec / 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"target_fps": Engine.max_fps,
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}
	var root := get_viewport().get_viewport_rid()
	out["root_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(root)
	out["root_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(root)
	# A hidden tower (on Home, say) doesn't render, so it counts as 0.
	if tower_viewport != null and _renders(tower_viewport):
		var rid := tower_viewport.get_viewport_rid()
		out["tower_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(rid)
		out["tower_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return out


## Files `values` (a sample) under `scene`.
func record(scene: String, values: Dictionary) -> void:
	if not _windows.has(scene):
		_windows[scene] = PerfWindow.new(scene)
	(_windows[scene] as PerfWindow).add(values)


## Sums up and logs every screen seen since the last flush, then starts
## over. Returns the summaries.
func flush() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for scene in _windows:
		var window: PerfWindow = _windows[scene]
		if not window.is_empty():
			out.append(window.summary())
	_windows.clear()
	if out.is_empty():
		return out
	var lines: PackedStringArray = []
	for s in out:
		var line := PerfWindow.describe(s)
		print("[perf] " + line)
		lines.append(line)
	_write_rows(out)
	if _overlay_label != null:
		_overlay_label.text = "\n".join(lines)
	return out


func overlay_visible() -> bool:
	return _overlay != null and _overlay.visible


func set_overlay_visible(on: bool) -> void:
	if _overlay != null:
		_overlay.visible = on


func _on_frame_start() -> void:
	_frame_start_usec = Time.get_ticks_usec()


func _on_frame_drawn() -> void:
	_last_busy_usec = Time.get_ticks_usec() - _frame_start_usec


func _renders(viewport: Viewport) -> bool:
	var parent := viewport.get_parent()
	return not (parent is CanvasItem and not (parent as CanvasItem).is_visible_in_tree())


func _log_file() -> String:
	return ProjectSettings.globalize_path(log_path) if log_path != "" else "(console only)"


func _write_rows(summaries: Array[Dictionary]) -> void:
	if log_path == "":
		return
	var is_new := not FileAccess.file_exists(log_path)
	var file := FileAccess.open(log_path, FileAccess.WRITE if is_new else FileAccess.READ_WRITE)
	if file == null:
		push_warning("PerfMonitor: could not open %s" % log_path)
		log_path = ""
		return
	file.seek_end()
	if is_new:
		var header := PackedStringArray(["session", "t", "device"])
		header.append_array(PerfWindow.columns())
		file.store_csv_line(header)
	for s in summaries:
		var row := PackedStringArray([_session, "%.1f" % elapsed, _device])
		row.append_array(PerfWindow.csv_cells(s))
		file.store_csv_line(row)
	file.close()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	_overlay.visible = false
	add_child(_overlay)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(4, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = OVERLAY_COLOR
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_overlay.add_child(panel)
	_overlay_label = Label.new()
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_label.add_theme_font_size_override("font_size", OVERLAY_FONT_SIZE)
	_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_overlay_label.custom_minimum_size = Vector2(300, 0)
	_overlay_label.text = "[perf] first numbers in %.0fs" % WINDOW_SECONDS
	panel.add_child(_overlay_label)
