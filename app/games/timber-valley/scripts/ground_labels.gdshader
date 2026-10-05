shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_back, depth_draw_never, shadows_disabled;

// GroundLabels: one quad per zone label, its atlas rect in INSTANCE_CUSTOM. The atlas comes from
// a transparent SubViewport, so its colours are premultiplied by alpha.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;

varying vec4 rect;

void vertex() {
	rect = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 c = texture(atlas, rect.xy + UV * rect.zw);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
