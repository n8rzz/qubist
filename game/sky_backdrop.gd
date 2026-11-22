extends Control
## Sky backdrop for the menu screens: a vertical blue-to-white gradient with
## a few soft clouds near the top. Home (#72) uses it now; the loading view
## (#69) should reuse it.

const TOP := Color("#9FD3EE")
const MIDDLE := Color("#CBE8F6")
const BOTTOM := Color("#F3FAFD")
## Where MIDDLE sits, as a fraction of the height.
const MIDDLE_AT := 0.42

## Clouds as [opacity, [center, radii]...], laid out on a 390-point-wide
## band that starts CLOUD_TOP points down. x stretches with the width.
const CLOUD_TOP := 70.0
const CLOUDS := [
	[0.85, [Vector2(54, 62), Vector2(38, 13)], [Vector2(74, 52), Vector2(22, 15)], [Vector2(44, 54), Vector2(15, 11)]],
	[0.7, [Vector2(330, 150), Vector2(44, 12)], [Vector2(312, 140), Vector2(20, 13)], [Vector2(344, 138), Vector2(17, 11)]],
	[0.55, [Vector2(300, 40), Vector2(24, 7)], [Vector2(292, 35), Vector2(11, 7)]],
]


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var mid := size.y * MIDDLE_AT
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, mid), Vector2(0, mid)]),
		PackedColorArray([TOP, TOP, MIDDLE, MIDDLE]))
	draw_polygon(PackedVector2Array([Vector2(0, mid), Vector2(w, mid), Vector2(w, size.y), Vector2(0, size.y)]),
		PackedColorArray([MIDDLE, MIDDLE, BOTTOM, BOTTOM]))

	var stretch := w / 390.0
	for cloud in CLOUDS:
		# Opaque, pre-blended with the sky behind it, so overlapping puffs
		# don't stack up brighter than the cloud as a whole.
		var color := sky_color(CLOUD_TOP + cloud[1][0].y).lerp(Color.WHITE, cloud[0])
		for i in range(1, cloud.size()):
			var center: Vector2 = cloud[i][0]
			var radii: Vector2 = cloud[i][1]
			draw_colored_polygon(ellipse(Vector2(center.x * stretch, CLOUD_TOP + center.y), radii), color)


## The gradient's color `y` points down.
func sky_color(y: float) -> Color:
	var t := clampf(y / maxf(size.y, 1.0), 0.0, 1.0)
	if t < MIDDLE_AT:
		return TOP.lerp(MIDDLE, t / MIDDLE_AT)
	return MIDDLE.lerp(BOTTOM, (t - MIDDLE_AT) / (1.0 - MIDDLE_AT))


static func ellipse(center: Vector2, radii: Vector2, segments := 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var a := i * TAU / segments
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
