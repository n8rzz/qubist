shader_type spatial;
// Marks the stencil so swept cubes never draw over these (#67).
stencil_mode write, compare_always, 1;
render_mode depth_draw_always;

// Cleared cubes under Reduce Motion (#116): lit like a cube about to break,
// then fading out where they sit, by each instance colour's alpha.

#include "res://game/shaders/block_edges.gdshaderinc"

uniform vec4 flash_face_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec4 flash_edge_color : source_color = vec4(0.72, 0.53, 0.04, 1.0);

void fragment() {
	vec3 n;
	ALBEDO = stone(flash_face_color.rgb, flash_edge_color.rgb, n);
	NORMAL = n;
	ALPHA = COLOR.a;
}
