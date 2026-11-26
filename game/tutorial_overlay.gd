extends Control
## What the tutorial (#29) draws over the game screen, following the
## Tutorial artboard in the Qubist designs: a dim with the step's controls
## cut out, a yellow ring on the control to press, the "Step N of 3" bar
## with Skip, a white card with the step's text, and a hand showing the move.
##
## game/tutorial_run.gd decides what goes where; this only draws it.

signal skip_pressed

const UI := preload("res://game/ui_style.gd")

const DIM := Color(UI.DIM_INK, 0.55)
const HIGHLIGHT := Color("#FFC94D")
const DOT := Color(1, 1, 1, 0.5)
const SKIP_FACE := Color(1, 1, 1, 0.18)
const SKIP_PRESSED := Color(1, 1, 1, 0.3)
const CARD_WIDTH := 280
const CARD_RADIUS := 22
## The card's pointer: 22 wide, 12 deep, 22 in from the card's right edge.
const TAIL_SIZE := Vector2(22, 12)
const TAIL_INSET := 22.0
## Space between the card's pointer and the control it points at.
const CARD_GAP := 6.0
const BAR_TOP := UI.SAFE_TOP + 4
const BAR_HEIGHT := 44
## The hand icon's side, and where its fingertip sits in that box.
const HAND_SIDE := 44.0
const HAND_TIP := Vector2(19.0, 6.0)
const HAND_TILT_DEG := -18.0
const HAND_DRAG_SECONDS := 1.1

## The design's hand: white with an ink outline (24-unit grid).
const HAND_SVG := """
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"
	fill="#FFFFFF" stroke="#22313F" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
	<path d="M9 11V5.5a1.5 1.5 0 0 1 3 0V11M12 10V4.5a1.5 1.5 0 0 1 3 0V11
		M15 10.5V6.5a1.5 1.5 0 0 1 3 0V14a7 7 0 0 1-7 7h-.5a6 6 0 0 1-5-2.7
		L3 14.5a1.6 1.6 0 0 1 2.6-1.9L9 15V8.5"/>
</svg>"""

var spotlight: Spotlight
var ring: Ring
var dots: HBoxContainer
var step_label: Label
var skip_button: Button
var card: PanelContainer
var title_label: Label
var body_label: Label
var tail: Tail
var hand: TextureRect
var _hand_tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	spotlight = Spotlight.new()
	add_child(spotlight)
	ring = Ring.new()
	add_child(ring)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = UI.SIDE_MARGIN
	bar.offset_right = -UI.SIDE_MARGIN
	bar.offset_top = BAR_TOP
	bar.offset_bottom = BAR_TOP + BAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(dots)
	step_label = UI.label("", 13, UI.WHITE)
	step_label.add_theme_font_override("font", UI.body_font(600))
	step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step_label.size_flags_vertical = Control.SIZE_FILL
	var label_margin := MarginContainer.new()
	label_margin.add_theme_constant_override("margin_left", 6)
	label_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_margin.add_child(step_label)
	bar.add_child(label_margin)
	bar.add_child(UI.spacer())
	skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.tooltip_text = "Skip the tutorial"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.custom_minimum_size.y = BAR_HEIGHT
	skip_button.add_theme_font_size_override("font_size", 15)
	skip_button.add_theme_font_override("font", UI.body_font(600))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		skip_button.add_theme_color_override(state, UI.WHITE)
	skip_button.add_theme_stylebox_override("normal", UI.box(SKIP_FACE, 22, Vector2(18, 0)))
	skip_button.add_theme_stylebox_override("hover", UI.box(SKIP_PRESSED, 22, Vector2(18, 0)))
	skip_button.add_theme_stylebox_override("pressed", UI.box(SKIP_PRESSED, 22, Vector2(18, 0)))
	skip_button.pressed.connect(func(): skip_pressed.emit())
	bar.add_child(skip_button)
	add_child(bar)

	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size.x = CARD_WIDTH
	var style := UI.box(UI.WHITE, CARD_RADIUS, Vector2(18, 0))
	style.content_margin_top = 18
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 17
	style.shadow_offset = Vector2(0, 14)
	card.add_theme_stylebox_override("panel", style)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label = UI.label("", 22, UI.SKY_INK)
	title_label.add_theme_font_override("font", UI.title_font(600))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label = UI.label("", 15, UI.SKY_MUTED)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_constant_override("line_spacing", 3)
	text.add_child(title_label)
	text.add_child(body_label)
	card.add_child(text)
	add_child(card)
	tail = Tail.new()
	add_child(tail)

	hand = TextureRect.new()
	hand.texture = _hand_texture()
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_SCALE
	hand.size = Vector2(HAND_SIDE, HAND_SIDE)
	hand.pivot_offset = HAND_TIP
	hand.rotation_degrees = HAND_TILT_DEG
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.visible = false
	add_child(hand)


## Shows step `index` (from 0) of `count` in the top bar.
func set_progress(index: int, count: int) -> void:
	for child in dots.get_children():
		child.queue_free()
	for i in range(count):
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(22 if i == index else 8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UI.box(HIGHLIGHT if i == index else DOT, 4))
		dots.add_child(dot)
	step_label.text = "Step %d of %d" % [index + 1, count]


func set_text(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body


## Puts the card under the top bar, centered, with no pointer.
func place_card_at_top() -> void:
	var left := (size.x - CARD_WIDTH) * 0.5
	_place_card(left, BAR_TOP + BAR_HEIGHT + 14, Control.GROW_DIRECTION_END)
	tail.visible = false


## Puts the card just above `target`, against the screen's right edge, with
## its pointer aimed down at the middle of `target`.
func place_card_above(target: Rect2) -> void:
	var left := size.x - UI.SIDE_MARGIN - CARD_WIDTH
	var bottom := target.position.y - CARD_GAP - TAIL_SIZE.y
	_place_card(left, bottom, Control.GROW_DIRECTION_BEGIN)
	var tail_x := clampf(
		target.get_center().x - TAIL_SIZE.x * 0.5,
		left + CARD_RADIUS,
		left + CARD_WIDTH - CARD_RADIUS - TAIL_SIZE.x
	)
	tail.position = Vector2(tail_x, bottom - 1)
	tail.size = TAIL_SIZE + Vector2(0, 1)
	tail.visible = true


func _place_card(left: float, edge: float, grow: int) -> void:
	card.anchor_left = 0
	card.anchor_right = 0
	card.anchor_top = 0
	card.anchor_bottom = 0
	card.offset_left = left
	card.offset_right = left + CARD_WIDTH
	card.offset_top = edge
	card.offset_bottom = edge
	card.grow_vertical = grow


## Dims everything but `holes`, a list of [Rect2, corner radius]; input
## inside a hole reaches the game beneath. Rings `highlight` in yellow
## unless it is empty.
func set_spotlight(holes: Array, highlight := Rect2(), highlight_radius := 0.0) -> void:
	spotlight.set_holes(holes)
	ring.target = highlight
	ring.radius = highlight_radius
	ring.queue_redraw()


## Loops the hand pressing at `from` and dragging to `to`.
func show_hand_drag(from: Vector2, to: Vector2) -> void:
	_restart_hand(from)
	_hand_tween.tween_property(hand, "modulate:a", 1.0, 0.2)
	_hand_tween.tween_property(hand, "scale", Vector2(0.88, 0.88), 0.15)
	(
		_hand_tween
		. tween_property(hand, "position", to - HAND_TIP, HAND_DRAG_SECONDS)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_hand_tween.tween_property(hand, "scale", Vector2.ONE, 0.15)
	_hand_tween.tween_property(hand, "modulate:a", 0.0, 0.25).set_delay(0.2)
	_hand_tween.tween_interval(0.4)
	_hand_tween.tween_callback(func(): hand.position = from - HAND_TIP)


## Loops the hand tapping at `at`.
func show_hand_tap(at: Vector2) -> void:
	_restart_hand(at)
	hand.modulate.a = 1.0
	_hand_tween.tween_property(hand, "scale", Vector2(0.85, 0.85), 0.18)
	_hand_tween.tween_property(hand, "scale", Vector2.ONE, 0.18)
	_hand_tween.tween_interval(0.7)


func hide_hand() -> void:
	if _hand_tween != null:
		_hand_tween.kill()
	hand.visible = false


func _restart_hand(at: Vector2) -> void:
	if _hand_tween != null:
		_hand_tween.kill()
	hand.position = at - HAND_TIP
	hand.scale = Vector2.ONE
	hand.modulate.a = 0.0
	hand.visible = true
	_hand_tween = create_tween().set_loops()


static func _hand_texture() -> ImageTexture:
	var img := Image.new()
	# Drawn at twice the size it shows at, so it stays crisp when scaled.
	img.load_svg_from_string(HAND_SVG, HAND_SIDE * 2.0 / 24.0)
	return ImageTexture.create_from_image(img)


## The dim. Clicks inside a hole fall through to whatever is underneath.
class Spotlight:
	extends ColorRect

	const MAX_HOLES := 4
	const SHADER := preload("res://game/shaders/spotlight.gdshader")

	var _holes: Array[Rect2] = []

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("dim_color", DIM)
		material = mat

	func set_holes(holes: Array) -> void:
		_holes.clear()
		var rects: Array[Vector4] = []
		var radii: Array[float] = []
		for hole in holes.slice(0, MAX_HOLES):
			var r: Rect2 = hole[0]
			_holes.append(r)
			rects.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
			radii.append(float(hole[1]))
		while rects.size() < MAX_HOLES:
			rects.append(Vector4.ZERO)
			radii.append(0.0)
		material.set_shader_parameter("holes", rects)
		material.set_shader_parameter("radii", radii)
		material.set_shader_parameter("hole_count", _holes.size())

	func is_lit(point: Vector2) -> bool:
		for r in _holes:
			if r.has_point(point):
				return true
		return false

	func _has_point(point: Vector2) -> bool:
		return Rect2(Vector2.ZERO, size).has_point(point) and not is_lit(point)

	func _gui_input(event: InputEvent) -> void:
		# Taps on the dim do nothing, but don't reach the game either.
		if event is InputEventMouseButton:
			accept_event()


## The design's highlight: a white ring then a yellow one around a control.
class Ring:
	extends Control

	var target := Rect2()
	var radius := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if target.size == Vector2.ZERO:
			return
		for band in [[8.0, HIGHLIGHT], [4.0, UI.WHITE]]:
			var grow: float = band[0]
			var style := StyleBoxFlat.new()
			style.bg_color = UI.CLEAR
			style.border_color = band[1]
			style.set_border_width_all(4)
			style.set_corner_radius_all(int(radius + grow))
			style.anti_aliasing = true
			draw_style_box(style, target.grow(grow))


## The card's pointer, a small white triangle below it.
class Tail:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2.ZERO,
					Vector2(size.x, 0),
					Vector2(size.x * 0.5, size.y),
				]
			),
			UI.WHITE
		)
