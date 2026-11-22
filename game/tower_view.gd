extends Node3D
## Greybox 3D view of the tower: placed blocks, faded blocks, the ghost
## preview, a base under the footprint and guides for the grid and height.
##
## Knows nothing about rules; main.gd tells it which cells to draw how.

const ViewMath := preload("res://game/view_math.gd")
const CameraRig := preload("res://game/camera_rig.gd")

const SolidShader := preload("res://game/shaders/block_solid.gdshader")
const FadedShader := preload("res://game/shaders/block_faded.gdshader")

const CUBE_SIZE := 0.94
## Mid-grey stone, so cubes stand apart from the base and the sky.
const BLOCK_COLOR := Color("#A8A8A3")
## Darker line along every cube edge, so cells can be counted.
const EDGE_COLOR := Color("#5E5E5A")
## Faded blocks keep the block colour at low opacity and a faint outline.
const FADED_COLOR := Color(BLOCK_COLOR, 0.15)
const FADED_EDGE_COLOR := Color(EDGE_COLOR, 0.45)
const GHOST_OK_COLOR := Color(0.18, 0.62, 0.36, 0.45)
const GHOST_BAD_COLOR := Color(0.85, 0.25, 0.2, 0.45)
const BASE_COLOR := Color("#CFCFCB")
const GUIDE_COLOR := Color(0.45, 0.45, 0.45, 0.55)
const BACKGROUND_COLOR := Color("#F4F4F2")
const BASE_THICKNESS := 0.4

# Placeholder move animation (#47). Real effects come later.
## A placed piece drops this far, in cubes, as it lands.
const DROP_HEIGHT := 0.6
const LAND_SECONDS := 0.1
## Cleared cubes flash this colour, then shrink to nothing.
const FLASH_COLOR := Color("#FFD23F")
const FLASH_EDGE_COLOR := Color("#B8860B")
const FLASH_SECONDS := 0.15
const SHRINK_SECONDS := 0.25

## Emitted when the move animation ends (or is skipped). Not emitted when it is
## cancelled.
signal move_animation_finished

var grid_size := Vector3i(6, 6, 12)
var rig: CameraRig

var _solid := MultiMeshInstance3D.new()
var _faded := MultiMeshInstance3D.new()
var _ghost := MultiMeshInstance3D.new()
var _ghost_ok := _material(GHOST_OK_COLOR, true)
var _ghost_bad := _material(GHOST_BAD_COLOR, true)
## Cubes of the piece being placed, drawn apart while they drop in.
var _landing := MultiMeshInstance3D.new()
## Cubes being cleared, drawn apart so the grid can update straight away.
var _clearing := MultiMeshInstance3D.new()
var _clearing_material: ShaderMaterial
## Placed cells still landing; update_blocks leaves them out of the solid set.
var _landing_set := {}
var _landing_cells: Array = []
var _clearing_cells: Array = []
var _move_tween: Tween


func setup(size: Vector3i) -> void:
	grid_size = size
	_add_environment()
	_add_base()
	_add_guides()

	_solid.multimesh = _make_multimesh()
	_solid.material_override = _block_material(SolidShader, BLOCK_COLOR, EDGE_COLOR)
	_faded.multimesh = _make_multimesh()
	_faded.material_override = _block_material(FadedShader, FADED_COLOR, FADED_EDGE_COLOR)
	_faded.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.multimesh = _make_multimesh()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	_landing.multimesh = _make_multimesh()
	_landing.material_override = _solid.material_override
	_clearing.multimesh = _make_multimesh()
	_clearing_material = _block_material(SolidShader, BLOCK_COLOR, EDGE_COLOR)
	_clearing.material_override = _clearing_material
	for node in [_solid, _faded, _ghost, _landing, _clearing]:
		add_child(node)

	rig = CameraRig.new()
	rig.position = Vector3(0, size.z * 0.42, 0)
	add_child(rig)


## Draws `cells`; those in `faded` (a set of Vector3i keys) are see-through.
func update_blocks(cells: Array, faded: Dictionary) -> void:
	var solid: Array = []
	var faint: Array = []
	for c in cells:
		if faded.has(c):
			faint.append(c)
		elif not _landing_set.has(c):
			solid.append(c)
	_fill(_solid, solid)
	_fill(_faded, faint)


func show_ghost(cells: Array, legal: bool) -> void:
	_ghost.material_override = _ghost_ok if legal else _ghost_bad
	_fill(_ghost, cells)
	_ghost.visible = true


func hide_ghost() -> void:
	_ghost.visible = false


## Plays the placeholder move animation: `placed` cubes (minus any in `skip`,
## such as sliced-away ones) drop into place, then `cleared` cubes flash and
## shrink away. The grid should already hold the result of the move; call
## update_blocks() after this so the landing cubes are left out.
func play_move(placed: Array, cleared: Array, skip: Dictionary) -> void:
	cancel_move_animation()
	var cleared_set := {}
	for c in cleared:
		cleared_set[c] = true
	for c in placed:
		# Placed cubes that clear stay in the clearing set, so they land and
		# flash in one place.
		if not cleared_set.has(c) and not skip.has(c):
			_landing_set[c] = true
			_landing_cells.append(c)
	_clearing_cells = cleared.duplicate()
	var total := LAND_SECONDS
	if not cleared.is_empty():
		total += FLASH_SECONDS + SHRINK_SECONDS
	_set_move_time(0.0)
	_move_tween = create_tween()
	_move_tween.tween_method(_set_move_time, 0.0, total, total)
	_move_tween.finished.connect(_end_move_animation.bind(true))


func is_animating() -> bool:
	return _move_tween != null and _move_tween.is_valid()


## Jumps the move animation to its end, emitting move_animation_finished.
func finish_move_animation() -> void:
	if is_animating():
		_move_tween.kill()
		_end_move_animation(true)


## Stops the move animation without emitting move_animation_finished.
func cancel_move_animation() -> void:
	if _move_tween != null:
		_move_tween.kill()
	_end_move_animation(false)


func _end_move_animation(notify: bool) -> void:
	_move_tween = null
	_landing_set.clear()
	_landing_cells.clear()
	_clearing_cells.clear()
	_landing.multimesh.instance_count = 0
	_clearing.multimesh.instance_count = 0
	if notify:
		move_animation_finished.emit()


func _set_move_time(t: float) -> void:
	var land := clampf(t / LAND_SECONDS, 0.0, 1.0)
	var drop := Vector3(0, DROP_HEIGHT * (1.0 - ease(land, 0.4)), 0)
	var lmm := _landing.multimesh
	lmm.instance_count = _landing_cells.size()
	for i in range(_landing_cells.size()):
		lmm.set_instance_transform(i, Transform3D(Basis(), ViewMath.to_world(_landing_cells[i], grid_size) + drop))

	# Clearing cubes sit still while the piece lands, flash, then shrink.
	var after_land := t - LAND_SECONDS
	var flash := clampf(after_land / FLASH_SECONDS, 0.0, 1.0) if after_land > 0.0 else 0.0
	var shrink := clampf((after_land - FLASH_SECONDS) / SHRINK_SECONDS, 0.0, 1.0)
	var size := maxf(1.0 - ease(shrink, 2.0), 0.001)
	_clearing_material.set_shader_parameter("face_color", BLOCK_COLOR.lerp(FLASH_COLOR, flash))
	_clearing_material.set_shader_parameter("edge_color", EDGE_COLOR.lerp(FLASH_EDGE_COLOR, flash))
	var cmm := _clearing.multimesh
	cmm.instance_count = _clearing_cells.size()
	for i in range(_clearing_cells.size()):
		var shrunk := Basis().scaled(Vector3.ONE * size)
		cmm.set_instance_transform(i, Transform3D(shrunk, ViewMath.to_world(_clearing_cells[i], grid_size)))


func camera() -> Camera3D:
	return rig.camera


## Screen position, in this view's viewport, of a world point.
func project_point(p: Vector3) -> Vector2:
	return rig.camera.unproject_position(p)


func project_cell(c: Vector3i) -> Vector2:
	return project_point(ViewMath.to_world(c, grid_size))


## Distance from the camera plane; smaller is nearer the player.
func depth_of(c: Vector3i) -> float:
	var cam := rig.camera.global_transform
	return (ViewMath.to_world(c, grid_size) - cam.origin).dot(-cam.basis.z)


## Where to put the axis labels, in viewport pixels: [x, y, z]. X and Y sit
## `gap` pixels outside the middle of the base's right-front and left-front
## edges, the edges the swiper's X and Y modes cut along. Z sits `gap` pixels
## below the base's front corner.
func axis_label_points(gap: float) -> Array[Vector2]:
	var hx := grid_size.x * 0.5 + 0.5
	var hz := grid_size.y * 0.5 + 0.5
	var y := -BASE_THICKNESS
	var corners: Array[Vector2] = []
	for c in [Vector3(hx, y, hz), Vector3(-hx, y, hz), Vector3(-hx, y, -hz), Vector3(hx, y, -hz)]:
		corners.append(project_point(c))
	# The front corner is the lowest on screen; its neighbours end the two
	# front edges.
	var front := 0
	for i in range(1, 4):
		if corners[i].y > corners[front].y:
			front = i
	var a := corners[(front + 1) % 4]
	var b := corners[(front + 3) % 4]
	var right := a if a.x > b.x else b
	var left := b if a.x > b.x else a
	var center := project_point(Vector3(0, y, 0))
	var f := corners[front]
	var x_mid := (f + right) * 0.5
	var y_mid := (f + left) * 0.5
	return [
		x_mid + (x_mid - center).normalized() * gap,
		y_mid + (y_mid - center).normalized() * gap,
		f + Vector2(0, gap),
	]


## On-screen size of one cube, in viewport pixels.
func cube_pixels() -> float:
	return get_viewport().get_visible_rect().size.y / rig.camera.size


func _fill(target: MultiMeshInstance3D, cells: Array) -> void:
	var mm := target.multimesh
	mm.instance_count = cells.size()
	for i in range(cells.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), ViewMath.to_world(cells[i], grid_size)))


func _make_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE * CUBE_SIZE
	mm.mesh = box
	return mm


func _block_material(shader: Shader, face: Color, edge: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("face_color", face)
	m.set_shader_parameter("edge_color", edge)
	m.set_shader_parameter("half_size", CUBE_SIZE * 0.5)
	return m


func _material(color: Color, transparent := false, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 0.9
	add_child(sun)


func _add_base() -> void:
	var slab := BoxMesh.new()
	slab.size = Vector3(grid_size.x + 1, BASE_THICKNESS, grid_size.y + 1)
	var base := MeshInstance3D.new()
	base.mesh = slab
	base.material_override = _material(BASE_COLOR)
	base.position = Vector3(0, -BASE_THICKNESS * 0.5, 0)
	add_child(base)


## Floor grid lines and the outline of the full-height bounding box.
func _add_guides() -> void:
	var hx := grid_size.x * 0.5
	var hz := grid_size.y * 0.5
	var top := float(grid_size.z)
	var floor_y := 0.005
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _material(GUIDE_COLOR, true, true))
	for i in range(grid_size.x + 1):
		mesh.surface_add_vertex(Vector3(-hx + i, floor_y, -hz))
		mesh.surface_add_vertex(Vector3(-hx + i, floor_y, hz))
	for i in range(grid_size.y + 1):
		mesh.surface_add_vertex(Vector3(-hx, floor_y, -hz + i))
		mesh.surface_add_vertex(Vector3(hx, floor_y, -hz + i))
	var corners := [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		mesh.surface_add_vertex(Vector3(a.x, 0, a.y))
		mesh.surface_add_vertex(Vector3(a.x, top, a.y))
		mesh.surface_add_vertex(Vector3(a.x, top, a.y))
		mesh.surface_add_vertex(Vector3(b.x, top, b.y))
	mesh.surface_end()
	var guides := MeshInstance3D.new()
	guides.mesh = mesh
	guides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(guides)
