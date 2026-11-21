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
	# Test at iPhone size; headless windows otherwise start at a default size.
	DisplayServer.window_set_size(Vector2i(390, 844))
	root.size = Vector2i(390, 844)
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
			main._set_slice_mode(i % 2)
			main._set_slice_depth(i % 4)
		if main.autoplay_one_move():
			moves += 1
		else:
			failures.append("move %d did not go through the drag path" % i)
	main._set_slice_depth(0)
	print("Placed %d of %d moves; score %d" % [moves, MOVES, main.game.score])


func _finish() -> void:
	if failures.is_empty():
		print("Smoke test passed.")
		quit(0)
	else:
		print("Smoke test failed:")
		for f in failures:
			print("  - " + f)
		quit(1)
