extends Button
## A button that draws a line icon instead of text, so the UI needs no icon
## assets. Shapes follow the 24-unit icons in the Qubist designs. Set `kind` to "pause", "settings", "gear", "stats",
## "back", "close", "rotate_left" or "rotate_right".

var kind := "pause"
var icon_color := Color("#22313F")


func _init(p_kind: String = "pause", label: String = "") -> void:
	kind = p_kind
	tooltip_text = label
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var c := size * 0.5
	match kind:
		"pause":
			var bar := StyleBoxFlat.new()
			bar.bg_color = icon_color
			bar.set_corner_radius_all(2)
			bar.anti_aliasing = true
			draw_style_box(bar, Rect2(c + Vector2(-5.5, -7), Vector2(3.5, 14)))
			draw_style_box(bar, Rect2(c + Vector2(2, -7), Vector2(3.5, 14)))
		"settings":
			draw_line(c + Vector2(-8, -4), c + Vector2(8, -4), icon_color, 2.0)
			draw_line(c + Vector2(-8, 4), c + Vector2(8, 4), icon_color, 2.0)
			draw_circle(c + Vector2(3, -4), 3.0, icon_color)
			draw_circle(c + Vector2(-3, 4), 3.0, icon_color)
		"gear":
			draw_arc(c, 3.2, 0.0, TAU, 24, icon_color, 2.0, true)
			draw_arc(c, 6.6, 0.0, TAU, 32, icon_color, 2.0, true)
			for i in range(8):
				var dir := Vector2.from_angle(i * TAU / 8.0)
				draw_line(c + dir * 7.8, c + dir * 10.0, icon_color, 2.0, true)
		"stats":
			for bar in [Vector2(-7, 10), Vector2(0, 16), Vector2(7, 7)]:
				draw_line(c + Vector2(bar.x, 8), c + Vector2(bar.x, 8 - bar.y), icon_color, 2.0, true)
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(4, -8), c + Vector2(-4, 0), c + Vector2(4, 8)]),
				icon_color, 2.0, true)
		"close":
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), icon_color, 2.0, true)
			draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), icon_color, 2.0, true)
		"rotate_left", "rotate_right":
			# An open circle with an L-shaped arrowhead at its top-left (or
			# top-right), on the design's 24-unit grid scaled to 26 points.
			var k := 26.0 / 24.0
			var flip := 1.0 if kind == "rotate_left" else -1.0
			var start := PI if kind == "rotate_left" else 0.0
			var sweep := deg_to_rad(312.5) * flip
			draw_arc(c, 8.0 * k, start, start - sweep, 40, icon_color, 2.2, true)
			var corner := PackedVector2Array()
			for p in [Vector2(-8, -8), Vector2(-8, -3), Vector2(-3, -3)]:
				corner.append(c + Vector2(p.x * flip, p.y) * k)
			draw_polyline(corner, icon_color, 2.2, true)
