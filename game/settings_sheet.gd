extends Control
## Settings bottom sheet, opened from the header gear (#20).
##
## Holds the Game › Stats row (#32), Game › Home (#72) and the Display ›
## Grid ticks switch (#56). The sound and haptics toggles and Replay tutorial come with #20
## and #29.

const UI := preload("res://game/ui_style.gd")

signal stats_pressed
signal home_pressed
signal grid_ticks_toggled(on: bool)
signal closed

const SHEET_RADIUS := 28
const ROW_HEIGHT := 52
const SWITCH_OFF_COLOR := Color("#CFCFCB")

var stats_button: Button
var home_button: Button
var grid_ticks_button: CheckButton


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
	var heading := UI.label("Settings", 24, UI.INK)
	heading.add_theme_font_override("font", UI.title_font(600))
	header.add_child(heading)
	header.add_child(UI.spacer())
	var close := UI.icon_button("close", "Close settings")
	close.pressed.connect(close_sheet)
	header.add_child(close)
	column.add_child(header)

	column.add_child(UI.label("GAME", 12, UI.MUTED))
	stats_button = _row("Stats")
	stats_button.pressed.connect(func(): stats_pressed.emit())
	column.add_child(stats_button)
	home_button = _row("Home")
	home_button.tooltip_text = "Back to the home screen; your game is saved"
	home_button.pressed.connect(func(): home_pressed.emit())
	column.add_child(home_button)

	column.add_child(UI.label("DISPLAY", 12, UI.MUTED))
	grid_ticks_button = CheckButton.new()
	_style_row(grid_ticks_button, "Grid ticks")
	# A switch that is on stays white; only the switch itself shows it.
	var padding := Vector2(16, 0)
	grid_ticks_button.add_theme_stylebox_override("pressed", UI.box(UI.WHITE, UI.LINE, 16, 2, padding))
	grid_ticks_button.add_theme_icon_override("checked", _switch(true))
	grid_ticks_button.add_theme_icon_override("unchecked", _switch(false))
	grid_ticks_button.tooltip_text = "Marks each cell along the tower's edges"
	grid_ticks_button.toggled.connect(func(on): grid_ticks_toggled.emit(on))
	column.add_child(grid_ticks_button)


## Shows `on` without emitting grid_ticks_toggled.
func set_grid_ticks(on: bool) -> void:
	grid_ticks_button.set_pressed_no_signal(on)


## `in_game`: opened from the game screen, so the Home row shows.
func open(in_game := true) -> void:
	home_button.visible = in_game
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
	_style_row(b, text)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.icon = _chevron()
	return b


## The look shared by every row: white, outlined, name on the left.
func _style_row(b: Button, text: String) -> void:
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = ROW_HEIGHT
	b.add_theme_font_size_override("font_size", 17)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, UI.INK)
	var padding := Vector2(16, 0)
	b.add_theme_stylebox_override("normal", UI.box(UI.WHITE, UI.LINE, 16, 2, padding))
	b.add_theme_stylebox_override("hover", UI.box(Color("#F0F0EE"), UI.LINE, 16, 2, padding))
	b.add_theme_stylebox_override("pressed", UI.box(Color("#E2E2E0"), UI.LINE, 16, 2, padding))
	b.add_theme_stylebox_override("hover_pressed", UI.box(Color("#F0F0EE"), UI.LINE, 16, 2, padding))
	for state in ["font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, UI.INK)


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


## An on/off switch: a pill with a white knob, dark when on.
static func _switch(on: bool) -> ImageTexture:
	var w := 44
	var h := 26
	var r := h * 0.5
	var knob_x := w - r if on else r
	var track := UI.INK if on else SWITCH_OFF_COLOR
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var p := Vector2(x + 0.5, y + 0.5)
			var d_track := _segment_distance(p, Vector2(r, r), Vector2(w - r, r)) - r
			var d_knob := p.distance_to(Vector2(knob_x, r)) - (r - 3.0)
			var c := track * Color(1, 1, 1, clampf(0.5 - d_track, 0.0, 1.0))
			c = c.blend(UI.WHITE * Color(1, 1, 1, clampf(0.5 - d_knob, 0.0, 1.0)))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
