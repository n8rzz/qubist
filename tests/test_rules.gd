extends "res://tests/q_test.gd"

const Config := preload("res://core/config.gd")
const Grid := preload("res://core/grid.gd")
const Rules := preload("res://core/rules.gd")

var cfg := Config.new()


func _grid():
	return Grid.new(6, 6, 12)


func _piece(id: String):
	return cfg.piece_by_id(id)


func _fill(grid, cells: Array) -> void:
	for c in cells:
		grid.set_filled(c, true)


# --- Placement ---

func test_floor_placement_is_legal() -> void:
	check(Rules.can_place(_grid(), _piece("bar2_x"), Vector3i(0, 0, 0)))


func test_floating_placement_is_illegal() -> void:
	check(not Rules.can_place(_grid(), _piece("bar2_x"), Vector3i(0, 0, 1)))


func test_resting_on_a_block_is_legal() -> void:
	var g = _grid()
	_fill(g, [Vector3i(0, 0, 0)])
	check(Rules.can_place(g, _piece("bar2_x"), Vector3i(0, 0, 1)))


func test_overhang_is_legal_with_one_supported_cube() -> void:
	var g = _grid()
	_fill(g, [Vector3i(0, 0, 0)])
	check(Rules.can_place(g, _piece("bar4_x"), Vector3i(0, 0, 1)))


func test_side_contact_alone_is_illegal() -> void:
	var g = _grid()
	_fill(g, [Vector3i(0, 0, 0), Vector3i(0, 0, 1)])
	# Touches the column's side at h = 1, but nothing is underneath.
	check(not Rules.can_place(g, _piece("bar2_x"), Vector3i(1, 0, 1)))


func test_own_cubes_do_not_support_each_other() -> void:
	check(not Rules.can_place(_grid(), _piece("bar2_up"), Vector3i(0, 0, 1)))


func test_out_of_bounds_is_illegal() -> void:
	check(not Rules.can_place(_grid(), _piece("bar4_x"), Vector3i(3, 0, 0)))
	check(not Rules.can_place(_grid(), _piece("bar2_y"), Vector3i(0, 5, 0)))
	check(not Rules.can_place(_grid(), _piece("bar2_x"), Vector3i(-1, 0, 0)))


func test_overlap_is_illegal() -> void:
	var g = _grid()
	_fill(g, [Vector3i(1, 0, 0)])
	check(not Rules.can_place(g, _piece("bar2_x"), Vector3i(0, 0, 0)))


func test_nothing_above_the_top_layer() -> void:
	var g = _grid()
	for h in range(11):
		g.set_filled(Vector3i(0, 0, h), true)
	check(Rules.can_place(g, _piece("bar2_x"), Vector3i(0, 0, 11)), "top layer is usable")
	check(not Rules.can_place(g, _piece("bar2_up"), Vector3i(0, 0, 11)), "would reach layer 13")


func test_legal_positions_on_empty_grid() -> void:
	# Only the floor is supported on an empty grid.
	check_eq(Rules.legal_positions(_grid(), _piece("bar2_x")).size(), 5 * 6)
	check_eq(Rules.legal_positions(_grid(), _piece("cube2")).size(), 5 * 5)
	check_eq(Rules.legal_positions(_grid(), _piece("bar4_up")).size(), 6 * 6)


func test_no_legal_position_on_full_grid() -> void:
	var g = _grid()
	for h in range(12):
		for y in range(6):
			for x in range(6):
				g.set_filled(Vector3i(x, y, h), true)
	check(not Rules.has_any_legal(g, _piece("bar2_x")))


func test_cube_blocked_by_checkerboard() -> void:
	var g = _grid()
	for h in range(12):
		for y in range(6):
			for x in range(6):
				if (x + y) % 2 == 0:
					g.set_filled(Vector3i(x, y, h), true)
	check(not Rules.has_any_legal(g, _piece("cube2")))
	check(not Rules.has_any_legal(g, _piece("bar2_x")))
	check(Rules.has_any_legal(g, _piece("bar2_up")), "the empty columns still take an upright bar")


# --- Lines ---

func test_full_x_line() -> void:
	var g = _grid()
	for x in range(6):
		g.set_filled(Vector3i(x, 2, 0), true)
	var lines := Rules.full_lines_through(g, [Vector3i(3, 2, 0)])
	check_eq(lines.size(), 1)
	check_eq(lines[0].axis, Rules.AXIS_X)
	check_eq(lines[0].cells.size(), 6)


func test_full_y_line() -> void:
	var g = _grid()
	for y in range(6):
		g.set_filled(Vector3i(4, y, 3), true)
	var lines := Rules.full_lines_through(g, [Vector3i(4, 0, 3)])
	check_eq(lines.size(), 1)
	check_eq(lines[0].axis, Rules.AXIS_Y)


func test_full_vertical_line() -> void:
	var g = _grid()
	for h in range(12):
		g.set_filled(Vector3i(1, 1, h), true)
	var lines := Rules.full_lines_through(g, [Vector3i(1, 1, 5)])
	check_eq(lines.size(), 1)
	check_eq(lines[0].axis, Rules.AXIS_H)
	check_eq(lines[0].cells.size(), 12)


func test_incomplete_line_is_not_full() -> void:
	var g = _grid()
	for x in range(5):
		g.set_filled(Vector3i(x, 0, 0), true)
	check_eq(Rules.full_lines_through(g, [Vector3i(0, 0, 0)]).size(), 0)


func test_crossing_lines_are_both_found() -> void:
	var g = _grid()
	for i in range(6):
		g.set_filled(Vector3i(i, 0, 0), true)
		g.set_filled(Vector3i(0, i, 0), true)
	check_eq(Rules.full_lines_through(g, [Vector3i(0, 0, 0)]).size(), 2)


func test_each_line_listed_once() -> void:
	var g = _grid()
	for x in range(6):
		g.set_filled(Vector3i(x, 0, 0), true)
	var lines := Rules.full_lines_through(g, [Vector3i(1, 0, 0), Vector3i(2, 0, 0)])
	check_eq(lines.size(), 1)
