extends "res://tests/q_test.gd"
## Player settings and the save file they live in (#56).

const Settings := preload("res://core/settings.gd")
const SaveFile := preload("res://core/save_file.gd")

const TEST_PATH := "user://test_saves/settings.json"


func test_grid_ticks_start_off() -> void:
	check_eq(Settings.new().grid_ticks, false)


func test_round_trips_through_the_save_file() -> void:
	var settings := Settings.new()
	settings.grid_ticks = true
	check(SaveFile.write(TEST_PATH, settings.to_dict()), "settings were written")
	var loaded := Settings.new()
	loaded.from_dict(SaveFile.read(TEST_PATH))
	check_eq(loaded.grid_ticks, true)
	SaveFile.remove(TEST_PATH)


func test_missing_or_bad_values_keep_the_default() -> void:
	var settings := Settings.new()
	settings.from_dict({})
	check_eq(settings.grid_ticks, false, "missing")
	settings.from_dict({"grid_ticks": "yes"})
	check_eq(settings.grid_ticks, false, "not a bool")
	settings.from_dict({"grid_ticks": 1})
	check_eq(settings.grid_ticks, false, "a number")
