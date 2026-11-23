extends Control
## Full-screen lifetime stats (#32), opened from Settings › Stats. Back
## returns to the Settings sheet.

const UI := preload("res://game/ui_style.gd")

signal back_pressed

const CARD_RADIUS := 22

## Value labels by stat name, filled in by open().
var values := {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

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
	var back := UI.icon_button("back", "Back", 44, 14)
	back.pressed.connect(func(): back_pressed.emit())
	header.add_child(back)
	var heading := UI.label("Stats", 30, UI.INK)
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

	var footer := UI.label("Stats are kept on this device.", 13, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(footer)


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
		UI.box(UI.WHITE, UI.LINE, CARD_RADIUS, 2, Vector2(16, 18)))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	var caption := UI.label(title, 13, UI.MUTED)
	caption.add_theme_font_override("font", UI.body_font(600))
	stack.add_child(caption)
	var value := UI.label("0", value_size, UI.INK)
	value.add_theme_font_override("font", UI.title_font(600))
	stack.add_child(value)
	card.add_child(stack)
	values[key] = value
	return card
