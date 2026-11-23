shader_type spatial;
// Swept cubes (#67, #85), first pass: invisible faces that only write depth,
// so the edge pass (block_swept_edges, this material's next pass) draws just
// the edges of the swept faces nearest the camera. With no fill, the floor
// and empty cells show through. Pixels a solid cube or the ghost has marked
// in the stencil buffer are skipped, so the slice and the ghost always show.
// Alpha keeps this in the see-through pass, after the solid cubes have
// marked the stencil.
render_mode unshaded, depth_draw_always, blend_mix;
stencil_mode read, compare_not_equal, 1;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
