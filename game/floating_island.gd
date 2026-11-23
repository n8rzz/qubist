extends Node3D
## The floating island under the tower on the game screen (#23): the floor
## under the footprint, a strip of shallow water round it, a grass border, a
## brick rim and an earth underside that tapers to a point, plus two bushes
## and a rock.
##
## Colours come from the Home art (island_art.gd) so the screens match, and
## the proportions follow the Home design: one cell of grass beyond the
## footprint, a 0.38-cell water strip, a rim 0.85 of a cube deep. It sits in
## world space under the tower, so it turns and zooms with it. Tops are lit
## and catch the cubes' shadows; sides are flat colours, darker on the left.

const IslandArt := preload("res://game/island_art.gd")
const SideShader := preload("res://game/shaders/island_side.gdshader")

## Grass reaches this many cells past the footprint on every side.
const GRASS_MARGIN := 1.0
const WATER_MARGIN := 0.38
## Tops step down a hair from the floor so they never fight for depth.
const FLOOR_Y := 0.0
const WATER_Y := -0.012
const GRASS_Y := -0.024
## The grass's own edge, then the brick below it, in cubes.
const GRASS_DEPTH := 0.16
const RIM_DEPTH := 0.85
## The underside, as (fraction of the rim's half-size, depth below the rim)
## from the rim down to the point. Traced from the Home art's outline.
const UNDERSIDE := [
	Vector2(1.0, 0.0),
	Vector2(0.85, 1.6),
	Vector2(0.7, 2.5),
	Vector2(0.51, 4.15),
	Vector2(0.0, 5.8),
]
## Heights of the two strata lines on the underside, below the rim.
const STRATA := Vector2(0.9, 2.1)
## Ripples in the water strip, in the middle of it: [side, from, to], side 0
## along the +x edge and 1 along the +y edge (core axes), from and to as
## fractions of that edge, as on Home.
const RIPPLES := [[0, 0.2, 0.317], [0, 0.6, 0.717], [1, 0.333, 0.45], [1, 0.767, 0.883]]
const RIPPLE_WIDTH := 0.07
const BUSH_RADIUS := 0.42
## Darkens the lit tops so, under the sun and ambient light together, they
## come out close to the Home art's flat colours.
const TOP_TINT := Color(0.88, 0.88, 0.88)

var grid_size := Vector3i(6, 6, 12)


func setup(size: Vector3i) -> void:
	grid_size = size
	_add_tops()
	_add_sides()
	_add_props()


## Half the grass's width and depth, in world units.
static func rim_half(size: Vector3i) -> Vector2:
	return Vector2(size.x * 0.5 + GRASS_MARGIN, size.y * 0.5 + GRASS_MARGIN)


static func rim_bottom() -> float:
	return GRASS_Y - RIM_DEPTH


## Grass, water, floor and ripples, lit so they catch shadows.
func _add_tops() -> void:
	var hx := grid_size.x * 0.5
	var hz := grid_size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	_rect(st, hx + GRASS_MARGIN, hz + GRASS_MARGIN, GRASS_Y, IslandArt.GRASS)
	_rect(st, hx + WATER_MARGIN, hz + WATER_MARGIN, WATER_Y, IslandArt.WATER)
	_rect(st, hx, hz, FLOOR_Y, IslandArt.FLOOR)
	var mid := WATER_MARGIN * 0.5
	for r in RIPPLES:
		var a: Vector3
		var b: Vector3
		if r[0] == 0:
			a = Vector3(hx + mid, 0, -hz + grid_size.y * r[1])
			b = Vector3(hx + mid, 0, -hz + grid_size.y * r[2])
		else:
			a = Vector3(-hx + grid_size.x * r[1], 0, hz + mid)
			b = Vector3(-hx + grid_size.x * r[2], 0, hz + mid)
		var across := (b - a).normalized().cross(Vector3.UP) * RIPPLE_WIDTH * 0.5
		_quad(st, [a - across, b - across, b + across, a + across], WATER_Y + 0.003, IslandArt.RIPPLE)
	var tops := MeshInstance3D.new()
	tops.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = TOP_TINT
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	tops.material_override = m
	tops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tops)


## Grass edge, brick rim and earth underside.
func _add_sides() -> void:
	var half := rim_half(grid_size)
	var grass_bottom := GRASS_Y - GRASS_DEPTH
	var bottom := rim_bottom()

	var grass := _ring_band(half, GRASS_Y, half, grass_bottom)
	_add_side(grass, _side_material(IslandArt.GRASS_LEFT, IslandArt.GRASS_RIGHT))

	var brick := _side_material(IslandArt.BRICK_LEFT, IslandArt.BRICK_RIGHT)
	brick.set_shader_parameter("pattern", 1)
	brick.set_shader_parameter("line_color", IslandArt.MORTAR)
	brick.set_shader_parameter("top_y", GRASS_Y)
	brick.set_shader_parameter("course", RIM_DEPTH * 0.5)
	_add_side(_ring_band(half, grass_bottom, half, bottom), brick)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(UNDERSIDE.size() - 1):
		var a: Vector2 = UNDERSIDE[i]
		var b: Vector2 = UNDERSIDE[i + 1]
		_band(st, half * a.x, bottom - a.y, half * b.x, bottom - b.y)
	var earth := _side_material(IslandArt.EARTH_LEFT, IslandArt.EARTH_RIGHT)
	earth.set_shader_parameter("pattern", 2)
	earth.set_shader_parameter("line_color", IslandArt.EARTH_STRATA)
	earth.set_shader_parameter("line_width", 0.05)
	earth.set_shader_parameter("strata_a", bottom - STRATA.x)
	earth.set_shader_parameter("strata_b", bottom - STRATA.y)
	_add_side(st.commit(), earth)


func _ring_band(top_half: Vector2, top_y: float, bottom_half: Vector2, bottom_y: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_band(st, top_half, top_y, bottom_half, bottom_y)
	return st.commit()


## Four faces joining a rectangle at `top_y` to a smaller or equal one at
## `bottom_y`, each with an outward normal.
func _band(st: SurfaceTool, top_half: Vector2, top_y: float, bottom_half: Vector2, bottom_y: float) -> void:
	var signs := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	for i in range(4):
		var s0: Vector2 = signs[i]
		var s1: Vector2 = signs[(i + 1) % 4]
		var corners := [
			Vector3(top_half.x * s0.x, top_y, top_half.y * s0.y),
			Vector3(top_half.x * s1.x, top_y, top_half.y * s1.y),
			Vector3(bottom_half.x * s1.x, bottom_y, bottom_half.y * s1.y),
			Vector3(bottom_half.x * s0.x, bottom_y, bottom_half.y * s0.y),
		]
		var outward := Vector3((s0.x + s1.x) * 0.5, 0, (s0.y + s1.y) * 0.5)
		var normal: Vector3 = (corners[1] - corners[0]).cross(corners[3] - corners[0]).normalized()
		if normal.dot(outward) < 0.0:
			normal = -normal
		st.set_normal(normal)
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(corners[k])


func _add_side(mesh: Mesh, material: ShaderMaterial) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _side_material(left: Color, right: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SideShader
	m.set_shader_parameter("left_color", left)
	m.set_shader_parameter("right_color", right)
	return m


## Bushes at the grass's left and right corners and a rock by the water at
## the front, placed as on Home (at the starting view).
func _add_props() -> void:
	var hx := grid_size.x * 0.5
	var hz := grid_size.y * 0.5
	var bush_material := StandardMaterial3D.new()
	bush_material.albedo_color = IslandArt.BUSH
	for spot in [[Vector2(hx + 0.67, -hz - 0.4), 1.0], [Vector2(-hx - 0.4, hz + 0.65), 0.857]]:
		var sphere := SphereMesh.new()
		sphere.radius = BUSH_RADIUS * spot[1]
		sphere.height = sphere.radius * 2.0
		var bush := MeshInstance3D.new()
		bush.mesh = sphere
		bush.material_override = bush_material
		bush.position = Vector3(spot[0].x, GRASS_Y + sphere.radius * 0.8, spot[0].y)
		add_child(bush)

	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.16, 0.24)
	var rock := MeshInstance3D.new()
	rock.mesh = box
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = IslandArt.ROCK
	rock.material_override = rock_material
	rock.position = Vector3(hx + 0.2, WATER_Y + 0.05, hz + 0.2)
	rock.rotation.y = deg_to_rad(25)
	add_child(rock)


func _rect(st: SurfaceTool, hx: float, hz: float, y: float, color: Color) -> void:
	_quad(st, [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)], y, color)


func _quad(st: SurfaceTool, corners: Array, y: float, color: Color) -> void:
	st.set_color(color)
	for k in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = corners[k]
		st.add_vertex(Vector3(p.x, y, p.z))
