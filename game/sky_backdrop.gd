extends Control
## Sky backdrop for the menu screens: a vertical blue-to-white gradient with
## a few soft clouds near the top. Home (#72) uses it now; the loading view
## (#69) should reuse it.
##
## The clouds drift right and wrap around (#167). Fainter clouds read as
## farther away, so they move slower, and each one floats gently up and down.
## The motion runs off the engine clock rather than a per-node timer, so the
## clouds stay put when one screen's backdrop hands off to the next.

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

## How fast the nearest cloud drifts, in points per second.
const DRIFT_SPEED := 12.0
## Opacities that map to full speed and to standing still. Speed scales
## linearly between them, so the 0.85 / 0.7 / 0.55 clouds move at
## 100% / 70% / 40% of DRIFT_SPEED.
const NEAR_OPACITY := 0.85
const FAR_OPACITY := 0.35
## How far past each edge (at 390 wide) a cloud travels before it wraps,
## so it's fully offscreen when it jumps.
const DRIFT_MARGIN := 100.0
## How far each cloud floats up and down, in points, and how many seconds
## one float takes.
const BOB_HEIGHT := 4.0
const BOB_PERIOD := 12.0
## Seconds between clouds in the float, so they don't rise together.
const BOB_STAGGER := 4.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


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
	var seconds := Time.get_ticks_msec() / 1000.0
	for c in CLOUDS.size():
		var cloud: Array = CLOUDS[c]
		# Opaque, pre-blended with the sky behind it, so overlapping puffs
		# don't stack up brighter than the cloud as a whole.
		var color := sky_color(CLOUD_TOP + cloud[1][0].y).lerp(Color.WHITE, cloud[0])
		var shift := cloud_shift(c, seconds, w)
		for i in range(1, cloud.size()):
			var center: Vector2 = cloud[i][0]
			var radii: Vector2 = cloud[i][1]
			draw_colored_polygon(ellipse(Vector2(center.x * stretch, CLOUD_TOP + center.y) + shift, radii), color)


## How far cloud `index` has moved from where CLOUDS puts it, `seconds` in,
## on a backdrop `width` points wide. x drifts right and wraps once the
## cloud's first puff is DRIFT_MARGIN past the right edge; y floats.
static func cloud_shift(index: int, seconds: float, width: float) -> Vector2:
	var cloud: Array = CLOUDS[index]
	var stretch := width / 390.0
	var margin := DRIFT_MARGIN * maxf(stretch, 1.0)
	var home := (cloud[1][0] as Vector2).x * stretch
	var x := fposmod(home + margin + seconds * drift_speed(cloud[0]), width + 2.0 * margin) - margin
	var y := sin(TAU * (seconds + index * BOB_STAGGER) / BOB_PERIOD) * BOB_HEIGHT
	return Vector2(x - home, y)


## Drift speed, in points per second, for a cloud of this opacity.
static func drift_speed(opacity: float) -> float:
	return DRIFT_SPEED * clampf((opacity - FAR_OPACITY) / (NEAR_OPACITY - FAR_OPACITY), 0.0, 1.0)


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
