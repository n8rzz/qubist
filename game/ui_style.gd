extends RefCounted
## Greybox colors and widget builders shared by the Settings sheet and the
## Stats screen. Matches the placeholder look in game/main.gd until the final
## screen styling (#28).

const IconButton := preload("res://game/icon_button.gd")

const BG := Color("#F4F4F2")
const INK := Color("#222222")
const MUTED := Color("#555555")
const LINE := Color("#555555")
const WHITE := Color.WHITE

## Points kept clear of the notch and the home indicator (390×844 iPhone).
const SAFE_TOP := 54
const SAFE_BOTTOM := 34
const SIDE_MARGIN := 16


static func box(bg: Color, border: Color, radius: int, width: int = 2, padding := Vector2.ZERO) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = padding.x
	b.content_margin_right = padding.x
	b.content_margin_top = padding.y
	b.content_margin_bottom = padding.y
	b.anti_aliasing = true
	return b


static func label(text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func icon_button(kind: String, tooltip: String, side: int = 44, radius: int = 12) -> IconButton:
	var b := IconButton.new(kind, tooltip)
	b.custom_minimum_size = Vector2(side, side)
	b.add_theme_stylebox_override("normal", box(WHITE, LINE, radius))
	b.add_theme_stylebox_override("hover", box(Color("#F0F0EE"), LINE, radius))
	b.add_theme_stylebox_override("pressed", box(Color("#E2E2E0"), LINE, radius))
	return b


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Thousands separators: 5272 -> "5,272".
static func format_number(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out
