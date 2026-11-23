extends RefCounted
## Base class for test suites. Each method whose name starts with "test_" is
## run by tests/run_tests.gd. Failed checks are collected, not thrown.

var failures: Array[String] = []
var current := ""


func check(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("%s: %s" % [current, message if message != "" else "check failed"])


func check_eq(actual, expected, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		var note := (" (%s)" % message) if message != "" else ""
		failures.append("%s: expected %s, got %s%s" % [current, var_to_str(expected), var_to_str(actual), note])


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
