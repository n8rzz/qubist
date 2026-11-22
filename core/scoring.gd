extends RefCounted
## Points for one placement. Only clearing lines scores; a placement that
## clears nothing is worth 0.
##
##   (points_per_cube_cleared × cubes in all cleared lines) × number of lines
## + streak_bonus × (streak − 1), when this placement cleared a line
##
## A cube shared by two cleared lines counts toward both. Vertical lines hold
## 12 cubes and horizontal lines 6, so a vertical line is worth double.

var points_per_cube_cleared := 10
var streak_bonus := 50


func _init(config = null) -> void:
	if config != null:
		points_per_cube_cleared = config.points_per_cube_cleared
		streak_bonus = config.streak_bonus


## `line_lengths`: the cube count of each line cleared by this placement.
## `streak`: placements in a row that cleared a line, including this one.
func score_placement(line_lengths: Array, streak: int) -> Dictionary:
	var lines := line_lengths.size()
	var cubes_in_lines := 0
	for length in line_lengths:
		cubes_in_lines += int(length)
	var line_points := points_per_cube_cleared * cubes_in_lines * lines
	var bonus := 0
	if lines > 0 and streak > 1:
		bonus = streak_bonus * (streak - 1)
	return {
		"lines": lines,
		"combo": lines,
		"line_points": line_points,
		"streak": streak,
		"streak_bonus": bonus,
		"total": line_points + bonus,
	}
