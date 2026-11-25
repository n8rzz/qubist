extends Control
## What drifts in front of the island (#168): cherry petals in spring,
## butterflies and fireflies and floating seeds in summer, falling leaves in
## fall and snow in winter, as game/sky_view.gd's season and time of day call for.
## Dimmed and slowed at night.
##
## Add it over the island and tower but under the cards and menus; it never
## takes input. Particles fall through the top FALL_SHARE of the screen, over
## the header and the tower, and fade out before the tray. Each one's
## position is worked out from the clock, so there's nothing to simulate and
## under Reduce Motion they simply stand still.
##
## Positions are in the design's 390 × 844 frame, stretched to the control.

const SkyView := preload("res://game/sky_view.gd")
const DrawUtil := preload("res://game/draw_util.gd")

## Particles fall through this share of the height, and fade out over the
## last FADE_SHARE of it.
const FALL_SHARE := 600.0 / 844.0
const FADE_SHARE := 0.12
## Opacity of petals and leaves at night.
const NIGHT_DIM := 0.55

## Falling petals and leaves are the spring and fall canopy colours (#210),
## so the tree and what drops from it can't drift apart. Leaves add a gold.
const PETALS: Array = SkyView.TREES["spring"][1]
const LEAVES: Array = SkyView.TREES["fall"][1] + [Color("#D9A441")]
const FIREFLY := Color("#FFF3A0")
const FIREFLY_GLOW := Color(1.0, 236 / 255.0, 120 / 255.0, 0.7)
const SEED := Color(1.0, 250 / 255.0, 235 / 255.0, 0.9)
## Butterflies as [home, colour, seconds per loop].
const BUTTERFLIES := [[Vector2(60, 380), Color("#F5A3C7"), 9.0], [Vector2(250, 300), Color("#FFC94D"), 12.0]]
const BUTTERFLY_BODY := Color("#3D3A36")

## Kinds of falling things: count, size, sideways drift range, turn range in
## degrees, seconds to fall. Each kind draws its own way.
const FALLING := {
	"petal": [16, Vector2(9, 6), Vector2(-60, 80), Vector2(180, 540), Vector2(9, 15)],
	"leaf": [14, Vector2(10, 7), Vector2(-80, 80), Vector2(200, 720), Vector2(8, 13)],
	"snow": [34, Vector2(4, 8), Vector2(-30, 30), Vector2(0, 0), Vector2(7, 14)],
	"seed": [10, Vector2(4, 4), Vector2(60, 160), Vector2(0, 0), Vector2(14, 20)],
}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var k := Vector2(size.x / 390.0, size.y / 844.0)
	var seconds := SkyView.seconds()
	for layer in SkyView.layers():
		var night: bool = layer.time == "night"
		for feature in SkyView.features(layer.season, layer.time):
			match feature:
				"firefly":
					_draw_fireflies(k, seconds, layer.weight)
				"butterfly":
					_draw_butterflies(k, seconds, layer.weight)
				_:
					if FALLING.has(feature):
						_draw_falling(feature, night, k, seconds, layer.weight)


## Where falling particle `i` of `kind` is, as [position in the design
## frame, turn in radians, progress 0–1 down its fall].
static func falling_at(kind: String, i: int, seconds: float) -> Array:
	var spec: Array = FALLING[kind]
	var salt := 17 * (FALLING.keys().find(kind) + 1)
	var duration := lerpf(spec[4].x, spec[4].y, DrawUtil.rand(i + salt, 1))
	var p := fposmod(seconds / duration + DrawUtil.rand(i + salt, 2), 1.0)
	var drift := lerpf(spec[2].x, spec[2].y, DrawUtil.rand(i + salt, 3))
	var turn := deg_to_rad(lerpf(spec[3].x, spec[3].y, DrawUtil.rand(i + salt, 4)))
	var x := 380.0 * DrawUtil.rand(i + salt, 5) + drift * p
	return [Vector2(x, -40.0 + 680.0 * p), turn * p, p]


func _draw_falling(kind: String, night: bool, k: Vector2, seconds: float, alpha: float) -> void:
	var spec: Array = FALLING[kind]
	var salt := 17 * (FALLING.keys().find(kind) + 1)
	var bottom := size.y * FALL_SHARE
	for i in int(spec[0]):
		var at: Array = falling_at(kind, i, seconds)
		var pos := Vector2(at[0].x * k.x, at[0].y * k.y)
		if pos.y > bottom:
			continue
		var fade := clampf((bottom - pos.y) / (size.y * FADE_SHARE), 0.0, 1.0) * alpha
		var pick := DrawUtil.rand(i + salt, 6)
		match kind:
			"petal":
				var color: Color = PETALS[int(pick * PETALS.size())]
				color.a = (NIGHT_DIM if night else 1.0) * fade
				_blob(pos, spec[1] * 0.5, at[1], color, 0.0)
			"leaf":
				var color: Color = LEAVES[int(pick * LEAVES.size())]
				color.a = (NIGHT_DIM if night else 1.0) * fade
				_blob(pos, spec[1] * 0.5, at[1], color, 1.0)
			"snow":
				var diameter: float = [4.0, 5.0, 6.0, 8.0][int(pick * 4.0)]
				var opacity := (0.9 if diameter > 5.0 else 0.7) * (0.85 if night else 1.0)
				draw_circle(pos, diameter * 0.5, Color(1, 1, 1, opacity * fade), true, -1.0, true)
			"seed":
				draw_circle(pos, 3.5, Color(1, 1, 1, 0.25 * fade), true, -1.0, true)
				draw_circle(pos, 2.0, Color(SEED, SEED.a * fade), true, -1.0, true)


## A petal (round, `point` 0) or leaf (pointed at both ends, `point` 1).
func _blob(center: Vector2, radii: Vector2, turn: float, color: Color, point: float) -> void:
	var points := PackedVector2Array()
	for s in 16:
		var a := s * TAU / 16.0
		var v := Vector2(cos(a) * radii.x, sin(a) * radii.y)
		# A leaf pinches toward two opposite corners.
		v.y *= lerpf(1.0, absf(cos(a)) * 0.4 + 0.6 * absf(sin(a)), point)
		points.append(center + v.rotated(turn))
	draw_colored_polygon(points, color)


func _draw_fireflies(k: Vector2, seconds: float, alpha: float) -> void:
	for i in 14:
		var period := 3.0 + 3.0 * DrawUtil.rand(i + 300, 1)
		var p := fposmod(seconds / period + DrawUtil.rand(i + 300, 2), 1.0)
		# Out and back along a short diagonal, blinking twice on the way.
		var reach := 1.0 - absf(1.0 - 2.0 * p)
		var home := Vector2(30.0 + 330.0 * DrawUtil.rand(i + 300, 3), 250.0 + 310.0 * DrawUtil.rand(i + 300, 4))
		var at := home + Vector2(14, -12) * reach
		var blink := 0.575 - 0.425 * cos(TAU * p * 2.0)
		var pos := Vector2(at.x * k.x, at.y * k.y)
		draw_circle(pos, 6.0, Color(FIREFLY_GLOW, 0.3 * blink * alpha), true, -1.0, true)
		draw_circle(pos, 2.5, Color(FIREFLY, blink * alpha), true, -1.0, true)


func _draw_butterflies(k: Vector2, seconds: float, alpha: float) -> void:
	for j in BUTTERFLIES.size():
		var spec: Array = BUTTERFLIES[j]
		var p := fposmod((seconds + j * 4.0) / spec[2], 1.0)
		# A loop: up and right, down, back under and home.
		var a := TAU * p
		var offset := Vector2(40.0 - 40.0 * cos(a), -30.0 * sin(a) if sin(a) > 0.0 else -24.0 * sin(a))
		var at: Vector2 = spec[0] + offset
		var pos := Vector2(at.x * k.x, at.y * k.y)
		var wing := 0.6 + 0.4 * cos(TAU * seconds / 0.35)
		var color := Color(spec[1], alpha)
		for side in [-1.0, 1.0]:
			draw_colored_polygon(DrawUtil.ellipse(pos + Vector2(4.5 * side * wing, -1), Vector2(4.5 * wing, 5), 16), color)
		draw_rect(Rect2(pos - Vector2(0.8, 5), Vector2(1.6, 10)), Color(BUTTERFLY_BODY, alpha))
