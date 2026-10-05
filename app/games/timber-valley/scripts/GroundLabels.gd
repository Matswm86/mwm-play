class_name TvGroundLabels
extends MultiMeshInstance3D

## Draw-call reduction: the static text on the ground next to zones ("LOGS", "PLANKS", "CASH",
## "UPGRADES") is drawn for the whole valley by this one MultiMesh instead of one Label3D each.
## The texts are rendered once into an atlas by 2D Labels with the same font, size, colours and
## outline, then shown on quads the size the Label3D would have (1 atlas pixel = pixel_size m).
## A Label3D stays visible until its text is in the atlas, and stays the fallback without a
## renderer (headless tests). New texts (unlocks) re-render the atlas.

const SHADER := preload("res://games/timber-valley/scripts/ground_labels.gdshader")
const ATLAS_W := 1024
const PAD := 4

var _labels: Array[Label3D] = []
## text key -> Rect2i in atlas pixels.
var _rects: Dictionary = {}
var _atlas_h: int = 0
var _baking: bool = false
var _dirty: bool = false
var _mat: ShaderMaterial


func _init() -> void:
	name = "GroundLabels"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	multimesh = mm
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The valley's GroundLabels above `n`, or null.
static func find_for(n: Node) -> TvGroundLabels:
	var p: Node = n.get_parent()
	while p and not (p is TvRegion):
		p = p.get_parent()
	return (p.get_node_or_null("GroundLabels") as TvGroundLabels) if p else null


static func key_of(l: Label3D) -> String:
	return "%s|%d|%d|%s|%s" % [l.text, l.font_size, l.outline_size, l.modulate.to_html(), l.outline_modulate.to_html()]


func add(l: Label3D) -> void:
	if DisplayServer.get_name() == "headless" or _labels.has(l):
		return
	_labels.append(l)
	if _rects.has(key_of(l)):
		l.visible = false
	else:
		_dirty = true


func remove(l: Label3D) -> void:
	_labels.erase(l)


func _process(_delta: float) -> void:
	# Labels freed with their node (a handcar stop rebuilt for a new valley) drop out here.
	for i in range(_labels.size() - 1, -1, -1):
		if not is_instance_valid(_labels[i]):
			_labels.remove_at(i)
	if _dirty and not _baking:
		_bake()
	var inv := global_transform.affine_inverse()
	var mm := multimesh
	if mm.instance_count < _labels.size():
		mm.instance_count = _labels.size() + 8
	var n := 0
	var box := AABB()
	var size := Vector2(ATLAS_W, maxi(_atlas_h, 1))
	for l in _labels:
		var r: Variant = _rects.get(key_of(l))
		if r == null or l.visible or not (l.get_parent() as Node3D).is_visible_in_tree():
			continue
		var rect: Rect2i = r
		var xf := inv * l.global_transform
		var w := rect.size.x * l.pixel_size
		var h := rect.size.y * l.pixel_size
		xf.basis = xf.basis * Basis.from_scale(Vector3(w, h, 1.0))
		mm.set_instance_transform(n, xf)
		mm.set_instance_custom_data(n, Color(rect.position.x / size.x, rect.position.y / size.y, rect.size.x / size.x, rect.size.y / size.y))
		var b := AABB(xf.origin - Vector3(w, w, w) * 0.5, Vector3(w, w, w))
		box = b if n == 0 else box.merge(b)
		n += 1
	mm.visible_instance_count = n
	if n > 0:
		mm.custom_aabb = box.grow(0.5)


## Renders every known text into a fresh atlas (shelf packing), then swaps it in.
func _bake() -> void:
	_baking = true
	_dirty = false
	var specs := {}
	for l in _labels:
		specs[key_of(l)] = l
	var rects := {}
	var x := 0
	var y := 0
	var row_h := 0
	for k in specs:
		var l: Label3D = specs[k]
		var sz := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size)
		var w := int(ceil(sz.x)) + l.outline_size * 2 + PAD * 2
		var h := int(ceil(l.font.get_height(l.font_size))) + l.outline_size * 2 + PAD * 2
		if x + w > ATLAS_W:
			x = 0
			y += row_h
			row_h = 0
		rects[k] = Rect2i(x, y, w, h)
		x += w
		row_h = maxi(row_h, h)
	var height := y + row_h
	if height <= 0:
		_baking = false
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(ATLAS_W, height)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for k in specs:
		var l: Label3D = specs[k]
		var r: Rect2i = rects[k]
		var t := Label.new()
		t.text = l.text
		var ls := LabelSettings.new()
		ls.font = l.font
		ls.font_size = l.font_size
		ls.font_color = l.modulate
		ls.outline_size = l.outline_size
		ls.outline_color = l.outline_modulate
		t.label_settings = ls
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.position = Vector2(r.position)
		t.size = Vector2(r.size)
		vp.add_child(t)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		_baking = false
		return
	img.generate_mipmaps()
	_mat.set_shader_parameter("atlas", ImageTexture.create_from_image(img))
	_rects = rects
	_atlas_h = height
	for l in _labels:
		if is_instance_valid(l) and _rects.has(key_of(l)):
			l.visible = false
	_baking = false
