extends RefCounted
## Dragging a piece from the tray onto the tower: the floating preview, snapping
## to the nearest legal spot and which blocks to fade so they don't hide the ghost.
##
## The game screen routes input here and does the placing itself, when
## `dropped` fires. Reads the screen's game, tower and widgets through `host`,
## since the game is replaced on every new game.

const Rules := preload("res://core/rules.gd")
const ViewMath := preload("res://game/view_math.gd")

## A dragged piece floats this far above the finger so the finger doesn't
## cover it.
const LIFT := 64.0
## How close, in points, the finger must be to a legal spot for the ghost to
## snap to it.
const SNAP_RADIUS := 72.0
## Screen distance, in cubes, within which a nearer block counts as hiding
## the ghost.
const OCCLUDE_RADIUS := 1.1

## The ghost moved, appeared or went away, so the blocks need redrawing.
signal target_changed
## The piece was let go over a legal spot.
signal dropped(index: int, origin: Vector3i)

## The game screen (game/main.gd).
var host
var _index := -1
var _has_target := false
var _target := Vector3i.ZERO


func _init(screen) -> void:
	host = screen


func is_dragging() -> bool:
	return _index >= 0


func start(index: int, finger: Vector2) -> void:
	_index = index
	host.drag_preview.set_piece(host.game.tray[index], host.tower.rig.view_step())
	host.drag_preview.visible = true
	host.tray_previews[index].modulate.a = 0.25
	update(finger)


func update(finger: Vector2) -> void:
	var preview = host.drag_preview
	var lifted := finger - Vector2(0, LIFT)
	preview.position = lifted - preview.size * 0.5

	var rect: Rect2 = host.viewport_box.get_global_rect()
	var over_tower := rect.has_point(lifted)
	var found := false
	var origin := Vector3i.ZERO
	if over_tower:
		var snap: Array = _find_snap(host.game.tray[_index], lifted - rect.position)
		found = snap[0]
		origin = snap[1]

	if found != _has_target or origin != _target:
		_has_target = found
		_target = origin
		if found:
			host.tower.show_ghost(host.game.tray[_index].cells_at(origin))
		else:
			host.tower.hide_ghost()
		target_changed.emit()

	preview.modulate.a = 0.55 if found else 1.0
	preview.queue_redraw()


## Lets go at `finger`. Emits `dropped` if the piece was over a legal spot.
func end(finger: Vector2) -> void:
	update(finger)
	var index := _index
	var place := _has_target
	var origin := _target
	clear()
	if place:
		dropped.emit(index, origin)


## Drops the piece back in the tray without placing it.
func clear() -> void:
	if _index >= 0 and _index < host.tray_previews.size():
		host.tray_previews[_index].modulate.a = 1.0
	_index = -1
	_has_target = false
	if host.drag_preview != null:
		host.drag_preview.visible = false
	if host.tower != null:
		host.tower.hide_ghost()


## Adds to `faded` the cells of `filled` that sit in front of the ghost and
## would hide it. Does nothing unless the piece is snapped to a spot.
func fade_occluders(faded: Dictionary, filled: Array) -> void:
	if _index < 0 or not _has_target:
		return
	var tower = host.tower
	var ghost: Array = host.game.tray[_index].cells_at(_target)
	var radius: float = tower.cube_pixels() * OCCLUDE_RADIUS
	var ghost_points: Array = []
	var ghost_depths: Array = []
	for q in ghost:
		ghost_points.append(tower.project_cell(q))
		ghost_depths.append(tower.depth_of(q))
	for c in filled:
		if faded.has(c):
			continue
		var p: Vector2 = tower.project_cell(c)
		var depth: float = tower.depth_of(c)
		for i in range(ghost.size()):
			if depth < ghost_depths[i] and p.distance_to(ghost_points[i]) < radius:
				faded[c] = true
				break


## Nearest legal origin whose piece center projects within SNAP_RADIUS of
## `point` (in the tower viewport). Returns [found: bool, origin: Vector3i].
func _find_snap(piece, point: Vector2) -> Array:
	var best_distance := SNAP_RADIUS
	var best := Vector3i.ZERO
	var found := false
	for origin in Rules.legal_positions(host.game.grid, piece):
		var center := ViewMath.cells_center(piece.cells_at(origin), host.config.grid_size)
		var d: float = host.tower.project_point(center).distance_to(point)
		if d < best_distance:
			best_distance = d
			best = origin
			found = true
	return [found, best]
