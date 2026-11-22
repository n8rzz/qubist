shader_type spatial;
render_mode blend_mix, depth_draw_never;

#include "res://game/shaders/block_edges.gdshaderinc"

void fragment() {
	vec4 c = mix(face_color, edge_color, edge_amount());
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
