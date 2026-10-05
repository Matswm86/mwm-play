class_name TvItems
extends RefCounted

## Item catalogue: how each carried item looks and how tall it stacks.

## v3 item models (assets/models_v3/ASSETS_M1.md section 2, ASSETS_M2.md), world units at scale 1.0.
## "max_drawn": piles draw at most this many of the item (the rest stay counted, not drawn).
const DEFS := {
	"log": {"path": "res://games/timber-valley/assets/models_v3/items/item_log.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.31, "cell": Vector2(1.05, 0.36)},
	"plank": {"path": "res://games/timber-valley/assets/models_v3/items/item_plank.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.11, "cell": Vector2(1.0, 0.4)},
	"chair": {"path": "res://games/timber-valley/assets/models_v3/items/item_chair.glb", "scale": 1.0, "rot": Vector3(0, 180, 0), "layer": 0.36, "cell": Vector2(0.5, 0.5)},
	"table": {"path": "res://games/timber-valley/assets/models_v3/items/item_table.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.36, "cell": Vector2(0.95, 0.55)},
	"bookcase": {"path": "res://games/timber-valley/assets/models_v3/items/item_bookcase.glb", "scale": 1.0, "rot": Vector3(-90, 0, 0), "layer": 0.34, "cell": Vector2(0.6, 1.15)},
	"birch_log": {"path": "res://games/timber-valley/assets/models_v3/items/item_birch_log.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.31, "cell": Vector2(1.05, 0.36)},
	"veneer": {"path": "res://games/timber-valley/assets/models_v3/items/item_veneer.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.05, "cell": Vector2(1.0, 0.5)},
	"plywood": {"path": "res://games/timber-valley/assets/models_v3/items/item_plywood.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.12, "cell": Vector2(1.0, 0.6)},
	"canoe": {"path": "res://games/timber-valley/assets/models_v3/items/item_canoe.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.35, "cell": Vector2(0.7, 2.0)},
	"maple_log": {"path": "res://games/timber-valley/assets/models_v3/items/item_maple_log.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.31, "cell": Vector2(1.05, 0.36)},
	"beam": {"path": "res://games/timber-valley/assets/models_v3/items/item_beam.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.28, "cell": Vector2(1.2, 0.3)},
	"floorboard": {"path": "res://games/timber-valley/assets/models_v3/items/item_floorboard.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.07, "cell": Vector2(1.0, 0.25)},
	"cabin_kit": {"path": "res://games/timber-valley/assets/models_v3/items/item_cabin_kit.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.6, "cell": Vector2(1.0, 1.0), "max_drawn": TvBalance.KIT_PILE_DRAWN},
	"coin": {"path": "", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.075, "cell": Vector2(0.36, 0.36)},
	# Redwood Coast and Frost Peaks (GDD 7.3, ASSETS_M3/M4.md). A def may use "model" (a Models
	# key) instead of "path" while its art is a stand-in.
	"red_log": {"path": "res://games/timber-valley/assets/models_v3/items/item_red_log.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.42, "cell": Vector2(1.3, 0.5)},
	"timber": {"path": "res://games/timber-valley/assets/models_v3/items/item_timber.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.4, "cell": Vector2(1.3, 0.45)},
	"deckboard": {"path": "res://games/timber-valley/assets/models_v3/items/item_deckboard.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.09, "cell": Vector2(1.1, 0.35)},
	"mast": {"path": "res://games/timber-valley/assets/models_v3/items/item_mast.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.4, "cell": Vector2(0.4, 2.4)},
	"frost_log": {"path": "res://games/timber-valley/assets/models_v3/items/item_frost_log.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.33, "cell": Vector2(1.05, 0.4)},
	"dry_lumber": {"path": "res://games/timber-valley/assets/models_v3/items/item_dry_lumber.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.11, "cell": Vector2(1.0, 0.4)},
	"skis": {"path": "res://games/timber-valley/assets/models_v3/items/item_skis.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.12, "cell": Vector2(0.4, 1.6)},
	"sled": {"path": "res://games/timber-valley/assets/models_v3/items/item_sled.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.5, "cell": Vector2(0.8, 1.3)},
	"guitar": {"path": "res://games/timber-valley/assets/models_v3/items/item_guitar.glb", "scale": 1.0, "rot": Vector3.ZERO, "layer": 0.2, "cell": Vector2(0.5, 1.2)},
}

## Upper-case plural for signs and squares where "<ITEM>S" would be wrong.
const LABELS := {"skis": "SKIS", "dry_lumber": "DRY LUMBER"}

static var _cache: Dictionary = {}


## "PLANKS", "CABIN KITS", "SKIS", "DRY LUMBER".
static func label(type: String) -> String:
	return str(LABELS.get(type, (type.to_upper() + "S").replace("_", " ")))


## "1 plank", "3 planks", "2 skis", "4 dry lumber" (shopper bubbles).
static func noun(type: String, n: int) -> String:
	if n == 1 or LABELS.has(type):
		return "%d %s" % [n, label(type).to_lower() if LABELS.has(type) else type.replace("_", " ")]
	return "%d %ss" % [n, type.replace("_", " ")]
static var _meshes: Dictionary = {}
static var _coin_mesh: Mesh
static var _coin_mat: StandardMaterial3D


static func def(type: String) -> Dictionary:
	return DEFS[type]


static func make(type: String) -> Node3D:
	var root := Node3D.new()
	root.name = type
	root.set_meta("item", type)
	var d: Dictionary = DEFS[type]
	if d.has("proc"):
		root.add_child(_procedural(str(d.proc)))
		return root
	if type == "coin":
		var mi := MeshInstance3D.new()
		mi.mesh = _coin()
		mi.material_override = _coin_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 0.035
		root.add_child(mi)
		return root
	var info: Dictionary = _load(type)
	root.add_child(_build(info.scene, d))
	(root.get_child(0) as Node3D).position = info.offset
	# A loose item is only seen in flight (piles and belts draw landed items in MultiMeshes,
	# which keep the shadows): its own shadow would be a shadow-pass draw per item.
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _procedural(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"log":
			TvShapes.log_node(n, 0.16, 0.95, Vector3(0, 0.16, 0), Vector3(0, 0, 90))
		"plank":
			var mi := TvShapes.box_node(n, Vector3(0.95, 0.1, 0.34), Vector3(0, 0.05, 0), TvShapes.wood(Color(0.96, 0.76, 0.48), 9.0), 0.03)
			mi.name = "plank"
	return n


static func _build(scene: PackedScene, d: Dictionary) -> Node3D:
	var inst: Node3D = scene.instantiate()
	var pivot := Node3D.new()
	pivot.rotation_degrees = d.rot
	pivot.add_child(inst)
	inst.scale = Vector3.ONE * float(d.scale)
	if d.has("model"):
		var key := str(d.model)
		TvModels.tint(inst, TvModels.tint_of(key))
		inst.scale = TvModels.standin_scale(key) * float(d.scale)
		pivot.rotation_degrees = (d.rot as Vector3) + TvModels.standin_rot(key)
	return pivot


static func _load(type: String) -> Dictionary:
	if _cache.has(type):
		return _cache[type]
	var d0: Dictionary = DEFS[type]
	var scene: PackedScene = load(TvModels.path(str(d0.model)) if d0.has("model") else str(d0.path))
	var tmp := _build(scene, DEFS[type])
	var box := aabb_of(tmp, Transform3D.IDENTITY)
	tmp.free()
	var c := box.get_center()
	var info := {"scene": scene, "offset": Vector3(-c.x, -box.position.y, -c.z)}
	_cache[type] = info
	return info


static func _coin() -> Mesh:
	if _coin_mesh == null:
		var m := CylinderMesh.new()
		m.top_radius = 0.15
		m.bottom_radius = 0.15
		m.height = 0.07
		m.radial_segments = 20
		_coin_mesh = m
		_coin_mat = StandardMaterial3D.new()
		_coin_mat.albedo_color = Color(1.0, 0.78, 0.2)
		_coin_mat.metallic = 0.75
		_coin_mat.roughness = 0.3
		_coin_mat.emission_enabled = true
		_coin_mat.emission = Color(0.35, 0.22, 0.0)
	return _coin_mesh


static func aabb_of(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		out = xf * (n as MeshInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var a := aabb_of(c, xf)
		if a.size != Vector3.ZERO:
			out = a if first else out.merge(a)
			first = false
	return out


## One mesh per item type in the item root's space (every surface keeps its material), for the
## MultiMeshes that draw landed piles and riding belt items.
static func mesh_of(type: String) -> ArrayMesh:
	if _meshes.has(type):
		return _meshes[type]
	var root := make(type)
	var am := ArrayMesh.new()
	_bake_into(root, Transform3D.IDENTITY, am, true)
	root.free()
	_meshes[type] = am
	return am


static func _bake_into(n: Node, xf: Transform3D, am: ArrayMesh, is_root: bool) -> void:
	if n is Node3D and not is_root:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var nb := xf.basis.inverse().transposed()
			for i in verts.size():
				verts[i] = xf * verts[i]
			for i in norms.size():
				norms[i] = (nb * norms[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			# Tangents would need the same rotation; the item materials use no normal maps.
			arr[Mesh.ARRAY_TANGENT] = null
			am.add_surface_from_arrays(mesh_primitive(mi.mesh, s), arr)
			am.surface_set_material(am.get_surface_count() - 1, mi.get_active_material(s))
	for c in n.get_children():
		_bake_into(c, xf, am, false)


static func mesh_primitive(m: Mesh, s: int) -> Mesh.PrimitiveType:
	return (m as ArrayMesh).surface_get_primitive_type(s) if m is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES


## Only bulky items (logs, furniture, canoes) cast shadows; thin sheets, planks and coins would
## add a shadow-pass draw per pile for a sliver of shadow.
## Since 2026-10-03 only the bulkiest (layer 0.45 m and up: sleds, cabin kits) cast one: piles of
## logs and furniture cost a shadow draw each, and the 150-draw budget needed them.
static func casts_shadow(type: String) -> bool:
	return float(DEFS[type].layer) >= 0.45
