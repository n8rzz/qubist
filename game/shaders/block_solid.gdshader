shader_type spatial;

#include "res://game/shaders/block_edges.gdshaderinc"

void fragment() {
	ALBEDO = mix(face_color.rgb, edge_color.rgb, edge_amount());
}
