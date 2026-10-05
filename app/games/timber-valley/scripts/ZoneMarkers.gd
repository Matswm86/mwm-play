class_name TvZoneMarkers
extends MultiMeshInstance3D

## Draw-call reduction: every zone ground marker (DROP / PICK / CASH squares) in one valley is
## drawn by this one MultiMesh instead of one transparent quad each. Zones register on entering
## the tree; each frame the visible ones are copied in (position, size, colour, progress).

const SHADER := preload("res://games/timber-valley/scripts/zone_markers_mm.gdshader")

var _zones: Array[TvZone] = []


func _init() -> void:
	name = "ZoneMarkers"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	mm.mesh = pm
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The valley's ZoneMarkers above `n`, or null.
static func find_for(n: Node) -> TvZoneMarkers:
	var p: Node = n.get_parent()
	while p and not (p is TvRegion):
		p = p.get_parent()
	return (p.get_node_or_null("ZoneMarkers") as TvZoneMarkers) if p else null


func add(z: TvZone) -> void:
	if not _zones.has(z):
		_zones.append(z)


func remove(z: TvZone) -> void:
	_zones.erase(z)


func _process(_delta: float) -> void:
	var inv := global_transform.affine_inverse()
	var mm := multimesh
	if mm.instance_count < _zones.size():
		mm.instance_count = _zones.size() + 8
	var n := 0
	var box := AABB()
	for z in _zones:
		if not z.marker.is_visible_in_tree():
			continue
		var xf := inv * z.marker.global_transform
		xf.basis = xf.basis * Basis.from_scale(Vector3(z.half.x * 2.0, 1.0, z.half.y * 2.0))
		mm.set_instance_transform(n, xf)
		mm.set_instance_color(n, z.marker_color)
		mm.set_instance_custom_data(n, Color(z.half.x * 2.0, z.half.y * 2.0, z.progress, z.active))
		var b := AABB(xf.origin - Vector3(z.half.x, 0.1, z.half.y), Vector3(z.half.x * 2.0, 0.2, z.half.y * 2.0))
		box = b if n == 0 else box.merge(b)
		n += 1
	mm.visible_instance_count = n
	if n > 0:
		mm.custom_aabb = box.grow(1.0)
