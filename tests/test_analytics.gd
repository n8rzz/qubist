extends "res://tests/q_test.gd"
## Anonymous events and error reports (#31).

const Analytics := preload("res://core/analytics.gd")
const ErrorReporter := preload("res://game/error_reporter.gd")
const Config := preload("res://core/config.gd")
const Game := preload("res://core/game.gd")


func _make() -> Analytics:
	var analytics := Analytics.new()
	analytics.backend = Analytics.MemoryBackend.new()
	return analytics


func test_game_events_carry_only_their_numbers() -> void:
	var analytics := _make()
	var game := Game.new(Config.new())
	game.start()
	game.score = 120
	game.moves = 9
	game.lines_cleared_total = 2
	analytics.game_started()
	analytics.game_over(game)
	analytics.game_quit(game, Analytics.QUIT_BACKGROUNDED)
	var events: Array = analytics.backend.events
	check_eq(analytics.backend.names(), ["game_start", "game_over", "game_quit"])
	check_eq(events[0][1], {}, "game_start props")
	check_eq(events[1][1], {"score": 120, "moves": 9, "lines": 2}, "game_over props")
	check_eq(events[2][1], {"score": 120, "moves": 9, "lines": 2, "reason": "backgrounded"},
		"game_quit props")


func test_tutorial_steps_count_from_one() -> void:
	var analytics := _make()
	analytics.tutorial_step(0, 3)
	analytics.tutorial_ended(false, 1)
	check_eq(analytics.backend.events, [
		["tutorial_step", {"step": 1, "of": 3}],
		["tutorial_end", {"completed": false, "step": 2}],
	])


func test_unknown_events_and_extra_props_are_refused() -> void:
	var analytics := _make()
	analytics.track("player_email")
	analytics.track("game_start", {"device": "abc"})
	analytics.track("game_over", {"score": 1})
	check_eq(analytics.backend.events, [], "nothing sent")


func test_every_event_name_is_short_and_snake_case() -> void:
	var pattern := RegEx.create_from_string("^[a-z][a-z_]{2,39}$")
	for event in Analytics.EVENTS:
		check(pattern.search(event) != null, event)


func test_switched_off_sends_nothing() -> void:
	var analytics := _make()
	analytics.enabled = false
	analytics.game_started()
	analytics.report_error("boom")
	check_eq(analytics.backend.events, [], "events")
	check_eq(analytics.backend.errors, [], "errors")


func test_no_backend_is_safe() -> void:
	var analytics := Analytics.new()
	analytics.game_started()
	analytics.report_error("boom")
	check_eq(analytics.backend, null)


func test_each_error_is_sent_once_and_capped_per_launch() -> void:
	var analytics := _make()
	analytics.report_error("boom", {"line": 1})
	analytics.report_error("boom", {"line": 1})
	check_eq(analytics.backend.errors, [["boom", {"line": 1}]], "deduped")
	for i in Analytics.MAX_ERRORS_PER_LAUNCH + 5:
		analytics.report_error("error %d" % i)
	check_eq(analytics.backend.errors.size(), Analytics.MAX_ERRORS_PER_LAUNCH, "capped")


func test_error_reporter_forwards_logged_errors() -> void:
	var analytics := _make()
	var reporter := ErrorReporter.new(analytics)
	# Not in a tree, so add the logger by hand.
	reporter._enter_tree()
	push_error("analytics test error")
	push_warning("analytics test warning")
	reporter.flush()
	reporter._exit_tree()
	reporter.free()
	var errors: Array = analytics.backend.errors
	check_eq(errors.size(), 1, "one error, no warning")
	if errors.size() == 1:
		check(errors[0][0].begins_with("analytics test error"), errors[0][0])
		check_eq(errors[0][1].file, "test_analytics.gd", "file")
		check_eq(errors[0][1].kind, "engine", "push_error is not a script error")
