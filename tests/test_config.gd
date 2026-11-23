extends "res://tests/q_test.gd"

const Config := preload("res://core/config.gd")
const Piece := preload("res://core/piece.gd")


func test_loads_default_files() -> void:
	var cfg := Config.new()
	check_eq(cfg.grid_size, Vector3i(6, 6, 12))
	check_eq(cfg.tray_size, 3)
	check_eq(cfg.points_per_cube_cleared, 10)


## Every entry in pieces.json is loaded: plain entries as written, and
## "orientations": "all" entries once per distinct rotation.
func test_loads_every_piece_in_the_file() -> void:
	var cfg := Config.new()
	var expected := 0
	for entry in Config.load_json(Config.DEFAULT_PIECES_PATH).pieces:
		if entry.get("orientations", "") == "all":
			var turns := Piece.orientations(Piece.parse_cells(entry.cells)).size()
			expected += turns
			check(cfg.piece_by_id("%s_00" % entry.id) != null, "%s_00 is loaded" % entry.id)
			check(cfg.piece_by_id("%s_%02d" % [entry.id, turns - 1]) != null, "last %s rotation is loaded" % entry.id)
		else:
			expected += 1
			check(cfg.piece_by_id(entry.id) != null, "%s is loaded" % entry.id)
	check_eq(cfg.pieces.size(), expected)


func test_piece_sizes() -> void:
	var cfg := Config.new()
	check_eq(cfg.piece_by_id("cube2").size, Vector3i(2, 2, 2))
	check_eq(cfg.piece_by_id("cube2").cube_count(), 8)
	check_eq(cfg.piece_by_id("bar4_00").size, Vector3i(4, 1, 1), "the first bar is the one written")
	for size in [BAR2_X, BAR2_Y, BAR2_UP, BAR4_X, BAR4_Y, BAR4_UP]:
		var bar = cfg.piece_by_size(size)
		check(bar != null, "a bar of size %s is dealt" % size)
		if bar != null:
			check_eq(bar.size, size)


func test_unknown_piece_is_null() -> void:
	check(Config.new().piece_by_id("nope") == null)
	check(Config.new().piece_by_size(Vector3i(5, 5, 5)) == null)


## Each bar is dealt in three orientations whose weights add up to the
## cube's, so the cube is picked as often as either bar shape.
func test_bars_weigh_the_same_as_the_cube() -> void:
	var cfg := Config.new()
	for bar in ["bar2", "bar4"]:
		var total := 0.0
		var count := 0
		for p in cfg.pieces:
			if p.id.begins_with(bar + "_"):
				total += p.weight
				count += 1
		check_eq(count, 3, "%s lies along x, along y or upright" % bar)
		check(is_equal_approx(total, cfg.piece_by_id("cube2").weight), "%s weighs as much as cube2" % bar)


func test_piece_cells_are_normalized() -> void:
	var piece := Piece.new({"id": "shifted", "cells": [[3, 2, 5], [4, 2, 5]]})
	check_eq(piece.cells[0], Vector3i(0, 0, 0))
	check_eq(piece.cells[1], Vector3i(1, 0, 0))
	check_eq(piece.size, Vector3i(2, 1, 1))


func test_piece_cells_at_offsets_every_cell_by_the_origin() -> void:
	var piece := Piece.new({"id": "ell", "cells": [[0, 0, 0], [1, 0, 0], [0, 1, 1]]})
	var expected: Array[Vector3i] = [Vector3i(2, 3, 4), Vector3i(3, 3, 4), Vector3i(2, 4, 5)]
	check_eq(piece.cells_at(Vector3i(2, 3, 4)), expected)
	check_eq(piece.cells_at(Vector3i.ZERO), piece.cells)


func test_overrides_fall_back_to_defaults() -> void:
	var cfg := Config.new({"grid": {"width": 4}}, {"pieces": [{"id": "dot", "cells": [[0, 0, 0]]}]})
	check_eq(cfg.grid_size, Vector3i(4, 6, 12))
	check_eq(cfg.max_rerolls, 5)
	check_eq(cfg.pieces.size(), 1)


func test_all_orientations_expand_into_rotations() -> void:
	var cfg := Config.new()
	var by_shape := {}
	for piece in cfg.pieces:
		if piece.id.begins_with("L4_") or piece.id.begins_with("corner3_"):
			var key: String = piece.id.split("_")[0]
			by_shape[key] = by_shape.get(key, []) + [piece]
	check_eq(by_shape["L4"].size(), 24)
	check_eq(by_shape["corner3"].size(), 12)
	for key in by_shape:
		var total := 0.0
		var seen := {}
		for piece in by_shape[key]:
			total += piece.weight
			check(not seen.has(str(piece.cells)), "%s is listed twice" % piece.id)
			seen[str(piece.cells)] = true
		check(absf(total - 1.0) < 0.0001, "%s weights add up to 1" % key)


func test_first_orientation_is_the_one_written() -> void:
	var cfg := Config.new()
	var l4 = cfg.piece_by_id("L4_00")
	check_eq(l4.size, Vector3i(3, 2, 1))
	check_eq(l4.cube_count(), 4)
	check_eq(l4.shape, "L, 1 wide")
	check_eq(cfg.piece_by_id("corner3_00").size, Vector3i(2, 2, 1))


func test_orientations_cover_every_axis() -> void:
	var sizes := {}
	for cells in Piece.orientations([Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 1, 0)]):
		var piece := Piece.new({"id": "t", "cells": cells.map(func(c): return [c.x, c.y, c.z])})
		sizes[piece.size] = true
	# A 3x2 L can lie along any two of the three axes.
	check_eq(sizes.size(), 6)
	check(sizes.has(Vector3i(1, 2, 3)), "includes standing up")


func test_symmetric_shapes_have_fewer_orientations() -> void:
	check_eq(Piece.orientations([Vector3i(0, 0, 0), Vector3i(1, 0, 0)]).size(), 3)
	check_eq(Piece.orientations([Vector3i(0, 0, 0)]).size(), 1)


func test_plain_entries_are_not_expanded() -> void:
	var cfg := Config.new({}, {"pieces": [{"id": "dot", "cells": [[0, 0, 0]]}]})
	check_eq(cfg.pieces.size(), 1)
	check(cfg.piece_by_id("dot") != null)


## A repeated id logs a push_error and is skipped, so the first entry wins.
func test_duplicate_piece_id_keeps_the_first() -> void:
	var cfg := Config.new({}, {"pieces": [
		{"id": "dot", "cells": [[0, 0, 0]]},
		{"id": "dot", "cells": [[0, 0, 0], [1, 0, 0]]},
		{"id": "bar", "cells": [[0, 0, 0], [0, 1, 0]]},
	]})
	check_eq(cfg.pieces.size(), 2)
	check_eq(cfg.piece_by_id("dot").cube_count(), 1)
	check(cfg.piece_by_id("bar") != null, "pieces after the duplicate still load")


func test_signature_is_stable_for_the_same_data() -> void:
	var game := {"grid": {"width": 5, "depth": 4, "height": 8}, "tray_size": 2}
	var pieces := {"pieces": [{"id": "dot", "cells": [[0, 0, 0]]}]}
	check_eq(Config.new(game, pieces).signature(), Config.new(game, pieces).signature())


func test_signature_changes_with_tray_and_grid_size() -> void:
	var pieces := {"pieces": [{"id": "dot", "cells": [[0, 0, 0]]}]}
	var base := Config.new({"tray_size": 3}, pieces).signature()
	check(Config.new({"tray_size": 4}, pieces).signature() != base, "tray_size changes it")
	for axis in ["width", "depth", "height"]:
		var other := Config.new({"tray_size": 3, "grid": {axis: 20}}, pieces).signature()
		check(other != base, "grid %s changes it" % axis)


## An entry with no cells logs a push_error and is skipped, "all" or not.
func test_entry_with_no_cells_is_skipped() -> void:
	var cfg := Config.new({}, {"pieces": [
		{"id": "empty_all", "orientations": "all", "cells": []},
		{"id": "empty", "cells": []},
		{"id": "dot", "cells": [[0, 0, 0]]},
	]})
	check_eq(cfg.pieces.size(), 1)
	check(cfg.piece_by_id("empty_all") == null, "the \"all\" entry is skipped")
	check(cfg.piece_by_id("empty_all_00") == null, "the \"all\" entry isn't expanded")
	check(cfg.piece_by_id("empty") == null, "the plain entry is skipped")
	check(cfg.piece_by_id("dot") != null, "later pieces still load")
