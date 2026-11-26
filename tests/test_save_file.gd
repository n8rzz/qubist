extends "res://tests/q_test.gd"

const SaveFile := preload("res://core/save_file.gd")

## Every file these tests make lives under here, and is removed afterward.
const TEST_DIR := "user://test_saves/save_file"


## Collects every error and warning the engine logs while it's added with
## OS.add_logger().
class ErrorLog:
	extends Logger
	var entries: Array[String] = []

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		_error_type: Logger.ErrorType,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		entries.append(
			"%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function]
		)


func test_json_array_reads_as_empty() -> void:
	_clean_up()
	var path := TEST_DIR + "/array.json"
	# An array of objects is still not a save file's top-level object.
	for text in ["[1, 2, 3]", "[]", '[{"best_score": 5}]']:
		check(_write_raw(path, text), "can create the test file")
		check_eq(SaveFile.read(path), {}, "%s reads as {}" % text)
	_clean_up()


func test_write_creates_missing_folders() -> void:
	_clean_up()
	var path := TEST_DIR + "/new/deeper/data.json"
	check(not DirAccess.dir_exists_absolute(path.get_base_dir()), "the folders start missing")
	check(SaveFile.write(path, {"name": "deep"}), "write succeeds")
	check(FileAccess.file_exists(path), "the file was written")
	check(not FileAccess.file_exists(path + ".tmp"), "the temporary file was renamed away")
	check_eq(SaveFile.read(path), {"name": "deep"})
	_clean_up()


func test_remove_missing_file_does_nothing() -> void:
	_clean_up()
	var path := TEST_DIR + "/missing.json"
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	SaveFile.remove(path)
	OS.remove_logger(errors)
	check(not FileAccess.file_exists(path), "nothing was created")
	check_eq(errors.entries, [] as Array[String], "remove() logged nothing")
	_clean_up()


func test_error_log_sees_warnings() -> void:
	# Proves the check above can fail: ErrorLog does catch what the engine logs.
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	push_warning("expected warning from test_save_file.gd")
	OS.remove_logger(errors)
	check_eq(errors.entries.size(), 1, "the warning was caught")


## Writes `text` to `path` as is, creating its folder. Returns true on success.
func _write_raw(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


## Deletes TEST_DIR and everything in it.
func _clean_up() -> void:
	_remove_tree(TEST_DIR)
	check(not DirAccess.dir_exists_absolute(TEST_DIR), "%s was cleaned up" % TEST_DIR)


func _remove_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
