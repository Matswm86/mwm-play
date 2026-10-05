shader_type spatial;

// Wooden shingle roof: staggered rows with slight per-shingle colour variation.

uniform vec4 base : source_color = vec4(0.8, 0.3, 0.2, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 lp = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = vec2(lp.x * 2.2, lp.z * 3.2);
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float edge = smoothstep(0.0, 0.08, f.y) * smoothstep(0.0, 0.04, f.x) * smoothstep(1.0, 0.96, f.x);
	float v = hash(cell) * 0.14 - 0.07;
	vec3 col = base.rgb * (1.0 + v) * mix(0.7, 1.0, edge);
	col *= mix(0.85, 1.0, f.y);
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
