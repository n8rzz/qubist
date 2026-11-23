shader_type spatial;
// The ghost's outer faces (#22): the placed cube's shape in translucent
// green, each cube face with a faint lighter panel inside its border, as the
// stone has. UV runs 0 to 1 across each cube face.
//
// Drawn with a depth prepass so only the face nearest the camera shows and
// the ghost's own back lines are hidden. Marks the stencil so swept cubes
// (#67) leave the ghost uncovered.
render_mode unshaded, cull_disabled, depth_prepass_alpha, blend_mix;
stencil_mode write, compare_always, 1;

uniform vec4 fill_color : source_color = vec4(0.25, 0.79, 0.53, 0.35);
uniform vec4 panel_color : source_color = vec4(1.0, 1.0, 1.0, 0.14);
// The panel's inset from the face's edges, as a share of the face.
uniform float panel_inset = 0.11;

void fragment() {
	vec2 to_edge = min(UV, vec2(1.0) - UV);
	float d = min(to_edge.x, to_edge.y);
	float aa = fwidth(d);
	float panel = smoothstep(panel_inset - aa, panel_inset + aa, d);
	vec4 c = mix(fill_color, vec4(mix(fill_color.rgb, panel_color.rgb, panel_color.a), fill_color.a), panel);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
