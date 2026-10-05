class_name TvTreeBatch
extends Node3D

## Draw-call reduction: the choppable trees of one valley are drawn by one MultiMesh per tree
## model per CELL_M square (trees never move, so groves batch together and off-screen groves
## still cull; 48 m since 2026-10-03, was 24, to stay under 150 draws per view) instead of one draw (plus one shadow draw) per tree. Each ChopTree keeps its own nodes
## and tweens (sway, fall, regrow, pop-in); every frame this copies the live transform of each
## visible tree mesh into its model's MultiMesh. The tree's MeshInstance3D keeps no mesh.

const CELL_M := 48.0

## [Mesh, cell] -> MultiMeshInstance3D.
var _mms: Dictionary = {}
## [MeshInstance3D, Mesh, key] entries.
var _trees: Array = []


func _init() -> void:
	name = "TreeBatch"


## The valley's TreeBatch above `n`, or null.
static func find_for(n: Node) -> TvTreeBatch:
	var p: Node = n.get_parent()
	while p and not (p is TvRegion):
		p = p.get_parent()
	return (p.get_node_or_null("TreeBatch") as TvTreeBatch) if p else null


## Takes over drawing mi (a tree model mesh); mi stays in place for transforms and visibility.
## at = the tree's world position (mi is not inside the tree yet while its ChopTree enters).
func add(mi: MeshInstance3D, at: Vector3 = Vector3.INF) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	var p := at if at != Vector3.INF else mi.global_position
	var key := [mesh, Vector2i(floori(p.x / CELL_M), floori(p.z / CELL_M))]
	if not _mms.has(key):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = mi.cast_shadow
		add_child(mmi)
		TvShadowCull.track(mmi)
		_mms[key] = mmi
	_trees.append([mi, mesh, key])
	mi.mesh = null


func remove(mi: MeshInstance3D) -> void:
	for i in range(_trees.size() - 1, -1, -1):
		if _trees[i][0] == mi:
			mi.mesh = _trees[i][1]
			_trees.remove_at(i)


func _process(_delta: float) -> void:
	var inv := global_transform.affine_inverse()
	var lists := {}
	for t in _trees:
		var mi: MeshInstance3D = t[0]
		if not is_instance_valid(mi) or not mi.is_visible_in_tree():
			continue
		if not lists.has(t[2]):
			lists[t[2]] = []
		(lists[t[2]] as Array).append(inv * mi.global_transform)
	for key in _mms:
		var mmi: MultiMeshInstance3D = _mms[key]
		var mesh: Mesh = key[0]
		var list: Array = lists.get(key, [])
		var mm := mmi.multimesh
		if mm.instance_count < list.size():
			mm.instance_count = list.size() + 4
		var box := AABB()
		var aabb := mesh.get_aabb()
		for i in list.size():
			var xf: Transform3D = list[i]
			mm.set_instance_transform(i, xf)
			var b := xf * aabb
			box = b if i == 0 else box.merge(b)
		mm.visible_instance_count = list.size()
		if not list.is_empty():
			mm.custom_aabb = box
