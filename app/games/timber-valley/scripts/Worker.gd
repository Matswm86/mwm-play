class_name TvWorker
extends TvWalker

## Hired help. Lumberjacks chop a forest and deliver logs; haulers move items between two spots.
## A forklift is a hauler that serves several piles (the fullest first) and asks `route` where
## each load goes (a counter, a build site, an export pile).

enum Job { LUMBERJACK, HAULER }

var job: Job
var trees: Array = []
var source: TvItemStack
var source_pos: Vector3
var dest: TvItemStack
var dest_pos: Vector3
var home: Vector3
## Valley this worker belongs to (its Crew Coffee level applies).
var region: int = 1
## Forklift: [[ItemStack, Vector3 stand point], ...] and route(item, commit) -> [ItemStack, Vector3] or [].
var sources: Array = []
var route: Callable
var forklift: bool = false
## Routed hauler (forklift, shipwright, snowcat, porter): picks the fullest source pile whose
## items have somewhere to go, and asks `route` for each load's destination.
var routed: bool = false
## Vehicle worker (Balance.VEHICLES key: "skidder", "snowcat"), "" = on foot.
var vehicle: String = ""
## Extra carry on top of the worker capacity (shipwrights, porters).
var extra_cap: int = 0
## Lumberjack: when set, asked for [ItemStack, Vector3] each time a load heads out (Frost Peaks
## crews take their logs to the kiln with the most room).
var pick_dest: Callable
var _target_tree: TvChopTree
var _delivering: bool = false
var _timer: float = 0.0
var _wait: float = 0.0
## Routed hauler: the pile the current load came from (it goes back there if no drop wants it).
var _came_from: TvItemStack
var _came_from_pos: Vector3


func as_lumberjack(look: String, forest: Array, d: TvItemStack, d_pos: Vector3, home_pos: Vector3) -> TvWorker:
	job = Job.LUMBERJACK
	trees = forest
	dest = d
	dest_pos = d_pos
	home = home_pos
	init_walker(look)
	position = home_pos
	return self


func as_hauler(look: String, s: TvItemStack, s_pos: Vector3, d: TvItemStack, d_pos: Vector3) -> TvWorker:
	job = Job.HAULER
	source = s
	source_pos = s_pos
	dest = d
	dest_pos = d_pos
	home = s_pos
	init_walker(look)
	position = s_pos + Vector3(0.5, 0, 0.8)
	return self


## Forklift hauler (Maple Highlands): its own model, speed and load (Balance.FORKLIFT).
func as_forklift(rt: Callable, home_pos: Vector3, model_key: String = "forklift") -> TvWorker:
	job = Job.HAULER
	forklift = true
	routed = true
	route = rt
	home = home_pos
	init_walker("forklift" if model_key == "forklift" else "vehicle:" + model_key)
	position = home_pos
	return self


## Routed hauler on foot (shipwright, porter) or in a vehicle (snowcat).
func as_router(look: String, rt: Callable, home_pos: Vector3, vehicle_kind: String = "", extra: int = 0) -> TvWorker:
	job = Job.HAULER
	routed = true
	route = rt
	home = home_pos
	vehicle = vehicle_kind
	extra_cap = extra
	init_walker(look if vehicle_kind == "" else "vehicle:" + str(TvBalance.VEHICLES[vehicle_kind].model))
	position = home_pos
	return self


## Lumberjack in a vehicle (log skidder): its own model, speed and load.
func as_vehicle_jack(vehicle_kind: String, forest: Array, d: TvItemStack, d_pos: Vector3, home_pos: Vector3) -> TvWorker:
	vehicle = vehicle_kind
	job = Job.LUMBERJACK
	trees = forest
	dest = d
	dest_pos = d_pos
	home = home_pos
	init_walker("vehicle:" + str(TvBalance.VEHICLES[vehicle_kind].model))
	position = home_pos
	return self


func add_source(s: TvItemStack, s_pos: Vector3) -> void:
	sources.append([s, s_pos])


func _process(delta: float) -> void:
	walk_speed = TimberGame.worker_speed(region)
	cap = TimberGame.worker_capacity(region)
	if forklift:
		var fk: Dictionary = TvBalance.FORKLIFT_BY_REGION.get(region, TvBalance.FORKLIFT)
		walk_speed *= float(fk.speed) / 3.2
		cap += int(fk.cap) - 6
		if not stack.is_empty():
			var d: Dictionary = TvItems.def(stack.top_type())
			var layers := maxi(int(float(fk.max_load_h) / float(d.layer)), 1)
			cap = mini(cap, layers * stack.cols * stack.rows)
	elif vehicle != "":
		var vd: Dictionary = TvBalance.VEHICLES[vehicle]
		walk_speed *= float(vd.speed) / 3.2
		cap += int(vd.cap) - 6
	cap += extra_cap
	# Thin goods (veneer) carry by height: x Balance.CARRY_MULT, 1 for every other item.
	var carried := stack.top_type()
	if carried == "" and source != null:
		carried = source.item_type
	cap *= int(TvBalance.CARRY_MULT.get(carried, 1))
	if job == Job.LUMBERJACK:
		_lumberjack(delta)
	else:
		_hauler(delta)
	animate()


func _deliver(delta: float) -> void:
	if step_to(dest_pos, delta, 0.3):
		_timer -= delta
		if _timer <= 0.0:
			_timer = 0.09
			if not stack.transfer_to(dest):
				if stack.is_empty():
					_delivering = false
				elif routed and dest == _came_from:
					# Back at a full source pile: it takes the load anyway (it only waits longer).
					dest.push(stack.pop())
				elif routed:
					# The drop filled up on the way (a build site finished): ask for another one.
					var r: Array = route.call(stack.top_type(), true)
					if not r.is_empty() and r[0] != dest:
						dest = r[0]
						dest_pos = r[1]
					elif r.is_empty() and _came_from != null and _came_from != dest and _came_from.can_accept(stack.top_type()):
						# Nowhere wants the load any more: take it back to the pile it came from.
						dest = _came_from
						dest_pos = _came_from_pos
			else:
				TimberSfx.play("wood", -16.0)
				# Thin goods (veneer) unload a bundle per tick, as they carry (1 for other items).
				for k in int(TvBalance.CARRY_MULT.get(dest.top_type(), 1)) - 1:
					if not stack.transfer_to(dest):
						break
			if stack.is_empty():
				_delivering = false


func _lumberjack(delta: float) -> void:
	if _delivering:
		_deliver(delta)
		return
	if stack.count() >= cap:
		_release_tree()
		_head_out()
		return
	if _target_tree == null or not _target_tree.is_ready():
		_release_tree()
		_target_tree = _find_tree()
		if _target_tree == null:
			if not stack.is_empty():
				_head_out()
			else:
				step_to(home, delta, 0.3)
			return
		_target_tree.reserved_by = self
	var tp := _target_tree.global_position
	var to_me := global_position - tp
	to_me.y = 0
	var stand := tp + (to_me.normalized() if to_me.length() > 0.01 else Vector3.BACK) * 0.9
	if step_to(stand, delta, 0.2):
		face(tp - global_position, delta)
		_target_tree._on_carrier(self, delta)


func _head_out() -> void:
	_delivering = true
	if pick_dest.is_valid():
		var r: Array = pick_dest.call()
		if not r.is_empty():
			dest = r[0]
			dest_pos = r[1]


func _find_tree() -> TvChopTree:
	var best: TvChopTree = null
	var best_d := INF
	for t in trees:
		var tree: TvChopTree = t
		if not tree.is_visible_in_tree() or not tree.is_ready():
			continue
		if tree.reserved_by != null and tree.reserved_by != self and is_instance_valid(tree.reserved_by):
			continue
		var d := tree.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = tree
	return best


func _release_tree() -> void:
	if _target_tree != null and _target_tree.reserved_by == self:
		_target_tree.reserved_by = null
	_target_tree = null


func _hauler(delta: float) -> void:
	if _delivering:
		_deliver(delta)
		return
	if routed and not _pick_source():
		step_to(home, delta, 0.3)
		return
	if step_to(source_pos, delta, 0.3):
		_timer -= delta
		if _timer > 0.0:
			return
		_timer = 0.09
		var lim := cap
		if routed and region >= 4 and not source.is_empty():
			# Load no more than a build site or cargo line still needs (Redwood Coast on; the
			# Maple Highlands forklift keeps its measured behaviour).
			var r0: Array = route.call(source.top_type(), false)
			if not r0.is_empty():
				var d0: TvItemStack = r0[0]
				if d0.get_parent() is TvBuildSite or d0.get_parent() is TvOrderBoard:
					lim = mini(cap, maxi(d0.capacity - d0.count(), 1))
		if stack.count() < lim and not source.is_empty() and stack.can_accept(source.top_type()):
			source.transfer_to(stack)
			# Thin goods (veneer) load a bundle per tick, as they carry (1 for other items).
			for k in int(TvBalance.CARRY_MULT.get(stack.top_type(), 1)) - 1:
				if stack.count() >= lim or not source.transfer_to(stack):
					break
			TimberSfx.play("place", -16.0)
			_wait = 0.0
		else:
			_wait += 0.09
		# Head off when full, or when holding something and the pile has been empty a moment.
		if stack.count() >= lim or (not stack.is_empty() and _wait > 1.2):
			if routed:
				var r: Array = route.call(stack.top_type(), true)
				if r.is_empty():
					return
				dest = r[0]
				dest_pos = r[1]
				_came_from = source
				_came_from_pos = source_pos
				source = null
			_delivering = true
			_wait = 0.0


## Forklift: keep the current pile while loading; otherwise take the fullest pile whose items
## have somewhere to go. False when there is nothing to move.
func _pick_source() -> bool:
	if source != null and (not stack.is_empty() or not source.is_empty()):
		return true
	source = null
	var best := 0
	for sp in sources:
		var s: TvItemStack = sp[0]
		if s.is_empty():
			continue
		var r: Array = route.call(s.item_type, false)
		if r.is_empty():
			continue
		# A pile whose items a build site is waiting for counts as fuller, so belts that keep a
		# pile low do not starve the houses of that item.
		var score := s.count() + (12 if (r[0] as Node).get_parent() is TvBuildSite else 0)
		# A cargo ship waiting for this item comes first (Redwood Coast orders need no player).
		if (r[0] as Node).get_parent() is TvOrderBoard:
			score += 60
		# Maple Highlands on (Redwood Coast before 2026-10-04): the emptier a site's slot for this
		# item, the sooner it is served, so three masts (or a few kits and beams for a house) are
		# not left waiting behind piles of timber (floorboards).
		var site := (r[0] as Node).get_parent() as TvBuildSite
		var d: TvItemStack = r[0]
		if site and region >= 3:
			score += int(48.0 * float(d.capacity - d.count()) / maxf(float(site.goods[s.item_type]), 1.0))
		elif region >= 5:
			# Frost Peaks snowcat: an empty machine input or counter waits less (the sled shop is
			# otherwise starved of dry lumber by the ski belts).
			score += int(30.0 * float(maxi(d.capacity - d.count(), 0)) / maxf(float(d.capacity), 1.0))
		if score > best:
			best = score
			source = s
			source_pos = sp[1]
	return source != null
