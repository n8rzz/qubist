extends RefCounted
## Player settings kept on the device (#20): the Sound and feel switches and
## the grid ticks switch (#56) and the tips switch (#164).
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
}

var music := true
var sound_effects := true
var haptics := true
## Show tick marks on the tower's border, to make distances easier to count.
var grid_ticks := false
## Show the one-time tip popups during play (#29). Off keeps them hidden.
var tips := true


func to_dict() -> Dictionary:
	var data := {"version": SAVE_VERSION}
	for key in DEFAULTS:
		data[key] = get(key)
	return data


## Restores from to_dict(). A missing or malformed value keeps the default.
func from_dict(data: Dictionary) -> void:
	for key in DEFAULTS:
		var value = data.get(key)
		set(key, value if value is bool else DEFAULTS[key])
