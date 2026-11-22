extends "res://tests/q_test.gd"

const ViewMath := preload("res://game/view_math.gd")

const SIZE := Vector3i(6, 6, 12)


func test_footprint_is_centered() -> void:
	check_eq(ViewMath.to_world(Vector3i(0, 0, 0), SIZE), Vector3(-2.5, 0.5, -2.5))
	check_eq(ViewMath.to_world(Vector3i(5, 5, 11), SIZE), Vector3(2.5, 11.5, 2.5))


func test_core_y_maps_to_world_z() -> void:
	var p := ViewMath.to_world(Vector3i(0, 3, 7), SIZE)
	check_eq(p.y, 7.5, "layer becomes world height")
	check_eq(p.z, 0.5, "depth becomes world z")


func test_start_view_faces_the_high_corner() -> void:
	var toward := ViewMath.toward_camera(0)
	check(toward.x > 0.0 and toward.y > 0.0)


func test_quarter_turn_moves_to_the_next_corner() -> void:
	var a := ViewMath.toward_camera(0)
	var b := ViewMath.toward_camera(1)
	check(absf(a.dot(b)) < 0.001, "views a quarter turn apart are perpendicular")
	check(ViewMath.toward_camera(4).distance_to(a) < 0.001, "four turns come back around")


func test_swiper_axis_alternates_with_the_view() -> void:
	check_eq(ViewMath.slice_axis(ViewMath.MODE_X, 0), 1)
	check_eq(ViewMath.slice_axis(ViewMath.MODE_Y, 0), 0)
	check_eq(ViewMath.slice_axis(ViewMath.MODE_X, 1), 0)
	check_eq(ViewMath.slice_axis(ViewMath.MODE_X, -1), 0)


func test_swiper_cuts_from_the_front() -> void:
	# Matches the Slicing wireframe: at the start view, X mode at depth 3
	# hides the three y-layers nearest the player (y = 3, 4, 5).
	check(ViewMath.is_sliced_away(Vector3i(0, 5, 0), ViewMath.MODE_X, 0, SIZE, 3))
	check(ViewMath.is_sliced_away(Vector3i(0, 3, 0), ViewMath.MODE_X, 0, SIZE, 3))
	check(not ViewMath.is_sliced_away(Vector3i(0, 2, 0), ViewMath.MODE_X, 0, SIZE, 3))
	check(not ViewMath.is_sliced_away(Vector3i(0, 5, 0), ViewMath.MODE_X, 0, SIZE, 0), "depth 0 shows everything")


func test_swiper_front_follows_rotation() -> void:
	# Two quarter turns put the camera at the low corner, so y = 0 is in front.
	check_eq(ViewMath.layer_from_viewer(Vector3i(0, 0, 0), ViewMath.MODE_X, 2, SIZE), 0)
	check_eq(ViewMath.layer_from_viewer(Vector3i(0, 5, 0), ViewMath.MODE_X, 2, SIZE), 5)


func test_preview_projection_directions() -> void:
	var base := ViewMath.preview_point(Vector3(0, 0, 0), 0)
	var higher := ViewMath.preview_point(Vector3(0, 0, 1), 0)
	var nearer := ViewMath.preview_point(Vector3(1, 1, 0), 0)
	check(higher.y < base.y, "higher layers draw further up the screen")
	check(nearer.y > base.y, "cells nearer the camera draw lower on screen")
	check(absf(nearer.x - base.x) < 0.001, "stepping straight toward the camera stays centered")


func test_z_mode_steps_through_layers() -> void:
	for step in range(4):
		check_eq(ViewMath.slice_axis(ViewMath.MODE_Z, step), 2)
		check_eq(ViewMath.slice_layer_count(ViewMath.MODE_Z, step, SIZE), 12)


func test_z_mode_fades_layers_above_the_slice_at_every_rotation() -> void:
	# Depth 3 cuts away the top three layers (h = 9, 10, 11); the slice at
	# h = 8 and everything below stay solid, whichever way the tower faces.
	for step in range(-1, 5):
		for c in [Vector3i(0, 0, 11), Vector3i(5, 2, 9), Vector3i(3, 5, 9)]:
			check(ViewMath.is_sliced_away(c, ViewMath.MODE_Z, step, SIZE, 3),
				"%s hidden at step %d" % [c, step])
		for c in [Vector3i(0, 0, 8), Vector3i(5, 5, 0), Vector3i(2, 3, 4)]:
			check(not ViewMath.is_sliced_away(c, ViewMath.MODE_Z, step, SIZE, 3),
				"%s solid at step %d" % [c, step])
		check(not ViewMath.is_sliced_away(Vector3i(0, 0, 11), ViewMath.MODE_Z, step, SIZE, 0),
			"depth 0 shows everything")


func test_z_mode_counts_from_the_top() -> void:
	check_eq(ViewMath.layer_from_viewer(Vector3i(0, 0, 11), ViewMath.MODE_Z, 0, SIZE), 0)
	check_eq(ViewMath.layer_from_viewer(Vector3i(0, 0, 0), ViewMath.MODE_Z, 0, SIZE), 11)
	check_eq(ViewMath.layer_from_viewer(Vector3i(4, 1, 6), ViewMath.MODE_Z, 3, SIZE), 5)


func test_ripple_starts_at_the_placed_cells() -> void:
	var line: Array = []
	for x in range(6):
		line.append(Vector3i(x, 2, 0))
	var steps := ViewMath.ripple_steps(line, [Vector3i(5, 2, 0)])
	check_eq(steps[Vector3i(5, 2, 0)], 0, "the placed cell goes first")
	check_eq(steps[Vector3i(4, 2, 0)], 1)
	check_eq(steps[Vector3i(0, 2, 0)], 5, "the far end goes last")


func test_ripple_uses_the_nearest_placed_cell() -> void:
	var line: Array = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)]
	var steps := ViewMath.ripple_steps(line, [Vector3i(0, 0, 0), Vector3i(3, 0, 0)])
	check_eq(steps[Vector3i(1, 0, 0)], 1)
	check_eq(steps[Vector3i(2, 0, 0)], 1)


func test_ripple_with_nothing_placed_starts_everywhere() -> void:
	var steps := ViewMath.ripple_steps([Vector3i(1, 1, 1)], [])
	check_eq(steps[Vector3i(1, 1, 1)], 0)
