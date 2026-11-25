extends RefCounted
## Lifetime stats across finished games, kept on the device (#32).
##
## Only games that reach game over count. Call record_game() once per
## finished game; a game restored from a save that was already over must not
## be recorded again.

const SAVE_VERSION := 1

var games_played := 0
## Sum of every finished game's score, for the average.
var total_score := 0
var best_score := 0
var lines_cleared := 0
## Most lines cleared by one placement, in any game.
var best_combo := 0
## Most placements in a row that each cleared a line, in any game.
var longest_streak := 0


## Adds one finished game. `game` is a core/game.gd instance.
func record_game(game) -> void:
	record(game.score, game.lines_cleared_total, game.best_combo, game.longest_streak)


func record(score: int, lines: int, combo: int, streak: int) -> void:
	games_played += 1
	total_score += score
	best_score = maxi(best_score, score)
	lines_cleared += lines
	best_combo = maxi(best_combo, combo)
	longest_streak = maxi(longest_streak, streak)


## True once a game has finished, so there is a best score to show (#118).
func has_best() -> bool:
	return games_played > 0


## Average score of finished games, rounded to a whole number; 0 before any.
func average_score() -> int:
	if games_played == 0:
		return 0
	return roundi(float(total_score) / games_played)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"games_played": games_played,
		"total_score": total_score,
		"best_score": best_score,
		"lines_cleared": lines_cleared,
		"best_combo": best_combo,
		"longest_streak": longest_streak,
	}


## Restores from to_dict(). Missing or negative fields read as 0, so a
## damaged file can't make the stats go backwards into nonsense.
func from_dict(data: Dictionary) -> void:
	games_played = _count(data, "games_played")
	total_score = _count(data, "total_score")
	best_score = _count(data, "best_score")
	lines_cleared = _count(data, "lines_cleared")
	best_combo = _count(data, "best_combo")
	longest_streak = _count(data, "longest_streak")


static func _count(data: Dictionary, key: String) -> int:
	var value = data.get(key, 0)
	if not (value is int or value is float):
		return 0
	return maxi(0, int(value))
