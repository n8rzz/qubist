extends RefCounted
## Haptic feedback for moves (#27): a light tap when a piece lands, a medium
## pulse when a line clears and a heavy one when several clear at once.
##
## Does nothing while `enabled` is off (the Haptics setting) or on devices
## without a vibration motor.

## Each pulse is [duration in ms, amplitude 0..1].
const TAP := [15, 0.3]
const CLEAR := [30, 0.6]
const BIG_CLEAR := [50, 1.0]

var enabled := true
## Sends one pulse as (duration_ms, amplitude). Tests swap this out.
var vibrate: Callable = Input.vibrate_handheld


## The pulse for clearing `lines` lines at once, or an empty array for none.
static func clear_pulse(lines: int) -> Array:
	if lines <= 0:
		return []
	return CLEAR if lines == 1 else BIG_CLEAR


## A piece was placed.
func tap() -> void:
	_send(TAP)


## `lines` lines were cleared together.
func clear(lines: int) -> void:
	_send(clear_pulse(lines))


func _send(pulse: Array) -> void:
	if enabled and not pulse.is_empty():
		vibrate.call(pulse[0], pulse[1])
