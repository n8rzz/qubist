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
