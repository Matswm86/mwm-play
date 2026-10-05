class_name TvPlayer
extends CharacterBody3D

## The lumberjack you control. Joystick or WASD to walk; everything else happens by standing on things.

var is_player := true
var stack: TvItemStack
var model: TvCharacterModel
var input_vector: Vector2 = Vector2.ZERO
var chopping_until: float = 0.0
var _step_timer: float = 0.0
var _sway: Vector2 = Vector2.ZERO
var _max_label: Label3D
var _zones_cache: Array = []
var _zone_refresh: float = 0.0
## Seconds of joystick input without moving (the unstuck safety net fires at UNSTUCK_S).
var _stuck_t: float = 0.0
const UNSTUCK_S := 2.0


func _ready() -> void:
	is_player = true
	TimberGame.player = self
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.5
	col.shape = cap
	col.position.y = 0.75
	add_child(col)
	model = TvCharacterModel.new().setup("character-male-e")
	add_child(model)
	model.set_axe_model(TimberGame.level("axe") >= 3)
	TimberGame.upgraded.connect(_on_upgraded)
	stack = TvItemStack.new().setup("", 999, 1, 1)
	stack.fly_time = 0.22
	stack.position = Vector3(0, 0.62, 0.42)
	model.add_child(stack)
	_max_label = Label3D.new()
	_max_label.text = "MAX"
	_max_label.font = TvFx.font()
	_max_label.font_size = 64
	_max_label.outline_size = 16
	_max_label.modulate = Color(1.0, 0.35, 0.25)
	_max_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_max_label.pixel_size = 0.006
	_max_label.no_depth_test = true
	_max_label.visible = false
	add_child(_max_label)
	floor_snap_length = 0.3


## Throws away everything carried: the items tumble off and vanish, nothing is paid.
func dump() -> void:
	if stack.is_empty():
		return
	var i := 0
	var scene := get_tree().current_scene
	while not stack.is_empty():
		var it := stack.pop()
		var gxf := it.global_transform
		it.get_parent().remove_child(it)
		scene.add_child(it)
		it.global_transform = gxf
		var away := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.8, 1.8)
		var tw := it.create_tween()
		tw.tween_interval(0.02 * i)
		tw.tween_property(it, "global_position", global_position + away + Vector3(0, 0.15, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(it, "rotation", Vector3(randf_range(-2, 2), randf_range(-3, 3), randf_range(-2, 2)), 0.35)
		tw.tween_property(it, "scale", Vector3.ONE * 0.01, 0.25)
		tw.tween_callback(it.queue_free)
		i += 1
	TimberSfx.play("tree_fall", -12.0, 1.5)


func capacity() -> int:
	# Thin goods (veneer) carry by height: x Balance.CARRY_MULT, 1 for every other item.
	return TimberGame.player_capacity() * int(TvBalance.CARRY_MULT.get(stack.top_type(), 1))


func _on_upgraded(id: String, lvl: int) -> void:
	if id == "axe" and lvl == 3:
		model.set_axe_model(true)


func _physics_process(delta: float) -> void:
	var dir := input_vector
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	for k in [[KEY_A, Vector2.LEFT], [KEY_D, Vector2.RIGHT], [KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN]]:
		if Input.is_physical_key_pressed(k[0]):
			kb += k[1]
	if kb.length() > 0.1:
		dir = kb.limit_length(1.0)
	var speed := TimberGame.player_speed()
	var target := Vector3(dir.x, 0, dir.y) * speed
	var accel := 30.0 if dir.length() > 0.05 else 40.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	var before := global_position
	move_and_slide()
	global_position.y = maxf(global_position.y, 0.0)
	# Unstuck: pushing for 2 s without getting anywhere while wedged inside or boxed in by
	# collision moves the player to the nearest free spot.
	if dir.length() > 0.3 and Vector2(global_position.x - before.x, global_position.z - before.z).length() < speed * delta * 0.15:
		_stuck_t += delta
		if _stuck_t >= UNSTUCK_S:
			_stuck_t = 0.0
			if TimberGame.world and TimberGame.world.has_method("unstick"):
				TimberGame.world.unstick(self)
	else:
		_stuck_t = 0.0

	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		var want := atan2(flat.x, flat.y)
		model.rotation.y = lerp_angle(model.rotation.y, want, 1.0 - exp(-14.0 * delta))
	var move01 := flat.length() / maxf(speed, 0.01)
	var now := Time.get_ticks_msec() / 1000.0
	model.update_state(move01, not stack.is_empty(), now < chopping_until)

	# The carried tower leans back when walking and wobbles when stopping.
	var local_v := flat.rotated(model.rotation.y) / maxf(speed, 0.01)
	_sway = _sway.lerp(Vector2(local_v.y, -local_v.x) * 0.10, 1.0 - exp(-6.0 * delta))
	stack.rotation = Vector3(-_sway.x, 0, _sway.y * 0.5)

	if move01 > 0.2:
		_step_timer -= delta * move01
		if _step_timer <= 0.0:
			_step_timer = 0.34
			TimberSfx.play("step", -22.0)

	var full := stack.count() >= capacity()
	_max_label.visible = full
	if full:
		_max_label.position = Vector3(0, 1.9 + stack.height() * 0.3, 0)
	_check_zones(delta)


func _check_zones(delta: float) -> void:
	_zone_refresh -= delta
	if _zone_refresh <= 0.0:
		_zone_refresh = 0.5
		_zones_cache = get_tree().get_nodes_in_group("zones")
	var p := global_position
	for z in _zones_cache:
		if not is_instance_valid(z) or not z.is_visible_in_tree():
			continue
		if z.contains(p):
			z.tick(self, delta)
		else:
			z.left(self)
