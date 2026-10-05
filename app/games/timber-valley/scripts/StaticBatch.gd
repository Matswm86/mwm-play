class_name TvStaticBatch
extends Node3D

## Draw-call reduction for the visible pass: the already merged meshes of static roots in one
## valley (conveyors: belt surface, rails, legs, end rollers; market counters) are merged again ACROSS roots, one
## mesh per material per CELL_M square. Five belts in view drew 20 surfaces; now each material
## draws once per cell. The source meshes are hidden; the batch meshes are handed to the valley's
## ShadowProxy, so the shadow geometry stays the same. Lives under its Region and sleeps with it.
## A rebuild runs REBUILD_DELAY_S after the last registration, after pop-in animations.

## Belts are long and low-poly: big cells keep a valley's belts together (24 m split most of them).
const CELL_M := 48.0
const REBUILD_DELAY_S := 1.3

var _roots: Array[Node3D] = []
var _timer: float = -1.0
var _cells: Array[MeshInstance3D] = []


func _ready() -> void:
	name = "StaticBatch"
	set_process(false)


## Queues `root` (a node whose meshes never move after it is built) for its valley's batch.
static func register(root: Node3D) -> void:
	if not root.is_inside_tree():
		if not root.tree_entered.is_connected(register.bind(root)):
			root.tree_entered.connect(register.bind(root), CONNECT_ONE_SHOT)
		return
	var p: Node = root.get_parent()
	while p and not (p is TvRegion):
		p = p.get_parent()
	if p == null:
		return
	var batch := (p as Node).get_node_or_null("StaticBatch") as TvStaticBatch
	if batch:
		batch.add_root(root)


func add_root(root: Node3D) -> void:
	if not _roots.has(root):
		_roots.append(root)
	_timer = REBUILD_DELAY_S
	set_process(true)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		set_process(false)
		rebuild()


func rebuild() -> void:
	# Show the sources again, so the ones merged last time are collected with the new ones.
	for c in _cells:
		c.queue_free()
	_cells.clear()
	var inv := global_transform.affine_inverse()
	var groups := {}
	for i in range(_roots.size() - 1, -1, -1):
		if not is_instance_valid(_roots[i]) or not _roots[i].is_inside_tree():
			_roots.remove_at(i)
	for r in _roots:
		for n in r.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.has_meta("merged") or mi.get_parent() != r:
				continue
			mi.visible = true
			var mat := mi.material_override
			if mat == null:
				continue
			var xf := inv * mi.global_transform
			var c := xf * mi.get_aabb().get_center()
			var key := [mat, Vector2i(floori(c.x / CELL_M), floori(c.z / CELL_M))]
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append([mi, xf])
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var am := ArrayMesh.new()
		var arrays := []
		for e in list:
			var mi: MeshInstance3D = e[0]
			var src := mi.mesh.surface_get_arrays(0)
			arrays.append([src, e[1], mi.mesh.surface_get_format(0)])
		var merged := _concat(arrays)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged[0], [], {}, merged[1])
		var out := MeshInstance3D.new()
		out.name = "Batch"
		out.mesh = am
		out.material_override = key[0]
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		out.set_meta("merged", true)
		add_child(out)
		_cells.append(out)
		for e in list:
			(e[0] as MeshInstance3D).visible = false
	# The batch meshes carry the shadows of the hidden sources from now on.
	var proxy := get_parent().get_node_or_null("ShadowProxy") as TvShadowProxy
	if proxy:
		proxy.add_root(self)


## Appends surfaces that share one format (MeshMerge output) into one array set, moved by xf.
## Returns [arrays, format flags].
static func _concat(list: Array) -> Array:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var idx := PackedInt32Array()
	var flags := 0
	for e in list:
		var arr: Array = e[0]
		var xf: Transform3D = e[1]
		var m := Mesh.ARRAY_FORMAT_CUSTOM_MASK
		flags = int(e[2]) & ((m << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (m << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (m << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT))
		var base := v.size()
		var nb := xf.basis.inverse().transposed()
		var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in sv.size():
			v.append(xf * sv[i])
			nrm.append((nb * sn[i]).normalized())
		uv.append_array(arr[Mesh.ARRAY_TEX_UV])
		col.append_array(arr[Mesh.ARRAY_COLOR])
		if arr[Mesh.ARRAY_CUSTOM0] != null:
			c0.append_array(arr[Mesh.ARRAY_CUSTOM0])
			c1.append_array(arr[Mesh.ARRAY_CUSTOM1])
			c2.append_array(arr[Mesh.ARRAY_CUSTOM2])
		var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for i in si.size():
			idx.append(base + si[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = v
	out[Mesh.ARRAY_NORMAL] = nrm
	out[Mesh.ARRAY_TEX_UV] = uv
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_INDEX] = idx
	if not c0.is_empty():
		out[Mesh.ARRAY_CUSTOM0] = c0
		out[Mesh.ARRAY_CUSTOM1] = c1
		out[Mesh.ARRAY_CUSTOM2] = c2
	return [out, flags]
