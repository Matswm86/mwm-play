shader_type spatial;

// Rubber conveyor belt with chevrons that scroll in the travel direction (local -Z).

uniform float length = 4.0;
uniform float speed = 2.0;

void fragment() {
	vec3 base = vec3(0.16, 0.17, 0.18);
	// Top face UVs run along the belt; scroll them over time.
	float v = UV.y * length * 1.5 + TIME * speed * 1.5;
	float stripe = step(0.72, fract(v + abs(UV.x - 0.5) * 0.8));
	ALBEDO = mix(base, vec3(0.34, 0.35, 0.36), stripe);
	ROUGHNESS = 0.7;
}
