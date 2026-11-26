extends "res://tests/q_test.gd"

const LoadingArt := preload("res://game/loading_art.gd")
const LoadingScreen := preload("res://game/loading_screen.gd")
const SkyView := preload("res://game/sky_view.gd")
const UI := preload("res://game/ui_style.gd")


## The drop keyframes start high and clear, land, bounce and rest.
func test_cube_starts_high_and_invisible() -> void:
	check(is_equal_approx(LoadingArt.keyframe(LoadingArt.LIFT_KEYS, 0.0), 140.0), "a cube should start 140 up")
	check_eq(LoadingArt.keyframe(LoadingArt.ALPHA_KEYS, 0.0), 0.0, "a cube should start invisible")


func test_cube_is_landed_and_opaque_mid_loop() -> void:
	check(is_zero_approx(LoadingArt.keyframe(LoadingArt.LIFT_KEYS, 0.2)), "a cube should be landed at 0.2")
	check(is_equal_approx(LoadingArt.keyframe(LoadingArt.ALPHA_KEYS, 0.5), 1.0), "a cube should be opaque mid-loop")


func test_cube_bounces_after_landing() -> void:
	check(is_equal_approx(LoadingArt.keyframe(LoadingArt.LIFT_KEYS, 0.24), 8.0), "a cube should bounce 8 up after landing")
	check(is_zero_approx(LoadingArt.keyframe(LoadingArt.LIFT_KEYS, 0.28)), "a cube should settle after the bounce")


func test_cube_fades_out_by_the_end_of_the_loop() -> void:
	check(is_zero_approx(LoadingArt.keyframe(LoadingArt.ALPHA_KEYS, 1.0)), "a cube should fade out by the end of the loop")


func test_bezier_ease_hits_its_endpoints() -> void:
	check_eq(LoadingArt.bezier_ease(0.0), 0.0)
	check_eq(LoadingArt.bezier_ease(1.0), 1.0)


func test_bezier_ease_clamps_outside_the_unit_range() -> void:
	check_eq(LoadingArt.bezier_ease(-0.5), 0.0)
	check_eq(LoadingArt.bezier_ease(-3.0), 0.0)
	check_eq(LoadingArt.bezier_ease(1.5), 1.0)
	check_eq(LoadingArt.bezier_ease(3.0), 1.0)


func test_bezier_ease_never_decreases() -> void:
	var previous := LoadingArt.bezier_ease(0.0)
	for i in range(1, 201):
		var x := i / 200.0
		var y := LoadingArt.bezier_ease(x)
		check(y >= previous, "ease(%.3f) = %f is below ease at the step before (%f)" % [x, y, previous])
		check(y >= 0.0 and y <= 1.0, "ease(%.3f) = %f is outside 0–1" % [x, y])
		previous = y


## #116: the loading view's art holds still under Reduce Motion. _build() is
## called directly, so nothing starts loading the game screen.
func test_loading_view_holds_the_art_still_under_reduce_motion() -> void:
	for reduce in [1, 0]:
		UI.motion_override = reduce
		var loading = LoadingScreen.new()
		loading._build()
		check_eq(loading.art.still, reduce == 1, "Reduce Motion %d" % reduce)
		loading.free()
	UI.motion_override = -1
	SkyView.show("spring", "day", true)
