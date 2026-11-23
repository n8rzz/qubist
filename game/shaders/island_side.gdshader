shader_type spatial;
// The floating island's sides (#23): grass strip, brick rim and earth
// underside. Flat colours like the Home art, picked by which way the face
// points on screen, so the left side is always the darker one whichever way
// the tower is turned.
render_mode unshaded;

uniform vec4 left_color : source_color;
uniform vec4 right_color : source_color;
// 0 plain, 1 brick courses, 2 earth strata.
uniform int pattern = 0;
uniform vec4 line_color : source_color = vec4(1.0);
uniform float line_width = 0.035;
// Brick: the top of the rim, the height of one course and a brick's length.
uniform float top_y = 0.0;
uniform float course = 0.425;
uniform float brick_length = 1.0;
// Strata: the heights of the two lines.
uniform float strata_a = -1.7;
uniform float strata_b = -2.9;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1.0 on a line `d` world units away, anti-aliased.
float line(float d) {
	float aa = fwidth(d);
	return 1.0 - smoothstep(line_width * 0.5 - aa, line_width * 0.5 + aa, d);
}

void fragment() {
	vec3 color = NORMAL.x < 0.0 ? left_color.rgb : right_color.rgb;
	float amount = 0.0;
	if (pattern == 1) {
		float depth = top_y - world_pos.y;
		float row = floor(depth / course);
		float along = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
		// Joints on cell boundaries, the next course down offset by half.
		float u = along / brick_length + 0.5 * mod(row, 2.0);
		float dv = abs(fract(depth / course + 0.5) - 0.5) * course;
		float du = abs(fract(u + 0.5) - 0.5) * brick_length;
		amount = max(line(dv), line(du));
	} else if (pattern == 2) {
		amount = max(line(abs(world_pos.y - strata_a)), line(abs(world_pos.y - strata_b)));
	}
	ALBEDO = mix(color, line_color.rgb, amount * line_color.a);
}
