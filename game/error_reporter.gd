extends Node
## Sends the engine's errors to core/analytics.gd (#31): script errors (a
## null access, a call to a missing method…) and push_error() messages.
##
## The engine can log from any thread, so errors are queued as they happen
## and handed to analytics on the main thread each frame. This catches the
## errors the game survives. A hard crash that kills the app needs the
## provider's native SDK, which records it and sends it on the next launch.

## Most errors held between frames; any more in one frame are dropped.
const MAX_QUEUED := 50

var analytics

var _log := ErrorLog.new()


func _init(p_analytics) -> void:
	analytics = p_analytics
	name = "ErrorReporter"


func _enter_tree() -> void:
	OS.add_logger(_log)


func _exit_tree() -> void:
	OS.remove_logger(_log)


func _process(_delta: float) -> void:
	flush()


## Hands every queued error to analytics.
func flush() -> void:
	for error in _log.take():
		analytics.report_error(error[0], error[1])


class ErrorLog:
	extends Logger
	var _mutex := Mutex.new()
	var _queue: Array = []

	func take() -> Array:
		_mutex.lock()
		var out := _queue
		_queue = []
		_mutex.unlock()
		return out

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: Logger.ErrorType,
		script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		var message := rationale if rationale != "" else code
		var details := {
			"file": file.get_file(),
			"line": line,
			"function": function,
			"kind": "script" if error_type == Logger.ERROR_TYPE_SCRIPT else "engine",
		}
		# push_error() is logged from the engine's C++; the script call stack
		# says where in the game it came from. Release builds only have one
		# with Project Settings › GDScript › Always Track Call Stacks on.
		for trace in script_backtraces:
			if trace.get_frame_count() > 0:
				details.file = trace.get_frame_file(0).get_file()
				details.line = trace.get_frame_line(0)
				details.function = trace.get_frame_function(0)
				break
		_mutex.lock()
		if _queue.size() < MAX_QUEUED:
			_queue.append(["%s (%s:%d)" % [message, details.file, details.line], details])
		_mutex.unlock()
