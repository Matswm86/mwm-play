extends Node3D
class_name TeBoard3D

# Owns the Tile3D collection. The blocking algorithm is byte-for-byte the
# original 2D one (px-space AABB overlap with a 6 px inset) so all 30
# shipped levels behave identically. Touch picking is a camera ray against
# tile AABBs — nearest hit wins, which naturally selects the visually
# topmost tile.

signal tile_tapped(tile)
signal blocked_tapped(tile)

const OVERLAP_INSET: float = 6.0  # px — tiles must overlap by more than this
## A touch that misses every tile takes the nearest free tile whose centre is
## this close on screen, so a lone tile has a 200 px wide touch circle (12.7 mm
## at 400 dpi) although it is drawn about 100 px wide.
const SNAP_RADIUS_PX: float = 100.0
## Touch-down feedback: the touched tile sinks to this scale until release.
const PRESS_SCALE: float = 0.9

# px-space -> world-space mapping. Levels live in a 1080x1920 layout with
# board content at x 120..960, y 540..1250.
const PX_CENTER: Vector2 = Vector2(540.0, 895.0)
const WORLD_Z_OFFSET: float = -0.85  # shift board up-screen, away from tray

var tiles: Array[TeTile3D] = []
var input_locked: bool = false
var _pressed_tile: TeTile3D = null
var _press_index: int = -1

@onready var camera: Camera3D = get_viewport().get_camera_3d()


static func px_to_world(px: Vector2, layer: int) -> Vector3:
	var x: float = (px.x - PX_CENTER.x) / TeTile3D.TILE_PX
	var z: float = (px.y - PX_CENTER.y) / TeTile3D.TILE_PX + WORLD_Z_OFFSET
	var y: float = TeTile3D.SIZE.y * (0.5 + float(layer))
	return Vector3(x, y, z)


func clear_board() -> void:
	for t in tiles:
		t.queue_free()
	tiles.clear()


# tile_data: Array of {icon: int, x: float, y: float, layer: int}
func load_tiles(tile_data: Array) -> void:
	clear_board()
	for d in tile_data:
		var t := TeTile3D.new()
		t.layer = int(d.get("layer", 0))
		t.board_position = Vector2(float(d["x"]), float(d["y"]))
		t.position = px_to_world(t.board_position, t.layer)
		add_child(t)
		t.icon_id = int(d["icon"])
		tiles.append(t)
	recompute_blocking()


func remaining_count() -> int:
	var n: int = 0
	for t in tiles:
		if not t.in_tray:
			n += 1
	return n


func recompute_blocking() -> void:
	for t in tiles:
		if t.in_tray:
			continue
		t.set_blocked(_is_blocked(t))


func _is_blocked(t: TeTile3D) -> bool:
	var b1: Rect2 = t.bounds().grow(-OVERLAP_INSET)
	for o in tiles:
		if o == t or o.in_tray:
			continue
		if o.layer <= t.layer:
			continue
		if b1.intersects(o.bounds()):
			return true
	return false


# Touch-down only gives feedback (the tile sinks, a blocked tile wiggles). The
# move happens on release, and only if the finger lifts over the same tile, so
# a resting palm or a finger sliding off does nothing. Mouse clicks arrive as
# touches through emulate_touch_from_mouse.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		if _pressed_tile != null or input_locked:
			return
		var hit: TeTile3D = pick_tile_for_touch(touch.position)
		if hit == null:
			return
		if hit.blocked:
			emit_signal("blocked_tapped", hit)
			return
		_pressed_tile = hit
		_press_index = touch.index
		hit.scale = Vector3.ONE * PRESS_SCALE
		return
	if touch.index != _press_index or _pressed_tile == null:
		return
	var t: TeTile3D = _pressed_tile
	_pressed_tile = null
	_press_index = -1
	if not is_instance_valid(t):
		return
	t.scale = Vector3.ONE
	if input_locked or t.in_tray or t.blocked:
		return
	if pick_tile_for_touch(touch.position) == t:
		emit_signal("tile_tapped", t)


# The tile a touch at screen_pos means: the tile under the finger, else the
# nearest free tile within SNAP_RADIUS_PX of it.
func pick_tile_for_touch(screen_pos: Vector2) -> TeTile3D:
	var hit: TeTile3D = pick_tile(screen_pos)
	if hit != null or camera == null:
		return hit
	var best: TeTile3D = null
	var best_d: float = SNAP_RADIUS_PX
	for t in tiles:
		if t.in_tray or t.blocked:
			continue
		var d: float = camera.unproject_position(t.global_position).distance_to(screen_pos)
		if d <= best_d:
			best_d = d
			best = t
	return best


# Nearest tile whose world AABB the camera ray through screen_pos intersects.
func pick_tile(screen_pos: Vector2) -> TeTile3D:
	if camera == null:
		camera = get_viewport().get_camera_3d()
		if camera == null:
			return null
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: TeTile3D = null
	var best_t: float = INF
	for t in tiles:
		if t.in_tray:
			continue
		var d: float = _ray_aabb(origin, dir, t.world_aabb())
		if d >= 0.0 and d < best_t:
			best_t = d
			hit = t
	return hit


# Slab-method ray/AABB intersection. Returns entry distance, or -1 on miss.
static func _ray_aabb(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var t_min: float = -INF
	var t_max: float = INF
	for axis in 3:
		var o: float = origin[axis]
		var d: float = dir[axis]
		var lo: float = box.position[axis]
		var hi: float = box.position[axis] + box.size[axis]
		if absf(d) < 1e-8:
			if o < lo or o > hi:
				return -1.0
			continue
		var t1: float = (lo - o) / d
		var t2: float = (hi - o) / d
		if t1 > t2:
			var tmp: float = t1
			t1 = t2
			t2 = tmp
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return -1.0
	return maxf(t_min, 0.0)
