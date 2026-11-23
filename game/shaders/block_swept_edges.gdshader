shader_type spatial;
// Swept cubes (#85), second pass: a faint line along each cube edge, drawn
// only where block_faded's depth pass left this face as the nearest swept
// face, so hidden lines stay hidden. The edge colour's alpha sets how faint
// the lines are.
render_mode unshaded, depth_draw_never, blend_mix;
stencil_mode read, compare_not_equal, 1;

#include "res://game/shaders/block_edges.gdshaderinc"

void fragment() {
	float e = edge_amount();
	if (e < 0.01) {
		discard;
	}
	ALBEDO = edge_color.rgb;
	ALPHA = edge_color.a * e;
}
