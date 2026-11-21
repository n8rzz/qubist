extends Control
## Draws a piece as small isometric cubes, from the same corner as the 3D
## camera, so it looks the way it will land. Used in the tray and while
## dragging.

const ViewMath := preload("res://game/view_math.gd")

const TOP_COLOR := Color("#EBEBEB")
const LIGHT_SIDE := Color("#D2D2D2")
const DARK_SIDE := Color("#BDBDBD")
const EDGE_COLOR := Color("#555555")

var piece = null
var step := 0
## Size of one cube edge in pixels; shrinks if the piece would not fit.
var unit := 16.0
var tint := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_piece(p, view_step: int) -> void:
	piece = p
	step = view_step
	queue_redraw()


func _draw() -> void:
	if piece == null:
		return
	var toward := ViewMath.toward_camera(step)
	var right := ViewMath.screen_right(step)
	var x_face_on_left := Vector2(signf(toward.x), 0).dot(right) < 0.0

	# Paint back to front: furthest from the camera first, then lowest first.
	var cubes: Array = piece.cells.duplicate()
	cubes.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var da := Vector2(a.x + 0.5, a.y + 0.5).dot(toward)
		var db := Vector2(b.x + 0.5, b.y + 0.5).dot(toward)
		if absf(da - db) > 0.01:
			return da < db
		return a.z < b.z)

	var faces: Array = []
	for cell in cubes:
		var c: Vector3i = cell
		var fx: int = c.x + 1 if toward.x > 0.0 else c.x
		var fy: int = c.y + 1 if toward.y > 0.0 else c.y
		faces.append([[Vector3(fx, c.y, c.z), Vector3(fx, c.y + 1, c.z), Vector3(fx, c.y + 1, c.z + 1), Vector3(fx, c.y, c.z + 1)],
			DARK_SIDE if x_face_on_left else LIGHT_SIDE])
		faces.append([[Vector3(c.x, fy, c.z), Vector3(c.x + 1, fy, c.z), Vector3(c.x + 1, fy, c.z + 1), Vector3(c.x, fy, c.z + 1)],
			LIGHT_SIDE if x_face_on_left else DARK_SIDE])
		faces.append([[Vector3(c.x, c.y, c.z + 1), Vector3(c.x + 1, c.y, c.z + 1), Vector3(c.x + 1, c.y + 1, c.z + 1), Vector3(c.x, c.y + 1, c.z + 1)],
			TOP_COLOR])

	var polys: Array = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for face in faces:
		var pts := PackedVector2Array()
		for corner in face[0]:
			var q := ViewMath.preview_point(corner, step) * unit
			pts.append(q)
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		polys.append([pts, face[1]])

	var extent := hi - lo
	var fit := minf((size.x - 8.0) / maxf(extent.x, 1.0), (size.y - 8.0) / maxf(extent.y, 1.0))
	var s := minf(1.0, fit)
	var offset := size * 0.5 - (lo + hi) * 0.5 * s
	for poly in polys:
		var src: PackedVector2Array = poly[0]
		var pts := PackedVector2Array()
		for q in src:
			pts.append(q * s + offset)
		draw_colored_polygon(pts, poly[1] * tint)
		pts.append(pts[0])
		draw_polyline(pts, EDGE_COLOR * tint, 1.0, true)
