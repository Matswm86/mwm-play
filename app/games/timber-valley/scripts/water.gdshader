shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Stylised river: flowing ripples, bright foam at the banks, soft transparent edges.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.13, 0.46, 0.58);
uniform vec3 shallow : source_color = vec3(0.35, 0.72, 0.74);
uniform float flow = 0.6;
uniform float half_width = 4.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.z * 0.8 + TIME * 1.5) * 0.02;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME * flow;
	float n1 = texture(noise_tex, p * 0.09 + vec2(0.0, t * 0.35)).r;
	float n2 = texture(noise_tex, p * 0.16 + vec2(0.3, t * 0.6)).r;
	float ripple = n1 * 0.6 + n2 * 0.4;
	float edge = abs(UV.x - 0.5) * 2.0;
	vec3 col = mix(deep, shallow, smoothstep(0.35, 1.0, edge) * 0.8 + ripple * 0.25);
	float glint = smoothstep(0.66, 0.72, ripple);
	float foam = smoothstep(0.82, 0.95, edge + (n2 - 0.5) * 0.12);
	col = mix(col, vec3(0.95, 0.98, 1.0), max(glint * 0.55, foam * 0.85));
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	NORMAL_MAP = vec3(0.5 + (n1 - 0.5) * 0.35, 0.5 + (n2 - 0.5) * 0.35, 1.0);
	ALPHA = mix(0.92, 0.0, smoothstep(0.93, 1.0, edge));
}
