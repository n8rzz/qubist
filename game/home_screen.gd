extends Control
## Home screen (#72): the first screen on launch. Sky and clouds, Stats and
## Settings in the top bar, the Qubist wordmark over the best score, the
## tower on its island, then New game, Continue and How to play. With no game
## to continue, the island builds and crumbles towers on a loop (#186).
## The sky, island and drifting particles follow the season and time of day
## (#168); at night the wordmark and How to play turn light.

const UI := preload("res://game/ui_style.gd")
const IconButton := preload("res://game/icon_button.gd")
const SkyBackdrop := preload("res://game/sky_backdrop.gd")
const SkyView := preload("res://game/sky_view.gd")
const SkyWeather := preload("res://game/sky_weather.gd")
const HomeTowerArt := preload("res://game/home_tower_art.gd")

signal new_game_pressed
signal continue_pressed
signal stats_pressed
signal settings_pressed
signal how_to_play_pressed

const ACCENT_SHADOW := Color("#123D50")
const CARD_SHADOW := UI.CARD_SHADOW
const CROWN := Color("#F5C451")
const CROWN_EDGE := Color("#C98A1E")
const SIDE_MARGIN := 20
const GAP := 16

## The stack shown on the island when there's no game to continue and
## Reduce Motion is on.
const SAMPLE_CELLS: Array[Vector3i] = [
	Vector3i(1, 1, 0), Vector3i(2, 1, 0), Vector3i(3, 1, 0), Vector3i(1, 2, 0),
	Vector3i(1, 3, 0), Vector3i(3, 3, 0), Vector3i(4, 3, 0), Vector3i(4, 4, 0),
	Vector3i(2, 4, 0), Vector3i(1, 1, 1), Vector3i(2, 1, 1), Vector3i(1, 2, 1),
	Vector3i(1, 1, 2), Vector3i(4, 4, 1),
]

var stats_button: IconButton
var settings_button: IconButton
var best_label: Label
var island: HomeTowerArt
var new_game_button: Button
var continue_button: Button
var continue_score: Label
var how_to_play_button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_child(SkyBackdrop.new())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", UI.SAFE_TOP)
	margin.add_theme_constant_override("margin_bottom", UI.SAFE_BOTTOM)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	margin.add_child(column)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 44
	stats_button = SkyView.by_night(UI.icon_button("stats", "Stats")) as IconButton
	stats_button.pressed.connect(func(): stats_pressed.emit())
	bar.add_child(stats_button)
	bar.add_child(UI.spacer())
	settings_button = SkyView.by_night(UI.icon_button("settings", "Settings")) as IconButton
	settings_button.pressed.connect(func(): settings_pressed.emit())
	bar.add_child(settings_button)
	column.add_child(bar)

	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	var wordmark: Label = SkyView.ink(UI.label("Qubist", 68, UI.SKY_INK, HORIZONTAL_ALIGNMENT_CENTER)) as Label
	wordmark.add_theme_font_override("font", UI.title_font(600))
	title.add_child(wordmark)
	title.add_child(_best_pill())
	column.add_child(title)

	island = HomeTowerArt.new()
	island.size_flags_vertical = Control.SIZE_EXPAND_FILL
	island.cells = SAMPLE_CELLS
	column.add_child(island)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	new_game_button = _button(62, 22, UI.SKY_ACCENT, ACCENT_SHADOW, 4)
	new_game_button.text = "New game"
	new_game_button.add_theme_font_size_override("font_size", 22)
	new_game_button.add_theme_font_override("font", UI.title_font(600))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		new_game_button.add_theme_color_override(state, Color.WHITE)
	new_game_button.pressed.connect(func(): new_game_pressed.emit())
	buttons.add_child(new_game_button)

	continue_button = _button(54, 20, Color.WHITE, CARD_SHADOW, 3)
	continue_button.tooltip_text = "Continue your last game"
	var parts := HBoxContainer.new()
	parts.set_anchors_preset(Control.PRESET_FULL_RECT)
	parts.alignment = BoxContainer.ALIGNMENT_CENTER
	parts.add_theme_constant_override("separation", 8)
	parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var continue_text := UI.label("Continue", 17, UI.SKY_ACCENT)
	continue_text.add_theme_font_override("font", UI.body_font(600))
	parts.add_child(continue_text)
	continue_score = UI.label("· 0", 17, UI.SKY_MUTED)
	continue_score.add_theme_font_override("font", UI.body_font(500))
	parts.add_child(continue_score)
	continue_button.add_child(parts)
	continue_button.pressed.connect(func(): continue_pressed.emit())
	SkyView.by_night(continue_button)
	buttons.add_child(continue_button)

	how_to_play_button = Button.new()
	how_to_play_button.text = "How to play"
	how_to_play_button.flat = true
	how_to_play_button.focus_mode = Control.FOCUS_NONE
	how_to_play_button.custom_minimum_size.y = 44
	how_to_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	how_to_play_button.add_theme_font_size_override("font_size", 15)
	how_to_play_button.add_theme_font_override("font", UI.body_font(600))
	SkyView.on_sky(how_to_play_button, UI.SKY_ACCENT, SkyView.NIGHT_INK)
	how_to_play_button.pressed.connect(func(): how_to_play_pressed.emit())
	buttons.add_child(how_to_play_button)
	column.add_child(buttons)

	# In front of the island; it never takes taps.
	add_child(SkyWeather.new())


## Shows Home with the best score. `resume_score` is the score of the game
## Continue resumes, or -1 to hide Continue; `cells` fill the island's tower.
## With no `cells`, the island plays its build-and-crumble loop (the sample
## stack, standing still, under Reduce Motion).
func open(best: int, resume_score: int = -1, cells: Array = []) -> void:
	best_label.text = "BEST %s" % UI.format_number(best)
	continue_button.visible = resume_score >= 0
	continue_score.text = "· %s" % UI.format_number(maxi(resume_score, 0))
	island.still = UI.reduce_motion()
	if cells.is_empty():
		island.play(SAMPLE_CELLS)
	else:
		island.show_cells(cells)
	visible = true


func _best_pill() -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel",
		UI.box(Color(1, 1, 1, 0.85), 999, Vector2(14, 6)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var crown := Control.new()
	crown.custom_minimum_size = Vector2(14, 14)
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crown.draw.connect(_draw_crown.bind(crown))
	row.add_child(crown)
	best_label = UI.label("BEST 0", 13, UI.SKY_MUTED)
	best_label.add_theme_font_override("font", UI.body_font(700, 1))
	row.add_child(best_label)
	pill.add_child(row)
	SkyView.by_night(pill)
	return pill


func _draw_crown(on: Control) -> void:
	# The design's 24-unit crown, scaled into the 14-point box.
	var k := on.size.x / 24.0
	var points := PackedVector2Array()
	for p in [Vector2(4, 17), Vector2(3, 8), Vector2(8, 12), Vector2(12, 6), Vector2(16, 12), Vector2(21, 8), Vector2(20, 17)]:
		points.append(p * k)
	on.draw_colored_polygon(points, CROWN)
	points.append(points[0])
	on.draw_polyline(points, CROWN_EDGE, 2.2 * k, true)


## A raised button: `color` with a solid `shadow` ledge `drop` points deep,
## which shrinks while pressed.
func _button(height: int, radius: int, color: Color, shadow: Color, drop: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("normal", _card(color, radius, shadow, drop))
	b.add_theme_stylebox_override("hover", _card(color.lightened(0.06), radius, shadow, drop))
	b.add_theme_stylebox_override("pressed", _card(color.darkened(0.08), radius, shadow, 1))
	return b


static func _card(color: Color, radius: int, shadow: Color, drop: int) -> StyleBoxFlat:
	var b := UI.box(color, radius)
	b.shadow_color = shadow
	b.shadow_size = 1
	b.shadow_offset = Vector2(0, drop)
	return b

