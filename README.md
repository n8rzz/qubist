# Qubist

A 3D block-stacking puzzle for iPhone and iPad, built with Godot 4. Players drop 3D pieces into a 6×6×12 tower and clear any straight line they complete. The tower can be rotated and sliced open with the swiper to see inside.

The product requirements live in Notion (Qubist › PRD and Concept wireframes).

## Project layout

| Path | What it holds |
| --- | --- |
| `core/` | The game rules in plain GDScript: grid, pieces, placement, line clearing, scoring, dealing, game state. No rendering and no platform code, so it can be unit-tested and reused on Android. |
| `config/` | Data that tunes the game: grid size, tray size, scoring numbers (`game.json`) and piece shapes (`pieces.json`). |
| `tests/` | Unit tests for everything in `core/`, with a small built-in runner (no add-ons needed). |

## Coordinates

The core uses `Vector3i(x, y, h)`: `x` is width, `y` is depth and `h` (stored in `.z`) is the layer, with `h = 0` as the floor. The 3D view will map this to Godot's Y-up space as `(x, h, y)`.

## Running the tests

Requires Godot 4.3 or newer on your `PATH`.

```sh
godot --headless --path . --script res://tests/run_tests.gd
```

The runner prints one line per test and exits with code 1 if any test fails.

## Using the core

```gdscript
const Game := preload("res://core/game.gd")

var game := Game.new()          # loads config/game.json and config/pieces.json
game.lines_cleared.connect(_on_lines_cleared)
game.game_over.connect(_on_game_over)
game.start()

if game.can_place(0, Vector3i(2, 3, 0)):
    var result := game.place(0, Vector3i(2, 3, 0))
    print(result.score.total, " points")

var save := game.to_dict()      # JSON-safe; restore with game.from_dict(save)
```

## Adding a piece

Add an entry to `config/pieces.json`. Each entry is one piece in one fixed orientation; list a shape once per orientation it can be dealt in.

```json
{ "id": "l3_x", "shape": "3-cube L", "weight": 0.25, "cells": [[0,0,0],[1,0,0],[0,1,0]] }
```

`weight` sets how often the dealer picks it relative to the others.
