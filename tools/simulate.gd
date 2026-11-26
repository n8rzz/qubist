extends SceneTree
## Plays many games with the core and prints how long they last and how the
## scores spread out. Used for the tuning pass on scoring and dealing (#21).
##
##   godot --headless --path . --script res://tools/simulate.gd -- [options]
##
## Options (all optional):
##   --games=N         games per bot (default 200)
##   --bots=a,b        which bots play: greedy, mixed, random (default all)
##   --seed=N          first seed; game i uses seed + i (default 1)
##   --max-moves=N     stop a game after this many moves (default 2000)
##   --rerolls=N       override dealer.max_rerolls
##   --ppc=N           override scoring.points_per_cube_cleared
##   --streak=N        override scoring.streak_bonus
##   --weight=id:w     override one piece entry's weight (repeatable)
##
## The bots stand in for players at two ends of the skill range:
##   random  drops a random tray piece on a random legal spot.
##   mixed   plays the greedy move half the time and a random one otherwise.
##   greedy  tries every piece on every legal spot and takes the one that
##           clears the most lines, then keeps the tower lowest and tightest.

const Config := preload("res://core/config.gd")
const Game := preload("res://core/game.gd")
const Rules := preload("res://core/rules.gd")

const BOTS := ["greedy", "mixed", "random"]


func _init() -> void:
	var opts := _parse_args(OS.get_cmdline_user_args())
	var cfg = _make_config(opts)
	print(
		(
			"Config: rerolls=%d ppc=%d streak=%d pieces=%d"
			% [cfg.max_rerolls, cfg.points_per_cube_cleared, cfg.streak_bonus, cfg.pieces.size()]
		)
	)
	var bots: Array = opts.get("bots", BOTS)
	for bot in bots:
		_run(
			cfg,
			str(bot),
			int(opts.get("games", 200)),
			int(opts.get("seed", 1)),
			int(opts.get("max_moves", 2000))
		)
	quit(0)


func _run(cfg, bot: String, games: int, first_seed: int, max_moves: int) -> void:
	var moves: Array = []
	var scores: Array = []
	var lines: Array = []
	var streaks: Array = []
	var combos: Array = []
	var streak_share: Array = []
	var capped := 0
	var started := Time.get_ticks_msec()
	for i in games:
		var game := Game.new(cfg, first_seed + i)
		var rng := RandomNumberGenerator.new()
		rng.seed = first_seed + i
		var bonus_points := 0
		game.start()
		while not game.is_over and game.moves < max_moves:
			var move: Dictionary = _choose(game, bot, rng)
			if move.is_empty():
				break
			var result: Dictionary = game.place(move.slot, move.origin)
			bonus_points += int(result.score.streak_bonus)
		if not game.is_over:
			capped += 1
		moves.append(game.moves)
		scores.append(game.score)
		lines.append(game.lines_cleared_total)
		streaks.append(game.longest_streak)
		combos.append(game.best_combo)
		streak_share.append(0.0 if game.score == 0 else float(bonus_points) / game.score)
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	print("")
	print(
		(
			"== %s bot: %d games in %.1fs%s =="
			% [bot, games, secs, "" if capped == 0 else " (%d hit the move cap)" % capped]
		)
	)
	print("            min    p10    p25 median    p75    p90    max   mean")
	_row("moves", moves)
	_row("score", scores)
	_row("lines", lines)
	_row("streak", streaks)
	_row("combo", combos)
	print("streak bonus share of score: %.0f%% (mean)" % (100.0 * _mean(streak_share)))


func _row(label: String, values: Array) -> void:
	var s := values.duplicate()
	s.sort()
	print(
		(
			"%-8s %6d %6d %6d %6d %6d %6d %6d %6.0f"
			% [
				label,
				s[0],
				_pct(s, 0.10),
				_pct(s, 0.25),
				_pct(s, 0.50),
				_pct(s, 0.75),
				_pct(s, 0.90),
				s[-1],
				_mean(s)
			]
		)
	)


func _pct(sorted: Array, p: float):
	return sorted[clampi(int(round(p * (sorted.size() - 1))), 0, sorted.size() - 1)]


func _mean(values: Array) -> float:
	var total := 0.0
	for v in values:
		total += float(v)
	return total / maxi(values.size(), 1)


## Returns { slot, origin } or {} when nothing fits.
func _choose(game, bot: String, rng: RandomNumberGenerator) -> Dictionary:
	var options: Array = []
	for slot in game.tray.size():
		var piece = game.tray[slot]
		if piece == null:
			continue
		for origin in Rules.legal_positions(game.grid, piece):
			options.append({"slot": slot, "origin": origin})
	if options.is_empty():
		return {}
	if bot == "random" or (bot == "mixed" and rng.randf() < 0.5):
		return options[rng.randi_range(0, options.size() - 1)]
	var best: Dictionary = {}
	var best_value := -INF
	for option in options:
		var value := (
			_evaluate(game.grid, game.tray[option.slot], option.origin) + rng.randf() * 0.01
		)
		if value > best_value:
			best_value = value
			best = option
	return best


## Higher is better: lines cleared first, then a low, well-packed placement.
func _evaluate(grid, piece, origin: Vector3i) -> float:
	var cells: Array[Vector3i] = piece.cells_at(origin)
	for c in cells:
		grid.set_filled(c, true)
	var lines := Rules.full_lines_through(grid, cells)
	var contacts := 0
	var top := 0
	for c in cells:
		top = maxi(top, c.z)
		for d in [
			Vector3i(1, 0, 0),
			Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0),
			Vector3i(0, -1, 0),
			Vector3i(0, 0, -1)
		]:
			var n: Vector3i = c + d
			if not grid.in_bounds(n) or grid.is_filled(n):
				contacts += 1
	for c in cells:
		grid.set_filled(c, false)
	var line_cubes := 0
	for line in lines:
		line_cubes += line.cells.size()
	return line_cubes * 100.0 + contacts * 2.0 - top * 6.0


func _make_config(opts: Dictionary):
	var game_data := Config.load_json(Config.DEFAULT_GAME_PATH)
	var pieces_data := Config.load_json(Config.DEFAULT_PIECES_PATH)
	if opts.has("rerolls"):
		game_data["dealer"]["max_rerolls"] = int(opts.rerolls)
	if opts.has("ppc"):
		game_data["scoring"]["points_per_cube_cleared"] = int(opts.ppc)
	if opts.has("streak"):
		game_data["scoring"]["streak_bonus"] = int(opts.streak)
	for pair in opts.get("weight", []):
		var bits: PackedStringArray = str(pair).split(":")
		for entry in pieces_data.pieces:
			if entry.id == bits[0]:
				entry["weight"] = float(bits[1])
	return Config.new(game_data, pieces_data)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var key := arg.substr(2, arg.find("=") - 2).replace("-", "_")
		var value := arg.substr(arg.find("=") + 1)
		match key:
			"bots":
				out[key] = Array(value.split(","))
			"weight":
				if not out.has(key):
					out[key] = []
				out[key].append(value)
			_:
				out[key] = value
	return out
