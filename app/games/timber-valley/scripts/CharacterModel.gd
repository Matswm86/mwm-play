class_name TvCharacterModel
extends Node3D

## KayKit Adventurer (models_v3) with walk/idle/carry/chop animations and the axe already in the hand.
## Wiring follows assets/models_v3/chars/WIRING.md.

const MODEL_PATH := "res://games/timber-valley/assets/models_v3/chars/%s.glb"
## The rig scale (0.35-0.37) is baked in the file, so 0.80 x 2.25 = 1.8 m tall.
const SCALE := 2.25
const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_RUN := "Running_A"
const ANIM_CHOP := "1H_Melee_Attack_Slice_Horizontal"
const ANIM_CARRY := "Carry_Pose"
const CARRY_BONES := ["upperarm.l", "lowerarm.l", "upperarm.r", "lowerarm.r"]
const CHOP_BONES := [
	"upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "chest",
]

var anim: AnimationPlayer
var skeleton: Skeleton3D
## The axe that is currently shown while chopping (plain or upgraded).
var axe: Node3D
var _axe_plain: Node3D
var _axe_gold: Node3D
var _current: String = ""
var _chop_until: float = 0.0


func setup(model_name: String) -> TvCharacterModel:
	var scene: PackedScene = load(MODEL_PATH % model_name)
	var inst: Node3D = scene.instantiate()
	inst.scale = Vector3.ONE * SCALE
	add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		TvShadowCull.track(mi as GeometryInstance3D)
	anim = inst.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	_build_anims()
	_axe_plain = inst.find_child("Axe", true, false)
	_axe_gold = inst.find_child("AxeUpgraded", true, false)
	_axe_plain.visible = false
	_axe_gold.visible = false
	axe = _axe_plain
	_play("idle")
	return self


## Switches which of the two in-hand axes shows while chopping.
func set_axe_model(upgraded: bool) -> void:
	var vis := axe.visible
	axe.visible = false
	axe = _axe_gold if upgraded else _axe_plain
	axe.visible = vis


func _build_anims() -> void:
	var lib: AnimationLibrary = anim.get_animation_library("")
	for n in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if lib.has_animation(n):
			lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# Short aliases keep the state code readable.
	lib.add_animation("idle", lib.get_animation(ANIM_IDLE))
	lib.add_animation("walk", lib.get_animation(ANIM_WALK))
	lib.add_animation("carry-walk", _compose(ANIM_WALK, ANIM_CARRY, CARRY_BONES))
	lib.add_animation("carry-idle", _compose(ANIM_IDLE, ANIM_CARRY, CARRY_BONES))
	lib.add_animation("chop-walk", _compose(ANIM_WALK, ANIM_CHOP, CHOP_BONES))
	lib.get_animation("chop-walk").loop_mode = Animation.LOOP_NONE
	var chop: Animation = lib.get_animation(ANIM_CHOP)
	chop.loop_mode = Animation.LOOP_NONE
	lib.add_animation("chop", chop)


func _compose(base: String, overlay: String, bones: Array) -> Animation:
	var a: Animation = anim.get_animation(base).duplicate(true)
	var o: Animation = anim.get_animation(overlay)
	for bone in bones:
		for t in range(a.get_track_count() - 1, -1, -1):
			if str(a.track_get_path(t)).ends_with(":" + bone):
				a.remove_track(t)
		for t in o.get_track_count():
			if str(o.track_get_path(t)).ends_with(":" + bone):
				o.copy_track(t, a)
	# A one-frame pose overlay (Carry_Pose) must hold its key across the base loop.
	a.loop_mode = Animation.LOOP_LINEAR
	return a


func _play(n: String, speed: float = 1.0) -> void:
	if _current == n:
		anim.speed_scale = speed
		return
	_current = n
	anim.play(n, 0.12)
	anim.speed_scale = speed


## moving: speed 0..1, carrying: has items, chopping: swinging the axe.
func update_state(move_speed: float, carrying: bool, chopping: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if chopping:
		axe.visible = true
		if now >= _chop_until:
			_current = ""
			var n := "chop-walk" if move_speed > 0.1 else "chop"
			_play(n, 1.5)
			_chop_until = now + anim.get_animation(n).length / 1.5
		return
	if now < _chop_until:
		return
	axe.visible = false
	if move_speed > 0.1:
		_play("carry-walk" if carrying else "walk", clampf(move_speed * 1.25, 0.7, 1.6))
	else:
		_play("carry-idle" if carrying else "idle")
