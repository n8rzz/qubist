extends Node3D
## Greybox 3D view of the tower: placed blocks, faded blocks, the ghost
## preview, a base under the footprint and guides for the grid and height.
##
## Knows nothing about rules; main.gd tells it which cells to draw how.

const ViewMath := preload("res://game/view_math.gd")
const CameraRig := preload("res://game/camera_rig.gd")

const SolidShader := preload("res://game/shaders/block_solid.gdshader")
const FadedShader := preload("res://game/shaders/block_faded.gdshader")
const GhostLinesShader := preload("res://game/shaders/ghost_lines.gdshader")

const CUBE_SIZE := 0.94
## Mid-grey stone, so cubes stand apart from the base and the sky.
const BLOCK_COLOR := Color("#A8A8A3")
## Darker line along every cube edge, so cells can be counted.
const EDGE_COLOR := Color("#5E5E5A")
## Faded blocks keep the block colour at low opacity and a faint outline.
const FADED_COLOR := Color(BLOCK_COLOR, 0.15)
const FADED_EDGE_COLOR := Color(EDGE_COLOR, 0.45)
## The piece being placed is a wireframe (#62): a strong outline around the
## whole piece, fainter lines between its cubes and a barely-there fill.
const GHOST_OK_COLOR := Color(0.18, 0.62, 0.36)
const GHOST_OK_LINE_COLOR := Color(0.12, 0.44, 0.25)
const GHOST_BAD_COLOR := Color(0.85, 0.25, 0.2)
const GHOST_BAD_LINE_COLOR := Color(0.62, 0.17, 0.12)
const GHOST_FILL_ALPHA := 0.08
const GHOST_INNER_LINE_ALPHA := 0.35
const BASE_COLOR := Color("#CFCFCB")
const GUIDE_COLOR := Color(0.45, 0.45, 0.45, 0.55)
const BACKGROUND_COLOR := Color("#F4F4F2")
const BASE_THICKNESS := 0.4

const ClearingShader := preload("res://game/shaders/block_clearing.gdshader")

## A placed piece drops this far, in cubes, as it lands.
const DROP_HEIGHT := 0.6
const LAND_SECONDS := 0.1

# Line-clear effect (#24): the clear ripples out from the placed piece. Each
# cleared cube flashes and swells, then cracks into stone chips with a puff
# of dust.
## Delay between a cube and its neighbour one step further from the piece.
const RIPPLE_STEP_SECONDS := 0.025
const FLASH_COLOR := Color("#FFD23F")
const FLASH_EDGE_COLOR := Color("#B8860B")
const CRACK_SECONDS := 0.08
## A cube swells by this much just before it breaks.
const CRACK_SWELL := 0.09
## How long chips and dust last after a cube breaks.
const BURST_SECONDS := 0.5
const CHIPS_PER_CUBE := 5
const CHIP_GRAVITY := 11.0
const DUST_PER_CUBE := 2
const DUST_COLOR := Color("#D9D6CC")
## Clearing more than one line at once: extra chips and speed per extra line,
## and a camera shake.
const EXTRA_CHIPS_PER_LINE := 2
const BURST_PER_LINE := 0.35
const MAX_BURST := 2.0
const SHAKE_PER_LINE := 0.12
const MAX_SHAKE := 0.3
const SHAKE_SECONDS := 0.3

## Emitted when the move animation ends (or is skipped). Not emitted when it is
## cancelled.
signal move_animation_finished

var grid_size := Vector3i(6, 6, 12)
var rig: CameraRig

var _solid := MultiMeshInstance3D.new()
var _faded := MultiMeshInstance3D.new()
## The ghost's outer shell, drawn faintly. Its depth hides wireframe lines
## behind the piece.
var _ghost_fill := MeshInstance3D.new()
var _ghost_lines := MeshInstance3D.new()
var _ghost_fill_material := _ghost_shell_material()
var _ghost_lines_material := ShaderMaterial.new()
## Cubes of the piece being placed, drawn apart while they drop in.
var _landing := MultiMeshInstance3D.new()
## Cubes being cleared, drawn apart so the grid can update straight away.
var _clearing := MultiMeshInstance3D.new()
var _chips := MultiMeshInstance3D.new()
var _dust := MultiMeshInstance3D.new()
## Placed cells still landing; update_blocks leaves them out of the solid set.
var _landing_set := {}
var _landing_cells: Array = []
var _clearing_cells: Array = []
## When each clearing cube starts to crack, in seconds from the move.
var _clearing_starts: Array[float] = []
## One entry per chip or dust puff: { "cube", "offset", "velocity", ... }.
var _chip_list: Array = []
var _dust_list: Array = []
var _burst := 1.0
var _shake := 0.0
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
	_ghost_fill.mesh = ImmediateMesh.new()
	_ghost_fill.material_override = _ghost_fill_material
	_ghost_lines.mesh = ImmediateMesh.new()
	_ghost_lines_material.shader = GhostLinesShader
	# Drawn after every other see-through thing, lines last, so the fill's
	# depth only ever hides the ghost's own back lines.
	_ghost_lines_material.render_priority = 2
	_ghost_lines.material_override = _ghost_lines_material
	for node in [_ghost_fill, _ghost_lines]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
	_landing.multimesh = _make_multimesh()
	_landing.material_override = _solid.material_override
	_clearing.multimesh = _make_multimesh(true)
	var clearing_material := _block_material(ClearingShader, BLOCK_COLOR, EDGE_COLOR)
	clearing_material.set_shader_parameter("flash_face_color", FLASH_COLOR)
	clearing_material.set_shader_parameter("flash_edge_color", FLASH_EDGE_COLOR)
	_clearing.material_override = clearing_material
	_chips.multimesh = _make_multimesh(true, 1.0)
	var chip_material := _material(Color.WHITE)
	chip_material.vertex_color_use_as_albedo = true
	chip_material.vertex_color_is_srgb = true
	_chips.material_override = chip_material
	_dust.multimesh = _make_dust_multimesh()
	_dust.material_override = _dust_material()
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in [_solid, _faded, _ghost_fill, _ghost_lines, _landing, _clearing, _chips, _dust]:
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
	_ghost_fill_material.albedo_color = Color(
			GHOST_OK_COLOR if legal else GHOST_BAD_COLOR, GHOST_FILL_ALPHA)
	_ghost_lines_material.set_shader_parameter(
			"line_color", GHOST_OK_LINE_COLOR if legal else GHOST_BAD_LINE_COLOR)
	_build_ghost_shell(cells)
	_build_ghost_lines(cells)
	_ghost_fill.visible = true
	_ghost_lines.visible = true


func hide_ghost() -> void:
	_ghost_fill.visible = false
	_ghost_lines.visible = false


## Fills the ghost's outer faces only, so no walls show between its cubes.
func _build_ghost_shell(cells: Array) -> void:
	var mesh: ImmediateMesh = _ghost_fill.mesh
	mesh.clear_surfaces()
	var faces := ViewMath.exposed_faces(cells)
	if faces.is_empty():
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var corners := _face_corners(face[0], face[1])
		for i in [0, 1, 2, 0, 2, 3]:
			mesh.surface_add_vertex(corners[i])
	mesh.surface_end()


## The four world-space corners of one cube face, in order around it.
func _face_corners(c: Vector3i, d: Vector3i) -> Array[Vector3]:
	var axis := 0 if d.x != 0 else (1 if d.y != 0 else 2)
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var base := c
	if d[axis] > 0:
		base[axis] += 1
	var out: Array[Vector3] = []
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var p := base
		p[u] += o.x
		p[v] += o.y
		out.append(ViewMath.corner_to_world(p, grid_size))
	return out


## Outline in full strength, the edges between cubes fainter.
func _build_ghost_lines(cells: Array) -> void:
	var mesh: ImmediateMesh = _ghost_lines.mesh
	mesh.clear_surfaces()
	var edges := ViewMath.piece_edges(cells)
	if edges.outer.is_empty():
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for group in [[edges.inner, GHOST_INNER_LINE_ALPHA], [edges.outer, 1.0]]:
		for e in group[0]:
			mesh.surface_set_color(Color(1, 1, 1, group[1]))
			mesh.surface_add_vertex(ViewMath.corner_to_world(e[0], grid_size))
			mesh.surface_add_vertex(ViewMath.corner_to_world(e[1], grid_size))
	mesh.surface_end()


## Plays the move animation: `placed` cubes (minus any in `skip`, such as
## sliced-away ones) drop into place, then `cleared` cubes break apart one
## after another, starting next to the placed piece. `line_count` lines
## cleared at once make a bigger burst and, above one, shake the camera. The
## grid should already hold the result of the move; call update_blocks()
## after this so the landing cubes are left out.
func play_move(placed: Array, cleared: Array, skip: Dictionary, line_count := 1) -> void:
	cancel_move_animation()
	var cleared_set := {}
	for c in cleared:
		cleared_set[c] = true
	for c in placed:
		# Placed cubes that clear stay in the clearing set, so they land and
		# break in one place.
		if not cleared_set.has(c) and not skip.has(c):
			_landing_set[c] = true
			_landing_cells.append(c)
	_clearing_cells = cleared.duplicate()
	var total := LAND_SECONDS
	if not cleared.is_empty():
		var extra := maxi(line_count - 1, 0)
		_burst = minf(1.0 + BURST_PER_LINE * extra, MAX_BURST)
		_shake = minf(SHAKE_PER_LINE * extra, MAX_SHAKE)
		var steps := ViewMath.ripple_steps(cleared, placed)
		var last := 0.0
		for c in _clearing_cells:
			var start: float = LAND_SECONDS + steps[c] * RIPPLE_STEP_SECONDS
			_clearing_starts.append(start)
			last = maxf(last, start)
		_make_debris(CHIPS_PER_CUBE + EXTRA_CHIPS_PER_LINE * extra)
		total = last + CRACK_SECONDS + BURST_SECONDS
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
	_clearing_starts.clear()
	_chip_list.clear()
	_dust_list.clear()
	_shake = 0.0
	for node in [_landing, _clearing, _chips, _dust]:
		node.multimesh.instance_count = 0
	if rig != null:
		rig.camera.h_offset = 0.0
		rig.camera.v_offset = 0.0
	if notify:
		move_animation_finished.emit()


func _set_move_time(t: float) -> void:
	var land := clampf(t / LAND_SECONDS, 0.0, 1.0)
	var drop := Vector3(0, DROP_HEIGHT * (1.0 - ease(land, 0.4)), 0)
	var lmm := _landing.multimesh
	lmm.instance_count = _landing_cells.size()
	for i in range(_landing_cells.size()):
		lmm.set_instance_transform(i, Transform3D(Basis(), ViewMath.to_world(_landing_cells[i], grid_size) + drop))

	# Clearing cubes sit still until the ripple reaches them, flash and swell,
	# then break into chips and dust.
	var whole: Array[int] = []
	for i in range(_clearing_cells.size()):
		if t < _clearing_starts[i] + CRACK_SECONDS:
			whole.append(i)
	var cmm := _clearing.multimesh
	cmm.instance_count = whole.size()
	for n in range(whole.size()):
		var i := whole[n]
		var crack := clampf((t - _clearing_starts[i]) / CRACK_SECONDS, 0.0, 1.0)
		var swell := Basis().scaled(Vector3.ONE * (1.0 + CRACK_SWELL * crack))
		cmm.set_instance_transform(n, Transform3D(swell, ViewMath.to_world(_clearing_cells[i], grid_size)))
		cmm.set_instance_color(n, Color(crack, crack, crack))
	_draw_chips(t)
	_draw_dust(t)
	_draw_shake(t)


## Seconds since cube `i` broke, or -1 if it hasn't yet or its debris is gone.
func _burst_time(i: int, t: float) -> float:
	var since := t - _clearing_starts[i] - CRACK_SECONDS
	return since if since >= 0.0 and since < BURST_SECONDS else -1.0


## Rolls the chips and dust puffs for every clearing cube.
func _make_debris(chips_per_cube: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_clearing_cells)
	for i in range(_clearing_cells.size()):
		for k in range(chips_per_cube):
			var offset := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			var out := Vector3(offset.x, 0.0, offset.z).normalized()
			if out == Vector3.ZERO:
				out = Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)
			var speed := rng.randf_range(1.2, 2.6) * _burst
			var stone := rng.randf_range(0.82, 1.08)
			_chip_list.append({
				"cube": i,
				"offset": offset,
				"velocity": out * speed + Vector3.UP * rng.randf_range(1.5, 3.5) * _burst,
				"axis": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(),
				"spin": rng.randf_range(6.0, 14.0),
				"size": Vector3(rng.randf_range(0.16, 0.32), rng.randf_range(0.12, 0.26), rng.randf_range(0.16, 0.32)),
				"color": Color(BLOCK_COLOR.r * stone, BLOCK_COLOR.g * stone, BLOCK_COLOR.b * stone),
			})
		for k in range(DUST_PER_CUBE):
			_dust_list.append({
				"cube": i,
				"offset": Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.25, 0.25)),
				"rise": rng.randf_range(0.3, 0.7),
				"size": rng.randf_range(0.9, 1.3) * _burst,
			})


func _draw_chips(t: float) -> void:
	var live: Array = []
	for chip in _chip_list:
		var since: float = _burst_time(chip.cube, t)
		if since >= 0.0:
			live.append([chip, since])
	var mm := _chips.multimesh
	mm.instance_count = live.size()
	for n in range(live.size()):
		var chip: Dictionary = live[n][0]
		var since: float = live[n][1]
		var life := since / BURST_SECONDS
		# Chips keep their size for most of their flight, then shrink away.
		var fade := 1.0 - smoothstep(0.55, 1.0, life)
		var basis := Basis(chip.axis, chip.spin * since).scaled(chip.size * maxf(fade, 0.001))
		var origin: Vector3 = ViewMath.to_world(_clearing_cells[chip.cube], grid_size) + chip.offset \
			+ chip.velocity * since + Vector3.DOWN * 0.5 * CHIP_GRAVITY * since * since
		mm.set_instance_transform(n, Transform3D(basis, origin))
		mm.set_instance_color(n, chip.color)


func _draw_dust(t: float) -> void:
	var live: Array = []
	for puff in _dust_list:
		var since: float = _burst_time(puff.cube, t)
		if since >= 0.0:
			live.append([puff, since])
	# Puffs face the camera.
	var facing := rig.camera.global_transform.basis.orthonormalized()
	var mm := _dust.multimesh
	mm.instance_count = live.size()
	for n in range(live.size()):
		var puff: Dictionary = live[n][0]
		var since: float = live[n][1]
		var life := since / BURST_SECONDS
		var size: float = puff.size * (0.5 + ease(life, 0.4) * 0.9)
		var origin: Vector3 = ViewMath.to_world(_clearing_cells[puff.cube], grid_size) + puff.offset \
			+ Vector3.UP * puff.rise * life
		mm.set_instance_transform(n, Transform3D(facing.scaled(Vector3.ONE * size), origin))
		mm.set_instance_color(n, Color(DUST_COLOR, 0.55 * (1.0 - life) * minf(life * 8.0, 1.0)))


## Multi-line clears shake the camera from the first break, dying away.
func _draw_shake(t: float) -> void:
	if _shake <= 0.0 or _clearing_starts.is_empty():
		return
	var since: float = t - float(_clearing_starts.min()) - CRACK_SECONDS
	var left := 1.0 - clampf(since / SHAKE_SECONDS, 0.0, 1.0) if since >= 0.0 else 0.0
	var amount := _shake * left * left
	rig.camera.h_offset = amount * sin(since * 71.0)
	rig.camera.v_offset = amount * cos(since * 53.0)


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


func _make_multimesh(colors := false, size := CUBE_SIZE) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	mm.mesh = box
	return mm


func _make_dust_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = QuadMesh.new()
	return mm


## Soft round puff, tinted and faded per instance.
func _dust_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var puff := GradientTexture2D.new()
	puff.gradient = gradient
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	puff.width = 64
	puff.height = 64
	var m := _material(Color.WHITE, true, true)
	m.albedo_texture = puff
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


func _block_material(shader: Shader, face: Color, edge: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("face_color", face)
	m.set_shader_parameter("edge_color", edge)
	m.set_shader_parameter("half_size", CUBE_SIZE * 0.5)
	return m


## Faint, unlit, and drawn with a depth prepass so only the face nearest the
## camera shows and the wireframe behind it is hidden.
func _ghost_shell_material() -> StandardMaterial3D:
	var m := _material(Color(GHOST_OK_COLOR, GHOST_FILL_ALPHA), true, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 1
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
