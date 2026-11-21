extends RefCounted
## One dealable piece in one fixed orientation.
##
## `cells` are offsets from the piece's origin as Vector3i(x, y, h), shifted so
## the smallest x, y and h are all 0. `size` is the piece's bounding box.

var id: String = ""
var shape: String = ""
var weight: float = 1.0
var cells: Array[Vector3i] = []
var size: Vector3i = Vector3i.ZERO


func _init(data: Dictionary = {}) -> void:
	if data.is_empty():
		return
	id = str(data.get("id", ""))
	shape = str(data.get("shape", id))
	weight = float(data.get("weight", 1.0))
	var raw: Array[Vector3i] = []
	for c in data.get("cells", []):
		raw.append(Vector3i(int(c[0]), int(c[1]), int(c[2])))
	_set_cells(raw)


func cube_count() -> int:
	return cells.size()


func _set_cells(raw: Array[Vector3i]) -> void:
	assert(not raw.is_empty(), "Piece '%s' has no cells" % id)
	var lo: Vector3i = raw[0]
	var hi: Vector3i = raw[0]
	for c in raw:
		lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
		hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	cells.clear()
	for c in raw:
		cells.append(c - lo)
	size = hi - lo + Vector3i.ONE
