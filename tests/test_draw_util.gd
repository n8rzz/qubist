extends "res://tests/q_test.gd"
## The shared drawing helpers (#208).

const DrawUtil := preload("res://game/draw_util.gd")


func test_rand_is_repeatable_and_in_range() -> void:
	for i in 50:
		for k in 5:
			var v := DrawUtil.rand(i, k)
			check(v >= 0.0 and v < 1.0, "rand(%d, %d) = %f is out of range" % [i, k, v])
			check(v == DrawUtil.rand(i, k), "rand(%d, %d) should repeat" % [i, k])
	check(DrawUtil.rand(1, 1) != DrawUtil.rand(2, 1), "different items differ")


func test_ellipse_points_lie_on_the_ellipse() -> void:
	var center := Vector2(10, 20)
	var radii := Vector2(8, 3)
	var points := DrawUtil.ellipse(center, radii, 12)
	check_eq(points.size(), 12, "one point per segment")
	check(points[0].is_equal_approx(center + Vector2(radii.x, 0)), "starts at the right-hand end")
	for p in points:
		var d := (p - center) / radii
		check(is_equal_approx(d.length_squared(), 1.0), "point %s is off the ellipse" % p)
	check_eq(DrawUtil.ellipse(center, radii).size(), 32, "32 segments by default")
