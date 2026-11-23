extends RefCounted
## Plays the tutorial (#29) on the game screen: three scripted moves from
## core/tutorial.gd, each on its own small game, with the overlay showing
## what to do.
##
## The player's own game is set aside while it runs and put back after,
## along with the camera. Reads and drives the screen through `host`
## (game/main.gd), like the drag controller.

const Tutorial := preload("res://core/tutorial.gd")
const ViewMath := preload("res://game/view_math.gd")
const DragController := preload("res://game/drag_controller.gd")
const CameraRig := preload("res://game/camera_rig.gd")

## Pause between one move landing and the next step coming up.
const NEXT_STEP_SECONDS := 0.45
## Padding around a lit control, in points.
const HOLE_PAD := 6.0

signal finished(completed: bool)

## The game screen (game/main.gd).
var host
var step := -1
## A hidden target has been brought into view by turning or slicing.
var found := false
var _saved_game
var _saved_view_step := 0
var _saved_zoom := 0.0
var _on_done := Callable()
## The last layout drawn, so the overlay is only rebuilt when it changes.
var _layout_key := []
## The step's move is placed and playing out.
var _moving := false


func _init(screen) -> void:
	host = screen


func is_active() -> bool:
	return step >= 0


## Sets the player's game aside and starts at move 1. `on_done` runs once
## the tutorial is finished or skipped, after the game is back.
func start(on_done := Callable()) -> void:
	if is_active():
		return
	_on_done = on_done
	host.save_game()
	_saved_game = host.game
	_saved_view_step = host.tower.rig.view_step()
	_saved_zoom = host.tower.rig.camera.size
	host.tutorial_overlay.visible = true
	# Skip sits where the gear is, so the gear makes way.
	host.gear_button.modulate.a = 0.0
	_load_step(0)


## Ends the tutorial early, as with Skip.
func skip() -> void:
	_end(false)


func _end(completed: bool) -> void:
	if not is_active():
		return
	step = -1
	_moving = false
	host.drag.clear()
	host.drag.allowed_origins = null
	host.tutorial_overlay.hide_hand()
	host.tutorial_overlay.visible = false
	host.gear_button.modulate.a = 1.0
	host.onboarding_done()
	_reset_view(_saved_view_step, _saved_zoom)
	host._use_game(_saved_game)
	_saved_game = null
	host._refresh()
	var done := _on_done
	_on_done = Callable()
	if done.is_valid():
		done.call()
	finished.emit(completed)


func _load_step(index: int) -> void:
	step = index
	found = false
	_moving = false
	_layout_key = []
	_reset_view(0, CameraRig.DEFAULT_ZOOM)
	host._use_game(Tutorial.make_game(host.config, index))
	host.drag.allowed_origins = Tutorial.allowed_origins(index, found)
	var overlay = host.tutorial_overlay
	# Over the last move's score pop, which was added after it.
	overlay.move_to_front()
	overlay.set_progress(index, Tutorial.step_count())
	_show_text()
	host._refresh()
	host._on_tray_refilled(host.game.tray)
	update()


func _reset_view(view_step: int, zoom: float) -> void:
	host.tower.rig.restore(view_step, zoom)
	host.swiper.mode = ViewMath.MODE_X
	host.swiper.depth = 0


func _show_text() -> void:
	var data := Tutorial.step(step)
	if data.hidden and found:
		host.tutorial_overlay.set_text(data.found_title, data.found_body)
	else:
		host.tutorial_overlay.set_text(data.title, data.body)


## The player turned or sliced the tower. On a hidden step that finds the
## target.
func view_used() -> void:
	if not is_active() or found or not Tutorial.step(step).hidden:
		return
	found = true
	host.drag.allowed_origins = Tutorial.allowed_origins(step, found)
	_show_text()
	update()


## The step's piece was placed; once it has played out, the next step comes
## up (or the tutorial ends after the last).
func placed() -> void:
	_moving = true
	host.tutorial_overlay.hide_hand()


func move_finished() -> void:
	if not is_active() or not _moving:
		return
	var at := step
	host.get_tree().create_timer(NEXT_STEP_SECONDS).timeout.connect(func():
		if step == at and _moving:
			advance())


## Goes on to the next step, or ends the tutorial after the last. Called a
## moment after the step's move has played out; the smoke test calls it
## straight away.
func advance() -> void:
	if not is_active():
		return
	if step + 1 < Tutorial.step_count():
		_load_step(step + 1)
	else:
		_end(true)


## Lays out the dim, card and hand for the current step. Cheap to call every
## frame: it only redraws when the step, the view or the layout changes.
func update() -> void:
	if not is_active():
		return
	var tower_rect: Rect2 = host.viewport_box.get_global_rect()
	var slot_rect: Rect2 = host.tray_slots[0].get_global_rect()
	var turning: bool = host.tower.rig.is_turning()
	var key := [step, found, _moving, turning, host.tower.rig.view_step(),
		tower_rect, slot_rect, host.swiper.depth, host.tutorial_overlay.size]
	if key == _layout_key:
		return
	_layout_key = key

	var overlay = host.tutorial_overlay
	var data := Tutorial.step(step)
	if data.hidden and not found:
		# Light only the view controls, and ring the one to press.
		var turn_right: Rect2 = host.rotate_buttons[1].get_global_rect()
		overlay.set_spotlight([
			[host.rotate_buttons[0].get_global_rect().grow(HOLE_PAD), 28 + HOLE_PAD],
			[turn_right.grow(HOLE_PAD), 28 + HOLE_PAD],
			[host.swiper_bar.get_global_rect().grow(HOLE_PAD), 28 + HOLE_PAD],
		], turn_right, 28)
		overlay.place_card_above(turn_right)
		overlay.show_hand_tap(turn_right.get_center() + Vector2(4, 10))
		return

	var holes := [
		[tower_rect, 0.0],
		[slot_rect.grow(HOLE_PAD), 20 + HOLE_PAD],
	]
	if data.hidden:
		# Found: keep the view controls lit so the player can look around.
		holes.append([host.swiper_bar.get_global_rect().grow(HOLE_PAD), 28 + HOLE_PAD])
	overlay.set_spotlight(holes)
	overlay.place_card_at_top()
	if _moving or turning:
		overlay.hide_hand()
	else:
		overlay.show_hand_drag(slot_rect.get_center(), target_finger())


## Where a finger lets go to drop the step's piece on its target: the
## piece floats DragController.LIFT above the finger.
func target_finger() -> Vector2:
	var data := Tutorial.step(step)
	var piece = host.game.tray[0] if host.game.tray[0] != null else host.config.piece_by_size(data.piece_size)
	var center := ViewMath.cells_center(piece.cells_at(data.target), host.config.grid_size)
	return host.viewport_box.get_global_rect().position + host.tower.project_point(center) \
		+ Vector2(0, DragController.LIFT)
