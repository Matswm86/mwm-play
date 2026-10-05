class_name TvShop
extends Node3D

## Market by the road: counters for each product, a till with a coin pile, and shoppers.

const SHELF_X := 0.0
const PLAYER_SIDE := -1.7
const CUSTOMER_SIDE := 1.5

var shelves: Dictionary = {}
var queues: Dictionary = {"till": []}
var coins: TvItemStack
var coin_zone: TvZone
var coin_value: int = 0
var has_cashier: bool = false
var cashier: TvWalker
var road_x: float = 7.0
var till_z: float = -5.2
## Valley this market belongs to (Local Fame, ledger, earnings).
var region: int = 1
var region_node: TvRegion
## 1 = player side west, shoppers east (Valley 1). -1 mirrors it (Birch Bend, shoppers from the west).
var side: float = 1.0
## Unlock that boosts shoppers x1.7 ("" = none).
var sign_unlock: String = "roadsign"
var customer_cap: int = TvBalance.CUSTOMERS_PER_REGION
## Extra shopper rate (Maple Highlands: +10% per finished village house).
var spawn_bonus: float = 1.0
## Optional shopper route (local spawn/exit points plus a world waypoint on the lane).
var spawn_local: Vector3 = Vector3.INF
var exit_local: Vector3 = Vector3.INF
var lane_via: Vector3 = Vector3.INF
var _spawn_timer: float = 0.5
var _cashier_timer: float = 0.0
## Shoppers out of this market, and item type -> MultiMeshInstance3D drawing what they carry.
var _customers: Array[TvCustomer] = []
var _carry_mm: Dictionary = {}


func setup(region_id: int = 1, mirror: float = 1.0) -> TvShop:
	name = "Shop" if region_id == 1 else "Shop%d" % region_id
	region = region_id
	side = mirror
	_build_till()
	_build_canopy()
	# Canopy and till bake into a few meshes (shelves bake when they open).
	TvMeshMerge.merge(self)
	return self


## Shade cloth over the customer side of the market (v3 canopy, ASSETS_LEFTOVER.md 2.9):
## 10.1 m long, centred between the first counter and the till; teal in Maple Highlands.
func _build_canopy() -> void:
	var c: Node3D = TvModels.make(str({3: "market_canopy_teal", 4: "market_canopy_navy", 5: "market_canopy_alpine"}.get(region, "market_canopy")))
	c.position = Vector3(0, 0, (3.9 + till_z - 1.0) * 0.5)
	# 180 deg = the mirrored layout (cloth on the other side).
	c.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
	add_child(c)


func _sign(root: Node3D, product: String) -> void:
	var l := Label3D.new()
	l.font = TvFx.font()
	l.text = "%s  %s" % [TvItems.label(product), TimberGame.fmt(TimberGame.price_of(product))]
	l.font_size = 44
	l.outline_size = 12
	l.modulate = Color(1, 0.97, 0.88)
	l.outline_modulate = Color(0.3, 0.18, 0.08)
	l.pixel_size = 0.006
	l.rotation_degrees = Vector3(-55, 0, 0)
	# Mirrored markets push the sign toward the player side so the canopy does not cover it.
	l.position = Vector3(-0.2 if side > 0.0 else 0.6, 1.9, 0.9)
	l.name = "PriceSign"
	root.add_child(l)
	# Product icon on the price tag, left of the text (job 2, Models.ICONS 128 px). A sibling of the
	# sign, not a child: the sign text is drawn by the valley's GroundLabels and its node is hidden.
	var tex := TvModels.shop_icon(product)
	var icon: Sprite3D = null
	if tex:
		icon = Sprite3D.new()
		icon.texture = tex
		icon.pixel_size = 0.0036
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(icon)
		_place_sign_icon(l, icon)
	TimberGame.upgraded.connect(func(id: String, _lv: int) -> void:
		if id == "prices" or id == "r%d_fame" % region:
			var gl := TvGroundLabels.find_for(l) if l.is_inside_tree() else null
			if gl:
				gl.remove(l)
				l.visible = true
			l.text = "%s  %s" % [TvItems.label(product), TimberGame.fmt(TimberGame.price_of(product))]
			if gl and (l.get_parent() as Node3D).visible:
				gl.add(l)
			if icon:
				_place_sign_icon(l, icon))


## Icon just left of the sign text, vertically centred on it.
func _place_sign_icon(l: Label3D, icon: Sprite3D) -> void:
	var w := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
	icon.transform = l.transform * Transform3D(Basis(), Vector3(-w * 0.5 - 0.3, 0.0, 0.0))


func _blocker(size: Vector3, pos: Vector3, parent: Node3D) -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position = pos
	sb.add_child(col)
	parent.add_child(sb)


func _build_till() -> void:
	var root := Node3D.new()
	root.position = Vector3(SHELF_X, 0, till_z)
	add_child(root)
	# Counter with the cash chest on top (symmetric, so mirrored markets need no flip).
	root.add_child(TvModels.make("shop_till"))
	_blocker(Vector3(1.3, 1.5, 1.6), Vector3(0, 0.75, 0), root)
	coins = TvItemStack.new().setup("coin", 400, 3, 3)
	coins.position = Vector3(SHELF_X + (PLAYER_SIDE - 0.2) * side, 0, till_z)
	add_child(coins)
	coin_zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.0, 2.2), "CASH", Color(1.0, 0.85, 0.3))
	coin_zone.position = coins.position
	coin_zone.interval = 0.0
	coin_zone.on_carrier = _collect
	add_child(coin_zone)


func add_shelf(product: String, z: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(SHELF_X, 0, z)
	add_child(root)
	# v3 counter: top at y 0.62, the ItemStack height.
	root.add_child(TvModels.make("shop_counter"))
	_blocker(Vector3(1.2, 1.5, 2.0), Vector3(0, 0.75, 0), root)
	_sign(root, product)
	var st := TvItemStack.new().setup(product, 30, 1, 2, "shelf:" + product)
	st.position = Vector3(0, 0.62, 0)
	root.add_child(st)
	var zone := TvZone.new().setup(
		TvZone.Kind.DROP, st, Vector2(2.0, 2.2), TvItems.label(product), Color(1, 1, 1)
	)
	zone.position = Vector3(PLAYER_SIDE * side, 0, 0)
	root.add_child(zone)
	shelves[product] = {"root": root, "stack": st, "zone": zone, "z": z}
	queues[product] = []
	root.visible = false


func open_shelf(product: String, animate: bool) -> void:
	var s: Dictionary = shelves[product]
	var root: Node3D = s.root
	root.visible = true
	# The price sign joins the valley's GroundLabels atlas (one draw for every static sign).
	var sign_l := root.get_node_or_null("PriceSign") as Label3D
	var gl := TvGroundLabels.find_for(sign_l) if sign_l and sign_l.is_inside_tree() else null
	if gl:
		gl.add(sign_l)
	TvMeshMerge.merge(root)
	# Counters share one texture: the valley's StaticBatch draws them together.
	TvStaticBatch.register(root)
	if animate:
		root.scale = Vector3.ONE * 0.05
		var tw := create_tween()
		tw.tween_property(root, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_open(product: String) -> bool:
	return shelves.has(product) and (shelves[product].root as Node3D).visible


func shelf(product: String) -> TvItemStack:
	return shelves[product].stack


func shelf_zone(product: String) -> TvZone:
	return shelves[product].zone


func shelf_spot(product: String, idx: int) -> Vector3:
	var z: float = shelves[product].z
	return to_global(Vector3(SHELF_X + (CUSTOMER_SIDE + idx * 0.9) * side, 0, z + idx * 0.25))


func till_spot(idx: int) -> Vector3:
	return to_global(Vector3(SHELF_X + (CUSTOMER_SIDE + idx * 0.9) * side, 0, till_z - idx * 0.2))


func join_queue(q: String, c: Node) -> void:
	(queues[q] as Array).append(c)


func leave_queue(q: String, c: Node) -> void:
	(queues[q] as Array).erase(c)


func queue_index(q: String, c: Node) -> int:
	return maxi((queues[q] as Array).find(c), 0)


func pay(c: Node3D, amount: int) -> void:
	coin_value += amount
	TimberSfx.play("pay", -6.0)
	var n := clampi(amount / 2, 1, 6)
	for i in n:
		if coins.is_full():
			break
		var it := TvItems.make("coin")
		get_tree().current_scene.add_child(it)
		it.global_position = c.global_position + Vector3(0, 1.2, 0)
		coins.push(it)
	TvFx.float_text(get_tree().current_scene, c.global_position + Vector3(0, 2.3, 0), "+" + TimberGame.fmt(amount), Color(1.0, 0.9, 0.35))


func _collect(carrier: Node, _delta: float) -> bool:
	if not carrier.get("is_player") or coin_value <= 0:
		return false
	_take_coins(carrier as Node3D)
	return true


func _take_coins(to: Node3D, by_cashier: bool = false) -> void:
	var value := coin_value
	coin_value = 0
	var shown := 0
	while not coins.is_empty():
		var it := coins.pop()
		if shown < 16:
			TvFx.fly_to_and_free(it, to, 0.02 * shown)
			shown += 1
		else:
			it.queue_free()
	TimberSfx.play("coins", -2.0)
	TimberGame.add_money(value, region)
	if by_cashier and region_node:
		region_node.record(value)
	TvFx.float_text(get_tree().current_scene, to.global_position + Vector3(0, 2.6, 0), "+" + TimberGame.fmt(value), Color(1.0, 0.85, 0.2), 1.3)


func hire_cashier(animate: bool) -> void:
	has_cashier = true
	cashier = TvWalker.new()
	cashier.init_walker("character-female-e")
	cashier.position = Vector3(SHELF_X - 0.2 * side, 0, till_z - 1.4)
	add_child(cashier)
	cashier.model.rotation.y = PI * 0.5 * side
	if animate:
		TvFx.pop_in(cashier)


func _process(delta: float) -> void:
	_draw_carried()
	if has_cashier:
		cashier.animate()
		_cashier_timer -= delta
		if _cashier_timer <= 0.0 and coin_value > 0:
			_cashier_timer = 1.2
			_take_coins(TimberGame.player, true)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		# More stock waiting on the counters brings more shoppers, so counters never clog.
		var stock := 0
		for p in shelves:
			if is_open(p):
				stock += shelf(p).count()
		var rush := 1.0 + clampf(stock / 12.0, 0.0, 2.5)
		var sign := 1.7 if sign_unlock != "" and TimberGame.is_unlocked(sign_unlock) else 1.0
		_spawn_timer = randf_range(0.9, 1.7) / (rush * sign * spawn_bonus * (1.0 + 0.1 * TimberGame.level("prices")) * TimberGame.fame_mult(region))
		_try_spawn()


func _try_spawn() -> void:
	var options: Array = []
	for p in shelves:
		if not is_open(p):
			continue
		if (queues[p] as Array).size() >= 7:
			continue
		var w := 3 if not shelf(p).is_empty() else 1
		for i in w:
			options.append(p)
	if options.is_empty():
		return
	# GDD 7.9: at most CUSTOMERS_PER_REGION shoppers per valley, walking ones included (it
	# counted only queued shoppers, so 30-40 could be on the map, each a draw call).
	if _customers.size() >= customer_cap:
		return
	var total := 0
	for q in queues:
		total += (queues[q] as Array).size()
	if total >= customer_cap:
		return
	var prod: String = options[randi() % options.size()]
	var big := shelf(prod).count() >= 12
	var n := randi_range(2, 5) if prod == "plank" else randi_range(1, 3)
	if big:
		n += randi_range(1, 3)
	# Veneer sells in bundles (Balance.SHOPPER_QTY_MULT, 1 for every other item).
	n *= int(TvBalance.SHOPPER_QTY_MULT.get(prod, 1))
	var spawn := to_global(Vector3(road_x, 0, 7.0 + randf() * 3.0))
	if spawn_local != Vector3.INF:
		spawn = to_global(spawn_local + Vector3(0, 0, randf() * 2.0))
	var entry := to_global(Vector3((CUSTOMER_SIDE + 3.0) * side, 0, shelves[prod].z + 1.5))
	var exit_pt := to_global(Vector3(road_x, 0, till_z - 16.0))
	if exit_local != Vector3.INF:
		exit_pt = to_global(exit_local)
	var c := TvCustomer.new().setup(self, prod, n, spawn, entry, exit_pt, lane_via)
	get_parent().add_child(c)
	_customers.append(c)


## Draw-call reduction: what all shoppers carry is drawn by one MultiMesh per item type (was one
## per shopper). Their landed items stay hidden nodes; flying items still draw themselves.
func _draw_carried() -> void:
	var inv := global_transform.affine_inverse()
	var by_type := {}
	for i in range(_customers.size() - 1, -1, -1):
		var c := _customers[i]
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			_customers.remove_at(i)
			continue
		for it in c.stack.items:
			if is_instance_valid(it) and it.has_meta("landed"):
				var t := str(it.get_meta("item"))
				if not by_type.has(t):
					by_type[t] = []
				(by_type[t] as Array).append(inv * it.global_transform)
	for t in _carry_mm:
		if not by_type.has(t):
			(_carry_mm[t] as MultiMeshInstance3D).multimesh.visible_instance_count = 0
	for t in by_type:
		var list: Array = by_type[t]
		var mmi: MultiMeshInstance3D = _carry_mm.get(t)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.name = "Carried_" + str(t)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = TvItems.mesh_of(t)
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if TvItems.casts_shadow(t) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_carry_mm[t] = mmi
		var m := mmi.multimesh
		if m.instance_count < list.size():
			m.instance_count = list.size() + 16
		var box := AABB()
		var aabb := m.mesh.get_aabb()
		for i in list.size():
			var xf: Transform3D = list[i]
			m.set_instance_transform(i, xf)
			var b := xf * aabb
			box = b if i == 0 else box.merge(b)
		m.visible_instance_count = list.size()
		if not list.is_empty():
			mmi.custom_aabb = box
