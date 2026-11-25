extends Control
## The game screen, layout D: header, tower, piece tray, controls.
##
## Builds its UI in code and connects input to the core game. Sizes and
## styling follow the Gameplay artboard in the Qubist designs (390×844 pt).

const Config := preload("res://core/config.gd")
const Game := preload("res://core/game.gd")
const ViewMath := preload("res://game/view_math.gd")
const TowerView := preload("res://game/tower_view.gd")
const SkyBackdrop := preload("res://game/sky_backdrop.gd")
const SkyView := preload("res://game/sky_view.gd")
const SkyWeather := preload("res://game/sky_weather.gd")
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
const Haptics := preload("res://game/haptics.gd")
const Audio := preload("res://game/audio.gd")
const Onboarding := preload("res://core/onboarding.gd")
const TutorialRun := preload("res://game/tutorial_run.gd")
const TutorialOverlay := preload("res://game/tutorial_overlay.gd")
const HintToast := preload("res://game/hint_toast.gd")
const Analytics := preload("res://core/analytics.gd")
const ErrorReporter := preload("res://game/error_reporter.gd")

# Layout, in points (one point is one pixel of the 390×844 base viewport).
const GAP := 8
const HEADER_HEIGHT := 56
const TRAY_HEIGHT := 140
const CONTROLS_HEIGHT := 72

## Axis labels around the tower's base (#53): small and quiet, so they don't
## compete with the blocks. They fade out while the tower turns.
const AXIS_LABEL_SIZE := 11
## White, to read on the island's brick rim and earth underside (#23).
const AXIS_LABEL_COLOR := Color(1, 1, 1, 0.92)
const AXIS_LABEL_GAP := 10.0
const AXIS_LABEL_FADE_SECONDS := 0.1

const TRAY_FADE_SECONDS := 0.2
## A longer buzz as the tower starts to crumble (#132).
const CRUMBLE_VIBRATE_MS := 300
## How far below the tower area's top edge hints appear.
const HINT_TOP := 64.0

var config: Config = Config.new()
var game: Game
## Lifetime stats (#32), loaded from and saved to `stats_path`.
var stats: Stats = Stats.new()
## Set before the node enters the tree to keep tests off the real save.
var stats_path := "user://stats.json"
## Player settings, loaded from and saved to `settings_path`.
var settings: Settings = Settings.new()
var settings_path := Settings.PATH
## Whether the tutorial and each one-time hint have been shown (#29).
var onboarding: Onboarding = Onboarding.new()
var onboarding_path := "user://onboarding.json"
## Taps and pulses on placements and clears (#27), off with the setting.
var haptics: Haptics = Haptics.new()
## Clacks, crumbles, the combo chime and the music (#26), off with the settings.
var audio: Audio = Audio.new()
## Anonymous gameplay events and error reports (#31), off with the settings.
## No provider yet: debug builds print them, release builds drop them.
var analytics: Analytics = Analytics.new()
## The in-progress game and camera, saved after every placement and when the
## app goes to the background, and resumed on launch (#18).
var game_save_path := "user://game.json"
## The game already added to `stats`, so it is never counted twice.
var _recorded_game: Game
## The last game a game_quit was sent for, so leaving it twice sends once.
var _quit_sent_game: Game
## The "+points" pop, the combo/streak banner and the header count-up.
var score_feedback := ScoreFeedback.new(self)
## The score the header shows; trails game.score while the counter ticks up.
var shown_score: int:
	get:
		return score_feedback.shown_score

var tower: TowerView
var viewport_box: SubViewportContainer
## Petals, leaves, snow and fireflies over the tower (#168).
var weather: SkyWeather
var score_label: Label
## The header's crown and best score.
var best_row: HBoxContainer
var best_label: Label
var tray_slots: Array[PanelContainer] = []
var tray_previews: Array = []
var drag_preview: PiecePreview
var slice_chip: Label
var show_all_button: Button
var slice_slider: HSlider
var axis_buttons: Array[Button] = []
## Turn left, turn right.
var rotate_buttons: Array[Button] = []
var swiper_bar: PanelContainer
var settings_button: Button
## Back to Home from the game (#163); the game stays saved for Continue.
var home_button: Button
## Takes back the last move (#184). Dimmed when there is nothing to undo.
var undo_button: Button
## Axis labels on the tower, indexed by ViewMath mode.
var axis_labels: Array[Label] = []
var game_over_card: GameOverCard
var settings_sheet: SettingsSheet
var stats_screen: StatsScreen
var home: HomeScreen
var tutorial_overlay: TutorialOverlay
var hint_toast: HintToast
## Stats was opened from the Settings sheet, so Back returns there; from
## Home, Back just closes it.
var _stats_from_settings := false

## Slice mode, depth and the sweep plane's fade.
var swiper: Swiper = Swiper.new(config.grid_size)

## Dragging a piece from the tray onto the tower.
var drag := DragController.new(self)
## The three-move tutorial (#29), played on this screen.
var tutorial := TutorialRun.new(self)
var _touches := {}
var _pinch_distance := 0.0
## Game over arrived while the move animation was playing; show it after.
var _pending_game_over := false
## True while game.place() runs, so a game over it raises waits for the
## move's animation, which starts just after.
var _placing := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stats.from_dict(SaveFile.read(stats_path))
	settings.from_dict(SaveFile.read(settings_path))
	onboarding.from_dict(SaveFile.read(onboarding_path))
	SkyView.start(settings)
	# Before add_child(audio) and the ErrorReporter, so neither starts on a
	# default the player has turned off.
	for key in settings.to_dict():
		_apply_setting(key)
	add_child(audio)
	if analytics.backend == null and OS.is_debug_build():
		analytics.backend = Analytics.LogBackend.new()
	add_child(ErrorReporter.new(analytics))
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
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_send_quit(Analytics.QUIT_BACKGROUNDED)


## Sends game_quit if a game is in progress (not the tutorial's), once per
## game.
func _send_quit(reason: String) -> void:
	if tutorial.is_active() or not can_continue() or _quit_sent_game == game:
		return
	_quit_sent_game = game
	analytics.game_quit(game, reason)


func new_game() -> void:
	_send_quit(Analytics.QUIT_NEW_GAME)
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
## Nothing is written during the tutorial: the player's game was saved as it
## started and is put back after.
func save_game() -> void:
	if game == null or tutorial.is_active():
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
	tower.clear_crumble()
	_pending_game_over = false
	game = next
	# The tutorial hands back a game that is already connected.
	if not game.game_over.is_connected(_on_game_over):
		game.game_over.connect(_on_game_over)
		game.tray_refilled.connect(_on_tray_refilled)
	game_over_card.close()
	score_feedback.snap()


func _process(delta: float) -> void:
	_update_axis_labels(delta)
	tutorial.update()
	# Undo depends on drags, menus and animations, so it is checked each frame.
	undo_button.disabled = not can_undo()
	update_sky(delta)
	if swiper.update_sweep(delta, tower.rig.is_turning()):
		tower.set_sweep_alpha(swiper.sweep_alpha())


## Follows the clock when Settings says the sky follows the day, but never
## while a piece is being dragged (#168). Applies the current sky's light,
## snow and night (#253) to the game. The score's colours follow the sky through SkyView.ink()
## and muted() (#204).
func update_sky(delta: float) -> void:
	SkyView.follow_clock(delta, drag.is_dragging())
	viewport_box.modulate = SkyView.tint()
	var snow := SkyView.snow_amount()
	if not is_equal_approx(tower.snow_amount(), snow):
		tower.set_snow(snow)
	var night := SkyView.night_amount()
	if not is_equal_approx(tower.night_amount(), night):
		tower.set_night(night)


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
		start_drag(index, event.global_position)
		accept_event()


func _handle_zoom(event: InputEvent) -> void:
	var over_tower := false
	if event is InputEventMouse:
		over_tower = viewport_box.get_global_rect().has_point(event.position)
	if event is InputEventMouseButton and event.pressed and over_tower:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tower.rig.zoom_by(1.1)
			show_hint("zoom")
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tower.rig.zoom_by(1.0 / 1.1)
			show_hint("zoom")
	elif event is InputEventMagnifyGesture:
		tower.rig.zoom_by(event.factor)
		show_hint("zoom")
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
				show_hint("zoom")
			_pinch_distance = spread


func _touch_spread() -> float:
	if _touches.size() != 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1])


# --- Dragging a piece ---

## A finger went down on tray slot `index`. Does nothing while a move can't
## start.
func start_drag(index: int, finger: Vector2) -> void:
	# No new move until the last one has finished animating, so the grid and
	# the view stay in step.
	if game.is_over or game_over_card.visible or menu_open() or tower.is_animating() or game.tray[index] == null:
		return
	drag.start(index, finger)


## The dragged piece was let go over a legal spot.
func _place(index: int, origin: Vector3i) -> void:
	_placing = true
	var result: Dictionary = game.place(index, origin)
	_placing = false
	if result.ok:
		haptics.tap()
		audio.land()
		if not result.lines.is_empty():
			# Pulse and crumble as the cleared cubes start to break, after they land.
			var lines: int = result.lines.size()
			var cubes_break := get_tree().create_timer(TowerView.LAND_SECONDS).timeout
			cubes_break.connect(haptics.clear.bind(lines))
			cubes_break.connect(audio.clear.bind(lines))
		# Sliced-away cubes stay faded instead of animating.
		tower.play_move(result.placed, result.cleared, _faded_cells(), result.lines.size())
		score_feedback.show_gain(result)
		if tutorial.is_active():
			tutorial.placed()
		elif game.moves == 1:
			analytics.game_started()
		save_game()


## True when the Undo button may take back the last move: not during the
## tutorial, a drag or a move animation, and not with anything covering the
## game.
func can_undo() -> bool:
	return game != null and game.can_undo() and not tutorial.is_active() \
		and not drag.is_dragging() and not tower.is_animating() \
		and not game_over_card.visible and not menu_open()


## Takes back the last move (#184): the piece goes back to its slot and the
## tower, score and tray are redrawn as they were, without animation.
func undo() -> void:
	if not can_undo() or not game.undo():
		return
	haptics.tap()
	score_feedback.snap()
	_refresh()
	save_game()


# --- View controls ---

func _turn(quarter_turns: int) -> void:
	tower.rig.turn(quarter_turns)
	tutorial.view_used()
	show_hint("rotate")
	_refresh()


## The player moved the swiper's slider or picked its axis.
func _on_swiper_used() -> void:
	swiper.bump()
	if swiper.is_sliced():
		tutorial.view_used()
	show_hint("swiper")


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
			_tray_card(piece != null))
		SkyView.paint_night(tray_slots[i])

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
	tutorial.move_finished()
	if _pending_game_over:
		_pending_game_over = false
		_on_game_over(game.score)


## Skips any running animation, the crumble included. Used by the smoke
## test.
func finish_animations() -> void:
	tower.finish_move_animation()
	tower.finish_crumble()
	score_feedback.snap()


## Once the last move has played out, the tower crumbles (#132), then the
## game-over card comes up. Under Reduce Motion the tower stays standing and
## the card comes up straight away.
func _on_game_over(_final_score: int) -> void:
	if _placing or tower.is_animating():
		_pending_game_over = true
		return
	_record_finished_game()
	if not tower.has_crumbled():
		Input.vibrate_handheld(CRUMBLE_VIBRATE_MS)
		if UI.reduce_motion():
			_open_game_over_card()
		else:
			tower.play_crumble(game.grid.filled_cells())
	elif not tower.is_crumbling():
		_open_game_over_card()


func _on_crumble_finished() -> void:
	# Left for Home mid-crumble: the card would cover it.
	if game.is_over and not menu_open():
		_open_game_over_card()


func _open_game_over_card() -> void:
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
	score_feedback.refresh_best()
	analytics.game_over(game)
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
	game_over_card.close()
	settings_sheet.visible = false
	stats_screen.visible = false
	var resume := can_continue()
	home.open(stats.best_score if stats.has_best() else -1, game.score if resume else -1,
		game.grid.filled_cells() if resume else [])
	# Nothing to draw behind Home, so let the 3D view rest.
	viewport_box.visible = false


func _leave_home() -> void:
	home.visible = false
	viewport_box.visible = true
	_refresh()


func _on_home_new_game() -> void:
	# A new player gets the tutorial first, then this fresh game (#29).
	var teach := onboarding.should_auto_start(stats.games_played, can_continue())
	new_game()
	_leave_home()
	if teach:
		start_tutorial()


func _on_home_continue() -> void:
	_leave_home()


func _on_home_stats() -> void:
	_stats_from_settings = false
	stats_screen.open(stats)


## Plays the tutorial over whatever is showing (#29). Home's How to play
## returns to Home after; Settings' Replay tutorial returns to where the
## sheet was opened from.
func start_tutorial(on_done := Callable()) -> void:
	drag.clear()
	hint_toast.dismiss()
	settings_sheet.visible = false
	stats_screen.visible = false
	home.visible = false
	viewport_box.visible = true
	tutorial.start(on_done)


func _on_replay_tutorial() -> void:
	start_tutorial(show_home if home.visible else Callable())


## The tutorial was finished or skipped: it won't start on its own again.
func onboarding_done() -> void:
	onboarding.tutorial_done = true
	SaveFile.write(onboarding_path, onboarding.to_dict())


## Shows one-time hint `key` (core/onboarding.gd HINTS) if the player hasn't
## had it yet. Not during the tutorial, which teaches the same controls, nor
## with Settings › Tips off (#164); a hint skipped that way stays unseen.
func show_hint(key: String) -> void:
	if not settings.tips or tutorial.is_active() or menu_open() or not onboarding.see(key):
		return
	SaveFile.write(onboarding_path, onboarding.to_dict())
	hint_toast.show_hint(key, viewport_box.get_global_rect(), HINT_TOP)


func _on_tutorial_finished(completed: bool) -> void:
	if completed and not menu_open():
		hint_toast.show_hint("tutorial_done", viewport_box.get_global_rect(), HINT_TOP)


func show_settings() -> void:
	drag.clear()
	stats_screen.visible = false
	settings_sheet.open(not home.visible)


## Hands setting `key` to whatever it drives: every key at startup, and one
## again each time the player changes it. A new setting is applied here only.
## At startup the screen isn't built yet, so the builders apply what they own.
func _apply_setting(key: String) -> void:
	var value = settings.get(key)
	match key:
		"music", "sound_effects", "music_volume", "sound_effects_volume":
			audio.set(key, value)
		"haptics":
			haptics.enabled = value
		"analytics":
			analytics.enabled = value
		"grid_ticks":
			if tower != null:
				tower.set_grid_ticks(value)
		"tips":
			if not value and hint_toast != null:
				hint_toast.dismiss()
		"sky_follows_day", "sky_season", "sky_time", "sky_christmas":
			SkyView.follow(settings)


## Changes one on/off setting (#20), applies it and saves the settings.
## `key` is a Settings field name.
func set_setting(key: String, on: bool) -> void:
	settings.set(key, on)
	settings_sheet.set_switch(key, on)
	if key == "sky_follows_day" and not on:
		# Start the pickers on what's showing, so nothing jumps.
		for choice in [["sky_season", SkyView.season], ["sky_time", SkyView.time_of_day]]:
			settings.set(choice[0], choice[1])
			settings_sheet.set_choice(choice[0], choice[1])
		settings.sky_christmas = SkyView.christmas
		settings_sheet.set_switch("sky_christmas", SkyView.christmas)
	_apply_setting(key)
	SaveFile.write(settings_path, settings.to_dict())


## Picks a season or time of day for the sky (#168), shows it and saves the
## settings. `key` is "sky_season" or "sky_time".
func set_choice(key: String, value: String) -> void:
	if not (Settings.CHOICES[key] as Array).has(value):
		return
	settings.set(key, value)
	settings_sheet.set_choice(key, value)
	_apply_setting(key)
	SaveFile.write(settings_path, settings.to_dict())


## Changes the music or sound effects volume (#165), applies it and saves the
## settings. `key` is "music_volume" or "sound_effects_volume"; `value` is 0–1.
func set_volume(key: String, value: float) -> void:
	settings.set(key, clampf(value, 0.0, 1.0))
	_apply_setting(key)
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

	# Over the tower, under the dragged piece, the cards and the menus.
	weather = SkyWeather.new()
	add_child(weather)

	drag_preview = PiecePreview.new()
	drag_preview.size = Vector2(110, 110)
	drag_preview.unit = 18.0
	drag_preview.visible = false
	add_child(drag_preview)

	game_over_card = GameOverCard.new()
	game_over_card.play_again_pressed.connect(new_game)
	game_over_card.home_pressed.connect(show_home)
	add_child(game_over_card)
	# Under Home and the menus, so they cover it.
	hint_toast = HintToast.new()
	add_child(hint_toast)

	home = HomeScreen.new()
	home.island.pieces = config.pieces
	home.new_game_pressed.connect(_on_home_new_game)
	home.continue_pressed.connect(_on_home_continue)
	home.stats_pressed.connect(_on_home_stats)
	home.settings_pressed.connect(show_settings)
	home.how_to_play_pressed.connect(start_tutorial.bind(show_home))
	add_child(home)

	settings_sheet = SettingsSheet.new()
	settings_sheet.stats_pressed.connect(show_stats)
	settings_sheet.home_pressed.connect(show_home)
	settings_sheet.setting_toggled.connect(set_setting)
	settings_sheet.volume_changed.connect(set_volume)
	settings_sheet.choice_changed.connect(set_choice)
	settings_sheet.next_track_pressed.connect(audio.next_track)
	audio.track_changed.connect(settings_sheet.set_now_playing)
	settings_sheet.set_now_playing(audio.track_title(), audio.track_artist())
	settings_sheet.tutorial_pressed.connect(_on_replay_tutorial)
	settings_sheet.show_settings(settings)
	add_child(settings_sheet)
	stats_screen = StatsScreen.new()
	stats_screen.back_pressed.connect(_on_stats_back)
	add_child(stats_screen)

	tutorial_overlay = TutorialOverlay.new()
	tutorial_overlay.skip_pressed.connect(tutorial.skip)
	tutorial.finished.connect(_on_tutorial_finished)
	add_child(tutorial_overlay)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HEADER_HEIGHT
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Home and Undo sit opposite Settings. Both sides get the same width,
	# so the score stays centered (#163).
	var left := _header_side(BoxContainer.ALIGNMENT_BEGIN)
	home_button = SkyView.by_night(UI.icon_button("home", "Home")) as Button
	home_button.pressed.connect(show_home)
	left.add_child(home_button)
	undo_button = SkyView.by_night(UI.icon_button("undo", "Undo")) as Button
	undo_button.pressed.connect(undo)
	left.add_child(undo_button)
	row.add_child(left)

	var scores := VBoxContainer.new()
	scores.alignment = BoxContainer.ALIGNMENT_CENTER
	scores.add_theme_constant_override("separation", 2)
	score_label = SkyView.ink(UI.label("0", 36, UI.SKY_INK, HORIZONTAL_ALIGNMENT_CENTER)) as Label
	score_label.add_theme_font_override("font", UI.title_font(600))
	best_label = SkyView.muted(UI.label("", 11, UI.SKY_MUTED)) as Label
	best_label.add_theme_font_override("font", UI.body_font(700, 1))
	best_row = HBoxContainer.new()
	best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	best_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	best_row.add_theme_constant_override("separation", 4)
	var crown := GameOverCard.Crown.new()
	crown.custom_minimum_size = Vector2(12, 12)
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	best_row.add_child(crown)
	best_row.add_child(best_label)
	scores.add_child(score_label)
	scores.add_child(best_row)
	row.add_child(scores)

	var right := _header_side(BoxContainer.ALIGNMENT_END)
	settings_button = SkyView.by_night(UI.icon_button("settings", "Settings")) as Button
	settings_button.pressed.connect(show_settings)
	right.add_child(settings_button)
	row.add_child(right)
	return row


## One side of the header. Both sides expand equally around the score.
func _header_side(alignment: BoxContainer.AlignmentMode) -> HBoxContainer:
	var side := HBoxContainer.new()
	side.alignment = alignment
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return side


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
	_apply_setting("grid_ticks")
	tower.rig.view_changed.connect(func(_step): _refresh())
	tower.move_animation_finished.connect(_on_move_animation_finished)
	tower.crumble_finished.connect(_on_crumble_finished)

	for axis_name in Swiper.AXIS_NAMES:
		var axis_label := UI.label(axis_name, AXIS_LABEL_SIZE, AXIS_LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
		area.add_child(axis_label)
		axis_labels.append(axis_label)

	slice_chip = UI.label("", 13, UI.SKY_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	slice_chip.add_theme_font_override("font", UI.body_font(700))
	slice_chip.add_theme_stylebox_override("normal", UI.card(UI.WHITE, 16, Vector2(12, 6)))
	slice_chip.position = Vector2(12, 12)
	slice_chip.visible = false
	SkyView.by_night(slice_chip)
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
	SkyView.by_night(show_all_button)
	area.add_child(show_all_button)

	# Rotate buttons sit in the bottom corners beside the base, so the swiper
	# can use the whole controls row (it has a third, Z, axis button the
	# design's row leaves out). Round white 56-point buttons, as designed.
	for dir in [-1, 1]:
		var b := UI.icon_button("rotate_left" if dir < 0 else "rotate_right",
			"Rotate tower left" if dir < 0 else "Rotate tower right", 56, 28)
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if dir < 0 else Control.PRESET_BOTTOM_RIGHT)
		b.offset_left = 4 if dir < 0 else -60
		b.offset_right = 60 if dir < 0 else -4
		b.offset_top = -64
		b.offset_bottom = -8
		b.pressed.connect(_turn.bind(dir))
		SkyView.by_night(b)
		area.add_child(b)
		rotate_buttons.append(b)
	return area


func _build_tray() -> Control:
	var tray := HBoxContainer.new()
	tray.custom_minimum_size.y = TRAY_HEIGHT
	tray.add_theme_constant_override("separation", 12)
	for i in range(config.tray_size):
		var slot := PanelContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", _tray_card(true))
		slot.gui_input.connect(_on_slot_input.bind(i))
		var preview := PiecePreview.new()
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(preview)
		SkyView.by_night(slot)
		tray.add_child(slot)
		tray_slots.append(slot)
		tray_previews.append(preview)
	return tray


## A tray slot's card: white and raised when it holds a piece, a faint
## outline once the piece is placed. SkyView.paint_night() gives it its
## night colours.
static func _tray_card(filled: bool) -> StyleBoxFlat:
	if filled:
		return UI.card(UI.TRAY_CARD, 20)
	return UI.box(Color(1, 1, 1, 0.25), 20, Vector2.ZERO, Color(1, 1, 1, 0.7), 2)


func _build_controls() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = CONTROLS_HEIGHT
	row.add_theme_constant_override("separation", 8)


	swiper_bar = PanelContainer.new()
	swiper_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swiper_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swiper_bar.custom_minimum_size.y = 56
	var bar_card := UI.card(UI.WHITE, 28, Vector2(6, 6))
	# Extra room past the slider's end, so the knob doesn't crowd the bar's
	# rounded edge.
	bar_card.content_margin_right = 18
	swiper_bar.add_theme_stylebox_override("panel", bar_card)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	swiper_bar.add_child(inner)

	# The axis toggle: a pale pill track with the chosen axis drawn as the
	# teal primary key, ledge and all (#162).
	var track := PanelContainer.new()
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override("panel", UI.box(UI.SEGMENT_TRACK, 22, Vector2(2, 2)))
	var axes := HBoxContainer.new()
	axes.add_theme_constant_override("separation", 0)
	track.add_child(axes)
	var group := ButtonGroup.new()
	for mode in [ViewMath.MODE_X, ViewMath.MODE_Y, ViewMath.MODE_Z]:
		var b := UI.text_button(Swiper.AXIS_NAMES[mode], 15)
		b.add_theme_font_override("font", UI.title_font(600))
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(40, 40)
		b.add_theme_stylebox_override("normal", UI.box(UI.CLEAR, 20))
		b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.6), 20))
		b.add_theme_stylebox_override("pressed", UI.accent_key(20, UI.SKY_ACCENT, 3))
		b.add_theme_stylebox_override("hover_pressed", UI.accent_key(20, UI.SKY_ACCENT, 3))
		for state in ["font_color", "font_hover_color"]:
			b.add_theme_color_override(state, UI.SKY_MUTED)
		b.add_theme_color_override("font_pressed_color", UI.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", UI.WHITE)
		b.pressed.connect(_set_slice_mode.bind(mode))
		b.pressed.connect(_on_swiper_used)
		axes.add_child(b)
		axis_buttons.append(b)
	inner.add_child(track)

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
	var grabber := UI.knob_texture(26)
	slice_slider.add_theme_icon_override("grabber", grabber)
	slice_slider.add_theme_icon_override("grabber_highlight", grabber)
	slice_slider.add_theme_stylebox_override("slider", UI.slider_track(UI.SLIDER_RAIL))
	slice_slider.add_theme_stylebox_override("grabber_area", UI.slider_track(UI.SKY_ACCENT))
	slice_slider.add_theme_stylebox_override("grabber_area_highlight", UI.slider_track(UI.SKY_ACCENT))
	slice_slider.value_changed.connect(func(v: float):
		_set_slice_depth(int(v))
		_on_swiper_used())
	slice_slider.drag_started.connect(swiper.begin_sweep)
	slice_slider.drag_ended.connect(func(_changed: bool): swiper.end_sweep())
	inner.add_child(slice_slider)
	# Navy at night, with the track, axis keys and slider inside it (#219).
	SkyView.by_night(swiper_bar)
	row.add_child(swiper_bar)

	return row


# --- Test hooks ---

## Turns the view as the rotate buttons do. With `instant`, the turn ends at
## once instead of animating. Used by the smoke test.
func turn(quarter_turns: int, instant := false) -> void:
	_turn(quarter_turns)
	if instant:
		tower.rig.finish_turn()


## Sets the swiper's axis and depth, as its buttons and slider do, without
## the hints they show. Used by the smoke test.
func set_slice(mode: int, depth: int) -> void:
	_set_slice_mode(mode)
	_set_slice_depth(depth)


## Places a piece through the same drag path a finger would take: presses the
## tray slot, moves to where the ghost would snap, releases. Returns true if a
## move was made. Used by the smoke test.
func autoplay_one_move() -> bool:
	for i in range(game.tray.size()):
		var piece = game.tray[i]
		if piece == null:
			continue
		var options := drag.snap_origins(piece)
		if options.is_empty():
			continue
		var origin: Vector3i = options[options.size() >> 1]
		var center := ViewMath.cells_center(piece.cells_at(origin), config.grid_size)
		var finger := viewport_box.get_global_rect().position + tower.project_point(center) \
			+ Vector2(0, DragController.LIFT)
		var before := game.moves
		start_drag(i, finger)
		if not drag.is_dragging():
			return false
		drag.update(finger)
		drag.end(finger)
		_refresh()
		return game.moves == before + 1
	return false
