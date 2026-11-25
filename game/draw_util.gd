extends RefCounted
## Small drawing helpers shared by the sky, its weather and the island arts
## (#208): repeatable random numbers, ellipse outlines and soft glows.


## A repeatable random number in [0, 1) for item `i`, draw `k`.
static func rand(i: int, k: int) -> float:
	var v := sin(i * 12.9898 + k * 78.233) * 43758.5453
	return v - floorf(v)


## The outline of an ellipse around `center` with these `radii`, as
## `segments` points, for draw_colored_polygon().
static func ellipse(center: Vector2, radii: Vector2, segments := 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var a := i * TAU / segments
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points


## Draws a soft round glow on `canvas`: `color` in the middle, fading out by
## 70% of `radius`.
static func glow(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var rings := 10
	for i in rings:
		var r := radius * 0.7 * (1.0 - float(i) / rings)
		canvas.draw_circle(center, r, Color(color, color.a / rings * 1.6), true, -1.0, true)
