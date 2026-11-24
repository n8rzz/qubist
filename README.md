# Qubist

A 3D block-stacking puzzle for iPhone and iPad, built with Godot 4. Players drop 3D pieces into a 6×6×12 tower and clear any straight line they complete. The tower can be rotated and sliced open with the swiper to see inside.

The product requirements live in Notion (Qubist › PRD and Concept wireframes).

## Project layout

| Path | What it holds |
| --- | --- |
| `core/` | The game rules in plain GDScript: grid, pieces, placement, line clearing, scoring, dealing, game state, plus the analytics events. No rendering and no platform code, so it can be unit-tested and reused on Android. |
| `config/` | Data that tunes the game: grid size, tray size, scoring numbers (`game.json`) and piece shapes (`pieces.json`). |
| `game/` | The greybox game screen: layout, 3D tower view, camera, piece previews and touch input. Builds its UI in code. |
| `assets/` | The app icon, the Fredoka and Inter fonts (`assets/fonts/`, each with its OFL license), the sound effects and music (`assets/audio/`, with every source and license in `CREDITS.md`) and `ui_theme.tres`, the project theme that makes Inter the default font. |
| `scenes/` | `loading.tscn`, the loading view the app starts in, and `main.tscn`, the game screen it hands off to (opening on Home). |
| `tools/` | `simulate.gd`, which plays many games with bots to check game length and score spread. Results and the chosen config values are in [docs/tuning.md](docs/tuning.md). |
| `tests/` | Unit tests for everything in `core/`, with a small built-in runner (no add-ons needed). |

## Coordinates

The core uses `Vector3i(x, y, h)`: `x` is width, `y` is depth and `h` (stored in `.z`) is the layer, with `h = 0` as the floor. The 3D view will map this to Godot's Y-up space as `(x, h, y)`.

## Running the game

Open the folder in Godot 4.7+ and press Play, or run `godot --path .`. The window opens at iPhone size (390×844). With a mouse: drag pieces from the tray onto the tower, scroll over the tower to zoom.

To run it on your iPhone, follow [docs/ios-device-build.md](docs/ios-device-build.md).

## Running the tests

Requires Godot 4.7 or newer on your `PATH`.

On a fresh checkout, import the assets once first (opening the project in the editor does the same):

```sh
godot --headless --path . --import
```

```sh
godot --headless --path . --script res://tests/run_tests.gd
```

A test fails if one of its checks fails or if it hits a script error, such as a call on a null value. Warnings and `push_error()` messages don't fail a test, since some tests trigger them on purpose.

A smoke test loads the game screen headless and plays moves through the real drag path:

```sh
godot --headless --path . --script res://tests/smoke_main.gd
```

Another checks that the loading view holds for its minimum time, then hands off to Home:

```sh
godot --headless --path . --script res://tests/smoke_loading.gd
```

The runner prints one line per test and exits with code 1 if any test fails.

GitHub Actions runs the same tests on every pull request and on pushes to `main` (`.github/workflows/tests.yml`), using Godot 4.7.2 by default. To test against another version, set a repository variable named `GODOT_VERSION` (for example `4.7.1`).

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
                                # from_dict() refuses saves from another config
```

## Adding a piece

Add an entry to `config/pieces.json`. Each entry is one piece in one fixed orientation; list a shape once per orientation it can be dealt in.

```json
{ "id": "l3_x", "shape": "3-cube L", "weight": 0.25, "cells": [[0,0,0],[1,0,0],[0,1,0]] }
```

`weight` sets how often the dealer picks it relative to the others. Before changing a weight, see [docs/tuning.md](docs/tuning.md) for how the current ones were chosen and how to measure a change.

To deal a shape in every orientation, write it once and add `"orientations": "all"`. The config expands it into one piece per distinct 3D rotation (`L4_00`, `L4_01`, …) and splits `weight` evenly between them:

```json
{ "id": "L4", "shape": "L, 1 wide", "weight": 1.0, "orientations": "all", "cells": [[0,0,0],[1,0,0],[2,0,0],[0,1,0]] }
```

Changing the piece list changes the save signature, so a game saved under the old list starts fresh.

## Analytics and error reports

`core/analytics.gd` defines the anonymous events the game sends (`game_start`, `game_over`, `tutorial_step`, `tutorial_end`, `game_quit`) and the numbers each one carries. `track()` refuses any other event or prop. `game/error_reporter.gd` hands the engine's script errors and `push_error()` messages to it, sending each distinct error once per launch.

No provider is plugged in yet. Debug builds print each event as `[analytics] …`, and release builds drop them. To add a provider, write a backend with `track(event, props)` and `report_error(message, details)` that forwards to its SDK, and set it as `analytics.backend` in `game/main.gd` before the screen is ready. Native crashes, the kind that kill the app, need the provider's own SDK.

Nothing identifies the player: no device or advertising ID and no ID kept between launches, so there's no App Tracking Transparency prompt. Settings › Share usage data turns it all off.
