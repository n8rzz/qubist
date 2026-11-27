# Measuring performance

The phone gets warm after 5–10 minutes of play (#34). This page covers how to measure what the game costs, so each fix in #313–#320 can be checked against a baseline (#321).

There are three tools, from quickest to most realistic:

| Tool | What it measures | Where |
| --- | --- | --- |
| `tools/benchmark.gd` | CPU time of the per-frame work: sky, weather and Home art drawing, the island, the SkyView helpers, the drag snap search, and the game screen's `_process` | Headless, on a desktop |
| Perf monitor (`game/perf_monitor.gd`) | Frame rate, frame, process and busy times, draw calls, and the CPU and GPU render time of the screen and the tower, for each screen | Debug builds, on the device |
| Xcode Instruments | Energy, thermal state, GPU and CPU time across the whole app | On the device |

## 1. CPU benchmark (desktop)

```sh
godot --headless --path . --script res://tools/benchmark.gd
```

Options: `--frames=N` (frames per drawing case, default 120), `--calls=N` (calls per function case, default 2000), `--only=sky,home_art,island,sky_view,snap,main` and `--csv=PATH`. A full run takes about a minute.

Each row is one case. It shows how many times the case ran, and the average, 95th-percentile and worst time of one run in microseconds. Headless has no GPU, so this covers only the CPU side, and a desktop is several times faster than a phone. Only compare runs from the same machine, and close other heavy apps first. Look at the averages; a single worst time is often noise.

To compare a change, run it on `main` and on your branch with `--csv`, then diff the two files.

## 2. Perf monitor (on the device)

Debug builds add the monitor to the game screen. Export templates built with Debug, and runs from the editor or from Xcode, are debug builds. Release builds and the headless tests never run it.

- Every 5 seconds it prints one `[perf]` line per screen seen in that window to the console. In Xcode the console is the debug area, and in the editor it's the Output panel.
- It appends the same numbers as rows to `user://perf.csv`. On iOS, get the file from Xcode › Window › Devices and Simulators › the app › ⚙ › Download Container…, under `AppData/Documents/` or `AppData/Library/Application Support/`. On a desktop it's in the app's user data folder, which the first `[perf]` line prints.
- **F3** or a **three-finger tap** shows or hides a small overlay with the latest lines.

The screens are `home`, `stats`, `settings`, `tutorial`, `game_over`, `drag` (a piece being dragged), `game_active` (an animation, turn or sky fade running, at the active frame cap) and `game_idle`.

A `[perf]` line reads:

```
game_idle 5.0s 30fps (cap 30) frame 33.3/33.3/47.4ms process 0.28/0.37ms busy 6.65/9.24ms draws 405 prims 68475 render cpu 0.27 gpu 0.56ms tower cpu 0.46 gpu 6.50ms
```

| Field | Meaning |
| --- | --- |
| `fps (cap)` | Frames per second actually drawn, and `Engine.max_fps` (the frame cap) |
| `frame` | Time from one frame to the next, avg/p95/max. Mostly set by the cap. |
| `process` | Every node's `_process`, avg/p95 |
| `busy` | CPU time from the start of the frame to the end of drawing: process, `_draw` calls and handing the frame to the GPU, avg/p95. It can include waiting on the GPU. |
| `draws`, `prims` | Draw calls and primitives per frame, 2D and 3D together |
| `render cpu/gpu` | The main screen's render time: 2D sky, weather and UI |
| `tower cpu/gpu` | The tower's 3D SubViewport. 0 while it is hidden (on Home). |

The CSV has every average plus the p95 and max for frame, process and busy time.

Measuring render time costs a little itself, so compare monitor numbers with other monitor numbers, not with a release build.

## 3. Xcode Instruments (on the device)

Build and run from Xcode as in [ios-device-build.md](ios-device-build.md), then use Product › Profile, or attach Instruments to the running app:

- **Power Profiler** (or **Energy Log** on older Xcode): energy impact and CPU/GPU/display share over time. This is the closest to "is it getting hot".
- **Metal System Trace**: GPU time per frame and per pass. Use it for the tower's shadows and MSAA (#313).
- **Time Profiler**: which native and script functions take the CPU.
- Xcode's debug navigator gauges (CPU, GPU, Energy Impact) give a quick read without Instruments.

Read the thermal state (nominal, fair, serious, critical) from the Power Profiler's thermal track.

Godot's remote debugger also works on the device. Run from the editor with Remote Debug, then use Debugger › Profiler (script time per function), Visual Profiler (CPU/GPU per render step) and Monitors.

## Scenarios

To get comparable numbers, start each one from a cold app with the phone at room temperature, not charging, and at a fixed brightness. Note the phone model, iOS version and battery level.

| Scenario | Steps | Look at |
| --- | --- | --- |
| A. Idle game | Continue a game and leave it for 2 minutes | `game_idle` busy and tower GPU, energy impact |
| B. Home | Leave Home open for 2 minutes | `home` busy and render GPU, energy impact |
| C. Dragging | Drag a piece around over the tower for 30 seconds without dropping it | `drag` busy p95, fps |
| D. Session | Play normally for 10 minutes | Battery drop, thermal state reached, energy impact over time |

Record the sky's season and time of day too: winter nights and fall mornings draw the most.

## Baseline

### Desktop benchmark

On a MacBook Pro 16" 2019 (i9-9880H), Godot 4.7.2, before any of #313–#320. Times are averages in microseconds.

| Case | avg µs |
| --- | ---: |
| Sky backdrop draw, per view (16 season × time views) | 600–1800 (winter night the most) |
| Sky backdrop draw, crossfade / Christmas | ~2150 / ~1500 |
| Sky weather draw, per view | 70–550 |
| Sky weather draw, crossfade | ~930 |
| Home art draw, building | ~1650 |
| Island `_process`, steady / crossfade | ~15 / ~175 |
| `Rules.legal_positions`, one piece, empty / mid-game tower | ~2700 / ~2100 |
| Game screen `_process`, Home / idle game | ~550 / ~540 |

The snap search stands out. A drag runs it on every touch-move, so on a phone dragging can cost several milliseconds per touch event (#316).

### Desktop perf monitor (debug, windowed)

Same Mac, spring day:

| Screen | fps (cap) | busy avg ms | draws | render gpu ms | tower gpu ms |
| --- | --- | ---: | ---: | ---: | ---: |
| `home` | 29 (30) | 21.4 | 828 | 0.8 | — |
| `game_idle` | 30 (30) | 6.5 | ~400 | 0.4 | 6.2–6.5 |

### Device

To fill in from scenarios A–D on a phone.

| Date | Device | iOS | Commit | Scenario | fps | busy ms | render gpu ms | tower gpu ms | Energy impact | Thermal | Battery drop |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | | |
