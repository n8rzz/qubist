extends RefCounted
## Colours and widget builders shared by the game screen, the Settings sheet,
## the Stats screen and Home, following the Qubist designs canvas.

const IconButton := preload("res://game/icon_button.gd")

## Fredoka for titles and numbers, Inter for UI text. Both are variable fonts,
## so each weight is a FontVariation on the one file. Inter at 400 is also the
## project's default font, set in assets/ui_theme.tres.
const FREDOKA: FontFile = preload("res://assets/fonts/Fredoka-Variable.ttf")
const INTER: FontFile = preload("res://assets/fonts/Inter-Variable.ttf")

const WHITE := Color.WHITE
## Fully transparent, for a box with no fill or border.
const CLEAR := Color(0, 0, 0, 0)
## The dim navy laid over the screen behind sheets, cards and the tutorial.
## Each place sets its own alpha: Color(UI.DIM_INK, 0.45).
const DIM_INK := Color(16 / 255.0, 32 / 255.0, 44 / 255.0)

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
## The pale track behind segmented toggles, and the slider's rail.
const SEGMENT_TRACK := Color("#EAF1F5")
const SLIDER_RAIL := Color("#D5E2EA")
## A switch's track while off, and the Settings sheet's drag handle.
const SWITCH_OFF := Color("#C9D5DC")
## Tray cards are slightly see-through so the sky tints them.
const TRAY_CARD := Color(1, 1, 1, 0.86)

## Points kept clear of the notch and the home indicator (390×844 iPhone).
const SAFE_TOP := 54
const SAFE_BOTTOM := 34
const SIDE_MARGIN := 16

static var _fonts := {}

## Tests set this to 1 or 0 to force Reduce Motion on or off; -1 asks the
## device.
static var motion_override := -1


## Whether iOS Reduce Motion is on (#116). Everything that moves on its own
## checks this and holds still, fades or jumps to its end instead.
static func reduce_motion() -> bool:
	if motion_override >= 0:
		return motion_override == 1
	# 1 is on; 0 is off and -1 is unknown, which shouldn't freeze anything.
	return DisplayServer.accessibility_should_reduce_animation() == 1


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
		font.variation_opentype = {
			TextServerManager.get_primary_interface().name_to_tag("wght"): weight
		}
		font.spacing_glyph = spacing
		_fonts[key] = font
	return _fonts[key]


## A rounded `bg` box. It has no border unless `width` and `border` are given.
static func box(
	bg: Color, radius: int, padding := Vector2.ZERO, border := CLEAR, width: int = 0
) -> StyleBoxFlat:
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


static func label(
	text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
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
	var b := box(color, radius, padding)
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
	b.add_theme_stylebox_override("disabled", card(WHITE, radius, padding))


## A white icon tile. Pass `radius` = side / 2 for a round button. In a row
## taller than `side` it stays square, centered (#255).
static func icon_button(
	kind: String, tooltip: String, side: int = 44, radius: int = 14
) -> IconButton:
	var b := IconButton.new(kind, tooltip)
	b.icon_color = SKY_INK
	b.custom_minimum_size = Vector2(side, side)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		b.add_theme_stylebox_override("normal", accent_key(22))
		b.add_theme_stylebox_override("hover", accent_key(22, SKY_ACCENT.lightened(0.06)))
		b.add_theme_stylebox_override("pressed", accent_key(22, SKY_ACCENT.darkened(0.08), 1))
	else:
		style_card_button(b, 22)
	return b


## The teal primary face with its dark ledge `drop` points deep, shared by
## primary buttons and the swiper's chosen axis.
static func accent_key(radius: int, face: Color = SKY_ACCENT, drop: int = 4) -> StyleBoxFlat:
	var style := box(face, radius)
	style.shadow_color = ACCENT_LEDGE
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, drop)
	return style


## One choice of a segmented toggle: `on_style` and `on_color` text while
## picked, no fill and `off_color` text otherwise. The caller gives the
## buttons of a toggle one ButtonGroup.
static func segment_button(
	text: String, font_size: int, on_style: StyleBox, on_color: Color, off_color: Color
) -> Button:
	var b := text_button(text, font_size)
	b.toggle_mode = true
	var off := box(CLEAR, 0)
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, off)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, on_style)
	for state in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(state, off_color)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, on_color)
	return b


## The pale pill around a segmented toggle's `row` of segment_button()s.
static func segment_track(row: HBoxContainer, radius: int) -> PanelContainer:
	row.add_theme_constant_override("separation", 0)
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", box(SEGMENT_TRACK, radius, Vector2(2, 2)))
	track.add_child(row)
	return track


## Slider track: a rounded bar 10 px thick.
static func slider_track(color: Color) -> StyleBoxFlat:
	var b := box(color, 5)
	b.content_margin_top = 5
	b.content_margin_bottom = 5
	return b


## A round slider knob like the Settings switch's: plain white with a soft
## shadow 2 px below it, drawn in code so it needs no image assets. The
## texture is 3 px taller than `diameter` to fit the shadow.
static func knob_texture(diameter: int) -> ImageTexture:
	var img := Image.create(diameter, diameter + 3, false, Image.FORMAT_RGBA8)
	var r := diameter * 0.5
	var knob := Vector2(r, r)
	var shadow := knob + Vector2(0, 2)
	for y in range(diameter + 3):
		for x in range(diameter):
			var p := Vector2(x + 0.5, y + 0.5)
			var a_knob := clampf(r - 0.5 - p.distance_to(knob), 0.0, 1.0)
			var a_shadow := clampf(r - p.distance_to(shadow), 0.0, 1.0) * 0.12
			var out_a := a_knob + a_shadow * (1.0 - a_knob)
			if out_a <= 0.0:
				continue
			var c := WHITE * a_knob + Color.BLACK * a_shadow * (1.0 - a_knob)
			img.set_pixel(x, y, Color(c.r / out_a, c.g / out_a, c.b / out_a, out_a))
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
