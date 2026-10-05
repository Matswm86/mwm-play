extends Node3D
class_name TeTile3D

# A single 3D tile: rounded-box body + icon quad on the top face.
# Game state (icon_id, layer, blocked, in_tray) mirrors the original 2D Tile.
# Blocking detection still runs in the original 130 px board space via
# `board_position`, so the validated 2D level logic carries over unchanged.

const TILE_PX: float = 130.0  # level JSON grid unit
const SIZE: Vector3 = Vector3(0.94, 0.40, 0.94)  # world extents
const CORNER: float = 0.11
const ICON_SIZE: float = 0.84

var icon_id: int = 0:
	set(v):
		icon_id = v
		_apply_materials()
var board_position: Vector2 = Vector2.ZERO  # original px-space position
var layer: int = 0
var blocked: bool = true
var in_tray: bool = false

var _body: MeshInstance3D
var _icon: MeshInstance3D
var _shake_tween: Tween

# Shared resources, installed once by Board3D before any tile is created.
static var shared_mesh: ArrayMesh
static var body_mat: StandardMaterial3D
static var body_mat_blocked: StandardMaterial3D
static var icon_mats: Array = []  # per icon id
static var icon_mats_blocked: Array = []


static func install_shared(icon_textures: Array) -> void:
	shared_mesh = TeRoundedBox.build(SIZE, CORNER, 8)
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(1.0, 0.985, 0.945)
	body_mat.roughness = 0.42
	body_mat_blocked = body_mat.duplicate()
	body_mat_blocked.albedo_color = Color(0.62, 0.62, 0.70)
	icon_mats.clear()
	icon_mats_blocked.clear()
	for tex in icon_textures:
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.9
		m.metallic_specular = 0.0
		icon_mats.append(m)
		var mb: StandardMaterial3D = m.duplicate()
		mb.albedo_color = Color(0.52, 0.52, 0.58)
		icon_mats_blocked.append(mb)


func _ready() -> void:
	_body = MeshInstance3D.new()
	_body.mesh = shared_mesh
	add_child(_body)
	_icon = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.mesh = quad
	_icon.position = Vector3(0, SIZE.y * 0.5 + 0.004, 0)
	_icon.rotation_degrees = Vector3(-90, 0, 0)
	_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_icon)
	_apply_materials()


func _apply_materials() -> void:
	if _body == null:
		return
	_body.material_override = body_mat_blocked if (blocked and not in_tray) else body_mat
	var mats: Array = icon_mats_blocked if (blocked and not in_tray) else icon_mats
	_icon.material_override = mats[icon_id]


# px-space AABB used by the (unchanged) blocking algorithm.
func bounds() -> Rect2:
	var half: float = TILE_PX * 0.5
	return Rect2(board_position - Vector2(half, half), Vector2(TILE_PX, TILE_PX))


func set_blocked(b: bool) -> void:
	if blocked != b:
		blocked = b
		_apply_materials()


# World-space AABB for ray picking.
func world_aabb() -> AABB:
	return AABB(global_position - SIZE * 0.5, SIZE)


# Brief rotation wiggle when the player taps a blocked tile.
func shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		return
	_shake_tween = create_tween()
	for offs in [0.07, -0.06, 0.04, -0.02, 0.0]:
		_shake_tween.tween_property(self, "rotation:z", offs, 0.05)
