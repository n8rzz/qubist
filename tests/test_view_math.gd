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


func test_slice_plane_sits_between_cut_and_shown_layers() -> void:
	# Start view, X mode, depth 3: y = 3..5 are cut, so the cut is at y = 3.
	var plane := ViewMath.slice_plane(ViewMath.MODE_X, 0, SIZE, 3)
	check_eq(plane.size(), 4)
	for p in plane:
		check_eq(p.y, 3)
	check_eq(ViewMath.slice_toward_viewer(ViewMath.MODE_X, 0), Vector3i(0, 1, 0))
	# Spans the whole footprint width and the full height.
	check(plane.has(Vector3i(0, 3, 0)) and plane.has(Vector3i(6, 3, 12)))


func test_slice_plane_at_depth_zero_is_the_front_face() -> void:
	for p in ViewMath.slice_plane(ViewMath.MODE_X, 0, SIZE, 0):
		check_eq(p.y, 6)
	# Two quarter turns put y = 0 in front.
	for p in ViewMath.slice_plane(ViewMath.MODE_X, 2, SIZE, 0):
		check_eq(p.y, 0)
	check_eq(ViewMath.slice_toward_viewer(ViewMath.MODE_X, 2), Vector3i(0, -1, 0))


func test_slice_plane_follows_rotation() -> void:
	# After two turns X mode depth 2 cuts y = 0, 1, so the cut is at y = 2.
	for p in ViewMath.slice_plane(ViewMath.MODE_X, 2, SIZE, 2):
		check_eq(p.y, 2)
	# One turn swaps X mode onto the x axis.
	var axis := ViewMath.slice_axis(ViewMath.MODE_X, 1)
	check_eq(axis, 0)
	var x := ViewMath.slice_plane(ViewMath.MODE_X, 1, SIZE, 2)[0].x
	for c in [Vector3i(0, 0, 0), Vector3i(5, 0, 0)]:
		var cut: bool = ViewMath.is_sliced_away(c, ViewMath.MODE_X, 1, SIZE, 2)
		var in_front: bool = c.x >= x if ViewMath.slice_toward_viewer(ViewMath.MODE_X, 1).x > 0 else c.x < x
		check_eq(cut, in_front, "plane at x = %d splits %s correctly" % [x, c])


func test_z_slice_plane_is_flat_below_the_cut_layers() -> void:
	for step in range(4):
		var plane := ViewMath.slice_plane(ViewMath.MODE_Z, step, SIZE, 3)
		for p in plane:
			check_eq(p.z, 9, "h = 9..11 cut, so the cut is at h = 9")
		check_eq(ViewMath.slice_toward_viewer(ViewMath.MODE_Z, step), Vector3i(0, 0, 1))


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


func test_slice_number_counts_x_and_y_from_the_front() -> void:
	for mode in [ViewMath.MODE_X, ViewMath.MODE_Y]:
		for step in range(4):
			check_eq(ViewMath.slice_number(mode, step, SIZE, 0), 1, "front slice is 1")
			check_eq(ViewMath.slice_number(mode, step, SIZE, 2), 3)
			check_eq(ViewMath.slice_number(mode, step, SIZE, 5), 6, "back slice is the last")


func test_slice_number_counts_z_from_the_floor() -> void:
	# Depth counts down from the top, so the top layer is 12 and the floor is 1.
	for step in range(4):
		check_eq(ViewMath.slice_number(ViewMath.MODE_Z, step, SIZE, 0), 12)
		check_eq(ViewMath.slice_number(ViewMath.MODE_Z, step, SIZE, 2), 10)
		check_eq(ViewMath.slice_number(ViewMath.MODE_Z, step, SIZE, 11), 1)


func test_clamp_depth_keeps_depth_in_the_mode_range() -> void:
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_Z, 0, SIZE, 11), 11, "Z has 12 layers")
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_X, 0, SIZE, 11), 5, "X has 6 layers")
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_Y, 1, SIZE, 11), 5, "Y has 6 layers")
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_X, 0, SIZE, 3), 3, "in-range depth is kept")
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_Z, 0, SIZE, -2), 0, "never below 0")


func test_clamp_depth_follows_the_axis_on_an_uneven_footprint() -> void:
	# 4 wide (x) by 8 deep (y). X mode cuts along y at even steps, x at odd.
	var size := Vector3i(4, 8, 12)
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_X, 0, size, 7), 7)
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_X, 1, size, 7), 3)
	check_eq(ViewMath.clamp_depth(ViewMath.MODE_Y, 0, size, 7), 3)


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


func test_corners_line_up_with_cell_centers() -> void:
	var c := Vector3i(2, 4, 3)
	var lo := ViewMath.corner_to_world(c, SIZE)
	var hi := ViewMath.corner_to_world(c + Vector3i.ONE, SIZE)
	check_eq((lo + hi) * 0.5, ViewMath.to_world(c, SIZE))


func test_single_cube_has_six_faces_and_twelve_outer_edges() -> void:
	var cells := [Vector3i(0, 0, 0)]
	check_eq(ViewMath.exposed_faces(cells).size(), 6)
	var edges := ViewMath.piece_edges(cells)
	check_eq(edges.outer.size(), 12)
	check_eq(edges.inner.size(), 0)


func test_shared_faces_are_not_exposed() -> void:
	var pair := [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]
	check_eq(ViewMath.exposed_faces(pair).size(), 10, "the touching faces drop out")


func test_two_cubes_split_their_long_faces_with_inner_edges() -> void:
	var edges := ViewMath.piece_edges([Vector3i(0, 0, 0), Vector3i(1, 0, 0)])
	check_eq(edges.outer.size(), 16, "the 2x1x1 box outline in unit-long pieces")
	check_eq(edges.inner.size(), 4, "one ring of seams where the cubes meet")


func test_big_cube_hides_its_center_edges() -> void:
	var cells: Array = []
	for x in range(2):
		for y in range(2):
			for z in range(2):
				cells.append(Vector3i(x, y, z))
	var edges := ViewMath.piece_edges(cells)
	check_eq(edges.outer.size(), 24, "12 box edges, each two cubes long")
	check_eq(edges.inner.size(), 24, "a cross on each of the six faces")
	check_eq(ViewMath.exposed_faces(cells).size(), 24)


func test_l_shape_inner_corner_is_an_outer_edge() -> void:
	var edges := ViewMath.piece_edges([Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0)])
	var crease := [Vector3i(1, 1, 0), Vector3i(1, 1, 1)]
	check(edges.outer.has(crease), "the concave corner is part of the outline")


func test_diagonal_cubes_keep_both_outlines() -> void:
	var edges := ViewMath.piece_edges([Vector3i(0, 0, 0), Vector3i(1, 1, 0)])
	check_eq(edges.outer.size(), 23, "both outlines, sharing one vertical edge")


func test_border_ticks_count_cells_and_layers() -> void:
	var ticks := ViewMath.border_ticks(SIZE)
	# Posts: 4 corners x 11 layers x 2 walls. Rim and lip: 4 edges x 5 marks each.
	var segments := (4 * 11 * 2) + (4 * 5) * 2
	check_eq((ticks.minor.size() + ticks.major.size()) / 2, segments)
	# Majors at layers 3, 6, 9 on the posts and the midline of every edge.
	check_eq(ticks.major.size() / 2, 4 * 3 * 2 + 4 * 2)


func test_border_ticks_stay_on_the_tower() -> void:
	var ticks := ViewMath.border_ticks(SIZE)
	for p in ticks.minor + ticks.major:
		check(absf(p.x) <= 3.5 and absf(p.z) <= 3.5, "tick at %s is off the base" % p)
		check(p.y >= 0.0 and p.y <= 12.0, "tick at %s is outside the tower's height" % p)


func test_major_ticks_are_longer() -> void:
	var ticks := ViewMath.border_ticks(SIZE)
	for group in [[ticks.minor, ViewMath.TICK_LENGTH], [ticks.major, ViewMath.MAJOR_TICK_LENGTH]]:
		var points: Array = group[0]
		for i in range(0, points.size(), 2):
			var length: float = (points[i + 1] - points[i]).length()
			var expected: float = minf(group[1], ViewMath.FLOOR_TICK_MAX) if points[i].y < 0.01 else group[1]
			check(is_equal_approx(length, expected), "tick %s has length %.2f" % [points[i], length])


func test_crumble_starts_at_the_top() -> void:
	var cells := [Vector3i(0, 0, 0), Vector3i(1, 0, 2), Vector3i(2, 0, 1), Vector3i(3, 0, 2)]
	var starts := ViewMath.crumble_starts(cells, [0.0, 0.0, 0.0, 1.0], 0.1, 0.05)
	check(is_equal_approx(starts[1], 0.0), "the top layer breaks first")
	check(is_equal_approx(starts[2], 0.1), "one layer down waits one step")
	check(is_equal_approx(starts[0], 0.2), "the floor layer breaks last")
	check(is_equal_approx(starts[3], 0.05), "jitter staggers cubes within a layer")


func test_rubble_peak_grows_with_the_tower() -> void:
	var low := ViewMath.rubble_peak(20, 3.0, 0.12, 0.3, 2.5)
	var high := ViewMath.rubble_peak(200, 3.0, 0.12, 0.3, 2.5)
	check(high > low, "more cubes make a taller heap")
	check_eq(ViewMath.rubble_peak(1, 3.0, 0.12, 0.3, 2.5), 0.3, "a few cubes still make a heap")
	check_eq(ViewMath.rubble_peak(432, 3.0, 1.0, 0.3, 2.5), 2.5, "a full tower is capped")
	check_eq(ViewMath.rubble_peak(0, 3.0, 0.12, 0.3, 2.5), 0.0, "no cubes, no heap")


func test_rubble_height_slopes_to_the_edge() -> void:
	check_eq(ViewMath.rubble_height(0.0, 2.0, 3.0), 2.0, "peak in the middle")
	check_eq(ViewMath.rubble_height(3.0, 2.0, 3.0), 0.0, "flat at the edge")
	check_eq(ViewMath.rubble_height(5.0, 2.0, 3.0), 0.0, "flat beyond the edge")
	check(ViewMath.rubble_height(1.0, 2.0, 3.0) > ViewMath.rubble_height(2.0, 2.0, 3.0), "slopes down")


func test_fall_seconds() -> void:
	# Dropped from 4.9 under 9.8 lands after 1 second.
	check(is_equal_approx(ViewMath.fall_seconds(4.9, 0.0, 9.8), 1.0))
	# Thrown up, it takes longer.
	check(ViewMath.fall_seconds(4.9, 2.0, 9.8) > 1.0)
	# Landing above the start: reached on the way down from the peak.
	var t := ViewMath.fall_seconds(-1.0, 6.0, 10.0)
	check(is_equal_approx(6.0 * t - 5.0 * t * t, 1.0), "lands at the right height")
	# Too low a throw to reach: stops at the peak instead of failing.
	check(is_equal_approx(ViewMath.fall_seconds(-5.0, 1.0, 10.0), 0.1))
