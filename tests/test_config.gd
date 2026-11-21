extends "res://tests/q_test.gd"

const Config := preload("res://core/config.gd")
const Piece := preload("res://core/piece.gd")


func test_loads_default_files() -> void:
	var cfg := Config.new()
	check_eq(cfg.grid_size, Vector3i(6, 6, 12))
	check_eq(cfg.tray_size, 3)
	check_eq(cfg.pieces.size(), 7)
	check_eq(cfg.points_per_cube_cleared, 10)


func test_piece_sizes() -> void:
	var cfg := Config.new()
	check_eq(cfg.piece_by_id("cube2").size, Vector3i(2, 2, 2))
	check_eq(cfg.piece_by_id("cube2").cube_count(), 8)
	check_eq(cfg.piece_by_id("bar4_x").size, Vector3i(4, 1, 1))
	check_eq(cfg.piece_by_id("bar4_up").size, Vector3i(1, 1, 4))
	check_eq(cfg.piece_by_id("bar2_y").size, Vector3i(1, 2, 1))


func test_unknown_piece_is_null() -> void:
	check(Config.new().piece_by_id("nope") == null)


func test_piece_cells_are_normalized() -> void:
	var piece := Piece.new({"id": "shifted", "cells": [[3, 2, 5], [4, 2, 5]]})
	check_eq(piece.cells[0], Vector3i(0, 0, 0))
	check_eq(piece.cells[1], Vector3i(1, 0, 0))
	check_eq(piece.size, Vector3i(2, 1, 1))


func test_overrides_fall_back_to_defaults() -> void:
	var cfg := Config.new({"grid": {"width": 4}}, {"pieces": [{"id": "dot", "cells": [[0, 0, 0]]}]})
	check_eq(cfg.grid_size, Vector3i(4, 6, 12))
	check_eq(cfg.max_rerolls, 5)
	check_eq(cfg.pieces.size(), 1)
