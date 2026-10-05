extends Node3D
class_name TeTray3D

# 7-slot tray at the near edge of the table. Matching logic is unchanged
# from the 2D version: insertions sort by icon_id so groups stay adjacent,
# and resolve_matches() returns {tiles, tween} with the caller owning
# queue_free (single-owner rule — see the 2026-05-01 double-free lesson).

const SLOTS: int = 7
const SLOT_PITCH: float = 0.96
const TRAY_Z: float = 3.30
const TILE_REST_Y: float = 0.34  # tray base top (0.14) + half tile height
const SLIDE_TIME: float = 0.18
const FLY_TIME: float = 0.32
const CLEAR_TIME: float = 0.24
const ARC_HEIGHT: float = 1.6

var tiles: Array[TeTile3D] = []  # tray order, sorted by icon_id groups


func slot_position(i: int) -> Vector3:
	var x: float = (float(i) - float(SLOTS - 1) * 0.5) * SLOT_PITCH
	return Vector3(x, TILE_REST_Y, TRAY_Z)


# Fly a tile into its sorted slot along an arc, with a tumble and a landing
# squash. Returns the Tween so the caller can await it.
func add_tile(t: TeTile3D) -> Tween:
	t.in_tray = true
	var insert_at: int = tiles.size()
	for i in tiles.size():
		if tiles[i].icon_id > t.icon_id:
			insert_at = i
			break
	tiles.insert(insert_at, t)
	var tw: Tween = create_tween().set_parallel(true)
	for i in tiles.size():
		var target: Vector3 = slot_position(i)
		if tiles[i] == t:
			_tween_arc(tw, t, target)
		else:
			(
				tw
				. tween_property(tiles[i], "position", target, SLIDE_TIME)
				. set_trans(Tween.TRANS_QUAD)
				. set_ease(Tween.EASE_OUT)
			)
	return tw


func _tween_arc(tw: Tween, t: TeTile3D, target: Vector3) -> void:
	var start: Vector3 = t.position
	(
		tw
		. tween_method(
			func(s: float) -> void:
				var p: Vector3 = start.lerp(target, s)
				p.y += ARC_HEIGHT * 4.0 * s * (1.0 - s)
				t.position = p,
			0.0,
			1.0,
			FLY_TIME
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	# Gentle forward tumble that settles flat on landing.
	t.rotation.x = -0.55
	tw.tween_property(t, "rotation:x", 0.0, FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	# Landing squash, chained after the flight. Tracked on the tile so a
	# match that resolves immediately can kill it (it animates scale too).
	var squash: Tween = create_tween()
	squash.tween_interval(FLY_TIME)
	squash.tween_property(t, "scale", Vector3(1.12, 0.78, 1.12), 0.07).set_trans(Tween.TRANS_QUAD)
	squash.tween_property(t, "scale", Vector3.ONE, 0.10).set_trans(Tween.TRANS_QUAD)
	t.set_meta("squash_tween", squash)


# If the tray holds a triple: removes those 3 tiles from the tray list and
# returns {tiles, tween} — tiles slam together, pop and shrink while the
# rest reflow. Caller frees. Empty dict when no triple.
func resolve_matches() -> Dictionary:
	var counts: Dictionary = {}
	for t in tiles:
		counts[t.icon_id] = int(counts.get(t.icon_id, 0)) + 1
	var match_icon: int = -1
	for k in counts.keys():
		if int(counts[k]) >= 3:
			match_icon = int(k)
			break
	if match_icon < 0:
		return {}
	var to_remove: Array[TeTile3D] = []
	for t in tiles:
		if t.icon_id == match_icon and to_remove.size() < 3:
			to_remove.append(t)
	for t in to_remove:
		tiles.erase(t)
		if t.has_meta("squash_tween"):
			var sq: Tween = t.get_meta("squash_tween")
			if sq != null and sq.is_valid():
				sq.kill()
	var centroid: Vector3 = Vector3.ZERO
	for t in to_remove:
		centroid += t.position
	centroid /= float(to_remove.size())
	centroid.y += 0.35
	var tw: Tween = create_tween().set_parallel(true)
	for t in to_remove:
		tw.tween_property(t, "position", centroid, CLEAR_TIME).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_IN
		)
		(
			tw
			. tween_property(t, "scale", Vector3(0.05, 0.05, 0.05), CLEAR_TIME)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN)
		)
	for i in tiles.size():
		(
			tw
			. tween_property(tiles[i], "position", slot_position(i), SLIDE_TIME)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	return {"tiles": to_remove, "tween": tw, "centroid": centroid, "icon": match_icon}


# Remove one tile (without freeing) and reflow. Used by Undo and Clear 3.
func remove_tile(t: TeTile3D) -> Tween:
	tiles.erase(t)
	var tw: Tween = create_tween().set_parallel(true)
	if tiles.is_empty():
		tw.tween_interval(0.01)  # keep the tween valid when nothing reflows
	for i in tiles.size():
		(
			tw
			. tween_property(tiles[i], "position", slot_position(i), SLIDE_TIME)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	return tw


func is_full() -> bool:
	return tiles.size() >= SLOTS


func is_empty() -> bool:
	return tiles.is_empty()


func size() -> int:
	return tiles.size()
