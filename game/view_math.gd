extends RefCounted
## Math shared by the 3D tower view and the 2D piece previews.
##
## Core cells are Vector3i(x, y, h). In Godot's Y-up world a cell's center is
## (x, h, y), shifted so the footprint is centered on the origin.
##
## The camera looks at the tower from one of four corners, 30° above the
## horizon. `step` counts quarter turns from the starting corner (0–3; other
## values wrap). At step 0 the camera sits at the corner with the highest x
## and y, so that corner is nearest the player.

const PITCH_DEG := 30.0
const BASE_YAW_DEG := 45.0

## Swiper modes. X cuts planes that run left-right across the screen and steps
## from the front of the tower to the back. Y cuts planes that run front-back
## and steps across from one side.
const MODE_X := 0
const MODE_Y := 1


static func to_world(c: Vector3i, grid_size: Vector3i) -> Vector3:
	return Vector3(
		c.x - (grid_size.x - 1) * 0.5,
		c.z + 0.5,
		c.y - (grid_size.y - 1) * 0.5)


static func cells_center(cells: Array, grid_size: Vector3i) -> Vector3:
	var sum := Vector3.ZERO
	for c in cells:
		sum += to_world(c, grid_size)
	return sum / maxi(cells.size(), 1)


static func yaw_for_step(step: int) -> float:
	return deg_to_rad(BASE_YAW_DEG + 90.0 * step)


## Unit vector on the ground, in core (x, y), pointing from the tower toward
## the camera. Cells further along it are nearer the player.
static func toward_camera(step: int) -> Vector2:
	var yaw := yaw_for_step(step)
	return Vector2(sin(yaw), cos(yaw))


## Unit vector on the ground, in core (x, y), pointing to the screen's right.
static func screen_right(step: int) -> Vector2:
	var yaw := yaw_for_step(step)
	return Vector2(cos(yaw), -sin(yaw))


## Which core axis the swiper steps along: 0 for x, 1 for y.
static func slice_axis(mode: int, step: int) -> int:
	var even := posmod(step, 2) == 0
	if mode == MODE_X:
		return 1 if even else 0
	return 0 if even else 1


static func slice_layer_count(mode: int, step: int, grid_size: Vector3i) -> int:
	return grid_size.x if slice_axis(mode, step) == 0 else grid_size.y


## 0 for the layer nearest the viewer along the swiper's axis, counting back.
static func layer_from_viewer(c: Vector3i, mode: int, step: int, grid_size: Vector3i) -> int:
	var axis := slice_axis(mode, step)
	var toward: float = toward_camera(step).x if axis == 0 else toward_camera(step).y
	var coord: int = c.x if axis == 0 else c.y
	var count: int = grid_size.x if axis == 0 else grid_size.y
	return (count - 1 - coord) if toward > 0.0 else coord


## True if the swiper, cut `depth` layers deep, hides this cell. Depth 0 shows
## the whole tower.
static func is_sliced_away(c: Vector3i, mode: int, step: int, grid_size: Vector3i, depth: int) -> bool:
	return depth > 0 and layer_from_viewer(c, mode, step, grid_size) < depth


## Projects a core-space point (x, y, h) to 2D, matching the 3D camera's view,
## in units of one cube. Screen y grows downward.
static func preview_point(p: Vector3, step: int) -> Vector2:
	var ground := Vector2(p.x, p.y)
	var pitch := deg_to_rad(PITCH_DEG)
	return Vector2(
		ground.dot(screen_right(step)),
		ground.dot(toward_camera(step)) * sin(pitch) - p.z * cos(pitch))
