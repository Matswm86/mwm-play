shader_type spatial;
render_mode diffuse_burley;

// One shader for every MeshMerge'd procedural surface, so a building or belt is one draw.
// Per vertex: COLOR = base colour (sRGB), CUSTOM1.w = mode, and per mode:
//   0 flat (plain StandardMaterial3D): CUSTOM2 = roughness, metallic, rim, rim tint
//   1 wood (wood.gdshader):  CUSTOM0 = local position + grain scale, CUSTOM1.xyz = local normal
//   2 log (log.gdshader):    CUSTOM0 = local position + radius, CUSTOM1.xyz = local normal, CUSTOM2 = core colour
//   3 roof (roof.gdshader):  CUSTOM0 = local position
//   4 belt (belt.gdshader):  UV.y already scaled by the belt length, CUSTOM0.w = scroll speed
// Each mode reproduces its source shader exactly; the local position replaces model space.

varying vec3 obj_pos;
varying vec3 obj_nrm;
varying vec3 base_lin;
varying vec4 extra;
varying flat float mode;
varying float param;

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	obj_pos = CUSTOM0.xyz;
	param = CUSTOM0.w;
	obj_nrm = CUSTOM1.xyz;
	mode = CUSTOM1.w;
	base_lin = to_linear(COLOR.rgb);
	extra = CUSTOM2;
	if (mode > 1.5 && mode < 2.5) {
		extra.rgb = to_linear(CUSTOM2.rgb);
	}
}

void fragment() {
	if (mode < 0.5) {
		ALBEDO = base_lin;
		ROUGHNESS = extra.x;
		METALLIC = extra.y;
		RIM = extra.z;
		RIM_TINT = extra.w;
	} else if (mode < 1.5) {
		float gx = obj_pos.z * param + noise1(obj_pos.x * 3.0) * 1.5 + obj_pos.y * 2.0;
		float gz = obj_pos.x * param + noise1(obj_pos.z * 3.0) * 1.5 + obj_pos.y * 2.0;
		float g = mix(gx, gz, step(abs(obj_nrm.z), abs(obj_nrm.x)));
		float stripes = smoothstep(0.35, 0.5, abs(fract(g) - 0.5)) * 0.12;
		float blotch = noise1(obj_pos.x * 1.7 + obj_pos.z * 2.3 + 11.0) * 0.1;
		ALBEDO = base_lin * (1.0 - stripes + blotch - 0.05);
		ROUGHNESS = 0.7;
		RIM = 0.2;
		RIM_TINT = 0.5;
	} else if (mode < 2.5) {
		float cap = step(0.7, abs(obj_nrm.y));
		float ang = atan(obj_pos.z, obj_pos.x);
		float ridge = 0.5 + 0.5 * sin(ang * 16.0 + sin(obj_pos.y * 5.0) * 1.5);
		vec3 side = base_lin * (0.82 + 0.25 * ridge);
		float rad = length(obj_pos.xz) / param;
		float rings = 0.5 + 0.5 * cos(rad * 6.2831 * 4.5);
		vec3 core = extra.rgb;
		vec3 end = core * (0.88 + 0.12 * rings);
		end = mix(end, core * 0.72, smoothstep(0.25, 0.0, rad) * 0.3);
		end = mix(end, base_lin * 0.85, smoothstep(0.8, 0.88, rad));
		ALBEDO = mix(side, end, cap);
		ROUGHNESS = mix(0.9, 0.65, cap);
		RIM = 0.25;
		RIM_TINT = 0.5;
	} else if (mode < 3.5) {
		vec2 uv = vec2(obj_pos.x * 2.2, obj_pos.z * 3.2);
		float row = floor(uv.y);
		uv.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		float edge = smoothstep(0.0, 0.08, f.y) * smoothstep(0.0, 0.04, f.x) * smoothstep(1.0, 0.96, f.x);
		float v = hash2(cell) * 0.14 - 0.07;
		vec3 col = base_lin * (1.0 + v) * mix(0.7, 1.0, edge);
		col *= mix(0.85, 1.0, f.y);
		ALBEDO = col;
		ROUGHNESS = 0.85;
	} else {
		vec3 base = vec3(0.16, 0.17, 0.18);
		float v = UV.y * 1.5 + TIME * param * 1.5;
		float stripe = step(0.72, fract(v + abs(UV.x - 0.5) * 0.8));
		ALBEDO = mix(base, vec3(0.34, 0.35, 0.36), stripe);
		ROUGHNESS = 0.7;
	}
}
