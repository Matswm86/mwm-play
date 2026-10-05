class_name TvMegaSaw
extends Node3D

## Big late-game machine: a crane drops a giant log on a conveyor bed and a huge chainsaw
## slices it into planks. Logs arrive by themselves, so it only needs room in its output pile.

const LOG_R := 0.85
const LOG_LEN := 4.6
const SAW_X := 1.6

var output: TvItemStack
var out_zone: TvZone
var body: Node3D
var _busy: bool = true
var _log: MeshInstance3D
var _t: float = 0.0
var _batch: float = 0.0
var _dropping: bool = false
var _chips: CPUParticles3D
var _crane_hook: Node3D


func setup() -> TvMegaSaw:
	name = "MegaSaw"
	body = Node3D.new()
	add_child(body)
	# v3 body (ASSETS_LEFTOVER.md 2.8): bed, rails, gantry and sawdust mound in one model.
	body.add_child(TvModels.make("megasaw_body"))
	var belt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.06, 8.2)
	belt.mesh = bm
	var bmat := ShaderMaterial.new()
	bmat.shader = TvConveyor.BELT_SHADER
	bmat.set_shader_parameter("length", 8.2)
	bmat.set_shader_parameter("speed", -0.5)
	belt.material_override = bmat
	belt.position = Vector3(-0.6, 0.82, 0)
	belt.rotation_degrees.y = 90
	body.add_child(belt)
	# Upright giant chainsaw on the gantry arm (the gantry is part of the body model).
	var saw := TvChainSaw.new()
	saw.bar_len = 3.2
	saw.bar_h = 0.8
	saw.setup(null, Color(1.0, 0.45, 0.12))
	saw.rotation_degrees = Vector3(90, 90, 0)
	saw.position = Vector3(SAW_X, 2.35, 0)
	saw.always_on = true
	body.add_child(saw)
	# Tower crane that brings in the next log: jib (+X, tip x 4.4) over the log drop path.
	var crane := TvModels.make("megasaw_crane")
	crane.position = Vector3(-4.2, 0, -2.2)
	crane.rotation_degrees.y = -20
	body.add_child(crane)
	_crane_hook = Node3D.new()
	body.add_child(_crane_hook)
	# Hook origin = hook bottom; the cable runs up 3 m like the old box.
	_crane_hook.add_child(TvModels.make("crane_hook"))
	_crane_hook.visible = false
	_log = TvShapes.log_node(body, LOG_R, LOG_LEN, Vector3.ZERO, Vector3(0, 0, 90), TvShapes.log_material(LOG_R))
	_place_log(0.0)
	# Body, belt and crane bake into a few meshes; the log and hook move.
	TvMeshMerge.merge(body, [_log, _crane_hook])
	_chips = CPUParticles3D.new()
	_chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chips.amount = 70
	_chips.lifetime = 1.2
	_chips.direction = Vector3(0.7, 1, 0.5)
	_chips.spread = 45
	_chips.initial_velocity_min = 3
	_chips.initial_velocity_max = 7
	_chips.gravity = Vector3(0, -10, 0)
	_chips.scale_amount_min = 0.8
	_chips.scale_amount_max = 1.6
	var cm := BoxMesh.new()
	cm.size = Vector3(0.12, 0.05, 0.06)
	cm.material = TvShapes.mat(Color(0.98, 0.78, 0.45))
	_chips.mesh = cm
	_chips.position = Vector3(SAW_X + 0.2, 1.8, 0.4)
	add_child(_chips)
	output = TvItemStack.new().setup("plank", 60, 2, 3, "megasaw:out")
	output.position = Vector3(SAW_X + 3.3, 0, 0.3)
	add_child(output)
	out_zone = TvZone.new().setup(TvZone.Kind.PICK, output, Vector2(2.4, 2.8), "PLANKS", Color(1.0, 0.95, 0.7))
	out_zone.position = output.position
	add_child(out_zone)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(8.4, 2.5, 3.6)
	col.shape = bs
	col.position = Vector3(-0.6, 1.25, 0)
	sb.add_child(col)
	add_child(sb)
	return self


## t = 0 fresh log, 1 = fully cut. The log's right end stays at the saw while it shortens.
func _place_log(t: float) -> void:
	var length := LOG_LEN * (1.0 - t * 0.92)
	_log.scale = Vector3(1, length / LOG_LEN, 1)
	_log.position = Vector3(SAW_X - length * 0.5 + 0.2, 0.84 + LOG_R, 0)


func _process(delta: float) -> void:
	var room := output.count() + 2 <= output.capacity
	_chips.emitting = room and not _dropping
	if _dropping or not room:
		return
	var speed := TimberGame.machine_speed()
	_t += delta * speed / 14.0
	_batch += delta * speed
	if _batch >= 0.7:
		_batch = 0.0
		for i in 2:
			var it := TvItems.make("plank")
			add_child(it)
			it.position = Vector3(SAW_X + 0.6, 1.2 + i * 0.12, 0.3)
			output.push(it)
		TimberSfx.play("machine", -12.0, 0.8, 0.2)
	if _t >= 1.0:
		_t = 0.0
		_drop_new_log()
	else:
		_place_log(_t)


func _drop_new_log() -> void:
	_dropping = true
	_crane_hook.visible = true
	_place_log(0.0)
	var rest := _log.position
	_log.position = rest + Vector3(-1.5, 6.0, -2.5)
	_crane_hook.position = _log.position + Vector3(0, LOG_R, 0)
	var tw := create_tween()
	tw.tween_property(_log, "position", rest + Vector3(0, 0.4, 0), 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_crane_hook, "position", rest + Vector3(0, LOG_R + 0.4, 0), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_log, "position", rest, 0.2).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_callback(func() -> void:
		TimberSfx.play("tree_fall", -6.0, 0.8)
		_crane_hook.visible = false
		_dropping = false)
