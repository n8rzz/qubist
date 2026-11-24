extends RefCounted
## Player settings kept on the device (#20): the Sound and feel switches,
## the music and sound effects volumes (#165), the grid ticks switch (#56)
## the tips switch (#164), the usage data switch (#31) and the sky (#168):
## whether it follows the device's date and clock, and the season and time of
## day to show when it doesn't.
##
## Music and sound effects drive game/audio.gd (#26); haptics drives
## game/haptics.gd (#27).

const SkyClock := preload("res://core/sky_clock.gd")

const SAVE_VERSION := 1

## Every on/off setting with its default.
const DEFAULTS := {
	"music": true,
	"sound_effects": true,
	"haptics": true,
	"grid_ticks": false,
	"tips": true,
	"analytics": true,
	"sky_follows_day": true,
}

## Every choice setting with its default; each must be one of CHOICES[key].
const CHOICE_DEFAULTS := {
	"sky_season": "spring",
	"sky_time": "day",
}
const CHOICES := {
	"sky_season": SkyClock.SEASONS,
	"sky_time": SkyClock.TIMES,
}

## Every volume, 0 (silent) to 1 (full), with its default.
const VOLUME_DEFAULTS := {
	"music_volume": 1.0,
	"sound_effects_volume": 1.0,
}

var music := true
var sound_effects := true
var haptics := true
## Show tick marks on the tower's border, to make distances easier to count.
var grid_ticks := false
var music_volume := 1.0
var sound_effects_volume := 1.0
## Show the one-time tip popups during play (#29). Off keeps them hidden.
var tips := true
## Send anonymous gameplay events and error reports (core/analytics.gd).
var analytics := true
## The sky matches the season and time of day (#168). Off shows sky_season
## and sky_time instead.
var sky_follows_day := true
var sky_season := "spring"
var sky_time := "day"


func to_dict() -> Dictionary:
	var data := {"version": SAVE_VERSION}
	for key in DEFAULTS:
		data[key] = get(key)
	for key in VOLUME_DEFAULTS:
		data[key] = get(key)
	for key in CHOICE_DEFAULTS:
		data[key] = get(key)
	return data


## Restores from to_dict(). A missing or malformed value keeps the default;
## a volume out of range is clamped to 0–1, and a choice that isn't one of
## its CHOICES falls back to the default.
func from_dict(data: Dictionary) -> void:
	for key in DEFAULTS:
		var value = data.get(key)
		set(key, value if value is bool else DEFAULTS[key])
	for key in VOLUME_DEFAULTS:
		var value = data.get(key)
		var is_number := value is float or value is int
		set(key, clampf(value, 0.0, 1.0) if is_number else VOLUME_DEFAULTS[key])
	for key in CHOICE_DEFAULTS:
		var value = data.get(key)
		set(key, value if value is String and (CHOICES[key] as Array).has(value) else CHOICE_DEFAULTS[key])
