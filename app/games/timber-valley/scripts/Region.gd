class_name TvRegion
extends Node3D

## One valley. Everything the valley owns (forests, machines, walkers, pads, market, belts,
## props) is a child, so the whole valley can sleep: hidden and not processed. While asleep it
## pays the average income its automation earned over its last 120 awake seconds (GDD 10.4).
## World drives wake/sleep and the ledger from its own _process, because a sleeping Region
## does not process.

var id: int = 1
var title: String = ""
## Walkable interior in world x/z.
var rect: Rect2
var awake: bool = true
## Per-second buckets of automated income over the last LEDGER_WINDOW_S awake seconds.
var _window: PackedFloat32Array = PackedFloat32Array()
var _bucket: float = 0.0
var _bucket_t: float = 0.0
var _sleep_carry: float = 0.0
var _sleep_t: float = 0.0
## Rate loaded from the save; fills the window until 120 awake seconds are measured.
var _baseline: float = 0.0


func setup(region_id: int) -> TvRegion:
	id = region_id
	var d: Dictionary = TvBalance.REGIONS[region_id]
	title = str(d.name)
	rect = d.rect
	name = "Region%d" % region_id
	_baseline = float(TimberGame.ledger.get(key(), 0.0))
	add_child(TvShadowProxy.new())
	add_child(TvStaticBatch.new())
	add_child(TvZoneMarkers.new())
	add_child(TvGroundLabels.new())
	add_child(TvTreeBatch.new())
	return self


func key() -> String:
	return "r%d" % id


## Automated income (cashier till runs, exports, rent, orders by workers) while awake.
func record(amount: int) -> void:
	if awake:
		_bucket += amount


## Saved rate, blended with what has been measured this session until the window is full.
func rate() -> float:
	var saved := float(TimberGame.ledger.get(key(), 0.0))
	var n := _window.size()
	if n == 0 or not awake:
		return saved
	var sum := 0.0
	for v in _window:
		sum += v
	var w := float(TvBalance.LEDGER_WINDOW_S)
	return (sum + _baseline * maxf(w - n, 0.0)) / w


func distance_outside(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var dx := maxf(maxf(rect.position.x - q.x, q.x - rect.end.x), 0.0)
	var dz := maxf(maxf(rect.position.y - q.y, q.y - rect.end.y), 0.0)
	return Vector2(dx, dz).length()


func contains_point(p: Vector3) -> bool:
	return rect.has_point(Vector2(p.x, p.z))


func center() -> Vector3:
	var c := rect.get_center()
	return Vector3(c.x, 0, c.y)


func set_awake(on: bool) -> void:
	if on == awake:
		return
	if not on:
		TimberGame.ledger[key()] = rate()
	awake = on
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if not on:
		_sleep_carry = 0.0
		_sleep_t = 0.0


## Called every frame by World, awake or not.
func tick(delta: float) -> void:
	if awake:
		_bucket_t += delta
		if _bucket_t >= 1.0:
			_bucket_t -= 1.0
			_window.append(_bucket)
			_bucket = 0.0
			if _window.size() > TvBalance.LEDGER_WINDOW_S:
				_window.remove_at(0)
			TimberGame.ledger[key()] = rate()
		return
	# Asleep: pay the measured average once per second, no coins and no float text.
	_sleep_t += delta
	if _sleep_t < 1.0:
		return
	_sleep_t -= 1.0
	_sleep_carry += rate()
	var whole := int(_sleep_carry)
	if whole > 0:
		_sleep_carry -= whole
		TimberGame.add_money(whole, id)
