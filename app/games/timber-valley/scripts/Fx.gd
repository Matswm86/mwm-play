class_name TvFx
extends RefCounted

## Small visual helpers: floating text, pop-in, items flying to a target, confetti.

static var _font: Font


static func font(weight: int = 600) -> Font:
	if _font == null:
		var fv := FontVariation.new()
		fv.base_font = load("res://games/timber-valley/assets/fonts/Fredoka.ttf")
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_font = fv
	return _font


static func float_text(parent: Node, pos: Vector3, text: String, color: Color, size: float = 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font()
	l.font_size = int(64 * size)
	l.outline_size = 16
	l.modulate = color
	l.outline_modulate = Color(0.2, 0.12, 0.02, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", pos + Vector3(0, 1.3, 0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)


static func pop_in(n: Node3D, dur: float = 0.55) -> void:
	var s := n.scale
	n.scale = s * 0.05
	var tw := n.create_tween()
	tw.tween_property(n, "scale", s, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func fly_to_and_free(it: Node3D, target: Node3D, delay: float = 0.0) -> void:
	if it.has_meta("tw"):
		var old: Tween = it.get_meta("tw")
		if old and old.is_valid():
			old.kill()
	var start := it.global_position
	var tw := it.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(target):
				return
			var end := target.global_position + Vector3(0, 1.2, 0)
			var mid := (start + end) * 0.5 + Vector3(0, 1.5, 0)
			it.global_position = start.lerp(mid, t).lerp(mid.lerp(end, t), t),
		0.0, 1.0, 0.3
	)
	tw.tween_callback(it.queue_free)


static func confetti(parent: Node, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	# Small bits: no shadow pass draw.
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = 60
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 35
	p.initial_velocity_min = 6
	p.initial_velocity_max = 10
	p.gravity = Vector3(0, -9, 0)
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var m := QuadMesh.new()
	m.size = Vector2(0.14, 0.09)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([
		Color(1, 0.8, 0.2), Color(0.3, 0.8, 0.45), Color(0.95, 0.4, 0.3), Color(0.3, 0.7, 0.95), Color(1, 1, 1)
	])
	p.color_initial_ramp = g
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(2.5).timeout.connect(p.queue_free)
