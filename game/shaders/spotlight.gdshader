shader_type canvas_item;
// The tutorial's dim (#29): a dark wash over the screen with up to four
// rounded holes cut out, so the controls the step needs stay lit.

uniform vec4 dim_color : source_color = vec4(0.063, 0.125, 0.172, 0.55);
// Each hole is (x, y, width, height) in the node's own points.
uniform vec4 holes[4];
uniform float radii[4];
uniform int hole_count = 0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float rounded_box(vec2 p, vec4 box, float radius) {
	vec2 half_size = box.zw * 0.5;
	vec2 q = abs(p - (box.xy + half_size)) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	float alpha = 1.0;
	for (int i = 0; i < hole_count; i++) {
		float d = rounded_box(local, holes[i], radii[i]);
		alpha = min(alpha, clamp(d + 0.5, 0.0, 1.0));
	}
	COLOR = vec4(dim_color.rgb, dim_color.a * alpha);
}
