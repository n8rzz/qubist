extends RefCounted
## Game settings and piece definitions, loaded from config/*.json.
##
## Pass dictionaries to the constructor to override the files (used by tests);
## anything left out falls back to the defaults below.

const Piece := preload("res://core/piece.gd")

const DEFAULT_GAME_PATH := "res://config/game.json"
const DEFAULT_PIECES_PATH := "res://config/pieces.json"

var grid_size := Vector3i(6, 6, 12)
var tray_size := 3
var max_rerolls := 5
var points_per_cube_cleared := 10
var streak_bonus := 50
var pieces: Array = []

var _by_id: Dictionary = {}


func _init(game_data: Dictionary = {}, pieces_data: Dictionary = {}) -> void:
	if game_data.is_empty():
		game_data = load_json(DEFAULT_GAME_PATH)
	if pieces_data.is_empty():
		pieces_data = load_json(DEFAULT_PIECES_PATH)
	apply(game_data, pieces_data)


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read config file %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config file %s is not a JSON object" % path)
		return {}
	return parsed


func apply(game_data: Dictionary, pieces_data: Dictionary) -> void:
	var grid: Dictionary = game_data.get("grid", {})
	grid_size = Vector3i(
		int(grid.get("width", 6)),
		int(grid.get("depth", 6)),
		int(grid.get("height", 12)))
	tray_size = int(game_data.get("tray_size", 3))

	var dealer: Dictionary = game_data.get("dealer", {})
	max_rerolls = int(dealer.get("max_rerolls", 5))

	var scoring: Dictionary = game_data.get("scoring", {})
	points_per_cube_cleared = int(scoring.get("points_per_cube_cleared", 10))
	streak_bonus = int(scoring.get("streak_bonus", 50))

	pieces.clear()
	_by_id.clear()
	for entry in pieces_data.get("pieces", []):
		var piece := Piece.new(entry)
		if _by_id.has(piece.id):
			push_error("Duplicate piece id '%s'" % piece.id)
			continue
		pieces.append(piece)
		_by_id[piece.id] = piece


## Short fingerprint of everything a saved game depends on: grid size, tray
## size and every piece's id and cells. A save made under a different
## signature is not resumed (#18). Scoring numbers are left out, since a
## save still plays correctly when only they change.
func signature() -> String:
	var parts: Array = [grid_size, tray_size]
	for piece in pieces:
		parts.append([piece.id, piece.cells])
	return str(parts).sha256_text().substr(0, 16)


## Returns the piece with this id, or null.
func piece_by_id(id: String):
	return _by_id.get(id)
