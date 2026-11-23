extends "res://tests/q_test.gd"

const Grid := preload("res://core/grid.gd")


func test_starts_empty() -> void:
	var g := Grid.new(6, 6, 12)
	check_eq(g.cell_count(), 432)
	check_eq(g.filled_count(), 0)


func test_bounds() -> void:
	var g := Grid.new(6, 6, 12)
	check(g.in_bounds(Vector3i(0, 0, 0)))
	check(g.in_bounds(Vector3i(5, 5, 11)))
	check(not g.in_bounds(Vector3i(6, 0, 0)))
	check(not g.in_bounds(Vector3i(0, 6, 0)))
	check(not g.in_bounds(Vector3i(0, 0, 12)))
	check(not g.in_bounds(Vector3i(-1, 0, 0)))


func test_fill_and_clear() -> void:
	var g := Grid.new(6, 6, 12)
	g.set_filled(Vector3i(2, 3, 4), true)
	check(g.is_filled(Vector3i(2, 3, 4)))
	check(not g.is_filled(Vector3i(3, 2, 4)), "x and y must not be swapped")
	check(not g.is_filled(Vector3i(2, 3, 3)))
	g.set_filled(Vector3i(2, 3, 4), false)
	check_eq(g.filled_count(), 0)


func test_outside_is_never_filled() -> void:
	var g := Grid.new(6, 6, 12)
	check(not g.is_filled(Vector3i(0, 0, -1)))
	check(not g.is_filled(Vector3i(9, 9, 9)))


func test_array_round_trip() -> void:
	var g := Grid.new(6, 6, 12)
	g.set_filled(Vector3i(0, 0, 0), true)
	g.set_filled(Vector3i(5, 5, 11), true)
	var copy := Grid.new(6, 6, 12)
	copy.load_array(g.to_array())
	check(copy.is_filled(Vector3i(0, 0, 0)))
	check(copy.is_filled(Vector3i(5, 5, 11)))
	check_eq(copy.filled_count(), 2)
	check_eq(copy.filled_cells().size(), 2)


# Saves store to_array() as-is, so its order (x fastest, then y, then h) is
# part of the save format. A grid with distinct sizes catches swapped axes.
func test_array_order() -> void:
	var g := Grid.new(3, 4, 5)
	fill(g, [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)])
	var values := g.to_array()
	var filled: Array[int] = []
	for i in range(values.size()):
		if values[i] != 0:
			filled.append(i)
	var expected: Array[int] = [1, g.width, g.width * g.depth]
	check_eq(filled, expected)


func test_filled_cells_order() -> void:
	var g := Grid.new(3, 4, 5)
	var expected: Array[Vector3i] = [
		Vector3i(2, 0, 0),
		Vector3i(0, 1, 0),
		Vector3i(1, 1, 0),
		Vector3i(0, 0, 1),
		Vector3i(2, 3, 4),
	]
	var reversed := expected.duplicate()
	reversed.reverse()
	fill(g, reversed)
	check_eq(g.filled_cells(), expected)
