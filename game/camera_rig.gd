extends Node3D
## Orthographic camera orbiting the tower in 90° steps, with zoom.
##
## Only the view turns; the grid and piece orientations never change.

signal view_changed(step: int)

const ViewMath := preload("res://game/view_math.gd")

const ROTATE_SECONDS := 0.25
const DEFAULT_ZOOM := 17.0

var zoom_min := 9.0
var zoom_max := 24.0
var camera := Camera3D.new()

## Quarter turns taken so far. Not wrapped, so tweens always take the short way.
var _turns := 0
var _tween: Tween


func _init() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = DEFAULT_ZOOM
	camera.near = 0.1
	camera.far = 200.0
	camera.position = Vector3(0, 0, 50)
	add_child(camera)
	rotation = Vector3(deg_to_rad(-ViewMath.PITCH_DEG), ViewMath.yaw_for_step(0), 0)


func _ready() -> void:
	camera.current = true


## The view's corner, 0–3, as used by ViewMath.
func view_step() -> int:
	return posmod(_turns, 4)


## Turns the view by `quarter_turns` (positive turns the tower to the right).
func turn(quarter_turns: int) -> void:
	_turns += quarter_turns
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", ViewMath.yaw_for_step(_turns), ROTATE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(func(): view_changed.emit(view_step()))


func is_turning() -> bool:
	return _tween != null and _tween.is_running()


## factor > 1 zooms in.
func zoom_by(factor: float) -> void:
	if factor <= 0.0:
		return
	camera.size = clampf(camera.size / factor, zoom_min, zoom_max)


## Jumps straight to a view corner and zoom, as when resuming a saved game.
func restore(step: int, zoom: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_turns = posmod(step, 4)
	rotation.y = ViewMath.yaw_for_step(_turns)
	camera.size = clampf(zoom, zoom_min, zoom_max)


func reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_turns = 0
	rotation.y = ViewMath.yaw_for_step(0)
	camera.size = DEFAULT_ZOOM
