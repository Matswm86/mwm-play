shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Rounded-square ground marker: soft fill, dashed border, optional fill progress.

uniform vec4 color : source_color = vec4(1.0);
uniform vec2 size = vec2(2.0, 2.0);
uniform float progress = 0.0;
uniform float active = 0.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float d = sd_round_box(p, size * 0.5 - 0.04, 0.35);
	float border = smoothstep(0.02, 0.0, abs(d + 0.07) - 0.045);
	// Dashes march around the border.
	float ang = atan(p.y, p.x);
	float dash = step(0.0, sin(ang * 18.0 - TIME * 2.0));
	border *= mix(dash, 1.0, active);
	float inside = smoothstep(0.02, -0.02, d);
	float fill = inside * (0.16 + 0.12 * active);
	// Progress fills from the bottom edge upward.
	float prog_line = (1.0 - UV.y);
	float prog = inside * step(prog_line, progress) * 0.55;
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	ALBEDO = mix(color.rgb, vec3(1.0, 0.85, 0.3), step(0.001, prog));
	ALPHA = clamp(max(max(border * pulse, fill), prog), 0.0, 1.0) * color.a;
}
