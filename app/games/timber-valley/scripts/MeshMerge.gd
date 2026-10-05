class_name TvMeshMerge
extends RefCounted

## Draw-call reduction: bakes the static MeshInstance3D nodes under a root into as few meshes as
## possible, so a shed of 20 boxes or a belt with 40 legs is one draw instead of 20 or 45.
## - Procedural looks (plain StandardMaterial3D colours, wood, log, roof and belt shaders) all go
##   into ONE surface drawn by proc_merged.gdshader. Each vertex carries its source material's
##   parameters and its original local position/normal, so grain, rings and shingles do not move.
## - Textured StandardMaterial3D surfaces (imported models) merge per texture/settings; their
##   albedo colour moves into the vertex colour.
## Nodes with a script (piles, zones, saws, people), anything in `skip`, hidden nodes, skinned
## meshes and other shaders are left alone. Call it again after adding parts: only the new,
## not yet merged meshes are baked.

const PROC_SHADER := preload("res://games/timber-valley/scripts/proc_merged.gdshader")
## Plain materials may differ only in these (per vertex in the shader); the rest must be default.
const PLAIN_PROPS := ["albedo_color", "roughness", "metallic", "rim_enabled", "rim", "rim_tint"]
const MODE_FLAT := 0.0
const MODE_WOOD := 1.0
const MODE_LOG := 2.0
const MODE_ROOF := 3.0
const MODE_BELT := 4.0

static var _mats: Dictionary = {}
static var _plain_sig: String = ""


## Merges root's static meshes. Returns the number of MeshInstance3D nodes that were baked.
## proxy: hand the root's shadow casters to its valley's ShadowProxy (false for parts that move).
static func merge(root: Node3D, skip: Array = [], proxy: bool = true) -> int:
	var groups: Dictionary = {}
	var victims: Array = []
	# Static meshes that cannot merge (glass, other shaders) still join the shadow proxy.
	var keep: Array = []
	for c in root.get_children():
		_collect(c, Transform3D.IDENTITY, skip, groups, victims, keep)
	var casts := false
	for v in victims + keep:
		if (v as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casts = true
	if proxy:
		for k in keep:
			(k as Node).set_meta("static", true)
	if proxy and casts:
		if root.is_inside_tree():
			TvShadowProxy.register(root)
		else:
			root.tree_entered.connect(func() -> void: TvShadowProxy.register(root), CONNECT_ONE_SHOT)
	if victims.size() < 2:
		# Nothing to merge, but a lone static mesh can still join the shadow proxy.
		for v in victims:
			if proxy:
				(v as Node).set_meta("static", true)
		return 0
	for key in groups:
		var g: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_TEX_UV] = g.uv
		arrays[Mesh.ARRAY_COLOR] = g.col
		arrays[Mesh.ARRAY_INDEX] = g.idx
		var flags := 0
		if g.proc:
			arrays[Mesh.ARRAY_CUSTOM0] = g.c0
			arrays[Mesh.ARRAY_CUSTOM1] = g.c1
			arrays[Mesh.ARRAY_CUSTOM2] = g.c2
			flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
				| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) \
				| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var mi := MeshInstance3D.new()
		mi.name = "Merged"
		mi.mesh = am
		mi.material_override = g.mat
		mi.cast_shadow = g.shadow
		mi.set_meta("merged", true)
		root.add_child(mi)
	for v in victims:
		var mi: MeshInstance3D = v
		if mi.get_child_count() == 0:
			mi.get_parent().remove_child(mi)
			mi.queue_free()
		else:
			mi.mesh = null
			mi.material_override = null
	return victims.size()


static func _collect(n: Node, parent_xf: Transform3D, skip: Array, groups: Dictionary, victims: Array, keep: Array) -> void:
	if not (n is Node3D) or n in skip or n.has_meta("merged") or n.has_meta("item"):
		return
	var n3 := n as Node3D
	if not n3.visible or n.get_script() != null:
		return
	var xf := parent_xf * n3.transform
	if n is MeshInstance3D:
		if _add(n as MeshInstance3D, xf, groups):
			victims.append(n)
		elif (n as MeshInstance3D).skin == null:
			keep.append(n)
	for c in n.get_children():
		_collect(c, xf, skip, groups, victims, keep)


## Classifies each surface; returns false (and adds nothing) if any surface cannot merge.
static func _add(mi: MeshInstance3D, xf: Transform3D, groups: Dictionary) -> bool:
	var mesh := mi.mesh
	if mesh == null or mi.skin != null or mi.visibility_range_end > 0.0 or mi.transparency > 0.0:
		return false
	var plans := []
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var plan := _plan(mi.get_active_material(s))
		if plan.is_empty():
			return false
		plans.append(plan)
	for s in plans.size():
		var plan: Dictionary = plans[s]
		var key := "%s|%d" % [plan.key, mi.cast_shadow]
		if not groups.has(key):
			groups[key] = {
				"proc": plan.has("mode"), "mat": plan.mat, "shadow": mi.cast_shadow,
				"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
				"col": PackedColorArray(), "idx": PackedInt32Array(),
				"c0": PackedFloat32Array(), "c1": PackedFloat32Array(), "c2": PackedFloat32Array(),
			}
		_append(groups[key], mesh.surface_get_arrays(s), xf, plan)
	return true


## Which merged group a surface joins and its per-vertex values. Empty = cannot merge.
static func _plan(m: Material) -> Dictionary:
	if m is StandardMaterial3D:
		var b := m as StandardMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or b.normal_enabled or b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			return {}
		if b.vertex_color_use_as_albedo or b.albedo_color.a < 1.0:
			return {}
		if _is_plain(b):
			return {"key": "proc", "mat": _proc_mat(), "mode": MODE_FLAT, "color": b.albedo_color,
				"c2": Color(b.roughness, b.metallic, b.rim if b.rim_enabled else 0.0, b.rim_tint)}
		var sig := _signature(b, ["albedo_color"])
		if not _mats.has("std|" + sig):
			var nm := b.duplicate() as StandardMaterial3D
			nm.albedo_color = Color(1, 1, 1)
			nm.vertex_color_use_as_albedo = true
			nm.vertex_color_is_srgb = true
			_mats["std|" + sig] = nm
		return {"key": "std|" + sig, "mat": _mats["std|" + sig], "color": b.albedo_color}
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		match sm.shader:
			TvShapes.WOOD_SHADER:
				return {"key": "proc", "mat": _proc_mat(), "mode": MODE_WOOD, "color": sm.get_shader_parameter("base"),
					"w": float(sm.get_shader_parameter("grain_scale"))}
			TvShapes.LOG_SHADER:
				return {"key": "proc", "mat": _proc_mat(), "mode": MODE_LOG, "color": sm.get_shader_parameter("bark"),
					"c2": sm.get_shader_parameter("core"), "w": float(sm.get_shader_parameter("radius"))}
			TvWorld.ROOF_SHADER:
				return {"key": "proc", "mat": _proc_mat(), "mode": MODE_ROOF, "color": sm.get_shader_parameter("base")}
			TvConveyor.BELT_SHADER:
				return {"key": "proc", "mat": _proc_mat(), "mode": MODE_BELT, "w": float(sm.get_shader_parameter("speed")),
					"uv_y": float(sm.get_shader_parameter("length"))}
	return {}


static func _proc_mat() -> ShaderMaterial:
	if not _mats.has("proc"):
		var m := ShaderMaterial.new()
		m.shader = PROC_SHADER
		_mats["proc"] = m
	return _mats["proc"]


## True when only PLAIN_PROPS differ from a fresh StandardMaterial3D.
static func _is_plain(b: StandardMaterial3D) -> bool:
	if _plain_sig == "":
		_plain_sig = _signature(StandardMaterial3D.new(), PLAIN_PROPS)
	return _signature(b, PLAIN_PROPS) == _plain_sig


## Hash of every stored material property except skip_props.
static func _signature(b: BaseMaterial3D, skip_props: Array) -> String:
	var parts := PackedStringArray()
	for p in b.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var pn := str(p.name)
		if pn in skip_props or pn in ["resource_name", "resource_path", "resource_local_to_scene", "script"]:
			continue
		var v: Variant = b.get(pn)
		if v is Object:
			parts.append("%s=%d" % [pn, (v as Object).get_instance_id()])
		else:
			parts.append("%s=%s" % [pn, v])
	return str(hash(",".join(parts)))


static func _append(g: Dictionary, arr: Array, xf: Transform3D, plan: Dictionary) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var count := verts.size()
	if count == 0:
		return
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nb := xf.basis.inverse().transposed()
	var proc: bool = g.proc
	var mode: float = plan.get("mode", 0.0)
	var col: Color = plan.get("color", Color(1, 1, 1))
	var c2v: Color = plan.get("c2", Color(0, 0, 0, 0))
	var w: float = plan.get("w", 0.0)
	var uv_y: float = plan.get("uv_y", 1.0)
	var v_out: PackedVector3Array = g.v
	var n_out: PackedVector3Array = g.n
	var uv_out: PackedVector2Array = g.uv
	var c_out: PackedColorArray = g.col
	var c0: PackedFloat32Array = g.c0
	var c1: PackedFloat32Array = g.c1
	var c2: PackedFloat32Array = g.c2
	var i_out: PackedInt32Array = g.idx
	# Drop the dictionary's references so the appends below do not copy the arrays.
	for k in ["v", "n", "uv", "col", "c0", "c1", "c2", "idx"]:
		g[k] = null
	var base := v_out.size()
	for i in count:
		var lv := verts[i]
		var ln := norms[i] if i < norms.size() else Vector3.UP
		v_out.append(xf * lv)
		n_out.append((nb * ln).normalized())
		var uv := uvs[i] if i < uvs.size() else Vector2.ZERO
		uv.y *= uv_y
		uv_out.append(uv)
		c_out.append(col)
		if proc:
			c0.append_array([lv.x, lv.y, lv.z, w])
			c1.append_array([ln.x, ln.y, ln.z, mode])
			c2.append_array([c2v.r, c2v.g, c2v.b, c2v.a])
	if idx.is_empty():
		idx.resize(count)
		for i in count:
			idx[i] = i
	var flip := xf.basis.determinant() < 0.0
	for t in range(0, idx.size(), 3):
		if flip:
			i_out.append_array([base + idx[t], base + idx[t + 2], base + idx[t + 1]])
		else:
			i_out.append_array([base + idx[t], base + idx[t + 1], base + idx[t + 2]])
	g.v = v_out
	g.n = n_out
	g.uv = uv_out
	g.col = c_out
	g.c0 = c0
	g.c1 = c1
	g.c2 = c2
	g.idx = i_out
