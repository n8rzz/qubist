extends "res://tests/q_test.gd"
## Player settings and the save file they live in (#20, #56).

const Settings := preload("res://core/settings.gd")
const SaveFile := preload("res://core/save_file.gd")

const TEST_PATH := "user://test_saves/settings.json"


func test_defaults() -> void:
	var settings := Settings.new()
	check_eq(settings.music, true, "music")
	check_eq(settings.sound_effects, true, "sound effects")
	check_eq(settings.haptics, true, "haptics")
	check_eq(settings.grid_ticks, false, "grid ticks")
	check_eq(settings.tips, true, "tips")


func test_round_trips_through_the_save_file() -> void:
	var settings := Settings.new()
	settings.music = false
	settings.sound_effects = false
	settings.haptics = false
	settings.grid_ticks = true
	settings.tips = false
	check(SaveFile.write(TEST_PATH, settings.to_dict()), "settings were written")
	var loaded := Settings.new()
	loaded.from_dict(SaveFile.read(TEST_PATH))
	check_eq(loaded.music, false, "music")
	check_eq(loaded.sound_effects, false, "sound effects")
	check_eq(loaded.haptics, false, "haptics")
	check_eq(loaded.grid_ticks, true, "grid ticks")
	check_eq(loaded.tips, false, "tips")
	SaveFile.remove(TEST_PATH)


func test_missing_or_bad_values_keep_the_default() -> void:
	var settings := Settings.new()
	settings.from_dict({})
	check_eq(settings.grid_ticks, false, "missing")
	check_eq(settings.music, true, "missing music")
	settings.from_dict({"grid_ticks": "yes", "haptics": 0})
	check_eq(settings.grid_ticks, false, "not a bool")
	check_eq(settings.haptics, true, "a number")


## A save from before #20 holds only grid_ticks; the new switches start on.
func test_older_save_keeps_its_grid_ticks() -> void:
	var settings := Settings.new()
	settings.from_dict({"version": 1, "grid_ticks": true})
	check_eq(settings.grid_ticks, true, "grid ticks")
	check_eq(settings.sound_effects, true, "sound effects")


## A save from before #164 has no tips value; tips start on.
func test_older_save_shows_tips() -> void:
	var settings := Settings.new()
	settings.from_dict({"version": 1, "music": false})
	check_eq(settings.tips, true, "tips")
