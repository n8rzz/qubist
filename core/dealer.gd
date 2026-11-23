extends RefCounted
## Deals trays of pieces, weighted by each piece's `weight`.
##
## A dealt set is rerolled (up to `max_rerolls` times) when none of its pieces
## has a legal spot on the current grid, so impossible sets are rare but the
## game can still end. Seed the generator for repeatable games and tests.

const Rules := preload("res://core/rules.gd")

var tray_size := 3
var max_rerolls := 5
var rng := RandomNumberGenerator.new()

var _pieces: Array = []
var _total_weight := 0.0


func _init(pieces: Array, p_tray_size: int = 3, p_max_rerolls: int = 5, seed_value: int = -1) -> void:
	assert(not pieces.is_empty(), "Dealer needs at least one piece")
	_pieces = pieces
	tray_size = p_tray_size
	max_rerolls = p_max_rerolls
	for piece in pieces:
		_total_weight += maxf(piece.weight, 0.0)
	assert(_total_weight > 0.0, "Piece weights must add up to more than 0")
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func pick():
	var roll := rng.randf() * _total_weight
	# Floating-point leftovers can let the roll fall through, so remember the
	# last piece that can be picked and return it at the end.
	var last_pickable = _pieces[-1]
	for piece in _pieces:
		var w := maxf(piece.weight, 0.0)
		if w <= 0.0:
			continue
		last_pickable = piece
		roll -= w
		if roll < 0.0:
			return piece
	return last_pickable


func deal(grid) -> Array:
	var tray: Array = []
	for _attempt in range(max_rerolls + 1):
		tray = []
		for _i in range(tray_size):
			tray.append(pick())
		for piece in tray:
			if Rules.has_any_legal(grid, piece):
				return tray
	return tray
