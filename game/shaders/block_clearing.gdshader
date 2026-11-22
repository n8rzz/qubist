shader_type spatial;

// Cubes about to break in a line clear. Each instance's colour (red channel)
// says how far it has flashed, so cubes can flash one after another in a
// single MultiMesh draw.

#include "res://game/shaders/block_edges.gdshaderinc"

uniform vec4 flash_face_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec4 flash_edge_color : source_color = vec4(0.72, 0.53, 0.04, 1.0);

void fragment() {
	float e = edge_amount();
	vec3 stone = mix(face_color.rgb, edge_color.rgb, e);
	vec3 lit = mix(flash_face_color.rgb, flash_edge_color.rgb, e);
	ALBEDO = mix(stone, lit, clamp(COLOR.r, 0.0, 1.0));
}
