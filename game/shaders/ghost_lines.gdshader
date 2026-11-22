shader_type spatial;
// Wireframe of the piece being placed. Each vertex's alpha says how strong
// its line is (outer outline vs. inner cube edges). Lines are nudged toward
// the camera so the ones on the piece's front faces win the depth test
// against the ghost's own fill, while the fill still hides lines behind it.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 line_color : source_color = vec4(0.12, 0.44, 0.25, 1.0);
// How far, in world units, lines are pulled toward the camera.
uniform float bias = 0.03;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz -= normalize(view_pos.xyz) * bias;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a * COLOR.a;
}
