extends RefCounted
## Player settings kept on the device (#20): the Sound and feel switches,
## the music and sound effects volumes (#165), the grid ticks switch (#56)
## the tips switch (#164) and the usage data switch (#31).
##
## Music and sound effects drive game/audio.gd (#26); haptics drives
## game/haptics.gd (#27).

const SAVE_VERSION := 1

## Every on/off setting with its default.
const DEFAULTS := {
	"music": true,
	"sound_effects": true,
	"haptics": true,
	"grid_ticks": false,
	"tips": true,
	"analytics": true,
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


func to_dict() -> Dictionary:
	var data := {"version": SAVE_VERSION}
	for key in DEFAULTS:
		data[key] = get(key)
	for key in VOLUME_DEFAULTS:
		data[key] = get(key)
	return data


## Restores from to_dict(). A missing or malformed value keeps the default;
## a volume out of range is clamped to 0–1.
func from_dict(data: Dictionary) -> void:
	for key in DEFAULTS:
		var value = data.get(key)
		set(key, value if value is bool else DEFAULTS[key])
	for key in VOLUME_DEFAULTS:
		var value = data.get(key)
		var is_number := value is float or value is int
		set(key, clampf(value, 0.0, 1.0) if is_number else VOLUME_DEFAULTS[key])
