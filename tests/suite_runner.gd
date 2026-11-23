extends RefCounted
## Runs the test_ methods of one suite and reports which passed.
##
## A test fails when one of its checks fails, and also when it hits a script
## error (a null access, a call to a missing method…). GDScript stops the
## method at the error and carries on, so without this the test would pass.
## Warnings and push_error() messages don't fail a test: some tests trigger
## them on purpose.


## Records the script errors the engine logs, into the innermost open
## capture, so a suite run from inside a test keeps its errors to itself.
class ScriptErrorLog extends Logger:
	var _mutex := Mutex.new()
	var _captures: Array = []

	func begin() -> void:
		_mutex.lock()
		_captures.append([])
		_mutex.unlock()

	## Closes the innermost capture and returns what it caught.
	func end() -> Array:
		_mutex.lock()
		var caught: Array = _captures.pop_back()
		_mutex.unlock()
		return caught

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: Logger.ErrorType, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		if not _captures.is_empty():
			_captures[-1].append("script error: %s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line])
		_mutex.unlock()


static var _errors: ScriptErrorLog


## Runs every test_ method of `script`, named `label` in messages. Returns
## { "results": [[method name, passed], …], "failures": [message, …] }.
static func run(script: GDScript, label: String) -> Dictionary:
	if _errors == null:
		_errors = ScriptErrorLog.new()
		OS.add_logger(_errors)
	var results: Array = []
	var suite = script.new()
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		suite.current = "%s::%s" % [label, method_name]
		var before: int = suite.failures.size()
		_errors.begin()
		suite.call(method_name)
		for error in _errors.end():
			suite.failures.append("%s: %s" % [suite.current, error])
		results.append([method_name, suite.failures.size() == before])
	return {"results": results, "failures": suite.failures}


## Removes the error log. Call once, when every suite has run.
static func finish() -> void:
	if _errors != null:
		OS.remove_logger(_errors)
		_errors = null
