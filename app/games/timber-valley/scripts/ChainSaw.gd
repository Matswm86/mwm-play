class_name TvChainSaw
extends Node3D

## Big industrial chainsaw: a bar standing across the conveyor with teeth running around it.

const TEETH := 26

var machine: TvMachine
var bar_len: float = 1.9
var bar_h: float = 0.42
## All teeth in one MultiMesh (one draw instead of 26).
var _teeth: MultiMeshInstance3D
var _phase: float = 0.0
var _speed: float = 0.0
var always_on: bool = false


func setup(m: TvMachine, frame: Color) -> TvChainSaw:
	machine = m
	var steel := TvShapes.mat(Color(0.8, 0.82, 0.85), 0.28, 0.85)
	var dark := TvShapes.mat(Color(0.18, 0.18, 0.2), 0.5, 0.4)
	# Bar long axis is local Z, height local Y; callers rotate it to stand upright facing the camera.
	TvShapes.box_node(self, Vector3(0.08, bar_h, bar_len), Vector3.ZERO, steel, 0.2)
	TvShapes.box_node(self, Vector3(0.1, bar_h * 0.5, bar_len * 0.9), Vector3.ZERO, TvShapes.mat(Color(0.62, 0.64, 0.68), 0.35, 0.8), 0.1)
	var motor := TvShapes.box_node(self, Vector3(0.6, 0.7, 0.55), Vector3(0, 0.0, -bar_len * 0.5 - 0.2), TvShapes.mat(frame, 0.45), 0.14)
	motor.name = "motor"
	TvShapes.box_node(self, Vector3(0.64, 0.12, 0.3), Vector3(0, 0.0, -bar_len * 0.5 - 0.25), dark, 0.05)
	# The bar, guide and motor bake into one mesh before the teeth are added.
	TvMeshMerge.merge(self)
	var tm := BoxMesh.new()
	tm.size = Vector3(0.1, 0.07, 0.09) * (bar_h / 0.42)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tm
	mm.instance_count = TEETH
	_teeth = MultiMeshInstance3D.new()
	_teeth.multimesh = mm
	_teeth.material_override = dark
	# Teeth are 7 cm: no visible shadow of their own.
	_teeth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_teeth)
	_place_teeth()
	return self


## Position along the rounded-rectangle outline of the bar, 0..1.
func _outline(u: float) -> Array:
	var r := bar_h * 0.5
	var straight := bar_len - bar_h
	var total := 2.0 * straight + TAU * r
	var d := fposmod(u, 1.0) * total
	if d < straight:
		return [Vector3(0, r, straight * 0.5 - d), 0.0]
	d -= straight
	if d < PI * r:
		var a := d / r
		return [Vector3(0, cos(a) * r, -straight * 0.5 - sin(a) * r), a]
	d -= PI * r
	if d < straight:
		return [Vector3(0, -r, -straight * 0.5 + d), PI]
	d -= straight
	var a2 := d / r
	return [Vector3(0, -cos(a2) * r, straight * 0.5 + sin(a2) * r), PI + a2]


func _place_teeth() -> void:
	var mm := _teeth.multimesh
	for i in TEETH:
		var o := _outline(_phase + float(i) / TEETH)
		var p: Vector3 = o[0]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, -float(o[1])), p * 1.08))


func _process(delta: float) -> void:
	var target := 1.0 if always_on or (machine != null and machine._busy) else 0.0
	_speed = lerpf(_speed, target * TimberGame.machine_speed(), 1.0 - exp(-5.0 * delta))
	if _speed > 0.01:
		_phase += delta * _speed * 0.9
		_place_teeth()
		position.y = _base_y + sin(Time.get_ticks_msec() * 0.06) * 0.008 * _speed


var _base_y: float = 0.0


func _ready() -> void:
	_base_y = position.y
