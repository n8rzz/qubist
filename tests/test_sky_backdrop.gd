extends "res://tests/q_test.gd"

const SkyBackdrop := preload("res://game/sky_backdrop.gd")


## Where cloud `index`'s first puff sits on screen, `seconds` in.
func _first_puff_x(index: int, seconds: float, width: float) -> float:
	var home: float = SkyBackdrop.CLOUDS[index][1][0].x * width / 390.0
	return home + SkyBackdrop.cloud_shift(index, seconds, width).x


func test_clouds_start_where_clouds_lists_them() -> void:
	for i in SkyBackdrop.CLOUDS.size():
		check(is_zero_approx(SkyBackdrop.cloud_shift(i, 0.0, 390.0).x), "cloud %d should start at its CLOUDS x" % i)


func test_fainter_clouds_drift_slower() -> void:
	check(is_equal_approx(SkyBackdrop.drift_speed(0.85), SkyBackdrop.DRIFT_SPEED), "the nearest cloud should move at full speed")
	check(SkyBackdrop.drift_speed(0.7) < SkyBackdrop.drift_speed(0.85), "a 0.7 cloud should be slower than a 0.85 one")
	check(SkyBackdrop.drift_speed(0.55) < SkyBackdrop.drift_speed(0.7), "a 0.55 cloud should be slower than a 0.7 one")
	check(SkyBackdrop.drift_speed(0.55) > 0.0, "every cloud should still move")


func test_clouds_drift_right() -> void:
	for i in SkyBackdrop.CLOUDS.size():
		check(_first_puff_x(i, 1.0, 390.0) > _first_puff_x(i, 0.0, 390.0), "cloud %d should move right" % i)


func test_clouds_wrap_fully_offscreen() -> void:
	var margin := SkyBackdrop.DRIFT_MARGIN
	for width in [320.0, 390.0, 820.0]:
		var m: float = margin * maxf(width / 390.0, 1.0)
		for i in SkyBackdrop.CLOUDS.size():
			for step in range(0, 600):
				var x := _first_puff_x(i, step * 1.7, width)
				check(x >= -m - 0.001 and x <= width + m + 0.001, "cloud %d at width %d left the wrap band: %f" % [i, width, x])


func test_clouds_come_back_around() -> void:
	# The slowest cloud crosses 390 + 2 * 100 points at 40% speed.
	var lap: float = (390.0 + 2.0 * SkyBackdrop.DRIFT_MARGIN) / SkyBackdrop.drift_speed(0.55)
	var x := _first_puff_x(2, lap, 390.0)
	check(is_equal_approx(x, _first_puff_x(2, 0.0, 390.0)), "cloud 2 should be back home after one lap, got %f" % x)


func test_bob_stays_within_its_height() -> void:
	for i in SkyBackdrop.CLOUDS.size():
		for step in range(0, 200):
			var y := SkyBackdrop.cloud_shift(i, step * 0.37, 390.0).y
			check(absf(y) <= SkyBackdrop.BOB_HEIGHT + 0.001, "cloud %d bobbed %f" % [i, y])


func test_clouds_bob_out_of_step() -> void:
	# Two clouds can pass the same height at a moment, so look across a float.
	var apart := 0.0
	for step in range(0, 12):
		apart = maxf(apart, absf(SkyBackdrop.cloud_shift(0, step, 390.0).y - SkyBackdrop.cloud_shift(1, step, 390.0).y))
	check(apart > 1.0, "neighboring clouds shouldn't float in sync")
