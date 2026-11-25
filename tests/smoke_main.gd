extends SceneTree
## Smoke test for the game screen. Loads scenes/main.tscn headless, lets the
## layout settle, then plays moves through the same drag path a finger takes,
## rotating and slicing along the way.
##
##   godot --headless --path . --script res://tests/smoke_main.gd
##
## Exits with code 0 if every move went through, 1 otherwise. Script errors are
## caught separately by CI, which fails on any "SCRIPT ERROR" in the output.

const MOVES := 30
const SaveFile := preload("res://core/save_file.gd")
const SmokeSaves := preload("res://tests/support/smoke_saves.gd")
const UI := preload("res://game/ui_style.gd")
const ScoreFeedback := preload("res://game/score_feedback.gd")
const Tutorial := preload("res://core/tutorial.gd")
const Analytics := preload("res://core/analytics.gd")
const HintToast := preload("res://game/hint_toast.gd")
const SettingsSheet := preload("res://game/settings_sheet.gd")
const SkyView := preload("res://game/sky_view.gd")

var main
var frame := 0
var failures: Array[String] = []
## Keeps the smoke test's stats, auto-saved game (#18) and settings (#56) out
## of the real save files.
var saves := SmokeSaves.new("smoke")
## A Settings sheet on a short screen, so its cards have to scroll (#213).
var short_sheet: SettingsSheet


func _initialize() -> void:
	# Note: headless Godot ignores window size changes, so this runs at the
	# headless default (wider than a phone). Layout is fluid, so the drag path
	# is the same; check real sizes on a device.
	saves.clear()
	main = _make_main()
	main.analytics.backend = Analytics.MemoryBackend.new()
	root.add_child(main)


func _make_main():
	var screen = load("res://scenes/main.tscn").instantiate()
	saves.use_on(screen)
	return screen


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		_check_layout()
		_check_night_lines()
		_open_short_sheet()
	elif frame == 7:
		_check_best_hidden()
		_check_home()
		_check_settings_swipe()
	elif frame == 10:
		_play()
	elif frame == 15:
		_check_stats()
	elif frame == 17:
		_check_undo()
	elif frame == 18:
		_check_resume()
	elif frame == 19:
		_check_finished_save()
	elif frame == 20:
		# Free the screen and give the audio thread a moment to drop its
		# sounds (#26) before quitting, or they show up as leaks at exit.
		main.queue_free()
		create_timer(0.25).timeout.connect(
			saves.finish.bind(self, failures, "game screen smoke test"))
	return false


func _check_layout() -> void:
	var rect: Rect2 = main.viewport_box.get_global_rect()
	print("Tower area: %s" % rect)
	if rect.size.x < 100 or rect.size.y < 100:
		failures.append("tower area is too small: %s" % rect)
	if main.tray_slots.size() != 3:
		failures.append("expected 3 tray slots, found %d" % main.tray_slots.size())
	# Home and Undo on one side, Settings on the other: the score stays
	# centered over the screen (#184).
	var score_mid: float = main.score_label.get_global_rect().get_center().x
	var screen_mid: float = main.get_global_rect().get_center().x
	if absf(score_mid - screen_mid) > 1.0:
		failures.append("score is off center: %.1f vs %.1f" % [score_mid, screen_mid])


func _open_short_sheet() -> void:
	var screen := Control.new()
	screen.size = Vector2(390, 560)
	root.add_child(screen)
	short_sheet = SettingsSheet.new()
	screen.add_child(short_sheet)
	short_sheet.open(true)


## Settings › a swipe scrolls the cards, even one that starts on a switch,
## and doesn't flip it; a tap still does; and the bottom row, Home, can be
## scrolled to and tapped (#213). Driven through the viewport, like a finger;
## it waits a frame where Godot updates hover and scrolled rows on the next.
func _check_settings_swipe() -> void:
	var sheet := short_sheet
	var scroll: ScrollContainer = sheet._scroll
	if scroll.get_v_scroll_bar().max_value <= scroll.size.y:
		failures.append("the short Settings sheet fits without scrolling, so the swipe check proves nothing")
	var flips := []
	sheet.setting_toggled.connect(func(key, on): flips.append([key, on]))
	var music_on := sheet.music_button.button_pressed
	var start := sheet.music_button.get_global_rect().get_center()
	await _swipe(start, start + Vector2(0, -250))
	if scroll.scroll_vertical <= 0:
		failures.append("a swipe up on Settings did not scroll it")
	if not flips.is_empty() or sheet.music_button.button_pressed != music_on:
		failures.append("a swipe that started on the Music switch flipped it")
	var scrolled := scroll.scroll_vertical
	await _swipe(start, start + Vector2(0, 120))
	if scroll.scroll_vertical >= scrolled:
		failures.append("a swipe down on Settings did not scroll it back")
	await _swipe(start, start + Vector2(0, 250))

	await _tap(sheet.music_button.get_global_rect().get_center())
	if flips != [["music", not music_on]]:
		failures.append("tapping the Music switch did not flip it: %s" % [flips])
	sheet.set_switch("music", music_on)

	for i in range(6):
		await _swipe(start, start + Vector2(0, -300))
	var home: Rect2 = sheet.home_button.get_global_rect()
	if not scroll.get_global_rect().encloses(home):
		failures.append("Home, the bottom row, could not be scrolled into view: %s in %s" \
			% [home, scroll.get_global_rect()])
	var went_home := [false]
	sheet.home_pressed.connect(func(): went_home[0] = true)
	await _tap(home.get_center())
	if not went_home[0]:
		failures.append("tapping Home after scrolling to it did nothing")
	sheet.get_parent().queue_free()


## A finger down at `from`, moved to `to` in steps, and lifted.
func _swipe(from: Vector2, to: Vector2) -> void:
	_mouse_move(from, false)
	await process_frame
	_mouse_button(from, true)
	for i in range(1, 11):
		_mouse_move(from.lerp(to, i / 10.0), true)
	_mouse_button(to, false)
	await process_frame


func _tap(at: Vector2) -> void:
	_mouse_move(at, false)
	await process_frame
	_mouse_button(at, true)
	_mouse_button(at, false)
	await process_frame


func _mouse_move(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)


## Launch opens Home with no Continue (nothing saved yet); New game leaves
## it for the game (#72). For a new player, New game runs the tutorial first
## (#29).
func _check_home() -> void:
	if not main.home.visible or not main.menu_open():
		failures.append("launch did not open Home")
	if main.home.continue_button.visible:
		failures.append("Home offered Continue with no game to resume")
	if not main.home.island.is_animating():
		failures.append("Home's island did not play its tower loop with no game to resume")
	main.home.new_game_button.pressed.emit()
	if main.home.visible or main.menu_open():
		failures.append("New game did not leave Home")
	if main.game == null or main.game.moves != 0:
		failures.append("New game did not start a fresh game")
	_check_tutorial()
	_check_hints()


## The tutorial's three moves play through the real drag path: a bar
## anywhere on the floor, a bar that finishes a row, and a bar into a gap
## that only snaps once the tower has been turned (#29).
func _check_tutorial() -> void:
	var tutorial = main.tutorial
	# The new game, set aside while the tutorial plays.
	var fresh = tutorial.saved_game()
	if not tutorial.is_active() or not main.tutorial_overlay.visible:
		failures.append("New game for a new player did not start the tutorial")
		return
	if main.tutorial_overlay.step_label.text != "Step 1 of 3":
		failures.append("tutorial bar shows '%s'" % main.tutorial_overlay.step_label.text)
	for i in range(Tutorial.step_count()):
		if tutorial.step != i:
			failures.append("tutorial is on step %d, expected %d" % [tutorial.step, i])
			return
		if main.game.tray[0] == null or main.game.tray[0].size != Tutorial.step(i).piece_size:
			failures.append("tutorial step %d has the wrong piece" % i)
		if Tutorial.step(i).hidden:
			if main.autoplay_one_move():
				failures.append("the hidden gap took the piece before the tower was turned")
			if not main.tutorial_overlay.ring.target.has_area():
				failures.append("the hidden step does not ring the rotate button")
			main.turn(1, true)
			if not tutorial.found:
				failures.append("turning the tower did not find the hidden gap")
		var lines: int = main.game.lines_cleared_total
		if not main.autoplay_one_move():
			failures.append("tutorial step %d move did not go through" % i)
			return
		if i > 0 and main.game.lines_cleared_total != lines + 1:
			failures.append("tutorial step %d did not clear its row" % i)
		if main.game.tray.any(func(p): return p != null):
			failures.append("tutorial step %d refilled the tray" % i)
		main.finish_animations()
		tutorial.advance()
	if tutorial.is_active() or main.tutorial_overlay.visible:
		failures.append("the tutorial did not end after its last move")
	if main.game != fresh or main.game.moves != 0:
		failures.append("the tutorial did not hand back the new game")
	if main.tower.rig.view_step() != 0:
		failures.append("the tutorial left the camera turned")
	if main.drag.allowed_origins != null:
		failures.append("the tutorial left the drag limited to its target")
	if not main.hint_toast.visible or main.hint_toast.label.text != HintToast.TEXT.tutorial_done:
		failures.append("finishing the tutorial did not say so")
	if SaveFile.read(saves.onboarding_path).get("tutorial_done") != true:
		failures.append("finishing the tutorial was not saved")
	if int(SaveFile.read(saves.game_path).get("game", {}).get("moves", -1)) != 0:
		failures.append("the tutorial's moves were saved over the player's game")
	main.show_home()
	main.home.new_game_button.pressed.emit()
	if tutorial.is_active():
		failures.append("the tutorial started on its own a second time")


## Each one-time hint shows the first time its control is used, and never
## again (#29).
func _check_hints() -> void:
	main.hint_toast.dismiss()
	main.turn(1, true)
	if not main.hint_toast.visible or main.hint_toast.label.text != HintToast.TEXT.rotate:
		failures.append("the first turn did not show the rotate hint")
	main.hint_toast.dismiss()
	main.turn(-1, true)
	if main.hint_toast.visible:
		failures.append("the rotate hint showed twice")
	main.slice_slider.value = 2
	if not main.hint_toast.visible or main.hint_toast.label.text != HintToast.TEXT.swiper:
		failures.append("the first slice did not show the swiper hint")
	main.set_slice(main.swiper.mode, 0)
	main.hint_toast.dismiss()
	if not main.onboarding.has_seen("rotate") or not main.onboarding.has_seen("swiper"):
		failures.append("hints seen were not recorded")
	var saved: Dictionary = SaveFile.read(saves.onboarding_path)
	if not "swiper" in saved.get("hints_seen", []):
		failures.append("hints seen were not saved")
	_check_tips_switch()


## Settings › Game › Tips off hides a showing hint and keeps new ones from
## coming up; they stay unseen and show once Tips is back on (#164).
func _check_tips_switch() -> void:
	var tips_button = main.settings_sheet.tips_button
	if not tips_button.button_pressed:
		failures.append("the Tips switch did not start on")
	main.hint_toast.show_hint("rotate", main.viewport_box.get_global_rect(), 0)
	tips_button.button_pressed = false
	if main.hint_toast.visible:
		failures.append("turning off Tips left a hint showing")
	if SaveFile.read(saves.settings_path).get("tips") != false:
		failures.append("Tips off was not saved")
	main.show_hint("zoom")
	if main.hint_toast.visible:
		failures.append("a hint showed with Tips off")
	if main.onboarding.has_seen("zoom"):
		failures.append("a hint skipped with Tips off was marked seen")
	var reopened = _make_main()
	root.add_child(reopened)
	if reopened.settings.tips or reopened.settings_sheet.tips_button.button_pressed:
		failures.append("a fresh screen did not start with Tips off")
	reopened.queue_free()
	tips_button.button_pressed = true
	main.show_hint("zoom")
	if not main.hint_toast.visible or main.hint_toast.label.text != HintToast.TEXT.zoom:
		failures.append("turning Tips back on did not bring the hints back")
	main.hint_toast.dismiss()
	SaveFile.remove(saves.settings_path)


func _play() -> void:
	var moves := 0
	for i in range(MOVES):
		if main.game.is_over:
			main.new_game()
		# Exercise rotation and the swiper between moves.
		if i % 7 == 3:
			main.turn(1, true)
		if i % 5 == 2:
			main.set_slice(i % 3, i % 10)
		if main.autoplay_one_move():
			moves += 1
			if not main.tower.is_animating():
				failures.append("move %d did not start the move animation" % i)
			# The next drag is blocked until the animation ends.
			main.finish_animations()
			if main.shown_score != main.game.score:
				failures.append("move %d: header shows %d, score is %d" % [i, main.shown_score, main.game.score])
		else:
			failures.append("move %d did not go through the drag path" % i)
	main.set_slice(main.swiper.mode, 0)
	_check_score_tick()
	print("Placed %d of %d moves; score %d" % [moves, MOVES, main.game.score])
	# A new game mid-animation must cancel it cleanly.
	if main.autoplay_one_move():
		main.new_game()
		if main.tower.is_animating():
			failures.append("new game left the move animation running")


## The tutorial and the games played so far sent their events (#31): the
## finished game's game_over once, despite the repeated signal.
func _check_analytics() -> void:
	var sent: Array = main.analytics.backend.events
	var names: Array = main.analytics.backend.names()
	for i in Tutorial.step_count():
		if not sent.has(["tutorial_step", {"step": i + 1, "of": Tutorial.step_count()}]):
			failures.append("analytics: no tutorial_step %d" % (i + 1))
	if not sent.has(["tutorial_end", {"completed": true, "step": Tutorial.step_count()}]):
		failures.append("analytics: no tutorial_end for the finished tutorial")
	for event in ["game_start", "game_over", "game_quit"]:
		if not names.has(event):
			failures.append("analytics: no %s in %s" % [event, names])
	if names.count("game_over") != 1:
		failures.append("analytics: game_over sent %d times" % names.count("game_over"))
	if names.count("game_start") != names.count("game_over") + names.count("game_quit"):
		failures.append("analytics: every started game should end or be quit once: %s" % [names])


## The header counts up to a new score instead of jumping (#25).
func _check_score_tick() -> void:
	main.score_feedback.snap()
	var start: int = main.shown_score
	main.score_feedback.tick_to(start + 1000)
	if main.shown_score != start:
		failures.append("score counter jumped instead of ticking")
	main.score_feedback.tween().custom_step(ScoreFeedback.SCORE_TICK_SECONDS * 0.5)
	if main.shown_score <= start or main.shown_score >= start + 1000:
		failures.append("score counter mid-tick shows %d" % main.shown_score)
	main.score_feedback.tween().custom_step(ScoreFeedback.SCORE_TICK_SECONDS)
	if main.shown_score != start + 1000:
		failures.append("score counter ended on %d, not %d" % [main.shown_score, start + 1000])
	main.score_feedback.snap()


## The game-over card (#19) shows this game's score and stats over one
## Play again button, and hides the Game Center line until #30 sends a score.
func _check_game_over_card() -> void:
	var card = main.game_over_card
	card.finish_animation()
	if not card.visible:
		failures.append("game over did not show the game-over card")
		return
	if card.slider.position.y != 0.0:
		failures.append("game-over card did not finish sliding up")
	var g = main.game
	var expected := {
		"score": UI.format_number(g.score),
		"best": "Best %s" % UI.format_number(main.stats.best_score),
		"lines": UI.format_number(g.lines_cleared_total),
		"streak": str(g.longest_streak),
	}
	var shown := {
		"score": card.score_label.text,
		"best": card.best_label.text,
		"lines": card.lines_label.text,
		"streak": card.streak_label.text,
	}
	if shown != expected:
		failures.append("game-over card shows %s, expected %s" % [shown, expected])
	if card.score_saved_row.visible:
		failures.append("game-over card claims a Game Center save with Game Center off")
	if main.overlay.visible:
		failures.append("game over also opened the old overlay")
	main.start_drag(0, Vector2.ZERO)
	if main.drag.is_dragging():
		failures.append("a piece could be dragged under the game-over card")


## On a loss the last move lands, then the tower shakes and crumbles into
## rubble before the game-over card comes up (#132). The game ends while its
## last move is still animating, so main holds the game over until then
## (#112).
func _check_crumble() -> void:
	var tower = main.tower
	var cubes: int = main.game.grid.filled_cells().size()
	if not tower.is_animating():
		failures.append("the last move was not animating when the game ended, so the held game over went untested")
	if main.game_over_card.visible:
		failures.append("game-over card opened before the last move landed")
	tower.finish_move_animation()
	if not tower.is_crumbling():
		failures.append("game over did not start the crumble")
	if main.game_over_card.visible:
		failures.append("game-over card opened before the tower crumbled")
	if tower.solid_count() != 0:
		failures.append("placed blocks still drawn while the tower crumbles")
	main.finish_animations()
	if tower.is_crumbling() or not tower.has_crumbled():
		failures.append("crumble did not finish into rubble")
	if not main.game_over_card.visible:
		failures.append("the held game over did not open the game-over card once the tower crumbled")
	if tower.rubble_count() != cubes * tower.RUBBLE_PER_CUBE:
		failures.append("rubble has %d pieces, expected %d" % [tower.rubble_count(), cubes * tower.RUBBLE_PER_CUBE])
	if tower.crumbling_count() != 0:
		failures.append("whole cubes left standing after the crumble")
	for rest in tower.rubble_rests():
		if rest.y < 0.0 or Vector2(rest.x, rest.z).length() > 4.0:
			failures.append("rubble came to rest off the island at %s" % rest)
			break


## With no finished game, neither the header nor Home shows a best score
## (#118).
func _check_best_hidden() -> void:
	if main.best_row.visible:
		failures.append("the header shows a best score before any game has finished")
	if main.home.best_pill.visible:
		failures.append("Home shows a best score before any game has finished")


## Finished games are recorded once and saved; settings button → Settings → Stats → Back
## opens and closes the right screens (#32).
func _check_stats() -> void:
	main.new_game()
	var before: int = main.stats.games_played
	while not main.game.is_over and main.autoplay_one_move():
		if not main.game.is_over:
			main.finish_animations()
	if not main.game.is_over:
		failures.append("autoplay could not finish a game")
		return
	_check_crumble()
	_check_game_over_card()
	# A repeated game_over must not count the game a second time.
	main.game.game_over.emit(main.game.score)
	if main.stats.games_played != before + 1:
		failures.append("finished game counted %d times" % (main.stats.games_played - before))
	_check_analytics()
	if not main.best_row.visible:
		failures.append("the header hides the best score after a finished game")
	if main.stats.best_score < main.game.score:
		failures.append("best score %d is below the finished score %d" % [main.stats.best_score, main.game.score])
	if FileAccess.file_exists(saves.game_path):
		failures.append("a finished game left its auto-save behind")
	var saved: Dictionary = SaveFile.read(saves.stats_path)
	if int(saved.get("games_played", -1)) != main.stats.games_played:
		failures.append("stats file has %s games, expected %d" % [saved.get("games_played"), main.stats.games_played])
	main.game_over_card.play_again_button.pressed.emit()
	if main.game_over_card.visible or main.game.is_over or main.game.moves != 0:
		failures.append("Play again did not close the card and start a fresh game")

	main.show_settings()
	if not main.settings_sheet.visible or not main.menu_open():
		failures.append("the settings button did not open the Settings sheet")
	if not main.settings_sheet.home_button.visible:
		failures.append("Settings opened in a game has no Home row")
	main.settings_sheet.stats_button.pressed.emit()
	if main.settings_sheet.visible or not main.stats_screen.visible:
		failures.append("Settings › Stats did not open the Stats screen")
	if main.stats_screen.values.games_played.text != str(main.stats.games_played):
		failures.append("Stats screen shows %s games, expected %d" % [main.stats_screen.values.games_played.text, main.stats.games_played])
	main.stats_screen.back_pressed.emit()
	if main.stats_screen.visible or not main.settings_sheet.visible:
		failures.append("Back from Stats did not return to Settings")
	_check_grid_ticks()
	_check_sound_switches()
	_check_volume_sliders()
	_check_now_playing()
	main.settings_sheet.close_sheet()
	if main.menu_open():
		failures.append("closing Settings left a menu open")
	_check_home_menus()
	SaveFile.remove(saves.stats_path)


## Home's Stats closes back to Home; Home's Settings has no Home row; and
## Settings › Home from a game returns to Home (#72).
func _check_home_menus() -> void:
	main.show_home()
	var best_text := "BEST %s" % UI.format_number(main.stats.best_score)
	if not main.home.best_pill.visible or main.home.best_label.text != best_text:
		failures.append("Home does not show %s after a finished game" % best_text)
	main.home.stats_button.pressed.emit()
	if not main.stats_screen.visible:
		failures.append("Home › Stats did not open the Stats screen")
	main.stats_screen.back_pressed.emit()
	if main.stats_screen.visible or main.settings_sheet.visible or not main.home.visible:
		failures.append("Back from Stats did not return to Home")
	main.home.settings_button.pressed.emit()
	if not main.settings_sheet.visible or main.settings_sheet.home_button.visible:
		failures.append("Home › Settings should open Settings without a Home row")
	# Replay tutorial from Home's Settings, then Skip, lands back on Home.
	main.settings_sheet.tutorial_button.pressed.emit()
	if not main.tutorial.is_active() or main.settings_sheet.visible or main.home.visible:
		failures.append("Replay tutorial did not start the tutorial")
	main.tutorial_overlay.skip_button.pressed.emit()
	if main.tutorial.is_active() or not main.home.visible:
		failures.append("Skip from a tutorial started on Home did not return to Home")
	main.home.how_to_play_button.pressed.emit()
	if not main.tutorial.is_active():
		failures.append("How to play did not start the tutorial")
	main.tutorial_overlay.skip_button.pressed.emit()
	if not main.home.visible:
		failures.append("Skip from How to play did not return to Home")
	main.home.new_game_button.pressed.emit()
	# Replay tutorial from a game, then Skip, returns to that game.
	main.autoplay_one_move()
	main.finish_animations()
	var playing = main.game
	var moves: int = playing.moves
	main.show_settings()
	main.settings_sheet.tutorial_button.pressed.emit()
	main.tutorial_overlay.skip_button.pressed.emit()
	if main.game != playing or main.game.moves != moves or main.menu_open():
		failures.append("Skip from Replay tutorial did not return to the game")
	main.show_settings()
	main.settings_sheet.home_button.pressed.emit()
	if not main.home.visible or main.settings_sheet.visible:
		failures.append("Settings › Home did not return to Home")
	main.home.new_game_button.pressed.emit()
	_check_home_buttons()


## The header's Home button leaves a game for Home with Continue on offer,
## is hidden during the tutorial, and the game-over card's Home button
## returns to Home with nothing to continue (#163).
func _check_home_buttons() -> void:
	main.autoplay_one_move()
	main.finish_animations()
	var playing = main.game
	main.home_button.pressed.emit()
	if not main.home.visible or not main.home.continue_button.visible:
		failures.append("the header's Home button did not open Home with Continue")
	if main.home.island.is_animating() or main.home.island.cells.size() != main.game.grid.filled_cells().size():
		failures.append("Home with a game to continue did not show that game's tower standing still")
	main.home.continue_button.pressed.emit()
	if main.game != playing or main.menu_open():
		failures.append("Continue after the header's Home button did not return to the game")

	main.start_tutorial()
	if main.home_button.modulate.a != 0.0 or not main.home_button.disabled:
		failures.append("the header's Home button stayed usable during the tutorial")
	if main.undo_button.modulate.a != 0.0 or main.can_undo():
		failures.append("the header's Undo button stayed usable during the tutorial")
	main.tutorial_overlay.skip_button.pressed.emit()
	if main.home_button.modulate.a != 1.0 or main.home_button.disabled:
		failures.append("the header's Home button did not come back after the tutorial")

	while not main.game.is_over and main.autoplay_one_move():
		main.finish_animations()
	main.finish_animations()
	if not main.game_over_card.visible:
		failures.append("could not finish a game to test the game-over card's Home button")
		return
	main.game_over_card.home_button.pressed.emit()
	if not main.home.visible or main.game_over_card.visible:
		failures.append("the game-over card's Home button did not return to Home")
	if main.home.continue_button.visible:
		failures.append("Home offered Continue for a finished game")
	main.home.new_game_button.pressed.emit()


## Settings › Display › Grid ticks shows the ticks, saves the choice and a
## fresh screen starts with it (#56).
func _check_grid_ticks() -> void:
	if main.tower.grid_ticks_visible():
		failures.append("grid ticks showed before they were turned on")
	main.settings_sheet.grid_ticks_button.button_pressed = true
	if not main.tower.grid_ticks_visible():
		failures.append("turning on Grid ticks did not show them")
	if SaveFile.read(saves.settings_path).get("grid_ticks") != true:
		failures.append("Grid ticks were not saved")
	var reopened = _make_main()
	root.add_child(reopened)
	if not reopened.tower.grid_ticks_visible() or not reopened.settings_sheet.grid_ticks_button.button_pressed:
		failures.append("a fresh screen did not start with Grid ticks on")
	reopened.queue_free()
	main.settings_sheet.grid_ticks_button.button_pressed = false
	if main.tower.grid_ticks_visible():
		failures.append("turning off Grid ticks did not hide them")
	SaveFile.remove(saves.settings_path)


## The tower's bounding box is grey by day and ice blue at night, so it
## still shows on the dark sky (#253).
func _check_night_lines() -> void:
	var tower = main.tower
	var was: Array = [SkyView.season, SkyView.time_of_day]
	SkyView.show("fall", "night", true)
	main.update_sky(0.0)
	if not tower.guide_color().is_equal_approx(tower.GUIDE_NIGHT_COLOR):
		failures.append("bounding box at night is %s, expected %s" % [tower.guide_color(), tower.GUIDE_NIGHT_COLOR])
	SkyView.show("fall", "day", true)
	main.update_sky(0.0)
	if not tower.guide_color().is_equal_approx(tower.GUIDE_COLOR):
		failures.append("bounding box by day is %s, expected %s" % [tower.guide_color(), tower.GUIDE_COLOR])
	SkyView.show(was[0], was[1], true)
	main.update_sky(0.0)


## Settings › Sound and feel: each switch starts on, saves when flipped and
## a fresh screen shows the saved state (#20). Replay tutorial stays hidden
## until the tutorial exists (#29).
func _check_sound_switches() -> void:
	var sheet = main.settings_sheet
	if not sheet.tutorial_button.visible:
		failures.append("Settings has no Replay tutorial row")
	var switches := {
		"music": sheet.music_button,
		"sound_effects": sheet.sound_effects_button,
		"haptics": sheet.haptics_button,
	}
	if not main.audio.is_music_playing():
		failures.append("the music did not start on")
	for key in switches:
		if not switches[key].button_pressed:
			failures.append("%s switch did not start on" % key)
		switches[key].button_pressed = false
		if main.settings.get(key) != false:
			failures.append("turning off %s did not change the setting" % key)
	if main.haptics.enabled:
		failures.append("turning off haptics left the haptics on")
	if main.audio.sound_effects:
		failures.append("turning off sound effects left them on")
	if main.audio.is_music_playing():
		failures.append("turning off music left it playing")
	var saved: Dictionary = SaveFile.read(saves.settings_path)
	for key in switches:
		if saved.get(key) != false:
			failures.append("%s was not saved" % key)
	var reopened = _make_main()
	root.add_child(reopened)
	if reopened.settings_sheet.music_button.button_pressed or reopened.settings.haptics:
		failures.append("a fresh screen did not start with the saved sound settings")
	if reopened.haptics.enabled:
		failures.append("a fresh screen did not apply the saved haptics setting")
	if reopened.audio.sound_effects or reopened.audio.is_music_playing():
		failures.append("a fresh screen did not apply the saved sound settings")
	reopened.queue_free()
	main.new_game()
	if main.tower.has_crumbled() or main.tower.rubble_count() != 0:
		failures.append("a new game kept the last game's rubble")
	for key in switches:
		switches[key].button_pressed = true
	if not main.haptics.enabled:
		failures.append("turning haptics back on left them off")
	if not main.audio.sound_effects or not main.audio.is_music_playing():
		failures.append("turning sound back on left it off")
	SaveFile.remove(saves.settings_path)


## Settings › Sound and feel: the track playing shows under the music
## slider, the skip button starts a new one, and it stops while Music is
## off (#166).
func _check_now_playing() -> void:
	var sheet = main.settings_sheet
	if sheet.track_title_label.text == "" or sheet.track_title_label.text != main.audio.track_title():
		failures.append("Settings does not show the track playing")
	var started := [0]
	var count := func(_t, _a): started[0] += 1
	main.audio.track_changed.connect(count)
	sheet.next_track_button.pressed.emit()
	main.audio.track_changed.disconnect(count)
	if started[0] != 1:
		failures.append("the skip button did not start the next track")
	if sheet.track_title_label.text != main.audio.track_title():
		failures.append("Settings did not show the skipped-to track")
	var was_on: bool = sheet.music_button.button_pressed
	sheet.music_button.button_pressed = false
	if not sheet.next_track_button.disabled:
		failures.append("the skip button works while Music is off")
	main.audio.next_track()
	if main.audio.is_music_playing():
		failures.append("a new track played while Music is off")
	sheet.music_button.button_pressed = was_on


## Settings › Sound and feel: each volume slider starts full, sets its own
## audio and saves, a fresh screen picks it up, and it dims while its
## switch is off (#165).
func _check_volume_sliders() -> void:
	var sheet = main.settings_sheet
	var sliders := {
		"music_volume": sheet.music_volume_slider,
		"sound_effects_volume": sheet.sound_effects_volume_slider,
	}
	for key in sliders:
		if sliders[key].value != 1.0:
			failures.append("%s slider did not start full" % key)
	sheet.music_volume_slider.value = 0.3
	sheet.sound_effects_volume_slider.value = 0.7
	if not is_equal_approx(main.audio.music_volume, 0.3) or not is_equal_approx(main.audio.sound_effects_volume, 0.7):
		failures.append("moving a volume slider did not set the audio")
	if main.audio.music_db() >= main.audio.MUSIC_DB:
		failures.append("lowering the music volume left the music as loud")
	var saved: Dictionary = SaveFile.read(saves.settings_path)
	if not is_equal_approx(saved.get("music_volume", 0.0), 0.3) or not is_equal_approx(saved.get("sound_effects_volume", 0.0), 0.7):
		failures.append("the volumes were not saved")
	var reopened = _make_main()
	root.add_child(reopened)
	if not is_equal_approx(reopened.settings_sheet.music_volume_slider.value, 0.3) \
			or not is_equal_approx(reopened.audio.sound_effects_volume, 0.7):
		failures.append("a fresh screen did not pick up the saved volumes")
	reopened.queue_free()
	sheet.music_button.button_pressed = false
	if sheet.music_volume_slider.editable or not sheet.sound_effects_volume_slider.editable:
		failures.append("the music slider did not follow its switch alone")
	sheet.music_button.button_pressed = true
	if not sheet.music_volume_slider.editable:
		failures.append("the music slider stayed off with its switch back on")
	for key in sliders:
		sliders[key].value = 1.0
	SaveFile.remove(saves.settings_path)


## Undo takes back the last move through the header button, only once,
## and only once the move has finished animating (#184).
func _check_undo() -> void:
	main.new_game()
	if main.can_undo():
		failures.append("a new game offers undo")
	var before := JSON.stringify(main.game.to_dict())
	if not main.autoplay_one_move():
		failures.append("undo check could not place a piece")
		return
	if main.can_undo():
		failures.append("undo is offered while the move animates")
	main.finish_animations()
	if not main.can_undo():
		failures.append("undo is not offered after a move")
	main.undo_button.pressed.emit()
	if JSON.stringify(main.game.to_dict()) != before:
		failures.append("undo did not restore the game")
	if main.shown_score != main.game.score:
		failures.append("header shows %d after undo, score is %d" % [main.shown_score, main.game.score])
	if main.can_undo():
		failures.append("undo is offered twice in a row")
	var saved := SaveFile.read(saves.game_path)
	if int(saved.get("game", {}).get("moves", -1)) != 0:
		failures.append("the undone game was not saved")
	main.autoplay_one_move()
	main.finish_animations()
	main.show_settings()
	if main.can_undo():
		failures.append("undo is offered behind the Settings sheet")
	main.settings_sheet.close_sheet()
	if not main.can_undo():
		failures.append("undo is not offered once Settings closes")


## A placement saves the game and camera; a fresh screen picks both up, and
## a save that doesn't fit the config is dropped for a new game (#18).
func _check_resume() -> void:
	main.new_game()
	main.turn(1, true)
	main.tower.rig.zoom_by(1.2)
	if not main.autoplay_one_move():
		failures.append("resume check could not place a piece")
		return
	main.finish_animations()
	var expected: Dictionary = main.game.to_dict()
	var step: int = main.tower.rig.view_step()
	var zoom: float = main.tower.rig.camera.size

	var resumed = _make_main()
	root.add_child(resumed)
	if not resumed.home.visible or not resumed.home.continue_button.visible:
		failures.append("Home did not offer Continue for a saved game")
	elif resumed.home.continue_score.text != "· %s" % UI.format_number(main.game.score):
		failures.append("Continue shows %s, expected score %d" % [resumed.home.continue_score.text, main.game.score])
	resumed.home.continue_button.pressed.emit()
	if resumed.home.visible or resumed.menu_open():
		failures.append("Continue did not leave Home")
	if JSON.stringify(resumed.game.to_dict()) != JSON.stringify(expected):
		failures.append("resumed game differs from the saved one")
	if resumed.tower.rig.view_step() != step or not is_equal_approx(resumed.tower.rig.camera.size, zoom):
		failures.append("resumed camera is step %d zoom %.2f, expected %d zoom %.2f" % [
			resumed.tower.rig.view_step(), resumed.tower.rig.camera.size, step, zoom])
	resumed.queue_free()

	var data := SaveFile.read(saves.game_path)
	data.game.config = "other"
	SaveFile.write(saves.game_path, data)
	var fresh = _make_main()
	root.add_child(fresh)
	if fresh.game.moves != 0:
		failures.append("a save from another config was resumed")
	fresh.queue_free()
	SaveFile.remove(saves.game_path)


## A save whose game is already over (the app closed before the game-over
## card counted it) is counted on launch, once: the next launch doesn't
## count it again (#111).
func _check_finished_save() -> void:
	main.new_game()
	var data: Dictionary = main.game.to_dict()
	data.is_over = true
	data.moves = 12
	data.score = 98765
	SaveFile.write(saves.game_path, {"game": data, "view": {}})
	var before := int(SaveFile.read(saves.stats_path).get("games_played", 0))

	var first = _make_main()
	root.add_child(first)
	if first.stats.games_played != before + 1:
		failures.append("a finished game in the save was counted %d times on launch" % (first.stats.games_played - before))
	if first.stats.best_score < 98765:
		failures.append("launch counted the finished game with best score %d, expected 98765" % first.stats.best_score)
	if int(SaveFile.read(saves.stats_path).get("games_played", -1)) != before + 1:
		failures.append("the finished game counted on launch was not saved to the stats file")
	# Launch starts a new game and saves it, so the finished game's save must
	# be gone or replaced by that fresh one.
	var left: Dictionary = SaveFile.read(saves.game_path).get("game", {})
	if left.get("is_over", false) or int(left.get("moves", 0)) != 0:
		failures.append("the finished game's save was left behind after launch")
	if first.game.is_over or first.game.moves != 0:
		failures.append("launch with a finished game saved did not start a new game")
	if not first.home.visible or first.home.continue_button.visible:
		failures.append("Home offered Continue for a game that was already over")
	first.queue_free()

	var second = _make_main()
	root.add_child(second)
	if second.stats.games_played != before + 1:
		failures.append("the finished game was counted again on the next launch (%d games, expected %d)" % [second.stats.games_played, before + 1])
	second.queue_free()
	SaveFile.remove(saves.game_path)
	SaveFile.remove(saves.stats_path)
