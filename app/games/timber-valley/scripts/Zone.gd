class_name TvZone
extends Node3D

## A marked square on the ground. Carriers standing on it drop, pick up, or trigger something.

enum Kind { DROP, PICK, CUSTOM }

const MARKER_SHADER := preload("res://games/timber-valley/scripts/zone_marker.gdshader")

var kind: Kind = Kind.CUSTOM
var stack: TvItemStack
var half: Vector2 = Vector2(1.1, 1.1)
var interval: float = 0.06
var player_only: bool = false
var on_carrier: Callable
var on_enter: Callable
var on_exit: Callable
var marker: MeshInstance3D
var label: Label3D
var _timers: Dictionary = {}
## Seconds the player has stood still inside (PICK squares only load a passing player that
## already carries that item; otherwise only after PICK_STILL_S standing still).
var _still: Dictionary = {}
const PICK_STILL_S := 0.4
var _inside: Dictionary = {}
var _mat: ShaderMaterial
## Marker look, also read by the valley's ZoneMarkers MultiMesh.
var marker_color: Color = Color.WHITE
var progress: float = 0.0
var active: float = 0.0
var _plane: Mesh
var _batch: TvZoneMarkers
var _label_batch: TvGroundLabels


func setup(k: Kind, s: TvItemStack, size: Vector2, text: String, color: Color = Color.WHITE) -> TvZone:
	kind = k
	stack = s
	half = size * 0.5
	marker_color = color
	marker = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	marker.mesh = pm
	_mat = ShaderMaterial.new()
	_mat.shader = MARKER_SHADER
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("size", size)
	marker.material_override = _mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position.y = 0.03
	add_child(marker)
	if text != "":
		label = Label3D.new()
		label.text = text
		label.font = TvFx.font()
		label.font_size = 56
		label.outline_size = 20
		label.modulate = Color(1, 1, 1, 1)
		label.outline_modulate = Color(0.32, 0.2, 0.1, 1.0)
		label.pixel_size = 0.0095
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = Vector3(0, 0.05, size.y * 0.5 + 0.4)
		label.double_sided = false
		add_child(label)
	add_to_group("zones")
	return self


func set_progress(p: float) -> void:
	progress = p
	_mat.set_shader_parameter("progress", p)


func set_highlight(on: bool) -> void:
	active = 1.0 if on else 0.0
	_mat.set_shader_parameter("active", active)


func contains(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= half.x + 0.25 and absf(l.z) <= half.y + 0.25


## Inside a valley the marker is drawn by the valley's ZoneMarkers (one draw for all zones);
## the marker node stays (other code shows/hides it) but has no mesh of its own.
func _enter_tree() -> void:
	_batch = TvZoneMarkers.find_for(self)
	if _batch:
		if _plane == null:
			_plane = marker.mesh
		marker.mesh = null
		_batch.add(self)
	if label:
		_label_batch = TvGroundLabels.find_for(self)
		if _label_batch:
			_label_batch.add(label)


func _exit_tree() -> void:
	if _batch:
		_batch.remove(self)
		_batch = null
		marker.mesh = _plane
	if _label_batch:
		_label_batch.remove(label)
		_label_batch = null
		label.visible = true


## Called every physics frame for a carrier standing inside. Returns true if something moved.
func tick(carrier: Node, delta: float) -> bool:
	var id := carrier.get_instance_id()
	if not _inside.has(id):
		_inside[id] = true
		if carrier.get("is_player") and on_enter.is_valid():
			on_enter.call(carrier)
	if kind == Kind.PICK and carrier.get("is_player"):
		var v: Vector3 = carrier.velocity
		_still[id] = (float(_still.get(id, 0.0)) + delta) if Vector2(v.x, v.z).length() < 0.6 else 0.0
	var t: float = _timers.get(id, 0.0) - delta
	if t > 0.0:
		_timers[id] = t
		return false
	var moved := false
	match kind:
		Kind.DROP:
			var back: TvItemStack = carrier.stack
			if not back.is_empty() and stack.can_accept(back.top_type()):
				back.transfer_to(stack)
				# Thin goods (veneer) move a bundle per tick (Balance.CARRY_MULT, 1 for other items).
				for k in int(TvBalance.CARRY_MULT.get(stack.top_type(), 1)) - 1:
					if not back.transfer_to(stack):
						break
				TimberSfx.play("wood", -8.0, 1.1)
				moved = true
		Kind.PICK:
			var back: TvItemStack = carrier.stack
			var keen: bool = not carrier.get("is_player") or back.top_type() == stack.top_type() or float(_still.get(id, 0.0)) >= PICK_STILL_S
			if keen and not stack.is_empty() and back.count() < carrier.capacity() and back.can_accept(stack.top_type()):
				stack.transfer_to(back)
				for k in int(TvBalance.CARRY_MULT.get(back.top_type(), 1)) - 1:
					if back.count() >= carrier.capacity() or not stack.transfer_to(back):
						break
				TimberSfx.play("place", -8.0)
				moved = true
		Kind.CUSTOM:
			if on_carrier.is_valid():
				moved = on_carrier.call(carrier, delta)
	_timers[id] = interval if moved else 0.0
	return moved


func left(carrier: Node) -> void:
	var id := carrier.get_instance_id()
	if _inside.has(id):
		_inside.erase(id)
		_timers.erase(id)
		_still.erase(id)
		if carrier.get("is_player") and on_exit.is_valid():
			on_exit.call(carrier)
