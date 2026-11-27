extends "res://tests/q_test.gd"

const PerfWindow := preload("res://game/perf_window.gd")
const PerfMonitor := preload("res://game/perf_monitor.gd")


func _frames(times: Array) -> PerfWindow:
	var w := PerfWindow.new("game_idle")
	for t in times:
		w.add({"frame_ms": t, "process_ms": t / 10.0, "draw_calls": 10})
	return w


func test_empty_window() -> void:
	var w := PerfWindow.new("home")
	check(w.is_empty(), "a new window should be empty")
	var s := w.summary()
	check_eq(s.frames, 0)
	check_eq(s.fps, 0.0, "no frames should give 0 fps, not a division by zero")
	check_eq(s.frame_ms, 0.0)


func test_summary_averages_fields() -> void:
	var s := _frames([10.0, 20.0, 30.0, 40.0]).summary()
	check_eq(s.scene, "game_idle")
	check_eq(s.frames, 4)
	check(is_equal_approx(s.frame_ms, 25.0), "average frame time, got %s" % s.frame_ms)
	check(is_equal_approx(s.process_ms, 2.5), "average process time, got %s" % s.process_ms)
	check(is_equal_approx(s.draw_calls, 10.0), "average draw calls")
	check_eq(s.root_gpu_ms, 0.0, "missing fields count as 0")


func test_summary_fps_from_frame_times() -> void:
	var s := _frames([20.0, 20.0, 20.0, 20.0, 20.0]).summary()
	check(is_equal_approx(s.seconds, 0.1), "5 frames of 20 ms are 0.1 s, got %s" % s.seconds)
	check(is_equal_approx(s.fps, 50.0), "20 ms frames are 50 fps, got %s" % s.fps)


func test_summary_spread() -> void:
	var times: Array = []
	for i in range(1, 101):
		times.append(float(i))
	var s := _frames(times).summary()
	check(is_equal_approx(s.frame_ms_p95, 95.0), "p95 of 1..100, got %s" % s.frame_ms_p95)
	check(is_equal_approx(s.frame_ms_max, 100.0), "max of 1..100")
	check(s.has("busy_ms_p95") and s.has("busy_ms_max"), "busy time gets a spread too")
	check(not s.has("draw_calls_p95"), "only SPREAD_FIELDS get a p95")


func test_percentile() -> void:
	check_eq(PerfWindow.percentile(PackedFloat32Array(), 0.95), 0.0)
	check_eq(PerfWindow.percentile(PackedFloat32Array([3.0]), 0.95), 3.0)
	var values := PackedFloat32Array([5.0, 1.0, 4.0, 2.0, 3.0])
	check_eq(PerfWindow.percentile(values, 1.0), 5.0)
	check_eq(PerfWindow.percentile(values, 0.0), 1.0)
	check_eq(PerfWindow.percentile(values, 0.5), 3.0)
	check_eq(values[0], 5.0, "percentile() should not sort the caller's array")


func test_csv_cells_follow_columns() -> void:
	var columns := PerfWindow.columns()
	check_eq(columns[0], "scene")
	check(columns.has("frame_ms_p95") and columns.has("tower_gpu_ms"), "columns cover every field")
	var cells := PerfWindow.csv_cells(_frames([10.0, 30.0]).summary())
	check_eq(cells.size(), columns.size(), "one cell per column")
	check_eq(cells[0], "game_idle")
	check_eq(cells[columns.find("frame_ms")], "20.000")
	check_eq(cells[columns.find("frames")], "2", "whole numbers stay whole")


func test_describe_names_the_scene() -> void:
	var line := PerfWindow.describe(_frames([16.0, 17.0]).summary())
	check(line.begins_with("game_idle "), "the line starts with the scene: %s" % line)
	check("fps" in line and "busy" in line, "the line shows fps and busy time")


func test_monitor_groups_by_scene_and_logs() -> void:
	var path := "user://test_saves/perf_%d.csv" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	DirAccess.remove_absolute(path)
	var monitor := PerfMonitor.new(func(): return "home")
	monitor.log_path = path
	monitor.record("home", {"frame_ms": 33.0})
	monitor.record("home", {"frame_ms": 35.0})
	monitor.record("drag", {"frame_ms": 8.0})
	var out := monitor.flush()
	check_eq(out.size(), 2, "one summary per scene")
	var by_scene := {}
	for s in out:
		by_scene[s.scene] = s
	check_eq(by_scene["home"].frames, 2)
	check_eq(by_scene["drag"].frames, 1)
	check_eq(monitor.flush().size(), 0, "flush starts over")

	monitor.record("home", {"frame_ms": 30.0})
	monitor.flush()
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	check_eq(lines.size(), 4, "a header, then a row per summary across both flushes")
	check(lines[0].begins_with("session,t,device,scene,"), "header: %s" % lines[0])
	monitor.free()
	DirAccess.remove_absolute(path)


func test_monitor_without_log_only_prints() -> void:
	var monitor := PerfMonitor.new(func(): return "home")
	monitor.log_path = ""
	monitor.record("home", {"frame_ms": 16.0})
	check_eq(monitor.flush().size(), 1)
	monitor.free()
