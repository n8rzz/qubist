extends Control
## Full-screen lifetime stats (#32), opened from Settings › Stats. Back
## returns to the Settings sheet.

const UI := preload("res://game/ui_style.gd")
const SkyBackdrop := preload("res://game/sky_backdrop.gd")
const SkyView := preload("res://game/sky_view.gd")

signal back_pressed

const CARD_RADIUS := 22

## Value labels by stat name, filled in by open().
var values := {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Opaque, so the game screen doesn't show through.
	add_child(SkyBackdrop.new())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UI.SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", UI.SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", UI.SAFE_TOP)
	margin.add_theme_constant_override("margin_bottom", UI.SAFE_BOTTOM)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 56
	header.add_theme_constant_override("separation", 12)
	var back := SkyView.by_night(UI.icon_button("back", "Back")) as Button
	back.pressed.connect(func(): back_pressed.emit())
	header.add_child(back)
	# Text on the sky turns light at night (#168).
	var heading: Label = SkyView.ink(UI.label("Stats", 30, UI.SKY_INK)) as Label
	heading.add_theme_font_override("font", UI.title_font(600))
	header.add_child(heading)
	column.add_child(header)

	column.add_child(_card("best_score", "Best score", 56))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for entry in [
		["games_played", "Games played"],
		["average_score", "Average score"],
		["lines_cleared", "Lines cleared"],
		["best_combo", "Best combo"],
		["longest_streak", "Longest streak"],
	]:
		var card := _card(entry[0], entry[1], 34)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	column.add_child(grid)

	column.add_child(SkyView.muted(UI.label("Stats are kept on this device.", 13, UI.SKY_MUTED, HORIZONTAL_ALIGNMENT_CENTER)))


## Shows the screen with `stats` (a core/stats.gd instance).
func open(stats) -> void:
	values.best_score.text = UI.format_number(stats.best_score)
	values.games_played.text = UI.format_number(stats.games_played)
	values.average_score.text = UI.format_number(stats.average_score())
	values.lines_cleared.text = UI.format_number(stats.lines_cleared)
	values.best_combo.text = "×%d" % stats.best_combo
	values.longest_streak.text = UI.format_number(stats.longest_streak)
	visible = true


func _card(key: String, title: String, value_size: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UI.card(UI.WHITE, CARD_RADIUS, Vector2(16, 18)))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	var caption := UI.label(title, 13, UI.SKY_MUTED)
	caption.add_theme_font_override("font", UI.body_font(600))
	stack.add_child(caption)
	var value := UI.label("0", value_size, UI.SKY_INK)
	value.add_theme_font_override("font", UI.title_font(600))
	stack.add_child(value)
	card.add_child(stack)
	SkyView.by_night(card)
	values[key] = value
	return card
