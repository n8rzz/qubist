extends Control
## Greybox game screen, layout D: header, tower, piece tray, controls.
##
## Builds its UI in code and connects input to the core game. Styling is
## placeholder; sizes follow the concept wireframes (390×844 pt iPhone).

const Config := preload("res://core/config.gd")
const Game := preload("res://core/game.gd")
const Rules := preload("res://core/rules.gd")
const ViewMath := preload("res://game/view_math.gd")
const TowerView := preload("res://game/tower_view.gd")
const PiecePreview := preload("res://game/piece_preview.gd")
const IconButton := preload("res://game/icon_button.gd")

# Layout, in points (one point is one pixel of the 390×844 base viewport).
const SAFE_TOP := 54
const SAFE_BOTTOM := 34
const SIDE_MARGIN := 16
const GAP := 8
const HEADER_HEIGHT := 56
const TRAY_HEIGHT := 140
const CONTROLS_HEIGHT := 72
## Pause is hidden for MVP (#42); re-enable for the post-MVP timed mode.
const SHOW_PAUSE_BUTTON := false

## A dragged piece floats this far above the finger so the finger doesn't
## cover it.
const LIFT := 64.0
## How close, in points, the finger must be to a legal spot for the ghost to
## snap to it.
const SNAP_RADIUS := 72.0
## Screen distance, in cubes, within which a nearer block counts as hiding
## the ghost.
const OCCLUDE_RADIUS := 1.1

## Swiper button and chip labels, indexed by ViewMath mode.
const AXIS_NAMES := ["X", "Y", "Z"]
## Axis labels around the tower's base (#53): small and quiet, so they don't
## compete with the blocks. They fade out while the tower turns.
const AXIS_LABEL_SIZE := 11
const AXIS_LABEL_COLOR := Color("#8A8A86")
const AXIS_LABEL_GAP := 10.0
const AXIS_LABEL_FADE_SECONDS := 0.1

const BG := Color("#F4F4F2")
const INK := Color("#222222")
const MUTED := Color("#555555")
const LINE := Color("#555555")
const ACCENT := Color("#2559C9")
const WHITE := Color.WHITE

# Placeholder feedback (#47).
const SCORE_POP_COLOR := Color("#1B428F")
const SCORE_POP_RISE := 56.0
const SCORE_POP_SECONDS := 0.9
const BANNER_SECONDS := 1.2
const TRAY_FADE_SECONDS := 0.2

var config: Config = Config.new()
var game: Game
var best_score := 0

var tower: TowerView
var viewport_box: SubViewportContainer
var score_label: Label
var best_label: Label
var tray_slots: Array[PanelContainer] = []
var tray_previews: Array = []
var drag_preview: PiecePreview
var slice_chip: Label
var show_all_button: Button
var slice_slider: HSlider
var axis_buttons: Array[Button] = []
## Axis labels on the tower, indexed by ViewMath mode.
var axis_labels: Array[Label] = []
var overlay: Control
var overlay_panel: VBoxContainer

var slice_mode := ViewMath.MODE_X
var slice_depth := 0

var _drag_index := -1
var _has_target := false
var _target := Vector3i.ZERO
var _touches := {}
var _pinch_distance := 0.0
## Game over arrived while the move animation was playing; show it after.
var _pending_game_over := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	new_game()


func new_game() -> void:
	_clear_drag()
	tower.cancel_move_animation()
	_pending_game_over = false
	game = Game.new(config)
	game.game_over.connect(_on_game_over)
	game.tray_refilled.connect(_on_tray_refilled)
	game.start()
	_hide_overlay()
	_refresh()


func _process(delta: float) -> void:
	_update_axis_labels(delta)


## Keeps the axis labels beside the base as the view zooms, resizes or turns.
func _update_axis_labels(delta: float) -> void:
	# The front corner swaps halfway through a turn, so hide the labels until
	# the turn ends rather than have them jump.
	var target := 0.0 if tower.rig.is_turning() else 1.0
	var points := tower.axis_label_points(AXIS_LABEL_GAP)
	for i in range(axis_labels.size()):
		var label := axis_labels[i]
		label.modulate.a = move_toward(label.modulate.a, target, delta / AXIS_LABEL_FADE_SECONDS)
		label.position = points[i] - label.size * 0.5


# --- Input ---

func _input(event: InputEvent) -> void:
	if _drag_index >= 0:
		if event is InputEventMouseMotion:
			_update_drag(event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(event.position)
			get_viewport().set_input_as_handled()
		return
	_handle_zoom(event)


func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag(index, event.global_position)
		accept_event()


func _handle_zoom(event: InputEvent) -> void:
	var over_tower := false
	if event is InputEventMouse:
		over_tower = viewport_box.get_global_rect().has_point(event.position)
	if event is InputEventMouseButton and event.pressed and over_tower:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tower.rig.zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tower.rig.zoom_by(1.0 / 1.1)
	elif event is InputEventMagnifyGesture:
		tower.rig.zoom_by(event.factor)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_distance = _touch_spread()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var spread := _touch_spread()
			if _pinch_distance > 0.0 and spread > 0.0:
				tower.rig.zoom_by(spread / _pinch_distance)
			_pinch_distance = spread


func _touch_spread() -> float:
	if _touches.size() != 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])


# --- Dragging a piece ---

func _start_drag(index: int, finger: Vector2) -> void:
	# No new move until the last one has finished animating, so the grid and
	# the view stay in step.
	if game.is_over or overlay.visible or tower.is_animating() or game.tray[index] == null:
		return
	_drag_index = index
	drag_preview.set_piece(game.tray[index], tower.rig.view_step())
	drag_preview.visible = true
	tray_previews[index].modulate.a = 0.25
	_update_drag(finger)


func _update_drag(finger: Vector2) -> void:
	var lifted := finger - Vector2(0, LIFT)
	drag_preview.position = lifted - drag_preview.size * 0.5

	var rect := viewport_box.get_global_rect()
	var over_tower := rect.has_point(lifted)
	var found := false
	var origin := Vector3i.ZERO
	if over_tower:
		var snap: Array = _find_snap(game.tray[_drag_index], lifted - rect.position)
		found = snap[0]
		origin = snap[1]

	if found != _has_target or origin != _target:
		_has_target = found
		_target = origin
		if found:
			tower.show_ghost(_cells_at(game.tray[_drag_index], origin), true)
		else:
			tower.hide_ghost()
		_refresh_blocks()

	# Over the tower with nowhere to snap: tint the floating piece red.
	drag_preview.tint = Color(1.0, 0.55, 0.5) if over_tower and not found else Color.WHITE
	drag_preview.modulate.a = 0.55 if found else 1.0
	drag_preview.queue_redraw()


func _end_drag(finger: Vector2) -> void:
	_update_drag(finger)
	var index := _drag_index
	var place := _has_target
	var origin := _target
	_clear_drag()
	if place:
		var result: Dictionary = game.place(index, origin)
		if result.ok:
			Input.vibrate_handheld(15)
			# Sliced-away cubes stay faded instead of animating.
			tower.play_move(result.placed, result.cleared, _faded_cells())
			_show_score_gain(result)
	_refresh()


func _clear_drag() -> void:
	if _drag_index >= 0 and _drag_index < tray_previews.size():
		tray_previews[_drag_index].modulate.a = 1.0
	_drag_index = -1
	_has_target = false
	if drag_preview != null:
		drag_preview.visible = false
	if tower != null:
		tower.hide_ghost()


## Nearest legal origin whose piece center projects within SNAP_RADIUS of
## `point` (in the tower viewport). Returns [found: bool, origin: Vector3i].
func _find_snap(piece, point: Vector2) -> Array:
	var best_distance := SNAP_RADIUS
	var best := Vector3i.ZERO
	var found := false
	for origin in Rules.legal_positions(game.grid, piece):
		var center := ViewMath.cells_center(_cells_at(piece, origin), config.grid_size)
		var d := tower.project_point(center).distance_to(point)
		if d < best_distance:
			best_distance = d
			best = origin
			found = true
	return [found, best]


func _cells_at(piece, origin: Vector3i) -> Array:
	var out: Array = []
	for offset in piece.cells:
		out.append(origin + offset)
	return out


# --- View controls ---

func _turn(quarter_turns: int) -> void:
	tower.rig.turn(quarter_turns)
	_refresh()


func _set_slice_mode(mode: int) -> void:
	slice_mode = mode
	_refresh()


func _set_slice_depth(depth: int) -> void:
	slice_depth = depth
	if int(slice_slider.value) != depth:
		slice_slider.set_value_no_signal(depth)
	_refresh()


# --- Drawing state ---

func _refresh() -> void:
	if game == null:
		return
	score_label.text = _format(game.score)
	best_label.text = "Best %s" % _format(maxi(best_score, game.score))

	var step := tower.rig.view_step()
	for i in range(tray_slots.size()):
		var piece = game.tray[i] if i < game.tray.size() else null
		tray_previews[i].set_piece(piece, step)
		tray_slots[i].add_theme_stylebox_override("panel",
			_box(WHITE, LINE, 16) if piece != null else _box(Color(0, 0, 0, 0), Color("#9A9A9A"), 16))

	var layers := ViewMath.slice_layer_count(slice_mode, step, config.grid_size)
	# Modes can have different layer counts (Z has 12, X/Y have 6), so keep the
	# depth inside the current mode's range.
	slice_depth = mini(slice_depth, layers - 1)
	slice_slider.max_value = layers - 1
	slice_slider.set_value_no_signal(slice_depth)
	var axis_name: String = AXIS_NAMES[slice_mode]
	slice_chip.visible = slice_depth > 0
	show_all_button.visible = slice_depth > 0
	# X/Y number slices from the front. Z numbers them from the floor, so the
	# label matches the layer the player sees on top.
	var slice_number := layers - slice_depth if slice_mode == ViewMath.MODE_Z else slice_depth + 1
	slice_chip.text = "Slice %d of %d · %s" % [slice_number, layers, axis_name]
	for i in range(axis_buttons.size()):
		axis_buttons[i].set_pressed_no_signal(i == slice_mode)

	_refresh_blocks()


func _refresh_blocks() -> void:
	tower.update_blocks(game.grid.filled_cells(), _faded_cells())


## Cells to draw see-through: those the swiper has cut away, plus, while
## dragging, those that would hide the ghost.
func _faded_cells() -> Dictionary:
	var faded := {}
	var step := tower.rig.view_step()
	var filled: Array = game.grid.filled_cells()
	for c in filled:
		if ViewMath.is_sliced_away(c, slice_mode, step, config.grid_size, slice_depth):
			faded[c] = true
	if _drag_index < 0 or not _has_target:
		return faded

	var ghost := _cells_at(game.tray[_drag_index], _target)
	var radius := tower.cube_pixels() * OCCLUDE_RADIUS
	var ghost_points: Array = []
	var ghost_depths: Array = []
	for q in ghost:
		ghost_points.append(tower.project_cell(q))
		ghost_depths.append(tower.depth_of(q))
	for c in filled:
		if faded.has(c):
			continue
		var p := tower.project_cell(c)
		var depth := tower.depth_of(c)
		for i in range(ghost.size()):
			if depth < ghost_depths[i] and p.distance_to(ghost_points[i]) < radius:
				faded[c] = true
				break
	return faded


func _on_move_animation_finished() -> void:
	_refresh_blocks()
	if _pending_game_over:
		_pending_game_over = false
		_on_game_over(game.score)


## Skips any running animation. Used by the smoke test.
func finish_animations() -> void:
	tower.finish_move_animation()


func _on_game_over(final_score: int) -> void:
	if tower.is_animating():
		_pending_game_over = true
		return
	best_score = maxi(best_score, final_score)
	_show_overlay("No moves left", "Score %s\nBest %s" % [_format(final_score), _format(best_score)],
		"Play again", new_game)


## Floating "+points" over the move, and a combo/streak banner when they apply.
func _show_score_gain(result: Dictionary) -> void:
	var cells: Array = result.cleared if not result.cleared.is_empty() else result.placed
	var at := viewport_box.get_global_rect().position \
		+ tower.project_point(ViewMath.cells_center(cells, config.grid_size))
	var pop := _label("+%s" % _format(int(result.score.total)), 24 if result.lines.size() > 0 else 18, SCORE_POP_COLOR)
	add_child(pop)
	pop.reset_size()
	pop.position = at - pop.size * 0.5
	var tween := pop.create_tween().set_parallel()
	tween.tween_property(pop, "position:y", pop.position.y - SCORE_POP_RISE, SCORE_POP_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(pop, "modulate:a", 0.0, SCORE_POP_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(pop.queue_free)

	var parts: Array[String] = []
	if int(result.score.combo) > 1:
		parts.append("Combo ×%d" % int(result.score.combo))
	if result.lines.size() > 0 and int(result.score.streak) > 1:
		parts.append("Streak %d" % int(result.score.streak))
	if parts.is_empty():
		return
	var banner := _label("  ·  ".join(parts), 18, WHITE)
	banner.add_theme_stylebox_override("normal", _box(ACCENT, ACCENT, 18, 0, Vector2(16, 8)))
	add_child(banner)
	banner.reset_size()
	var rect := viewport_box.get_global_rect()
	banner.position = Vector2(rect.get_center().x - banner.size.x * 0.5, rect.position.y + 56)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.6, 0.6)
	var bt := banner.create_tween()
	bt.tween_property(banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_interval(BANNER_SECONDS)
	bt.tween_property(banner, "modulate:a", 0.0, 0.3)
	bt.tween_callback(banner.queue_free)


## New pieces fade into their slots, one after another.
func _on_tray_refilled(_tray: Array) -> void:
	for i in range(tray_previews.size()):
		var preview: Control = tray_previews[i]
		preview.modulate.a = 0.0
		var tween := preview.create_tween()
		tween.tween_interval(i * 0.06)
		tween.tween_property(preview, "modulate:a", 1.0, TRAY_FADE_SECONDS)


func _show_pause() -> void:
	_show_overlay("Paused", "", "Resume", _hide_overlay, "New game", new_game)


func _format(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


# --- Building the UI ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", SAFE_TOP)
	margin.add_theme_constant_override("margin_bottom", SAFE_BOTTOM)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", GAP)
	margin.add_child(column)
	column.add_child(_build_header())
	column.add_child(_build_tower_area())
	column.add_child(_build_tray())
	column.add_child(_build_controls())

	drag_preview = PiecePreview.new()
	drag_preview.size = Vector2(110, 110)
	drag_preview.unit = 18.0
	drag_preview.visible = false
	add_child(drag_preview)

	overlay = _build_overlay()
	add_child(overlay)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HEADER_HEIGHT
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var pause := _icon_button("pause", "Pause", 44, 12)
	pause.pressed.connect(_show_pause)
	if not SHOW_PAUSE_BUTTON:
		# Keep the slot so the score stays centered, but make it inert.
		pause.modulate.a = 0.0
		pause.disabled = true
		pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pause.focus_mode = Control.FOCUS_NONE
	row.add_child(pause)
	row.add_child(_spacer())

	var scores := VBoxContainer.new()
	scores.alignment = BoxContainer.ALIGNMENT_CENTER
	scores.add_theme_constant_override("separation", 0)
	score_label = _label("0", 28, INK)
	best_label = _label("Best 0", 12, MUTED)
	scores.add_child(score_label)
	scores.add_child(best_label)
	row.add_child(scores)

	row.add_child(_spacer())
	var settings := _icon_button("settings", "Settings", 44, 12)
	settings.pressed.connect(_show_pause)
	row.add_child(settings)
	return row


func _build_tower_area() -> Control:
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	viewport_box = SubViewportContainer.new()
	viewport_box.stretch = true
	viewport_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(viewport_box)

	var sub := SubViewport.new()
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_4X
	viewport_box.add_child(sub)
	tower = TowerView.new()
	sub.add_child(tower)
	tower.setup(config.grid_size)
	tower.rig.view_changed.connect(func(_step): _refresh())
	tower.move_animation_finished.connect(_on_move_animation_finished)

	for axis_name in AXIS_NAMES:
		var axis_label := _label(axis_name, AXIS_LABEL_SIZE, AXIS_LABEL_COLOR)
		area.add_child(axis_label)
		axis_labels.append(axis_label)

	slice_chip = _label("", 13, Color("#1B428F"))
	slice_chip.add_theme_stylebox_override("normal", _box(WHITE, ACCENT, 16, 2, Vector2(10, 4)))
	slice_chip.position = Vector2(12, 12)
	slice_chip.visible = false
	area.add_child(slice_chip)

	show_all_button = _text_button("Show all", 13)
	show_all_button.custom_minimum_size = Vector2(96, 44)
	show_all_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	show_all_button.offset_left = -108
	show_all_button.offset_right = -12
	show_all_button.offset_top = 8
	show_all_button.offset_bottom = 52
	show_all_button.pressed.connect(func(): _set_slice_depth(0))
	show_all_button.visible = false
	area.add_child(show_all_button)

	# Rotate buttons sit in the bottom corners beside the base, so the swiper
	# can use the whole controls row.
	for dir in [-1, 1]:
		var b := _icon_button("rotate_left" if dir < 0 else "rotate_right",
			"Rotate tower left" if dir < 0 else "Rotate tower right", 52, 26)
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if dir < 0 else Control.PRESET_BOTTOM_RIGHT)
		b.offset_left = 4 if dir < 0 else -56
		b.offset_right = 56 if dir < 0 else -4
		b.offset_top = -56
		b.offset_bottom = -4
		b.pressed.connect(_turn.bind(dir))
		area.add_child(b)
	return area


func _build_tray() -> Control:
	var tray := HBoxContainer.new()
	tray.custom_minimum_size.y = TRAY_HEIGHT
	tray.add_theme_constant_override("separation", 10)
	for i in range(config.tray_size):
		var slot := PanelContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", _box(WHITE, LINE, 16))
		slot.gui_input.connect(_on_slot_input.bind(i))
		var preview := PiecePreview.new()
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(preview)
		tray.add_child(slot)
		tray_slots.append(slot)
		tray_previews.append(preview)
	return tray


func _build_controls() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = CONTROLS_HEIGHT
	row.add_theme_constant_override("separation", 8)


	var swiper := PanelContainer.new()
	swiper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swiper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swiper.custom_minimum_size.y = 56
	swiper.add_theme_stylebox_override("panel", _box(WHITE, LINE, 28, 2, Vector2(6, 6)))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	swiper.add_child(inner)

	var axes := HBoxContainer.new()
	axes.add_theme_constant_override("separation", 0)
	var group := ButtonGroup.new()
	for mode in [ViewMath.MODE_X, ViewMath.MODE_Y, ViewMath.MODE_Z]:
		var b := _text_button(AXIS_NAMES[mode], 14)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(44, 40)
		b.add_theme_stylebox_override("normal", _box(Color("#ECECEA"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_stylebox_override("hover", _box(Color("#E2E2E0"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_stylebox_override("pressed", _box(Color("#333333"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_color_override("font_pressed_color", WHITE)
		b.add_theme_color_override("font_hover_pressed_color", WHITE)
		b.pressed.connect(_set_slice_mode.bind(mode))
		axes.add_child(b)
		axis_buttons.append(b)
	inner.add_child(axes)

	# The chip over the tower names the slice, so the slider gets the bar's
	# full height and a large grabber to make it easy to hit with a thumb.
	slice_slider = HSlider.new()
	slice_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slice_slider.size_flags_vertical = Control.SIZE_FILL
	slice_slider.min_value = 0
	slice_slider.max_value = config.grid_size.y - 1
	slice_slider.step = 1
	slice_slider.focus_mode = Control.FOCUS_NONE
	slice_slider.custom_minimum_size.y = 40
	var grabber := _grabber_texture(26)
	slice_slider.add_theme_icon_override("grabber", grabber)
	slice_slider.add_theme_icon_override("grabber_highlight", grabber)
	slice_slider.add_theme_stylebox_override("slider", _track(Color("#D6D6D3")))
	slice_slider.add_theme_stylebox_override("grabber_area", _track(Color("#333333")))
	slice_slider.add_theme_stylebox_override("grabber_area_highlight", _track(Color("#333333")))
	slice_slider.value_changed.connect(func(v: float): _set_slice_depth(int(v)))
	inner.add_child(slice_slider)
	row.add_child(swiper)

	return row


func _build_overlay() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 310
	panel.add_theme_stylebox_override("panel", _box(WHITE, LINE, 24, 2, Vector2(24, 24)))
	center.add_child(panel)
	overlay_panel = VBoxContainer.new()
	overlay_panel.add_theme_constant_override("separation", 14)
	panel.add_child(overlay_panel)
	return root


func _show_overlay(title: String, body: String, primary: String, on_primary: Callable,
		secondary: String = "", on_secondary: Callable = Callable()) -> void:
	for child in overlay_panel.get_children():
		child.queue_free()
	overlay_panel.add_child(_label(title, 22, INK))
	if body != "":
		overlay_panel.add_child(_label(body, 16, MUTED))
	var first := _text_button(primary, 16, true)
	first.custom_minimum_size.y = 52
	first.pressed.connect(on_primary)
	overlay_panel.add_child(first)
	if secondary != "":
		var second := _text_button(secondary, 14)
		second.custom_minimum_size.y = 44
		second.pressed.connect(on_secondary)
		overlay_panel.add_child(second)
	overlay.visible = true


func _hide_overlay() -> void:
	if overlay != null:
		overlay.visible = false


# --- Widgets ---

func _box(bg: Color, border: Color, radius: int, width: int = 2, padding := Vector2.ZERO) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	box.anti_aliasing = true
	return box


## Slider track: a rounded bar 8 px thick.
func _track(color: Color) -> StyleBoxFlat:
	var box := _box(color, Color(0, 0, 0, 0), 4, 0)
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## A round slider grabber: white with a dark ring, drawn in code so the
## greybox needs no image assets.
func _grabber_texture(diameter: int) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter * 0.5
	for y in range(diameter):
		for x in range(diameter):
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var ring := clampf(r - d, 0.0, 1.0)
			var fill := clampf(r - 2.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color("#333333").lerp(WHITE, fill) * Color(1, 1, 1, ring))
	return ImageTexture.create_from_image(img)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _text_button(text: String, font_size: int, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var bg := INK if primary else WHITE
	var fg := WHITE if primary else INK
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_stylebox_override("normal", _box(bg, LINE, 22))
	b.add_theme_stylebox_override("hover", _box(bg.darkened(0.05), LINE, 22))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.12), LINE, 22))
	return b


func _icon_button(kind: String, label: String, side: int, radius: int) -> IconButton:
	var b := IconButton.new(kind, label)
	b.custom_minimum_size = Vector2(side, side)
	b.add_theme_stylebox_override("normal", _box(WHITE, LINE, radius))
	b.add_theme_stylebox_override("hover", _box(Color("#F0F0EE"), LINE, radius))
	b.add_theme_stylebox_override("pressed", _box(Color("#E2E2E0"), LINE, radius))
	return b


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# --- Test hooks ---

## Places a piece through the same drag path a finger would take: presses the
## tray slot, moves to where the ghost would snap, releases. Returns true if a
## move was made. Used by the smoke test.
func autoplay_one_move() -> bool:
	for i in range(game.tray.size()):
		var piece = game.tray[i]
		if piece == null:
			continue
		var options := Rules.legal_positions(game.grid, piece)
		if options.is_empty():
			continue
		var origin: Vector3i = options[options.size() >> 1]
		var center := ViewMath.cells_center(_cells_at(piece, origin), config.grid_size)
		var finger := viewport_box.get_global_rect().position + tower.project_point(center) + Vector2(0, LIFT)
		var before := game.moves
		_start_drag(i, finger)
		_update_drag(finger)
		_end_drag(finger)
		return game.moves == before + 1
	return false
