extends RefCounted
## Colours and widget builders shared by the game screen, the Settings sheet,
## the Stats screen and Home, following the Qubist designs canvas.

const IconButton := preload("res://game/icon_button.gd")

## Fredoka for titles and numbers, Inter for UI text. Both are variable fonts,
## so each weight is a FontVariation on the one file. Inter at 400 is also the
## project's default font, set in assets/ui_theme.tres.
const FREDOKA: FontFile = preload("res://assets/fonts/Fredoka-Variable.ttf")
const INTER: FontFile = preload("res://assets/fonts/Inter-Variable.ttf")

static var _fonts := {}

const WHITE := Color.WHITE

## Text and accent colours for everything drawn over the sky.
const SKY_INK := Color("#22313F")
const SKY_MUTED := Color("#3D5568")
const SKY_ACCENT := Color("#1F5E7A")
## The darker ledge under the teal primary button.
const ACCENT_LEDGE := Color("#123D50")

## The soft blue-grey ledge under every white card and button.
const CARD_SHADOW := Color(36 / 255.0, 72 / 255.0, 96 / 255.0, 0.16)
## White cards and buttons while hovered and pressed.
const CARD_HOVER := Color("#F4F8FA")
const CARD_PRESSED := Color("#E6EEF2")
## The pale track behind the swiper's axis toggle, and the slider's rail.
const SEGMENT_TRACK := Color("#EAF1F5")
const SLIDER_RAIL := Color("#D5E2EA")
## Tray cards are slightly see-through so the sky tints them.
const TRAY_CARD := Color(1, 1, 1, 0.86)

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


## A borderless card: `color` with rounded corners and a soft ledge `drop`
## points deep below it.
static func card(color: Color, radius: int, padding := Vector2.ZERO, drop: int = 3) -> StyleBoxFlat:
	var b := box(color, Color(0, 0, 0, 0), radius, 0, padding)
	b.shadow_color = CARD_SHADOW
	b.shadow_size = 1
	b.shadow_offset = Vector2(0, drop)
	return b


## Sets a button's normal, hover and pressed styles to a white card whose
## ledge shrinks while pressed.
static func style_card_button(b: Button, radius: int, padding := Vector2.ZERO) -> void:
	b.add_theme_stylebox_override("normal", card(WHITE, radius, padding))
	b.add_theme_stylebox_override("hover", card(CARD_HOVER, radius, padding))
	b.add_theme_stylebox_override("pressed", card(CARD_PRESSED, radius, padding, 1))


## A white icon tile. Pass `radius` = side / 2 for a round button.
static func icon_button(kind: String, tooltip: String, side: int = 44, radius: int = 14) -> IconButton:
	var b := IconButton.new(kind, tooltip)
	b.icon_color = SKY_INK
	b.custom_minimum_size = Vector2(side, side)
	style_card_button(b, radius)
	return b


## A text button: a white card with ink text, or teal with white text when
## `primary`.
static func text_button(text: String, font_size: int, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", body_font(600))
	var fg := WHITE if primary else SKY_INK
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, fg)
	if primary:
		for state in ["normal", "hover", "pressed"]:
			var face := SKY_ACCENT
			if state == "hover":
				face = SKY_ACCENT.lightened(0.06)
			elif state == "pressed":
				face = SKY_ACCENT.darkened(0.08)
			var style := box(face, Color(0, 0, 0, 0), 22, 0)
			style.shadow_color = ACCENT_LEDGE
			style.shadow_size = 1
			style.shadow_offset = Vector2(0, 1 if state == "pressed" else 4)
			b.add_theme_stylebox_override(state, style)
	else:
		style_card_button(b, 22)
	return b


## Slider track: a rounded bar 6 px thick.
static func slider_track(color: Color) -> StyleBoxFlat:
	var b := box(color, Color(0, 0, 0, 0), 3, 0)
	b.content_margin_top = 3
	b.content_margin_bottom = 3
	return b


## A round slider grabber: white with a `ring` coloured edge and a faint
## shadow, drawn in code so it needs no image assets.
static func grabber_texture(diameter: int, ring: Color = SKY_ACCENT) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter * 0.5
	for y in range(diameter):
		for x in range(diameter):
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var edge := clampf(r - d, 0.0, 1.0)
			var fill := clampf(r - 3.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, ring.lerp(WHITE, fill) * Color(1, 1, 1, edge))
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
