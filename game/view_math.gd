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
## and steps across from one side. Z cuts flat planes by layer and steps down
## from the top of the tower; it doesn't change when the tower rotates.
const MODE_X := 0
const MODE_Y := 1
const MODE_Z := 2


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


## Which core axis the swiper steps along: 0 for x, 1 for y, 2 for z (layers).
static func slice_axis(mode: int, step: int) -> int:
	if mode == MODE_Z:
		return 2
	var even := posmod(step, 2) == 0
	if mode == MODE_X:
		return 1 if even else 0
	return 0 if even else 1


static func slice_layer_count(mode: int, step: int, grid_size: Vector3i) -> int:
	return grid_size[slice_axis(mode, step)]


## The slice number the chip shows at `depth`, counting from 1. X and Y count
## from the front of the tower. Z counts from the floor, so the number matches
## the layer the player sees on top.
static func slice_number(mode: int, step: int, grid_size: Vector3i, depth: int) -> int:
	if mode == MODE_Z:
		return slice_layer_count(mode, step, grid_size) - depth
	return depth + 1


## `depth` kept inside the mode's range, 0 to one less than its layer count.
## Modes can have different layer counts (Z has 12, X and Y have 6), so clamp
## the depth again after the mode changes.
static func clamp_depth(mode: int, step: int, grid_size: Vector3i, depth: int) -> int:
	return clampi(depth, 0, slice_layer_count(mode, step, grid_size) - 1)


## 0 for the layer nearest the viewer along the swiper's axis, counting back.
## In Z mode the viewer is above the tower, so 0 is the top layer.
static func layer_from_viewer(c: Vector3i, mode: int, step: int, grid_size: Vector3i) -> int:
	var axis := slice_axis(mode, step)
	if axis == 2:
		return grid_size.z - 1 - c.z
	var toward: float = toward_camera(step).x if axis == 0 else toward_camera(step).y
	var coord: int = c.x if axis == 0 else c.y
	var count: int = grid_size.x if axis == 0 else grid_size.y
	return (count - 1 - coord) if toward > 0.0 else coord


## True if the swiper, cut `depth` layers deep, hides this cell. Depth 0 shows
## the whole tower.
static func is_sliced_away(c: Vector3i, mode: int, step: int, grid_size: Vector3i, depth: int) -> bool:
	return depth > 0 and layer_from_viewer(c, mode, step, grid_size) < depth


## Unit step along the swiper's axis, in core space, pointing toward the
## viewer: toward the camera for X and Y, straight up for Z.
static func slice_toward_viewer(mode: int, step: int) -> Vector3i:
	var axis := slice_axis(mode, step)
	var d := Vector3i.ZERO
	if axis == 2:
		d.z = 1
	else:
		var toward: float = toward_camera(step).x if axis == 0 else toward_camera(step).y
		d[axis] = 1 if toward > 0.0 else -1
	return d


## The swiper's cut at `depth`, as four core-space corners in order around
## it: the boundary between the layers cut away and the first layer still
## shown. At depth 0 it lies on the tower's outer face nearest the viewer.
static func slice_plane(mode: int, step: int, grid_size: Vector3i, depth: int) -> Array[Vector3i]:
	var axis := slice_axis(mode, step)
	var count: int = grid_size[axis]
	var k := count - depth if slice_toward_viewer(mode, step)[axis] > 0 else depth
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var out: Array[Vector3i] = []
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var p := Vector3i.ZERO
		p[axis] = k
		p[u] = o.x * grid_size[u]
		p[v] = o.y * grid_size[v]
		out.append(p)
	return out


## Projects a core-space point (x, y, h) to 2D, matching the 3D camera's view,
## in units of one cube. Screen y grows downward.
static func preview_point(p: Vector3, step: int) -> Vector2:
	var ground := Vector2(p.x, p.y)
	var pitch := deg_to_rad(PITCH_DEG)
	return Vector2(
		ground.dot(screen_right(step)),
		ground.dot(toward_camera(step)) * sin(pitch) - p.z * cos(pitch))


## How many steps each cleared cell is from the nearest placed cell, as a
## dictionary of cell -> int (Manhattan distance). The clear effect ripples
## out from the placed piece one step at a time. With nothing placed, every
## cell is 0 steps away.
static func ripple_steps(cleared: Array, placed: Array) -> Dictionary:
	var steps := {}
	for c in cleared:
		var best := 0
		if not placed.is_empty():
			best = 1 << 30
			for p in placed:
				var d: Vector3i = (c as Vector3i) - (p as Vector3i)
				best = mini(best, absi(d.x) + absi(d.y) + absi(d.z))
		steps[c] = best
	return steps


## Core-space corner (x, y, h) of the cell grid to world space. Cell c spans
## corners c to c + (1, 1, 1).
static func corner_to_world(p: Vector3i, grid_size: Vector3i) -> Vector3:
	return Vector3(p.x - grid_size.x * 0.5, p.z, p.y - grid_size.y * 0.5)


## The six face directions of a cube, in core space.
const FACE_DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## Faces of `cells` that don't touch another cell of the same set, as
## [cell, direction] pairs. Together they form the piece's outer shell.
static func exposed_faces(cells: Array) -> Array:
	var occupied := {}
	for c in cells:
		occupied[c] = true
	var faces: Array = []
	for c in cells:
		for d in FACE_DIRS:
			if not occupied.has((c as Vector3i) + d):
				faces.append([c, d])
	return faces


## The cube edges of `cells`, each listed once as [from, to] core corners.
## "outer" edges trace the piece's silhouette and creases: one or three of the
## four cells around the edge are in the set, or two that sit diagonally.
## "inner" edges split one flat face between two cells. Edges with all four
## cells around them are buried inside the piece and left out.
static func piece_edges(cells: Array) -> Dictionary:
	var occupied := {}
	for c in cells:
		occupied[c] = true
	var outer: Array = []
	var inner: Array = []
	var seen := {}
	# For each axis, the two axes it doesn't run along.
	var others := [[1, 2], [0, 2], [0, 1]]
	for c in cells:
		for axis in range(3):
			var u: int = others[axis][0]
			var v: int = others[axis][1]
			for du in range(2):
				for dv in range(2):
					var start: Vector3i = c
					start[u] += du
					start[v] += dv
					var key := [axis, start]
					if seen.has(key):
						continue
					seen[key] = true
					# The four cells around this edge, in order (-,-) (0,-) (-,0) (0,0).
					var around: Array[bool] = []
					for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
						var q := start
						q[u] += o.x
						q[v] += o.y
						around.append(occupied.has(q))
					var count := around.count(true)
					var end := start
					end[axis] += 1
					var diagonal := count == 2 and around[0] == around[3]
					if count == 1 or count == 3 or diagonal:
						outer.append([start, end])
					elif count == 2:
						inner.append([start, end])
	return {"outer": outer, "inner": inner}


## Grid ticks (#56): short marks on the tower's border, one per cell along
## the top rim and the base's lip and one per layer on each corner post.
## Every MAJOR_TICK_EVERY-th mark is a longer major tick.
const MAJOR_TICK_EVERY := 3
const TICK_LENGTH := 0.24
const MAJOR_TICK_LENGTH := 0.5
## Floor ticks lie on the base's lip, which is half a cube wide.
const FLOOR_TICK_MAX := 0.42
## Floor ticks sit just above the base, like the floor grid.
const FLOOR_TICK_LIFT := 0.005


## World-space line segments for the grid ticks, as consecutive endpoint
## pairs: {"minor": Array[Vector3], "major": Array[Vector3]}.
static func border_ticks(grid_size: Vector3i) -> Dictionary:
	var minor: Array[Vector3] = []
	var major: Array[Vector3] = []
	var hx := grid_size.x * 0.5
	var hz := grid_size.y * 0.5
	var top := float(grid_size.z)

	# Corner posts: at every layer, a mark into each of the two walls.
	for corner in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		var into_x := -signf(corner.x)
		var into_z := -signf(corner.y)
		for h in range(1, grid_size.z):
			var is_major := h % MAJOR_TICK_EVERY == 0
			var out: Array[Vector3] = major if is_major else minor
			var length := MAJOR_TICK_LENGTH if is_major else TICK_LENGTH
			var at := Vector3(corner.x, h, corner.y)
			out.append(at)
			out.append(at + Vector3(into_x * length, 0, 0))
			out.append(at)
			out.append(at + Vector3(0, 0, into_z * length))

	# Top rim and base lip: a mark at every cell boundary along each edge.
	# The rim's hang down the wall; the lip's point out across the base.
	for axis in [0, 1]:
		var cells := grid_size.x if axis == 0 else grid_size.y
		var half := hx if axis == 0 else hz
		var across := hz if axis == 0 else hx
		for i in range(1, cells):
			var is_major := i % MAJOR_TICK_EVERY == 0
			var out: Array[Vector3] = major if is_major else minor
			var length := MAJOR_TICK_LENGTH if is_major else TICK_LENGTH
			var along := -half + i
			for side in [-1.0, 1.0]:
				var rim := _edge_point(axis, along, side * across, top)
				out.append(rim)
				out.append(rim - Vector3(0, length, 0))
				var lip := _edge_point(axis, along, side * across, FLOOR_TICK_LIFT)
				var outward := _edge_point(axis, 0.0, side * minf(length, FLOOR_TICK_MAX), 0.0)
				out.append(lip)
				out.append(lip + outward)
	return {"minor": minor, "major": major}


## A point on the footprint's edge: `along` runs on world x (axis 0) or z
## (axis 1), `across` is the other horizontal coordinate.
static func _edge_point(axis: int, along: float, across: float, height: float) -> Vector3:
	if axis == 0:
		return Vector3(along, height, across)
	return Vector3(across, height, along)


# --- Tower crumble (#132) ---

## Seconds after the shake that each cube breaks when the tower crumbles:
## the top layer goes first and each layer below follows `layer_seconds`
## later. `jitter` (one value in 0..1 per cube, in the same order as
## `cells`) staggers cubes within a layer by up to `jitter_seconds`.
static func crumble_starts(cells: Array, jitter: Array, layer_seconds: float, jitter_seconds: float) -> Array[float]:
	var top := 0
	for c in cells:
		top = maxi(top, (c as Vector3i).z)
	var out: Array[float] = []
	for i in range(cells.size()):
		var c: Vector3i = cells[i]
		out.append((top - c.z) * layer_seconds + float(jitter[i]) * jitter_seconds)
	return out


## Height of the rubble pile's peak for `cube_count` broken cubes, each
## leaving `fill` cubic units of rubble, heaped in a cone of `radius`.
## Clamped to `low`..`high` so a few cubes still make a visible heap and a
## full tower doesn't bury the camera.
static func rubble_peak(cube_count: int, radius: float, fill: float, low: float, high: float) -> float:
	if cube_count <= 0 or radius <= 0.0:
		return 0.0
	var volume := cube_count * fill
	return clampf(3.0 * volume / (PI * radius * radius), low, high)


## Height of a cone-shaped pile of `peak` and `radius` at distance `r` from
## its middle, with a rounded top.
static func rubble_height(r: float, peak: float, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	var t := clampf(r / radius, 0.0, 1.0)
	return peak * (1.0 - smoothstep(0.0, 1.0, t))


## Seconds for something at height `drop` above where it lands, thrown up at
## `up_speed`, to come down under `gravity`. `drop` may be negative (landing
## above the start), in which case it must be thrown up hard enough to get
## there; returns the time it reaches its peak if it can't.
static func fall_seconds(drop: float, up_speed: float, gravity: float) -> float:
	var disc := up_speed * up_speed + 2.0 * gravity * drop
	if disc < 0.0:
		return up_speed / gravity
	return (up_speed + sqrt(disc)) / gravity
