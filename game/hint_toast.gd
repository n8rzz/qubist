extends PanelContainer
## A one-time hint (#29): a small white card over the top of the tower that
## fades in, stays a few seconds and fades out. It never takes input.

const UI := preload("res://game/ui_style.gd")

## What each first-use hint says; keys are core/onboarding.gd HINTS.
const TEXT := {
	"rotate": "The tray turns with the tower, so each piece faces the way you'll place it.",
	"swiper": "X and Y slice the tower from the front or the side. Z peels off the top layers.",
	"zoom": "Spread two fingers to look closer. Pinch them together to see the whole tower.",
	"tutorial_done": "You're ready! Clear as many lines as you can before the tower fills up.",
}

const MAX_WIDTH := 300
const FADE_SECONDS := 0.25
const HOLD_SECONDS := 4.0

var label: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_stylebox_override("panel", UI.card(UI.WHITE, 18, Vector2(16, 10)))
	label = UI.label("", 14, UI.SKY_INK, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_font_override("font", UI.body_font(500))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = MAX_WIDTH - 32
	add_child(label)


## Shows hint `key` centered across `area`, `top` points below its top edge.
func show_hint(key: String, area: Rect2, top: float) -> void:
	label.text = TEXT.get(key, "")
	size = Vector2.ZERO
	reset_size()
	position = Vector2(area.get_center().x - size.x * 0.5, area.position.y + top)
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide)


func dismiss() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
