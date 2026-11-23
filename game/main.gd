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
const SkyBackdrop := preload("res://game/sky_backdrop.gd")
const PiecePreview := preload("res://game/piece_preview.gd")
const UI := preload("res://game/ui_style.gd")
const Stats := preload("res://core/stats.gd")
const SaveFile := preload("res://core/save_file.gd")
const Settings := preload("res://core/settings.gd")
const SettingsSheet := preload("res://game/settings_sheet.gd")
const StatsScreen := preload("res://game/stats_screen.gd")
const HomeScreen := preload("res://game/home_screen.gd")
const Swiper := preload("res://game/swiper.gd")
const DragController := preload("res://game/drag_controller.gd")
const ScoreFeedback := preload("res://game/score_feedback.gd")
const GameOverCard := preload("res://game/game_over_card.gd")

# Layout, in points (one point is one pixel of the 390×844 base viewport).
const GAP := 8
const HEADER_HEIGHT := 56
const TRAY_HEIGHT := 140
const CONTROLS_HEIGHT := 72
## Pause is hidden for MVP (#42); re-enable for the post-MVP timed mode.
const SHOW_PAUSE_BUTTON := false

## Axis labels around the tower's base (#53): small and quiet, so they don't
## compete with the blocks. They fade out while the tower turns.
const AXIS_LABEL_SIZE := 11
## White, to read on the island's brick rim and earth underside (#23).
const AXIS_LABEL_COLOR := Color(1, 1, 1, 0.92)
const AXIS_LABEL_GAP := 10.0
const AXIS_LABEL_FADE_SECONDS := 0.1

## Blue for the slice chip's border and the combo banner. The other colours
## come from game/ui_style.gd.
const ACCENT := Color("#2559C9")

const TRAY_FADE_SECONDS := 0.2

var config: Config = Config.new()
var game: Game
## Lifetime stats (#32), loaded from and saved to `stats_path`.
var stats: Stats = Stats.new()
## Set before the node enters the tree to keep tests off the real save.
var stats_path := "user://stats.json"
## Player settings, loaded from and saved to `settings_path`.
var settings: Settings = Settings.new()
var settings_path := "user://settings.json"
## The in-progress game and camera, saved after every placement and when the
## app goes to the background, and resumed on launch (#18).
var game_save_path := "user://game.json"
## The game already added to `stats`, so it is never counted twice.
var _recorded_game: Game
## The "+points" pop, the combo/streak banner and the header count-up.
var score_feedback := ScoreFeedback.new(self)
## The score the header shows; trails game.score while the counter ticks up.
var shown_score: int:
	get:
		return score_feedback.shown_score

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
var game_over_card: GameOverCard
var settings_sheet: SettingsSheet
var stats_screen: StatsScreen
var home: HomeScreen
## Stats was opened from the Settings sheet, so Back returns there; from
## Home, Back just closes it.
var _stats_from_settings := false

## Slice mode, depth and the sweep plane's fade.
var swiper: Swiper = Swiper.new(config.grid_size)

## Dragging a piece from the tray onto the tower.
var drag := DragController.new(self)
var _touches := {}
var _pinch_distance := 0.0
## Game over arrived while the move animation was playing; show it after.
var _pending_game_over := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stats.from_dict(SaveFile.read(stats_path))
	settings.from_dict(SaveFile.read(settings_path))
	drag.target_changed.connect(_refresh_blocks)
	drag.dropped.connect(_place)
	_build_ui()
	if not resume_game():
		new_game()
	show_home()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()


func new_game() -> void:
	var fresh := Game.new(config)
	_use_game(fresh)
	fresh.start()
	_refresh()
	save_game()


## Picks up the saved game and camera. Returns false, leaving nothing
## resumed, if there is no save or it doesn't fit the current config.
func resume_game() -> bool:
	var data := SaveFile.read(game_save_path)
	if data.is_empty():
		return false
	var saved := Game.new(config)
	if not saved.from_dict(data.get("game", {})):
		SaveFile.remove(game_save_path)
		return false
	if saved.is_over:
		# The app closed before the game-over screen counted it.
		game = saved
		_record_finished_game()
		return false
	_use_game(saved)
	var view: Dictionary = data.get("view", {})
	tower.rig.restore(int(view.get("step", 0)), float(view.get("zoom", tower.rig.camera.size)))
	_refresh()
	return true


## Writes the current game and camera to `game_save_path`. A finished game
## that is already in the stats is not saved, so it can't be counted again.
func save_game() -> void:
	if game == null:
		return
	if _recorded_game == game:
		SaveFile.remove(game_save_path)
		return
	SaveFile.write(game_save_path, {
		"game": game.to_dict(),
		"view": {"step": tower.rig.view_step(), "zoom": tower.rig.camera.size},
	})


func _use_game(next: Game) -> void:
	drag.clear()
	tower.cancel_move_animation()
	_pending_game_over = false
	game = next
	game.game_over.connect(_on_game_over)
	game.tray_refilled.connect(_on_tray_refilled)
	_hide_overlay()
	game_over_card.close()
	score_feedback.snap()


func _process(delta: float) -> void:
	_update_axis_labels(delta)
	if swiper.update_sweep(delta, tower.rig.is_turning()):
		tower.set_sweep_alpha(swiper.sweep_alpha())


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
	if drag.is_dragging():
		if event is InputEventMouseMotion:
			drag.update(event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			drag.end(event.position)
			_refresh()
			get_viewport().set_input_as_handled()
		return
	if menu_open():
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
	if game.is_over or overlay.visible or game_over_card.visible or menu_open() or tower.is_animating() or game.tray[index] == null:
		return
	drag.start(index, finger)


## The dragged piece was let go over a legal spot.
func _place(index: int, origin: Vector3i) -> void:
	var result: Dictionary = game.place(index, origin)
	if result.ok:
		Input.vibrate_handheld(15)
		# Sliced-away cubes stay faded instead of animating.
		tower.play_move(result.placed, result.cleared, _faded_cells(), result.lines.size())
		score_feedback.show_gain(result)
		save_game()


# --- View controls ---

func _turn(quarter_turns: int) -> void:
	tower.rig.turn(quarter_turns)
	_refresh()


func _set_slice_mode(mode: int) -> void:
	swiper.mode = mode
	_refresh()


func _set_slice_depth(depth: int) -> void:
	swiper.depth = depth
	if int(slice_slider.value) != depth:
		slice_slider.set_value_no_signal(depth)
	_refresh()


# --- Drawing state ---

func _refresh() -> void:
	if game == null:
		return
	score_feedback.tick_to(game.score)

	var step := tower.rig.view_step()
	for i in range(tray_slots.size()):
		var piece = game.tray[i] if i < game.tray.size() else null
		tray_previews[i].set_piece(piece, step)
		tray_slots[i].add_theme_stylebox_override("panel",
			UI.box(UI.WHITE, UI.LINE, 16) if piece != null else UI.box(Color(0, 0, 0, 0), Color("#9A9A9A"), 16))

	swiper.fit(step)
	slice_slider.max_value = swiper.layer_count(step) - 1
	slice_slider.set_value_no_signal(swiper.depth)
	slice_chip.visible = swiper.is_sliced()
	show_all_button.visible = swiper.is_sliced()
	slice_chip.text = swiper.chip_text(step)
	for i in range(axis_buttons.size()):
		axis_buttons[i].set_pressed_no_signal(i == swiper.mode)

	_refresh_blocks()


func _refresh_blocks() -> void:
	var filled: Array = game.grid.filled_cells()
	var faded := _faded_cells()
	var step := tower.rig.view_step()
	var shade := swiper.shade(filled, faded, step)
	tower.update_blocks(filled, faded, shade.behind)
	tower.set_sweep(swiper.plane(step), swiper.toward_viewer(step), shade.cap)


## Cells to draw see-through: those the swiper has cut away, plus, while
## dragging, those that would hide the ghost.
func _faded_cells() -> Dictionary:
	var filled: Array = game.grid.filled_cells()
	var faded := swiper.faded_cells(filled, tower.rig.view_step())
	drag.fade_occluders(faded, filled)
	return faded


func _on_move_animation_finished() -> void:
	_refresh_blocks()
	if _pending_game_over:
		_pending_game_over = false
		_on_game_over(game.score)


## Skips any running animation. Used by the smoke test.
func finish_animations() -> void:
	tower.finish_move_animation()
	score_feedback.snap()


func _on_game_over(_final_score: int) -> void:
	if tower.is_animating():
		_pending_game_over = true
		return
	_record_finished_game()
	# Above the last move's score pop and banner. Menus can't open while the
	# card is up, so it never covers them.
	game_over_card.move_to_front()
	game_over_card.open(game, stats.best_score)


## Adds the finished game to the lifetime stats and saves them, once per game.
func _record_finished_game() -> void:
	if _recorded_game == game or not game.is_over:
		return
	_recorded_game = game
	stats.record_game(game)
	SaveFile.write(stats_path, stats.to_dict())
	SaveFile.remove(game_save_path)


## True while Home, the Settings sheet or the Stats screen covers the game.
func menu_open() -> bool:
	return (settings_sheet != null and settings_sheet.visible) \
		or (stats_screen != null and stats_screen.visible) \
		or (home != null and home.visible)


## True if there's a game worth resuming: started and not over.
func can_continue() -> bool:
	return game != null and not game.is_over and game.moves > 0


## Shows Home over the game (#72). The game stays saved, ready for Continue.
func show_home() -> void:
	drag.clear()
	save_game()
	_hide_overlay()
	game_over_card.close()
	settings_sheet.visible = false
	stats_screen.visible = false
	var resume := can_continue()
	home.open(stats.best_score, game.score if resume else -1,
		game.grid.filled_cells() if resume else [])
	# Nothing to draw behind Home, so let the 3D view rest.
	viewport_box.visible = false


func _leave_home() -> void:
	home.visible = false
	viewport_box.visible = true
	_refresh()


func _on_home_new_game() -> void:
	new_game()
	_leave_home()


func _on_home_continue() -> void:
	_leave_home()


func _on_home_stats() -> void:
	_stats_from_settings = false
	stats_screen.open(stats)


func show_settings() -> void:
	drag.clear()
	stats_screen.visible = false
	settings_sheet.open(not home.visible)


## Turns the grid ticks on the tower's border on or off and saves it (#56).
func set_grid_ticks(on: bool) -> void:
	settings.grid_ticks = on
	tower.set_grid_ticks(on)
	settings_sheet.set_grid_ticks(on)
	SaveFile.write(settings_path, settings.to_dict())


func show_stats() -> void:
	_stats_from_settings = true
	settings_sheet.visible = false
	stats_screen.open(stats)


func _on_stats_back() -> void:
	if _stats_from_settings:
		show_settings()
	else:
		stats_screen.visible = false


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


# --- Building the UI ---

func _build_ui() -> void:
	# The sky shows through the tower's viewport, behind the island (#23).
	add_child(SkyBackdrop.new())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", UI.SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", UI.SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", UI.SAFE_TOP)
	margin.add_theme_constant_override("margin_bottom", UI.SAFE_BOTTOM)
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
	game_over_card = GameOverCard.new()
	game_over_card.play_again_pressed.connect(new_game)
	add_child(game_over_card)

	home = HomeScreen.new()
	home.new_game_pressed.connect(_on_home_new_game)
	home.continue_pressed.connect(_on_home_continue)
	home.stats_pressed.connect(_on_home_stats)
	home.settings_pressed.connect(show_settings)
	add_child(home)

	settings_sheet = SettingsSheet.new()
	settings_sheet.stats_pressed.connect(show_stats)
	settings_sheet.home_pressed.connect(show_home)
	settings_sheet.grid_ticks_toggled.connect(set_grid_ticks)
	settings_sheet.set_grid_ticks(settings.grid_ticks)
	add_child(settings_sheet)
	stats_screen = StatsScreen.new()
	stats_screen.back_pressed.connect(_on_stats_back)
	add_child(stats_screen)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HEADER_HEIGHT
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var pause := UI.icon_button("pause", "Pause", 44, 12)
	pause.pressed.connect(_show_pause)
	if not SHOW_PAUSE_BUTTON:
		# Keep the slot so the score stays centered, but make it inert.
		pause.modulate.a = 0.0
		pause.disabled = true
		pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pause.focus_mode = Control.FOCUS_NONE
	row.add_child(pause)
	row.add_child(UI.spacer())

	var scores := VBoxContainer.new()
	scores.alignment = BoxContainer.ALIGNMENT_CENTER
	scores.add_theme_constant_override("separation", 0)
	score_label = UI.label("0", 28, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	score_label.add_theme_font_override("font", UI.title_font(600))
	best_label = UI.label("Best 0", 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	best_label.add_theme_font_override("font", UI.body_font(700))
	scores.add_child(score_label)
	scores.add_child(best_label)
	row.add_child(scores)

	row.add_child(UI.spacer())
	var gear := UI.icon_button("settings", "Settings", 44, 12)
	gear.pressed.connect(show_settings)
	row.add_child(gear)
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
	sub.transparent_bg = true
	viewport_box.add_child(sub)
	tower = TowerView.new()
	sub.add_child(tower)
	tower.setup(config.grid_size)
	tower.set_grid_ticks(settings.grid_ticks)
	tower.rig.view_changed.connect(func(_step): _refresh())
	tower.move_animation_finished.connect(_on_move_animation_finished)

	for axis_name in Swiper.AXIS_NAMES:
		var axis_label := UI.label(axis_name, AXIS_LABEL_SIZE, AXIS_LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
		area.add_child(axis_label)
		axis_labels.append(axis_label)

	slice_chip = UI.label("", 13, Color("#1B428F"), HORIZONTAL_ALIGNMENT_CENTER)
	slice_chip.add_theme_stylebox_override("normal", UI.box(UI.WHITE, ACCENT, 16, 2, Vector2(10, 4)))
	slice_chip.position = Vector2(12, 12)
	slice_chip.visible = false
	area.add_child(slice_chip)

	show_all_button = UI.text_button("Show all", 13)
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
		var b := UI.icon_button("rotate_left" if dir < 0 else "rotate_right",
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
		slot.add_theme_stylebox_override("panel", UI.box(UI.WHITE, UI.LINE, 16))
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


	var swiper_bar := PanelContainer.new()
	swiper_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swiper_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swiper_bar.custom_minimum_size.y = 56
	swiper_bar.add_theme_stylebox_override("panel", UI.box(UI.WHITE, UI.LINE, 28, 2, Vector2(6, 6)))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	swiper_bar.add_child(inner)

	var axes := HBoxContainer.new()
	axes.add_theme_constant_override("separation", 0)
	var group := ButtonGroup.new()
	for mode in [ViewMath.MODE_X, ViewMath.MODE_Y, ViewMath.MODE_Z]:
		var b := UI.text_button(Swiper.AXIS_NAMES[mode], 14)
		b.add_theme_font_override("font", UI.title_font(600))
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(44, 40)
		b.add_theme_stylebox_override("normal", UI.box(Color("#ECECEA"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_stylebox_override("hover", UI.box(Color("#E2E2E0"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_stylebox_override("pressed", UI.box(Color("#333333"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_color_override("font_pressed_color", UI.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", UI.WHITE)
		b.pressed.connect(_set_slice_mode.bind(mode))
		b.pressed.connect(swiper.bump)
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
	var grabber := UI.grabber_texture(26)
	slice_slider.add_theme_icon_override("grabber", grabber)
	slice_slider.add_theme_icon_override("grabber_highlight", grabber)
	slice_slider.add_theme_stylebox_override("slider", UI.slider_track(Color("#D6D6D3")))
	slice_slider.add_theme_stylebox_override("grabber_area", UI.slider_track(Color("#333333")))
	slice_slider.add_theme_stylebox_override("grabber_area_highlight", UI.slider_track(Color("#333333")))
	slice_slider.value_changed.connect(func(v: float):
		swiper.bump()
		_set_slice_depth(int(v)))
	slice_slider.drag_started.connect(swiper.begin_sweep)
	slice_slider.drag_ended.connect(func(_changed: bool): swiper.end_sweep())
	inner.add_child(slice_slider)
	row.add_child(swiper_bar)

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
	panel.add_theme_stylebox_override("panel", UI.box(UI.WHITE, UI.LINE, 24, 2, Vector2(24, 24)))
	center.add_child(panel)
	overlay_panel = VBoxContainer.new()
	overlay_panel.add_theme_constant_override("separation", 14)
	panel.add_child(overlay_panel)
	return root


func _show_overlay(title: String, body: String, primary: String, on_primary: Callable,
		secondary: String = "", on_secondary: Callable = Callable(), score: String = "") -> void:
	for child in overlay_panel.get_children():
		child.queue_free()
	var heading := UI.label(title, 22, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_override("font", UI.title_font(600))
	overlay_panel.add_child(heading)
	if score != "":
		var big := UI.label(score, 48, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
		big.add_theme_font_override("font", UI.title_font(600))
		overlay_panel.add_child(big)
	if body != "":
		overlay_panel.add_child(UI.label(body, 16, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var first := UI.text_button(primary, 16, true)
	first.custom_minimum_size.y = 52
	first.pressed.connect(on_primary)
	overlay_panel.add_child(first)
	if secondary != "":
		var second := UI.text_button(secondary, 14)
		second.custom_minimum_size.y = 44
		second.pressed.connect(on_secondary)
		overlay_panel.add_child(second)
	overlay.visible = true


func _hide_overlay() -> void:
	if overlay != null:
		overlay.visible = false


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
		var center := ViewMath.cells_center(DragController.cells_at(piece, origin), config.grid_size)
		var finger := viewport_box.get_global_rect().position + tower.project_point(center) \
			+ Vector2(0, DragController.LIFT)
		var before := game.moves
		_start_drag(i, finger)
		if not drag.is_dragging():
			return false
		drag.update(finger)
		drag.end(finger)
		_refresh()
		return game.moves == before + 1
	return false
