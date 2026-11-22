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
## Keeps the smoke test's finished games out of the real stats file.
const STATS_PATH := "user://test_saves/smoke_stats.json"
## Likewise for the auto-saved game (#18).
const GAME_PATH := "user://test_saves/smoke_game.json"
## And for player settings (#56).
const SETTINGS_PATH := "user://test_saves/smoke_settings.json"
const SaveFile := preload("res://core/save_file.gd")

var main
var frame := 0
var failures: Array[String] = []


func _initialize() -> void:
	# Note: headless Godot ignores window size changes, so this runs at the
	# headless default (wider than a phone). Layout is fluid, so the drag path
	# is the same; check real sizes on a device.
	SaveFile.remove(STATS_PATH)
	SaveFile.remove(GAME_PATH)
	SaveFile.remove(SETTINGS_PATH)
	main = _make_main()
	root.add_child(main)


func _make_main():
	var screen = load("res://scenes/main.tscn").instantiate()
	screen.stats_path = STATS_PATH
	screen.game_save_path = GAME_PATH
	screen.settings_path = SETTINGS_PATH
	return screen


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		_check_layout()
	elif frame == 10:
		_play()
	elif frame == 15:
		_check_stats()
	elif frame == 18:
		_check_resume()
	elif frame == 20:
		_finish()
	return false


func _check_layout() -> void:
	var rect: Rect2 = main.viewport_box.get_global_rect()
	print("Tower area: %s" % rect)
	if rect.size.x < 100 or rect.size.y < 100:
		failures.append("tower area is too small: %s" % rect)
	if main.tray_slots.size() != 3:
		failures.append("expected 3 tray slots, found %d" % main.tray_slots.size())


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
	main._snap_score()
	var start: int = main.shown_score
	main._tick_score_to(start + 1000)
	if main.shown_score != start:
		failures.append("score counter jumped instead of ticking")
	main._score_tween.custom_step(main.SCORE_TICK_SECONDS * 0.5)
	if main.shown_score <= start or main.shown_score >= start + 1000:
		failures.append("score counter mid-tick shows %d" % main.shown_score)
	main._score_tween.custom_step(main.SCORE_TICK_SECONDS)
	if main.shown_score != start + 1000:
		failures.append("score counter ended on %d, not %d" % [main.shown_score, start + 1000])
	main._snap_score()


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
	if main.stats.games_played != before + 1:
		failures.append("finished game counted %d times" % (main.stats.games_played - before))
	if main.stats.best_score < main.game.score:
		failures.append("best score %d is below the finished score %d" % [main.stats.best_score, main.game.score])
	if FileAccess.file_exists(GAME_PATH):
		failures.append("a finished game left its auto-save behind")
	var saved: Dictionary = SaveFile.read(STATS_PATH)
	if int(saved.get("games_played", -1)) != main.stats.games_played:
		failures.append("stats file has %s games, expected %d" % [saved.get("games_played"), main.stats.games_played])
	main.new_game()

	main.show_settings()
	if not main.settings_sheet.visible or not main.menu_open():
		failures.append("gear did not open the Settings sheet")
	main.settings_sheet.stats_button.pressed.emit()
	if main.settings_sheet.visible or not main.stats_screen.visible:
		failures.append("Settings › Stats did not open the Stats screen")
	if main.stats_screen.values.games_played.text != str(main.stats.games_played):
		failures.append("Stats screen shows %s games, expected %d" % [main.stats_screen.values.games_played.text, main.stats.games_played])
	main.stats_screen.back_pressed.emit()
	if main.stats_screen.visible or not main.settings_sheet.visible:
		failures.append("Back from Stats did not return to Settings")
	_check_grid_ticks()
	main.settings_sheet.close_sheet()
	if main.menu_open():
		failures.append("closing Settings left a menu open")
	SaveFile.remove(STATS_PATH)


## Settings › Display › Grid ticks shows the ticks, saves the choice and a
## fresh screen starts with it (#56).
func _check_grid_ticks() -> void:
	if main.tower.grid_ticks_visible():
		failures.append("grid ticks showed before they were turned on")
	main.settings_sheet.grid_ticks_button.button_pressed = true
	if not main.tower.grid_ticks_visible():
		failures.append("turning on Grid ticks did not show them")
	if SaveFile.read(SETTINGS_PATH).get("grid_ticks") != true:
		failures.append("Grid ticks were not saved")
	var reopened = _make_main()
	root.add_child(reopened)
	if not reopened.tower.grid_ticks_visible() or not reopened.settings_sheet.grid_ticks_button.button_pressed:
		failures.append("a fresh screen did not start with Grid ticks on")
	reopened.queue_free()
	main.settings_sheet.grid_ticks_button.button_pressed = false
	if main.tower.grid_ticks_visible():
		failures.append("turning off Grid ticks did not hide them")
	SaveFile.remove(SETTINGS_PATH)


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
	if JSON.stringify(resumed.game.to_dict()) != JSON.stringify(expected):
		failures.append("resumed game differs from the saved one")
	if resumed.tower.rig.view_step() != step or not is_equal_approx(resumed.tower.rig.camera.size, zoom):
		failures.append("resumed camera is step %d zoom %.2f, expected %d zoom %.2f" % [
			resumed.tower.rig.view_step(), resumed.tower.rig.camera.size, step, zoom])
	resumed.queue_free()

	var data := SaveFile.read(GAME_PATH)
	data.game.config = "other"
	SaveFile.write(GAME_PATH, data)
	var fresh = _make_main()
	root.add_child(fresh)
	if fresh.game.moves != 0:
		failures.append("a save from another config was resumed")
	fresh.queue_free()
	SaveFile.remove(GAME_PATH)


func _finish() -> void:
	if failures.is_empty():
		print("Smoke test passed.")
		quit(0)
	else:
		print("Smoke test failed:")
		for f in failures:
			print("  - " + f)
		quit(1)
