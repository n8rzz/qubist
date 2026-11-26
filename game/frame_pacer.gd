extends RefCounted
## Caps the frame rate when the screen is idle (#264), so the sky, weather
## and island stop burning the battery at full speed while nothing the
## player cares about is changing fast enough to need it.
##
## Any screen's _process calls mark_active() when something is happening
## (a drag, an animation, a crossfade) and update() once per frame.
## update() sets Engine.max_fps: ACTIVE_FPS while something has been
## active in the last LINGER_SECONDS, IDLE_FPS otherwise.

## 30 fps is smooth enough for drifting clouds and twinkling stars.
const IDLE_FPS := 30
## While something the player is watching or driving moves.
const ACTIVE_FPS := 120
## Stay at the active rate this long after the last activity, so a
## settling animation doesn't stutter at the crossover.
const LINGER_SECONDS := 0.5

static var _active_until_msec := 0


static func mark_active() -> void:
	_active_until_msec = Time.get_ticks_msec() + int(LINGER_SECONDS * 1000.0)


static func update() -> void:
	Engine.max_fps = ACTIVE_FPS if Time.get_ticks_msec() < _active_until_msec else IDLE_FPS


## The rate update() would set right now, without calling it (for tests).
static func current_target() -> int:
	return ACTIVE_FPS if Time.get_ticks_msec() < _active_until_msec else IDLE_FPS


## Resets internal state so tests start clean.
static func reset() -> void:
	_active_until_msec = 0
