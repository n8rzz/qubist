extends "res://tests/q_test.gd"

const Config := preload("res://core/config.gd")
const Game := preload("res://core/game.gd")
const Rules := preload("res://core/rules.gd")


## A started game with a known tray and an otherwise empty grid.
## `tray` holds piece ids or bar sizes (see q_test.gd).
func _game(tray: Array = [BAR2_X, BAR4_X, "cube2"]):
	var game := Game.new(Config.new(), 7)
	game.start()
	game.grid.clear_all()
	game.tray = tray.map(func(key): return find_piece(game.config, key))
	return game


func _row(y: int, h: int, xs: Array) -> Array:
	return xs.map(func(x): return Vector3i(x, y, h))


func test_start() -> void:
	var game := Game.new(Config.new(), 7)
	game.start()
	check_eq(game.tray.size(), 3)
	check(game.tray.all(func(p): return p != null))
	check_eq(game.score, 0)
	check(not game.is_over)


func test_place_without_clear() -> void:
	var game = _game()
	var result: Dictionary = game.place(0, Vector3i(0, 0, 0))
	check(result.ok)
	check_eq(result.lines.size(), 0)
	check_eq(game.score, 0, "placing without clearing scores nothing")
	check_eq(game.moves, 1)
	check(game.tray[0] == null, "placed slot stays empty until refill")
	check(game.grid.is_filled(Vector3i(1, 0, 0)))


func test_illegal_move_changes_nothing() -> void:
	var game = _game()
	var result: Dictionary = game.place(0, Vector3i(0, 0, 3))
	check(not result.ok)
	check_eq(game.score, 0)
	check_eq(game.moves, 0)
	check(game.tray[0] != null)
	check_eq(game.grid.filled_count(), 0)


func test_empty_slot_cannot_be_placed() -> void:
	var game = _game()
	game.place(0, Vector3i(0, 0, 0))
	check(not game.place(0, Vector3i(0, 1, 0)).ok)
	check(not game.place(5, Vector3i(0, 1, 0)).ok)


func test_completing_a_line_clears_and_scores() -> void:
	var game = _game()
	fill(game.grid, _row(0, 0, [0, 1, 2, 3]))
	var result: Dictionary = game.place(0, Vector3i(4, 0, 0))
	check(result.ok)
	check_eq(result.lines.size(), 1)
	check_eq(result.cleared.size(), 6)
	check_eq(game.score, 60)
	check_eq(game.grid.filled_count(), 0)
	check_eq(game.streak, 1)
	check_eq(game.lines_cleared_total, 1)


func test_no_gravity_after_clear() -> void:
	var game = _game()
	fill(game.grid, _row(0, 0, [0, 1, 2, 3]))
	fill(game.grid, [Vector3i(2, 0, 1)])
	game.place(0, Vector3i(4, 0, 0))
	check(not game.grid.is_filled(Vector3i(2, 0, 0)))
	check(game.grid.is_filled(Vector3i(2, 0, 1)), "block above a cleared line stays put")


func test_crossing_lines_share_one_cube() -> void:
	var game = _game([BAR2_UP, BAR4_X, "cube2"])
	fill(game.grid, _row(0, 0, [1, 2, 3, 4, 5]))
	for y in range(1, 6):
		fill(game.grid, [Vector3i(0, y, 0)])
	var result: Dictionary = game.place(0, Vector3i(0, 0, 0))
	check_eq(result.lines.size(), 2)
	check_eq(result.cleared.size(), 11, "shared corner cube is removed once")
	check_eq(game.score, (60 + 60) * 2)
	check_eq(game.best_combo, 2)
	check(game.grid.is_filled(Vector3i(0, 0, 1)), "upper half of the bar is left floating")


func test_piece_placed_carries_the_slot_piece_and_origin() -> void:
	var game = _game()
	var piece = game.tray[1]
	var origin := Vector3i(1, 2, 0)
	var calls: Array = []
	game.piece_placed.connect(func(index, p, at): calls.append([index, p, at]))
	check(game.place(1, origin).ok)
	check_eq(calls.size(), 1, "piece_placed fired once")
	if calls.size() == 1:
		check_eq(calls[0][0], 1, "tray index")
		check(is_same(calls[0][1], piece), "the piece that was in the slot")
		check_eq(calls[0][2], origin, "origin")


func test_lines_cleared_carries_lines_and_cells_once() -> void:
	# Same crossing as above: two lines sharing the corner cube.
	var game = _game([BAR2_UP, BAR4_X, "cube2"])
	fill(game.grid, _row(0, 0, [1, 2, 3, 4, 5]))
	for y in range(1, 6):
		fill(game.grid, [Vector3i(0, y, 0)])
	var calls: Array = []
	game.lines_cleared.connect(func(lines, cells): calls.append([lines, cells]))
	var result: Dictionary = game.place(0, Vector3i(0, 0, 0))
	check_eq(calls.size(), 1, "lines_cleared fired once")
	if calls.size() != 1:
		return
	var lines: Array = calls[0][0]
	var cells: Array = calls[0][1]
	check_eq(lines, result.lines, "the lines that were cleared")
	check_eq(lines.size(), 2)
	var in_lines := {}
	for line in lines:
		for c in line.cells:
			in_lines[c] = true
	var listed := {}
	for c in cells:
		check(not listed.has(c), "%s is listed twice" % c)
		listed[c] = true
	check_eq(cells.size(), 11, "the shared corner cube is listed once")
	check(listed.has(Vector3i(0, 0, 0)), "the shared corner cube is listed")
	check_eq(listed.size(), in_lines.size(), "every cell of both lines is listed")
	for c in in_lines:
		check(listed.has(c), "%s from a cleared line is missing" % c)


func test_lines_cleared_does_not_fire_without_a_clear() -> void:
	var game = _game()
	var placed := [0]
	var cleared := [0]
	game.piece_placed.connect(func(_index, _p, _at): placed[0] += 1)
	game.lines_cleared.connect(func(_lines, _cells): cleared[0] += 1)
	check(game.place(0, Vector3i(0, 0, 0)).ok)
	check_eq(placed[0], 1, "the move went through")
	check_eq(cleared[0], 0, "lines_cleared stayed quiet")


func test_streak_builds_and_resets() -> void:
	var game = _game([BAR2_X, BAR2_X, "cube2"])
	fill(game.grid, _row(0, 0, [0, 1, 2, 3]))
	fill(game.grid, _row(1, 0, [0, 1, 2, 3]))
	game.place(0, Vector3i(4, 0, 0))
	check_eq(game.score, 60)
	var second: Dictionary = game.place(1, Vector3i(4, 1, 0))
	check_eq(second.score.streak_bonus, 50)
	check_eq(game.score, 60 + 110)
	check_eq(game.streak, 2)
	game.place(2, Vector3i(0, 3, 0))
	check_eq(game.streak, 0)
	check_eq(game.longest_streak, 2)
	check_eq(game.score, 60 + 110)


func test_tray_refills_after_three_placements() -> void:
	var game = _game()
	var refills := [0]
	game.tray_refilled.connect(func(_tray): refills[0] += 1)
	game.place(0, Vector3i(0, 0, 0))
	game.place(1, Vector3i(0, 1, 0))
	check_eq(refills[0], 0)
	game.place(2, Vector3i(0, 3, 0))
	check_eq(refills[0], 1)
	check(game.tray.all(func(p): return p != null))


## With auto_refill off (the tutorial, #29), an emptied tray stays empty
## and the game goes on.
func test_no_refill_leaves_the_tray_empty() -> void:
	var game = _game()
	game.tray = [game.tray[0], null, null]
	game.auto_refill = false
	var refills := [0]
	game.tray_refilled.connect(func(_tray): refills[0] += 1)
	check(game.place(0, Vector3i(0, 0, 0)).ok)
	check_eq(refills[0], 0)
	check(game.tray.all(func(p): return p == null), "tray stays empty")
	check(not game.is_over, "an empty tray doesn't end the game")


func test_game_over_when_nothing_fits() -> void:
	var game = _game(["cube2", "cube2", "cube2"])
	var ended := [false]
	game.game_over.connect(func(_score): ended[0] = true)
	checkerboard(game.grid)
	check(game.check_game_over())
	check(game.is_over)
	check(ended[0], "game_over signal fired")
	check(not game.place(0, Vector3i(0, 0, 0)).ok)


## Placing a piece that leaves the rest of the tray with nowhere to go ends
## the game in the same move.
func test_placement_that_strands_the_tray_ends_the_game() -> void:
	var game = _game([BAR2_UP, "cube2", "cube2"])
	var ended := [false]
	game.game_over.connect(func(_score): ended[0] = true)
	checkerboard(game.grid)
	var result: Dictionary = game.place(0, Vector3i(1, 0, 0))
	check(result.ok)
	check_eq(result.lines.size(), 0, "the placement clears nothing")
	check(result.game_over, "result reports game over")
	check(game.is_over)
	check(ended[0], "game_over signal fired")
	check(game.tray[1] != null and game.tray[2] != null, "unplaceable pieces stay in the tray")


func test_start_resets_a_played_game() -> void:
	var game = _game([BAR2_X, BAR2_X, "cube2"])
	fill(game.grid, _row(0, 0, [0, 1, 2, 3]))
	fill(game.grid, _row(1, 0, [0, 1, 2, 3]))
	game.place(0, Vector3i(4, 0, 0))
	game.place(1, Vector3i(4, 1, 0))
	checkerboard(game.grid)
	check(game.check_game_over())
	check(game.score > 0 and game.longest_streak == 2 and game.best_combo == 1, "game was played")

	game.start()
	check_eq(game.score, 0)
	check_eq(game.streak, 0)
	check_eq(game.longest_streak, 0)
	check_eq(game.best_combo, 0)
	check_eq(game.lines_cleared_total, 0)
	check_eq(game.moves, 0)
	check(not game.is_over)
	check_eq(game.grid.filled_count(), 0, "grid is emptied")
	check(game.tray.all(func(p): return p != null), "a fresh tray is dealt")


func test_restore_after_game_over() -> void:
	var game = _game(["cube2", "cube2", "cube2"])
	checkerboard(game.grid)
	check(game.check_game_over())
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.to_dict()))

	var restored := Game.new(Config.new(), 99)
	restored.start()
	check(not restored.is_over)
	check(restored.from_dict(saved))
	check(restored.is_over, "restored game is still over")
	check(not restored.place(0, Vector3i(0, 0, 0)).ok, "no moves after restoring a finished game")


func test_one_fitting_piece_keeps_the_game_going() -> void:
	var game = _game(["cube2", "cube2", BAR2_UP])
	checkerboard(game.grid)
	check(not game.check_game_over())


func test_save_and_restore() -> void:
	var game = _game()
	game.place(0, Vector3i(0, 0, 0))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.to_dict()))

	var restored := Game.new(Config.new(), 99)
	check(restored.from_dict(saved))
	check_eq(restored.score, game.score)
	check_eq(restored.moves, 1)
	check_eq(restored.grid.to_array(), game.grid.to_array())
	check(restored.tray[0] == null)
	check_eq(restored.tray[1].id, game.tray[1].id)
	check_eq(restored.tray[2].id, "cube2")
	check_eq(restored.tray[1].size, BAR4_X)
	for _i in range(5):
		check_eq(restored.dealer.pick().id, game.dealer.pick().id, "dealer continues the same sequence")


func test_restore_rejects_other_grid_size() -> void:
	var game = _game()
	var saved: Dictionary = game.to_dict()
	saved["grid"]["size"] = [4, 4, 8]
	check(not Game.new(Config.new(), 1).from_dict(saved))


func test_restore_rejects_changed_config() -> void:
	var saved: Dictionary = _game().to_dict()
	var pieces := Config.load_json(Config.DEFAULT_PIECES_PATH)
	pieces.pieces[0].cells.append([9, 9, 9])
	check(not Game.new(Config.new({}, pieces), 1).from_dict(saved), "changed piece shape")
	var bigger := Config.load_json(Config.DEFAULT_GAME_PATH)
	bigger.grid.height = 14
	check(not Game.new(Config.new(bigger), 1).from_dict(saved), "changed grid")


func test_restore_ignores_scoring_changes() -> void:
	var saved: Dictionary = _game().to_dict()
	var rescored := Config.load_json(Config.DEFAULT_GAME_PATH)
	rescored.scoring.streak_bonus = 999
	check(Game.new(Config.new(rescored), 1).from_dict(saved))


func test_restore_rejects_other_version() -> void:
	var saved: Dictionary = _game().to_dict()
	saved["version"] = Game.SAVE_VERSION - 1
	check(not Game.new(Config.new(), 1).from_dict(saved))


## The parts of a game that a rejected restore must leave alone.
func _state(game) -> Dictionary:
	return {
		"score": game.score,
		"streak": game.streak,
		"moves": game.moves,
		"is_over": game.is_over,
		"grid": game.grid.to_array(),
		"tray": game.tray.map(func(p): return "" if p == null else p.id),
	}


## Checks that from_dict rejects a save after `spoil` edits it, and that the
## game it was loaded into keeps its own state.
func _check_rejected(spoil: Callable, message: String) -> void:
	var source = _game(["cube2", BAR2_X, BAR4_X])
	source.place(0, Vector3i(0, 0, 0))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(source.to_dict()))
	spoil.call(saved)

	var game = _game()
	game.place(1, Vector3i(0, 0, 0))
	var before := _state(game)
	check(_state(source) != before, "source and target differ, so a partial restore would show")
	check(not game.from_dict(saved), message)
	check_eq(_state(game), before, message + ": game unchanged")


func test_restore_rejects_unknown_piece() -> void:
	_check_rejected(func(saved): saved["tray"][1] = "no_such_piece", "unknown piece id")


func test_restore_rejects_other_tray_size() -> void:
	_check_rejected(func(saved): saved["tray"].append(""), "longer tray")
	_check_rejected(func(saved): saved["tray"].pop_back(), "shorter tray")


func test_restore_rejects_wrong_cell_count() -> void:
	_check_rejected(func(saved): saved["grid"]["cells"].pop_back(), "too few cells")
	_check_rejected(func(saved): saved["grid"]["cells"].append(0), "too many cells")


func test_rejected_restore_leaves_the_game_unchanged() -> void:
	_check_rejected(func(saved): saved["version"] = Game.SAVE_VERSION - 1, "other version")
	_check_rejected(func(saved): saved["config"] = "other", "other config")
	_check_rejected(func(saved): saved["grid"]["size"] = [4, 4, 8], "other grid size")


func test_random_games_play_to_the_end() -> void:
	# Plays seeded games with random legal moves until each ends, checking
	# that the rules hold on every move.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for game_seed in range(5):
		var game := Game.new(Config.new(), game_seed)
		game.start()
		var last_score := 0
		var guard := 0
		while not game.is_over and guard < 2000:
			guard += 1
			var options: Array = []
			for i in range(game.tray.size()):
				if game.tray[i] == null:
					continue
				for origin in Rules.legal_positions(game.grid, game.tray[i]):
					options.append([i, origin])
			check(not options.is_empty(), "a game that is not over has a legal move")
			if options.is_empty():
				break
			var pick: Array = options[rng.randi_range(0, options.size() - 1)]
			var result: Dictionary = game.place(pick[0], pick[1])
			check(result.ok)
			if result.lines.is_empty():
				check_eq(game.score, last_score, "a move that clears nothing scores nothing")
			else:
				check(game.score > last_score, "a move that clears a line scores")
			last_score = game.score
			check_eq(Rules.full_lines_through(game.grid, game.grid.filled_cells()).size(), 0, "no full line is left on the grid")
		check(game.is_over, "seed %d ended within 2000 moves" % game_seed)
