extends RefCounted
## The tower's cells: which of width × depth × height positions hold a block.
##
## Positions are Vector3i(x, y, h); h = 0 is the floor (stored in .z).

var width: int
var depth: int
var height: int

var _cells := PackedByteArray()


func _init(w: int = 6, d: int = 6, h: int = 12) -> void:
	width = w
	depth = d
	height = h
	_cells.resize(w * d * h)
	_cells.fill(0)


func size() -> Vector3i:
	return Vector3i(width, depth, height)


func cell_count() -> int:
	return _cells.size()


func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.x < width \
		and c.y >= 0 and c.y < depth \
		and c.z >= 0 and c.z < height


## True if the cell holds a block. Cells outside the grid are never filled.
func is_filled(c: Vector3i) -> bool:
	return in_bounds(c) and _cells[_index(c)] != 0


func set_filled(c: Vector3i, filled: bool) -> void:
	assert(in_bounds(c), "Cell %s is outside the grid" % c)
	_cells[_index(c)] = 1 if filled else 0


func filled_count() -> int:
	var n := 0
	for v in _cells:
		n += v
	return n


func filled_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for h in range(height):
		for y in range(depth):
			for x in range(width):
				var c := Vector3i(x, y, h)
				if _cells[_index(c)] != 0:
					out.append(c)
	return out


func clear_all() -> void:
	_cells.fill(0)


## Flat list of 0/1 values, x fastest, then y, then h. JSON-safe.
func to_array() -> Array:
	return Array(_cells)


func load_array(values: Array) -> void:
	assert(values.size() == _cells.size(), "Saved grid has %d cells, expected %d" % [values.size(), _cells.size()])
	for i in range(_cells.size()):
		_cells[i] = 1 if int(values[i]) != 0 else 0


func _index(c: Vector3i) -> int:
	return c.x + c.y * width + c.z * width * depth
