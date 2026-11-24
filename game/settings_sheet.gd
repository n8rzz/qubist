extends Control
## Settings bottom sheet (#20), opened from the header gear and from Home.
##
## Sound and feel: Music, Sound effects and Haptics switches, with a volume
## slider under Music and Sound effects (#165). Game: Stats
## (#32), Replay tutorial (#29) and Home
## (#72, only when opened from a game). Display: the Grid ticks switch (#56),
## which the design doesn't show yet. Pause stays a separate menu (#42).

const UI := preload("res://game/ui_style.gd")
const IconButton := preload("res://game/icon_button.gd")

signal stats_pressed
signal tutorial_pressed
signal home_pressed
## A switch was flipped by the player. `key` is a Settings field name.
signal setting_toggled(key: String, on: bool)
## A volume slider was moved by the player. `key` is a Settings field name;
## `value` is 0–1.
signal volume_changed(key: String, value: float)
signal closed

## Colours from the Qubist Settings design.
const SHEET_BG := Color("#F3F8FA")
const HANDLE := Color("#C9D5DC")
const TILE := Color("#EEF5F8")
const DIVIDER := Color("#E6EEF2")
const CHEVRON := Color("#8AA0B0")
const ROW_PRESSED := Color("#F4F8FA")
const SWITCH_OFF := Color("#C9D5DC")
const DIM := Color(16 / 255.0, 32 / 255.0, 44 / 255.0, 0.45)
const CLOSE_SHADOW := Color(36 / 255.0, 72 / 255.0, 96 / 255.0, 0.16)

const SHEET_RADIUS := 30
const ROW_HEIGHT := 56
const ROW_GAP := 14
const TILE_SIDE := 36
const SLIDER_HEIGHT := 36

var music_button: Button
var sound_effects_button: Button
var haptics_button: Button
var grid_ticks_button: Button
var music_volume_slider: HSlider
var sound_effects_volume_slider: HSlider
var stats_button: Button
var tutorial_button: Button
var home_button: Button

## Settings key -> its switch row.
var _switches := {}
## Settings key -> its volume slider.
var _sliders := {}
## Each card's rows, so dividers can follow which rows are visible.
var _cards: Array[VBoxContainer] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Tapping the dimmed game behind the sheet closes it.
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := UI.box(SHEET_BG, Color(0, 0, 0, 0), SHEET_RADIUS, 0, Vector2(UI.SIDE_MARGIN, 0))
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_top = 10
	style.content_margin_bottom = UI.SAFE_BOTTOM
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 15
	style.shadow_offset = Vector2(0, -10)
	sheet.add_theme_stylebox_override("panel", style)
	add_child(sheet)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	sheet.add_child(column)

	var handle := Panel.new()
	handle.custom_minimum_size = Vector2(40, 5)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.add_theme_stylebox_override("panel", UI.box(HANDLE, Color(0, 0, 0, 0), 3, 0))
	column.add_child(handle)

	var header := HBoxContainer.new()
	var heading := UI.label("Settings", 30, UI.SKY_INK)
	heading.add_theme_font_override("font", UI.title_font(600))
	header.add_child(heading)
	header.add_child(UI.spacer())
	header.add_child(_close_button())
	column.add_child(header)

	var sound := _card(column, "SOUND AND FEEL")
	music_button = _switch_row(sound, "music", "Music", "music")
	music_volume_slider = _volume_row(sound, "music_volume", music_button, "Music volume")
	sound_effects_button = _switch_row(sound, "sound_effects", "Sound effects", "sound")
	sound_effects_volume_slider = _volume_row(sound, "sound_effects_volume",
		sound_effects_button, "Sound effects volume")
	haptics_button = _switch_row(sound, "haptics", "Haptics", "haptics")

	var game := _card(column, "GAME")
	stats_button = _link_row(game, "Stats", "stats")
	stats_button.pressed.connect(func(): stats_pressed.emit())
	tutorial_button = _link_row(game, "Replay tutorial", "replay")
	tutorial_button.pressed.connect(func(): tutorial_pressed.emit())
	home_button = _link_row(game, "Home", "home")
	home_button.tooltip_text = "Back to the home screen; your game is saved"
	home_button.pressed.connect(func(): home_pressed.emit())

	var display := _card(column, "DISPLAY")
	grid_ticks_button = _switch_row(display, "grid_ticks", "Grid ticks", "grid")
	grid_ticks_button.tooltip_text = "Marks each cell along the tower's edges"

	_update_dividers()


## Shows every switch and slider as `settings` has it, without emitting
## setting_toggled or volume_changed.
func show_settings(settings) -> void:
	for key in _switches:
		set_switch(key, settings.get(key))
	for key in _sliders:
		set_volume(key, settings.get(key))


## Shows one switch as `on`, without emitting setting_toggled.
func set_switch(key: String, on: bool) -> void:
	var row: Button = _switches[key]
	row.set_pressed_no_signal(on)
	row.queue_redraw()
	_sync_sliders()


## Shows one volume slider at `value` (0–1), without emitting volume_changed.
func set_volume(key: String, value: float) -> void:
	(_sliders[key] as HSlider).set_value_no_signal(value)


## `in_game`: opened from the game screen, so the Home row shows.
func open(in_game := true) -> void:
	home_button.visible = in_game
	_update_dividers()
	visible = true


func close_sheet() -> void:
	visible = false
	closed.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_sheet()
		accept_event()


func _close_button() -> IconButton:
	var b := IconButton.new("close", "Close settings")
	b.icon_color = UI.SKY_INK
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed"]:
		var face := UI.WHITE if state != "pressed" else Color("#E6EEF2")
		var box := UI.box(face, Color(0, 0, 0, 0), 22, 0)
		box.shadow_color = CLOSE_SHADOW
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, 3 if state != "pressed" else 1)
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(close_sheet)
	return b


## A captioned white card. Returns the column its rows go in.
func _card(column: VBoxContainer, caption: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	var title := UI.label(caption, 12, UI.SKY_MUTED)
	title.add_theme_font_override("font", UI.body_font(700, 1))
	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 2)
	title_margin.add_child(title)
	group.add_child(title_margin)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(UI.WHITE, Color(0, 0, 0, 0), 20, 0, Vector2(16, 4)))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	card.add_child(rows)
	group.add_child(card)
	column.add_child(group)
	_cards.append(rows)
	return rows


## A row that opens something: icon, name and a chevron.
func _link_row(rows: VBoxContainer, text: String, icon: String) -> Button:
	var row := _row(rows, text, icon)
	var chevron := Icon.new("chevron", CHEVRON)
	chevron.custom_minimum_size = Vector2(20, 20)
	row.get_child(0).add_child(chevron)
	return row


## A row with an on/off switch; tapping anywhere on it flips the switch.
func _switch_row(rows: VBoxContainer, key: String, text: String, icon: String) -> Button:
	var row := _row(rows, text, icon)
	row.toggle_mode = true
	# A switch that is on counts as pressed; only the switch shows it.
	row.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	row.get_child(0).add_child(Switch.new(row))
	row.toggled.connect(func(on): setting_toggled.emit(key, on))
	_switches[key] = row
	return row


## A volume slider under `switch_row`, indented to line up with its name.
## It dims and stops responding while its switch is off.
func _volume_row(rows: VBoxContainer, key: String, switch_row: Button, label: String) -> HSlider:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", TILE_SIDE + ROW_GAP)
	margin.add_theme_constant_override("margin_bottom", 8)
	rows.add_child(margin)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 1.0
	slider.custom_minimum_size.y = SLIDER_HEIGHT
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = label
	slider.set_meta("switch_row", switch_row)
	_style_slider(slider)
	slider.value_changed.connect(func(value): volume_changed.emit(key, value))
	margin.add_child(slider)
	_sliders[key] = slider
	switch_row.toggled.connect(func(_on): _sync_sliders())
	_sync_sliders()
	return slider


## Each slider is usable only while its switch is on.
func _sync_sliders() -> void:
	for key in _sliders:
		var slider: HSlider = _sliders[key]
		var on: bool = (slider.get_meta("switch_row") as Button).button_pressed
		slider.editable = on
		slider.modulate.a = 1.0 if on else 0.4


## A thin rounded track, filled in the switch colour up to a white knob.
static func _style_slider(slider: HSlider) -> void:
	var track := UI.box(SWITCH_OFF, Color(0, 0, 0, 0), 3, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := UI.box(Switch.ON, Color(0, 0, 0, 0), 3, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _knob_texture()
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon, knob)


## A 24-point white knob with a soft grey rim, like the switch's.
static func _knob_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.78, 0.86, 0.96, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE,
		Color(0.79, 0.84, 0.86), Color(0.79, 0.84, 0.86, 0.5), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 24
	texture.height = 24
	return texture


## The parts every row shares: a tinted icon tile and the name. The trailing
## chevron or switch goes at the end of the returned button's first child.
func _row(rows: VBoxContainer, text: String, icon: String) -> Button:
	if rows.get_child_count() > 0:
		rows.add_child(_divider())
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = ROW_HEIGHT
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover_pressed", StyleBoxEmpty.new())
	var pressed := UI.box(ROW_PRESSED, Color(0, 0, 0, 0), 12, 0)
	pressed.expand_margin_left = 8
	pressed.expand_margin_right = 8
	b.add_theme_stylebox_override("pressed", pressed)
	rows.add_child(b)

	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", ROW_GAP)
	b.add_child(line)

	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(TILE_SIDE, TILE_SIDE)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", UI.box(TILE, Color(0, 0, 0, 0), 10, 0))
	tile.add_child(Icon.new(icon, UI.SKY_ACCENT))
	line.add_child(tile)

	var name_label := UI.label(text, 17, UI.SKY_INK)
	name_label.add_theme_font_override("font", UI.body_font(500))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	line.add_child(name_label)
	return b


func _divider() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", TILE_SIDE + ROW_GAP)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_meta("divider", true)
	var line := ColorRect.new()
	line.color = DIVIDER
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(line)
	return margin


## A divider shows only between two visible rows. Volume sliders sit with
## the row above them and take no part.
func _update_dividers() -> void:
	for rows in _cards:
		var seen_row := false
		var pending_divider: Control = null
		for child in rows.get_children():
			if not (child is Button or child.has_meta("divider")):
				continue
			if child is Button:
				if pending_divider != null:
					pending_divider.visible = seen_row and child.visible
				if child.visible:
					seen_row = true
				pending_divider = null
			else:
				pending_divider = child
				child.visible = false


## The on/off pill at the end of a switch row, drawn from its row's state.
class Switch:
	extends Control

	const ON := Color("#1F5E7A")
	const OFF := Color("#C9D5DC")

	var row: Button

	func _init(p_row: Button) -> void:
		row = p_row
		custom_minimum_size = Vector2(52, 32)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.toggled.connect(func(_on): queue_redraw())
		row.draw.connect(queue_redraw)

	func _draw() -> void:
		var on := row.button_pressed
		var track := StyleBoxFlat.new()
		track.bg_color = ON if on else OFF
		track.set_corner_radius_all(16)
		track.anti_aliasing = true
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var knob := Vector2(22.0 if on else 3.0, 3.0) + Vector2(13, 13)
		draw_circle(knob + Vector2(0, 2), 13.5, Color(0, 0, 0, 0.12), true, -1.0, true)
		draw_circle(knob, 13.0, Color.WHITE, true, -1.0, true)


## A stroked line icon from the Settings design, drawn on a 24-unit grid and
## centered in its box at 20 points.
class Icon:
	extends Control

	var kind: String
	var color: Color

	func _init(p_kind: String, p_color: Color) -> void:
		kind = p_kind
		color = p_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := 20.0 / 24.0
		var o := (size - Vector2(20, 20)) * 0.5
		var w := 2.0
		var pts := func(list: Array) -> PackedVector2Array:
			var out := PackedVector2Array()
			for p in list:
				out.append(o + p * s)
			return out
		var line := func(list: Array) -> void:
			draw_polyline(pts.call(list), color, w, true)
		var arc := func(center: Vector2, radius: float, from: float, to: float) -> void:
			draw_arc(o + center * s, radius * s, from, to, 24, color, w, true)
		match kind:
			"music":
				line.call([Vector2(9, 18), Vector2(9, 6), Vector2(19, 4), Vector2(19, 16)])
				arc.call(Vector2(6.5, 18), 2.5, 0.0, TAU)
				arc.call(Vector2(16.5, 16), 2.5, 0.0, TAU)
			"sound":
				line.call([Vector2(4, 10), Vector2(4, 14), Vector2(8, 14), Vector2(13, 18),
					Vector2(13, 6), Vector2(8, 10), Vector2(4, 10)])
				arc.call(Vector2(13.85, 12), 4.0, -0.85, 0.85)
				arc.call(Vector2(13.9, 12), 7.5, -0.82, 0.82)
			"haptics":
				var r := 2.0
				arc.call(Vector2(10, 5), r, PI, PI * 1.5)
				arc.call(Vector2(14, 5), r, PI * 1.5, TAU)
				arc.call(Vector2(14, 19), r, 0.0, PI * 0.5)
				arc.call(Vector2(10, 19), r, PI * 0.5, PI)
				line.call([Vector2(10, 3), Vector2(14, 3)])
				line.call([Vector2(16, 5), Vector2(16, 19)])
				line.call([Vector2(14, 21), Vector2(10, 21)])
				line.call([Vector2(8, 19), Vector2(8, 5)])
				line.call([Vector2(4, 8), Vector2(4, 16)])
				line.call([Vector2(20, 8), Vector2(20, 16)])
			"stats":
				line.call([Vector2(5, 20), Vector2(5, 10)])
				line.call([Vector2(12, 20), Vector2(12, 4)])
				line.call([Vector2(19, 20), Vector2(19, 13)])
			"replay":
				arc.call(Vector2(12, 12), 8.0, PI, -2.4)
				line.call([Vector2(4, 4), Vector2(4, 9), Vector2(9, 9)])
				line.call([Vector2(10.5, 9.5), Vector2(14.5, 12), Vector2(10.5, 14.5), Vector2(10.5, 9.5)])
			"home":
				line.call([Vector2(4, 11), Vector2(12, 4), Vector2(20, 11)])
				line.call([Vector2(6, 9.5), Vector2(6, 20), Vector2(18, 20), Vector2(18, 9.5)])
			"grid":
				line.call([Vector2(4, 4), Vector2(4, 20), Vector2(20, 20)])
				for t in [8.0, 12.0, 16.0]:
					var tick := 5.0 if t == 12.0 else 3.0
					line.call([Vector2(t, 20), Vector2(t, 20 - tick)])
					line.call([Vector2(4, t), Vector2(4 + tick, t)])
			"chevron":
				line.call([Vector2(9, 5), Vector2(16, 12), Vector2(9, 19)])
