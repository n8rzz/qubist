extends "res://tests/q_test.gd"
## Whether the tutorial and the one-time hints have been shown (#29).

const Onboarding := preload("res://core/onboarding.gd")
const SaveFile := preload("res://core/save_file.gd")

const TEST_PATH := "user://test_saves/onboarding.json"


func test_starts_with_nothing_seen() -> void:
	var onboarding := Onboarding.new()
	check(not onboarding.tutorial_done)
	for hint in Onboarding.HINTS:
		check(not onboarding.has_seen(hint), hint)


func test_tutorial_starts_on_its_own_for_new_players_only() -> void:
	var onboarding := Onboarding.new()
	check(onboarding.should_auto_start(0, false), "new player")
	check(not onboarding.should_auto_start(1, false), "has finished a game")
	check(not onboarding.should_auto_start(0, true), "has a game going")
	onboarding.tutorial_done = true
	check(not onboarding.should_auto_start(0, false), "already done or skipped")


func test_each_hint_is_seen_once() -> void:
	var onboarding := Onboarding.new()
	check(onboarding.see("rotate"), "first time")
	check(not onboarding.see("rotate"), "second time")
	check(onboarding.has_seen("rotate"))
	check(not onboarding.has_seen("zoom"))


func test_round_trips_through_the_save_file() -> void:
	var onboarding := Onboarding.new()
	onboarding.tutorial_done = true
	onboarding.see("swiper")
	check(SaveFile.write(TEST_PATH, onboarding.to_dict()), "written")
	var loaded := Onboarding.new()
	loaded.from_dict(SaveFile.read(TEST_PATH))
	check(loaded.tutorial_done)
	check(loaded.has_seen("swiper"))
	check(not loaded.has_seen("rotate"))
	SaveFile.remove(TEST_PATH)


func test_bad_values_count_as_not_seen() -> void:
	var onboarding := Onboarding.new()
	onboarding.from_dict({"tutorial_done": "yes", "hints_seen": ["rotate", 3, "nope", "rotate"]})
	check(not onboarding.tutorial_done)
	check(onboarding.has_seen("rotate"))
	check_eq(onboarding.to_dict().hints_seen, ["rotate"])
	onboarding.from_dict({"hints_seen": "rotate"})
	check(not onboarding.has_seen("rotate"))
