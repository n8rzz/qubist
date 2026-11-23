extends RefCounted
## The three tutorial moves (#29): each one's tower, piece, target spot and
## card text. game/tutorial_run.gd plays them on the game screen.
##
## At the starting view the camera is at the corner with the highest x and
## y, so y = 5 is the front row and y = 0 the back.

const Game := preload("res://core/game.gd")

## Move 1: drop a bar anywhere on the empty floor.
## Move 2: finish a pre-built row to clear it.
## Move 3: the gap is in the back row, behind a low wall, so the player has
## to rotate the tower (or slice it) to see it.
##
## `piece_size` picks the piece by its size (x, y, h), so 4x1x1 is a bar
## lying along x. `target` is where the hand shows the piece going. With `only_target`, the
## piece snaps to nowhere else. With `hidden`, it snaps nowhere at all until
## the player has turned or sliced the tower, and the card shows the
## `found_*` text from then on.
const STEPS := [
	{
		"title": "Drag a piece onto the tower",
		"body": "Press the bar in the tray and drop it anywhere on the floor.",
		"piece_size": Vector3i(4, 1, 1),
		"cells": [],
		"target": Vector3i(1, 3, 0),
		"only_target": false,
		"hidden": false,
	},
	{
		"title": "Fill a row to clear it",
		"body": "Drop the bar in the gap. A row that runs edge to edge breaks away for points.",
		"piece_size": Vector3i(2, 1, 1),
		"cells": [
			Vector3i(0, 5, 0), Vector3i(1, 5, 0), Vector3i(2, 5, 0), Vector3i(3, 5, 0),
			Vector3i(0, 4, 0), Vector3i(1, 4, 0),
		],
		"target": Vector3i(4, 5, 0),
		"only_target": true,
		"hidden": false,
	},
	{
		"title": "The gap is around the back",
		"body": "Rotate the tower to see the hidden spot, then drag your piece in.",
		"found_title": "There it is",
		"found_body": "Drag the bar into the gap to finish the back row.",
		"piece_size": Vector3i(2, 1, 1),
		"cells": [
			Vector3i(2, 0, 0), Vector3i(3, 0, 0), Vector3i(4, 0, 0), Vector3i(5, 0, 0),
			Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(2, 1, 0), Vector3i(3, 1, 0), Vector3i(4, 1, 0),
			Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(2, 1, 1), Vector3i(3, 1, 1), Vector3i(4, 1, 1),
		],
		"target": Vector3i(0, 0, 0),
		"only_target": true,
		"hidden": true,
	},
]


static func step_count() -> int:
	return STEPS.size()


static func step(index: int) -> Dictionary:
	return STEPS[index]


## A game set up for step `index`: its cubes on the tower and its one piece
## in the first tray slot. It deals nothing more once the piece is placed.
static func make_game(config, index: int) -> Game:
	var data: Dictionary = STEPS[index]
	var game := Game.new(config)
	game.start()
	game.auto_refill = false
	for c in data.cells:
		game.grid.set_filled(c, true)
	var tray: Array = []
	tray.resize(config.tray_size)
	tray[0] = config.piece_by_size(data.piece_size)
	game.tray = tray
	return game


## Where the piece may snap in step `index`: null for any legal spot, or a
## list of origins (empty while a hidden target hasn't been found).
static func allowed_origins(index: int, found: bool):
	var data: Dictionary = STEPS[index]
	if data.hidden and not found:
		return []
	if data.only_target:
		return [data.target]
	return null
