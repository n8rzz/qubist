// Shared by the block shaders. Works in the cube's local space, so one
// MultiMesh draw call covers every cube.
//
// edge_amount() gives the dark line along each cube edge, so neighbouring
// cubes read as separate cells. stone() (#22) adds the look of a cut stone
// block on top: a bevelled band round each face that catches the light
// differently from the face, a slightly lighter panel inside it and a few
// chipped corners, picked per cube so every block is a little different.

uniform vec4 face_color : source_color = vec4(0.66, 0.66, 0.64, 1.0);
uniform vec4 edge_color : source_color = vec4(0.40, 0.40, 0.38, 1.0);
// Half the cube's side length, in local units.
uniform float half_size = 0.485;
// Width of the darkened band along each edge, in local units.
uniform float edge_width = 0.03;
// Width of the bevel round each face, in local units, and how far it leans
// out from the face (1 is a 45 degree chamfer).
uniform float bevel_width = 0.085;
uniform float bevel_lean = 0.8;
// The bevel band is this much darker than the panel inside it.
uniform float bevel_shade = 0.07;
// Share of cube corners that are chipped, and how far a chip reaches along
// each edge from the corner, in local units.
uniform float chip_chance = 0.22;
uniform float chip_size = 0.13;
// A chip's broken face is this much darker than the stone.
uniform float chip_shade = 0.14;

varying vec3 local_pos;
// Where this cube sits, so each cube picks its own chipped corners.
varying vec3 cube_origin;
// The cube's local axes in view space, to turn bevel normals into NORMAL.
varying vec3 view_axis_x;
varying vec3 view_axis_y;
varying vec3 view_axis_z;

void vertex() {
	local_pos = VERTEX;
	cube_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	view_axis_x = normalize((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	view_axis_y = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	view_axis_z = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
}

// 1.0 on an edge, 0.0 in the middle of a face, anti-aliased.
float edge_amount() {
	vec3 a = abs(local_pos) / half_size;
	// On a face the largest component is 1; the edge is where the
	// middle one also reaches 1.
	float mid = max(min(a.x, a.y), min(max(a.x, a.y), a.z));
	float d = (1.0 - mid) * half_size;
	float aa = fwidth(d);
	return 1.0 - smoothstep(edge_width - aa, edge_width + aa, d);
}

float stone_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Stone colour for `face` (with `edge` along the edge lines), lit through a
// bevelled, chipped surface: sets `normal` (view space) for the fragment.
vec3 stone(vec3 face, vec3 edge, out vec3 normal) {
	vec3 p = local_pos / half_size;
	vec3 a = abs(p);
	vec3 s = sign(p);
	// The face this fragment is on: the axis where the cube reaches 1.
	vec3 n = a.x >= a.y && a.x >= a.z ? vec3(s.x, 0.0, 0.0)
		: (a.y >= a.z ? vec3(0.0, s.y, 0.0) : vec3(0.0, 0.0, s.z));
	vec3 in_face = vec3(1.0) - abs(n);
	// Distance to the face's edges along each in-face axis, in local units
	// (large on the face axis, so it never counts).
	vec3 to_edge = mix(vec3(10.0), (vec3(1.0) - a) * half_size, in_face);

	// Bevel: a flat chamfer leaning out toward the nearest edges.
	vec3 lean = vec3(0.0);
	float band = 0.0;
	for (int i = 0; i < 3; i++) {
		float d = to_edge[i];
		float aa = fwidth(d);
		float b = 1.0 - smoothstep(bevel_width - aa, bevel_width + aa, d);
		lean[i] = s[i] * b;
		band = max(band, b);
	}
	vec3 n_local = normalize(n + lean * bevel_lean);
	vec3 color = face * (1.0 - bevel_shade * band);

	// Chips: some corners (the same on all three faces that meet there) are
	// knocked off, leaving a darker facet that faces out of the corner.
	float chipped = step(stone_hash(floor(cube_origin * 2.0 + 0.5) + s * 0.37), chip_chance);
	float reach = chip_size * mix(0.7, 1.3, stone_hash(cube_origin + s * 1.91));
	float corner = to_edge.x * in_face.x + to_edge.y * in_face.y + to_edge.z * in_face.z;
	float caa = fwidth(corner);
	float chip = chipped * (1.0 - smoothstep(reach - caa, reach + caa, corner));
	n_local = normalize(mix(n_local, s, chip));
	color = mix(color, face * (1.0 - chip_shade), chip);

	color = mix(color, edge, edge_amount() * (1.0 - chip));
	normal = normalize(view_axis_x * n_local.x + view_axis_y * n_local.y + view_axis_z * n_local.z);
	return color;
}
