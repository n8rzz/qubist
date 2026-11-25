extends "res://tests/q_test.gd"

const SuiteRunner := preload("res://tests/suite_runner.gd")
const CrashingSuite := preload("res://tests/fixtures/crashing_suite.gd")


func test_script_errors_fail_the_test() -> void:
	# The run below logs a script error, a warning and an error on purpose.
	var run := SuiteRunner.run(CrashingSuite, "crashing_suite")
	var passed := {}
	for result in run.results:
		passed[result[0]] = result[1]
	check_eq(passed.get("test_passes"), true, "a clean test passes")
	check_eq(passed.get("test_hits_a_script_error"), false, "a script error fails the test")
	check_eq(passed.get("test_warns_on_purpose"), true, "warnings and push_error() don't")
	check_eq(run.failures.size(), 1, "one failure, for the script error")
	if run.failures.size() == 1:
		var failure: String = run.failures[0]
		check(failure.begins_with("crashing_suite::test_hits_a_script_error: script error:"), "names the test: " + failure)
		check("crashing_suite.gd:16" in failure, "points at the line: " + failure)
