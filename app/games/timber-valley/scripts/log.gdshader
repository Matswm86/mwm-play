shader_type spatial;
render_mode diffuse_burley;

// Log on a CylinderMesh (axis = local Y): bark with vertical ridges on the side,
// pale end grain with growth rings on the caps.

uniform vec4 bark : source_color = vec4(0.55, 0.34, 0.2, 1.0);
uniform vec4 core : source_color = vec4(0.98, 0.8, 0.52, 1.0);
uniform float radius = 0.15;

varying vec3 obj_pos;
varying vec3 obj_nrm;

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

void fragment() {
	float cap = step(0.7, abs(obj_nrm.y));
	float ang = atan(obj_pos.z, obj_pos.x);
	float ridge = 0.5 + 0.5 * sin(ang * 16.0 + sin(obj_pos.y * 5.0) * 1.5);
	vec3 side = bark.rgb * (0.82 + 0.25 * ridge);
	float rad = length(obj_pos.xz) / radius;
	float rings = 0.5 + 0.5 * cos(rad * 6.2831 * 4.5);
	vec3 end = core.rgb * (0.88 + 0.12 * rings);
	end = mix(end, core.rgb * 0.72, smoothstep(0.25, 0.0, rad) * 0.3);
	end = mix(end, bark.rgb * 0.85, smoothstep(0.8, 0.88, rad));
	ALBEDO = mix(side, end, cap);
	ROUGHNESS = mix(0.9, 0.65, cap);
	RIM = 0.25;
	RIM_TINT = 0.5;
}
