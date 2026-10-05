class_name TvKiln
extends Node3D

## Batch drying kiln (GDD 7.6 D): the DROP square takes up to KILN.batch frost logs. Baking starts
## when the kiln is full, or idle_start_s after the last log arrived if it holds at least one.
## The bake takes bake_s / machine speed; the door is shut and the chimney glows brighter over the
## bake. Then the door opens with a ding and the batch pops out as dry lumber, 0.05 s apart.
## The kiln loads nothing while it bakes. Piles persist as "<id>:in" / "<id>:out".

const POP_GAP_S := 0.05
## Door hinge angle when open (closed = 0 while baking).
const DOOR_OPEN := -1.75

var region: int = 5
var input: TvItemStack
var output: TvItemStack
var in_zone: TvZone
var out_zone: TvZone
var body: Node3D
var baking: bool = false
var _t: float = 0.0
var _idle: float = 0.0
var _last_count: int = 0
var _batch: int = 0
var _glow: StandardMaterial3D
var _door: Node3D
var _pending: int = 0
var _pop_t: float = 0.0


func setup(id: String, region_id: int = 5) -> TvKiln:
	name = id
	region = region_id
	var k: Dictionary = TvBalance.KILN
	input = TvItemStack.new().setup("frost_log", int(k.batch), 2, 3, id + ":in")
	input.position = Vector3(-2.7, 0, 0.3)
	add_child(input)
	output = TvItemStack.new().setup("dry_lumber", 48, 2, 3, id + ":out")
	output.position = Vector3(2.7, 0, 0.3)
	add_child(output)
	in_zone = TvZone.new().setup(TvZone.Kind.DROP, input, Vector2(2.2, 2.6), TvItems.label("frost_log"), Color(1, 1, 1))
	in_zone.position = input.position
	add_child(in_zone)
	out_zone = TvZone.new().setup(TvZone.Kind.PICK, output, Vector2(2.2, 2.6), TvItems.label("dry_lumber"), Color(1.0, 0.95, 0.7))
	out_zone.position = output.position
	add_child(out_zone)
	body = Node3D.new()
	add_child(body)
	# ASSETS_M4.md 1.2: kiln house, a door on a hinge and the emissive chimney mouth + vents.
	body.add_child(TvModels.make("kiln"))
	var glow := TvModels.make("kiln_glow")
	add_child(glow)
	for m in glow.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Own material per kiln, so each glows on its own bake.
		var src := mi.get_active_material(0) as StandardMaterial3D
		_glow = (src.duplicate() as StandardMaterial3D) if src else StandardMaterial3D.new()
		_glow.emission_enabled = true
		_glow.emission_energy_multiplier = 0.0
		mi.material_override = _glow
	_door = TvModels.make("kiln_door")
	_door.position = Vector3(-0.72, 0.2, 1.26)
	_door.rotation.y = DOOR_OPEN
	add_child(_door)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.3, 2.5, 2.7)
	col.shape = box
	col.position = Vector3(0, 1.25, 0)
	sb.add_child(col)
	add_child(sb)
	TvMeshMerge.merge(body)
	return self


func _process(delta: float) -> void:
	var k: Dictionary = TvBalance.KILN
	if _pending > 0:
		_pop_t -= delta
		while _pending > 0 and _pop_t <= 0.0:
			_pop_t += POP_GAP_S
			_pending -= 1
			var it := TvItems.make("dry_lumber")
			add_child(it)
			it.position = Vector3(0.6, 0.6, 1.4)
			output.push(it)
		return
	if not baking:
		input.capacity = int(k.batch)
		var n := input.count()
		if n != _last_count:
			_last_count = n
			_idle = 0.0
		else:
			_idle += delta
		var room := output.capacity - output.count()
		if n > 0 and n <= room and (n >= int(k.batch) or _idle >= float(k.idle_start_s)):
			_start(n)
		return
	_t += delta * TimberGame.machine_speed(region)
	var bake := float(k.bake_s)
	_glow.emission_energy_multiplier = clampf(_t / bake, 0.0, 1.0) * TvBalance.KILN_GLOW_MAX
	if _t >= bake:
		_finish()


func _start(n: int) -> void:
	baking = true
	_t = 0.0
	_batch = n
	input.capacity = 0
	for i in n:
		var it := input.pop()
		if it == null:
			break
		var gxf := it.global_transform
		it.get_parent().remove_child(it)
		add_child(it)
		it.global_transform = gxf
		var tw := it.create_tween()
		tw.tween_property(it, "position", Vector3(-1.0, 0.9, 1.2), 0.25 + 0.02 * i).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(it, "scale", Vector3.ONE * 0.3, 0.25 + 0.02 * i)
		tw.tween_callback(it.queue_free)
	var dt := _door.create_tween()
	dt.tween_property(_door, "rotation:y", 0.0, 0.4).set_trans(Tween.TRANS_BACK)
	TimberSfx.play("machine", -6.0, 0.6)


func _finish() -> void:
	baking = false
	_glow.emission_energy_multiplier = 0.0
	_pending = _batch
	_pop_t = 0.2
	_batch = 0
	_last_count = 0
	_idle = 0.0
	var dt := _door.create_tween()
	dt.tween_property(_door, "rotation:y", DOOR_OPEN, 0.4).set_trans(Tween.TRANS_BACK)
	TimberSfx.play("bell", -4.0, 1.4)
