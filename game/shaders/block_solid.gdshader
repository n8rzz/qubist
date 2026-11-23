shader_type spatial;
// Marks the stencil so swept cubes never draw over solid ones (#67).
stencil_mode write, compare_always, 1;

// Placed stone cubes (#22): bevelled, with a few chipped corners.
#include "res://game/shaders/block_edges.gdshaderinc"

void fragment() {
	vec3 n;
	ALBEDO = stone(face_color.rgb, edge_color.rgb, n);
	NORMAL = n;
}
