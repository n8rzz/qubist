extends "res://tests/q_test.gd"

const Config := preload("res://core/config.gd")
const Game := preload("res://core/game.gd")
const Rules := preload("res://core/rules.gd")


## A started game with a known tray and an otherwise empty grid.
func _game(tray_ids: Array = ["bar2_x", "bar4_x", "cube2"]):
	var game := Game.new(Config.new(), 7)
	game.start()
	game.grid.clear_all()
	game.tray = tray_ids.map(func(id): return game.config.piece_by_id(id))
	return game


func _fill(game, cells: Array) -> void:
	for c in cells:
		game.grid.set_filled(c, true)


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
	check_eq(game.score, 2)
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
	_fill(game, _row(0, 0, [0, 1, 2, 3]))
	var result: Dictionary = game.place(0, Vector3i(4, 0, 0))
	check(result.ok)
	check_eq(result.lines.size(), 1)
	check_eq(result.cleared.size(), 6)
	check_eq(game.score, 2 + 60)
	check_eq(game.grid.filled_count(), 0)
	check_eq(game.streak, 1)
	check_eq(game.lines_cleared_total, 1)


func test_no_gravity_after_clear() -> void:
	var game = _game()
	_fill(game, _row(0, 0, [0, 1, 2, 3]))
	_fill(game, [Vector3i(2, 0, 1)])
	game.place(0, Vector3i(4, 0, 0))
	check(not game.grid.is_filled(Vector3i(2, 0, 0)))
	check(game.grid.is_filled(Vector3i(2, 0, 1)), "block above a cleared line stays put")


func test_crossing_lines_share_one_cube() -> void:
	var game = _game(["bar2_up", "bar4_x", "cube2"])
	_fill(game, _row(0, 0, [1, 2, 3, 4, 5]))
	for y in range(1, 6):
		_fill(game, [Vector3i(0, y, 0)])
	var result: Dictionary = game.place(0, Vector3i(0, 0, 0))
	check_eq(result.lines.size(), 2)
	check_eq(result.cleared.size(), 11, "shared corner cube is removed once")
	check_eq(game.score, 2 + (60 + 60) * 2)
	check_eq(game.best_combo, 2)
	check(game.grid.is_filled(Vector3i(0, 0, 1)), "upper half of the bar is left floating")


func test_streak_builds_and_resets() -> void:
	var game = _game(["bar2_x", "bar2_x", "cube2"])
	_fill(game, _row(0, 0, [0, 1, 2, 3]))
	_fill(game, _row(1, 0, [0, 1, 2, 3]))
	game.place(0, Vector3i(4, 0, 0))
	check_eq(game.score, 62)
	var second: Dictionary = game.place(1, Vector3i(4, 1, 0))
	check_eq(second.score.streak_bonus, 50)
	check_eq(game.score, 62 + 112)
	check_eq(game.streak, 2)
	game.place(2, Vector3i(0, 3, 0))
	check_eq(game.streak, 0)
	check_eq(game.longest_streak, 2)
	check_eq(game.score, 62 + 112 + 8)


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


func test_game_over_when_nothing_fits() -> void:
	var game = _game(["cube2", "cube2", "cube2"])
	var ended := [false]
	game.game_over.connect(func(_score): ended[0] = true)
	# Checkerboard every layer: no 2x2 footprint is ever empty.
	for h in range(12):
		for y in range(6):
			for x in range(6):
				if (x + y) % 2 == 0:
					_fill(game, [Vector3i(x, y, h)])
	check(game.check_game_over())
	check(game.is_over)
	check(ended[0], "game_over signal fired")
	check(not game.place(0, Vector3i(0, 0, 0)).ok)


func test_one_fitting_piece_keeps_the_game_going() -> void:
	var game = _game(["cube2", "cube2", "bar2_up"])
	for h in range(12):
		for y in range(6):
			for x in range(6):
				if (x + y) % 2 == 0:
					_fill(game, [Vector3i(x, y, h)])
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
	check_eq(restored.tray[1].id, "bar4_x")
	check_eq(restored.tray[2].id, "cube2")
	for _i in range(5):
		check_eq(restored.dealer.pick().id, game.dealer.pick().id, "dealer continues the same sequence")


func test_restore_rejects_other_grid_size() -> void:
	var game = _game()
	var saved: Dictionary = game.to_dict()
	saved["grid"]["size"] = [4, 4, 8]
	check(not Game.new(Config.new(), 1).from_dict(saved))


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
			check(game.score > last_score, "every move scores at least its placed cubes")
			last_score = game.score
			check_eq(Rules.full_lines_through(game.grid, game.grid.filled_cells()).size(), 0, "no full line is left on the grid")
		check(game.is_over, "seed %d ended within 2000 moves" % game_seed)
