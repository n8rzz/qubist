extends "res://tests/q_test.gd"
## Picking the sky's season and time of day from the date and clock (#168).

const SkyClock := preload("res://core/sky_clock.gd")


func test_seasons_by_month_in_the_north() -> void:
	check_eq(SkyClock.season_for(1), "winter", "January")
	check_eq(SkyClock.season_for(3), "spring", "March")
	check_eq(SkyClock.season_for(5), "spring", "May")
	check_eq(SkyClock.season_for(6), "summer", "June")
	check_eq(SkyClock.season_for(9), "fall", "September")
	check_eq(SkyClock.season_for(11), "fall", "November")
	check_eq(SkyClock.season_for(12), "winter", "December")


func test_seasons_flip_in_the_south() -> void:
	check_eq(SkyClock.season_for(1, true), "summer", "January")
	check_eq(SkyClock.season_for(4, true), "fall", "April")
	check_eq(SkyClock.season_for(7, true), "winter", "July")
	check_eq(SkyClock.season_for(10, true), "spring", "October")


func test_every_month_has_a_season() -> void:
	for month in range(1, 13):
		check(SkyClock.SEASONS.has(SkyClock.season_for(month)), "month %d" % month)
	check_eq(SkyClock.season_for(0), "winter", "out of range is clamped")
	check_eq(SkyClock.season_for(13), "winter", "out of range is clamped")


func test_times_of_day() -> void:
	# Summer: sunrise 5:45, sunset 20:30.
	check_eq(SkyClock.time_for("summer", 3 * 60), "night", "3:00")
	check_eq(SkyClock.time_for("summer", 5 * 60 + 15), "sunrise", "5:15, glow before sunrise")
	check_eq(SkyClock.time_for("summer", 6 * 60 + 30), "sunrise", "6:30")
	check_eq(SkyClock.time_for("summer", 7 * 60), "day", "7:00")
	check_eq(SkyClock.time_for("summer", 13 * 60), "day", "13:00")
	check_eq(SkyClock.time_for("summer", 19 * 60 + 45), "sunset", "19:45")
	check_eq(SkyClock.time_for("summer", 20 * 60 + 45), "sunset", "20:45, glow after sunset")
	check_eq(SkyClock.time_for("summer", 21 * 60 + 30), "night", "21:30")
	check_eq(SkyClock.time_for("summer", 23 * 60 + 59), "night", "23:59")


func test_winter_days_are_shorter() -> void:
	# 17:30 is still day in summer but after sunset's glow in winter.
	check_eq(SkyClock.time_for("summer", 17 * 60 + 30), "day", "summer 17:30")
	check_eq(SkyClock.time_for("winter", 17 * 60 + 30), "night", "winter 17:30")
	check_eq(SkyClock.time_for("winter", 16 * 60 + 30), "sunset", "winter 16:30")


func test_every_minute_has_a_time() -> void:
	for season in SkyClock.SEASONS:
		var seen := {}
		for minute in range(0, 24 * 60, 5):
			var time := SkyClock.time_for(season, minute)
			check(SkyClock.TIMES.has(time), "%s at %d" % [season, minute])
			seen[time] = true
		check_eq(seen.size(), 4, "%s shows all four times" % season)


func test_southern_locales() -> void:
	check(SkyClock.is_southern("en_AU"), "Australia")
	check(SkyClock.is_southern("pt-BR"), "Brazil, with a dash")
	check(SkyClock.is_southern("es_AR"), "Argentina")
	check(SkyClock.is_southern("en_nz"), "lower case")
	check(not SkyClock.is_southern("en_US"), "United States")
	check(not SkyClock.is_southern("en"), "no region")
	check(not SkyClock.is_southern(""), "empty")


func test_view_at_a_moment() -> void:
	var july_evening := {"year": 2026, "month": 7, "day": 4, "hour": 22, "minute": 0}
	check_eq(SkyClock.view_at(july_evening, "en_US"), ["summer", "night"] as Array[String], "US, July 22:00")
	check_eq(SkyClock.view_at(july_evening, "en_AU"), ["winter", "night"] as Array[String], "Australia, July 22:00")
	var spring_noon := {"year": 2026, "month": 4, "day": 1, "hour": 12, "minute": 0}
	check_eq(SkyClock.view_at(spring_noon, "fr_FR"), ["spring", "day"] as Array[String], "France, April noon")


func test_christmas_runs_from_the_20th_to_the_26th_of_december() -> void:
	check(not SkyClock.is_christmas({"month": 12, "day": 19}), "19 December is too early")
	check(SkyClock.is_christmas({"month": 12, "day": 20}), "20 December")
	check(SkyClock.is_christmas({"month": 12, "day": 25}), "Christmas Day")
	check(SkyClock.is_christmas({"month": 12, "day": 26}), "Boxing Day")
	check(not SkyClock.is_christmas({"month": 12, "day": 27}), "27 December is too late")
	check(not SkyClock.is_christmas({"month": 6, "day": 25}), "25 June isn't Christmas")
	check(not SkyClock.is_christmas({}), "an empty date isn't Christmas")
