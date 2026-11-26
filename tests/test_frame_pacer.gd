extends "res://tests/q_test.gd"

const FramePacer := preload("res://game/frame_pacer.gd")


func _setup() -> void:
	FramePacer.reset()


func test_starts_idle() -> void:
	_setup()
	check_eq(FramePacer.current_target(), FramePacer.IDLE_FPS, "should target idle fps by default")


func test_mark_active_raises_to_active_fps() -> void:
	_setup()
	FramePacer.mark_active()
	check_eq(
		FramePacer.current_target(), FramePacer.ACTIVE_FPS, "should target active fps after mark"
	)


func test_update_sets_engine_max_fps() -> void:
	_setup()
	FramePacer.update()
	check_eq(Engine.max_fps, FramePacer.IDLE_FPS, "idle update should set Engine.max_fps to idle")
	FramePacer.mark_active()
	FramePacer.update()
	check_eq(
		Engine.max_fps, FramePacer.ACTIVE_FPS, "active update should set Engine.max_fps to active"
	)


func test_idle_fps_is_30() -> void:
	check_eq(FramePacer.IDLE_FPS, 30, "idle fps should be 30")


func test_active_fps_is_120() -> void:
	check_eq(FramePacer.ACTIVE_FPS, 120, "active fps should be 120")


func test_linger_is_positive() -> void:
	check(FramePacer.LINGER_SECONDS > 0.0, "linger should be positive")
