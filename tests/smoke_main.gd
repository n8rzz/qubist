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
const SmokeSaves := preload("res://tests/smoke_saves.gd")
const UI := preload("res://game/ui_style.gd")
const ScoreFeedback := preload("res://game/score_feedback.gd")

var main
var frame := 0
var failures: Array[String] = []
## Keeps the smoke test's stats, auto-saved game (#18) and settings (#56) out
## of the real save files.
var saves := SmokeSaves.new("smoke")


func _initialize() -> void:
	# Note: headless Godot ignores window size changes, so this runs at the
	# headless default (wider than a phone). Layout is fluid, so the drag path
	# is the same; check real sizes on a device.
	saves.clear()
	main = _make_main()
	root.add_child(main)


func _make_main():
	var screen = load("res://scenes/main.tscn").instantiate()
	saves.use_on(screen)
	return screen


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		_check_layout()
	elif frame == 7:
		_check_home()
	elif frame == 10:
		_play()
	elif frame == 15:
		_check_stats()
	elif frame == 18:
		_check_resume()
	elif frame == 20:
		saves.finish(self, failures, "game screen smoke test")
	return false


func _check_layout() -> void:
	var rect: Rect2 = main.viewport_box.get_global_rect()
	print("Tower area: %s" % rect)
	if rect.size.x < 100 or rect.size.y < 100:
		failures.append("tower area is too small: %s" % rect)
	if main.tray_slots.size() != 3:
		failures.append("expected 3 tray slots, found %d" % main.tray_slots.size())


## Launch opens Home with no Continue (nothing saved yet); New game leaves
## it for the game (#72).
func _check_home() -> void:
	if not main.home.visible or not main.menu_open():
		failures.append("launch did not open Home")
	if main.home.continue_button.visible:
		failures.append("Home offered Continue with no game to resume")
	main.home.new_game_button.pressed.emit()
	if main.home.visible or main.menu_open():
		failures.append("New game did not leave Home")
	if main.game == null or main.game.moves != 0:
		failures.append("New game did not start a fresh game")


func _play() -> void:
	var moves := 0
	for i in range(MOVES):
		if main.game.is_over:
			main.new_game()
		# Exercise rotation and the swiper between moves.
		if i % 7 == 3:
			main._turn(1)
			main.tower.rig._tween.custom_step(1.0)
		if i % 5 == 2:
			main._set_slice_mode(i % 3)
			main._set_slice_depth(i % 10)
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
	main._set_slice_depth(0)
	_check_score_tick()
	print("Placed %d of %d moves; score %d" % [moves, MOVES, main.game.score])
	# A new game mid-animation must cancel it cleanly.
	if main.autoplay_one_move():
		main.new_game()
		if main.tower.is_animating():
			failures.append("new game left the move animation running")


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
	main._start_drag(0, Vector2.ZERO)
	if main.drag.is_dragging():
		failures.append("a piece could be dragged under the game-over card")


## Finished games are recorded once and saved; gear → Settings → Stats → Back
## opens and closes the right screens (#32).
func _check_stats() -> void:
	main.new_game()
	var before: int = main.stats.games_played
	while not main.game.is_over and main.autoplay_one_move():
		main.finish_animations()
	if not main.game.is_over:
		failures.append("autoplay could not finish a game")
		return
	main.finish_animations()
	main._on_game_over(main.game.score)
	_check_game_over_card()
	if main.stats.games_played != before + 1:
		failures.append("finished game counted %d times" % (main.stats.games_played - before))
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
		failures.append("gear did not open the Settings sheet")
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
	main.settings_sheet.close_sheet()
	if main.menu_open():
		failures.append("closing Settings left a menu open")
	_check_home_menus()
	SaveFile.remove(saves.stats_path)


## Home's Stats closes back to Home; Home's Settings has no Home row; and
## Settings › Home from a game returns to Home (#72).
func _check_home_menus() -> void:
	main.show_home()
	main.home.stats_button.pressed.emit()
	if not main.stats_screen.visible:
		failures.append("Home › Stats did not open the Stats screen")
	main.stats_screen.back_pressed.emit()
	if main.stats_screen.visible or main.settings_sheet.visible or not main.home.visible:
		failures.append("Back from Stats did not return to Home")
	main.home.settings_button.pressed.emit()
	if not main.settings_sheet.visible or main.settings_sheet.home_button.visible:
		failures.append("Home › Settings should open Settings without a Home row")
	main.settings_sheet.close_sheet()
	main.home.new_game_button.pressed.emit()
	main.show_settings()
	main.settings_sheet.home_button.pressed.emit()
	if not main.home.visible or main.settings_sheet.visible:
		failures.append("Settings › Home did not return to Home")
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


## Settings › Sound and feel: each switch starts on, saves when flipped and
## a fresh screen shows the saved state (#20). Replay tutorial stays hidden
## until the tutorial exists (#29).
func _check_sound_switches() -> void:
	var sheet = main.settings_sheet
	if sheet.tutorial_button.visible:
		failures.append("Replay tutorial showed before the tutorial exists")
	var switches := {
		"music": sheet.music_button,
		"sound_effects": sheet.sound_effects_button,
		"haptics": sheet.haptics_button,
	}
	for key in switches:
		if not switches[key].button_pressed:
			failures.append("%s switch did not start on" % key)
		switches[key].button_pressed = false
		if main.settings.get(key) != false:
			failures.append("turning off %s did not change the setting" % key)
	var saved: Dictionary = SaveFile.read(saves.settings_path)
	for key in switches:
		if saved.get(key) != false:
			failures.append("%s was not saved" % key)
	var reopened = _make_main()
	root.add_child(reopened)
	if reopened.settings_sheet.music_button.button_pressed or reopened.settings.haptics:
		failures.append("a fresh screen did not start with the saved sound settings")
	reopened.queue_free()
	for key in switches:
		switches[key].button_pressed = true
	SaveFile.remove(saves.settings_path)


## A placement saves the game and camera; a fresh screen picks both up, and
## a save that doesn't fit the config is dropped for a new game (#18).
func _check_resume() -> void:
	main.new_game()
	main._turn(1)
	main.tower.rig._tween.custom_step(1.0)
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
