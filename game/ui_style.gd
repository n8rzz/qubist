extends RefCounted
## Greybox colors and widget builders shared by the game screen, the Settings
## sheet and the Stats screen, until the final screen styling (#28).

const IconButton := preload("res://game/icon_button.gd")

## Fredoka for titles and numbers, Inter for UI text. Both are variable fonts,
## so each weight is a FontVariation on the one file. Inter at 400 is also the
## project's default font, set in assets/ui_theme.tres.
const FREDOKA: FontFile = preload("res://assets/fonts/Fredoka-Variable.ttf")
const INTER: FontFile = preload("res://assets/fonts/Inter-Variable.ttf")

static var _fonts := {}

const BG := Color("#F4F4F2")
const INK := Color("#222222")
const MUTED := Color("#555555")
const LINE := Color("#555555")
const WHITE := Color.WHITE

## Text and accent colours for the screens drawn over the sky (Home, Loading).
const SKY_INK := Color("#22313F")
const SKY_MUTED := Color("#3D5568")
const SKY_ACCENT := Color("#1F5E7A")

## Points kept clear of the notch and the home indicator (390×844 iPhone).
const SAFE_TOP := 54
const SAFE_BOTTOM := 34
const SIDE_MARGIN := 16


## Fredoka at `weight` (300–700), for titles, the wordmark and scores.
## `spacing` adds that many pixels between glyphs.
static func title_font(weight: int = 600, spacing: int = 0) -> FontVariation:
	return _font(FREDOKA, weight, spacing)


## Inter at `weight` (100–900), for everything else.
static func body_font(weight: int = 400, spacing: int = 0) -> FontVariation:
	return _font(INTER, weight, spacing)


## One shared FontVariation per family, weight and spacing, so screens that
## ask for the same font reuse its glyph cache.
static func _font(base: FontFile, weight: int, spacing: int) -> FontVariation:
	var key := "%s:%d:%d" % [base.resource_path, weight, spacing]
	if not _fonts.has(key):
		var font := FontVariation.new()
		font.base_font = base
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		font.spacing_glyph = spacing
		_fonts[key] = font
	return _fonts[key]


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


## A text button: white with dark text, or dark with white text when
## `primary`.
static func text_button(text: String, font_size: int, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var bg := INK if primary else WHITE
	var fg := WHITE if primary else INK
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_stylebox_override("normal", box(bg, LINE, 22))
	b.add_theme_stylebox_override("hover", box(bg.darkened(0.05), LINE, 22))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.12), LINE, 22))
	return b


## Slider track: a rounded bar 8 px thick.
static func slider_track(color: Color) -> StyleBoxFlat:
	var b := box(color, Color(0, 0, 0, 0), 4, 0)
	b.content_margin_top = 4
	b.content_margin_bottom = 4
	return b


## A round slider grabber: white with a dark ring, drawn in code so the
## greybox needs no image assets.
static func grabber_texture(diameter: int) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter * 0.5
	for y in range(diameter):
		for x in range(diameter):
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var ring := clampf(r - d, 0.0, 1.0)
			var fill := clampf(r - 2.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color("#333333").lerp(WHITE, fill) * Color(1, 1, 1, ring))
	return ImageTexture.create_from_image(img)


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
