class_name TvMachine
extends Node3D

## Turns input items into output items: logs -> planks, planks -> chairs, and so on.

var in_type: String
var out_type: String
var in_per_cycle: int = 1
var out_per_cycle: int = 2
var cycle_time: float = 1.0
## Valley this machine belongs to (its Sharp Saws level speeds it up).
var region: int = 1
var input: TvItemStack
var output: TvItemStack
var in_zone: TvZone
var out_zone: TvZone
## Assembler (GDD 7.4): optional second input with its own pile and DROP square. A cycle starts
## when both piles hold enough.
var in_type_b: String = ""
var in_per_cycle_b: int = 0
var input_b: TvItemStack
var in_zone_b: TvZone
var mouth_in_b := Vector3(-0.9, 1.0, 0)
var spinners: Array[Node3D] = []
var arms: Array[Node3D] = []
## Press plates: travel down and back up once per cycle while busy (local y).
var plates: Array[Node3D] = []
var plate_up: float = 1.35
var plate_down: float = 0.93
var dust: CPUParticles3D
var smoke: CPUParticles3D
var body: Node3D
var mouth_in := Vector3(-0.9, 1.0, 0)
var mouth_out := Vector3(0.9, 0.8, 0)
## When set, input items slide along the belt to this point while being processed.
var cut_point: Vector3 = Vector3.INF
var _busy: bool = false
var _spin: float = 0.0
var _t: float = 0.0
var _anim_t: float = 0.0


func setup(id: String, i_type: String, o_type: String, i_n: int, o_n: int, t: float, region_id: int = 1, out_cap: int = 48) -> TvMachine:
	name = id
	region = region_id
	in_type = i_type
	out_type = o_type
	in_per_cycle = i_n
	out_per_cycle = o_n
	cycle_time = t
	input = TvItemStack.new().setup(in_type, 36, 2, 3, id + ":in")
	input.position = Vector3(-2.7, 0, 0.2)
	add_child(input)
	output = TvItemStack.new().setup(out_type, out_cap, 2, 3, id + ":out")
	output.position = Vector3(2.7, 0, 0.2)
	add_child(output)
	var in_label := TvItems.label(in_type)
	var out_label := TvItems.label(out_type)
	in_zone = TvZone.new().setup(TvZone.Kind.DROP, input, Vector2(2.2, 2.6), in_label, Color(1, 1, 1))
	in_zone.position = input.position
	add_child(in_zone)
	out_zone = TvZone.new().setup(TvZone.Kind.PICK, output, Vector2(2.2, 2.6), out_label, Color(1.0, 0.95, 0.7))
	out_zone.position = output.position
	add_child(out_zone)
	body = Node3D.new()
	add_child(body)
	return self


## Makes this an Assembler: a second input pile (persisted as "<id>:in2") at `pos`.
func add_second_input(i_type: String, i_n: int, pos: Vector3) -> void:
	in_type_b = i_type
	in_per_cycle_b = i_n
	input_b = TvItemStack.new().setup(i_type, 36, 2, 3, name + ":in2")
	input_b.position = pos
	add_child(input_b)
	in_zone_b = TvZone.new().setup(TvZone.Kind.DROP, input_b, Vector2(2.2, 2.4), TvItems.label(i_type), Color(1, 1, 1))
	in_zone_b.position = pos
	add_child(in_zone_b)


func add_blocker(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = offset + Vector3(0, size.y * 0.5, 0)
	sb.add_child(col)
	add_child(sb)


func add_model(path: String, pos: Vector3, scl: float, rot_y_deg: float = 0.0) -> Node3D:
	var inst: Node3D = load(path).instantiate()
	inst.position = pos
	inst.scale = Vector3.ONE * scl
	inst.rotation_degrees.y = rot_y_deg
	body.add_child(inst)
	return inst


func add_saw_blade(pos: Vector3, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	# v3 blade (ASSETS_LEFTOVER.md 2.4): r 0.3, disc normal = local Z, so the spin about FORWARD works.
	var blade: Node3D = load(TvModels.path("saw_blade")).instantiate()
	blade.scale = Vector3.ONE * (radius / 0.3)
	pivot.add_child(blade)
	body.add_child(pivot)
	spinners.append(pivot)
	return pivot


func add_dust(pos: Vector3, c: Color) -> void:
	dust = CPUParticles3D.new()
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.amount = 24
	dust.lifetime = 0.9
	dust.emitting = false
	dust.direction = Vector3(0, 1, 0.4)
	dust.spread = 45
	dust.initial_velocity_min = 1.2
	dust.initial_velocity_max = 2.6
	dust.gravity = Vector3(0, -4, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.3
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	m.material = mat
	dust.mesh = m
	dust.position = pos
	add_child(dust)


func add_smoke(pos: Vector3) -> void:
	smoke = CPUParticles3D.new()
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.amount = 14
	smoke.lifetime = 3.0
	smoke.emitting = false
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 12
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.3
	smoke.gravity = Vector3(0.3, 0.2, 0)
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 1.6))
	smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.55))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	smoke.color_ramp = grad
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	sm.radial_segments = 10
	sm.rings = 5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.9)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	smoke.mesh = sm
	smoke.position = pos
	add_child(smoke)


func _process(delta: float) -> void:
	var speed := TimberGame.machine_speed(region)
	var b_ok := input_b == null or input_b.count() >= in_per_cycle_b
	if not _busy and b_ok and input.count() >= in_per_cycle and output.count() + out_per_cycle <= output.capacity:
		_start_cycle()
	if _busy:
		_t += delta * speed
		if _t >= cycle_time:
			_finish_cycle()
	var target_spin := 14.0 * speed if _busy else 0.0
	_spin = lerpf(_spin, target_spin, 1.0 - exp(-4.0 * delta))
	for s in spinners:
		s.rotate_object_local(Vector3.FORWARD, _spin * delta)
	if _busy:
		_anim_t += delta * speed
	for i in arms.size():
		var a := arms[i]
		a.rotation.y = sin(_anim_t * 3.0 + i * 1.7) * 0.9
	for pl in plates:
		var k := (0.5 - 0.5 * cos(_t / cycle_time * TAU)) if _busy else 0.0
		pl.position.y = lerpf(plate_up, plate_down, k)
	var working := _busy or _spin > 1.0
	if dust:
		dust.emitting = _busy
	if smoke:
		smoke.emitting = working
	body.scale = Vector3.ONE * (1.0 + (sin(_anim_t * 22.0) * 0.012 if _busy else 0.0))


func _start_cycle() -> void:
	_busy = true
	_t = 0.0
	for i in in_per_cycle:
		var it := input.pop()
		if it == null:
			break
		_fly_and_free(it, to_global(mouth_in), i)
	if input_b:
		for i in in_per_cycle_b:
			var it := input_b.pop()
			if it == null:
				break
			_fly_and_free(it, to_global(mouth_in_b), i)
		TimberSfx.play("wood", -10.0, 0.8)


func _finish_cycle() -> void:
	_busy = false
	TimberSfx.play("machine", -14.0, randf_range(0.9, 1.1), 0.1)
	for i in out_per_cycle:
		var it := TvItems.make(out_type)
		add_child(it)
		it.position = (cut_point if cut_point != Vector3.INF else mouth_out) + Vector3(0.3, 0.1 * i, 0)
		output.push(it)


func _fly_and_free(it: Node3D, target: Vector3, idx: int = 0) -> void:
	if it.has_meta("tw"):
		var old: Tween = it.get_meta("tw")
		if old and old.is_valid():
			old.kill()
	var gxf := it.global_transform
	it.get_parent().remove_child(it)
	add_child(it)
	it.global_transform = gxf
	var tw := it.create_tween()
	tw.tween_property(it, "global_position", target, 0.25).set_trans(Tween.TRANS_SINE)
	if cut_point != Vector3.INF:
		# Line up with the belt, then ride into the saw.
		tw.parallel().tween_property(it, "global_rotation", Vector3(0, 0, 0), 0.25)
		var slide := cycle_time / TimberGame.machine_speed(region) * 0.85
		tw.tween_interval(idx * 0.1)
		tw.tween_property(it, "global_position", to_global(cut_point), slide)
		tw.tween_property(it, "scale", Vector3(0.2, 1.0, 1.0), 0.12)
	else:
		tw.parallel().tween_property(it, "scale", Vector3.ONE * 0.4, 0.25)
	tw.tween_callback(it.queue_free)
