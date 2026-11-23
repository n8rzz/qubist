shader_type spatial;
// Marks the stencil so swept cubes never draw over these (#67).
stencil_mode write, compare_always, 1;

// Cubes about to break in a line clear. Each instance's colour (red channel)
// says how far it has flashed, so cubes can flash one after another in a
// single MultiMesh draw.

#include "res://game/shaders/block_edges.gdshaderinc"

uniform vec4 flash_face_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec4 flash_edge_color : source_color = vec4(0.72, 0.53, 0.04, 1.0);

void fragment() {
	vec3 n;
	vec3 rock = stone(face_color.rgb, edge_color.rgb, n);
	vec3 lit = stone(flash_face_color.rgb, flash_edge_color.rgb, n);
	ALBEDO = mix(rock, lit, clamp(COLOR.r, 0.0, 1.0));
	NORMAL = n;
}
