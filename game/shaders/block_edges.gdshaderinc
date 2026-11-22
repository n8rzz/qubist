// Shared by the block shaders: darkens each cube face near its edges so
// neighbouring cubes read as separate cells. Works in the cube's local
// space, so one MultiMesh draw call covers every cube.

uniform vec4 face_color : source_color = vec4(0.66, 0.66, 0.64, 1.0);
uniform vec4 edge_color : source_color = vec4(0.40, 0.40, 0.38, 1.0);
// Half the cube's side length, in local units.
uniform float half_size = 0.47;
// Width of the darkened band along each edge, in local units.
uniform float edge_width = 0.045;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
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
