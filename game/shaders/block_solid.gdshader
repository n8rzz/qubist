shader_type spatial;
// Marks the stencil so swept cubes never draw over solid ones (#67).
stencil_mode write, compare_always, 1;

// Placed stone cubes (#22): bevelled, with a few chipped corners.
#include "res://game/shaders/block_edges.gdshaderinc"

// Snow lying on every cube's top in winter (#168): 0 none, 1 full.
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 snow_color : source_color = vec4(0.953, 0.969, 0.984, 1.0);

void fragment() {
	vec3 n;
	ALBEDO = stone(face_color.rgb, edge_color.rgb, n);
	NORMAL = n;
	vec3 a = abs(local_pos);
	if (snow > 0.0 && local_pos.y > 0.0 && a.y >= a.x && a.y >= a.z) {
		// Leave the edge line showing so cubes still read as separate.
		ALBEDO = mix(ALBEDO, snow_color.rgb, snow * (1.0 - 0.7 * edge_amount()));
	}
}
