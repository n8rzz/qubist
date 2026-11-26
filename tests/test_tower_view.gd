extends "res://tests/q_test.gd"
## The helpers the line clear and the crumble share (#234). _draw_puffs and
## the timeline need the scene tree, so smoke_main.gd covers those.

const TowerView := preload("res://game/tower_view.gd")
const CameraRig := preload("res://game/camera_rig.gd")

const SEED := 234
const ROLLS := 200


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return rng


## The view builds its nodes up front and only parents them in setup(), which
## these tests skip. The orphaned VisualInstance3D members trigger an engine
## error when freed individually outside the tree (get_global_transform()
## requires is_inside_tree()). Root view in the SceneTree first so that
## add_child() and the subsequent free() have a live world context.
func _free_view(view: Node) -> void:
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	for property in view.get_property_list():
		var value = view.get(property.name)
		if (
			property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
			and is_instance_valid(value)
			and value is Node
			and value.get_parent() == null
		):
			view.add_child(value)
	view.free()


func test_rand_size_rolls_x_then_y_then_z() -> void:
	var view := TowerView.new()
	var rng := _rng()
	var expected := _rng()
	var x := expected.randf_range(1.0, 2.0)
	var y := expected.randf_range(3.0, 4.0)
	var z := expected.randf_range(5.0, 6.0)
	check_eq(view._rand_size(rng, Vector3(1, 3, 5), Vector3(2, 4, 6)), Vector3(x, y, z))
	check_eq(rng.state, expected.state, "three rolls and no more")
	_free_view(view)


func test_rand_vec3_stays_within_its_extent() -> void:
	var view := TowerView.new()
	var rng := _rng()
	var extent := Vector3(0.25, 0.2, 0.5)
	for i in ROLLS:
		var v: Vector3 = view._rand_vec3(rng, extent)
		check(
			v.abs().x <= extent.x and v.abs().y <= extent.y and v.abs().z <= extent.z,
			"%s is outside %s" % [v, extent]
		)
	_free_view(view)


func test_rand_axis_has_length_one() -> void:
	var view := TowerView.new()
	var rng := _rng()
	for i in ROLLS:
		check(view._rand_axis(rng).is_normalized(), "roll %d" % i)
	_free_view(view)


func test_stone_scales_the_block_colour_and_stays_opaque() -> void:
	var view := TowerView.new()
	var rng := _rng()
	var expected := _rng()
	for i in ROLLS:
		var shade := expected.randf_range(0.8, 1.06)
		var color: Color = view._stone(rng, 0.8, 1.06)
		var block := TowerView.BLOCK_COLOR
		check(
			color.is_equal_approx(Color(block.r * shade, block.g * shade, block.b * shade, 1.0)),
			"roll %d" % i
		)
		check_eq(color.a, 1.0, "alpha")
	_free_view(view)


func test_camera_shake_offsets_the_camera_until_reset() -> void:
	var view := TowerView.new()
	view.rig = CameraRig.new()
	view._camera_shake(0.2, 0.1)
	check(is_equal_approx(view.rig.camera.h_offset, 0.2 * sin(7.1)), "h_offset")
	check(is_equal_approx(view.rig.camera.v_offset, 0.2 * cos(5.3)), "v_offset")
	view._reset_camera()
	check_eq(view.rig.camera.h_offset, 0.0)
	check_eq(view.rig.camera.v_offset, 0.0)
	view.rig.free()
	_free_view(view)


func test_reset_camera_without_a_camera_does_nothing() -> void:
	var view := TowerView.new()
	view._reset_camera()
	check(view.rig == null)
	_free_view(view)
