shader_type spatial;
// Swept cubes (#67): paper-white faces with a thin outline, like a paper
// model. They write depth, so a swept cube hides the edges of swept cubes
// behind it, but skip any pixel a solid cube or the ghost has marked in the
// stencil buffer, so the slice and the ghost always show through.
// Alpha is written only to keep these in the see-through pass, after the
// solid cubes have marked the stencil.
render_mode unshaded, depth_draw_always, blend_mix;
stencil_mode read, compare_not_equal, 1;

#include "res://game/shaders/block_edges.gdshaderinc"

void fragment() {
	ALBEDO = mix(face_color.rgb, edge_color.rgb, edge_amount() * edge_color.a);
	ALPHA = 1.0;
}
