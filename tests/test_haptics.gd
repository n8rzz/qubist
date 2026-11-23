extends "res://tests/q_test.gd"

const Haptics := preload("res://game/haptics.gd")


## A Haptics that records its pulses instead of vibrating.
func _recording() -> Array:
	var sent: Array = []
	var haptics := Haptics.new()
	haptics.vibrate = func(ms: int, amplitude: float) -> void: sent.append([ms, amplitude])
	return [haptics, sent]


func test_clear_pulse_grows_with_the_lines_cleared() -> void:
	check_eq(Haptics.clear_pulse(0), [], "no lines, no pulse")
	check_eq(Haptics.clear_pulse(1), Haptics.CLEAR)
	check_eq(Haptics.clear_pulse(2), Haptics.BIG_CLEAR)
	check_eq(Haptics.clear_pulse(5), Haptics.BIG_CLEAR)


func test_pulses_get_stronger_from_tap_to_big_clear() -> void:
	check(Haptics.TAP[0] < Haptics.CLEAR[0] and Haptics.CLEAR[0] < Haptics.BIG_CLEAR[0], "durations grow")
	check(Haptics.TAP[1] < Haptics.CLEAR[1] and Haptics.CLEAR[1] < Haptics.BIG_CLEAR[1], "amplitudes grow")
	check(Haptics.BIG_CLEAR[1] <= 1.0, "amplitude stays in range")


func test_tap_and_clear_send_their_pulses() -> void:
	var pair := _recording()
	var haptics: Haptics = pair[0]
	haptics.tap()
	haptics.clear(1)
	haptics.clear(3)
	haptics.clear(0)
	check_eq(pair[1], [Haptics.TAP, Haptics.CLEAR, Haptics.BIG_CLEAR])


func test_nothing_is_sent_while_disabled() -> void:
	var pair := _recording()
	var haptics: Haptics = pair[0]
	haptics.enabled = false
	haptics.tap()
	haptics.clear(2)
	check_eq(pair[1], [])
