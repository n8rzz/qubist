extends RefCounted
## Anonymous gameplay events and error reports (#31), sent to whichever
## provider is plugged in as `backend`.
##
## No provider is chosen yet, so this only defines what gets sent and when.
## A backend is any object with these two methods:
##
##   func track(event: String, props: Dictionary) -> void
##   func report_error(message: String, details: Dictionary) -> void
##
## LogBackend prints to the console; MemoryBackend keeps everything for
## tests. To add a real provider, write a backend that forwards to its SDK
## and set it as `backend` in game/main.gd.
##
## Nothing here identifies the player: no device or advertising ID, no
## account, and no ID kept between launches. Events carry only the numbers
## listed in EVENTS. That keeps the app clear of cross-app tracking, so
## there's no App Tracking Transparency prompt.

## Every event and the props it carries. track() refuses anything else, so
## nothing extra can slip into a payload.
const EVENTS := {
	## The first piece of a game was placed (not in the tutorial).
	"game_start": [],
	## A game ended. Sent once per game.
	"game_over": ["score", "moves", "lines"],
	## A tutorial step came up. `step` counts from 1, out of `of`.
	"tutorial_step": ["step", "of"],
	## The tutorial was finished (`completed` true) or skipped at `step`.
	"tutorial_end": ["completed", "step"],
	## A game in progress was left. `reason` is "new_game" (a new game
	## replaced it) or "backgrounded" (the app was sent to the background or
	## closed, so the player may still come back to it).
	"game_quit": ["score", "moves", "lines", "reason"],
}

const QUIT_NEW_GAME := "new_game"
const QUIT_BACKGROUNDED := "backgrounded"

## Most distinct errors sent in one launch, so a bug that fires every frame
## can't flood the provider.
const MAX_ERRORS_PER_LAUNCH := 20

## Off sends nothing: Settings › Share usage data (core/settings.gd).
var enabled := true
## Where events go. Null drops them.
var backend

var _errors_sent := {}


## Sends `event` with `props`. Pushes an error, and sends nothing, if the
## event isn't in EVENTS or its props don't match.
func track(event: String, props := {}) -> void:
	if not EVENTS.has(event):
		push_error("Analytics: unknown event '%s'" % event)
		return
	var expected: Array = EVENTS[event]
	if props.size() != expected.size() or not props.has_all(expected):
		push_error("Analytics: '%s' takes %s, got %s" % [event, expected, props.keys()])
		return
	if enabled and backend != null:
		backend.track(event, props)


func game_started() -> void:
	track("game_start")


## `game` is a core/game.gd instance.
func game_over(game) -> void:
	track("game_over", _game_props(game))


## `index` counts from 0, as in game/tutorial_run.gd.
func tutorial_step(index: int, count: int) -> void:
	track("tutorial_step", {"step": index + 1, "of": count})


func tutorial_ended(completed: bool, index: int) -> void:
	track("tutorial_end", {"completed": completed, "step": index + 1})


## `reason` is QUIT_NEW_GAME or QUIT_BACKGROUNDED.
func game_quit(game, reason: String) -> void:
	var props := _game_props(game)
	props["reason"] = reason
	track("game_quit", props)


## Sends an error report. The same `message` is sent once per launch, and
## at most MAX_ERRORS_PER_LAUNCH different ones. `details` should say where
## it happened (file, line, function), never anything about the player.
func report_error(message: String, details := {}) -> void:
	if not enabled or backend == null:
		return
	if _errors_sent.has(message) or _errors_sent.size() >= MAX_ERRORS_PER_LAUNCH:
		return
	_errors_sent[message] = true
	backend.report_error(message, details)


static func _game_props(game) -> Dictionary:
	return {"score": game.score, "moves": game.moves, "lines": game.lines_cleared_total}


## Prints each event and error to the console. The default in debug builds.
class LogBackend:
	func track(event: String, props: Dictionary) -> void:
		print("[analytics] %s %s" % [event, JSON.stringify(props)])

	func report_error(message: String, details: Dictionary) -> void:
		print("[analytics] error: %s %s" % [message, JSON.stringify(details)])


## Keeps every event and error, for tests.
class MemoryBackend:
	## [[event, props], …] in the order sent.
	var events: Array = []
	## [[message, details], …] in the order sent.
	var errors: Array = []

	func track(event: String, props: Dictionary) -> void:
		events.append([event, props])

	func report_error(message: String, details: Dictionary) -> void:
		errors.append([message, details])

	## The names of the events sent, in order.
	func names() -> Array:
		return events.map(func(e): return e[0])
