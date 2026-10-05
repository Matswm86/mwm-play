shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Border-forest imposter card (ASSETS_M1.md section 5): one atlas, cell index in INSTANCE_CUSTOM.r.
// grid = cells per side: 8 for border_trees_atlas.png, 4 for border_trees_atlas_m2.png.

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float grid = 8.0;

void vertex() {
	float cell = floor(INSTANCE_CUSTOM.r * 255.0 + 0.5);
	UV = (UV + vec2(mod(cell, grid), floor(cell / grid))) / grid;
	// World up (instances are never rotated, so model up = world up): lit like the ground.
	// NORMAL is still in model space here; Godot moves it to view space after vertex().
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 c = texture(atlas, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
