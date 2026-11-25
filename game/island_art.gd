extends Control
## The tower on its floating island, drawn flat in 2D for the Home screen
## (#72): earth underside, brick rim, grass, a water channel, the 6×6 floor,
## a dashed outline of the tower and stone cubes in it.
##
## Shapes follow the Home design, in its units: a cube edge runs 17.32 across
## and 10 down per cell, and 20 up per layer, with the floor's back corner at
## the origin. The art scales to fit the control.
##
## It wears the season in game/sky_view.gd (#168): grass, water and bushes change
## colour, snow lies on the cubes in winter, the water glints and the light
## follows the time of day. Home adds the season's tree with draw_tree().

const DrawUtil := preload("res://game/draw_util.gd")
const SkyView := preload("res://game/sky_view.gd")

## Segments for the bush and loading shadow ellipses.
const ELLIPSE_SEGMENTS := 24

## Cells to draw, as core Vector3i(x, y, h) with h in .z.
var cells: Array = []

## The art's bounds in its own units: the design's view box, extended down
## past the island's underside (it ends at y 193) so nothing below the art
## covers it.
const VIEW := Rect2(-146.6, -256.0, 305.1, 461.0)
const CELL_X := 17.32
const CELL_Y := 10.0
const LAYER := 20.0
const GRID := Vector3i(6, 6, 12)

const EARTH_LEFT := Color("#8E6B4F")
const EARTH_RIGHT := Color("#A47C5B")
const EARTH_EDGE := Color("#6E523C")
const EARTH_STRATA := Color("#7E5E45", 0.55)
const BRICK_LEFT := Color("#C77E54")
const BRICK_RIGHT := Color("#D8956A")
const BRICK_EDGE := Color("#8F5235")
const MORTAR := Color("#F0C9A8", 0.8)
const GRASS_LEFT := Color("#7DB34A")
const GRASS_RIGHT := Color("#8BC152")
const GRASS := Color("#9CCD63")
const GRASS_EDGE := Color("#6E9E3E")
const WATER := Color("#79C6E0")
const WATER_EDGE := Color("#4E9DBB")
const RIPPLE := Color("#E6F7FC")
const FLOOR := Color("#B7DE83")
const FLOOR_EDGE := Color("#7FAE4E")
const FLOOR_LINES := Color(1, 1, 1, 0.55)
const BUSH := Color("#5E9E3A")
const BUSH_LIGHT := Color("#76B84A")
const BUSH_SHADOW := Color(40 / 255.0, 70 / 255.0, 30 / 255.0, 0.25)
const ROCK := Color("#C9C1B3")
const OUTLINE_BACK := Color(1, 1, 1, 0.9)
const OUTLINE_FRONT := Color(1, 1, 1, 0.55)

const CUBE_TOP := Color("#ECE7DD")
const CUBE_TOP_INSET := Color("#F6F2EA")
const CUBE_LEFT := Color("#B7AD9D")
const CUBE_LEFT_INSET := Color("#C2B9AA")
const CUBE_RIGHT := Color("#D3CABB")
const CUBE_RIGHT_INSET := Color("#DCD4C6")
const CUBE_EDGE := Color("#857B6D")
## Each face's lighter inset is the face shrunk by this much toward its
## center, which reads as a bevel.
const INSET := 0.78
## The tree stands at the grass's front-left corner, in grid cells.
const TREE_SPOT := Vector2(-0.45, 6.6)
const TREE_SHADOW := Color(40 / 255.0, 60 / 255.0, 30 / 255.0, 0.22)
## The tree sways this far either way, over TREE_SWAY_SECONDS.
const TREE_SWAY := deg_to_rad(2.5)
const TREE_SWAY_SECONDS := 4.5
## The water's ripples glint, over GLINT_SECONDS.
const GLINT_SECONDS := 2.6


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Internal, so subclasses can switch their own processing on and off.
	set_process_internal(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_INTERNAL_PROCESS and is_visible_in_tree():
		# The tree sways, the water glints and the season can change.
		self_modulate = SkyView.tint()
		queue_redraw()


func set_cells(next: Array) -> void:
	cells = next
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x / VIEW.size.x, size.y / VIEW.size.y)
	if s <= 0.0:
		return
	draw_set_transform(size * 0.5 - VIEW.get_center() * s, 0.0, Vector2(s, s))
	_draw_island()
	_draw_outline_back()
	var sorted := cells.duplicate()
	# Back to front: unit cubes on a grid never overlap out of this order.
	sorted.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x + a.y + a.z < b.x + b.y + b.z)
	for c in sorted:
		_draw_cube(c)
	_draw_outline_front()
	draw_tree()
	draw_set_transform(Vector2.ZERO)


## `color` as the current season paints it.
static func paint(color: Color) -> Color:
	return SkyView.island_color(color)


## Screen point of grid corner (x, y) at layer height h.
static func iso(x: float, y: float, h: float) -> Vector2:
	return Vector2((x - y) * CELL_X, (x + y) * CELL_Y - h * LAYER)


func _draw_island() -> void:
	_shape([-138.56, 77, -117.78, 109, -96.99, 127, -71.01, 160, 0, 193, 0, 157], paint(EARTH_LEFT), paint(EARTH_EDGE), 0.6)
	_shape([0, 157, 0, 193, 69.28, 161, 93.53, 131, 119.51, 106, 138.56, 77], paint(EARTH_RIGHT), paint(EARTH_EDGE), 0.6)
	draw_polyline(PackedVector2Array([Vector2(-128.17, 94), Vector2(0, 173), Vector2(124.71, 96)]),
		paint(EARTH_STRATA), 0.8, true)
	# The lower one starts further in, where the underside has narrowed.
	draw_polyline(PackedVector2Array([Vector2(-110, 119.2), Vector2(0, 187), Vector2(110, 119.1)]),
		paint(EARTH_STRATA), 0.8, true)

	_shape([-138.56, 60, 0, 140, 0, 157, -138.56, 77], paint(BRICK_LEFT), paint(BRICK_EDGE), 0.6)
	_shape([138.56, 60, 0, 140, 0, 157, 138.56, 77], paint(BRICK_RIGHT), paint(BRICK_EDGE), 0.6)
	draw_polyline(PackedVector2Array([Vector2(138.56, 68.5), Vector2(0, 148.5), Vector2(-138.56, 68.5)]),
		paint(MORTAR), 0.7, true)
	# Brick joints, one per cell along each course; the lower course is
	# offset by half a cell.
	for i in range(8):
		var y := 70.0 + 10.0 * i
		var x := 17.32 * (7 - i)
		if i < 7:
			draw_line(Vector2(-x, y), Vector2(-x, y + 8.5), paint(MORTAR), 0.7)
			draw_line(Vector2(x, y), Vector2(x, y + 8.5), paint(MORTAR), 0.7)
		draw_line(Vector2(-x - 8.66, y + 3.5), Vector2(-x - 8.66, y + 12), paint(MORTAR), 0.7)
		draw_line(Vector2(x + 8.66, y + 3.5), Vector2(x + 8.66, y + 12), paint(MORTAR), 0.7)

	_shape([-138.56, 60, 0, 140, 0, 143.2, -129.9, 70.12, -138.56, 63.2], paint(GRASS_LEFT))
	_shape([138.56, 60, 0, 140, 0, 143.2, 128.17, 71.44, 138.56, 63.2], paint(GRASS_RIGHT))
	_shape([0, -20, 138.56, 60, 0, 140, -138.56, 60], paint(GRASS), paint(GRASS_EDGE), 0.6)
	_shape([0, -7.6, 117.09, 60, 0, 127.6, -117.09, 60], paint(WATER), paint(WATER_EDGE), 0.6)
	var glint := paint(RIPPLE)
	glint.a *= 0.675 - 0.325 * cos(TAU * SkyView.seconds() / GLINT_SECONDS)
	for r in [[86.43, 73.9, 74.3, 80.9], [44.86, 97.9, 32.74, 104.9], [-72.57, 81.9, -60.45, 88.9], [-27.54, 107.9, -15.42, 114.9]]:
		draw_line(Vector2(r[0], r[1]), Vector2(r[2], r[3]), glint, 1.4, true)

	_shape([0, 0, 103.92, 60, 0, 120, -103.92, 60], paint(FLOOR), paint(FLOOR_EDGE), 0.8)
	for i in range(1, GRID.x):
		draw_line(iso(i, 0, 0), iso(i, GRID.y, 0), paint(FLOOR_LINES), 0.6, true)
		draw_line(iso(0, i, 0), iso(GRID.x, i, 0), paint(FLOOR_LINES), 0.6, true)

	_bush(Vector2(122.46, 62.7), 1.0)
	_bush(Vector2(-122.11, 62.5), 0.857)
	_shape([-6, 130.6, -2.4, 125, 3.6, 125.8, 6, 130.6], paint(ROCK), paint(CUBE_EDGE), 0.6)


func _bush(base: Vector2, k: float) -> void:
	draw_colored_polygon(DrawUtil.ellipse(base, Vector2(9.24, 3.78) * k, ELLIPSE_SEGMENTS), paint(BUSH_SHADOW))
	var top := base - Vector2(0, 6.88 * k)
	draw_circle(top, 8.4 * k, paint(BUSH))
	draw_circle(top - Vector2(2.1, 2.1) * k, 4.62 * k, paint(BUSH_LIGHT))


## The tower's back edges, behind the cubes.
func _draw_outline_back() -> void:
	var h := GRID.z
	var top_back := iso(0, 0, h)
	for line in [
		[iso(0, 0, 0), top_back],
		[top_back, iso(GRID.x, 0, h)],
		[top_back, iso(0, GRID.y, h)],
		[iso(GRID.x, 0, 0), iso(GRID.x, 0, h)],
		[iso(0, GRID.y, 0), iso(0, GRID.y, h)],
	]:
		draw_dashed_line(line[0], line[1], OUTLINE_BACK, 0.9, 4.4)


## The tower's front edges, faint, over the cubes.
func _draw_outline_front() -> void:
	var h := GRID.z
	var top_front := iso(GRID.x, GRID.y, h)
	for line in [
		[iso(GRID.x, GRID.y, 0), top_front],
		[iso(GRID.x, 0, h), top_front],
		[iso(0, GRID.y, h), top_front],
	]:
		draw_dashed_line(line[0], line[1], OUTLINE_FRONT, 0.9, 4.4)


## Draws one cube; `alpha` fades it (the loading view's falling cubes, #69).
func _draw_cube(c: Vector3i, alpha := 1.0) -> void:
	var x := c.x
	var y := c.y
	var h := c.z
	_face([iso(x, y, h + 1), iso(x + 1, y, h + 1), iso(x + 1, y + 1, h + 1), iso(x, y + 1, h + 1)],
		SkyView.snowy_top(CUBE_TOP), SkyView.snowy_top_inset(CUBE_TOP_INSET), alpha)
	_face([iso(x, y + 1, h + 1), iso(x + 1, y + 1, h + 1), iso(x + 1, y + 1, h), iso(x, y + 1, h)],
		CUBE_LEFT, CUBE_LEFT_INSET, alpha)
	_face([iso(x + 1, y + 1, h + 1), iso(x + 1, y, h + 1), iso(x + 1, y, h), iso(x + 1, y + 1, h)],
		CUBE_RIGHT, CUBE_RIGHT_INSET, alpha)


func _face(corners: Array, color: Color, inset: Color, alpha := 1.0) -> void:
	color.a *= alpha
	inset.a *= alpha
	var edge := Color(CUBE_EDGE, CUBE_EDGE.a * alpha)
	var points := PackedVector2Array(corners)
	var center := (points[0] + points[2]) * 0.5
	var inner := PackedVector2Array()
	for p in points:
		inner.append(center + (p - center) * INSET)
	draw_colored_polygon(points, color)
	draw_colored_polygon(inner, inset)
	points.append(points[0])
	draw_polyline(points, edge, 0.7, true)


## The season's tree at the grass's front-left corner, swaying from its
## foot, in front of the tower. Crossfades with the season.
func draw_tree() -> void:
	var base := iso(TREE_SPOT.x, TREE_SPOT.y, 0)
	var turn := TREE_SWAY * sin(TAU * SkyView.seconds() / TREE_SWAY_SECONDS)
	var at := func(offset: Vector2) -> Vector2: return base + offset.rotated(turn)
	for layer in SkyView.layers():
		var a: float = layer[2]
		var tree: Array = SkyView.TREES[layer[0]]
		var trunk: Color = tree[0]
		var canopy: Array = tree[1]
		draw_colored_polygon(DrawUtil.ellipse(base + Vector2(0, 2), Vector2(16, 5), ELLIPSE_SEGMENTS),
			Color(TREE_SHADOW, TREE_SHADOW.a * a))
		draw_colored_polygon(PackedVector2Array([at.call(Vector2.ZERO), at.call(Vector2(-3, -34)), at.call(Vector2(3, -34))]),
			Color(trunk, a))
		if canopy.is_empty():
			for branch in [[Vector2(0, -24), Vector2(-12, -38)], [Vector2(0, -30), Vector2(10, -42)],
					[Vector2(-6, -32), Vector2(-14, -41)], [Vector2(5, -36), Vector2(12, -44)]]:
				draw_line(at.call(branch[0]), at.call(branch[1]), Color(trunk, a), 2.4, true)
			for lump in [[-12, -38, 4.0], [10, -42, 4.5], [-8, -42, 3.0], [7, -44, 3.0], [0, -36, 3.5]]:
				draw_colored_polygon(DrawUtil.ellipse(at.call(Vector2(lump[0], lump[1])), Vector2(lump[2], lump[2] * 0.6), 16),
					Color(1, 1, 1, a))
			continue
		for puff in [[-9, -38, 13.0, 0], [9, -40, 12.0, 2], [0, -50, 13.0, 1], [0, -38, 10.0, 1]]:
			draw_circle(at.call(Vector2(puff[0], puff[1])), puff[2], Color(canopy[puff[3]], a), true, -1.0, true)
		if layer[0] == "spring":
			for i in 10:
				var dot := Vector2(-18 + 36 * DrawUtil.rand(i, 7), -60 + 32 * DrawUtil.rand(i, 8))
				draw_circle(at.call(dot), 1.6, Color(1, 1, 1, a), true, -1.0, true)
		elif layer[0] == "fall":
			for i in 5:
				var leaf := base + Vector2(-22 + 44 * DrawUtil.rand(i, 9), -2 + 6 * DrawUtil.rand(i, 10))
				draw_colored_polygon(DrawUtil.ellipse(leaf, Vector2(2.4, 1.4), 12), Color("#C8502A", a))


## A filled polygon from flat [x, y, ...] coordinates, with an optional edge.
func _shape(coords: Array, fill: Color, edge := Color(0, 0, 0, 0), width := 0.0) -> void:
	var points := PackedVector2Array()
	for i in range(0, coords.size(), 2):
		points.append(Vector2(coords[i], coords[i + 1]))
	draw_colored_polygon(points, fill)
	if width > 0.0:
		points.append(points[0])
		draw_polyline(points, edge, width, true)
