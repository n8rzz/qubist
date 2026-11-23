shader_type spatial;
// Marks the stencil so swept cubes never draw over these (#67).
stencil_mode write, compare_always, 1;

// Cubes cracking as the tower crumbles on a loss (#132). Each instance's
// colour carries its state, so the whole tower is one MultiMesh draw: red is
// how far the cracks have spread (0 to 1), green a per-cube seed so each
// cube cracks its own way and the pattern holds still while it shakes.

#include "res://game/shaders/block_edges.gdshaderinc"

uniform vec4 crack_color : source_color = vec4(0.27, 0.24, 0.20, 1.0);
// Width of a fully opened crack, in local units.
uniform float crack_width = 0.022;
// Crack cells across one face.
uniform float crack_scale = 1.0;

vec2 crack_hash(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Distance to the nearest border between Voronoi cells, and the id of the
// cell `g` is in. The borders are the cracks.
float crack_border(vec2 g, out vec2 cell) {
	vec2 i = floor(g);
	vec2 f = fract(g);
	vec2 nearest = vec2(8.0);
	float best = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + crack_hash(i + o) - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest = r;
				cell = i + o;
			}
		}
	}
	float border = 8.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + crack_hash(i + o) - f;
			vec2 gap = r - nearest;
			if (dot(gap, gap) > 0.0001) {
				border = min(border, dot(0.5 * (nearest + r), normalize(gap)));
			}
		}
	}
	return border;
}

void fragment() {
	vec3 n;
	vec3 rock = stone(face_color.rgb, edge_color.rgb, n);
	float amount = clamp(COLOR.r, 0.0, 1.0);

	// Flatten the face this fragment is on to 2D, seeded per cube and face.
	vec3 p = local_pos / half_size;
	vec3 a = abs(p);
	vec3 s = sign(p);
	vec2 uv;
	vec3 face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = p.yz;
		face = vec3(s.x, 0.0, 0.0);
	} else if (a.y >= a.z) {
		uv = p.xz;
		face = vec3(0.0, s.y, 0.0);
	} else {
		uv = p.xy;
		face = vec3(0.0, 0.0, s.z);
	}
	vec2 seed = vec2(dot(face, vec3(3.1, 5.7, 7.3)), COLOR.g * 41.0);

	vec2 cell;
	// Border distance in local units.
	float d = crack_border(uv * crack_scale + seed, cell) * half_size / crack_scale;
	// Cracks open one cell at a time and widen as they spread; some cells
	// stay whole so the cracks read as lines, not a net.
	float open = step(crack_hash(cell + 0.37).x, amount * 0.8);
	float width = crack_width * smoothstep(0.0, 0.6, amount);
	float aa = fwidth(d);
	float crack = open * (1.0 - smoothstep(width - aa, width + aa, d));

	// The stone dulls a little as it gives way.
	rock *= 1.0 - 0.08 * amount;
	ALBEDO = mix(rock, crack_color.rgb, crack);
	NORMAL = n;
}
