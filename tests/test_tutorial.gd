extends "res://tests/q_test.gd"
## The tutorial's scripted moves (#29).

const Config := preload("res://core/config.gd")
const Rules := preload("res://core/rules.gd")
const Tutorial := preload("res://core/tutorial.gd")
const ViewMath := preload("res://game/view_math.gd")


func test_three_steps() -> void:
	check_eq(Tutorial.step_count(), 3)


func test_each_step_starts_with_its_piece_and_tower() -> void:
	var config := Config.new()
	for i in range(Tutorial.step_count()):
		var data := Tutorial.step(i)
		var game = Tutorial.make_game(config, i)
		check_eq(game.tray.size(), config.tray_size, "step %d tray size" % i)
		check(game.tray[0] != null and game.tray[0].size == data.piece_size, "step %d piece" % i)
		check(game.tray.slice(1).all(func(p): return p == null), "step %d has one piece" % i)
		check_eq(game.grid.filled_cells().size(), data.cells.size(), "step %d cubes" % i)
		check_eq(game.score, 0, "step %d score" % i)
		check(not game.is_over, "step %d is playable" % i)


func test_no_step_starts_with_a_full_line() -> void:
	var config := Config.new()
	for i in range(Tutorial.step_count()):
		var game = Tutorial.make_game(config, i)
		var cells: Array[Vector3i] = []
		cells.assign(game.grid.filled_cells())
		check(Rules.full_lines_through(game.grid, cells).is_empty(), "step %d" % i)


## Each step's target is a legal spot, and every step after the first
## clears exactly one row there.
func test_targets_are_legal_and_clear_a_row() -> void:
	var config := Config.new()
	for i in range(Tutorial.step_count()):
		var data := Tutorial.step(i)
		var game = Tutorial.make_game(config, i)
		check(game.can_place(0, data.target), "step %d target is legal" % i)
		var result: Dictionary = game.place(0, data.target)
		check_eq(result.lines.size(), 0 if i == 0 else 1, "step %d lines" % i)
		check(not game.is_over, "step %d does not end the game" % i)


func test_first_step_allows_any_floor_spot() -> void:
	check_eq(Tutorial.allowed_origins(0, false), null)


func test_later_steps_allow_only_the_target() -> void:
	check_eq(Tutorial.allowed_origins(1, false), [Tutorial.step(1).target])
	check_eq(Tutorial.allowed_origins(2, true), [Tutorial.step(2).target])


func test_hidden_target_takes_nothing_until_found() -> void:
	check(Tutorial.step(2).hidden)
	check_eq(Tutorial.allowed_origins(2, false), [])


## At the starting view a wall stands in front of every cell of the hidden
## gap; one quarter turn to the right puts the gap in the front row.
func test_hidden_gap_is_behind_the_wall_until_turned() -> void:
	var config := Config.new()
	var data := Tutorial.step(2)
	var game = Tutorial.make_game(config, 2)
	var piece = game.tray[0]
	for step in [0, 1]:
		var toward := ViewMath.toward_camera(step)
		var front := Vector3i(int(signf(toward.x)), int(signf(toward.y)), 0)
		var blocked := 0
		for c in piece.cells_at(data.target):
			var ahead: Vector3i = c + front
			if game.grid.in_bounds(ahead) and game.grid.is_filled(ahead) \
					and game.grid.is_filled(ahead + Vector3i(0, 0, 1)):
				blocked += 1
		if step == 0:
			check_eq(blocked, piece.cube_count(), "hidden at the starting view")
		else:
			check_eq(blocked, 0, "in view after one turn right")
