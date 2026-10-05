class_name TvShadowCull
extends Node

## Shadow-pass draw reduction: the sun's shadow cascades collect casters from a light-space box
## that reaches far outside the screen, so off-screen people, trees and piles still cost a
## shadow draw (two when they span both cascades). This turns cast_shadow off for tracked casters
## whose bounds, grown by their own shadow length, are outside the camera frustum, and back on
## when they come near the screen. Nothing on screen changes. Checks SLICE casters per frame.

const GROUP := "shadow_cull"
const SLICE := 96
## The sun is 52 degrees up: a caster's shadow reaches about 0.8 x its height sideways.
const REACH_PER_M := 0.85
const MARGIN_M := 0.8

var _list: Array[Node] = []
var _i: int = 0


## Starts culling g's shadow; its current cast_shadow setting is what it gets when on screen.
static func track(g: GeometryInstance3D) -> void:
	g.set_meta("shadow_want", g.cast_shadow)
	g.add_to_group(GROUP)


func _process(_delta: float) -> void:
	if _i >= _list.size():
		_list = get_tree().get_nodes_in_group(GROUP)
		_i = 0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var planes := cam.get_frustum()
	var end := mini(_i + SLICE, _list.size())
	for k in range(_i, end):
		if not is_instance_valid(_list[k]):
			continue
		var g := _list[k] as GeometryInstance3D
		var want: int = g.get_meta("shadow_want", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		if want == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var box := g.global_transform * g.get_aabb()
		var c := box.get_center()
		var e := box.size * 0.5 + Vector3.ONE * (box.size.y * REACH_PER_M + MARGIN_M)
		var inside := true
		# Side planes only: Godot already drops casters beyond the shadow distance.
		for i in range(2, planes.size()):
			var pl: Plane = planes[i]
			var r := absf(pl.normal.x) * e.x + absf(pl.normal.y) * e.y + absf(pl.normal.z) * e.z
			if pl.distance_to(c) > r:
				inside = false
				break
		var setting := want if inside else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if g.cast_shadow != setting:
			g.cast_shadow = setting
	_i = end
