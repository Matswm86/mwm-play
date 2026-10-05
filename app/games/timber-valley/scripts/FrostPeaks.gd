class_name TvFrostPeaks
extends RefCounted

## Valley 5, Frost Peaks (GDD 7, milestone M4): frost firs, the cable car up from Redwood Coast,
## three batch kilns, the ski workshop, sled workshop (assembler) and luthier, the Ski Lodge
## market, a snowcat, the mountain train and the Summit Observatory. World builds the valley
## through this script at start-up and calls apply_unlock() for every r5_ pad.

const WEST_X := 22.8
const EAST_X := 76.8
const SOUTH_Z := -55.0
const NORTH_Z := -119.0
const KILN1 := Vector3(40, 0, -66)
const KILN2 := Vector3(40, 0, -82)
const KILN3 := Vector3(40, 0, -98)
const SKIWORKS := Vector3(48, 0, -76)
const SLEDSHOP := Vector3(56, 0, -88)
const LUTHIER := Vector3(52, 0, -98)
const LODGE := Vector3(60, 0, -62)
const OFFICE := Vector3(35, 0, -60.5)
const EXPRESS := Vector3(70, 0, -80)
## Mountain train track (east-west, south of the platform) and where the train waits out of sight.
const MTRAIN_Z := -76.5
const MTRAIN_STOP_X := 64.5
const MTRAIN_AWAY_X := 118.0
## Cable car (ASSETS_M4.md 1.3): bottom station in Redwood Coast (deck +Z), top station here
## (turned 180, deck -Z); ride tiles in front of each deck and arrival points beyond them.
const CABLE_TOP := Vector3(47, 0, -56.8)
const CABLE_TILE_TOP := Vector3(47, 0, -59.7)
const CABLE_TILE_BOTTOM := Vector3(47, 0, -42.5)
const CABLE_LAND_TOP := Vector3(47.8, 0, -61.8)
const CABLE_LAND_BOTTOM := Vector3(47, 0, -39.8)
const ROPE_Y := 4.2
const GROVE1 := Vector3(28.5, 0, -65.5)
const GROVE2 := Vector3(30, 0, -76)
const GROVE_NORTH := Vector3(35, 0, -112)
const GROVE_FAR := Vector3(55, 0, -113)
const BELT_K1 := [Vector3(42.7, 0, -67.1), Vector3(42.7, 0, -70.4), Vector3(45.3, 0, -70.4), Vector3(45.3, 0, -74.6)]
const BELT_K2 := [Vector3(42.7, 0, -80.3), Vector3(42.7, 0, -79.0), Vector3(46.5, 0, -79.0), Vector3(46.5, 0, -77.4)]
## Kiln 2's belt splits to the sled workshop's lumber square once it stands (design call: with
## both kilns belted to the ski workshop the sled workshop never got dry lumber).
const BELT_K2_SLED := [Vector3(42.7, 0, -80.3), Vector3(44.2, 0, -80.3), Vector3(44.2, 0, -84.4), Vector3(51.6, 0, -84.4), Vector3(51.6, 0, -88.2)]
const BELT_K3 := [Vector3(42.7, 0, -99.4), Vector3(49.3, 0, -99.4)]
const BELT_SLED := [Vector3(59.2, 0, -86.6), Vector3(59.2, 0, -71.0), Vector3(56.4, 0, -71.0), Vector3(56.4, 0, -64.6), Vector3(57.2, 0, -64.6)]
const BELT_GUITAR := [Vector3(54.7, 0, -96.6), Vector3(54.7, 0, -92.0), Vector3(68.2, 0, -92.0), Vector3(68.2, 0, -81.8)]

var w: TvWorld
var r: TvRegion
var lodge: TvShop
var office5_zone: TvZone
var snowcat: TvWorker
var kilns: Array[TvKiln] = []
var _flip: Dictionary = {}
var _cable_hold: Dictionary = {}
var _cabin: Node3D
var _belt_k2: TvConveyor
var _chain: Node3D
var _bottom: Node3D


func _init(world: TvWorld) -> void:
	w = world
	r = w.regions[5]


# ---------------------------------------------------------------- start-up (scenery, walls)

## Snow tile as the grass, packed snow on paths (ASSETS_M4.md 4), a touch darker so the near-white
## does not blow out under ACES and glow.
func ground_look(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("dirt_tex", load(TvModels.GROUND["snow_packed"]))
	mat.set_shader_parameter("alt_col", Color(0.92, 0.92, 0.92))
	mat.set_shader_parameter("alt_mix", 0.0)
	mat.set_shader_parameter("tint", Color(0.92, 0.92, 0.92))


func bounds() -> void:
	w._wall(Vector2(WEST_X, SOUTH_Z), Vector2(WEST_X, NORTH_Z))
	w._wall(Vector2(WEST_X, SOUTH_Z), Vector2(EAST_X + 4.0, SOUTH_Z))
	w._wall(Vector2(WEST_X, NORTH_Z), Vector2(EAST_X + 4.0, NORTH_Z))
	w._wall(Vector2(EAST_X, SOUTH_Z), Vector2(EAST_X, NORTH_Z))


func palisades() -> void:
	var rail3 := -105.0
	var lines := [
		[Vector2(WEST_X, SOUTH_Z - 0.4), Vector2(WEST_X, rail3 + 1.4)],
		[Vector2(WEST_X, rail3 - 1.4), Vector2(WEST_X, NORTH_Z + 0.4)],
		[Vector2(WEST_X, SOUTH_Z - 0.4), Vector2(EAST_X, SOUTH_Z - 0.4)],
		[Vector2(WEST_X, NORTH_Z + 0.4), Vector2(EAST_X, NORTH_Z + 0.4)],
		[Vector2(EAST_X, SOUTH_Z - 0.4), Vector2(EAST_X, MTRAIN_Z + 1.4)],
		[Vector2(EAST_X, MTRAIN_Z - 1.4), Vector2(EAST_X, rail3 + 1.4)],
		[Vector2(EAST_X, rail3 - 1.4), Vector2(EAST_X, NORTH_Z + 0.4)],
	]
	w._multimesh(TvModels.path("palisade_post"), TvRedwoodCoast._posts(lines, w.rng5), true, r)
	build_cable_bottom()


## The Highland Railway runs on through Frost Peaks to the east forest (always there: the
## Highlands train uses it from M2 on).
func build_rail_v3() -> void:
	var track := Node3D.new()
	track.name = "HighlandLine"
	r.add_child(track)
	var xf := []
	var along_x := Basis(Vector3.UP, PI * 0.5)
	var x := 23.0
	while x < TvWorld.V3_TRAIN_AWAY_X + 24.0:
		xf.append(Transform3D(along_x, Vector3(x, 0, TvWorld.V3_RAIL_Z)))
		x += 4.0
	w._multimesh(TvModels.path("rail"), xf, true, track)
	TvMeshMerge.merge(track)


## Forest east and north of the valley (pines, own seed), with gaps where the two trains leave.
func border_forest(buckets: Dictionary, _kinds: Array) -> void:
	# Frost fir cards from the M4 edge atlas (scaled 1.15x like the chop trees).
	var pines := ["m4:tree_frostfirA", "m4:tree_frostfirB", "m4:tree_frostfirC", "m4:tree_frostfirD", "m4:tree_frostfirD"]
	var g := RandomNumberGenerator.new()
	g.seed = 50505
	for rect in [Rect2(EAST_X, -141.0, 33.2, 86.0), Rect2(50.2, -141.0, 59.8, 22.0)]:
		var n := int((rect as Rect2).get_area() / 3.2)
		for i in n:
			var p := Vector2(g.randf_range(rect.position.x, rect.end.x), g.randf_range(rect.position.y, rect.end.y))
			var k: String = pines[g.randi() % pines.size()]
			var s := g.randf_range(2.4, 3.2) * 1.15
			if not buckets.has(k):
				continue
			if p.x > EAST_X - 1.0 and (absf(p.y - TvWorld.V3_RAIL_Z) < 2.8 or absf(p.y - MTRAIN_Z) < 2.8):
				continue
			(buckets[k] as Array).append(Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))


func reserve() -> void:
	for line in [BELT_K1, BELT_K2, BELT_K3, BELT_SLED, BELT_GUITAR]:
		for i in range(1, line.size()):
			var a: Vector3 = line[i - 1]
			var b: Vector3 = line[i]
			w._reserved_lines.append([Vector4(a.x, a.z, b.x, b.z), 0.8])
	w._reserved_lines.append([Vector4(WEST_X, TvWorld.V3_RAIL_Z, EAST_X, TvWorld.V3_RAIL_Z), 1.3])
	w._reserved_lines.append([Vector4(MTRAIN_STOP_X - 4.0, MTRAIN_Z, EAST_X, MTRAIN_Z), 1.3])
	for g in [[GROVE1, 3, 3], [GROVE2, 3, 2], [GROVE_NORTH, 4, 3], [GROVE_FAR, 3, 3]]:
		var c: Vector3 = g[0]
		w._reserved_rects.append(Vector4(c.x, c.z, int(g[1]) * 1.4 + 0.6, int(g[2]) * 1.4 + 0.6))
	for m in [KILN1, KILN2, KILN3, SKIWORKS, LUTHIER]:
		w._reserved_rects.append(Vector4(m.x, m.z, 4.8, 2.6))
	w._reserved_rects.append(Vector4(SLEDSHOP.x, SLEDSHOP.z, 5.0, 2.8))
	w._reserved_rects.append(Vector4(LODGE.x + 0.5, LODGE.z - 2.6, 4.4, 7.2))
	w._reserved_rects.append(Vector4(OFFICE.x, OFFICE.z + 1.4, 2.6, 3.4))
	w._reserved_rects.append(Vector4(EXPRESS.x - 1.0, EXPRESS.z, 5.0, 3.0))
	w._reserved_rects.append(Vector4(CABLE_TOP.x, CABLE_TOP.z - 1.4, 2.6, 2.4))
	var o: Vector3 = TvBalance.BUILD_SITES.r5_observatory.pos
	w._reserved_rects.append(Vector4(o.x + 1.2, o.z + 2.4, 5.0, 4.0))
	var st: Vector3 = TvBalance.HANDCAR_STOPS[5].pos
	w._reserved_rects.append(Vector4(st.x - 1.0, st.z, 5.0, 2.0))
	var pl: Vector3 = TvBalance.BUILD_SITES.cap_p5.pos
	w._reserved_rects.append(Vector4(pl.x + 1.0, pl.z, 2.6, 2.0))


## Snowy ground (ASSETS_M4.md 5): drifts, snowy junipers and rocks, a few plain rocks; no grass.
func scatter() -> void:
	var nature := "res://games/timber-valley/assets/models_v3/nature/%s.glb"
	var sets := [
		[TvModels.path("snow_drift"), 140, 2.6, false], [TvModels.path("snow_bush"), 90, 2.6, false], [TvModels.path("snow_rock"), 70, 2.4, true],
		[nature % "rock_smallA", 20, 2.2, false], [nature % "rock_smallC", 20, 2.2, false],
	]
	var area := Rect2(WEST_X + 0.7, NORTH_Z + 0.7, EAST_X - WEST_X - 1.4, SOUTH_Z - NORTH_Z - 1.4)
	var scale_n := area.get_area() / (66.0 * 68.0)
	for s in sets:
		var list := []
		var want := int(float(s[1]) * scale_n)
		var tries: int = want * 3
		while list.size() < want and tries > 0:
			tries -= 1
			var p := Vector2(w.rng5.randf_range(area.position.x, area.end.x), w.rng5.randf_range(area.position.y, area.end.y))
			if w._busy(p, 0.6):
				continue
			var sc: float = s[2] * w.rng5.randf_range(0.75, 1.3)
			list.append(Transform3D(Basis(Vector3.UP, w.rng5.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, 0, p.y)))
		w._deco.append([s[0], list, s[3]])


func _path5(a: Vector2, b: Vector2, wd: float) -> void:
	(w.grounds[5].paths as Array).append([Vector4(a.x, a.y, b.x, b.y), wd])


func _plaza5(c: Vector2, half: Vector2) -> void:
	(w.grounds[5].plazas as Array).append(Vector4(c.x, c.y, half.x, half.y))


# ---------------------------------------------------------------- unlocks

func apply_unlock(id: String, animate: bool) -> void:
	if id == "r5_observatory":
		var site: TvBuildSite = w._build_site(id, animate)
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(4.4, 6.0, 4.4)
		col.shape = bs
		col.position.y = 3.0
		sb.add_child(col)
		site.add_child(sb)
		var p: Vector3 = TvBalance.BUILD_SITES[id].pos
		_plaza5(Vector2(p.x + 1.2, p.z + 2.6), Vector2(5.0, 3.6))
		return
	match id:
		"r5_cablecar":
			_build_cable_car(animate)
			w._build_forest("frost", GROVE1, 3, 3, 2.8, "frost", animate, 5)
			_path5(Vector2(CABLE_TOP.x, CABLE_TOP.z), Vector2(CABLE_TOP.x, -62.0), 1.0)
			_path5(Vector2(32.0, -62.0), Vector2(62.0, -62.0), 0.9)
			if not w._loading:
				w._rebuild_handcar_stops(animate)
		"r5_kiln":
			_build_kiln("kiln", KILN1, animate)
		"r5_grove2":
			w._build_forest("frost", GROVE2, 3, 2, 2.8, "frost", animate, 5)
		"r5_office":
			_build_office5(animate)
		"r5_jack1":
			_jack("character-male-c", w.forests.frost, Vector3(33, 0, -70), animate)
		"r5_skilodge":
			_build_lodge(animate)
		"r5_skiworks":
			_build_machine("skiworks", "skiworks", SKIWORKS, animate)
			lodge.open_shelf("skis", animate)
		"r5_cashier":
			lodge.hire_cashier(animate)
		"r5_jack2":
			w._build_forest("frost_north", GROVE_NORTH, 4, 3, 2.8, "frost", animate, 5)
			for k in 2:
				_jack(["character-female-b", "character-male-d"][k], w.forests.frost_north, Vector3(31.0 + k * 1.6, 0, -106.5), animate)
		"r5_kiln2":
			_build_kiln("kiln2", KILN2, animate)
		"r5_belt_ks":
			var sw: TvMachine = w.machines.skiworks
			var k1o: TvItemStack = (w.machines.kiln as TvKiln).output
			var k1 := w._belt(k1o, sw.input, BELT_K1, animate, 5)
			# Kiln 1's belt leaves a reserve while the Observatory needs dry lumber, so the snowcat
			# finds some to take there (2026-10-04: the belts took nearly all of it, 5/200 in 6 min).
			k1.hold = _obs_reserve(k1o, "dry_lumber")
			_belt_k2 = w._belt((w.machines.kiln2 as TvKiln).output, sw.input, BELT_K2, animate, 5)
		"r5_sledshop":
			_build_sledshop(animate)
			lodge.open_shelf("sled", animate)
			if _belt_k2:
				_belt_k2.add_split((w.machines.sledshop as TvMachine).input, PackedVector3Array(BELT_K2_SLED), 0)
		"r5_snowcat":
			snowcat = TvWorker.new().as_router("", _cat_route, Vector3(51, 0, -81), "snowcat")
			snowcat.region = 5
			r.add_child(snowcat)
			for mid in ["kiln", "kiln2", "kiln3", "skiworks", "sledshop", "luthier"]:
				_cat_source(mid)
			if animate:
				TvFx.pop_in(snowcat)
		"r5_luthier":
			_build_machine("luthier", "luthier", LUTHIER, animate)
			_cat_source("luthier")
		"r5_express_r5":
			_build_express(animate)
		"r5_belt_sl":
			# Sled and guitar belts leave a reserve while the Observatory needs sleds or guitars (the
			# snowcat found none to take there: 0/20 sleds, 0/10 guitars in 6 min).
			var so: TvItemStack = (w.machines.sledshop as TvMachine).output
			var bs := w._belt(so, lodge.shelf("sled"), BELT_SLED, animate, 5)
			bs.hold = _obs_reserve(so, "sled")
			var lo: TvItemStack = (w.machines.luthier as TvMachine).output
			var bg := w._belt(lo, (w.machines.mtrain as TvTruckDock).pile, BELT_GUITAR, animate, 5)
			bg.hold = _obs_reserve(lo, "guitar")
		"r5_jack3":
			w._build_forest("frost_far", GROVE_FAR, 3, 3, 2.8, "frost", animate, 5)
			var looks := ["character-female-a", "character-male-a", "character-female-c"]
			for k in 3:
				_jack(looks[k], w.forests.frost_far, Vector3(52.0 + k * 1.5, 0, -108.5), animate)
			w._model(TvModels.path("log_stack_frost"), Vector3(59.5, 0, -109.0), 2.4, 20, r)
		"r5_kiln3":
			_build_kiln("kiln3", KILN3, animate)
			w._belt((w.machines.kiln3 as TvKiln).output, (w.machines.luthier as TvMachine).input, BELT_K3, animate, 5)


## Belt hold: keep Balance.SITE_RESERVE[item] on `src` while the Summit Observatory needs `item`.
func _obs_reserve(src: TvItemStack, item: String) -> Callable:
	var keep := int(TvBalance.SITE_RESERVE[item])
	return func() -> bool:
		var obs: TvBuildSite = w.sites.get("r5_observatory")
		return src.count() <= keep and obs != null and obs.room(item) > 0


func _jack(look: String, forest: Array, home: Vector3, animate: bool) -> void:
	var k: TvKiln = w.machines.kiln
	var j := TvWorker.new().as_lumberjack(look, forest, k.input, k.in_zone.global_position, home)
	j.region = 5
	j.pick_dest = _pick_kiln
	r.add_child(j)
	if animate:
		TvFx.pop_in(j)


## The kiln with the most room that is not baking (or the least busy one).
func _pick_kiln() -> Array:
	var best: TvKiln = null
	var best_room := -1
	for k in kilns:
		var room := 0 if k.baking else int(TvBalance.KILN.batch) - k.input.count()
		if room > best_room:
			best_room = room
			best = k
	if best == null:
		return []
	return [best.input, best.in_zone.global_position]


func _build_kiln(id: String, pos: Vector3, animate: bool) -> void:
	var k := TvKiln.new().setup(id, 5)
	k.position = pos
	r.add_child(k)
	w.machines[id] = k
	kilns.append(k)
	_cat_source(id)
	_plaza5(Vector2(pos.x, pos.z), Vector2(5.4, 2.6))
	if id == "kiln":
		w._model(TvModels.path("log_stack_frost"), pos + Vector3(-2.4, 0, -2.6), 2.3, 10, r)
	if animate:
		TvFx.pop_in(k, 0.7)


## Ski workshop (bending press) and luthier (sanding disc), ASSETS_M4.md 1.2 anchors.
func _build_machine(id: String, recipe: String, pos: Vector3, animate: bool) -> TvMachine:
	var m := w._machine2(id, recipe, pos, 5)
	TvRedwoodCoast.dress(m, id)
	if id == "skiworks":
		m.plates.append(m.add_model(TvModels.path("ski_press"), Vector3(0, 1.55, 0.2), 1.0))
		m.plate_up = 1.55
		m.plate_down = 1.08
		m.mouth_in = Vector3(-1.25, 0.6, 0.65)
		m.mouth_out = Vector3(0.9, 1.0, 0.2)
		m.add_blocker(Vector3(3.6, 2.0, 2.8))
	else:
		m.spinners.append(m.add_model(TvModels.path("luthier_sander"), Vector3(1.15, 1.32, 0.56), 1.0))
		m.mouth_in = Vector3(-1.0, 1.0, 0.2)
		m.mouth_out = Vector3(0.8, 1.0, 0.4)
		m.add_blocker(Vector3(3.8, 2.0, 3.0))
	m.add_dust(Vector3(0, 1.2, 0.4), Color(0.95, 0.88, 0.75))
	TvMeshMerge.merge(m.body, m.plates + m.spinners)
	r.add_child(m)
	_plaza5(Vector2(pos.x, pos.z), Vector2(4.8, 2.2))
	if animate:
		TvFx.pop_in(m, 0.7)
	return m


## Assembler: dry lumber at the back square, skis at the front, sleds out east.
func _build_sledshop(animate: bool) -> void:
	var rc: Array = TvBalance.MACHINES["sledshop"]
	var m := w._machine2("sledshop", "sledshop", SLEDSHOP, 5)
	m.input.position = Vector3(-3.2, 0, -1.45)
	m.in_zone.position = m.input.position
	m.in_zone.half = Vector2(1.1, 1.2)
	if m.in_zone.label:
		m.in_zone.label.position.z = -1.6
	m.add_second_input(str(rc[2]), int(rc[3]), Vector3(-3.2, 0, 1.45))
	m.output.position = Vector3(3.2, 0, 0)
	m.out_zone.position = m.output.position
	TvRedwoodCoast.dress(m, "sledshop")
	m.arms.append(m.add_model(TvModels.path("sledshop_arm"), Vector3(0.9, 0, -1.2), 1.0))
	m.mouth_in = Vector3(-2.1, 0.9, -1.2)
	m.mouth_in_b = Vector3(-2.1, 0.9, 1.2)
	m.mouth_out = Vector3(2.3, 0.9, 0)
	m.add_dust(Vector3(0, 1.2, 0.6), Color(0.95, 0.85, 0.65))
	m.add_blocker(Vector3(4.6, 3.0, 4.0))
	TvMeshMerge.merge(m.body, m.arms)
	r.add_child(m)
	_plaza5(Vector2(SLEDSHOP.x, SLEDSHOP.z), Vector2(5.6, 2.8))
	_cat_source("sledshop")
	if animate:
		TvFx.pop_in(m, 0.8)


## Ski Lodge: tourists come up on the cable car and walk east to the counters.
func _build_lodge(animate: bool) -> void:
	lodge = TvShop.new().setup(5, 1.0)
	lodge.position = LODGE
	lodge.spawn_local = Vector3(CABLE_TOP.x + 3.5, 0, -58.6) - LODGE
	lodge.exit_local = Vector3(CABLE_TOP.x + 3.5, 0, -57.8) - LODGE
	lodge.lane_via = Vector3(LODGE.x + 4.5, 0, -57.0)
	lodge.sign_unlock = ""
	lodge.region_node = r
	lodge.add_shelf("dry_lumber", 2.6)
	lodge.add_shelf("skis", 0.0)
	lodge.add_shelf("sled", -2.6)
	r.add_child(lodge)
	lodge.open_shelf("dry_lumber", animate)
	_plaza5(Vector2(LODGE.x - 0.3, LODGE.z - 1.5), Vector2(2.8, 5.8))
	# The chalet behind the customer side (ASSETS_M4.md 1.4), facing the counters; props around it.
	var deco := Node3D.new()
	deco.name = "LodgeChalet"
	r.add_child(deco)
	w._model(TvModels.path("ski_lodge"), LODGE + Vector3(9.0, 0, -3.0), 1.0, 0, deco)
	var lbl := Label3D.new()
	lbl.font = TvFx.font()
	lbl.text = "SKI LODGE"
	lbl.font_size = 48
	lbl.outline_size = 10
	lbl.modulate = Color(0.25, 0.16, 0.08)
	lbl.outline_modulate = Color(1, 0.95, 0.75)
	lbl.pixel_size = 0.006
	lbl.position = LODGE + Vector3(9.0, 2.38, -3.0 + 3.28)
	deco.add_child(lbl)
	for pr in [["snowman", Vector3(-3.4, 0, 4.4), 20], ["snowman", Vector3(5.8, 0, -7.2), -30], ["ski_rack", Vector3(5.4, 0, 3.6), -90],
			["ski_rack", Vector3(5.4, 0, -6.0), -90], ["alpine_lamp", Vector3(4.6, 0, 4.8), 0]]:
		w._model(TvModels.path(str(pr[0])), LODGE + (pr[1] as Vector3), 1.0, float(pr[2]), deco)
	TvMeshMerge.merge(deco)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.0, 4.0, 4.6)
	col.shape = bs
	col.position = LODGE + Vector3(9.0, 2.0, -3.0)
	sb.add_child(col)
	deco.add_child(sb)


func _build_office5(animate: bool) -> void:
	var root := Node3D.new()
	root.position = OFFICE
	r.add_child(root)
	root.add_child(TvModels.make("mountain_office"))
	TvMeshMerge.merge(root)
	var lbl := Label3D.new()
	lbl.font = TvFx.font()
	lbl.text = "OFFICE"
	lbl.font_size = 56
	lbl.outline_size = 12
	lbl.modulate = Color(0.25, 0.16, 0.08)
	lbl.outline_modulate = Color(1, 0.95, 0.75)
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, 2.1, 1.69)
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
	office5_zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.4, 2.0), "UPGRADES", Color(0.6, 0.95, 1.0))
	office5_zone.position = OFFICE + Vector3(0, 0, 3.4)
	office5_zone.on_enter = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.open_upgrades(5)
	office5_zone.on_exit = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.close_upgrades()
	r.add_child(office5_zone)
	_plaza5(Vector2(OFFICE.x, OFFICE.z + 2.6), Vector2(2.2, 1.6))
	if animate:
		TvFx.pop_in(root, 0.6)


## Express Platform: the mountain train comes in from the east forest along its own line.
func _build_express(animate: bool) -> void:
	var d := TvTruckDock.new().setup("guitar", 0.0, "mtrain", 5)
	# Firewood by the kilns' yard and the office (ASSETS_M4.md 5).
	w._model(TvModels.path("firewood_snow"), OFFICE + Vector3(2.6, 0, 1.6), 1.0, 0, r)
	d.position = EXPRESS
	d.rotation_degrees.y = -90
	d.region_node = r
	d.zone.position = Vector3(0.6, 0, 4.4)
	d.zone.rotation_degrees.y = 90
	d.set_route(Vector3(MTRAIN_STOP_X, 0, MTRAIN_Z), Vector3(MTRAIN_AWAY_X, 0, MTRAIN_Z), Vector3(MTRAIN_AWAY_X, 0, MTRAIN_Z), PI * 0.5)
	r.add_child(d)
	w.machines["mtrain"] = d
	var track := Node3D.new()
	track.name = "MountainLine"
	r.add_child(track)
	var xf := []
	var along_x := Basis(Vector3.UP, PI * 0.5)
	var x := MTRAIN_STOP_X - 3.0
	while x < MTRAIN_AWAY_X + 12.0:
		xf.append(Transform3D(along_x, Vector3(x, 0, MTRAIN_Z)))
		x += 4.0
	w._multimesh(TvModels.path("rail"), xf, true, track)
	var bumper := TvModels.make("rail_bumper")
	bumper.position = Vector3(MTRAIN_STOP_X - 4.6, 0, MTRAIN_Z)
	bumper.rotation_degrees.y = 90
	track.add_child(bumper)
	TvMeshMerge.merge(track)
	_plaza5(Vector2(EXPRESS.x - 1.2, EXPRESS.z - 0.4), Vector2(4.4, 2.6))
	if animate:
		TvFx.pop_in(d, 0.6)


## Bottom station in Redwood Coast from the start, chained shut until the Cable Car is bought.
func build_cable_bottom() -> void:
	_bottom = TvModels.make("cablecar_bottom")
	_bottom.position = TvRedwoodCoast.CABLE_V4
	w.r4.add_child(_bottom)
	TvMeshMerge.merge(_bottom)
	var lbl := Label3D.new()
	lbl.font = TvFx.font()
	lbl.text = "CABLE CAR"
	lbl.font_size = 44
	lbl.outline_size = 10
	lbl.modulate = Color(0.25, 0.16, 0.08)
	lbl.outline_modulate = Color(1, 0.95, 0.75)
	lbl.pixel_size = 0.006
	lbl.position = TvRedwoodCoast.CABLE_V4 + Vector3(0, 3.3, 1.82)
	w.r4.add_child(lbl)
	w._batch_label(lbl)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.0, 3.0, 2.6)
	col.shape = bs
	col.position = TvRedwoodCoast.CABLE_V4 + Vector3(0, 1.5, -0.6)
	sb.add_child(col)
	w.r4.add_child(sb)
	if not TimberGame.is_unlocked("r5_cablecar"):
		_chain = TvModels.make("cablecar_chain")
		_chain.position = TvRedwoodCoast.CABLE_V4
		w.r4.add_child(_chain)


## Cable car (GDD 9.1, ASSETS_M4.md 1.3): top station turned 180, the haul rope at y 4.2, a
## bull-wheel turning in each station, one gondola gliding between them, and a ride tile in front
## of each boarding deck (hold 0.8 s, fade, arrive at the other end).
func _build_cable_car(animate: bool) -> void:
	if _chain:
		var ch := _chain
		_chain = null
		if animate:
			var tw0 := ch.create_tween()
			tw0.tween_property(ch, "scale", Vector3.ONE * 0.01, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw0.tween_callback(ch.queue_free)
		else:
			ch.queue_free()
	var top := TvModels.make("cablecar_top")
	top.position = CABLE_TOP
	top.rotation_degrees.y = 180.0
	r.add_child(top)
	TvMeshMerge.merge(top)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.0, 3.0, 2.6)
	col.shape = bs
	col.position = CABLE_TOP + Vector3(0, 1.5, 0.6)
	sb.add_child(col)
	r.add_child(sb)
	var line := Node3D.new()
	line.name = "CableCar"
	w.r4.add_child(line)
	var z0 := TvRedwoodCoast.CABLE_V4.z
	var z1 := CABLE_TOP.z
	var rope := TvModels.make("cablecar_cable")
	rope.position = Vector3(CABLE_TOP.x, ROPE_Y, (z0 + z1) * 0.5)
	rope.scale = Vector3(1, 1, absf(z1 - z0))
	line.add_child(rope)
	for st in [[TvRedwoodCoast.CABLE_V4, w.r4], [CABLE_TOP, r]]:
		var wheel := TvModels.make("cablecar_bullwheel")
		wheel.position = (st[0] as Vector3) + Vector3(0, ROPE_Y, 0)
		(st[1] as Node3D).add_child(wheel)
		var tw := wheel.create_tween().set_loops()
		tw.tween_property(wheel, "rotation:y", TAU, 3.2).from(0.0)
	_cabin = TvModels.make("cablecar_gondola")
	_cabin.position = Vector3(CABLE_TOP.x, ROPE_Y, z0 + 1.3)
	line.add_child(_cabin)
	var tw := _cabin.create_tween().set_loops()
	tw.tween_property(_cabin, "position:z", z1 - 1.3, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.0)
	tw.tween_property(_cabin, "position:z", z0 + 1.3, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.0)
	_ride_tile(w.r4, CABLE_TILE_BOTTOM, "FROST PEAKS", CABLE_LAND_TOP, "up")
	_ride_tile(r, CABLE_TILE_TOP, "REDWOOD COAST", CABLE_LAND_BOTTOM, "down")
	if animate:
		TvFx.pop_in(top, 0.6)


func _ride_tile(parent: TvRegion, at: Vector3, label: String, land: Vector3, key: String) -> void:
	var tile := TvModels.make("handcar_tile")
	tile.position = at
	parent.add_child(tile)
	TvMeshMerge.merge(tile)
	var z := TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(1.6, 1.6), label, Color(1.0, 0.85, 0.3))
	z.position = at
	z.marker.visible = false
	z.interval = 0.0
	z.on_carrier = func(c: Node, delta: float) -> bool:
		if not c.get("is_player"):
			return false
		var t: float = float(_cable_hold.get(key, 0.0)) + delta
		_cable_hold[key] = t
		if t >= float(TvBalance.HANDCAR.hold_s) and t - delta < float(TvBalance.HANDCAR.hold_s):
			ride(land)
		return false
	z.on_exit = func(_c: Node) -> void:
		_cable_hold[key] = 0.0
	parent.add_child(z)
	if z.label:
		z.label.font_size = 40
		z.label.pixel_size = 0.0075
		z.label.position.z = 1.3


## Cable car ride: same fade as a handcar ride.
func ride(land: Vector3) -> void:
	_cable_hold.clear()
	TimberSfx.play("machine", -3.0, 0.6)
	var go := func() -> void:
		w.player.global_position = land
		w.player.velocity = Vector3.ZERO
		w._cam_pos = land
		w._update_regions(0.0, true)
	if TimberGame.hud:
		TimberGame.hud.fade_travel(go)
	else:
		go.call()


# ---------------------------------------------------------------- snowcat

func _cat_source(machine_id: String) -> void:
	if snowcat == null or not w.machines.has(machine_id):
		return
	var m: Node = w.machines[machine_id]
	var out: TvItemStack = m.get("output")
	var oz: TvZone = m.get("out_zone")
	snowcat.add_source(out, oz.global_position)


## Snowcat loads go round the places that use them, the first with room in turn:
## dry lumber -> sled workshop, luthier, lodge counter, Observatory; skis -> sled workshop,
## counter, Observatory; sleds -> counter, Observatory; guitars -> express platform, Observatory.
func _cat_route(item: String, commit: bool = false) -> Array:
	var opts: Array = []
	var ss: TvMachine = w.machines.get("sledshop")
	var lu: TvMachine = w.machines.get("luthier")
	var obs: TvBuildSite = w.sites.get("r5_observatory")
	match item:
		"dry_lumber":
			if ss:
				opts.append([ss.input, ss.in_zone.global_position])
			if lu:
				opts.append([lu.input, lu.in_zone.global_position])
		"skis":
			if ss:
				opts.append([ss.input_b, ss.in_zone_b.global_position])
		"guitar":
			if w.machines.has("mtrain"):
				var d: TvTruckDock = w.machines.mtrain
				opts.append([d.pile, d.zone.global_position])
	if lodge and lodge.shelves.has(item) and lodge.is_open(item):
		opts.append([lodge.shelf(item), lodge.shelf_zone(item).global_position])
	if obs and obs.room(item) > 0:
		# The Observatory takes dry lumber, sleds and guitars first while it needs them (it took
		# 26 min to fill when sharing loads with the counters and the train). Skis keep rotating:
		# the snowcat is the sled shop's only ski supply.
		if item != "skis":
			return [obs.intake_of(item), obs.zone_of(item).global_position]
		opts.append([obs.intake_of(item), obs.zone_of(item).global_position])
	var n := opts.size()
	if n == 0:
		return []
	var start := int(_flip.get(item, 0))
	for i in n:
		var o: Array = opts[(start + i) % n]
		var st: TvItemStack = o[0]
		var ok := not st.is_full()
		if st.get_parent() is TvBuildSite:
			ok = obs.room(item) > 0
		if ok:
			if commit:
				_flip[item] = (start + i + 1) % n
			return o
	return []


## Mini-tutorial until the first mountain lumberjack (GDD 12): build the kiln, chop, feed it.
func goal(p: Vector3) -> Array:
	var back := w.player.stack
	if not TimberGame.is_unlocked("r5_kiln"):
		if w.pads.has("r5_kiln"):
			return [(w.pads.r5_kiln as Node3D).global_position, "Build the drying kiln"]
		return [null, ""]
	var k: TvKiln = w.machines.kiln
	if back.top_type() == "frost_log":
		var t := w._nearest_tree(p, "frost")
		if k.in_zone.contains(p) or back.count() >= w.player.capacity() or t == null or back.count() >= 12:
			return [k.in_zone.global_position, "Fill the drying kiln"]
		return [t.global_position, "Chop the frost firs"]
	if not back.is_empty():
		return [null, ""]
	var t2 := w._nearest_tree(p, "frost")
	if t2:
		return [t2.global_position, "Chop the frost firs"]
	return [null, ""]
