extends RefCounted
## What the player has already been shown (#29): whether the tutorial was
## finished or skipped, and which one-time hints have come up.
##
## Kept apart from Settings, which holds only the switches the player sets.

const SAVE_VERSION := 1

## The one-time hints, each shown the first time its control is used.
const HINTS: Array[String] = ["rotate", "swiper", "zoom"]

## True once the tutorial has been played through or skipped.
var tutorial_done := false
var _hints_seen: Array[String] = []


## The tutorial starts on its own before the first game, for a new player
## only: one who hasn't finished a game or got a game going.
func should_auto_start(games_played: int, has_game_in_progress: bool) -> bool:
	return not tutorial_done and games_played == 0 and not has_game_in_progress


func has_seen(hint: String) -> bool:
	return hint in _hints_seen


## Marks `hint` as shown. Returns true the first time, so the caller knows
## to show it.
func see(hint: String) -> bool:
	if has_seen(hint):
		return false
	_hints_seen.append(hint)
	return true


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"tutorial_done": tutorial_done,
		"hints_seen": _hints_seen.duplicate(),
	}


## Restores from to_dict(). Missing or malformed values count as not seen.
func from_dict(data: Dictionary) -> void:
	var done = data.get("tutorial_done")
	tutorial_done = done if done is bool else false
	_hints_seen.clear()
	var seen = data.get("hints_seen")
	if seen is Array:
		for hint in seen:
			if hint is String and hint in HINTS and not hint in _hints_seen:
				_hints_seen.append(hint)
