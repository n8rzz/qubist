extends "res://tests/q_test.gd"
## The shared sky view (#168): what shows, the crossfade and its colours.

const SkyView := preload("res://game/sky_view.gd")
const SkyClock := preload("res://core/sky_clock.gd")
const SkyWeather := preload("res://game/sky_weather.gd")
const Settings := preload("res://core/settings.gd")
const IslandArt := preload("res://game/island_art.gd")


func _reset() -> void:
	SkyView.show("spring", "day", true)


func test_instant_show_has_no_crossfade() -> void:
	SkyView.show("winter", "night", true)
	check_eq(SkyView.season, "winter", "season")
	check_eq(SkyView.time_of_day, "night", "time")
	check(not SkyView.is_fading(), "no fade")
	check_eq(SkyView.layers().size(), 1, "one layer")
	check_eq(SkyView.night_amount(), 1.0, "night")
	check_eq(SkyView.snow_amount(), 1.0, "snow")
	_reset()


func test_a_change_crossfades() -> void:
	_reset()
	var before := SkyView.version
	SkyView.show("fall", "sunset")
	check(SkyView.version > before, "version bumps")
	check(SkyView.is_fading(), "fading")
	var layers := SkyView.layers()
	check_eq(layers.size(), 2, "two layers while fading")
	check_eq([layers[0][0], layers[0][1]], ["spring", "day"], "outgoing view first")
	check_eq([layers[1][0], layers[1][1]], ["fall", "sunset"], "incoming view second")
	check(is_equal_approx(layers[0][2] + layers[1][2], 1.0), "weights add to 1")
	_reset()


func test_showing_the_same_view_does_nothing() -> void:
	_reset()
	var before := SkyView.version
	SkyView.show("spring", "day")
	check_eq(SkyView.version, before, "no change")
	check(not SkyView.is_fading(), "no fade")


func test_unknown_views_are_ignored() -> void:
	_reset()
	SkyView.show("monsoon", "day")
	SkyView.show("spring", "noon")
	check_eq([SkyView.season, SkyView.time_of_day], ["spring", "day"], "unchanged")


func test_follows_settings() -> void:
	var settings := Settings.new()
	settings.sky_follows_day = false
	settings.sky_season = "summer"
	settings.sky_time = "sunrise"
	check_eq(SkyView.view_for(settings), ["summer", "sunrise"] as Array[String], "manual pick")
	settings.sky_follows_day = true
	check_eq(SkyView.view_for(settings), SkyClock.now(), "clock")
	settings.sky_follows_day = false
	SkyView.follow(settings, true)
	check_eq([SkyView.season, SkyView.time_of_day], ["summer", "sunrise"], "follow shows the pick")
	_reset()


func test_gradients_match_the_design_at_their_stops() -> void:
	for time in SkyView.GRADIENTS:
		for stop in SkyView.GRADIENTS[time]:
			var got := SkyView.gradient_color(time, stop[0])
			check(got.is_equal_approx(stop[1]), "%s at %.2f" % [time, stop[0]])
	var stops := SkyView.gradient_stops()
	check_eq(stops[0], 0.0, "starts at the top")
	check_eq(stops[-1], 1.0, "ends at the bottom")


func test_island_colours_by_season() -> void:
	check(SkyView.season_color("winter", IslandArt.GRASS).is_equal_approx(Color("#EEF3F8")), "winter grass is snow")
	check(SkyView.season_color("fall", IslandArt.BUSH).is_equal_approx(Color("#D9772B")), "fall bushes are orange")
	check(SkyView.season_color("spring", IslandArt.BRICK_LEFT).is_equal_approx(IslandArt.BRICK_LEFT), "brick never changes")
	var strata := SkyView.season_color("winter", IslandArt.EARTH_STRATA)
	check(is_equal_approx(strata.a, IslandArt.EARTH_STRATA.a), "alpha is kept")


func test_night_text_turns_light() -> void:
	SkyView.show("summer", "night", true)
	check(SkyView.text_color(Color.BLACK, Color.WHITE).is_equal_approx(Color.WHITE), "white at night")
	SkyView.show("summer", "day", true)
	check(SkyView.text_color(Color.BLACK, Color.WHITE).is_equal_approx(Color.BLACK), "dark by day")
	_reset()


func test_particles_by_view() -> void:
	check_eq(SkyWeather.kinds_for("spring", "night"), ["petal"] as Array[String], "spring")
	check_eq(SkyWeather.kinds_for("fall", "day"), ["leaf"] as Array[String], "fall")
	check_eq(SkyWeather.kinds_for("winter", "sunset"), ["snow"] as Array[String], "winter")
	check_eq(SkyWeather.kinds_for("summer", "night"), ["firefly"] as Array[String], "summer night")
	check_eq(SkyWeather.kinds_for("summer", "sunset"), ["seed"] as Array[String], "summer sunset")
	check_eq(SkyWeather.kinds_for("summer", "day"), ["butterfly"] as Array[String], "summer day")


func test_falling_particles_fall_and_loop() -> void:
	for kind in SkyWeather.FALLING:
		for i in 5:
			var a: Array = SkyWeather.falling_at(kind, i, 0.0)
			var b: Array = SkyWeather.falling_at(kind, i, 0.5)
			var p: float = a[2]
			if p < 0.9:
				check(b[0].y > a[0].y, "%s %d falls" % [kind, i])
			for step in 50:
				var at: Array = SkyWeather.falling_at(kind, i, step * 1.3)
				check(at[0].y >= -40.0 and at[0].y <= 640.0, "%s %d stays in its band" % [kind, i])


func test_still_sky_stops_the_clock() -> void:
	SkyView.still = true
	check_eq(SkyView.seconds(), 0.0, "stopped")
	SkyView.still = false
	check(SkyView.seconds() >= 0.0, "running")


## Settings › Sky (#168): one segment picked per picker, and the pickers
## show only while the sky doesn't follow the day.
func test_settings_sheet_pickers() -> void:
	var sheet = load("res://game/settings_sheet.gd").new()
	sheet.set_choice("sky_season", "winter")
	sheet.set_choice("sky_season", "fall")
	var picked := []
	for value in sheet._choices["sky_season"]:
		if sheet._choices["sky_season"][value].button_pressed:
			picked.append(value)
	check_eq(picked, ["fall"], "exactly one season picked")
	var chosen := []
	sheet.choice_changed.connect(func(key, value): chosen.append([key, value]))
	sheet._choices["sky_time"]["night"].button_pressed = true
	check_eq(chosen, [["sky_time", "night"]], "picking a time reports it")
	sheet.set_switch("sky_follows_day", true)
	check(not sheet.sky_choices.get_parent().visible, "hidden while following the day")
	sheet.set_switch("sky_follows_day", false)
	check(sheet.sky_choices.get_parent().visible, "shown when not")
	sheet.free()
