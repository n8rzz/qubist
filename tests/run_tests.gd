extends SceneTree
## Runs every tests/test_*.gd suite.
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Exits with code 0 when all tests pass and 1 otherwise. A script error
## inside a test fails that test (see tests/suite_runner.gd).

const SuiteRunner := preload("res://tests/suite_runner.gd")
const TEST_DIR := "res://tests"


func _init() -> void:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()

	var total := 0
	var failures: Array[String] = []
	for file in files:
		print(file)
		var script = load("%s/%s" % [TEST_DIR, file])
		if not script is GDScript or not script.can_instantiate():
			failures.append("%s: could not load (see the script error above)" % file)
			print("  FAIL could not load")
			continue
		var run := SuiteRunner.run(script, file.get_basename())
		for result in run.results:
			total += 1
			print("  %s %s" % ["ok  " if result[1] else "FAIL", result[0]])
		failures.append_array(run.failures)
	SuiteRunner.finish()

	print("")
	if failures.is_empty():
		print("All %d tests passed." % total)
	else:
		print("%d failed checks across %d tests:" % [failures.size(), total])
		for failure in failures:
			print("  - " + failure)
	quit(0 if failures.is_empty() else 1)
