class_name TvItemStack
extends Node3D

## A neat pile of items (logs, planks, coins...). Items fly into place in an arc.
## Items that have landed are hidden and drawn by one MultiMesh per item type (one draw per
## pile instead of one per item); the item nodes stay the game objects, and pop() shows them again.

signal changed(count: int)

var item_type: String = ""
var capacity: int = 40
var cols: int = 2
var rows: int = 2
var persist_id: String = ""
var fly_time: float = 0.28
var items: Array[Node3D] = []
## Landed items are drawn by someone else (a market draws all its shoppers' bags together).
var external_draw: bool = false
## item type -> MultiMeshInstance3D drawing the landed items of that type.
var _mm: Dictionary = {}
var _dirty: bool = false


func setup(type: String, cap: int, c: int, r: int, pid: String = "") -> TvItemStack:
	item_type = type
	capacity = cap
	cols = c
	rows = r
	persist_id = pid
	return self


func _ready() -> void:
	if persist_id != "":
		TimberGame.register_pile(persist_id, self)
		var n := mini(TimberGame.saved_pile_count(persist_id), capacity)
		for i in n:
			var it := TvItems.make(item_type)
			add_child(it)
			items.append(it)
			it.transform = slot_transform(i, item_type)
			_land(it)
		if n > 0:
			changed.emit(items.size())


func count() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func is_full() -> bool:
	return items.size() >= capacity


func top_type() -> String:
	if items.is_empty():
		return ""
	return str(items[-1].get_meta("item"))


func can_accept(type: String) -> bool:
	if items.size() >= capacity:
		return false
	if item_type != "":
		return type == item_type
	return items.is_empty() or top_type() == type


func slot_transform(i: int, type: String) -> Transform3D:
	var d: Dictionary = TvItems.def(type)
	var per_layer := cols * rows
	var layer := i / per_layer
	var r := i % per_layer
	var cx := r % cols
	var cz := r / cols
	var cell: Vector2 = d.cell
	var pos := Vector3(
		(cx - (cols - 1) * 0.5) * cell.x, layer * float(d.layer), (cz - (rows - 1) * 0.5) * cell.y
	)
	var yaw := sin(i * 12.9898) * 0.06
	if type == "coin":
		yaw = i * 0.7
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func height() -> float:
	if items.is_empty():
		return 0.0
	var d: Dictionary = TvItems.def(top_type())
	return (items.size() - 1) / (cols * rows) * float(d.layer) + float(d.layer)


func push(item: Node3D, animate: bool = true) -> void:
	var type := str(item.get_meta("item"))
	if item.has_meta("tw"):
		var old: Tween = item.get_meta("tw")
		if old and old.is_valid():
			old.kill()
		item.scale = Vector3.ONE
	var gxf := item.global_transform if item.is_inside_tree() else global_transform
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item)
	item.global_transform = gxf
	item.transform.basis = item.transform.basis.orthonormalized()
	items.append(item)
	var target := slot_transform(items.size() - 1, type)
	changed.emit(items.size())
	if not animate:
		item.transform = target
		_land(item)
		return
	var start := item.position
	var start_basis := item.transform.basis
	var mid := (start + target.origin) * 0.5 + Vector3.UP * (1.2 + start.distance_to(target.origin) * 0.25)
	var tw := item.create_tween()
	item.set_meta("tw", tw)
	tw.tween_method(
		func(t: float) -> void:
			var a := start.lerp(mid, t)
			var b := mid.lerp(target.origin, t)
			item.position = a.lerp(b, t)
			item.transform.basis = start_basis.slerp(target.basis, t),
		0.0, 1.0, fly_time
	).set_trans(Tween.TRANS_SINE)
	tw.tween_property(item, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	tw.tween_property(item, "scale", Vector3.ONE, 0.08)
	tw.tween_callback(_land.bind(item))


func pop() -> Node3D:
	if items.is_empty():
		return null
	var it: Node3D = items.pop_back()
	if it.has_meta("landed"):
		it.remove_meta("landed")
		it.visible = true
		_mark_dirty()
	changed.emit(items.size())
	return it


func transfer_to(other: TvItemStack) -> bool:
	if items.is_empty() or not other.can_accept(top_type()):
		return false
	other.push(pop())
	return true


func take_and_free() -> String:
	var it := pop()
	if it == null:
		return ""
	var t := str(it.get_meta("item"))
	it.queue_free()
	return t


## Frees every item that has finished its flight (any position in the pile) and returns how many.
## Build sites and cargo lines use it: with a belt adding items faster than they land, the top item
## was nearly always still in flight, so used-up items piled into a tower.
func take_landed() -> int:
	var n := 0
	for i in range(items.size() - 1, -1, -1):
		var it := items[i]
		if is_instance_valid(it) and it.has_meta("landed"):
			items.remove_at(i)
			it.queue_free()
			n += 1
	if n > 0:
		_mark_dirty()
		changed.emit(items.size())
	return n


func top_global() -> Vector3:
	return global_transform * Vector3(0, height(), 0)


## The item has finished its flight into this pile: hide the node, draw it in the MultiMesh.
func _land(item: Node3D) -> void:
	if not is_instance_valid(item) or item.get_parent() != self or not items.has(item):
		return
	item.set_meta("landed", true)
	item.visible = false
	_mark_dirty()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_dirty = false
	if not is_inside_tree() or external_draw:
		return
	var by_type := {}
	for it in items:
		if is_instance_valid(it) and it.has_meta("landed"):
			var t := str(it.get_meta("item"))
			if not by_type.has(t):
				by_type[t] = []
			(by_type[t] as Array).append(it.transform)
	for t in _mm.keys():
		if not by_type.has(t):
			(_mm[t] as MultiMeshInstance3D).multimesh.instance_count = 0
	for t in by_type:
		var list: Array = by_type[t]
		# Heavy items (cabin kits) draw a capped tower; the bottom layers stay, the count is real.
		var cap := int(TvItems.def(t).get("max_drawn", 0))
		if cap > 0 and list.size() > cap:
			list = list.slice(0, cap)
		var mmi: MultiMeshInstance3D = _mm.get(t)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.name = "Pile_" + str(t)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = TvItems.mesh_of(t)
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if TvItems.casts_shadow(t) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			TvShadowCull.track(mmi)
			_mm[t] = mmi
		var m := mmi.multimesh
		if m.instance_count != list.size():
			m.instance_count = list.size()
		for i in list.size():
			m.set_instance_transform(i, list[i])
