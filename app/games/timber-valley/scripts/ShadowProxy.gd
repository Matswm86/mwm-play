class_name TvShadowProxy
extends Node3D

## Draw-call reduction for the shadow pass: the static shadow casters of one valley (merged
## buildings, machine bodies, belts, props) are drawn into the shadow map as a few shadow-only
## meshes, one per CELL_M square, instead of one draw per object per cascade. The visible meshes
## stop casting; the shadow geometry is the same. Lives under its Region, so it sleeps with it.
## MeshMerge registers roots here; a rebuild runs REBUILD_DELAY_S after the last registration so
## pop-in animations finish with their own shadows first.

const CELL_M := 24.0
const REBUILD_DELAY_S := 1.2

var _roots: Array[Node3D] = []
var _timer: float = -1.0
var _cells: Array[MeshInstance3D] = []


func _ready() -> void:
	name = "ShadowProxy"
	set_process(false)


## Finds the Region above `root` and queues it for that valley's proxy (no-op outside a Region).
static func register(root: Node3D) -> void:
	var p: Node = root.get_parent()
	while p and not (p is TvRegion):
		p = p.get_parent()
	if p == null:
		return
	var proxy := (p as Node).get_node_or_null("ShadowProxy") as TvShadowProxy
	if proxy:
		proxy.add_root(root)


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
	for c in _cells:
		c.queue_free()
	_cells.clear()
	var inv := global_transform.affine_inverse()
	var tools := {}
	# Roots freed since (a rebuilt handcar stop) drop out by index: erase() refuses a freed object.
	for i in range(_roots.size() - 1, -1, -1):
		if not is_instance_valid(_roots[i]) or not _roots[i].is_inside_tree():
			_roots.remove_at(i)
	for r in _roots:
		for n in r.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not (mi.has_meta("merged") or mi.has_meta("static")):
				continue
			if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not mi.has_meta("proxied"):
				continue
			if not _shown(mi):
				continue
			var xf := inv * mi.global_transform
			var c := xf * mi.get_aabb().get_center()
			var key := Vector2i(floori(c.x / CELL_M), floori(c.z / CELL_M))
			if not tools.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = st
			for s in mi.mesh.get_surface_count():
				# Glass and other see-through surfaces cast no shadow on their own either.
				var sm := mi.get_active_material(s) as BaseMaterial3D
				if sm and sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					continue
				var src := mi.mesh.surface_get_arrays(s)
				var arr := []
				arr.resize(Mesh.ARRAY_MAX)
				arr[Mesh.ARRAY_VERTEX] = src[Mesh.ARRAY_VERTEX]
				arr[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
				var one := ArrayMesh.new()
				one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				(tools[key] as SurfaceTool).append_from(one, 0, xf)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta("proxied", true)
	for key in tools:
		var cell := MeshInstance3D.new()
		cell.mesh = (tools[key] as SurfaceTool).commit()
		cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(cell)
		TvShadowCull.track(cell)
		_cells.append(cell)


## Visible up to (not including) the Region, so a sleeping valley still rebuilds correctly.
func _shown(n: Node) -> bool:
	var p: Node = n
	while p and p != get_parent():
		if p is Node3D and not (p as Node3D).visible:
			return false
		p = p.get_parent()
	return true
