extends Control
## Sky backdrop for every screen: a vertical gradient with a few soft clouds
## near the top. Home (#72), the game, Stats and the loading view (#69) each
## add one.
##
## It shows the season and time of day in game/sky_view.gd (#168): the gradient,
## stars and northern lights, the sun or moon with its glow, clouds tinted to
## match, birds and morning mist. Back to front, as in the design. A change
## crossfades over SkyView.CROSSFADE_SECONDS. Falling petals, leaves, snow and
## fireflies go in front of the island, in game/sky_weather.gd.
##
## The clouds drift right and wrap around (#167). Fainter clouds read as
## farther away, so they move slower, and each one floats gently up and down.
## The motion runs off the engine clock rather than a per-node timer, so the
## clouds stay put when one screen's backdrop hands off to the next. Under
## Reduce Motion (SkyView.still) everything stands still.
##
## Positions are in the design's 390-point-wide frame: x stretches with the
## width, y is in points from the top.

const SkyView := preload("res://game/sky_view.gd")

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

## Sun by time of day: [center, radius, light colour, deep colour].
const SUNS := {
	"sunrise": [Vector2(52, 300), 36.0, Color("#FFD27A"), Color("#FFB86B")],
	"day": [Vector2(300, 120), 30.0, Color("#FFE27A"), Color("#FFD24D")],
	"sunset": [Vector2(290, 318), 42.0, Color("#FF9E5E"), Color("#FF7A45")],
}
## The sun floats this far up and down over SUN_BOB_PERIOD seconds.
const SUN_BOB := 6.0
const SUN_BOB_PERIOD := 14.0
## The day sun's rays: one full turn takes this many seconds.
const RAY_TURN_SECONDS := 40.0
const MOON_CENTER := Vector2(316, 174)
const MOON_RADIUS := 22.0
const MOON := Color("#F4F1DE")
const MOON_CRATER := Color("#DDD8BF")
const STAR_COUNT := 46
## Stars sit above this line, in points.
const STAR_BAND := 470.0
## Birds by season and time; geese fly in a V.
const BIRD_VIEWS := ["spring sunrise", "spring day", "summer day", "summer sunset", "fall day", "fall sunrise"]
const BIRDS := [Vector2(0, 0), Vector2(22, 12), Vector2(8, 26)]
const GEESE := [Vector2(0, 0), Vector2(16, 8), Vector2(-14, 10), Vector2(30, 16), Vector2(-28, 20)]
const BIRD_TOP := 230.0
const BIRD_CROSSING_SECONDS := 20.0
const MIST_VIEWS := ["spring sunrise", "fall sunrise"]
## Mist banks as [left, top, width, opacity].
const MIST := [[40.0, 420.0, 300.0, 0.55], [70.0, 470.0, 360.0, 0.45], [100.0, 520.0, 280.0, 0.5]]


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
	var stops := SkyView.gradient_stops()
	for i in range(1, stops.size()):
		var top := stops[i - 1] * size.y
		var bottom := stops[i] * size.y
		var a := SkyView.sky_color(stops[i - 1])
		var b := SkyView.sky_color(stops[i])
		draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, bottom), Vector2(0, bottom)]),
			PackedColorArray([a, a, b, b]))

	var k := w / 390.0
	var seconds := SkyView.seconds()
	var layers := SkyView.layers()
	for layer in layers:
		if layer[1] == "night":
			_draw_stars(k, seconds, layer[2])
			if layer[0] == "winter":
				_draw_aurora(k, seconds, layer[2])
			_draw_moon(k, seconds, layer[2])
		else:
			_draw_sun(layer[1], k, seconds, layer[2])

	var tint := SkyView.cloud_color()
	var strength := SkyView.cloud_opacity()
	for c in CLOUDS.size():
		var cloud: Array = CLOUDS[c]
		# Opaque, pre-blended with the sky behind it, so overlapping puffs
		# don't stack up brighter than the cloud as a whole.
		var color := sky_color(CLOUD_TOP + cloud[1][0].y).lerp(tint, cloud[0] * strength)
		var shift := cloud_shift(c, seconds, w)
		for i in range(1, cloud.size()):
			var center: Vector2 = cloud[i][0]
			var radii: Vector2 = cloud[i][1]
			draw_colored_polygon(ellipse(Vector2(center.x * k, CLOUD_TOP + center.y) + shift, radii), color)

	for layer in layers:
		var view: String = "%s %s" % [layer[0], layer[1]]
		if BIRD_VIEWS.has(view):
			_draw_birds(layer[0] == "fall", layer[1] == "day", k, seconds, layer[2])
		if MIST_VIEWS.has(view):
			_draw_mist(k, seconds, layer[2])


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
	return SkyView.sky_color(y / maxf(size.y, 1.0))


## A repeatable random number in [0, 1) for item `i`, draw `k`.
static func rand(i: int, k: int) -> float:
	var v := sin(i * 12.9898 + k * 78.233) * 43758.5453
	return v - floorf(v)


func _draw_stars(k: float, seconds: float, alpha: float) -> void:
	for i in STAR_COUNT:
		var radius: float = [1.0, 1.0, 1.5, 2.0][int(rand(i, 3) * 4.0)]
		var period := 2.0 + 3.0 * rand(i, 4)
		var twinkle := 0.6 - 0.4 * cos(TAU * (seconds / period + rand(i, 5)))
		var at := Vector2((6.0 + 378.0 * rand(i, 1)) * k, 8.0 + STAR_BAND * rand(i, 2))
		draw_circle(at, radius, Color(1, 1, 1, twinkle * alpha), true, -1.0, true)


## Two rippling bands of green fading to violet (winter nights).
func _draw_aurora(k: float, seconds: float, alpha: float) -> void:
	var phase := sin(TAU * seconds / 9.0)
	var sway := 24.0 * phase
	var strength := (0.725 + 0.225 * phase) * alpha
	for band in [[205.0, 60.0, 1.0, 0.0], [160.0, 44.0, 0.6, 1.7]]:
		var steps := 24
		var top := PackedVector2Array()
		var mid := PackedVector2Array()
		var bottom := PackedVector2Array()
		for s in steps + 1:
			var u := float(s) / steps
			var x := (-35.0 + 460.0 * u) * k + sway * (1.0 - u)
			var y: float = band[0] + 40.0 * sin(TAU * u * 1.3 + band[3] + seconds * 0.2)
			top.append(Vector2(x, y - band[1]))
			mid.append(Vector2(x + sway * 0.3, y))
			bottom.append(Vector2(x, y + band[1] * 0.8))
		var edge := Color("#7CF5C4", 0.0)
		var glow := Color("#5FE3B0", 0.75 * strength * band[2])
		var foot := Color("#8E7CF5", 0.0)
		for s in steps:
			draw_polygon(PackedVector2Array([top[s], top[s + 1], mid[s + 1], mid[s]]),
				PackedColorArray([edge, edge, glow, glow]))
			draw_polygon(PackedVector2Array([mid[s], mid[s + 1], bottom[s + 1], bottom[s]]),
				PackedColorArray([glow, glow, foot, foot]))


func _draw_moon(k: float, seconds: float, alpha: float) -> void:
	var center := Vector2(MOON_CENTER.x * k, MOON_CENTER.y)
	var pulse := 0.5 - 0.5 * cos(TAU * seconds / 6.0)
	_glow(center, 46.0 * (1.0 + 0.08 * pulse), Color(MOON, 0.35 * (0.55 + 0.35 * pulse) / 0.55 * alpha))
	draw_circle(center, MOON_RADIUS, Color(MOON, alpha), true, -1.0, true)
	for crater in [[Vector2(-8, -6), 4.0], [Vector2(4, 6), 5.0], [Vector2(7, -11), 2.5]]:
		draw_circle(center + crater[0], crater[1], Color(MOON_CRATER, alpha), true, -1.0, true)


func _draw_sun(time: String, k: float, seconds: float, alpha: float) -> void:
	var sun: Array = SUNS[time]
	var radius: float = sun[1]
	var light: Color = sun[2]
	var deep: Color = sun[3]
	var pulse := 0.5 - 0.5 * cos(TAU * seconds / 5.0)
	var bob := SUN_BOB * cos(TAU * seconds / SUN_BOB_PERIOD)
	var center := Vector2(sun[0].x * k, sun[0].y + bob)
	var glow_center := Vector2(sun[0].x * k, sun[0].y)
	_glow(glow_center, radius * 2.2 * (1.0 + 0.08 * pulse), Color(light, 0.7 * (0.55 + 0.35 * pulse) * alpha))
	if time == "day":
		var turn := TAU * seconds / RAY_TURN_SECONDS
		for i in 12:
			var dir := Vector2.UP.rotated(turn + i * TAU / 12.0)
			draw_line(glow_center + dir * 40.0, glow_center + dir * 52.0, Color(deep, alpha), 4.0, true)
			draw_circle(glow_center + dir * 40.0, 2.0, Color(deep, alpha), true, -1.0, true)
			draw_circle(glow_center + dir * 52.0, 2.0, Color(deep, alpha), true, -1.0, true)
	draw_circle(center, radius, Color(deep, alpha), true, -1.0, true)
	draw_circle(center - Vector2(radius, radius) * 0.18, radius * 0.72, Color(light, 0.85 * alpha), true, -1.0, true)


## A soft round glow: `color` in the middle, fading out by 70% of `radius`.
func _glow(center: Vector2, radius: float, color: Color) -> void:
	var rings := 10
	for i in rings:
		var r := radius * 0.7 * (1.0 - float(i) / rings)
		draw_circle(center, r, Color(color, color.a / rings * 1.6), true, -1.0, true)


func _draw_birds(geese: bool, by_day: bool, k: float, seconds: float, alpha: float) -> void:
	var color := Color("#3D4A5C" if by_day else "#4A3346", alpha)
	var p := fposmod((seconds + 8.0) / BIRD_CROSSING_SECONDS, 1.0)
	var origin := Vector2((-90.0 + 570.0 * p) * k, BIRD_TOP)
	var flock: Array = GEESE if geese else BIRDS
	for i in flock.size():
		var flap := 0.25 + 0.75 * cos(TAU * (seconds / 0.6 - i * 0.28))
		var at: Vector2 = origin + flock[i] + Vector2(40, 20)
		var points := PackedVector2Array()
		for s in 9:
			var u := float(s) / 8.0
			var x := -7.0 + 14.0 * u
			var lift := sin(PI * fposmod(u * 2.0, 1.0)) * -3.75 * flap
			points.append(at + Vector2(x, lift))
		draw_polyline(points, color, 2.0, true)


func _draw_mist(k: float, seconds: float, alpha: float) -> void:
	for i in MIST.size():
		var bank: Array = MIST[i]
		var period := 10.0 + i * 3.0
		var drift := -36.0 * cos(PI * (seconds + i * 2.0) / period)
		var center := Vector2((bank[0] + bank[2] * 0.5 + drift) * k, bank[1] + 20.0)
		var rings := 8
		for r in rings:
			var f := 0.7 * (1.0 - float(r) / rings)
			draw_colored_polygon(ellipse(center, Vector2(bank[2] * 0.5 * k, 20.0) * f),
				Color(1, 1, 1, bank[3] / rings * 1.4 * alpha))


static func ellipse(center: Vector2, radii: Vector2, segments := 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var a := i * TAU / segments
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
