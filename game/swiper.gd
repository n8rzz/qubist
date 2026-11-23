extends RefCounted
## The swiper's state: which axis it cuts along, how deep, and the sweep
## plane's fade.
##
## No nodes or drawing here. The game screen asks it which cells are faded,
## what the slice chip says and how strong the sweep plane is, and draws that.
## `step` is the camera's view step (ViewMath), passed in because X and Y
## slices follow the tower as it turns.

const ViewMath := preload("res://game/view_math.gd")

## Button and chip labels, indexed by ViewMath mode.
const AXIS_NAMES := ["X", "Y", "Z"]

## Sweep plane (#51): shown while the swiper moves, held briefly after it
## stops, then faded out.
const SWEEP_FADE_IN_SECONDS := 0.06
const SWEEP_HOLD_SECONDS := 0.18
const SWEEP_FADE_OUT_SECONDS := 0.45

var grid_size: Vector3i
var mode := ViewMath.MODE_X
## Layers cut away, counted from the viewer. 0 shows the whole tower.
var depth := 0

## True while a finger is on the swiper's slider.
var _sweeping := false
## Seconds left before the sweep plane starts to fade.
var _sweep_hold := 0.0
var _sweep_alpha := 0.0


func _init(size: Vector3i) -> void:
	grid_size = size


func is_sliced() -> bool:
	return depth > 0


func layer_count(step: int) -> int:
	return ViewMath.slice_layer_count(mode, step, grid_size)


## Keeps the depth inside the current mode's range (ViewMath.clamp_depth).
## Call this after the mode changes.
func fit(step: int) -> void:
	depth = ViewMath.clamp_depth(mode, step, grid_size, depth)


func chip_text(step: int) -> String:
	var number := ViewMath.slice_number(mode, step, grid_size, depth)
	return "Slice %d of %d · %s" % [number, layer_count(step), AXIS_NAMES[mode]]


## The cells of `cells` the swiper has cut away, as a set.
func faded_cells(cells: Array, step: int) -> Dictionary:
	var faded := {}
	for c in cells:
		if ViewMath.is_sliced_away(c, mode, step, grid_size, depth):
			faded[c] = true
	return faded


## Sorts the shown cells of `cells` (those not in `faded`) by where they sit
## against the cut. Returns `cap`, the cells on the cut that light up under the
## sweep plane, and `behind`, a set of the cells behind it, drawn lighter
## while sliced (#85).
func shade(cells: Array, faded: Dictionary, step: int) -> Dictionary:
	var behind := {}
	var cap: Array = []
	for c in cells:
		if faded.has(c):
			continue
		var layer := ViewMath.layer_from_viewer(c, mode, step, grid_size)
		if layer == depth:
			cap.append(c)
		elif depth > 0 and layer > depth:
			behind[c] = true
	return {"cap": cap, "behind": behind}


func plane(step: int) -> Array:
	return ViewMath.slice_plane(mode, step, grid_size, depth)


func toward_viewer(step: int) -> Vector3i:
	return ViewMath.slice_toward_viewer(mode, step)


# --- Sweep plane ---

## Marks the swiper as just moved, so the sweep plane shows and then fades.
func bump() -> void:
	_sweep_hold = SWEEP_HOLD_SECONDS


func begin_sweep() -> void:
	_sweeping = true


func end_sweep() -> void:
	_sweeping = false
	bump()


## Moves the sweep plane's fade on by `delta` seconds. Returns true if its
## strength changed, so the caller knows to redraw. While `turning`, the
## cut's axis can swap, so the plane stays hidden.
func update_sweep(delta: float, turning: bool) -> bool:
	_sweep_hold = maxf(_sweep_hold - delta, 0.0)
	var target := 1.0 if _sweeping or _sweep_hold > 0.0 else 0.0
	if turning:
		target = 0.0
		_sweep_hold = 0.0
	var seconds := SWEEP_FADE_IN_SECONDS if target > _sweep_alpha else SWEEP_FADE_OUT_SECONDS
	var alpha := move_toward(_sweep_alpha, target, delta / seconds)
	if alpha == _sweep_alpha:
		return false
	_sweep_alpha = alpha
	return true


## The sweep plane's strength, eased, from 0 (hidden) to 1.
func sweep_alpha() -> float:
	return ease(_sweep_alpha, 0.6)
