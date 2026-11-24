extends Control
## Game-over card (#19): the tower dims and a card slides up from the bottom
## with the final score, the best score and this game's lines, best combo and
## longest streak, over a single Play again button.
##
## There is no Home button: Home stays one tap away through the settings button
## once the next game starts. The "Score saved to Game Center" line stays
## hidden until the leaderboard (#30) reports a submit with
## show_score_saved().

const UI := preload("res://game/ui_style.gd")

signal play_again_pressed

## Colours from the Qubist game-over design.
const INK := Color("#22313F")
const SUBTLE := Color("#3D5568")
const TILE := Color("#EEF5F8")
const BUTTON := Color("#1F5E7A")
const BUTTON_EDGE := Color("#123D50")
const DIM_TOP := Color(16 / 255.0, 32 / 255.0, 44 / 255.0, 0.25)
const DIM_BOTTOM := Color(16 / 255.0, 32 / 255.0, 44 / 255.0, 0.6)

const CARD_SIDE_GAP := 12
const CARD_BOTTOM_GAP := 24
const CARD_RADIUS := 30
const SLIDE_SECONDS := 0.32
const DIM_SECONDS := 0.2

var dim: TextureRect
## Slides as one piece so the card needs no measuring before it moves.
var slider: Control
var card: PanelContainer
var score_label: Label
var best_label: Label
var lines_label: Label
var combo_label: Label
var streak_label: Label
var play_again_button: Button
var score_saved_row: HBoxContainer
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Catches every tap so nothing behind the card can be used.
	dim = TextureRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.stretch_mode = TextureRect.STRETCH_SCALE
	dim.texture = _dim_texture()
	add_child(dim)

	slider = Control.new()
	slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slider)

	card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_left = CARD_SIDE_GAP
	card.offset_right = -CARD_SIDE_GAP
	card.offset_bottom = -CARD_BOTTOM_GAP
	var style := UI.box(UI.WHITE, Color(0, 0, 0, 0), CARD_RADIUS, 0, Vector2(22, 22))
	style.content_margin_top = 26
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 12)
	card.add_theme_stylebox_override("panel", style)
	slider.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)

	var heading := UI.label("NO MOVES LEFT", 12, SUBTLE, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_override("font", UI.body_font(700, 1))
	column.add_child(heading)

	var scores := VBoxContainer.new()
	scores.add_theme_constant_override("separation", 2)
	score_label = UI.label("0", 64, INK, HORIZONTAL_ALIGNMENT_CENTER)
	score_label.add_theme_font_override("font", UI.title_font(600))
	scores.add_child(score_label)
	best_label = UI.label("Best 0", 14, SUBTLE)
	best_label.add_theme_font_override("font", UI.body_font(600))
	scores.add_child(_icon_row(Crown.new(), best_label, 5))
	column.add_child(scores)

	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	lines_label = _tile(tiles, "Lines")
	combo_label = _tile(tiles, "Best combo")
	streak_label = _tile(tiles, "Longest streak")
	column.add_child(tiles)

	play_again_button = _play_again_button()
	play_again_button.pressed.connect(func(): play_again_pressed.emit())
	column.add_child(play_again_button)

	var saved := UI.label("Score saved to Game Center", 13, SUBTLE)
	saved.add_theme_font_override("font", UI.body_font(500))
	score_saved_row = _icon_row(Trophy.new(), saved, 6)
	score_saved_row.visible = false
	column.add_child(score_saved_row)


## Fills the card from the finished `game` and slides it up.
func open(game, best_score: int) -> void:
	score_label.text = UI.format_number(game.score)
	best_label.text = "Best %s" % UI.format_number(best_score)
	lines_label.text = UI.format_number(game.lines_cleared_total)
	combo_label.text = "×%d" % game.best_combo if game.best_combo > 0 else "–"
	streak_label.text = str(game.longest_streak)
	score_saved_row.visible = false
	visible = true

	if _tween != null:
		_tween.kill()
	dim.modulate.a = 0.0
	slider.position.y = size.y
	_tween = create_tween().set_parallel()
	_tween.tween_property(dim, "modulate:a", 1.0, DIM_SECONDS)
	_tween.tween_property(slider, "position:y", 0.0, SLIDE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _tween != null:
		_tween.kill()
	slider.position.y = 0.0
	dim.modulate.a = 1.0
	visible = false


## Shows or hides "Score saved to Game Center". Game Center (#30) calls this
## once the score is sent; leave it hidden when Game Center is off or the
## submit fails.
func show_score_saved(saved := true) -> void:
	score_saved_row.visible = saved


## Skips the slide-in. Used by tests.
func finish_animation() -> void:
	if _tween != null and _tween.is_valid():
		_tween.custom_step(SLIDE_SECONDS)


## A stat tile: big value over a small name. Returns the value label.
func _tile(row: HBoxContainer, caption_text: String) -> Label:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", UI.box(TILE, Color(0, 0, 0, 0), 16, 0, Vector2(6, 12)))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	var value := UI.label("0", 24, INK, HORIZONTAL_ALIGNMENT_CENTER)
	value.add_theme_font_override("font", UI.title_font(600))
	stack.add_child(value)
	var caption := UI.label(caption_text, 12, SUBTLE, HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_font_override("font", UI.body_font(600))
	# No minimum width, so the three tiles split the row evenly.
	caption.clip_text = true
	stack.add_child(caption)
	tile.add_child(stack)
	row.add_child(tile)
	return value


func _play_again_button() -> Button:
	var b := Button.new()
	b.text = "Play again"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 58
	b.add_theme_font_override("font", UI.title_font(600))
	b.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, UI.WHITE)
	b.add_theme_stylebox_override("normal", _button_box(BUTTON, 4))
	b.add_theme_stylebox_override("hover", _button_box(BUTTON.lightened(0.06), 4))
	# Pressed sinks onto its edge.
	b.add_theme_stylebox_override("pressed", _button_box(BUTTON.darkened(0.08), 0, 4))
	return b


## The button's face with a solid `edge` px lip under it. `sink` pushes the
## face down by that much, for the pressed look.
static func _button_box(face: Color, edge: int, sink: int = 0) -> StyleBoxFlat:
	var b := UI.box(face, BUTTON_EDGE, 20, 0)
	b.border_width_bottom = edge
	b.expand_margin_bottom = edge
	b.expand_margin_top = -sink
	b.content_margin_top = sink
	return b


static func _icon_row(icon: Control, text: Label, gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", gap)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(text)
	return row


static func _dim_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, DIM_TOP)
	gradient.set_color(1, DIM_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	return texture


## The gold crown beside the best score, drawn on a 24-unit grid.
class Crown:
	extends Control

	const POINTS := [Vector2(4, 17), Vector2(3, 8), Vector2(8, 12), Vector2(12, 6),
		Vector2(16, 12), Vector2(21, 8), Vector2(20, 17)]

	func _init() -> void:
		custom_minimum_size = Vector2(14, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size.x / 24.0
		var shape := PackedVector2Array()
		for p in POINTS:
			shape.append(p * s)
		draw_colored_polygon(shape, Color("#F5C451"))
		shape.append(shape[0])
		draw_polyline(shape, Color("#C98A1E"), 2.2 * s, true)


## The trophy beside "Score saved to Game Center", stroked in the text colour.
class Trophy:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size.x / 24.0
		var color := Color("#3D5568")
		var w := 2.0 * s
		# Cup: a rim, straight sides and a round bottom.
		var cup := PackedVector2Array([Vector2(8, 9), Vector2(8, 4), Vector2(16, 4), Vector2(16, 9)])
		for i in range(1, 8):
			var a := PI * i / 8.0
			cup.append(Vector2(12 + 4 * cos(a), 9 + 4 * sin(a)))
		cup.append(Vector2(8, 9))
		for i in range(cup.size()):
			cup[i] *= s
		draw_polyline(cup, color, w, true)
		# Handles.
		draw_arc(Vector2(8, 8) * s, 2.5 * s, PI * 0.5, PI * 1.5, 8, color, w, true)
		draw_arc(Vector2(16, 8) * s, 2.5 * s, -PI * 0.5, PI * 0.5, 8, color, w, true)
		# Stem and base.
		draw_line(Vector2(12, 13) * s, Vector2(12, 17) * s, color, w, true)
		draw_line(Vector2(8, 20) * s, Vector2(16, 20) * s, color, w, true)
