extends "res://tests/q_test.gd"
## Not run on its own (the runner only picks up tests/test_*.gd):
## tests/test_suite_runner.gd runs it to prove script errors fail a test.


func test_passes() -> void:
	check(true)


func test_hits_a_script_error() -> void:
	var missing = null
	missing.land()
	check(true, "never reached")


func test_warns_on_purpose() -> void:
	push_warning("expected warning from tests/fixtures/crashing_suite.gd")
	push_error("expected error from tests/fixtures/crashing_suite.gd")
