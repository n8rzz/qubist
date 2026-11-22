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


## Every distinct 3D rotation of `raw` (up to 24), each shifted so its smallest
## x, y and h are 0 and its cells sorted. The order is fixed: the input's own
## orientation comes first, then the rest in the order the turns reach them.
## Mirror images are not included, only rotations.
static func orientations(raw: Array[Vector3i]) -> Array:
	var start := _normalized(raw)
	var out: Array = [start]
	var seen := {str(start): true}
	var i := 0
	while i < out.size():
		var current: Array[Vector3i] = out[i]
		for turn in 3:
			var turned: Array[Vector3i] = []
			for c in current:
				turned.append(_turn(c, turn))
			turned = _normalized(turned)
			var key := str(turned)
			if not seen.has(key):
				seen[key] = true
				out.append(turned)
		i += 1
	return out


## A quarter turn about the x (0), y (1) or h (2) axis.
static func _turn(c: Vector3i, axis: int) -> Vector3i:
	match axis:
		0:
			return Vector3i(c.x, -c.z, c.y)
		1:
			return Vector3i(c.z, c.y, -c.x)
		_:
			return Vector3i(-c.y, c.x, c.z)


static func _normalized(raw: Array[Vector3i]) -> Array[Vector3i]:
	var lo: Vector3i = raw[0]
	for c in raw:
		lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
	var out: Array[Vector3i] = []
	for c in raw:
		out.append(c - lo)
	out.sort()
	return out


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
