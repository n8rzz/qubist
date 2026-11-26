extends Button
## A button that draws a line icon instead of text, so the UI needs no icon
## assets. Shapes follow the 24-unit icons in the Qubist designs. Set `kind` to "home", "settings",
## "stats", "back", "close", "undo", "next", "rotate_left" or "rotate_right".
## A disabled button draws its icon faded.

var kind: String
var icon_color := Color("#22313F"):
	set(value):
		icon_color = value
		queue_redraw()


func _init(p_kind: String, label: String = "") -> void:
	kind = p_kind
	tooltip_text = label
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var c := size * 0.5
	var ink := icon_color
	if disabled:
		ink.a *= 0.35
	match kind:
		"home":
			# A roof over an open-bottomed house, as on the Settings sheet's Home row.
			draw_polyline(
				PackedVector2Array([c + Vector2(-8, -1), c + Vector2(0, -8), c + Vector2(8, -1)]),
				ink,
				2.0,
				true
			)
			draw_polyline(
				PackedVector2Array(
					[
						c + Vector2(-6, -2.5),
						c + Vector2(-6, 8),
						c + Vector2(6, 8),
						c + Vector2(6, -2.5)
					]
				),
				ink,
				2.0,
				true
			)
		"settings":
			draw_line(c + Vector2(-8, -4), c + Vector2(8, -4), ink, 2.0)
			draw_line(c + Vector2(-8, 4), c + Vector2(8, 4), ink, 2.0)
			draw_circle(c + Vector2(3, -4), 3.0, ink)
			draw_circle(c + Vector2(-3, 4), 3.0, ink)
		"stats":
			for bar in [Vector2(-7, 10), Vector2(0, 16), Vector2(7, 7)]:
				draw_line(c + Vector2(bar.x, 8), c + Vector2(bar.x, 8 - bar.y), ink, 2.0, true)
		"back":
			draw_polyline(
				PackedVector2Array([c + Vector2(4, -8), c + Vector2(-4, 0), c + Vector2(4, 8)]),
				ink,
				2.0,
				true
			)
		"undo":
			# A hook arrow: a line runs left into an arrowhead, its tail
			# curving back up and round from the right.
			draw_arc(c + Vector2(1, 1), 6.0, -PI * 0.5, PI * 0.5, 24, ink, 2.0, true)
			draw_line(c + Vector2(1, -5), c + Vector2(-7, -5), ink, 2.0, true)
			draw_line(c + Vector2(1, 7), c + Vector2(-4, 7), ink, 2.0, true)
			draw_polyline(
				PackedVector2Array([c + Vector2(-3, -9), c + Vector2(-7, -5), c + Vector2(-3, -1)]),
				ink,
				2.0,
				true
			)
		"next":
			# Skip to the next track (#166): a play triangle up against a bar.
			draw_colored_polygon(
				PackedVector2Array(
					[c + Vector2(-6, -6.5), c + Vector2(3, 0), c + Vector2(-6, 6.5)]
				),
				ink
			)
			draw_line(c + Vector2(5.5, -6.5), c + Vector2(5.5, 6.5), ink, 2.4, true)
		"close":
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), ink, 2.0, true)
			draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), ink, 2.0, true)
		"rotate_left", "rotate_right":
			# An open circle with an L-shaped arrowhead at its top-left (or
			# top-right), on the design's 24-unit grid scaled to 26 points.
			var k := 26.0 / 24.0
			var flip := 1.0 if kind == "rotate_left" else -1.0
			var start := PI if kind == "rotate_left" else 0.0
			var sweep := deg_to_rad(312.5) * flip
			draw_arc(c, 8.0 * k, start, start - sweep, 40, ink, 2.2, true)
			var corner := PackedVector2Array()
			for p in [Vector2(-8, -8), Vector2(-8, -3), Vector2(-3, -3)]:
				corner.append(c + Vector2(p.x * flip, p.y) * k)
			draw_polyline(corner, ink, 2.2, true)
