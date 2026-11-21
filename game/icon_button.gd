extends Button
## A button that draws a simple line icon instead of text, so the greybox
## needs no icon assets. Set `kind` to "pause", "settings", "rotate_left" or
## "rotate_right".

var kind := "pause"
var icon_color := Color("#333333")


func _init(p_kind: String = "pause", label: String = "") -> void:
	kind = p_kind
	tooltip_text = label
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var c := size * 0.5
	match kind:
		"pause":
			draw_rect(Rect2(c + Vector2(-6, -7), Vector2(4, 14)), icon_color)
			draw_rect(Rect2(c + Vector2(2, -7), Vector2(4, 14)), icon_color)
		"settings":
			draw_line(c + Vector2(-8, -4), c + Vector2(8, -4), icon_color, 2.0)
			draw_line(c + Vector2(-8, 4), c + Vector2(8, 4), icon_color, 2.0)
			draw_circle(c + Vector2(3, -4), 3.0, icon_color)
			draw_circle(c + Vector2(-3, 4), 3.0, icon_color)
		"rotate_left", "rotate_right":
			var dir := -1.0 if kind == "rotate_left" else 1.0
			var radius := 9.0
			var start := deg_to_rad(-90.0 - 40.0 * dir)
			var finish := start + deg_to_rad(280.0) * dir
			draw_arc(c, radius, start, finish, 32, icon_color, 2.0, true)
			var tip := c + Vector2(cos(finish), sin(finish)) * radius
			var along := Vector2(-sin(finish), cos(finish)) * dir
			var out := (tip - c).normalized()
			draw_colored_polygon(PackedVector2Array([
				tip + along * 5.0,
				tip - along * 2.0 + out * 4.5,
				tip - along * 2.0 - out * 4.5,
			]), icon_color)
