extends "res://game/island_art.gd"
## The loading view's art (#69): the floating island with five big stone
## cubes dropping onto it one at a time, bobbing gently over a still shadow.
##
## Follows the Loading design's 3.4 s loop: each cube falls 140 units, lands
## with a small bounce, rests, then fades out at the end of the loop. Cubes
## start 0.32 s apart. With `still` set, the cubes sit landed and nothing
## moves (Reduce Motion).

const LOOP_SECONDS := 3.4
const DROP_DELAY := 0.32
## The cubes, in drop order, in a grid of cubes two cells wide and two layers
## tall: the design's cubes are twice the size of the tower's.
const DROP_CELLS: Array[Vector3i] = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(2, 0, 0),
]
const CUBE_SCALE := 2.0

## Keyframes over one loop, as [time fraction, value]: a cube's lift above its
## spot, in design units, and its opacity.
const LIFT_KEYS := [[0.0, 140.0], [0.2, 0.0], [0.24, 8.0], [0.28, 0.0], [1.0, 0.0]]
const ALPHA_KEYS := [[0.0, 0.0], [0.08, 1.0], [0.86, 1.0], [1.0, 0.0]]
## The island bobs up this far and back once a loop.
const BOB := 6.0

## Art bounds in design units: the island plus the cubes stacked on it.
const LOADING_VIEW := Rect2(-140, -95, 280, 300)
const SHADOW := Color(31 / 255.0, 60 / 255.0, 80 / 255.0, 0.12)

## Seconds since the loading view appeared.
var time := 0.0
## Reduce Motion: cubes landed, island still.
var still := false


func _draw() -> void:
	var s := minf(size.x / LOADING_VIEW.size.x, size.y / LOADING_VIEW.size.y)
	if s <= 0.0:
		return
	var origin := size * 0.5 - LOADING_VIEW.get_center() * s
	# The shadow stays put while the island bobs above it.
	draw_set_transform(origin, 0.0, Vector2(s, s))
	draw_colored_polygon(DrawUtil.ellipse(Vector2(0, 205), Vector2(110, 14), ELLIPSE_SEGMENTS), SHADOW)

	var bob := 0.0 if still else -BOB * (1.0 - cos(TAU * time / LOOP_SECONDS)) * 0.5
	draw_set_transform(origin + Vector2(0, bob * s), 0.0, Vector2(s, s))
	_draw_island()

	var order := range(DROP_CELLS.size())
	# Back to front, as on Home.
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca := DROP_CELLS[a]
		var cb := DROP_CELLS[b]
		return ca.x + ca.y + ca.z < cb.x + cb.y + cb.z)
	for i: int in order:
		var lift := 0.0
		var alpha := 1.0
		if not still:
			var local := time - i * DROP_DELAY
			if local < 0.0:
				continue
			var t := fmod(local, LOOP_SECONDS) / LOOP_SECONDS
			lift = keyframe(LIFT_KEYS, t)
			alpha = keyframe(ALPHA_KEYS, t)
			if alpha <= 0.0:
				continue
		draw_set_transform(origin + Vector2(0, (bob - lift) * s), 0.0, Vector2(s, s) * CUBE_SCALE)
		_draw_cube(DROP_CELLS[i], alpha)
	draw_set_transform(Vector2.ZERO)


## The value of `keys` at loop fraction `t`, eased per segment like the
## design's cubic-bezier(.3, .7, .4, 1).
static func keyframe(keys: Array, t: float) -> float:
	for k in range(1, keys.size()):
		var a: Array = keys[k - 1]
		var b: Array = keys[k]
		if t <= b[0]:
			var span: float = b[0] - a[0]
			var u: float = 0.0 if span <= 0.0 else (t - a[0]) / span
			return lerpf(a[1], b[1], bezier_ease(u))
	return keys[-1][1]


## CSS cubic-bezier(.3, .7, .4, 1): progress at time `x` in [0, 1].
static func bezier_ease(x: float) -> float:
	const X1 := 0.3
	const Y1 := 0.7
	const X2 := 0.4
	const Y2 := 1.0
	if x <= 0.0 or x >= 1.0:
		return clampf(x, 0.0, 1.0)
	# Solve the curve's x(u) = x for u by bisection, then return y(u).
	var lo := 0.0
	var hi := 1.0
	var u := x
	for i in range(20):
		u = (lo + hi) * 0.5
		if _bezier(u, X1, X2) < x:
			lo = u
		else:
			hi = u
	return _bezier(u, Y1, Y2)


static func _bezier(u: float, p1: float, p2: float) -> float:
	var v := 1.0 - u
	return 3.0 * v * v * u * p1 + 3.0 * v * u * u * p2 + u * u * u
