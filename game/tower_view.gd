extends Node3D
## 3D view of the tower: placed blocks, faded blocks, the ghost preview, the
## floating island under the footprint and guides for the grid and height.
## The background is left clear so the sky behind the viewport shows (#23).
##
## Knows nothing about rules; main.gd tells it which cells to draw how.

const ViewMath := preload("res://game/view_math.gd")
const CameraRig := preload("res://game/camera_rig.gd")
const FloatingIsland := preload("res://game/floating_island.gd")

const SolidShader := preload("res://game/shaders/block_solid.gdshader")
const FadedShader := preload("res://game/shaders/block_faded.gdshader")
const SweptEdgesShader := preload("res://game/shaders/block_swept_edges.gdshader")
const GhostLinesShader := preload("res://game/shaders/ghost_lines.gdshader")
const GhostShellShader := preload("res://game/shaders/ghost_shell.gdshader")

## Cubes fill most of their 1-unit cell, leaving a thin gap between blocks.
const CUBE_SIZE := 0.97
## Light grey stone (#22), one material for every placed cube. Lit, it lands
## near the designs' #ECE7DD tops and #B7AD9D / #D3CABB sides; the shader adds
## the bevel and chipped corners.
const BLOCK_COLOR := Color("#D9D3C8")
## Darker line along every cube edge, so cells can be counted.
const EDGE_COLOR := Color("#857B6D")
## Swept blocks (#85) are outlines only, with hidden lines removed, so the
## floor and empty cells show through them.
const SWEPT_EDGE_COLOR := Color(EDGE_COLOR, 0.3)
## While sliced, cubes behind the slice are light stone (#85), so the slice
## itself is the only full-strength grey.
const BEHIND_COLOR := Color("#F3F0EA")
const BEHIND_EDGE_COLOR := Color("#C4BCB0")
## The piece being placed (#22): the cubes' shape in translucent green, with a
## strong outline round the whole piece and fainter lines between its cubes.
## It only ever shows on legal spots, so it has no blocked look.
const GHOST_COLOR := Color(64 / 255.0, 201 / 255.0, 135 / 255.0, 0.35)
const GHOST_LINE_COLOR := Color("#2FAE72")
const GHOST_INNER_LINE_ALPHA := 0.55
const GUIDE_COLOR := Color(0.45, 0.45, 0.45, 0.55)
## Floor grid lines, white on the green floor as on Home.
const FLOOR_LINE_COLOR := Color(1, 1, 1, 0.55)
## Grid ticks on the tower's border (#56), off unless the player turns them on.
## Major ticks are darker as well as longer.
const TICK_COLOR := Color(0.4, 0.4, 0.4, 0.7)
const MAJOR_TICK_COLOR := Color(0.25, 0.25, 0.25, 0.9)
## The sun keeps this angle to the view as the tower turns, so the lit sides
## and the shadows look the same from every corner.
const SUN_PITCH_DEG := -55.0
const SUN_YAW_FROM_VIEW_DEG := -10.0
## Soft shadows (#23): blurred and only partly dark.
const SHADOW_OPACITY := 0.6
const SHADOW_BLUR := 2.5

# Sweep plane (#51): while the swiper moves, a bright pane marks the cut and
# the cube faces sitting on it light up. main.gd fades it in and out.
const SWEEP_COLOR := Color("#2559C9")
const SWEEP_FILL_ALPHA := 0.22
const SWEEP_CAP_ALPHA := 0.7
## Width of the pane's bright border, in cubes.
const SWEEP_BORDER := 0.09
## Lifts the lit faces off the cubes so they don't flicker against them.
const SWEEP_CAP_LIFT := 0.004

const ClearingShader := preload("res://game/shaders/block_clearing.gdshader")
const CrumblingShader := preload("res://game/shaders/block_crumbling.gdshader")

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

# Tower crumble on a loss (#132): the tower shakes as cracks spread through
# every cube, then it breaks apart from the top down and the pieces fall
# into a heap of rubble on the island, which stays until the next game.
## The shake before the first cube breaks.
const CRUMBLE_SHAKE_SECONDS := 0.8
## How far the tower sways and cubes rattle at the height of the shake.
const CRUMBLE_SWAY := 0.06
const CRUMBLE_RATTLE := 0.025
## Delay between one layer breaking and the one below, plus a random stagger
## within each layer.
const CRUMBLE_LAYER_SECONDS := 0.07
const CRUMBLE_JITTER_SECONDS := 0.08
const RUBBLE_PER_CUBE := 4
const RUBBLE_GRAVITY := 16.0
## Rubble left per broken cube, in cubic units, for sizing the heap.
const RUBBLE_FILL := 0.12
const RUBBLE_MIN_PEAK := 0.35
const RUBBLE_MAX_PEAK := 2.4
## The heap keeps this far inside the island's grass edge.
const RUBBLE_EDGE_MARGIN := 0.4
## How far each piece drifts from under its cube toward a random spot in the
## heap (0 lands straight down, 1 anywhere).
const RUBBLE_SCATTER := 0.7
const CRUMBLE_DUST_SECONDS := 0.7
## The camera rumbles while the tower comes down.
const CRUMBLE_RUMBLE := 0.12
const CRUMBLE_RUMBLE_FADE_SECONDS := 0.5

## Emitted when the move animation ends (or is skipped). Not emitted when it is
## cancelled.
signal move_animation_finished
## Emitted when the crumble ends (or is skipped), with the rubble at rest.
## Not emitted when it is cleared.
signal crumble_finished

var grid_size := Vector3i(6, 6, 12)
var rig: CameraRig

var _solid := MultiMeshInstance3D.new()
var _faded := MultiMeshInstance3D.new()
## Cubes behind the slice, drawn lighter while the tower is sliced.
var _behind := MultiMeshInstance3D.new()
## The ghost's outer shell. Its depth hides the ghost's lines behind the
## piece.
var _ghost_fill := MeshInstance3D.new()
var _ghost_lines := MeshInstance3D.new()
var _ghost_fill_material := _ghost_shell_material()
var _ghost_lines_material := _ghost_line_material()
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
## The crumble (#132): whole cubes shaking and cracking, the rubble they
## break into and their dust.
var _crumbling := MultiMeshInstance3D.new()
var _rubble := MultiMeshInstance3D.new()
var _crumble_dust := MultiMeshInstance3D.new()
## True from play_crumble() until clear_crumble(): placed blocks are hidden.
var _crumbled := false
var _crumble_cells: Array = []
## When each cube breaks, in seconds from the start of the crumble.
var _crumble_breaks: Array[float] = []
## Per-cube seed in 0..1 for its crack pattern and rattle.
var _crumble_seeds: Array[float] = []
## One entry per rubble piece: { "start", "rest", "up", "fall", ... }.
var _rubble_list: Array = []
var _crumble_dust_list: Array = []
var _crumble_total := 0.0
var _crumble_tween: Tween
## The sweep pane and the lit faces under it, in one mesh.
var _sweep := MeshInstance3D.new()
var _sweep_material := _sweep_plane_material()
var _ticks := MeshInstance3D.new()
var _sun := DirectionalLight3D.new()
## Snow on the cubes' tops (#168), as set_snow() last set it.
var _snow := 0.0


func setup(size: Vector3i) -> void:
	grid_size = size
	_add_environment()
	var island := FloatingIsland.new()
	island.setup(size)
	add_child(island)
	_add_guides()
	_add_ticks()

	_solid.multimesh = _make_multimesh()
	_solid.material_override = _block_material(SolidShader, BLOCK_COLOR, EDGE_COLOR)
	_behind.multimesh = _make_multimesh()
	_behind.material_override = _block_material(SolidShader, BEHIND_COLOR, BEHIND_EDGE_COLOR)
	_faded.multimesh = _make_multimesh()
	_faded.material_override = _swept_material()
	_faded.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_fill.mesh = ImmediateMesh.new()
	_ghost_fill.material_override = _ghost_fill_material
	_ghost_lines.mesh = ImmediateMesh.new()
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
	_dust.multimesh = _make_multimesh(true, CUBE_SIZE, QuadMesh.new())
	_dust.material_override = _dust_material()
	# Before swept cubes, whose invisible faces would otherwise cut holes in
	# the puffs.
	_dust.material_override.render_priority = -3
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crumbling.multimesh = _make_multimesh(true)
	_crumbling.material_override = _block_material(CrumblingShader, BLOCK_COLOR, EDGE_COLOR)
	_rubble.multimesh = _make_multimesh(true, 1.0)
	_rubble.material_override = chip_material
	_crumble_dust.multimesh = _make_multimesh(true, CUBE_SIZE, QuadMesh.new())
	_crumble_dust.material_override = _dust.material_override
	_crumble_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sweep.mesh = ImmediateMesh.new()
	_sweep.material_override = _sweep_material
	_sweep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sweep.visible = false
	for node in [_solid, _behind, _faded, _ghost_fill, _ghost_lines, _landing, _clearing, _chips, _dust,
			_crumbling, _rubble, _crumble_dust, _sweep]:
		add_child(node)

	rig = CameraRig.new()
	rig.position = Vector3(0, size.z * 0.42, 0)
	add_child(rig)
	_follow_view()


func _process(_delta: float) -> void:
	_follow_view()


func _follow_view() -> void:
	if rig != null:
		_sun.rotation = Vector3(deg_to_rad(SUN_PITCH_DEG),
			rig.rotation.y + deg_to_rad(SUN_YAW_FROM_VIEW_DEG), 0)


## Shows or hides the grid ticks on the tower's border (#56).
func set_grid_ticks(on: bool) -> void:
	_ticks.visible = on


## Lays snow on the placed cubes' tops (#168), 0 for none to 1 for winter.
func set_snow(amount: float) -> void:
	_snow = amount
	for node in [_solid, _behind]:
		(node.material_override as ShaderMaterial).set_shader_parameter("snow", amount)


func snow_amount() -> float:
	return _snow


func grid_ticks_visible() -> bool:
	return _ticks.visible


## Draws `cells`; those in `faded` (a set of Vector3i keys) are see-through
## outlines and those in `behind` (cubes behind the slice) are lighter.
## Draws nothing once the tower has crumbled, until clear_crumble().
func update_blocks(cells: Array, faded: Dictionary, behind := {}) -> void:
	if _crumbled:
		cells = []
	var solid: Array = []
	var faint: Array = []
	var light: Array = []
	for c in cells:
		if faded.has(c):
			faint.append(c)
		elif _landing_set.has(c):
			continue
		elif behind.has(c):
			light.append(c)
		else:
			solid.append(c)
	_fill(_solid, solid)
	_fill(_faded, faint)
	_fill(_behind, light)


## Builds the sweep pane over `plane` (four core corners, from
## ViewMath.slice_plane) and lights the `toward` faces of `cap_cells`, the
## cubes sitting on the cut. Call set_sweep_alpha() to show it.
func set_sweep(plane: Array, toward: Vector3i, cap_cells: Array) -> void:
	var mesh: ImmediateMesh = _sweep.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer: Array[Vector3] = []
	for p in plane:
		outer.append(ViewMath.corner_to_world(p, grid_size))
	# Inset each corner along both of its edges to get the border's inside.
	var inner: Array[Vector3] = []
	for i in range(4):
		var c := outer[i]
		var next := (outer[(i + 1) % 4] - c).normalized()
		var prev := (outer[(i + 3) % 4] - c).normalized()
		inner.append(c + (next + prev) * SWEEP_BORDER)
	_add_quad(mesh, inner, Color(SWEEP_COLOR, SWEEP_FILL_ALPHA))
	for i in range(4):
		var j := (i + 1) % 4
		_add_quad(mesh, [outer[i], outer[j], inner[j], inner[i]], SWEEP_COLOR)

	var normal := Vector3(toward.x, toward.z, toward.y)
	var u := Vector3(normal.y, normal.z, normal.x).abs()
	var v := normal.cross(u).abs()
	var half := CUBE_SIZE * 0.5
	for c in cap_cells:
		var center := ViewMath.to_world(c, grid_size) + normal * (half + SWEEP_CAP_LIFT)
		_add_quad(mesh, [
			center + (-u - v) * half, center + (u - v) * half,
			center + (u + v) * half, center + (-u + v) * half,
		], Color(SWEEP_COLOR, SWEEP_CAP_ALPHA))
	mesh.surface_end()


## 0 hides the sweep plane, 1 shows it at full strength. Stays hidden once
## the tower has crumbled.
func set_sweep_alpha(alpha: float) -> void:
	_sweep_material.albedo_color = Color(1, 1, 1, alpha)
	_sweep.visible = alpha > 0.0 and not _crumbled


func _add_quad(mesh: ImmediateMesh, corners: Array, color: Color) -> void:
	mesh.surface_set_color(color)
	for i in [0, 1, 2, 0, 2, 3]:
		mesh.surface_add_vertex(corners[i])


## Shows the ghost over `cells`. Only call it for a legal spot (#22).
func show_ghost(cells: Array) -> void:
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
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for face in faces:
		var corners := _face_corners(face[0], face[1])
		for i in [0, 1, 2, 0, 2, 3]:
			mesh.surface_set_uv(uvs[i])
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


# --- Crumble (#132) ---

## Plays the loss animation over `cells`, every placed cube: the tower shakes
## and cracks, then breaks from the top down into a heap of rubble that stays
## until clear_crumble(). Placed blocks, the ghost and the sweep pane are
## hidden meanwhile. Emits crumble_finished when the rubble has settled.
func play_crumble(cells: Array) -> void:
	clear_crumble()
	cancel_move_animation()
	_crumbled = true
	hide_ghost()
	set_sweep_alpha(0.0)
	update_blocks([], {})
	_crumble_cells = cells.duplicate()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_crumble_cells)
	var jitter: Array = []
	for c in _crumble_cells:
		jitter.append(rng.randf())
		_crumble_seeds.append(rng.randf())
	for start in ViewMath.crumble_starts(_crumble_cells, jitter, CRUMBLE_LAYER_SECONDS, CRUMBLE_JITTER_SECONDS):
		_crumble_breaks.append(CRUMBLE_SHAKE_SECONDS + start)

	var rim := FloatingIsland.rim_half(grid_size)
	var radius := minf(rim.x, rim.y) - RUBBLE_EDGE_MARGIN
	var peak := ViewMath.rubble_peak(_crumble_cells.size(), radius, RUBBLE_FILL, RUBBLE_MIN_PEAK, RUBBLE_MAX_PEAK)
	_crumble_total = 0.0
	for i in range(_crumble_cells.size()):
		var center := ViewMath.to_world(_crumble_cells[i], grid_size)
		var broken := _crumble_breaks[i] + CRACK_SECONDS
		for k in range(RUBBLE_PER_CUBE):
			var start := center + Vector3(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28))
			var spot := Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
			var land := Vector2(start.x, start.z).lerp(spot, RUBBLE_SCATTER)
			if land.length() > radius:
				land = land.normalized() * radius
			var size := Vector3(rng.randf_range(0.26, 0.46), rng.randf_range(0.18, 0.34), rng.randf_range(0.26, 0.46))
			var lift := ViewMath.rubble_height(land.length(), peak, radius) * rng.randf_range(0.7, 1.0)
			var rest := Vector3(land.x, lift + size.y * 0.5, land.y)
			var up := rng.randf_range(0.5, 2.5)
			var fall := ViewMath.fall_seconds(start.y - rest.y, up, RUBBLE_GRAVITY)
			var stone := rng.randf_range(0.8, 1.06)
			_rubble_list.append({
				"cube": i,
				"start": start,
				"rest": rest,
				"up": up,
				"fall": fall,
				"axis": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(),
				"spin": rng.randf_range(3.0, 8.0),
				"size": size,
				"color": Color(BLOCK_COLOR.r * stone, BLOCK_COLOR.g * stone, BLOCK_COLOR.b * stone),
			})
			_crumble_total = maxf(_crumble_total, broken + fall)
		for k in range(DUST_PER_CUBE):
			_crumble_dust_list.append({
				"cube": i,
				"offset": Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.3, 0.3)),
				"rise": rng.randf_range(0.2, 0.6),
				"size": rng.randf_range(1.0, 1.5),
			})
		_crumble_total = maxf(_crumble_total, broken + CRUMBLE_DUST_SECONDS)

	_set_crumble_time(0.0)
	_crumble_tween = create_tween()
	_crumble_tween.tween_method(_set_crumble_time, 0.0, _crumble_total, _crumble_total)
	_crumble_tween.finished.connect(_end_crumble.bind(true))


func is_crumbling() -> bool:
	return _crumble_tween != null and _crumble_tween.is_valid()


## True from play_crumble() until clear_crumble(), the rubble included.
func has_crumbled() -> bool:
	return _crumbled


## Placed cubes drawn solid. None while the tower is crumbled.
func solid_count() -> int:
	return _solid.multimesh.instance_count


## Whole cubes drawn shaking before they break.
func crumbling_count() -> int:
	return _crumbling.multimesh.instance_count


## Rubble pieces drawn.
func rubble_count() -> int:
	return _rubble.multimesh.instance_count


## Where each rubble piece comes to rest, in the tower's space.
func rubble_rests() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for piece in _rubble_list:
		out.append(piece.rest)
	return out


## Jumps the crumble to its settled rubble, emitting crumble_finished.
func finish_crumble() -> void:
	if is_crumbling():
		_crumble_tween.kill()
		_set_crumble_time(_crumble_total)
		_end_crumble(true)


## Sweeps the rubble away and lets update_blocks() draw placed cubes again,
## without emitting crumble_finished.
func clear_crumble() -> void:
	if _crumble_tween != null:
		_crumble_tween.kill()
	_end_crumble(false)
	_crumbled = false
	_crumble_cells.clear()
	_crumble_breaks.clear()
	_crumble_seeds.clear()
	_rubble_list.clear()
	_crumble_dust_list.clear()
	for node in [_crumbling, _rubble, _crumble_dust]:
		node.multimesh.instance_count = 0


## Leaves the rubble where it lies.
func _end_crumble(notify: bool) -> void:
	_crumble_tween = null
	if rig != null:
		rig.camera.h_offset = 0.0
		rig.camera.v_offset = 0.0
	if notify:
		crumble_finished.emit()


func _set_crumble_time(t: float) -> void:
	_draw_crumbling_cubes(t)
	_draw_rubble(t)
	_draw_crumble_dust(t)
	_draw_rumble(t)


## Cubes still standing sway with the tower and rattle on their own, cracking
## more the closer they are to breaking, and swell just before they go.
func _draw_crumbling_cubes(t: float) -> void:
	var shake := smoothstep(0.0, CRUMBLE_SHAKE_SECONDS, t)
	var sway := Vector3(sin(t * 37.0), 0.0, cos(t * 29.0)) * CRUMBLE_SWAY * shake
	var standing: Array[int] = []
	for i in range(_crumble_cells.size()):
		if t < _crumble_breaks[i] + CRACK_SECONDS:
			standing.append(i)
	var mm := _crumbling.multimesh
	mm.instance_count = standing.size()
	for n in range(standing.size()):
		var i := standing[n]
		var cube_seed := _crumble_seeds[i]
		var cell: Vector3i = _crumble_cells[i]
		# Higher cubes sway further, as if the tower rocks on its base.
		var lean := sway * (0.3 + 0.7 * float(cell.z + 1) / grid_size.z)
		var rattle := Vector3(sin(t * 61.0 + cube_seed * 40.0), 0.5 * sin(t * 73.0 + cube_seed * 17.0),
			cos(t * 67.0 + cube_seed * 29.0)) * CRUMBLE_RATTLE * shake
		var crack := clampf(t / _crumble_breaks[i], 0.0, 1.0)
		var swell := clampf((t - _crumble_breaks[i]) / CRACK_SECONDS, 0.0, 1.0)
		var basis := Basis(Vector3(cube_seed - 0.5, 0.0, 0.5 - cube_seed).normalized(), 0.04 * shake * sin(t * 41.0 + cube_seed * 9.0)) \
			.scaled(Vector3.ONE * (1.0 + CRACK_SWELL * swell))
		mm.set_instance_transform(n, Transform3D(basis, ViewMath.to_world(cell, grid_size) + lean + rattle))
		mm.set_instance_color(n, Color(ease(crack, 0.6), cube_seed, 0.0))


## Pieces fly out from each broken cube and fall onto the heap, where they
## stay.
func _draw_rubble(t: float) -> void:
	var live: Array = []
	for piece in _rubble_list:
		var since: float = t - _crumble_breaks[piece.cube] - CRACK_SECONDS
		if since >= 0.0:
			live.append([piece, since])
	var mm := _rubble.multimesh
	mm.instance_count = live.size()
	for n in range(live.size()):
		var piece: Dictionary = live[n][0]
		var since: float = minf(live[n][1], piece.fall)
		var start: Vector3 = piece.start
		var rest: Vector3 = piece.rest
		var along := since / maxf(piece.fall, 0.001)
		var origin := Vector3(
			lerpf(start.x, rest.x, along),
			start.y + piece.up * since - 0.5 * RUBBLE_GRAVITY * since * since,
			lerpf(start.z, rest.z, along))
		if since >= piece.fall:
			origin = rest
		var basis := Basis(piece.axis, piece.spin * since).scaled(piece.size)
		mm.set_instance_transform(n, Transform3D(basis, origin))
		mm.set_instance_color(n, piece.color)


func _draw_crumble_dust(t: float) -> void:
	var live: Array = []
	for puff in _crumble_dust_list:
		var since: float = t - _crumble_breaks[puff.cube] - CRACK_SECONDS
		if since >= 0.0 and since < CRUMBLE_DUST_SECONDS:
			live.append([puff, since])
	var facing := rig.camera.global_transform.basis.orthonormalized()
	var mm := _crumble_dust.multimesh
	mm.instance_count = live.size()
	for n in range(live.size()):
		var puff: Dictionary = live[n][0]
		var life: float = live[n][1] / CRUMBLE_DUST_SECONDS
		var size: float = puff.size * (0.5 + ease(life, 0.4) * 0.9)
		var origin: Vector3 = ViewMath.to_world(_crumble_cells[puff.cube], grid_size) + puff.offset \
			+ Vector3.UP * puff.rise * life
		mm.set_instance_transform(n, Transform3D(facing.scaled(Vector3.ONE * size), origin))
		mm.set_instance_color(n, Color(DUST_COLOR, 0.5 * (1.0 - life) * minf(life * 8.0, 1.0)))


## The camera rumbles from the shake until the last cube breaks, then settles.
func _draw_rumble(t: float) -> void:
	if rig == null or _crumble_breaks.is_empty():
		return
	var last: float = float(_crumble_breaks.max()) + CRACK_SECONDS
	var amount := CRUMBLE_RUMBLE * smoothstep(CRUMBLE_SHAKE_SECONDS * 0.5, CRUMBLE_SHAKE_SECONDS, t)
	if t > last:
		var left := 1.0 - clampf((t - last) / CRUMBLE_RUMBLE_FADE_SECONDS, 0.0, 1.0)
		amount *= left * left
	rig.camera.h_offset = amount * sin(t * 71.0)
	rig.camera.v_offset = amount * cos(t * 53.0)


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
## `gap` pixels outside the middle of the island's right-front and left-front
## edges, the edges the swiper's X and Y modes cut along. Z sits `gap` pixels
## below the island's front corner.
func axis_label_points(gap: float) -> Array[Vector2]:
	var half := FloatingIsland.rim_half(grid_size)
	var hx := half.x
	var hz := half.y
	var y := FloatingIsland.rim_bottom()
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


## A MultiMesh of `mesh`, or of cubes `size` wide when no mesh is given.
func _make_multimesh(colors := false, size := CUBE_SIZE, mesh: Mesh = null) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	if mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * size
		mesh = box
	mm.mesh = mesh
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


## Translucent green faces (ghost_shell.gdshader). Drawn early among the
## see-through things, so swept cubes come after it and leave it uncovered.
func _ghost_shell_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GhostShellShader
	m.set_shader_parameter("fill_color", GHOST_COLOR)
	m.render_priority = -4
	return m


## Lines are drawn last of the see-through things, so the fill's depth hides
## the ghost's own back lines and swept cubes never cover them.
func _ghost_line_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GhostLinesShader
	m.set_shader_parameter("line_color", GHOST_LINE_COLOR)
	m.render_priority = 2
	return m


## Unlit and tinted per vertex. Drawn after the ghost's fill and before
## swept cubes, so the pane shows whole and swept outlines draw over it.
func _sweep_plane_material() -> StandardMaterial3D:
	var m := _material(Color(1, 1, 1, 0), true, true)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = -3
	return m


## Swept cubes (#85): a depth-only pass, then the edges of the nearest swept
## faces. After the sweep pane and the ghost's fill, so neither is cut by the
## invisible faces.
func _swept_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FadedShader
	m.render_priority = -2
	var edges := _block_material(SweptEdgesShader, SWEPT_EDGE_COLOR, SWEPT_EDGE_COLOR)
	edges.render_priority = -2
	m.next_pass = edges
	return m


## Guide and tick lines draw before every other see-through thing, so swept
## cubes' invisible faces (#85) don't hide them.
func _early_lines_material(color: Color) -> StandardMaterial3D:
	var m := _material(color, true, true)
	m.render_priority = -5
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
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_sun.light_energy = 0.9
	_sun.shadow_enabled = true
	_sun.shadow_opacity = SHADOW_OPACITY
	_sun.shadow_blur = SHADOW_BLUR
	# One orthogonal map covers the whole tower; the camera sits 50 units out.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 80.0
	add_child(_sun)


## Floor grid lines (white) and the outline of the floor and the full-height
## bounding box (grey).
func _add_guides() -> void:
	var hx := grid_size.x * 0.5
	var hz := grid_size.y * 0.5
	var top := float(grid_size.z)
	var floor_y := 0.005
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _early_lines_material(FLOOR_LINE_COLOR))
	for i in range(1, grid_size.x):
		mesh.surface_add_vertex(Vector3(-hx + i, floor_y, -hz))
		mesh.surface_add_vertex(Vector3(-hx + i, floor_y, hz))
	for i in range(1, grid_size.y):
		mesh.surface_add_vertex(Vector3(-hx, floor_y, -hz + i))
		mesh.surface_add_vertex(Vector3(hx, floor_y, -hz + i))
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _early_lines_material(GUIDE_COLOR))
	var corners := [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		mesh.surface_add_vertex(Vector3(a.x, floor_y, a.y))
		mesh.surface_add_vertex(Vector3(b.x, floor_y, b.y))
		mesh.surface_add_vertex(Vector3(a.x, 0, a.y))
		mesh.surface_add_vertex(Vector3(a.x, top, a.y))
		mesh.surface_add_vertex(Vector3(a.x, top, a.y))
		mesh.surface_add_vertex(Vector3(b.x, top, b.y))
	mesh.surface_end()
	var guides := MeshInstance3D.new()
	guides.mesh = mesh
	guides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(guides)


## Grid ticks (#56): minor and major marks as two line surfaces, hidden
## until set_grid_ticks() turns them on.
func _add_ticks() -> void:
	var ticks := ViewMath.border_ticks(grid_size)
	var mesh := ImmediateMesh.new()
	for group in [[ticks.minor, TICK_COLOR], [ticks.major, MAJOR_TICK_COLOR]]:
		var points: Array = group[0]
		if points.is_empty():
			continue
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, _early_lines_material(group[1]))
		for p in points:
			mesh.surface_add_vertex(p)
		mesh.surface_end()
	_ticks.mesh = mesh
	_ticks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ticks.visible = false
	add_child(_ticks)
