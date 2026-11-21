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
