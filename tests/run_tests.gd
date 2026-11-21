extends SceneTree
## Runs every tests/test_*.gd suite.
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Exits with code 0 when all tests pass and 1 otherwise.

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
		var suite = script.new()
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			suite.current = "%s::%s" % [file.get_basename(), method_name]
			var before: int = suite.failures.size()
			suite.call(method_name)
			total += 1
			var passed: bool = suite.failures.size() == before
			print("  %s %s" % ["ok  " if passed else "FAIL", method_name])
		failures.append_array(suite.failures)

	print("")
	if failures.is_empty():
		print("All %d tests passed." % total)
	else:
		print("%d failed checks across %d tests:" % [failures.size(), total])
		for failure in failures:
			print("  - " + failure)
	quit(0 if failures.is_empty() else 1)
