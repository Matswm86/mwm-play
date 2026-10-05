extends RefCounted
class_name TeFx3D

# One-shot 3D particle effects, built in code (CPUParticles3D — safe on the
# GL Compatibility renderer). Each helper spawns, plays and self-frees.


static func match_burst(parent: Node, at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.emitting = false
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 75.0
	p.gravity = Vector3(0, -7.0, 0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.5
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.color = color.lightened(0.2)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.emitting = true
	_auto_free(p, 1.4)


static func win_confetti(parent: Node, at: Vector3) -> void:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.45, 0.45))
	ramp.add_point(0.25, Color(1.0, 0.85, 0.3))
	ramp.add_point(0.5, Color(0.4, 0.85, 0.5))
	ramp.add_point(0.75, Color(0.4, 0.65, 1.0))
	ramp.set_color(1, Color(0.85, 0.5, 1.0))
	var p := CPUParticles3D.new()
	p.position = at
	p.emitting = false
	p.one_shot = true
	p.amount = 90
	p.lifetime = 1.6
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -5.0, 0)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.12
	p.color_initial_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 0.6)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.mesh = mesh
	mesh.material = mat
	p.particle_flag_rotate_y = true
	parent.add_child(p)
	p.emitting = true
	_auto_free(p, 3.0)


static func _auto_free(node: Node, after: float) -> void:
	var timer := node.get_tree().create_timer(after)
	timer.timeout.connect(node.queue_free)
