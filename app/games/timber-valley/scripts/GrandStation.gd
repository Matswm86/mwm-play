class_name TvGrandStation
extends RefCounted

## The finale (GDD 7.7, milestone M5): the Grand Timber Station pad pays the money slot; then the
## station rises in the forest belt between Home Valley and Maple Highlands, a rail line runs
## along it, and every valley gets a platform next to its handcar stop that wants one load of
## that valley's best goods. A porter per valley carries its export goods there (only while the
## valley is awake). With all five full, the Timber Express runs once past every valley (12 s)
## and the finish panel opens. Orders and ships keep running afterwards.

const PLATFORMS := ["cap_p1", "cap_p2", "cap_p3", "cap_p4", "cap_p5"]
## Where each valley's porter loads (World.machines key, and whether it is a dock pile).
const PORTER_FROM := {
	"cap_p1": ["dock", true], "cap_p2": ["barge", true], "cap_p3": ["rail", true],
	"cap_p4": ["mastlathe", false], "cap_p5": ["mtrain", true],
}

var w: TvWorld
var cutscene: bool = false
var built: bool = false
var _stages: Array[Node3D] = []
var _shown: int = 0
var _poll: float = 0.0
var _express: Node3D
var _plot: Node3D
var _sign: Label3D


func _init(world: TvWorld) -> void:
	w = world


## Border trees on the rail line and the station's footprint (cleared when the station is bought).
func on_clearing(o: Vector3) -> bool:
	var st: Dictionary = TvBalance.STATION
	var xr: Array = st.rail_x
	if absf(o.z - float(st.rail_z)) < 2.4 and o.x > float(xr[0]) - 2.0 and o.x < float(xr[1]) + 2.0:
		return true
	var c: Vector3 = st.pos
	return absf(o.x - c.x) < 9.5 and o.z > c.z - 4.2 and o.z < c.z + 6.4


func apply_unlock(id: String, animate: bool) -> void:
	if id != "cap_station" or built:
		return
	built = true
	_clear_trees(animate)
	_rail()
	w.retire_highland_gate(animate)
	var c: Vector3 = TvBalance.STATION.pos
	var root := Node3D.new()
	root.name = "GrandStation"
	root.position = c
	w.r1.add_child(root)
	_plaza(root)
	var bld := TvModels.make("grand_station")
	root.add_child(bld)
	for k in range(1, 7):
		var st := bld.find_child("stage%d" % k, true, false) as Node3D
		if st:
			st.visible = false
			_stages.append(st)
	_plot = TvModels.make("station_plot")
	root.add_child(_plot)
	_sign = Label3D.new()
	_sign.font = TvFx.font()
	_sign.font_size = 44
	_sign.outline_size = 10
	_sign.modulate = Color(0.25, 0.16, 0.08)
	_sign.outline_modulate = Color(1, 0.95, 0.8)
	_sign.pixel_size = 0.006
	_sign.text = "GRAND TIMBER\nSTATION"
	_sign.position = Vector3(0, 4.25, 5.14)
	_sign.visible = false
	root.add_child(_sign)
	# Collision (ASSETS_M5.md 1.1): both long walls with the walkway arch left open, and the four
	# corner piers. Nothing is enclosed: the hall is open at both ends along the track.
	for wz in [-2.65, 4.65]:
		for wx in [-4.5, 4.5]:
			_block(root, Vector3(6.2, 3.0, 0.3), Vector3(wx, 1.5, wz))
		for px in [-7.6, 7.6]:
			_block(root, Vector3(0.9, 4.8, 0.9), Vector3(px, 2.4, wz))
	for pid in PLATFORMS:
		w._build_site(pid, animate, Vector3(-0.55, 0, 0.1), Vector3(0, 0, 2.4), Vector3(1.1, 2.7, -0.6))
		_porter(pid, animate)
	_refresh(false)
	if animate:
		_announce()


## Right after the purchase: say what the finale is and glide the camera to the first platform.
func _announce() -> void:
	var first: Vector3 = TvBalance.BUILD_SITES.cap_p1.pos
	w.get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if TimberGame.hud:
			TimberGame.hud.toast("Fill one platform in every valley!")
		w._pan_to = first
		var tw := w.create_tween()
		tw.tween_property(w, "_pan_w", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(1.4)
		tw.tween_property(w, "_pan_w", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))


## Guide arrow and hint while the platforms load: this valley's platform first (its porter only
## works while the valley is awake), else the handcar stop on the way to the next one.
func goal(p: Vector3, cur: int) -> Array:
	var left := 0
	var next_pid := ""
	for pid in PLATFORMS:
		if not TimberGame.site_done(pid):
			left += 1
			if next_pid == "":
				next_pid = pid
	if next_pid == "":
		return [null, ""]
	var count := "Station %d/5" % (PLATFORMS.size() - left)
	var here := "cap_p%d" % cur
	var pid := here if cur >= 1 and cur <= 5 and not TimberGame.site_done(here) else next_pid
	var info: Dictionary = TvBalance.BUILD_SITES[pid]
	var item: String = info.goods.keys()[0]
	var need := int(info.goods[item])
	var have := mini(int((TimberGame.sites.get(pid, {}) as Dictionary).get(item, 0)), need)
	var rid := int(info.region)
	var what := "%s %d/%d" % [TvItems.label(item).capitalize(), have, need]
	if rid == cur:
		var to: Vector3 = info.pos
		var near := Vector2(p.x - to.x, p.z - to.z).length() < 6.0
		# The porter only works while this valley is awake: tell the player to stay.
		var tail := ", stay here" if near else " platform"
		return [null if near else to, "%s: %s%s" % [count, what, tail]]
	# Another valley: the arrow points at this valley's handcar stop.
	var stop: Vector3 = (TvBalance.HANDCAR_STOPS[clampi(cur, 1, 5)] as Dictionary).pos
	return [stop, "%s: handcar to %s" % [count, TvBalance.REGIONS[rid].name]]


func _block(root: Node3D, size: Vector3, at: Vector3) -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position = at
	sb.add_child(col)
	root.add_child(sb)


## Sandstone paving under the station (it stands in the forest belt, outside every valley's ground).
func _plaza(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(18.0, 9.4)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TvModels.GROUND["station"])
	mat.uv1_scale = Vector3(18.0 / 4.0, 9.4 / 4.0, 1)
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = Vector3(0, 0.02, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func restore() -> void:
	if built and _all_done() and not TimberGame.complete:
		_finale.call_deferred()


func _all_done() -> bool:
	for pid in PLATFORMS:
		if not TimberGame.site_done(pid):
			return false
	return true


func platform_done(id: String) -> void:
	var info: Dictionary = TvBalance.BUILD_SITES[id]
	if TimberGame.hud:
		TimberGame.hud.toast("%s platform loaded!" % str(TvBalance.REGIONS[int(info.region)].name))
	_refresh(true)
	if _all_done() and not TimberGame.complete:
		w.get_tree().create_timer(1.5).timeout.connect(_finale)


func tick(delta: float) -> void:
	if cutscene and _express:
		w._pan_to = _express.global_position
		w._pan_w = 1.0
		return
	if not built:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_refresh(true)


## Station stages rise with the share of all platform goods delivered.
func _refresh(animate: bool) -> void:
	var have := 0
	var need := 0
	for pid in PLATFORMS:
		var goods: Dictionary = TvBalance.BUILD_SITES[pid].goods
		var got: Dictionary = TimberGame.sites.get(pid, {})
		for item in goods:
			need += int(goods[item])
			have += mini(int(got.get(item, 0)), int(goods[item]))
	# The survey plot stands until the first sixth of the goods is in; then a stage per sixth.
	var n := _stages.size()
	var want := clampi(int(floor(float(have) / maxf(need, 1) * n + 0.0001)), 0, n)
	for k in n:
		var st := _stages[k]
		if k < want and k >= _shown:
			st.visible = true
			if animate:
				st.scale = Vector3(1, 0.01, 1)
				st.create_tween().tween_property(st, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shown = maxi(_shown, want)
	if _plot:
		_plot.visible = _shown == 0
	if _sign:
		_sign.visible = _shown >= n


func _porter(pid: String, animate: bool) -> void:
	var src: Array = PORTER_FROM[pid]
	if not w.machines.has(src[0]):
		return
	var m: Node = w.machines[src[0]]
	var pile: TvItemStack = m.get("pile") if bool(src[1]) else m.get("output")
	var zone: TvZone = m.get("zone") if bool(src[1]) else m.get("out_zone")
	var info: Dictionary = TvBalance.BUILD_SITES[pid]
	var rid := int(info.region)
	var site: TvBuildSite = w.sites[pid]
	var item: String = info.goods.keys()[0]
	var route := func(it: String, _commit: bool = false) -> Array:
		if it != item or site.room(item) <= 0:
			return []
		return [site.intake_of(item), site.zone_of(item).global_position]
	var pw := TvWorker.new().as_router("character-female-f", route, (info.pos as Vector3) + Vector3(2.0, 0, -2.0), "", TvBalance.PORTER_CAP - 6)
	pw.region = rid
	pw.add_source(pile, zone.global_position)
	(w.regions[rid] as TvRegion).add_child(pw)
	if animate:
		TvFx.pop_in(pw)


func _clear_trees(animate: bool) -> void:
	for e in w._station_trees:
		var mm: MultiMesh = e[0]
		var i: int = e[1]
		if animate:
			var xf := mm.get_instance_transform(i)
			var tw := w.create_tween()
			tw.tween_method(func(s: float) -> void:
				mm.set_instance_transform(i, Transform3D(xf.basis.scaled(Vector3.ONE * maxf(s, 0.001)), xf.origin)), 1.0, 0.0, 0.8)
		else:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), mm.get_instance_transform(i).origin))
	w._station_trees.clear()


## The Timber Express line along the forest belt, with a bridge over the river.
func _rail() -> void:
	var st: Dictionary = TvBalance.STATION
	var xr: Array = st.rail_x
	var track := Node3D.new()
	track.name = "ExpressLine"
	w.add_child(track)
	var xf := []
	var along_x := Basis(Vector3.UP, PI * 0.5)
	var x := float(xr[0])
	while x <= float(xr[1]):
		if absf(x - TvWorld.RIVER_X) > 4.6 and absf(x - TvWorld.ROAD_X) > 2.0:
			xf.append(Transform3D(along_x, Vector3(x, 0, float(st.rail_z))))
		x += 4.0
	w._multimesh(TvModels.path("rail"), xf, true, track)
	w._model(TvModels.path("rail_bridge"), Vector3(TvWorld.RIVER_X, 0, float(st.rail_z)), 1.0, 90, track)
	w._model(TvModels.path("rail_road_crossing"), Vector3(TvWorld.ROAD_X, 0, float(st.rail_z)), 1.0, 90, track)


## The Timber Express: out east past Redwood Coast and Frost Peaks, back west past Maple
## Highlands and Birch Bend, and home to the station (Balance.STATION.express_s), camera riding along.
func _finale() -> void:
	if cutscene or TimberGame.complete:
		return
	cutscene = true
	var st: Dictionary = TvBalance.STATION
	var z := float(st.rail_z)
	var home := Vector3((st.pos as Vector3).x, 0, z)
	_express = Node3D.new()
	_express.name = "TimberExpress"
	w.add_child(_express)
	# ASSETS_M5.md 1.3: loco, log tender 3.4 m behind, coaches 3.8 m behind the tender, 4.6 apart.
	_express.add_child(TvModels.make("express_loco"))
	var tender := TvModels.make("express_tender")
	tender.position = Vector3(0, 0, 3.4)
	_express.add_child(tender)
	for k in 2:
		var coach := TvModels.make("express_coach")
		coach.position = Vector3(0, 0, 3.4 + 3.8 + 4.6 * k)
		_express.add_child(coach)
	_express.position = home
	var east := Vector3(66, 0, z)
	var west := Vector3(-66, 0, z)
	var total := home.distance_to(east) + east.distance_to(west) + west.distance_to(home)
	var secs := float(st.express_s)
	TimberSfx.play("bell", 0.0, 0.5)
	if TimberGame.hud:
		TimberGame.hud.toast("The Timber Express is running!")
	var tw := _express.create_tween()
	# Loco front is -Z: facing east = -90 deg, west = +90 deg.
	tw.tween_callback(func() -> void: _express.rotation.y = -PI * 0.5)
	tw.tween_property(_express, "position", east, secs * home.distance_to(east) / total).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_express.rotation.y = PI * 0.5
		TimberSfx.play("bell", -2.0, 0.6))
	tw.tween_property(_express, "position", west, secs * east.distance_to(west) / total)
	tw.tween_callback(func() -> void:
		_express.rotation.y = -PI * 0.5
		TimberSfx.play("bell", -2.0, 0.6))
	tw.tween_property(_express, "position", home, secs * west.distance_to(home) / total).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish)


func _finish() -> void:
	cutscene = false
	w.cam_offset = Vector3(0, 8.4, 6.6)
	if _express:
		_express.queue_free()
		_express = null
	w._pan_w = 0.0
	w._cam_pos = w.player.global_position
	TimberGame.complete = true
	TimberGame.save_game()
	for i in 6:
		w.get_tree().create_timer(0.25 * i).timeout.connect(func() -> void:
			TvFx.confetti(w, (TvBalance.STATION.pos as Vector3) + Vector3(randf_range(-3, 3), 6, randf_range(-2, 2))))
	if TimberGame.hud:
		TimberGame.hud.show_finish()
