shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// zone_marker.gdshader for ZoneMarkers (one MultiMesh per valley): instance colour (sRGB) in
// COLOR, size / progress / active in INSTANCE_CUSTOM. Same look as zone_marker.gdshader.

varying vec4 inst;
varying vec4 col;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	inst = INSTANCE_CUSTOM;
	col = vec4(to_linear(COLOR.rgb), COLOR.a);
}

void fragment() {
	vec2 size = inst.xy;
	float progress = inst.z;
	float active = inst.w;
	vec2 p = (UV - 0.5) * size;
	float d = sd_round_box(p, size * 0.5 - 0.04, 0.35);
	float border = smoothstep(0.02, 0.0, abs(d + 0.07) - 0.045);
	float ang = atan(p.y, p.x);
	float dash = step(0.0, sin(ang * 18.0 - TIME * 2.0));
	border *= mix(dash, 1.0, active);
	float inside = smoothstep(0.02, -0.02, d);
	float fill = inside * (0.16 + 0.12 * active);
	float prog_line = (1.0 - UV.y);
	float prog = inside * step(prog_line, progress) * 0.55;
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	ALBEDO = mix(col.rgb, vec3(1.0, 0.85, 0.3), step(0.001, prog));
	ALPHA = clamp(max(max(border * pulse, fill), prog), 0.0, 1.0) * col.a;
}
