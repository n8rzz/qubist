extends "res://tests/q_test.gd"
## The shared sky view (#168): what shows, the crossfade and its colours.

const SkyView := preload("res://game/sky_view.gd")
const SkyClock := preload("res://core/sky_clock.gd")
const SkyWeather := preload("res://game/sky_weather.gd")
const Settings := preload("res://core/settings.gd")
const IslandArt := preload("res://game/island_art.gd")
const UI := preload("res://game/ui_style.gd")


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
	check_eq([layers[0].season, layers[0].time], ["spring", "day"], "outgoing view first")
	check_eq([layers[1].season, layers[1].time], ["fall", "sunset"], "incoming view second")
	check(is_equal_approx(layers[0].weight + layers[1].weight, 1.0), "weights add to 1")
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


func test_start_shows_the_settings_at_once() -> void:
	SkyView.show("spring", "day")
	var settings := Settings.new()
	settings.sky_follows_day = false
	settings.sky_season = "fall"
	settings.sky_time = "sunset"
	SkyView.start(settings)
	check_eq([SkyView.season, SkyView.time_of_day], ["fall", "sunset"], "shows the pick")
	check(not SkyView.is_fading(), "no crossfade")
	_reset()


func test_follow_clock_checks_every_interval() -> void:
	var settings := Settings.new()
	settings.sky_follows_day = false
	settings.sky_season = "summer"
	settings.sky_time = "day"
	SkyView.start(settings)
	# The clock picks a view only while the sky follows the day.
	settings.sky_follows_day = true
	var clock := SkyClock.now()
	SkyView.follow_clock(SkyView.CLOCK_CHECK_SECONDS - 1.0)
	check_eq([SkyView.season, SkyView.time_of_day], ["summer", "day"], "not yet")
	SkyView.follow_clock(2.0, true)
	check_eq([SkyView.season, SkyView.time_of_day], ["summer", "day"], "held")
	SkyView.follow_clock(0.0)
	check_eq([SkyView.season, SkyView.time_of_day], [clock[0], clock[1]], "checks once the hold clears")
	_reset()


func test_follow_clock_leaves_a_manual_pick() -> void:
	var settings := Settings.new()
	settings.sky_follows_day = false
	settings.sky_season = "winter"
	settings.sky_time = "night"
	SkyView.start(settings)
	SkyView.follow_clock(SkyView.CLOCK_CHECK_SECONDS * 2.0)
	check_eq([SkyView.season, SkyView.time_of_day], ["winter", "night"], "stays on the pick")
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


func test_night_light_keeps_the_tower_readable() -> void:
	SkyView.show("summer", "night", true)
	var night := SkyView.tint()
	check(night.get_luminance() >= 0.75, "night light isn't too dark (#214)")
	check(night.b > night.r, "night light stays cool")
	_reset()


func test_tree_shapes_fit_every_season() -> void:
	for key in SkyView.TREES:
		var canopy: Array = SkyView.TREES[key][1]
		if canopy.is_empty():
			continue
		for puff in SkyView.TREE_PUFFS:
			check(puff[3] < canopy.size(), "%s has a colour for every puff" % key)
	check(SkyView.TREES["fall"][1][SkyView.TREE_FALLEN_LEAF] == Color("#C8502A"), "fallen leaves stay deep red")
	for branch in SkyView.TREE_BRANCHES:
		check(branch[1].y > branch[0].y, "branches point up (y is up)")


func test_falling_petals_and_leaves_match_the_tree() -> void:
	check(SkyWeather.PETALS == SkyView.TREES["spring"][1], "petals are the spring canopy (#210)")
	var fall: Array = SkyView.TREES["fall"][1]
	check(SkyWeather.LEAVES.slice(0, fall.size()) == fall, "leaves start with the fall canopy")
	check(SkyWeather.LEAVES.has(Color("#D9A441")), "leaves keep their extra gold")


func test_cube_tops_turn_snowy_in_winter() -> void:
	var top := Color("#ECE7DD")
	var inset := Color("#F6F2EA")
	SkyView.show("winter", "day", true)
	check(SkyView.snowy_top(top).is_equal_approx(SkyView.SNOW_TOP), "snow on top in winter")
	check(SkyView.snowy_top_inset(inset).is_equal_approx(SkyView.SNOW_TOP_INSET), "snow on the inset in winter")
	SkyView.show("summer", "day", true)
	check(SkyView.snowy_top(top).is_equal_approx(top), "bare top in summer")
	check(SkyView.snowy_top_inset(inset).is_equal_approx(inset), "bare inset in summer")
	_reset()


func test_night_text_turns_light() -> void:
	SkyView.show("summer", "night", true)
	check(SkyView.text_color(Color.BLACK, Color.WHITE).is_equal_approx(Color.WHITE), "white at night")
	SkyView.show("summer", "day", true)
	check(SkyView.text_color(Color.BLACK, Color.WHITE).is_equal_approx(Color.BLACK), "dark by day")
	_reset()


func test_sky_text_is_tagged_and_coloured_now() -> void:
	SkyView.show("summer", "night", true)
	var label := Label.new()
	check(SkyView.ink(label) == label, "returns the control")
	check(label.is_in_group(SkyView.TEXT_GROUP), "tagged")
	check(label.get_theme_color("font_color").is_equal_approx(SkyView.NIGHT_INK), "coloured for night at once")
	label.free()
	_reset()


func test_sky_text_follows_the_time_of_day() -> void:
	_reset()
	var ink := SkyView.ink(Label.new())
	var muted := SkyView.muted(Label.new())
	var button := SkyView.on_sky(Button.new(), Color.RED, Color.BLUE)
	SkyView.show("winter", "night", true)
	SkyView.recolor([ink, muted, button])
	check(ink.get_theme_color("font_color").is_equal_approx(SkyView.NIGHT_INK), "ink at night")
	check(muted.get_theme_color("font_color").is_equal_approx(SkyView.NIGHT_MUTED), "muted at night")
	check(button.get_theme_color("font_pressed_color").is_equal_approx(Color.BLUE), "button states at night")
	SkyView.show("winter", "day", true)
	SkyView.recolor([ink, muted, button])
	check(ink.get_theme_color("font_color").is_equal_approx(UI.SKY_INK), "ink by day")
	check(muted.get_theme_color("font_color").is_equal_approx(UI.SKY_MUTED), "muted by day")
	check(button.get_theme_color("font_color").is_equal_approx(Color.RED), "button by day")
	for control in [ink, muted, button]:
		control.free()
	_reset()


func test_recolor_skips_untagged_controls() -> void:
	SkyView.show("summer", "night", true)
	var label := Label.new()
	label.add_theme_color_override("font_color", Color.GREEN)
	SkyView.recolor([label])
	check(label.get_theme_color("font_color").is_equal_approx(Color.GREEN), "left alone")
	label.free()
	_reset()


## #219: a white icon button on the sky turns midnight navy at night, with
## a white icon, and back again by day.
func test_sky_buttons_turn_midnight_at_night() -> void:
	SkyView.show("summer", "night", true)
	var b := SkyView.by_night(UI.icon_button("home", "Home")) as Button
	check(b.is_in_group(SkyView.NIGHT_GROUP), "tagged")
	var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
	check(normal.bg_color.is_equal_approx(SkyView.NIGHT_CARD), "navy at once")
	check(normal.shadow_color.is_equal_approx(SkyView.NIGHT_LEDGE), "dark ledge")
	check((b.get_theme_stylebox("pressed") as StyleBoxFlat).bg_color.is_equal_approx(SkyView.NIGHT_CARD_PRESSED), "pressed")
	check(b.icon_color.is_equal_approx(SkyView.NIGHT_INK), "white icon")
	SkyView.show("summer", "day", true)
	SkyView.recolor([b])
	check(normal.bg_color.is_equal_approx(UI.WHITE), "white by day")
	check(normal.shadow_color.is_equal_approx(UI.CARD_SHADOW), "day ledge")
	check(b.icon_color.is_equal_approx(UI.SKY_INK), "ink icon by day")
	b.free()
	_reset()


## Text inside a tagged card turns light, but white text on the teal key
## stays white and colours not in the swap lists stay as they are.
func test_night_swaps_only_listed_colours() -> void:
	SkyView.show("winter", "night", true)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card(UI.WHITE, 20))
	var caption := UI.label("Best", 13, UI.SKY_MUTED)
	card.add_child(caption)
	var key := UI.text_button("X", 15)
	key.add_theme_stylebox_override("pressed", UI.accent_key(20))
	key.add_theme_color_override("font_pressed_color", UI.WHITE)
	key.add_theme_color_override("font_hover_color", Color.GREEN)
	card.add_child(key)
	SkyView.by_night(card)
	check(caption.get_theme_color("font_color").is_equal_approx(SkyView.NIGHT_MUTED), "caption lightens")
	check(key.get_theme_color("font_color").is_equal_approx(SkyView.NIGHT_INK), "key text lightens")
	check(key.get_theme_color("font_pressed_color").is_equal_approx(UI.WHITE), "white on teal stays white")
	check(key.get_theme_color("font_hover_color").is_equal_approx(Color.GREEN), "unlisted colour left alone")
	var pressed := key.get_theme_stylebox("pressed") as StyleBoxFlat
	check(pressed.bg_color.is_equal_approx(SkyView.NIGHT_ACCENT), "brighter teal")
	check(pressed.shadow_color.is_equal_approx(SkyView.NIGHT_ACCENT_LEDGE), "teal ledge")
	card.free()
	_reset()


## A box swapped in after tagging (a tray slot refilling) takes its night
## colours at the next paint_night().
func test_new_boxes_take_night_colours() -> void:
	SkyView.show("summer", "night", true)
	var slot := SkyView.by_night(PanelContainer.new())
	slot.add_theme_stylebox_override("panel", UI.card(UI.TRAY_CARD, 20))
	SkyView.paint_night(slot)
	check((slot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.is_equal_approx(SkyView.NIGHT_TRAY_CARD), "filled slot")
	slot.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.25), 20, Vector2.ZERO, Color(1, 1, 1, 0.7), 2))
	SkyView.paint_night(slot)
	var empty := slot.get_theme_stylebox("panel") as StyleBoxFlat
	check(empty.bg_color.is_equal_approx(Color(1, 1, 1, 0.08)), "empty slot fill")
	check(empty.border_color.is_equal_approx(Color(1, 1, 1, 0.3)), "empty slot outline")
	slot.free()
	_reset()


## Halfway through a fade to night, a card is halfway to navy.
func test_night_cards_follow_the_fade() -> void:
	SkyView.show("summer", "day", true)
	var b := SkyView.by_night(UI.icon_button("home", "Home"))
	SkyView.show("summer", "night")
	SkyView._changed_msec = Time.get_ticks_msec() - int(SkyView.CROSSFADE_SECONDS * 500.0)
	var night := SkyView.night_amount()
	check(night > 0.0 and night < 1.0, "mid-fade")
	SkyView.recolor([b])
	var expected := UI.WHITE.lerp(SkyView.NIGHT_CARD, night)
	check((b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(expected), "part way to navy")
	b.free()
	_reset()


func test_every_view_lists_its_features() -> void:
	var known := ["sun", "stars", "aurora", "moon", "birds", "geese", "mist", "blossom", "fallen_leaves",
		"firefly", "butterfly"] + SkyWeather.FALLING.keys()
	var particles := ["firefly", "butterfly"] + SkyWeather.FALLING.keys()
	check_eq(SkyView.FEATURES.size(), 16, "16 views")
	for season in ["spring", "summer", "fall", "winter"]:
		for time in ["sunrise", "day", "sunset", "night"]:
			var view := "%s %s" % [season, time]
			var features := SkyView.features(season, time)
			check(not features.is_empty(), "%s listed" % view)
			for feature in features:
				check(known.has(feature), "%s: %s is drawn somewhere" % [view, feature])
			check_eq(features.has("sun"), time != "night", "%s sun" % view)
			check_eq(features.has("stars") and features.has("moon"), time == "night", "%s stars and moon" % view)
			check_eq(features.filter(func(f): return particles.has(f)).size(), 1, "%s one kind of particle" % view)


func test_features_by_view() -> void:
	check(SkyView.features("winter", "night").has("aurora"), "aurora on winter nights")
	check(not SkyView.features("winter", "day").has("aurora"), "no aurora by day")
	check(not SkyView.features("summer", "night").has("aurora"), "no aurora in summer")
	check(SkyView.features("spring", "sunrise").has("mist"), "spring sunrise mist")
	check(SkyView.features("fall", "day").has("geese"), "geese in fall")
	check(not SkyView.features("fall", "night").has("geese"), "no geese at night")
	check(SkyView.features("summer", "night").has("firefly"), "summer night fireflies")
	check(SkyView.features("summer", "sunset").has("seed"), "summer sunset seeds")
	check(SkyView.features("summer", "day").has("butterfly"), "summer day butterflies")
	check(SkyView.features("spring", "night").has("blossom"), "spring blossom")
	check(SkyView.features("fall", "sunset").has("fallen_leaves"), "fall leaves under the tree")
	check(SkyView.features("autumn", "noon").is_empty(), "unknown view shows nothing")


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
	check(not sheet.christmas_button.visible, "no Christmas switch while following the day")
	sheet.set_switch("sky_follows_day", false)
	check(sheet.sky_choices.get_parent().visible, "shown when not")
	check(sheet.christmas_button.visible, "the Christmas switch shows with the pickers")
	var toggled := []
	sheet.setting_toggled.connect(func(key, on): toggled.append([key, on]))
	sheet.christmas_button.button_pressed = true
	check_eq(toggled, [["sky_christmas", true]], "turning Christmas on reports it")
	sheet.free()


## Christmas (#198): the date decides while the sky follows the day, and the
## player's switch decides while it doesn't.
func test_christmas_follows_settings() -> void:
	var settings := Settings.new()
	check_eq(SkyView.christmas_for(settings), SkyClock.christmas_now(), "the date decides by default")
	settings.sky_christmas = true
	check_eq(SkyView.christmas_for(settings), SkyClock.christmas_now(), "the switch is ignored while following the day")
	settings.sky_follows_day = false
	check(SkyView.christmas_for(settings), "the switch turns Santa on")
	SkyView.follow(settings, true)
	check(SkyView.christmas, "follow puts Santa in the sky")
	settings.sky_christmas = false
	SkyView.follow(settings, true)
	check(not SkyView.christmas, "and takes him out")
	_reset()
