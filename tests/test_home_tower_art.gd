extends "res://tests/q_test.gd"

const HomeTowerArt := preload("res://game/home_tower_art.gd")
const Config := preload("res://core/config.gd")


func _loop(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return HomeTowerArt.plan_loop(Config.new().pieces, rng)


## Every tower fits the grid, stays under the height and cube caps, and no
## two pieces share a cell.
func test_towers_fit_the_grid_without_overlaps() -> void:
	for seed in range(30):
		var loop := _loop(seed)
		var seen := {}
		check(loop.placements.size() > 0, "seed %d built nothing" % seed)
		check(loop.placements.size() <= HomeTowerArt.MAX_PIECES, "seed %d placed too many pieces" % seed)
		for c: Vector3i in loop.cells:
			check(c.x >= 0 and c.x < 6 and c.y >= 0 and c.y < 6, "seed %d put %s off the floor" % [seed, c])
			check(c.z >= 0 and c.z < HomeTowerArt.MAX_LAYERS, "seed %d put %s too high" % [seed, c])
			check(not seen.has(c), "seed %d placed %s twice" % [seed, c])
			seen[c] = true


## Each piece rests on the floor or on a cube placed before it.
func test_pieces_rest_on_something() -> void:
	for seed in range(30):
		var filled := {}
		for placement in _loop(seed).placements:
			var resting := false
			for c: Vector3i in placement.cells:
				if c.z == 0 or filled.has(c - Vector3i(0, 0, 1)):
					resting = true
			check(resting, "seed %d left a piece floating at %s" % [seed, placement.cells])
			for c in placement.cells:
				filled[c] = true


## Ghosts show one at a time: each piece starts after the last has landed.
func test_pieces_take_turns() -> void:
	var loop := _loop(7)
	var last_end := 0.0
	for placement in loop.placements:
		check(placement.start >= last_end, "a ghost showed before the piece ahead of it landed")
		check(is_equal_approx(placement.end - placement.start,
			HomeTowerArt.GHOST_SECONDS + HomeTowerArt.DROP_SECONDS), "a piece took the wrong time to place")
		last_end = placement.end
	check(loop.build_end >= last_end, "the build ended before the last piece landed")


## The crumble waits for the tower to stand, then breaks it top layer first.
func test_crumble_breaks_from_the_top_down() -> void:
	var loop := _loop(3)
	var shake_end: float = loop.crumble_at + HomeTowerArt.SHAKE_SECONDS
	check(loop.crumble_at > loop.build_end, "the crumble started before the tower stood")
	var top := 0
	for c: Vector3i in loop.cells:
		top = maxi(top, c.z)
	for i in range(loop.cells.size()):
		var c: Vector3i = loop.cells[i]
		var brk: float = loop.breaks[i]
		check(brk >= shake_end, "a cube broke during the shake")
		var layer_start := shake_end + (top - c.z) * HomeTowerArt.LAYER_SECONDS
		check(brk >= layer_start - 0.0001 and brk <= layer_start + HomeTowerArt.JITTER_SECONDS + 0.0001,
			"cube %s broke out of its layer's turn" % c)


## Chips land on the floor's heap and the loop ends after the rubble fades.
func test_chips_land_on_the_heap() -> void:
	for seed in range(10):
		var loop := _loop(seed)
		check(loop.chips.size() == loop.cells.size() * HomeTowerArt.CHIPS_PER_CUBE, "seed %d is missing chips" % seed)
		for chip in loop.chips:
			var rest: Vector3 = chip.rest
			check(Vector2(rest.x, rest.y).distance_to(Vector2(3, 3)) <= HomeTowerArt.HEAP_RADIUS + 0.001,
				"seed %d dropped a chip off the heap" % seed)
			check(chip.start_time + chip.fall <= loop.settled + 0.0001, "seed %d settled before a chip landed" % seed)
			check(HomeTowerArt.chip_position(chip, chip.start_time + chip.fall + 1.0).is_equal_approx(rest),
				"seed %d left a chip short of its rest spot" % seed)
		check(loop.loop_end > loop.fade_at and loop.fade_at > loop.settled, "seed %d ends out of order" % seed)


func test_chips_start_where_their_cube_stood() -> void:
	var loop := _loop(5)
	for n in range(loop.chips.size()):
		var chip: Dictionary = loop.chips[n]
		var c: Vector3i = loop.cells[n / HomeTowerArt.CHIPS_PER_CUBE]
		var at := HomeTowerArt.chip_position(chip, chip.start_time)
		check(at.distance_to(Vector3(c) + Vector3.ONE * 0.5) < 0.5, "a chip started away from its cube")


func test_phases_follow_the_loop() -> void:
	var loop := _loop(11)
	check_eq(HomeTowerArt.phase_at(loop, 0.0), HomeTowerArt.Phase.BUILDING)
	check_eq(HomeTowerArt.phase_at(loop, loop.build_end + 0.01), HomeTowerArt.Phase.HOLDING)
	check_eq(HomeTowerArt.phase_at(loop, loop.crumble_at + 0.01), HomeTowerArt.Phase.CRUMBLING)
	check_eq(HomeTowerArt.phase_at(loop, loop.settled + 0.01), HomeTowerArt.Phase.RESETTING)


func test_same_seed_builds_the_same_tower() -> void:
	check_eq(_loop(42).cells, _loop(42).cells)


## Playing starts the loop and it rolls over into a new one; Reduce Motion
## and show_cells() stand still on the given cells.
func test_play_loops_and_still_stands() -> void:
	var art := HomeTowerArt.new()
	art.play([Vector3i.ZERO])
	check(art.is_animating(), "play() did not start the loop")
	var end: float = art.plan.loop_end
	art.advance(end + 0.01)
	check(art.time < end, "the loop did not start over")
	art.show_cells([Vector3i(1, 1, 0)])
	check(not art.is_animating(), "show_cells() left the loop running")
	check_eq(art.cells, [Vector3i(1, 1, 0)])
	art.still = true
	art.play([Vector3i(2, 2, 0)])
	check(not art.is_animating(), "Reduce Motion still played the loop")
	check_eq(art.cells, [Vector3i(2, 2, 0)])
	art.free()
