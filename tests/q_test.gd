extends RefCounted
## Base class for test suites. Each method whose name starts with "test_" is
## run by tests/run_tests.gd. Failed checks are collected, not thrown.

## The bars in config/pieces.json, by size (x, y, h). They're dealt with
## "orientations": "all", so look them up with `find_piece()`, not by id.
const BAR2_X := Vector3i(2, 1, 1)
const BAR2_Y := Vector3i(1, 2, 1)
const BAR2_UP := Vector3i(1, 1, 2)
const BAR4_X := Vector3i(4, 1, 1)
const BAR4_Y := Vector3i(1, 4, 1)
const BAR4_UP := Vector3i(1, 1, 4)

var failures: Array[String] = []
var current := ""


func check(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("%s: %s" % [current, message if message != "" else "check failed"])


func check_eq(actual, expected, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		var note := (" (%s)" % message) if message != "" else ""
		failures.append(
			"%s: expected %s, got %s%s" % [current, var_to_str(expected), var_to_str(actual), note]
		)


## The piece in `cfg` with this id (a String) or size (a Vector3i), or null.
static func find_piece(cfg, key):
	return cfg.piece_by_size(key) if key is Vector3i else cfg.piece_by_id(key)


## Fills each cell in `cells`.
static func fill(grid, cells: Array) -> void:
	for c in cells:
		grid.set_filled(c, true)


## Fills every layer in a checkerboard ((x + y) even), so no 2x2 footprint is
## ever empty but every other column stays open.
static func checkerboard(grid) -> void:
	for h in range(grid.height):
		for y in range(grid.depth):
			for x in range(grid.width):
				if (x + y) % 2 == 0:
					grid.set_filled(Vector3i(x, y, h), true)
