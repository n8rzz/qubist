extends "res://tests/q_test.gd"

const Config := preload("res://core/config.gd")
const Grid := preload("res://core/grid.gd")
const Rules := preload("res://core/rules.gd")
const Dealer := preload("res://core/dealer.gd")


func _ids(pieces: Array) -> Array:
	return pieces.map(func(p): return p.id)


func test_deals_a_full_tray() -> void:
	var cfg := Config.new()
	var dealer := Dealer.new(cfg.pieces, 3, 5, 1)
	var tray := dealer.deal(Grid.new(6, 6, 12))
	check_eq(tray.size(), 3)
	for piece in tray:
		check(piece != null)


func test_same_seed_same_pieces() -> void:
	var cfg := Config.new()
	var a := Dealer.new(cfg.pieces, 3, 5, 42)
	var b := Dealer.new(cfg.pieces, 3, 5, 42)
	var grid := Grid.new(6, 6, 12)
	for _round in range(10):
		check_eq(_ids(a.deal(grid)), _ids(b.deal(grid)))


func test_zero_weight_is_never_dealt() -> void:
	var cfg := Config.new({}, {"pieces": [
		{"id": "never", "weight": 0.0, "cells": [[0, 0, 0]]},
		{"id": "always", "weight": 1.0, "cells": [[0, 0, 0]]},
	]})
	var dealer := Dealer.new(cfg.pieces, 3, 0, 7)
	for _i in range(200):
		check_eq(dealer.pick().id, "always")


func test_rerolls_sets_that_cannot_be_placed() -> void:
	# A 1-wide grid: "wide" never fits, "dot" always does. Most picks are
	# "wide", so without rerolls many trays would be impossible.
	var cfg := Config.new(
		{"grid": {"width": 1, "depth": 1, "height": 2}, "dealer": {"max_rerolls": 50}},
		{"pieces": [
			{"id": "wide", "weight": 9.0, "cells": [[0, 0, 0], [1, 0, 0]]},
			{"id": "dot", "weight": 1.0, "cells": [[0, 0, 0]]},
		]})
	var grid := Grid.new(1, 1, 2)
	var dealer := Dealer.new(cfg.pieces, cfg.tray_size, cfg.max_rerolls, 3)
	for _round in range(20):
		var tray := dealer.deal(grid)
		check(tray.any(func(p): return Rules.has_any_legal(grid, p)), "tray %s has no playable piece" % [_ids(tray)])
