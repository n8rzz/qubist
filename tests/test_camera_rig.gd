extends "res://tests/q_test.gd"

const CameraRig := preload("res://game/camera_rig.gd")
const ViewMath := preload("res://game/view_math.gd")


func test_restore_wraps_the_step_into_0_to_3() -> void:
	var rig := CameraRig.new()
	for pair in [[0, 0], [3, 3], [4, 0], [5, 1], [-1, 3], [-6, 2]]:
		rig.restore(pair[0], CameraRig.DEFAULT_ZOOM)
		check_eq(rig.view_step(), pair[1], "step %d" % pair[0])
		# rotation is stored as 32-bit floats, so compare loosely.
		check(
			is_equal_approx(rig.rotation.y, ViewMath.yaw_for_step(pair[1])),
			"yaw for step %d" % pair[0]
		)
	rig.free()


func test_restore_clamps_the_zoom() -> void:
	var rig := CameraRig.new()
	rig.restore(0, 1.0)
	check_eq(rig.camera.size, rig.zoom_min)
	rig.restore(0, 100.0)
	check_eq(rig.camera.size, rig.zoom_max)
	rig.restore(0, 12.0)
	check_eq(rig.camera.size, 12.0, "a zoom inside the limits is kept")
	rig.free()


func test_zoom_by_ignores_zero_and_negative_factors() -> void:
	var rig := CameraRig.new()
	var before: float = rig.camera.size
	rig.zoom_by(0.0)
	check_eq(rig.camera.size, before, "zoom_by(0)")
	rig.zoom_by(-1.0)
	check_eq(rig.camera.size, before, "zoom_by(-1)")
	rig.free()


func test_zoom_by_stays_within_the_limits() -> void:
	var rig := CameraRig.new()
	for i in 20:
		rig.zoom_by(2.0)
		check(rig.camera.size >= rig.zoom_min, "zooming in stops at zoom_min")
	check_eq(rig.camera.size, rig.zoom_min)
	for i in 20:
		rig.zoom_by(0.5)
		check(rig.camera.size <= rig.zoom_max, "zooming out stops at zoom_max")
	check_eq(rig.camera.size, rig.zoom_max)
	rig.free()
