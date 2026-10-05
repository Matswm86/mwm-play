class_name TvRedwoodCoast
extends RefCounted

## Valley 4, Redwood Coast (GDD 7, milestone M3): redwoods and log skidders, the Level Crossing
## over the road, the Harbor Market with boat shoppers, a forklift, cargo orders, two repeatable
## ship slipways filled by shipwrights, and the Lighthouse. World builds the valley through this
## script at start-up and calls apply_unlock() for every r4_ pad. Positions: docs/GDD.md "M3 layout".

const CROSSING_Z := -20.0
const CROSSING_HALF := 1.4
## Redwood Coast's west palisade and the sea shore.
const WEST_X := 22.8
const SHORE_X := 74.6
const MILL := Vector3(32, 0, -20)
const DECKSAW := Vector3(32, 0, -32)
const MASTLATHE := Vector3(50, 0, -24)
const MARKET := Vector3(66, 0, -2)
const OFFICE := Vector3(28, 0, 4.5)
const ORDERS := Vector3(68, 0, 12)
const PIER_Z := 7.0
const PIER_END_X := 86.0
const CABLE_V4 := Vector3(47, 0, -45.4)
const GROVE1 := Vector3(45, 0, -8)
const GROVE2 := Vector3(45, 0, 4)
const GROVE_NORTH := Vector3(56, 0, -42)
const GROVE_FAR := Vector3(36, 0, -42)
const GROVE_CLIFF := Vector3(27.5, 0, -40)
const BELT_RD := [Vector3(35.0, 0, -21.4), Vector3(35.4, 0, -26.0), Vector3(29.3, 0, -26.0), Vector3(29.3, 0, -30.6)]
## Belts end just west of the hull (it reaches x -5.5 from the slipway origin).
const BELT_DECK1 := [Vector3(34.7, 0, -30.6), Vector3(34.7, 0, -29.0), Vector3(60.0, 0, -29.0), Vector3(60.0, 0, -27.0)]
const BELT_MAST1 := [Vector3(53.0, 0, -25.4), Vector3(60.0, 0, -25.4)]
const BELT_DECK2 := [Vector3(34.7, 0, -33.4), Vector3(34.7, 0, -36.8), Vector3(60.0, 0, -36.8)]
## Ship site slot squares (site-local, ASSETS_M3.md 1.4): on the camera side of the slipway.
const SHIP_SLOTS := [Vector3(-3.0, 0, 2.6), Vector3(3.0, 0, 0), Vector3(0, 4.4, 2.2)]
const LIGHT_SLOTS := [Vector3(-8.6, 0, 1.0), Vector3(2.6, 0, 0), Vector3(0, 4.2, 2.4)]

var w: TvWorld
var r: TvRegion
var shop4: TvShop
var office4_zone: TvZone
var forklift4: TvWorker
var orders: TvOrderBoard
## Timber carriers (r4_hauler1) until the harbor forklift takes over.
var _timber_carriers: Array[TvWorker] = []
var _gate_body: StaticBody3D
var _gate_prop: Node3D
var _arms: Array[Node3D] = []
var _arms_down: float = 0.0
var _boats: Node3D


func _init(world: TvWorld) -> void:
	w = world
	r = w.regions[4]


# ---------------------------------------------------------------- start-up (scenery, walls)

## The sea east of the shore: one water plane, foam along the beach.
func sea() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90.0, 120.0)
	pm.subdivide_depth = 40
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = TvWorld.WATER_SHADER
	mat.set_shader_parameter("noise_tex", w._noise_tex)
	mat.set_shader_parameter("flow", 0.25)
	mi.material_override = mat
	mi.position = Vector3(SHORE_X + 45.0 - 0.6, 0.06, -5.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Sea"
	w.add_child(mi)


func ground_look(mat: ShaderMaterial) -> void:
	# Wet sand at the shore (the shader's river band, moved out to sea) and dry sand behind it.
	mat.set_shader_parameter("river_x", SHORE_X + 50.0)
	mat.set_shader_parameter("river_half", 50.0)
	mat.set_shader_parameter("sand_x", Vector2(SHORE_X - 9.0, SHORE_X - 1.5))
	mat.set_shader_parameter("sand_col", Color(0.878, 0.796, 0.62))
	# Paths and plazas are beach sand here (ASSETS_M3.md 4).
	mat.set_shader_parameter("dirt_tex", load(TvModels.GROUND["sand"]))


func bounds() -> void:
	var rz := CROSSING_Z
	var h := CROSSING_HALF
	w._wall(Vector2(TvWorld.ROAD_X + 2.2, rz + h), Vector2(WEST_X, rz + h))
	w._wall(Vector2(TvWorld.ROAD_X + 2.2, rz - h), Vector2(WEST_X, rz - h))
	w._wall(Vector2(WEST_X, 15.5), Vector2(WEST_X, rz + h))
	w._wall(Vector2(WEST_X, rz - h), Vector2(WEST_X, -47))
	w._wall(Vector2(40, 15.5), Vector2(SHORE_X + 6.0, 15.5))
	w._wall(Vector2(40, -47), Vector2(SHORE_X + 6.0, -47))
	w._wall(Vector2(SHORE_X, 15.5), Vector2(SHORE_X, -47))
	if not TimberGame.is_unlocked("r4_crossing"):
		_gate_body = w._wall(Vector2(TvWorld.ROAD_X + 2.2, rz - h), Vector2(TvWorld.ROAD_X + 2.2, rz + h))


## Log palisade around the valley (sleeps with it), the closed crossing fence and barrier arms.
func palisades() -> void:
	var rz := CROSSING_Z
	var lines := [
		[Vector2(WEST_X, 15.3), Vector2(WEST_X, rz + CROSSING_HALF)],
		[Vector2(WEST_X, rz - CROSSING_HALF), Vector2(WEST_X, -46.6)],
		[Vector2(WEST_X, 15.3), Vector2(SHORE_X - 0.4, 15.3)],
		[Vector2(WEST_X, -46.6), Vector2(SHORE_X - 0.4, -46.6)],
	]
	w._multimesh(TvModels.path("palisade_post"), _posts(lines, w.rng4), true, r)
	if not TimberGame.is_unlocked("r4_crossing"):
		_gate_prop = w._model(TvModels.path("crossing_closed"), Vector3(TvWorld.ROAD_X + 2.2, 0, rz), 1.0, 0, w.r1)
	# Crossing posts with barrier booms (ASSETS_M3.md 1.5): down = rotation 0 across the road,
	# up = 80 deg. They come down while the player stands on the crossing.
	for k in 2:
		var post := TvModels.make("crossing_post")
		post.position = Vector3(14.9, 0, rz - 1.6) if k == 0 else Vector3(19.1, 0, rz + 1.6)
		post.rotation_degrees.y = 0.0 if k == 0 else 180.0
		w.r1.add_child(post)
		# The crossing only stands once it is bought.
		post.visible = TimberGame.is_unlocked("r4_crossing")
		var arm := TvModels.make("crossing_arm")
		arm.position = Vector3(0.12, 1.05, 0)
		post.add_child(arm)
		arm.rotation.z = deg_to_rad(80.0)
		_arms.append(arm)


static func _posts(lines: Array, g: RandomNumberGenerator) -> Array:
	var xforms := []
	for ln in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		var n := int(a.distance_to(b) / 0.31)
		for k in n + 1:
			var p := a.lerp(b, float(k) / maxf(n, 1))
			var hgt := g.randf_range(0.95, 1.3)
			var basis := Basis(Vector3.UP, g.randf() * TAU).scaled(Vector3(1, hgt, 1))
			xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	return xforms


## Forest south of the valley and in the belt to Frost Peaks (own seed): redwood cards from the
## M3 edge atlas (scaled 1.6x like the chop trees) with a few tall pines.
func border_forest(buckets: Dictionary, _kinds: Array) -> void:
	var pines := ["m3:tree_redwoodA", "m3:tree_redwoodB", "m3:tree_redwoodC", "m3:tree_pineTallB_detailed"]
	var g := RandomNumberGenerator.new()
	g.seed = 40404
	for rect in [Rect2(60.0, 18.0, SHORE_X - 60.0, 16.0), Rect2(50.2, -55.0, 27.0, 8.0)]:
		var n := int((rect as Rect2).get_area() / 3.2)
		for i in n:
			var p := Vector2(g.randf_range(rect.position.x, rect.end.x), g.randf_range(rect.position.y, rect.end.y))
			var k: String = pines[g.randi() % pines.size()]
			var s := g.randf_range(2.3, 2.8) * (1.6 if k.contains("redwood") else 1.2)
			if not buckets.has(k):
				continue
			# The cable car crosses the belt at x 47; keep its line clear.
			if absf(p.x - CABLE_V4.x) < 2.6 and p.y < -46.0:
				continue
			(buckets[k] as Array).append(Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))


## Keeps grass and rocks off the valley's belts, groves, buildings and squares.
func reserve() -> void:
	for line in [BELT_RD, BELT_DECK1, BELT_MAST1, BELT_DECK2]:
		for i in range(1, line.size()):
			var a: Vector3 = line[i - 1]
			var b: Vector3 = line[i]
			w._reserved_lines.append([Vector4(a.x, a.z, b.x, b.z), 0.8])
	w._reserved_lines.append([Vector4(TvWorld.ROAD_X, CROSSING_Z, MILL.x - 3.4, CROSSING_Z), 1.2])
	for g in [[GROVE1, 3, 2, 4.0], [GROVE2, 3, 2, 4.0], [GROVE_NORTH, 4, 2, 3.6], [GROVE_FAR, 3, 2, 3.5], [GROVE_CLIFF, 3, 3, 3.6]]:
		var c: Vector3 = g[0]
		w._reserved_rects.append(Vector4(c.x, c.z, int(g[1]) * float(g[3]) * 0.5 + 0.6, int(g[2]) * float(g[3]) * 0.5 + 0.6))
	for m in [MILL, DECKSAW, MASTLATHE]:
		w._reserved_rects.append(Vector4(m.x, m.z, 4.6, 2.2))
	w._reserved_rects.append(Vector4(MARKET.x + 0.5, MARKET.z - 1.5, 4.4, 5.8))
	w._reserved_rects.append(Vector4(OFFICE.x, OFFICE.z + 1.4, 2.6, 3.4))
	w._reserved_rects.append(Vector4(ORDERS.x + 2.0, ORDERS.z, 4.0, 2.0))
	for id in ["r4_slipway", "r4_slipway2", "r4_lighthouse"]:
		var p: Vector3 = TvBalance.BUILD_SITES[id].pos
		w._reserved_rects.append(Vector4(p.x - 1.0, p.z + 1.4, 6.0, 3.6) if id != "r4_lighthouse" else Vector4(p.x - 3.0, p.z, 6.0, 2.6))
	w._reserved_rects.append(Vector4(CABLE_V4.x, CABLE_V4.z + 2.0, 2.4, 2.6))
	var st: Vector3 = TvBalance.HANDCAR_STOPS[4].pos
	w._reserved_rects.append(Vector4(st.x + 1.0, st.z, 5.0, 2.0))
	var pl: Vector3 = TvBalance.BUILD_SITES.cap_p4.pos
	w._reserved_rects.append(Vector4(pl.x + 1.0, pl.z, 2.6, 2.0))


## Grass, bushes and rocks across the valley (a little sparser than Valley 1, no flowers by the sea).
func scatter() -> void:
	var nature := "res://games/timber-valley/assets/models_v3/nature/%s.glb"
	# ASSETS_M3.md 5: inland the V1 grass at half count, no flowers (shady redwood floor), rocks;
	# dune grass, driftwood and beach rocks near the shore.
	var sets := [
		[nature % "grass", 130, 2.4, false], [nature % "grass_large", 80, 2.4, false], [nature % "plant_bush", 60, 2.8, true],
		[nature % "rock_smallA", 40, 2.2, false], [nature % "rock_smallC", 40, 2.2, false], [nature % "mushroom_tanGroup", 15, 2.2, false],
		[nature % "rock_largeA", 12, 2.4, true], [TvModels.path("beach_rock"), 40, 2.4, false],
	]
	_scatter_sets(sets, Rect2(WEST_X + 0.7, -46.3, SHORE_X - 9.0 - WEST_X, 61.3))
	_scatter_sets([[TvModels.path("dune_grass"), 120, 2.6, false], [TvModels.path("driftwood"), 40, 2.4, false], [TvModels.path("beach_rock"), 60, 2.4, false]],
		Rect2(SHORE_X - 8.3, -46.3, 7.4, 61.3), 0.5)


func _scatter_sets(sets: Array, area: Rect2, mult: float = -1.0) -> void:
	var scale_n := area.get_area() / (66.0 * 68.0) if mult < 0.0 else mult
	for s in sets:
		var list := []
		var want := int(float(s[1]) * scale_n)
		var tries: int = want * 3
		while list.size() < want and tries > 0:
			tries -= 1
			var p := Vector2(w.rng4.randf_range(area.position.x, area.end.x), w.rng4.randf_range(area.position.y, area.end.y))
			if w._busy(p, 0.6) or absf(p.y - PIER_Z) < 1.8 and p.x > SHORE_X - 4.0:
				continue
			var sc: float = s[2] * w.rng4.randf_range(0.75, 1.3)
			list.append(Transform3D(Basis(Vector3.UP, w.rng4.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, 0, p.y)))
		w._deco.append([s[0], list, s[3]])


func _path4(a: Vector2, b: Vector2, wd: float) -> void:
	(w.grounds[4].paths as Array).append([Vector4(a.x, a.y, b.x, b.y), wd])


func _plaza4(c: Vector2, half: Vector2) -> void:
	(w.grounds[4].plazas as Array).append(Vector4(c.x, c.y, half.x, half.y))


# ---------------------------------------------------------------- unlocks

func apply_unlock(id: String, animate: bool) -> void:
	if TvBalance.BUILD_SITES.has(id):
		_build_ship_site(id, animate)
		if id == "r4_slipway2" and TimberGame.is_unlocked("r4_belt_ds"):
			_ship_belts(2, animate)
		return
	match id:
		"r4_crossing":
			_open_crossing(animate)
			w._build_forest("redwood", GROVE1, 3, 2, 4.0, "redwood", animate, 4)
			w.paths.append([Vector4(8.0, CROSSING_Z, TvWorld.ROAD_X, CROSSING_Z), 0.9])
			_path4(Vector2(TvWorld.ROAD_X + 2.0, CROSSING_Z), Vector2(MILL.x - 3.4, CROSSING_Z), 1.0)
			if not w._loading:
				w._rebuild_handcar_stops(animate)
		"r4_redmill":
			_build_mill(animate)
			_build_shop4(animate)
		"r4_grove2":
			w._build_forest("redwood", GROVE2, 3, 2, 4.0, "redwood", animate, 4)
		"r4_office":
			_build_office4(animate)
		"r4_jack1":
			var m: TvMachine = w.machines.redmill
			w._spawn_jack_to("character-male-d", w.forests.redwood, m.input, m.in_zone.global_position, Vector3(38, 0, -3), animate, 4)
		"r4_skidder1":
			_skidder(w.forests.redwood, w.machines.redmill, Vector3(38, 0, -14), animate)
		"r4_hauler1":
			# The harbor forklift replaces them (they took the slipways' timber: no ship launched).
			if TimberGame.is_unlocked("r4_forklift"):
				return
			var mt: TvMachine = w.machines.redmill
			var shelf_pos := shop4.shelf_zone("timber").global_position
			for k in int(TvBalance.TIMBER_CARRIERS):
				var look: String = ["character-female-d", "character-male-c"][k % 2]
				var src_pos := mt.out_zone.global_position
				var hw := TvWorker.new().as_hauler(look, mt.output, src_pos, shop4.shelf("timber"), shelf_pos)
				hw.region = 4
				r.add_child(hw)
				_timber_carriers.append(hw)
				if animate:
					TvFx.pop_in(hw)
		"r4_harbor":
			_build_boats(animate)
		"r4_cashier":
			shop4.hire_cashier(animate)
		"r4_decksaw":
			_build_decksaw(animate)
			shop4.open_shelf("deckboard", animate)
			_fork_source("decksaw")
		"r4_jack2":
			w._build_forest("redwood_north", GROVE_NORTH, 4, 2, 3.6, "redwood", animate, 4)
			var m: TvMachine = w.machines.redmill
			for k in 2:
				w._spawn_jack_to(["character-female-a", "character-male-b"][k], w.forests.redwood_north, m.input, m.in_zone.global_position, Vector3(52.0 - k * 1.6, 0, -38.0), animate, 4)
		"r4_belt_rd":
			w._belt((w.machines.redmill as TvMachine).output, (w.machines.decksaw as TvMachine).input, BELT_RD, animate, 4)
		"r4_forklift":
			for hw in _timber_carriers:
				if is_instance_valid(hw):
					hw.queue_free()
			_timber_carriers.clear()
			forklift4 = TvWorker.new().as_forklift(_fork_route, Vector3(44, 0, -13), "forklift_navy")
			forklift4.region = 4
			r.add_child(forklift4)
			for mid in ["redmill", "decksaw", "mastlathe"]:
				_fork_source(mid)
			if animate:
				TvFx.pop_in(forklift4)
		"r4_mastlathe":
			_build_mastlathe(animate)
			_fork_source("mastlathe")
		"r4_orders":
			_build_orders(animate)
		"r4_skidder2":
			w._build_forest("redwood_far", GROVE_FAR, 3, 2, 3.5, "redwood", animate, 4)
			_skidder(w.forests.redwood_far, w.machines.mastlathe, Vector3(40, 0, -37.5), animate)
			_skidder(w.forests.redwood_far, w.machines.redmill, Vector3(42, 0, -37.5), animate)
		"r4_builders":
			for k in 2:
				var sw := TvWorker.new().as_router(["character-male-a", "character-female-c"][k], _wright_route, Vector3(58.0 + k * 1.5, 0, -21.0), "", TvBalance.SHIPWRIGHT_CAP - 6)
				sw.region = 4
				for mid in ["redmill", "decksaw", "mastlathe"]:
					var m: TvMachine = w.machines[mid]
					sw.add_source(m.output, m.out_zone.global_position)
				r.add_child(sw)
				if animate:
					TvFx.pop_in(sw)
		"r4_belt_ds":
			_ship_belts(1, animate)
			if w.sites.has("r4_slipway2"):
				_ship_belts(2, animate)
		"r4_jack3":
			w._build_forest("redwood_cliff", GROVE_CLIFF, 3, 3, 3.6, "redwood", animate, 4)
			var looks := ["character-male-c", "character-female-d", "character-male-b"]
			for k in 3:
				var m: TvMachine = w.machines.redmill if k < 2 else w.machines.mastlathe
				w._spawn_jack_to(looks[k], w.forests.redwood_cliff, m.input, m.in_zone.global_position, Vector3(25.0 + k * 1.5, 0, -35.0), animate, 4)
			w._model(TvModels.path("log_stack_redwood"), Vector3(24.6, 0, -34.0), 2.4, 20, r)


func _open_crossing(animate: bool) -> void:
	for a in _arms:
		(a.get_parent() as Node3D).visible = true
	if _gate_body:
		_gate_body.queue_free()
		_gate_body = null
	if _gate_prop:
		var gp := _gate_prop
		_gate_prop = null
		if animate:
			var tw := gp.create_tween()
			tw.tween_property(gp, "scale", Vector3.ONE * 0.01, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(gp.queue_free)
		else:
			gp.queue_free()


func _skidder(forest: Array, m: TvMachine, home: Vector3, animate: bool) -> void:
	var sk := TvWorker.new().as_vehicle_jack("skidder", forest, m.input, m.in_zone.global_position, home)
	sk.region = 4
	r.add_child(sk)
	if animate:
		TvFx.pop_in(sk)


## A Models key (stand-in or real) on a machine body.
static func dress(m: TvMachine, key: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var inst := TvModels.make(key)
	inst.position = pos
	m.body.add_child(inst)
	return inst


func _build_mill(animate: bool) -> void:
	var m := w._machine2("redmill", "redmill", MILL, 4)
	m.input.position.x = -3.0
	m.in_zone.position.x = -3.0
	m.output.position.x = 3.0
	m.out_zone.position.x = 3.0
	# Twin-arbor headrig (ASSETS_M3.md 1.2): main saw and the smaller top saw.
	dress(m, "redmill")
	m.spinners.append(m.add_model(TvModels.path("redmill_blade"), Vector3(0, 0.8, 0.15), 1.0))
	m.spinners.append(m.add_model(TvModels.path("redmill_blade"), Vector3(0.22, 1.72, 0.15), 0.56))
	m.mouth_in = Vector3(-1.7, 1.0, 0.15)
	m.mouth_out = Vector3(1.45, 0.85, 0.15)
	m.cut_point = Vector3(0, 0.95, 0.15)
	m.add_dust(Vector3(0.1, 1.0, 0.3), Color(0.86, 0.5, 0.38))
	m.add_blocker(Vector3(4.6, 2.0, 2.3), Vector3(0, 0, -0.05))
	TvMeshMerge.merge(m.body, m.spinners)
	r.add_child(m)
	_plaza4(Vector2(MILL.x, MILL.z), Vector2(5.0, 2.2))
	w._model(TvModels.path("log_stack_redwood"), MILL + Vector3(-1.4, 0, -2.6), 2.4, 10, r)
	if animate:
		TvFx.pop_in(m, 0.7)


func _build_decksaw(animate: bool) -> void:
	var m := w._machine2("decksaw", "decksaw", DECKSAW, 4)
	dress(m, "decksaw")
	m.spinners.append(m.add_model(TvModels.path("decksaw_gang"), Vector3(0, 0.92, 0), 1.0))
	m.mouth_in = Vector3(-1.4, 0.9, 0)
	m.mouth_out = Vector3(1.2, 0.9, 0)
	m.add_dust(Vector3(0, 1.1, 0.4), Color(0.8, 0.55, 0.42))
	m.add_blocker(Vector3(3.4, 1.3, 1.6), Vector3(0, 0, -0.2))
	TvMeshMerge.merge(m.body, m.spinners)
	r.add_child(m)
	_plaza4(Vector2(DECKSAW.x, DECKSAW.z - 0.4), Vector2(4.8, 2.4))
	if animate:
		TvFx.pop_in(m, 0.7)


func _build_mastlathe(animate: bool) -> void:
	var m := w._machine2("mastlathe", "mastlathe", MASTLATHE, 4)
	m.input.position.x = -3.0
	m.in_zone.position.x = -3.0
	m.output.position.x = 3.0
	m.out_zone.position.x = 3.0
	# Masts are 2.4 m long: one row of four, not a 2 x 3 block.
	m.output.cols = 4
	m.output.rows = 1
	dress(m, "mastlathe")
	m.spinners.append(m.add_model(TvModels.path("mastlathe_log"), Vector3(0, 1.12, 0), 1.0, 90.0))
	m.mouth_in = Vector3(-1.3, 1.1, 0)
	m.mouth_out = Vector3(1.6, 1.0, 0.5)
	m.add_dust(Vector3(0, 1.1, 0.5), Color(0.9, 0.62, 0.48))
	m.add_blocker(Vector3(4.6, 1.6, 1.9), Vector3(-0.1, 0, -0.15))
	TvMeshMerge.merge(m.body, m.spinners)
	r.add_child(m)
	_plaza4(Vector2(MASTLATHE.x, MASTLATHE.z), Vector2(4.8, 2.2))
	if animate:
		TvFx.pop_in(m, 0.7)


## Harbor Market: shoppers come off the boats at the pier end and walk in along the pier.
func _build_shop4(animate: bool) -> void:
	shop4 = TvShop.new().setup(4, 1.0)
	shop4.position = MARKET
	shop4.spawn_local = Vector3(PIER_END_X - 1.0, 0, PIER_Z - 1.0) - MARKET
	shop4.exit_local = Vector3(PIER_END_X - 1.0, 0, PIER_Z) - MARKET
	shop4.lane_via = Vector3(SHORE_X - 1.4, 0, PIER_Z)
	shop4.sign_unlock = "r4_harbor"
	shop4.region_node = r
	shop4.add_shelf("timber", 2.6)
	shop4.add_shelf("deckboard", 0.0)
	r.add_child(shop4)
	shop4.open_shelf("timber", animate)
	_plaza4(Vector2(MARKET.x - 0.3, MARKET.z - 1.5), Vector2(2.8, 5.8))
	_build_pier()


## Wooden pier from the beach out to sea (the shoppers' boats tie up at its end).
func _build_pier() -> void:
	var root := Node3D.new()
	root.name = "Pier"
	r.add_child(root)
	# ASSETS_M3.md 1.3: 4 m straights along X (deck top y 0.3) and the pier head at the sea end.
	for x in [SHORE_X + 1.4, SHORE_X + 5.4]:
		w._model(TvModels.path("pier"), Vector3(x, 0, PIER_Z), 1.0, 0, root)
	w._model(TvModels.path("pier_end"), Vector3(PIER_END_X - 2.1, 0, PIER_Z), 1.0, 0, root)
	# Quay dressing: buoys off the pier, crates and lamps by the market.
	for b in [Vector3(PIER_END_X + 4.0, 0, PIER_Z - 4.0), Vector3(PIER_END_X + 6.0, 0, PIER_Z + 6.0), Vector3(SHORE_X + 9.0, 0, -12.0)]:
		w._model(TvModels.path("buoy"), b, 1.0, 0, root)
	w._model(TvModels.path("fish_crates"), MARKET + Vector3(-2.6, 0, 5.4), 1.0, 20, root)
	w._model(TvModels.path("harbor_lamp"), Vector3(SHORE_X - 1.2, 0, PIER_Z - 1.8), 1.0, 0, root)
	w._model(TvModels.path("anchor_prop"), Vector3(SHORE_X - 2.0, 0, -6.0), 1.0, -30, root)
	TvMeshMerge.merge(root)
	_path4(Vector2(MARKET.x + 4.0, PIER_Z), Vector2(SHORE_X, PIER_Z), 0.9)


## Fishing Pier (r4_harbor): two boats tie up at the pier end; shoppers x1.7 (Shop.sign_unlock).
func _build_boats(animate: bool) -> void:
	_boats = Node3D.new()
	_boats.name = "Boats"
	r.add_child(_boats)
	for k in 2:
		var b := TvModels.make("fishing_boat")
		b.position = Vector3(PIER_END_X - 3.0 - k * 5.0, 0.0, PIER_Z + (2.7 if k == 0 else -2.7))
		b.rotation_degrees.y = 90.0
		_boats.add_child(b)
	TvMeshMerge.merge(_boats)
	if animate:
		TvFx.pop_in(_boats, 0.7)


func _build_office4(animate: bool) -> void:
	var root := Node3D.new()
	root.position = OFFICE
	r.add_child(root)
	root.add_child(TvModels.make("harbor_office"))
	TvMeshMerge.merge(root)
	var lbl := Label3D.new()
	lbl.font = TvFx.font()
	lbl.text = "OFFICE"
	lbl.font_size = 56
	lbl.outline_size = 12
	lbl.modulate = Color(0.25, 0.16, 0.08)
	lbl.outline_modulate = Color(1, 0.95, 0.75)
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, 2.1, 1.62)
	root.add_child(lbl)
	w._batch_label(lbl)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.8, 3.0, 3.2)
	col.shape = bs
	col.position = Vector3(0, 1.5, -0.2)
	sb.add_child(col)
	root.add_child(sb)
	office4_zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.4, 2.0), "UPGRADES", Color(0.6, 0.95, 1.0))
	office4_zone.position = OFFICE + Vector3(0, 0, 3.4)
	office4_zone.on_enter = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.open_upgrades(4)
	office4_zone.on_exit = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.close_upgrades()
	r.add_child(office4_zone)
	_plaza4(Vector2(OFFICE.x, OFFICE.z + 2.6), Vector2(2.2, 1.6))
	if animate:
		TvFx.pop_in(root, 0.6)


func _build_orders(animate: bool) -> void:
	orders = TvOrderBoard.new()
	orders.masts_ok = func() -> bool: return w.machines.has("mastlathe")
	orders.region_node = r
	# The cargo ship ties up at sea, 6 m past the shore, level with the board.
	orders.setup(Vector3(SHORE_X + 7.6 - ORDERS.x, 0, 0))
	orders.position = ORDERS
	r.add_child(orders)
	_plaza4(Vector2(ORDERS.x + 1.5, ORDERS.z), Vector2(3.4, 1.8))
	_path4(Vector2(MARKET.x + 2.0, MARKET.z + 3.0), Vector2(ORDERS.x, ORDERS.z - 1.4), 0.8)
	if animate:
		TvFx.pop_in(orders, 0.6)


## Slipways (repeatable ship sites) and the Lighthouse, with their ramps and squares.
func _build_ship_site(id: String, animate: bool) -> void:
	var slots: Array = LIGHT_SLOTS if id == "r4_lighthouse" else SHIP_SLOTS
	var site: TvBuildSite = w._build_site(id, animate, slots[0], slots[1], slots[2])
	var p: Vector3 = TvBalance.BUILD_SITES[id].pos
	if id == "r4_lighthouse":
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3.2, 6.0, 3.2)
		col.shape = bs
		col.position.y = 3.0
		sb.add_child(col)
		site.add_child(sb)
		_plaza4(Vector2(p.x - 3.0, p.z + 0.6), Vector2(6.4, 2.6))
		return
	site.launched.connect(_on_launched)
	# Slipway (ASSETS_M3.md 1.4): origin = the hull's spot, sliding ways down into the sea (+X).
	var way := TvModels.make("slipway")
	way.position = p
	r.add_child(way)
	TvMeshMerge.merge(way)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(9.0, 3.0, 2.8)
	col.shape = bs
	col.position.y = 1.5
	sb.add_child(col)
	site.add_child(sb)
	_plaza4(Vector2(p.x - 0.5, p.z + 2.4), Vector2(4.6, 3.4))


## Belts from the deck saw (and, for the first slipway, the mast lathe) to a slipway.
func _ship_belts(n: int, animate: bool) -> void:
	var sid := "r4_slipway" if n == 1 else "r4_slipway2"
	if not w.sites.has(sid):
		return
	var site: TvBuildSite = w.sites[sid]
	var ds: TvMachine = w.machines.decksaw
	w._belt(ds.output, site.intake_of("deckboard"), BELT_DECK1 if n == 1 else BELT_DECK2, animate, 4)
	if n == 1:
		var ml: TvMachine = w.machines.mastlathe
		w._belt(ml.output, site.intake_of("mast"), BELT_MAST1, animate, 4)


## A finished ship slides 8 m east into the sea over 4 s, with a horn and a splash, then pays.
func _on_launched(id: String, hull: Node3D) -> void:
	for st in hull.get_children():
		(st as Node3D).scale = Vector3.ONE
		(st as Node3D).visible = true
	var reward := int(round(TvBalance.SHIP_REWARD * (1.0 + 0.1 * TimberGame.level("prices")) * TimberGame.fame_mult(4)))
	TimberSfx.play("bell", -2.0, 0.45)
	# ASSETS_M3.md 1.4: 8 m along the ways, 1.2 m down, a slight roll; splash at x +6.
	var start := hull.position
	var tw := hull.create_tween()
	var t := float(TvBalance.SHIP_LAUNCH.launch_s)
	tw.tween_property(hull, "position", start + Vector3(float(TvBalance.SHIP_LAUNCH.slide_m), -1.2, 0), t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hull, "rotation:z", -0.05, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_splash(hull.global_position + Vector3(6.0, 0.2, 0))
		TimberSfx.play("pop", -2.0, 0.6))
	tw.tween_property(hull, "position", start + Vector3(float(TvBalance.SHIP_LAUNCH.slide_m) + 14.0, -1.6, 0), 4.0)
	tw.tween_callback(hull.queue_free)
	TimberGame.add_money(reward, 4)
	# Ships the shipwrights build count as automation (the ledger pays them while asleep).
	if TimberGame.is_unlocked("r4_builders"):
		r.record(reward)
	var site: TvBuildSite = w.sites[id]
	TvFx.float_text(w.get_tree().current_scene, site.global_position + Vector3(0, 4.0, 0), "+" + TimberGame.fmt(reward), Color(1.0, 0.9, 0.35), 1.5)
	if TimberGame.hud:
		TimberGame.hud.toast("Ship launched: +%s" % TimberGame.fmt(reward))


## White splash where the hull meets the sea (one-shot, freed after).
func _splash(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.2
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.8, 0)
	var m := SphereMesh.new()
	m.radius = 0.16
	m.height = 0.32
	m.radial_segments = 6
	m.rings = 3
	m.material = TvShapes.mat(Color(0.95, 0.98, 1.0), 0.3)
	p.mesh = m
	p.position = at
	w.add_child(p)
	p.emitting = true
	w.get_tree().create_timer(1.8).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- routes (forklift, shipwrights)

func _fork_source(machine_id: String) -> void:
	if forklift4 == null or not w.machines.has(machine_id):
		return
	var m: TvMachine = w.machines[machine_id]
	forklift4.add_source(m.output, m.out_zone.global_position)


## Forklift loads: the cargo ship first while its manifest needs the item, else timber and
## deckboards to the Harbor counters; masts only ever go to the cargo ship.
func _fork_route(item: String, _commit: bool = false) -> Array:
	var main: Array = []
	if item in ["timber", "deckboard"] and shop4 and shop4.is_open(item) and not shop4.shelf(item).is_full():
		main = [shop4.shelf(item), shop4.shelf_zone(item).global_position]
	# The cargo ship pays 1.6x, so it comes first while its manifest wants the item.
	if orders != null and orders.room(item) > 0:
		return [orders.intake_of(item), orders.zone.global_position]
	return main


## Shipwright loads go to the Lighthouse while it needs the item, else to the slipway whose slot for
## that item is the least full. (2026-10-04: least-full-first kept the emptied slipways ahead of
## the Lighthouse, which sat at 145-185/200 timber for 12 min.)
func _wright_route(item: String, _commit: bool = false) -> Array:
	var lh: TvBuildSite = w.sites.get("r4_lighthouse")
	if lh and lh.room(item) > 0:
		return [lh.intake_of(item), lh.zone_of(item).global_position]
	var best: TvBuildSite = null
	var best_f := 2.0
	for id in ["r4_slipway", "r4_slipway2", "r4_lighthouse"]:
		if not w.sites.has(id):
			continue
		var s: TvBuildSite = w.sites[id]
		if s.room(item) <= 0:
			continue
		var f := float(int(s.goods[item]) - s.room(item)) / float(s.goods[item])
		if f < best_f:
			best_f = f
			best = s
	if best == null:
		return []
	return [best.intake_of(item), best.zone_of(item).global_position]


# ---------------------------------------------------------------- crossing, tutorial

func tick(delta: float) -> void:
	var on := _player_on_crossing()
	_arms_down = move_toward(_arms_down, 1.0 if on else 0.0, delta * 2.5)
	for a in _arms:
		a.rotation.z = deg_to_rad(80.0) * (1.0 - _arms_down)


func _player_on_crossing() -> bool:
	if w.player == null or not TimberGame.is_unlocked("r4_crossing"):
		return false
	var p := w.player.global_position
	return p.x > TvWorld.ROAD_X - 2.2 and p.x < TvWorld.ROAD_X + 2.6 and absf(p.z - CROSSING_Z) < 1.8


## True while the Valley 1 truck should wait before the crossing (it comes from the south).
func crossing_holds(pos: Vector3) -> bool:
	return _player_on_crossing() and pos.z > CROSSING_Z + 3.0 and pos.z < CROSSING_Z + 9.0


## Mini-tutorial until the first redwood lumberjack (GDD 12): chop, feed the mill, stock the counter.
func goal(p: Vector3) -> Array:
	var back := w.player.stack
	if not TimberGame.is_unlocked("r4_redmill"):
		if w.pads.has("r4_redmill"):
			return [(w.pads.r4_redmill as Node3D).global_position, "Build the redwood mill"]
		return [null, ""]
	var m: TvMachine = w.machines.redmill
	if shop4.coin_value > 0 and back.is_empty():
		return [shop4.coin_zone.global_position, "Collect your cash"]
	if back.top_type() == "red_log":
		var t := w._nearest_tree(p, "redwood")
		if m.in_zone.contains(p) or back.count() >= w.player.capacity() or t == null or back.count() >= 12:
			return [m.in_zone.global_position, "Feed the redwood mill"]
		return [t.global_position, "Chop the redwoods"]
	if back.top_type() == "timber":
		if m.out_zone.contains(p) and not m.output.is_empty() and back.count() < w.player.capacity():
			return [m.out_zone.global_position, "Pick up the timber"]
		return [shop4.shelf_zone("timber").global_position, "Stock the timber counter"]
	if not back.is_empty():
		return [null, ""]
	if m.output.count() >= 4:
		return [m.out_zone.global_position, "Pick up the timber"]
	var t2 := w._nearest_tree(p, "redwood")
	if t2:
		return [t2.global_position, "Chop the redwoods"]
	return [null, ""]
