extends RefCounted
## One game of Qubist: the grid, the 3-piece tray, score and streak.
##
## The view layer calls `place()` and listens to the signals; nothing here
## knows about rendering or platform services.

const Config := preload("res://core/config.gd")
const Grid := preload("res://core/grid.gd")
const Rules := preload("res://core/rules.gd")
const Scoring := preload("res://core/scoring.gd")
const Dealer := preload("res://core/dealer.gd")

const SAVE_VERSION := 2

signal piece_placed(tray_index: int, piece, origin: Vector3i)
signal lines_cleared(lines: Array, cells: Array)
signal tray_refilled(tray: Array)
signal game_over(final_score: int)

var config
var grid
var scoring
var dealer

## Pieces waiting to be placed; a placed slot holds null until the refill.
var tray: Array = []
var score := 0
var streak := 0
var longest_streak := 0
var best_combo := 0
var lines_cleared_total := 0
var moves := 0
var is_over := false


func _init(p_config = null, seed_value: int = -1) -> void:
	config = p_config if p_config != null else Config.new()
	grid = Grid.new(config.grid_size.x, config.grid_size.y, config.grid_size.z)
	scoring = Scoring.new(config)
	dealer = Dealer.new(config.pieces, config.tray_size, config.max_rerolls, seed_value)


func start() -> void:
	grid.clear_all()
	score = 0
	streak = 0
	longest_streak = 0
	best_combo = 0
	lines_cleared_total = 0
	moves = 0
	is_over = false
	_refill()


func can_place(tray_index: int, origin: Vector3i) -> bool:
	if is_over or tray_index < 0 or tray_index >= tray.size():
		return false
	var piece = tray[tray_index]
	return piece != null and Rules.can_place(grid, piece, origin)


## Places a tray piece, clears full lines and scores the move.
## Returns { "ok": false } if the move is not allowed. Otherwise returns
## { "ok", "piece", "origin", "placed", "lines", "cleared", "score", "game_over" }
## where "score" is the breakdown from Scoring.score_placement().
func place(tray_index: int, origin: Vector3i) -> Dictionary:
	if not can_place(tray_index, origin):
		return {"ok": false}

	var piece = tray[tray_index]
	var placed: Array[Vector3i] = piece.cells_at(origin)
	for c in placed:
		grid.set_filled(c, true)
	tray[tray_index] = null
	moves += 1
	piece_placed.emit(tray_index, piece, origin)

	# Clear every full line at once. Blocks around a cleared line stay where
	# they are, even if left floating: there is no gravity.
	var lines := Rules.full_lines_through(grid, placed)
	var cleared := {}
	var lengths: Array = []
	for line in lines:
		lengths.append(line.cells.size())
		for c in line.cells:
			cleared[c] = true
	for c in cleared:
		grid.set_filled(c, false)

	if lines.is_empty():
		streak = 0
	else:
		streak += 1
		longest_streak = maxi(longest_streak, streak)
		best_combo = maxi(best_combo, lines.size())
		lines_cleared_total += lines.size()

	var breakdown: Dictionary = scoring.score_placement(lengths, streak)
	score += int(breakdown.total)

	if not lines.is_empty():
		lines_cleared.emit(lines, cleared.keys())

	# Clears resolve before the game-over check.
	if _tray_is_empty():
		_refill()
	else:
		check_game_over()

	return {
		"ok": true,
		"piece": piece,
		"origin": origin,
		"placed": placed,
		"lines": lines,
		"cleared": cleared.keys(),
		"score": breakdown,
		"game_over": is_over,
	}


## Ends the game if no remaining tray piece fits anywhere, including spots
## hidden from the current view. Returns true when the game is over.
func check_game_over() -> bool:
	if is_over:
		return true
	for piece in tray:
		if piece != null and Rules.has_any_legal(grid, piece):
			return false
	is_over = true
	game_over.emit(score)
	return true


## JSON-safe snapshot for auto-save. Restore with from_dict().
func to_dict() -> Dictionary:
	var ids: Array = []
	for piece in tray:
		ids.append("" if piece == null else piece.id)
	return {
		"version": SAVE_VERSION,
		"config": config.signature(),
		"grid": {
			"size": [grid.width, grid.depth, grid.height],
			"cells": grid.to_array(),
		},
		"tray": ids,
		"score": score,
		"streak": streak,
		"longest_streak": longest_streak,
		"best_combo": best_combo,
		"lines_cleared_total": lines_cleared_total,
		"moves": moves,
		"is_over": is_over,
		# 64-bit state does not survive JSON numbers, so store it as text.
		"rng_state": str(dealer.rng.state),
	}


## Restores a snapshot from to_dict(). Returns false if it does not fit this
## game's config (another save version, a changed config, a different grid
## size or unknown pieces); the game is then left unchanged.
func from_dict(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Saved game is version %s, not %d; not restored" % [data.get("version"), SAVE_VERSION])
		return false
	if str(data.get("config", "")) != config.signature():
		push_warning("Saved game was made with a different config; not restored")
		return false
	var saved_grid: Dictionary = data.get("grid", {})
	var saved_size: Array = saved_grid.get("size", [])
	if saved_size.size() != 3 \
			or int(saved_size[0]) != grid.width \
			or int(saved_size[1]) != grid.depth \
			or int(saved_size[2]) != grid.height:
		push_warning("Saved game has a different grid size; not restored")
		return false
	var saved_cells: Array = saved_grid.get("cells", [])
	if saved_cells.size() != grid.cell_count():
		push_warning("Saved game grid is incomplete; not restored")
		return false

	var saved_tray: Array = data.get("tray", [])
	if saved_tray.size() != config.tray_size:
		push_warning("Saved game has a different tray size; not restored")
		return false
	var restored_tray: Array = []
	for id in saved_tray:
		if str(id) == "":
			restored_tray.append(null)
			continue
		var piece = config.piece_by_id(str(id))
		if piece == null:
			push_warning("Saved game uses unknown piece '%s'; not restored" % id)
			return false
		restored_tray.append(piece)

	grid.load_array(saved_cells)
	tray = restored_tray
	score = int(data.get("score", 0))
	streak = int(data.get("streak", 0))
	longest_streak = int(data.get("longest_streak", 0))
	best_combo = int(data.get("best_combo", 0))
	lines_cleared_total = int(data.get("lines_cleared_total", 0))
	moves = int(data.get("moves", 0))
	is_over = bool(data.get("is_over", false))
	dealer.rng.state = str(data.get("rng_state", "0")).to_int()
	return true


func _refill() -> void:
	tray = dealer.deal(grid)
	tray_refilled.emit(tray)
	check_game_over()


func _tray_is_empty() -> bool:
	for piece in tray:
		if piece != null:
			return false
	return true
