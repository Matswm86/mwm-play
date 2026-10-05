shader_type spatial;
render_mode diffuse_burley;

// Painted wood: soft grain stripes along the local X/Z axis with gentle colour variation.

uniform vec4 base : source_color = vec4(0.85, 0.6, 0.36, 1.0);
uniform float grain_scale = 6.0;

varying vec3 obj_pos;
varying vec3 obj_nrm;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

void fragment() {
	// Grain runs along the longest horizontal direction; use both and blend by normal.
	float gx = obj_pos.z * grain_scale + noise1(obj_pos.x * 3.0) * 1.5 + obj_pos.y * 2.0;
	float gz = obj_pos.x * grain_scale + noise1(obj_pos.z * 3.0) * 1.5 + obj_pos.y * 2.0;
	float g = mix(gx, gz, step(abs(obj_nrm.z), abs(obj_nrm.x)));
	float stripes = smoothstep(0.35, 0.5, abs(fract(g) - 0.5)) * 0.12;
	float blotch = noise1(obj_pos.x * 1.7 + obj_pos.z * 2.3 + 11.0) * 0.1;
	vec3 col = base.rgb * (1.0 - stripes + blotch - 0.05);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	RIM = 0.2;
	RIM_TINT = 0.5;
}
