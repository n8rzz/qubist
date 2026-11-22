shader_type spatial;
// Marks the stencil so swept cubes never draw over solid ones (#67).
stencil_mode write, compare_always, 1;

#include "res://game/shaders/block_edges.gdshaderinc"

void fragment() {
	ALBEDO = mix(face_color.rgb, edge_color.rgb, edge_amount());
}
