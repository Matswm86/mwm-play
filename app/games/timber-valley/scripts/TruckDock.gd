class_name TvTruckDock
extends Node3D

## Export dock. A vehicle (the Valley 1 truck on the road, the Birch Bend barge on the river,
## the Maple Highlands train on its track) pulls in, loads finished goods, and pays on the way out.

enum State { AWAY, ARRIVING, LOADING, LEAVING }

## Train: loco centre to the first wagon centre, then wagon to wagon (m, along the consist).
const WAGON_FIRST := 3.8
const WAGON_STEP := 3.6

var pile: TvItemStack
var zone: TvZone
var product: String
var road_x: float
var truck: Node3D
## Cargo spaces on the vehicle: one bed for the truck and barge, one per wagon for the train.
var beds: Array[TvItemStack] = []
var bed: TvItemStack
var state: State = State.AWAY
## "truck", "barge" or "train" (Balance.EXPORTS has capacity and time away).
var vehicle: String = "truck"
var region: int = 1
var region_node: TvRegion
var _away: float = 5.0
## How far up/down the road (river) the vehicle appears and leaves.
var start_dist: float = 45.0
var _timer: float = 2.0
var _wait: float = 0.0
var _stop: Vector3
var _start: Vector3
var _end: Vector3
## Set by set_route() (the train): explicit stop/start/end points and vehicle yaw.
var _route_set: bool = false
var _yaw: float = 0.0
## Train only: wagons built so far.
var _wagons: int = 0


func setup(prod: String, road_x_global: float, vehicle_kind: String = "truck", region_id: int = 1) -> TvTruckDock:
	name = "TruckDock" if vehicle_kind == "truck" else "BargeDock"
	product = prod
	road_x = road_x_global
	vehicle = vehicle_kind
	region = region_id
	var ex: Dictionary = TvBalance.EXPORTS[vehicle]
	_away = float(ex.away)
	if vehicle == "barge":
		# Appear north of the bridge, so the barge never sails through it.
		start_dist = 22.0
		return _setup_barge(int(ex.cap))
	if vehicle == "train" or vehicle == "mtrain":
		return _setup_train()
	# v3 dock (ASSETS_LEFTOVER.md 2.10): slab top y 0.18, bumper on the road edge, two lamp posts.
	add_child(TvModels.make("truck_dock"))
	pile = TvItemStack.new().setup(product, 24, 2, 3, "dock:" + product)
	pile.position = Vector3(0.9, 0.18, 0)
	add_child(pile)
	zone = TvZone.new().setup(TvZone.Kind.DROP, pile, Vector2(2.4, 3.0), "EXPORT " + TvItems.label(product), Color(0.7, 1.0, 0.8))
	zone.position = Vector3(-1.6, 0, 0)
	add_child(zone)
	TvMeshMerge.merge(self)
	truck = Node3D.new()
	# Scale 1.0 (the Kenney truck was x1.7); cab at +Z, turned 180 deg on the road like before.
	truck.add_child(TvModels.make("truck"))
	bed = TvItemStack.new().setup(product, int(ex.cap), 2, 2)
	bed.position = Vector3(0, 1.25, -0.9)
	truck.add_child(bed)
	beds = [bed]
	return self


## Maple Highlands: a rail platform (deck top y 0.4) and a train of wagons (4 kits each).
## World turns the dock and calls set_route(); the export pile and DROP zone are dock-local.
func _setup_train() -> TvTruckDock:
	var mt := vehicle == "mtrain"
	name = "MountainTrain" if mt else name
	add_child(TvModels.make("rail_platform_alpine" if mt else "rail_platform"))
	TvMeshMerge.merge(self)
	pile = TvItemStack.new().setup(product, 24, 2, 3, "dock:" + product)
	pile.position = Vector3(0.6, 0.4, 0)
	add_child(pile)
	zone = TvZone.new().setup(TvZone.Kind.DROP, pile, Vector2(2.4, 3.0), "EXPORT " + TvItems.label(product), Color(0.7, 1.0, 0.8))
	add_child(zone)
	truck = Node3D.new()
	truck.name = "Train"
	truck.add_child(TvModels.make("mountain_loco" if mt else "train_loco"))
	add_wagons(int(TvBalance.EXPORTS[vehicle].wagons))
	return self


## Couples more wagons behind the train (Longer Train). Each wagon carries 4 kits (2 x 2).
func add_wagons(n: int) -> void:
	var per := int(TvBalance.EXPORTS[vehicle].get("per_wagon", 4))
	for i in n:
		var w := TvModels.make("mountain_wagon" if vehicle == "mtrain" else "train_wagon")
		w.position = Vector3(0, 0, WAGON_FIRST + WAGON_STEP * _wagons)
		truck.add_child(w)
		var b := TvItemStack.new().setup(product, per, 2, 2)
		b.position = Vector3(0, 0.92, 0)
		w.add_child(b)
		beds.append(b)
		_wagons += 1
	bed = beds[0]


## Explicit route (world points) and vehicle yaw; the vehicle reverses out the way it came if
## end == start.
func set_route(stop: Vector3, start: Vector3, end: Vector3, yaw: float) -> void:
	_route_set = true
	_stop = stop
	_start = start
	_end = end
	_yaw = yaw


## Birch Bend: a pier on the river bank and a barge that sails south to north.
func _setup_barge(cap: int) -> TvTruckDock:
	var landing := TvModels.make("barge_landing")
	landing.position = Vector3(0.6, 0, 0)
	add_child(landing)
	TvMeshMerge.merge(self)
	pile = TvItemStack.new().setup(product, 24, 2, 3, "dock:" + product)
	pile.position = Vector3(0.6, 0.4, 0)
	add_child(pile)
	zone = TvZone.new().setup(TvZone.Kind.DROP, pile, Vector2(2.4, 3.0), "EXPORT " + TvItems.label(product), Color(0.7, 1.0, 0.8))
	zone.position = Vector3(-2.2, 0, 0)
	add_child(zone)
	truck = Node3D.new()
	truck.add_child(TvModels.make("barge"))
	# Cargo deck x -1.1..1.1, z -2.7..1.6, top at y 0.49: 6 canoes = 3 across x 2 long.
	bed = TvItemStack.new().setup(product, cap, 3, 2)
	bed.position = Vector3(0, 0.49, -0.55)
	truck.add_child(bed)
	beds = [bed]
	return self


func _ready() -> void:
	get_parent().add_child.call_deferred(truck)
	truck.visible = false
	if _route_set:
		return
	# The barge floats on the river surface (river mesh at y 0.06).
	var y := 0.06 if vehicle == "barge" else 0.0
	_stop = Vector3(road_x, y, global_position.z)
	_start = Vector3(road_x, y, global_position.z + start_dist)
	_end = Vector3(road_x, y, global_position.z - 45.0)
	_yaw = PI if vehicle == "truck" else 0.0


func _process(delta: float) -> void:
	if not truck.is_inside_tree():
		return
	match state:
		State.AWAY:
			_timer -= delta
			if _timer <= 0.0:
				state = State.ARRIVING
				truck.visible = true
				truck.global_position = _start
				truck.rotation.y = _yaw
		State.ARRIVING:
			if _held():
				return
			truck.global_position = truck.global_position.move_toward(_stop, _speed(9.0) * delta * _ease(_stop))
			if truck.global_position.distance_to(_stop) < 0.05:
				state = State.LOADING
				_wait = 0.0
				_timer = 0.0
		State.LOADING:
			_timer -= delta
			_wait += delta
			var open_bed := _open_bed()
			if _timer <= 0.0 and not pile.is_empty() and open_bed != null:
				_timer = 0.18
				pile.transfer_to(open_bed)
				TimberSfx.play("wood", -10.0)
			var loaded := _loaded()
			var ready := open_bed == null or (loaded > 0 and pile.is_empty() and _wait > 4.0)
			if ready:
				state = State.LEAVING
				TimberSfx.play("bell", -6.0)
		State.LEAVING:
			if _held():
				return
			truck.global_position = truck.global_position.move_toward(_end, _speed(10.0) * delta)
			if truck.global_position.distance_to(_end) < 0.1:
				var value := 0
				for b in beds:
					while not b.is_empty():
						value += TimberGame.price_of(b.take_and_free())
				TimberGame.add_money(value, region)
				if region_node:
					region_node.record(value)
				TimberSfx.play("coins", -4.0)
				if TimberGame.hud:
					TimberGame.hud.toast("%s delivered: +%s" % [{"mtrain": "Mountain train"}.get(vehicle, vehicle.capitalize()), TimberGame.fmt(value)])
				state = State.AWAY
				truck.visible = false
				_timer = _away


## Trains run at Balance.TRAIN_SPEED; the truck and barge keep their speed.
func _speed(base: float) -> float:
	return TvBalance.TRAIN_SPEED if vehicle == "train" or vehicle == "mtrain" else base


## The Valley 1 truck waits at the level crossing while the player stands on it (GDD 9.1).
func _held() -> bool:
	if vehicle != "truck" or TimberGame.world == null or not TimberGame.world.has_method("crossing_holds"):
		return false
	return bool(TimberGame.world.crossing_holds(truck.global_position))


func _ease(target: Vector3) -> float:
	return clampf(truck.global_position.distance_to(target) / 6.0, 0.15, 1.0)


## First bed with room, or null when the vehicle is full.
func _open_bed() -> TvItemStack:
	for b in beds:
		if not b.is_full():
			return b
	return null


func _loaded() -> int:
	var n := 0
	for b in beds:
		n += b.count()
	return n
