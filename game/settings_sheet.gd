extends Control
## Settings bottom sheet, opened from the header gear (#20).
##
## For now it holds only the Game › Stats row (#32). The sound and haptics
## toggles and Replay tutorial come with #20 and #29.

const UI := preload("res://game/ui_style.gd")

signal stats_pressed
signal closed

const SHEET_RADIUS := 28
const ROW_HEIGHT := 52

var stats_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Tapping the dimmed game behind the sheet closes it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := UI.box(UI.BG, UI.LINE, SHEET_RADIUS, 2,
		Vector2(UI.SIDE_MARGIN + 4, 20))
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_width_bottom = 0
	style.content_margin_bottom = UI.SAFE_BOTTOM + 12
	sheet.add_theme_stylebox_override("panel", style)
	add_child(sheet)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	sheet.add_child(column)

	var header := HBoxContainer.new()
	header.add_child(UI.label("Settings", 24, UI.INK))
	header.add_child(UI.spacer())
	var close := UI.icon_button("close", "Close settings")
	close.pressed.connect(close_sheet)
	header.add_child(close)
	column.add_child(header)

	column.add_child(UI.label("GAME", 12, UI.MUTED))
	stats_button = _row("Stats")
	stats_button.pressed.connect(func(): stats_pressed.emit())
	column.add_child(stats_button)


func open() -> void:
	visible = true


func close_sheet() -> void:
	visible = false
	closed.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_sheet()
		accept_event()


## A full-width list row: name on the left, a chevron on the right.
func _row(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = ROW_HEIGHT
	b.add_theme_font_size_override("font_size", 17)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, UI.INK)
	var padding := Vector2(16, 0)
	b.add_theme_stylebox_override("normal", UI.box(UI.WHITE, UI.LINE, 16, 2, padding))
	b.add_theme_stylebox_override("hover", UI.box(Color("#F0F0EE"), UI.LINE, 16, 2, padding))
	b.add_theme_stylebox_override("pressed", UI.box(Color("#E2E2E0"), UI.LINE, 16, 2, padding))
	b.icon = _chevron()
	return b


static func _chevron() -> ImageTexture:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			# Distance to the two strokes of a ">" centered in the image.
			var p := Vector2(x + 0.5, y + 0.5)
			var d := minf(_segment_distance(p, Vector2(5, 3), Vector2(11, 8)),
				_segment_distance(p, Vector2(11, 8), Vector2(5, 13)))
			img.set_pixel(x, y, UI.MUTED * Color(1, 1, 1, clampf(1.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
