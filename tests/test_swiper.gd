extends "res://tests/q_test.gd"

const Swiper := preload("res://game/swiper.gd")
const ViewMath := preload("res://game/view_math.gd")

const SIZE := Vector3i(6, 6, 12)


func test_starts_showing_the_whole_tower() -> void:
	var s := Swiper.new(SIZE)
	check_eq(s.mode, ViewMath.MODE_X)
	check(not s.is_sliced())
	check(s.faded_cells([Vector3i(0, 0, 0), Vector3i(5, 5, 11)], 0).is_empty())


func test_fit_keeps_depth_in_the_mode_range() -> void:
	var s := Swiper.new(SIZE)
	s.mode = ViewMath.MODE_Z
	s.depth = 10
	s.fit(0)
	check_eq(s.depth, 10, "Z has 12 layers")
	s.mode = ViewMath.MODE_X
	s.fit(0)
	check_eq(s.depth, 5, "X has 6 layers")


func test_chip_numbers_x_from_the_front_and_z_from_the_floor() -> void:
	var s := Swiper.new(SIZE)
	s.depth = 2
	check_eq(s.chip_text(0), "Slice 3 of 6 · X")
	s.mode = ViewMath.MODE_Z
	check_eq(s.chip_text(0), "Slice 10 of 12 · Z")


func test_faded_and_shade_split_the_tower_at_the_cut() -> void:
	var s := Swiper.new(SIZE)
	s.mode = ViewMath.MODE_Z
	s.depth = 1
	var top := Vector3i(0, 0, 11)
	var cut := Vector3i(0, 0, 10)
	var below := Vector3i(0, 0, 3)
	var cells := [top, cut, below]
	var faded := s.faded_cells(cells, 0)
	check_eq(faded.keys(), [top])
	var shade := s.shade(cells, faded, 0)
	check_eq(shade.cap, [cut])
	check_eq(shade.behind.keys(), [below])


func test_sweep_shows_on_bump_then_fades() -> void:
	var s := Swiper.new(SIZE)
	check(not s.update_sweep(0.1, false), "nothing to fade at rest")
	s.bump()
	check(s.update_sweep(0.1, false))
	check_eq(s.sweep_alpha(), 1.0, "fully shown after the fade-in")
	for i in range(20):
		s.update_sweep(0.1, false)
	check_eq(s.sweep_alpha(), 0.0, "faded out after the hold")


func test_sweep_holds_while_dragging_and_hides_while_turning() -> void:
	var s := Swiper.new(SIZE)
	s.begin_sweep()
	for i in range(20):
		s.update_sweep(0.1, false)
	check_eq(s.sweep_alpha(), 1.0, "held while the finger is down")
	for i in range(20):
		s.update_sweep(0.1, true)
	check_eq(s.sweep_alpha(), 0.0, "hidden while the tower turns")
