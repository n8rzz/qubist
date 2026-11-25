extends "res://game/island_art.gd"
## Home's tower animation (#186): when there's no game to continue, the
## island builds a tower from the real pieces, the game-over crumble knocks
## it down, the rubble fades, and it starts again with new pieces.
##
## Each piece shows as a green ghost where it will go, then drops into it the
## way a placed piece does in a game. The crumble follows the tower's
## (#132): the tower shakes while its cubes darken and crack, then breaks
## from the top layer down into chips that fall onto a heap.
##
## With `still` set (Reduce Motion), or after show_cells(), it draws a fixed
## stack like the plain island art.

const Config := preload("res://core/config.gd")
const ViewMath := preload("res://game/view_math.gd")

# --- Building ---
## Time before the first ghost shows.
const START_DELAY := 0.5
## How long a ghost shows before its piece drops, and how fast it fades in.
const GHOST_SECONDS := 0.5
const GHOST_FADE_SECONDS := 0.12
## The ghost's opacity pulses down by this much, this many radians a second.
const GHOST_PULSE := 0.25
const GHOST_PULSE_SPEED := 14.0
## The drop into the ghost, as in the tower view: from this many layers up.
const DROP_SECONDS := 0.1
const DROP_LAYERS := 0.6
## Time between one piece landing and the next ghost.
const PIECE_GAP := 0.3
## The tower stops growing at whichever of these it reaches first.
const MAX_PIECES := 13
const MAX_CUBES := 46
const MAX_LAYERS := 6
## Spots tried for each piece; the lowest, most central one wins.
const PLACE_TRIES := 10
## A dealt piece is skipped after this many draws that don't fit.
const MAX_DRAWS := 40

# --- Crumbling ---
## The built tower stands this long before it starts to shake.
const HOLD_SECONDS := 0.7
const SHAKE_SECONDS := 0.8
const LAYER_SECONDS := 0.07
const JITTER_SECONDS := 0.08
## A cube swells this much over its last moment before it breaks.
const CRACK_SECONDS := 0.08
const CRACK_SWELL := 0.09
## How far cracking cubes darken toward CRACK_COLOR.
const DARKEN := 0.35
const CRACK_COLOR := Color("#7A6F61")
const CRACK_LINE := Color("#5E554A")
const CRACKS_PER_CUBE := 2
## The sway and rattle of the shaking tower, in design units, and how long
## the shake takes to ramp up and down.
const SWAY := 1.6
const SWAY_HZ := 3.2
const RATTLE := 0.6
const SHAKE_RAMP := 0.4
const CHIPS_PER_CUBE := 4
const CHIP_GRAVITY := 16.0
## The rubble heaps in a cone this many cells across from the floor's middle.
const HEAP_RADIUS := 2.7
const HEAP_FILL := 0.12
const HEAP_MIN_PEAK := 0.35
const HEAP_MAX_PEAK := 1.4
## How far each chip moves from where its cube stood toward its spot on the
## heap.
const SCATTER := 0.7
## Chip sizes in cells, and how many design units that is across.
const CHIP_MIN := 0.26
const CHIP_MAX := 0.46
const CHIP_UNITS := 13.0
const CHIP_POINTS := 5
const DUST_PER_CUBE := 2
const DUST_SECONDS := 0.7
const DUST := Color("#D9D6CC")

# --- Resetting ---
## The rubble rests this long, fades out, then the next build starts after a
## pause.
const REST_SECONDS := 1.3
const FADE_SECONDS := 0.6
const PAUSE_SECONDS := 0.4

const GHOST_FILL := Color(64 / 255.0, 201 / 255.0, 135 / 255.0, 0.35)
const GHOST_LINE := Color("#2FAE72")

enum Phase { BUILDING, HOLDING, CRUMBLING, RESETTING }

## Reduce Motion: show the fixed stack instead of the animation.
var still := false
## Pieces to deal from (Piece objects, one per orientation, with weights).
## Loaded from config/pieces.json if left empty.
var pieces: Array = []
## Seconds into the current loop.
var time := 0.0
## The current loop, from plan_loop().
var plan: Dictionary = {}

var _animating := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	super()
	set_process(false)


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(_animating and is_visible_in_tree())


## Starts the build-and-crumble loop from the beginning, or shows `fallback`
## standing still when `still` is set.
func play(fallback: Array) -> void:
	if still:
		show_cells(fallback)
		return
	if pieces.is_empty():
		pieces = Config.new().pieces
	_animating = true
	_rng.randomize()
	_start_loop()
	set_process(is_visible_in_tree())


## Stops the loop and draws `next` standing still.
func show_cells(next: Array) -> void:
	_animating = false
	set_process(false)
	set_cells(next)


func is_animating() -> bool:
	return _animating


## Moves the loop on by `delta` seconds, starting a new one when it ends.
func advance(delta: float) -> void:
	if not _animating:
		return
	time += delta
	if time >= plan.loop_end:
		_start_loop()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _start_loop() -> void:
	time = 0.0
	plan = plan_loop(pieces, _rng)
	queue_redraw()


func phase() -> Phase:
	return phase_at(plan, time)


static func phase_at(loop: Dictionary, t: float) -> Phase:
	if t < loop.build_end:
		return Phase.BUILDING
	if t < loop.crumble_at:
		return Phase.HOLDING
	if t < loop.settled:
		return Phase.CRUMBLING
	return Phase.RESETTING


# --- Planning ---

## One loop: the pieces to build with and when, then the crumble.
static func plan_loop(deal_from: Array, rng: RandomNumberGenerator) -> Dictionary:
	var loop := plan_build(deal_from, rng)
	loop.merge(plan_crumble(loop.cells, loop.build_end, rng))
	return loop


## Deals pieces onto an empty floor, each resting on what's below it, until
## the tower reaches MAX_PIECES, MAX_CUBES or MAX_LAYERS. Returns `placements`
## ({cells, start, end}, in order), every placed `cells` in that order, and
## `build_end`, when the last piece has landed and its gap has passed.
static func plan_build(deal_from: Array, rng: RandomNumberGenerator) -> Dictionary:
	var heights := {}
	var placements: Array = []
	var all_cells: Array[Vector3i] = []
	var t := START_DELAY
	var total_weight := 0.0
	for p in deal_from:
		total_weight += p.weight
	for draw in range(MAX_DRAWS):
		if placements.size() >= MAX_PIECES or all_cells.size() >= MAX_CUBES:
			break
		var piece = _pick(deal_from, total_weight, rng)
		if piece == null:
			break
		var size: Vector3i = piece.size
		if size.x > GRID.x or size.y > GRID.y or size.z > MAX_LAYERS:
			continue
		var best := Vector3i(-1, -1, -1)
		var best_score := INF
		for i in range(PLACE_TRIES):
			var ox := rng.randi_range(0, GRID.x - size.x)
			var oy := rng.randi_range(0, GRID.y - size.y)
			var base := 0
			for c: Vector3i in piece.cells:
				base = maxi(base, int(heights.get(Vector2i(ox + c.x, oy + c.y), 0)) - c.z)
			var off_center := absf(ox + size.x * 0.5 - GRID.x * 0.5) + absf(oy + size.y * 0.5 - GRID.y * 0.5)
			var score := base * 3.0 + off_center * 0.6 + rng.randf() * 0.5
			if score < best_score:
				best_score = score
				best = Vector3i(ox, oy, base)
		if best.z + size.z > MAX_LAYERS:
			continue
		var cells: Array[Vector3i] = piece.cells_at(best)
		for c in cells:
			var column := Vector2i(c.x, c.y)
			heights[column] = maxi(int(heights.get(column, 0)), c.z + 1)
		var end := t + GHOST_SECONDS + DROP_SECONDS
		placements.append({"cells": cells, "start": t, "end": end})
		all_cells.append_array(cells)
		t = end + PIECE_GAP
	return {"placements": placements, "cells": all_cells, "build_end": t}


static func _pick(deal_from: Array, total_weight: float, rng: RandomNumberGenerator):
	if deal_from.is_empty():
		return null
	var w := rng.randf() * total_weight
	for p in deal_from:
		w -= p.weight
		if w <= 0.0:
			return p
	return deal_from[-1]


## The crumble of `cells` once the build ends at `build_end`: when each cube
## breaks (`breaks`, in the order of `cells`), its `cracks`, the `chips` and
## `dust` it leaves, and when the rubble has `settled`, starts to fade
## (`fade_at`) and the loop ends (`loop_end`).
static func plan_crumble(cells: Array[Vector3i], build_end: float, rng: RandomNumberGenerator) -> Dictionary:
	var crumble_at := build_end + HOLD_SECONDS
	var shake_end := crumble_at + SHAKE_SECONDS
	var jitter: Array = []
	for c in cells:
		jitter.append(rng.randf())
	var starts := ViewMath.crumble_starts(cells, jitter, LAYER_SECONDS, JITTER_SECONDS)
	var peak := ViewMath.rubble_peak(cells.size(), HEAP_RADIUS, HEAP_FILL, HEAP_MIN_PEAK, HEAP_MAX_PEAK)
	var middle := Vector2(GRID.x, GRID.y) * 0.5
	var breaks: Array[float] = []
	var cracks: Array = []
	var chips: Array = []
	var dust: Array = []
	var settled := shake_end
	for i in range(cells.size()):
		var c: Vector3i = cells[i]
		var brk := shake_end + starts[i]
		breaks.append(brk)
		var mine: Array = []
		for k in range(CRACKS_PER_CUBE):
			var points := PackedVector2Array()
			var u := rng.randf_range(0.2, 0.8)
			for s in range(4):
				points.append(Vector2(clampf(u, 0.05, 0.95), s / 3.0))
				u += rng.randf_range(-0.175, 0.175)
			mine.append({"right": rng.randf() < 0.5, "points": points})
		cracks.append(mine)
		var broken := brk + CRACK_SECONDS
		for k in range(CHIPS_PER_CUBE):
			var start := Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5) \
				+ Vector3(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28))
			var spot := middle + Vector2.from_angle(rng.randf() * TAU) * HEAP_RADIUS * sqrt(rng.randf())
			var land := Vector2(start.x, start.y).lerp(spot, SCATTER)
			if land.distance_to(middle) > HEAP_RADIUS:
				land = middle + (land - middle).normalized() * HEAP_RADIUS
			var size := rng.randf_range(CHIP_MIN, CHIP_MAX)
			var rest_h := ViewMath.rubble_height(land.distance_to(middle), peak, HEAP_RADIUS) \
				* rng.randf_range(0.7, 1.0) + size * 0.4
			var up := rng.randf_range(0.5, 2.5)
			var fall := ViewMath.fall_seconds(start.z - rest_h, up, CHIP_GRAVITY)
			var outline: Array = []
			for p in range(CHIP_POINTS):
				outline.append(Vector2(p * TAU / CHIP_POINTS + rng.randf() * 0.5,
					size * CHIP_UNITS * rng.randf_range(0.75, 1.15)))
			chips.append({
				"start_time": broken,
				"start": start,
				"rest": Vector3(land.x, land.y, rest_h),
				"up": up,
				"fall": fall,
				"spin": rng.randf_range(3.0, 8.0) * (1.0 if rng.randf() < 0.5 else -1.0),
				"outline": outline,
				"radius": size * CHIP_UNITS,
				"color": [CUBE_RIGHT, CUBE_LEFT, CUBE_TOP][rng.randi_range(0, 2)],
			})
			settled = maxf(settled, broken + fall)
		for k in range(DUST_PER_CUBE):
			dust.append({
				"start_time": broken,
				"at": Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)
					+ Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2)),
				"rise": rng.randf_range(0.2, 0.6),
				"size": rng.randf_range(7.0, 12.0),
			})
		settled = maxf(settled, broken + DUST_SECONDS)
	var fade_at := settled + REST_SECONDS
	return {
		"crumble_at": crumble_at,
		"breaks": breaks,
		"cracks": cracks,
		"chips": chips,
		"dust": dust,
		"settled": settled,
		"fade_at": fade_at,
		"loop_end": fade_at + FADE_SECONDS + PAUSE_SECONDS,
	}


## Where a chip is at loop time `t`: thrown up, then falling under gravity
## until it lands on its rest spot.
static func chip_position(chip: Dictionary, t: float) -> Vector3:
	var u := clampf(t - chip.start_time, 0.0, chip.fall)
	var k: float = u / chip.fall if chip.fall > 0.0 else 1.0
	var start: Vector3 = chip.start
	var rest: Vector3 = chip.rest
	var h := maxf(rest.z, start.z + chip.up * u - 0.5 * CHIP_GRAVITY * u * u)
	if k >= 1.0:
		h = rest.z
	return Vector3(lerpf(start.x, rest.x, k), lerpf(start.y, rest.y, k), h)


# --- Drawing ---

func _draw() -> void:
	if not _animating or plan.is_empty():
		super()
		return
	var s := minf(size.x / VIEW.size.x, size.y / VIEW.size.y)
	if s <= 0.0:
		return
	draw_set_transform(size * 0.5 - VIEW.get_center() * s, 0.0, Vector2(s, s))
	_draw_island()
	_draw_outline_back()

	# Everything on the floor, as [sort key, callable], drawn back to front.
	var items: Array = []
	var t := time
	var crumbling: bool = t >= plan.crumble_at
	var shake := _shake_offset(t) if crumbling else Vector2.ZERO
	var index := 0
	for placement in plan.placements:
		var local: float = t - placement.start
		for c: Vector3i in placement.cells:
			var i := index
			index += 1
			if local < 0.0:
				continue
			var key := float(c.x + c.y + c.z)
			if crumbling:
				var brk: float = plan.breaks[i]
				if t >= brk + CRACK_SECONDS:
					continue
				var crack := clampf((t - plan.crumble_at) / SHAKE_SECONDS, 0.0, 1.0)
				var swell := 1.0 + CRACK_SWELL * clampf((t - brk) / CRACK_SECONDS, 0.0, 1.0)
				var at := Vector3(c.x + shake.x / (2.0 * CELL_X), c.y - shake.x / (2.0 * CELL_X), c.z - shake.y / LAYER)
				items.append([key, _draw_block.bind(at, swell, 1.0, crack, plan.cracks[i])])
			elif t >= placement.end:
				items.append([key, _draw_block.bind(Vector3(c), 1.0, 1.0, 0.0, [])])
			elif local < GHOST_SECONDS:
				var fade_in := clampf(local / GHOST_FADE_SECONDS, 0.0, 1.0)
				var pulse := 1.0 - GHOST_PULSE * (0.5 - 0.5 * sin(local * GHOST_PULSE_SPEED))
				items.append([key - 0.01, _draw_ghost.bind(c, fade_in * pulse)])
			else:
				var v := clampf((local - GHOST_SECONDS) / DROP_SECONDS, 0.0, 1.0)
				items.append([key - 0.01, _draw_ghost.bind(c, 1.0 - v)])
				var lift := DROP_LAYERS * pow(1.0 - v, 2.5)
				items.append([key + lift + 0.001,
					_draw_block.bind(Vector3(c) + Vector3(0, 0, lift), 1.0, clampf(v * 4.0, 0.0, 1.0), 0.0, [])])
	var fade := clampf(1.0 - (t - plan.fade_at) / FADE_SECONDS, 0.0, 1.0)
	if fade > 0.0:
		for chip in plan.chips:
			if t < chip.start_time:
				continue
			var at := chip_position(chip, t)
			var turn: float = chip.spin * minf(t - chip.start_time, chip.fall)
			items.append([at.x + at.y + at.z - 0.5, _draw_chip.bind(chip, at, turn, fade)])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item in items:
		(item[1] as Callable).call()
	for puff in plan.dust:
		var u: float = (t - puff.start_time) / DUST_SECONDS
		if u < 0.0 or u > 1.0:
			continue
		var at: Vector3 = puff.at
		draw_circle(iso(at.x, at.y, at.z + puff.rise * u), puff.size * (1.0 + 0.6 * u),
			Color(DUST, 0.55 * (1.0 - u)))
	_draw_outline_front()
	draw_tree()
	draw_set_transform(Vector2.ZERO)


## The shaking tower's offset in design units: a sway plus a faster rattle,
## ramping in at the start of the crumble and out as the rubble settles.
func _shake_offset(t: float) -> Vector2:
	if t >= plan.settled:
		return Vector2.ZERO
	var since: float = t - plan.crumble_at
	var ramp := clampf(since / SHAKE_RAMP, 0.0, 1.0) * clampf((plan.settled - t) / SHAKE_RAMP, 0.0, 1.0)
	return Vector2(sin(since * TAU * SWAY_HZ) * SWAY + sin(since * 71.0) * RATTLE,
		sin(since * 53.0) * RATTLE * 0.75) * ramp


## A cube's top, left and right faces at grid position `at`, scaled by `k`
## about its middle, each as 4 screen points.
static func _faces(at: Vector3, k: float) -> Array:
	var mid := at + Vector3.ONE * 0.5
	var p := func(dx: float, dy: float, dh: float) -> Vector2:
		var q := mid + (Vector3(dx, dy, dh) - Vector3.ONE * 0.5) * k
		return iso(q.x, q.y, q.z)
	return [
		[p.call(0, 0, 1), p.call(1, 0, 1), p.call(1, 1, 1), p.call(0, 1, 1)],
		[p.call(0, 1, 1), p.call(1, 1, 1), p.call(1, 1, 0), p.call(0, 1, 0)],
		[p.call(1, 1, 1), p.call(1, 0, 1), p.call(1, 0, 0), p.call(1, 1, 0)],
	]


## A stone cube at `at`, scaled by `k`, faded by `alpha`, darkened and
## cracked by `crack` (0 to 1) along `cracks`.
func _draw_block(at: Vector3, k: float, alpha: float, crack: float, cracks: Array) -> void:
	var faces := _faces(at, k)
	var d := crack * DARKEN
	var snow_top := SkyView.snowy_top(CUBE_TOP)
	var snow_inset := SkyView.snowy_top_inset(CUBE_TOP_INSET)
	_face(faces[0], snow_top.lerp(CRACK_COLOR, d), snow_inset.lerp(CRACK_COLOR, d), alpha)
	_face(faces[1], CUBE_LEFT.lerp(CRACK_COLOR, d), CUBE_LEFT_INSET.lerp(CRACK_COLOR, d), alpha)
	_face(faces[2], CUBE_RIGHT.lerp(CRACK_COLOR, d), CUBE_RIGHT_INSET.lerp(CRACK_COLOR, d), alpha)
	if crack <= 0.0:
		return
	for line in cracks:
		# Points run across the face (x) and down it (y).
		var q: Array = faces[2] if line.right else faces[1]
		var path := PackedVector2Array()
		for uv: Vector2 in line.points:
			var top: Vector2 = (q[0] as Vector2).lerp(q[1], uv.x)
			var bottom: Vector2 = (q[3] as Vector2).lerp(q[2], uv.x)
			path.append(top.lerp(bottom, uv.y))
		draw_polyline(path, Color(CRACK_LINE, crack * alpha), 0.8, true)


func _draw_ghost(c: Vector3i, alpha: float) -> void:
	for corners in _faces(Vector3(c), 1.0):
		var points := PackedVector2Array(corners)
		draw_colored_polygon(points, Color(GHOST_FILL, GHOST_FILL.a * alpha))
		points.append(points[0])
		draw_polyline(points, Color(GHOST_LINE, alpha), 0.9, true)


## A stone chip: an uneven polygon, squashed to sit in the iso view, turned
## by `turn`, with a lighter top.
func _draw_chip(chip: Dictionary, at: Vector3, turn: float, alpha: float) -> void:
	var center := iso(at.x, at.y, at.z)
	var points := PackedVector2Array()
	for p: Vector2 in chip.outline:
		points.append(center + Vector2(cos(p.x + turn), sin(p.x + turn) * 0.8) * p.y)
	var tone: Color = chip.color
	draw_colored_polygon(points, Color(tone, alpha))
	var top := PackedVector2Array()
	for p in points:
		top.append(center + Vector2(0, -chip.radius * 0.25) + (p - center) * Vector2(0.55, 0.45))
	draw_colored_polygon(top, Color(CUBE_TOP, 0.9 * alpha))
	points.append(points[0])
	draw_polyline(points, Color(CUBE_EDGE, alpha), 0.6, true)
