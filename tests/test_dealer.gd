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
	var cfg := (
		Config
		. new(
			{},
			{
				"pieces":
				[
					{"id": "never", "weight": 0.0, "cells": [[0, 0, 0]]},
					{"id": "always", "weight": 1.0, "cells": [[0, 0, 0]]},
				]
			}
		)
	)
	var dealer := Dealer.new(cfg.pieces, 3, 0, 7)
	for _i in range(200):
		check_eq(dealer.pick().id, "always")


func test_rerolls_sets_that_cannot_be_placed() -> void:
	# A 1-wide grid: "wide" never fits, "dot" always does. Most picks are
	# "wide", so without rerolls many trays would be impossible.
	var cfg := (
		Config
		. new(
			{"grid": {"width": 1, "depth": 1, "height": 2}, "dealer": {"max_rerolls": 50}},
			{
				"pieces":
				[
					{"id": "wide", "weight": 9.0, "cells": [[0, 0, 0], [1, 0, 0]]},
					{"id": "dot", "weight": 1.0, "cells": [[0, 0, 0]]},
				]
			}
		)
	)
	var grid := Grid.new(1, 1, 2)
	var dealer := Dealer.new(cfg.pieces, cfg.tray_size, cfg.max_rerolls, 3)
	for _round in range(20):
		var tray := dealer.deal(grid)
		check(
			tray.any(func(p): return Rules.has_any_legal(grid, p)),
			"tray %s has no playable piece" % [_ids(tray)]
		)


## On a full grid nothing fits, so every reroll fails. deal() still hands
## back a full tray: the last set it drew, after max_rerolls rerolls.
func test_full_tray_when_every_reroll_fails() -> void:
	var cfg := Config.new()
	var grid := Grid.new(2, 2, 2)
	for h in range(2):
		for y in range(2):
			for x in range(2):
				grid.set_filled(Vector3i(x, y, h), true)
	var dealer := Dealer.new(cfg.pieces, 3, 4, 11)
	var tray := dealer.deal(grid)
	check_eq(tray.size(), 3)
	for piece in tray:
		check(piece != null, "tray slot is empty")
		check(not Rules.has_any_legal(grid, piece), "%s fits a full grid" % piece.id)
	# Draw the same picks by hand: the first set plus 4 rerolls, 3 pieces each.
	var same := Dealer.new(cfg.pieces, 3, 4, 11)
	var picks: Array = []
	for _i in range((4 + 1) * 3):
		picks.append(same.pick())
	check_eq(_ids(tray), _ids(picks.slice(-3)), "the tray is the last set drawn")
	check_eq(dealer.rng.state, same.rng.state, "deal() drew exactly the first set and 4 rerolls")


func test_picks_follow_the_weights() -> void:
	var cfg := (
		Config
		. new(
			{},
			{
				"pieces":
				[
					{"id": "heavy", "weight": 3.0, "cells": [[0, 0, 0]]},
					{"id": "light", "weight": 1.0, "cells": [[0, 0, 0]]},
				]
			}
		)
	)
	var dealer := Dealer.new(cfg.pieces, 3, 0, 21)
	const PICKS := 4000
	var heavy := 0
	for _i in range(PICKS):
		if dealer.pick().id == "heavy":
			heavy += 1
	var share := float(heavy) / PICKS
	# Expect 75%. One standard deviation is under 1%, so 5% either way is
	# generous.
	check(
		share > 0.70 and share < 0.80,
		"heavy was picked %.1f%% of the time, expected about 75%%" % (share * 100.0)
	)
