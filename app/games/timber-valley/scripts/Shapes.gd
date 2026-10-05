class_name TvShapes
extends RefCounted

## Procedural meshes and materials with soft rounded edges, used for buildings, items and props.

const WOOD_SHADER := preload("res://games/timber-valley/scripts/wood.gdshader")
const LOG_SHADER := preload("res://games/timber-valley/scripts/log.gdshader")

static var _box_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _log_mesh: Dictionary = {}


## Box with rounded edges: a subdivided cube whose vertices are pushed onto an inset box plus radius.
static func rounded_box(size: Vector3, radius: float, seg: int = 4) -> ArrayMesh:
	var key := "%s|%s|%d" % [size, radius, seg]
	if _box_cache.has(key):
		return _box_cache[key]
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) * 0.95)
	var inner := h - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := seg * 2 + 1
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var grid := []
		for j in n + 1:
			var row := []
			for i in n + 1:
				# Cluster samples near the edges so the rounding is smooth.
				var a := _edge_t(float(i) / n) * 2.0 - 1.0
				var b := _edge_t(float(j) / n) * 2.0 - 1.0
				var p := Vector3(nrm.x * h.x, nrm.y * h.y, nrm.z * h.z)
				p += Vector3(u.x * h.x, u.y * h.y, u.z * h.z) * a + Vector3(v.x * h.x, v.y * h.y, v.z * h.z) * b
				var c := p.clamp(-inner, inner)
				var d := (p - c)
				var dn := d.normalized() if d.length() > 0.00001 else nrm
				row.append([c + dn * r, dn, Vector2(float(i) / n, float(j) / n)])
			grid.append(row)
		for j in n:
			for i in n:
				var q := [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
				# Clockwise winding is the front face in Godot, so the box's outside faces the camera.
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(q[idx][1])
					st.set_uv(q[idx][2])
					st.add_vertex(q[idx][0])
	var mesh := st.commit()
	_box_cache[key] = mesh
	return mesh


static func _edge_t(t: float) -> float:
	# Smoothstep-like remap that packs vertices toward 0 and 1.
	return 0.5 - 0.5 * cos(t * PI)


static func mat(c: Color, rough: float = 0.75, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c, rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	_mat_cache[key] = m
	return m


static func wood(c: Color, grain_scale: float = 6.0) -> ShaderMaterial:
	var key := "wood|%s|%s" % [c, grain_scale]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WOOD_SHADER
	m.set_shader_parameter("base", c)
	m.set_shader_parameter("grain_scale", grain_scale)
	_mat_cache[key] = m
	return m


static func log_material(radius: float = 0.15, bark: Color = Color(0.55, 0.34, 0.2), core: Color = Color(0.98, 0.8, 0.52)) -> ShaderMaterial:
	var key := "log|%s|%s|%s" % [bark, core, radius]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = LOG_SHADER
	m.set_shader_parameter("bark", bark)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("radius", radius)
	_mat_cache[key] = m
	return m


## Cylinder lying along X with its end caps showing rings (for logs and palisade posts use rot).
static func log_mesh(radius: float, length: float) -> CylinderMesh:
	var key := "%s|%s" % [radius, length]
	if _log_mesh.has(key):
		return _log_mesh[key]
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 14
	cm.rings = 1
	_log_mesh[key] = cm
	return cm


static func box_node(parent: Node3D, size: Vector3, pos: Vector3, material: Material, radius: float = 0.06, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = rounded_box(size, radius)
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func log_node(parent: Node3D, radius: float, length: float, pos: Vector3, rot: Vector3, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = log_mesh(radius, length)
	mi.material_override = material if material else log_material(radius)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi
