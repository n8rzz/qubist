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

var main
var frame := 0
var failures: Array[String] = []


func _initialize() -> void:
	# Note: headless Godot ignores window size changes, so this runs at the
	# headless default (wider than a phone). Layout is fluid, so the drag path
	# is the same; check real sizes on a device.
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		_check_layout()
	elif frame == 10:
		_play()
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


func _finish() -> void:
	if failures.is_empty():
		print("Smoke test passed.")
		quit(0)
	else:
		print("Smoke test failed:")
		for f in failures:
			print("  - " + f)
		quit(1)
