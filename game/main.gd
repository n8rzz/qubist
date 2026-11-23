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
const UI := preload("res://game/ui_style.gd")
const Stats := preload("res://core/stats.gd")
const SaveFile := preload("res://core/save_file.gd")
const Settings := preload("res://core/settings.gd")
const SettingsSheet := preload("res://game/settings_sheet.gd")
const StatsScreen := preload("res://game/stats_screen.gd")
const HomeScreen := preload("res://game/home_screen.gd")
const DragController := preload("res://game/drag_controller.gd")

# Layout, in points (one point is one pixel of the 390×844 base viewport).
const GAP := 8
const HEADER_HEIGHT := 56
const TRAY_HEIGHT := 140
const CONTROLS_HEIGHT := 72
## Pause is hidden for MVP (#42); re-enable for the post-MVP timed mode.
const SHOW_PAUSE_BUTTON := false

## Swiper button and chip labels, indexed by ViewMath mode.
const AXIS_NAMES := ["X", "Y", "Z"]
## Axis labels around the tower's base (#53): small and quiet, so they don't
## compete with the blocks. They fade out while the tower turns.
const AXIS_LABEL_SIZE := 11
const AXIS_LABEL_COLOR := Color("#8A8A86")
const AXIS_LABEL_GAP := 10.0
const AXIS_LABEL_FADE_SECONDS := 0.1

## Sweep plane (#51): shown while the swiper moves, held briefly after it
## stops, then faded out.
const SWEEP_FADE_IN_SECONDS := 0.06
const SWEEP_HOLD_SECONDS := 0.18
const SWEEP_FADE_OUT_SECONDS := 0.45

## Blue for the slice chip's border and the combo banner. The other colours
## come from game/ui_style.gd.
const ACCENT := Color("#2559C9")

# Placeholder feedback (#47).
const SCORE_POP_COLOR := Color("#1B428F")
const SCORE_POP_RISE := 56.0
const SCORE_POP_SECONDS := 0.9
const BANNER_SECONDS := 1.2
## The score counter counts up to the new total over this long (#25).
const SCORE_TICK_SECONDS := 0.5
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
## The score the header shows; trails game.score while the counter ticks up.
var shown_score := 0
var _score_tween: Tween

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
var settings_sheet: SettingsSheet
var stats_screen: StatsScreen
var home: HomeScreen
## Stats was opened from the Settings sheet, so Back returns there; from
## Home, Back just closes it.
var _stats_from_settings := false

var slice_mode := ViewMath.MODE_X
var slice_depth := 0
## True while a finger is on the swiper's slider.
var _sweeping := false
## Seconds left before the sweep plane starts to fade.
var _sweep_hold := 0.0
var _sweep_alpha := 0.0

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
	_snap_score()


func _process(delta: float) -> void:
	_update_axis_labels(delta)
	_update_sweep(delta)


## Marks the swiper as just moved, so the sweep plane shows and then fades.
func _bump_sweep() -> void:
	_sweep_hold = SWEEP_HOLD_SECONDS


func _update_sweep(delta: float) -> void:
	_sweep_hold = maxf(_sweep_hold - delta, 0.0)
	var target := 1.0 if _sweeping or _sweep_hold > 0.0 else 0.0
	# The cut's axis can swap as the tower turns, so keep it hidden meanwhile.
	if tower.rig.is_turning():
		target = 0.0
		_sweep_hold = 0.0
	var seconds := SWEEP_FADE_IN_SECONDS if target > _sweep_alpha else SWEEP_FADE_OUT_SECONDS
	var alpha := move_toward(_sweep_alpha, target, delta / seconds)
	if alpha != _sweep_alpha:
		_sweep_alpha = alpha
		tower.set_sweep_alpha(ease(alpha, 0.6))


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
	if game.is_over or overlay.visible or menu_open() or tower.is_animating() or game.tray[index] == null:
		return
	drag.start(index, finger)


## The dragged piece was let go over a legal spot.
func _place(index: int, origin: Vector3i) -> void:
	var result: Dictionary = game.place(index, origin)
	if result.ok:
		Input.vibrate_handheld(15)
		# Sliced-away cubes stay faded instead of animating.
		tower.play_move(result.placed, result.cleared, _faded_cells(), result.lines.size())
		_show_score_gain(result)
		save_game()


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
	_tick_score_to(game.score)

	var step := tower.rig.view_step()
	for i in range(tray_slots.size()):
		var piece = game.tray[i] if i < game.tray.size() else null
		tray_previews[i].set_piece(piece, step)
		tray_slots[i].add_theme_stylebox_override("panel",
			UI.box(UI.WHITE, UI.LINE, 16) if piece != null else UI.box(Color(0, 0, 0, 0), Color("#9A9A9A"), 16))

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
	var filled: Array = game.grid.filled_cells()
	var faded := _faded_cells()
	var step := tower.rig.view_step()
	# While sliced, cubes behind the slice are drawn lighter (#85), and the
	# shown cubes on the cut light up under the sweep plane.
	var behind := {}
	var cap: Array = []
	for c in filled:
		if faded.has(c):
			continue
		var layer := ViewMath.layer_from_viewer(c, slice_mode, step, config.grid_size)
		if layer == slice_depth:
			cap.append(c)
		elif slice_depth > 0 and layer > slice_depth:
			behind[c] = true
	tower.update_blocks(filled, faded, behind)

	tower.set_sweep(
		ViewMath.slice_plane(slice_mode, step, config.grid_size, slice_depth),
		ViewMath.slice_toward_viewer(slice_mode, step), cap)


## Cells to draw see-through: those the swiper has cut away, plus, while
## dragging, those that would hide the ghost.
func _faded_cells() -> Dictionary:
	var faded := {}
	var step := tower.rig.view_step()
	var filled: Array = game.grid.filled_cells()
	for c in filled:
		if ViewMath.is_sliced_away(c, slice_mode, step, config.grid_size, slice_depth):
			faded[c] = true
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
	_snap_score()


## Counts the header score up to `target`. A new gain mid-tick carries on from
## the number on screen, so the counter never jumps back.
func _tick_score_to(target: int) -> void:
	if target == shown_score:
		_set_shown_score(target)
		return
	if _score_tween != null:
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(func(v: float) -> void: _set_shown_score(roundi(v)),
		float(shown_score), float(target), SCORE_TICK_SECONDS) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Stops any tick and shows the current score at once.
func _snap_score() -> void:
	if _score_tween != null:
		_score_tween.kill()
		_score_tween = null
	_set_shown_score(game.score if game != null else 0)


func _set_shown_score(value: int) -> void:
	shown_score = value
	score_label.text = UI.format_number(value)
	best_label.text = "Best %s" % UI.format_number(maxi(stats.best_score, value))


func _on_game_over(final_score: int) -> void:
	if tower.is_animating():
		_pending_game_over = true
		return
	_record_finished_game()
	var body := "Score %s\nBest %s" % [UI.format_number(final_score), UI.format_number(stats.best_score)]
	_show_overlay("No moves left", body, "Play again", new_game, "Home", show_home)


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


## Floating "+points" over the move, and a combo/streak banner when they apply.
## Only line clears score, so a move that clears nothing shows nothing.
func _show_score_gain(result: Dictionary) -> void:
	if int(result.score.total) <= 0:
		return
	var at := viewport_box.get_global_rect().position \
		+ tower.project_point(ViewMath.cells_center(result.cleared, config.grid_size))
	var pop := UI.label("+%s" % UI.format_number(int(result.score.total)), 24, SCORE_POP_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER)
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
	var banner := UI.label("  ·  ".join(parts), 18, UI.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	banner.add_theme_stylebox_override("normal", UI.box(ACCENT, ACCENT, 18, 0, Vector2(16, 8)))
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


# --- Building the UI ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

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
	best_label = UI.label("Best 0", 12, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
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
	viewport_box.add_child(sub)
	tower = TowerView.new()
	sub.add_child(tower)
	tower.setup(config.grid_size)
	tower.set_grid_ticks(settings.grid_ticks)
	tower.rig.view_changed.connect(func(_step): _refresh())
	tower.move_animation_finished.connect(_on_move_animation_finished)

	for axis_name in AXIS_NAMES:
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


	var swiper := PanelContainer.new()
	swiper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swiper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swiper.custom_minimum_size.y = 56
	swiper.add_theme_stylebox_override("panel", UI.box(UI.WHITE, UI.LINE, 28, 2, Vector2(6, 6)))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	swiper.add_child(inner)

	var axes := HBoxContainer.new()
	axes.add_theme_constant_override("separation", 0)
	var group := ButtonGroup.new()
	for mode in [ViewMath.MODE_X, ViewMath.MODE_Y, ViewMath.MODE_Z]:
		var b := UI.text_button(AXIS_NAMES[mode], 14)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(44, 40)
		b.add_theme_stylebox_override("normal", UI.box(Color("#ECECEA"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_stylebox_override("hover", UI.box(Color("#E2E2E0"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_stylebox_override("pressed", UI.box(Color("#333333"), Color(0, 0, 0, 0), 20, 0))
		b.add_theme_color_override("font_pressed_color", UI.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", UI.WHITE)
		b.pressed.connect(_set_slice_mode.bind(mode))
		b.pressed.connect(_bump_sweep)
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
		_bump_sweep()
		_set_slice_depth(int(v)))
	slice_slider.drag_started.connect(func(): _sweeping = true)
	slice_slider.drag_ended.connect(func(_changed: bool):
		_sweeping = false
		_bump_sweep())
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
	panel.add_theme_stylebox_override("panel", UI.box(UI.WHITE, UI.LINE, 24, 2, Vector2(24, 24)))
	center.add_child(panel)
	overlay_panel = VBoxContainer.new()
	overlay_panel.add_theme_constant_override("separation", 14)
	panel.add_child(overlay_panel)
	return root


func _show_overlay(title: String, body: String, primary: String, on_primary: Callable,
		secondary: String = "", on_secondary: Callable = Callable()) -> void:
	for child in overlay_panel.get_children():
		child.queue_free()
	overlay_panel.add_child(UI.label(title, 22, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
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
