extends RefCounted
## Player settings kept on the device. Holds the grid ticks switch (#56) for
## now; sound and haptics join it with #20.

const SAVE_VERSION := 1

## Show tick marks on the tower's border, to make distances easier to count.
var grid_ticks := false


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"grid_ticks": grid_ticks,
	}


## Restores from to_dict(). A missing or malformed value keeps the default.
func from_dict(data: Dictionary) -> void:
	var ticks = data.get("grid_ticks", false)
	grid_ticks = ticks if ticks is bool else false
