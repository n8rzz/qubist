extends RefCounted
## Placement and line rules. Pure functions over a grid and a piece.
##
## Placement: every cube lands inside the grid on an empty cell, and at least
## one cube is supported, meaning it sits on the floor (h = 0) or directly on
## top of an existing block. Side contact does not count, and a cube resting on
## another cube of the same piece does not count. Other cubes may overhang.
##
## Lines: a straight run of cells across the whole grid along X, Y or H. A line
## is full when every cell in it holds a block.

const AXIS_X := 0
const AXIS_Y := 1
const AXIS_H := 2
const AXES := [AXIS_X, AXIS_Y, AXIS_H]

const _DOWN := Vector3i(0, 0, -1)


static func can_place(grid, piece, origin: Vector3i) -> bool:
	var supported := false
	for offset in piece.cells:
		var c: Vector3i = origin + offset
		if not grid.in_bounds(c) or grid.is_filled(c):
			return false
		if c.z == 0 or grid.is_filled(c + _DOWN):
			supported = true
	return supported


## Every origin where the piece can be placed, layer by layer from the floor.
static func legal_positions(grid, piece) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for h in range(grid.height - piece.size.z + 1):
		for y in range(grid.depth - piece.size.y + 1):
			for x in range(grid.width - piece.size.x + 1):
				var origin := Vector3i(x, y, h)
				if can_place(grid, piece, origin):
					out.append(origin)
	return out


static func has_any_legal(grid, piece) -> bool:
	for h in range(grid.height - piece.size.z + 1):
		for y in range(grid.depth - piece.size.y + 1):
			for x in range(grid.width - piece.size.x + 1):
				if can_place(grid, piece, Vector3i(x, y, h)):
					return true
	return false


## The cells of the line along `axis` that passes through `through`.
static func line_cells(grid, axis: int, through: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	match axis:
		AXIS_X:
			for x in range(grid.width):
				out.append(Vector3i(x, through.y, through.z))
		AXIS_Y:
			for y in range(grid.depth):
				out.append(Vector3i(through.x, y, through.z))
		AXIS_H:
			for h in range(grid.height):
				out.append(Vector3i(through.x, through.y, h))
		_:
			push_error("Unknown axis %d" % axis)
	return out


static func is_full(grid, cells: Array) -> bool:
	for c in cells:
		if not grid.is_filled(c):
			return false
	return true


## Full lines that pass through any of `cells`, each listed once.
## Returns an Array of { "axis": int, "cells": Array[Vector3i] }.
static func full_lines_through(grid, cells: Array) -> Array:
	var seen := {}
	var lines: Array = []
	for c in cells:
		for axis in AXES:
			var key := _line_key(axis, c)
			if seen.has(key):
				continue
			seen[key] = true
			var run := line_cells(grid, axis, c)
			if is_full(grid, run):
				lines.append({"axis": axis, "cells": run})
	return lines


static func _line_key(axis: int, c: Vector3i) -> Vector3i:
	match axis:
		AXIS_X:
			return Vector3i(AXIS_X, c.y, c.z)
		AXIS_Y:
			return Vector3i(AXIS_Y, c.x, c.z)
		_:
			return Vector3i(AXIS_H, c.x, c.y)
