class_name TvBuildSite
extends Node3D

## A building raised from goods (GDD 7.6 B): one DROP square per item, each taking only its item
## and filling a bar, and a sign with "delivered/need". The building GLB holds stage1..stageN
## meshes; stage k rises from the ground (0.6 s, TRANS_BACK) when k/N of the goods are in.
## The money slot is the unlock pad that placed the site. Delivered counts live in Game.sites.

signal completed(id: String)
## Repeatable site (ship slipway): emitted when the finished ship starts its launch; the slots
## reset at once and the next ship can fill while this one slides into the sea.
signal launched(id: String, hull: Node3D)

const RISE_S := 0.6

var id: String
var goods: Dictionary = {}
var delivered: Dictionary = {}
var stages: Array[Node3D] = []
var done: bool = false
## item -> {"zone": Zone, "intake": ItemStack}
var slots: Dictionary = {}
var _plot: Node3D
var _building: Node3D
var _sign: Label3D
var _shown: int = 0
var _sign_text: String = ""
## Ship slipways (GDD 7.6 B): reset after each launch, at most one launch per SHIP_MIN_INTERVAL.
var repeat: bool = false
var _since_launch: float = 1e9
var _wait_shown: int = -1


## slot_origin/slot_step: site-local offsets of the first slot square and between squares;
## sign_at: site-local spot of the floating "delivered/need" sign.
func setup(site_id: String, info: Dictionary, slot_origin: Vector3, slot_step: Vector3, sign_at: Vector3) -> TvBuildSite:
	id = site_id
	name = "Site_" + site_id
	goods = info.goods
	repeat = bool(info.get("repeat", false))
	var saved: Dictionary = TimberGame.sites.get(id, {})
	for item in goods:
		delivered[item] = mini(int(saved.get(item, 0)), int(goods[item]))
	var building := TvModels.make(str(info.model))
	add_child(building)
	_building = building
	var n := int(info.stages)
	for k in range(1, n + 1):
		var st := building.find_child("stage%d" % k, true, false) as Node3D
		if st:
			stages.append(st)
	# Platforms and slipways have no village plot.
	if int(info.stages) > 0 and not repeat:
		_plot = TvModels.make("build_plot")
		add_child(_plot)
	var i := 0
	for item in goods:
		var intake := TvItemStack.new().setup(item, 999, 1, 1)
		intake.position = Vector3(0, 1.2, 0)
		add_child(intake)
		var label := TvItems.label(str(item))
		var z := TvZone.new().setup(TvZone.Kind.DROP, intake, Vector2(1.8, 1.8), label, Color(1, 1, 1))
		z.position = slot_origin + slot_step * i
		# Smaller name under the square, so it stays clear of the next square.
		if z.label:
			z.label.font_size = 40
			z.label.pixel_size = 0.0075
			z.label.position.z = 1.15
		add_child(z)
		slots[item] = {"zone": z, "intake": intake}
		i += 1
	_sign = Label3D.new()
	_sign.font = TvFx.font()
	_sign.font_size = 40
	_sign.outline_size = 12
	_sign.modulate = Color(1, 0.97, 0.88)
	_sign.outline_modulate = Color(0.3, 0.18, 0.08)
	_sign.pixel_size = 0.006
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Floats over the front of the plot and stays readable while the walls rise around it.
	_sign.no_depth_test = true
	_sign.render_priority = 2
	_sign.position = sign_at
	add_child(_sign)
	_refresh(false)
	return self


## Fraction of all goods delivered.
func fraction() -> float:
	var have := 0
	var need := 0
	for item in goods:
		have += int(delivered[item])
		need += int(goods[item])
	return float(have) / maxf(need, 1)


## Room left in an item's slot (0 = full or not part of this site).
func room(item: String) -> int:
	if done or not goods.has(item):
		return 0
	return int(goods[item]) - int(delivered[item]) - (slots[item].intake as TvItemStack).count()


func intake_of(item: String) -> TvItemStack:
	return slots[item].intake


func zone_of(item: String) -> TvZone:
	return slots[item].zone


func _process(delta: float) -> void:
	if done:
		return
	if repeat:
		_since_launch += delta
		if fraction() >= 1.0:
			var left := int(ceil(TvBalance.SHIP_MIN_INTERVAL - _since_launch))
			if left <= 0:
				_launch()
			elif left != _wait_shown:
				_wait_shown = left
				_sign.text = "Next ship in 0:%02d" % left
				_sign.visible = true
	var changed := false
	for item in slots:
		var intake: TvItemStack = slots[item].intake
		intake.capacity = maxi(int(goods[item]) - int(delivered[item]), 0)
		# Items that have landed in the building are used up (a belt load already on its way when
		# the slot filled is used up, not counted twice).
		var got := intake.take_landed()
		if got > 0:
			delivered[item] = mini(int(delivered[item]) + got, int(goods[item]))
			changed = true
	if changed:
		_refresh(true)


func _refresh(animate: bool) -> void:
	var saved := {}
	for item in goods:
		saved[item] = int(delivered[item])
		var z: TvZone = slots[item].zone
		z.set_progress(float(delivered[item]) / maxf(int(goods[item]), 1))
		z.visible = int(delivered[item]) < int(goods[item])
	TimberGame.sites[id] = saved
	var f := fraction()
	var want := mini(int(floor(f * stages.size() + 0.0001)), stages.size())
	for k in stages.size():
		var st := stages[k]
		if k < want and k >= _shown:
			st.visible = true
			if animate:
				st.scale = Vector3(1, 0.01, 1)
				var tw := st.create_tween()
				tw.tween_interval(0.15 * (k - _shown))
				tw.tween_property(st, "scale", Vector3.ONE, RISE_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				TimberSfx.play("wood", -4.0, 0.8)
				TimberSfx.play("tree_fall", -10.0, 1.4, 0.1)
				_dust()
			else:
				st.scale = Vector3.ONE
		elif k >= want:
			st.visible = false
	_shown = maxi(_shown, want)
	if _plot:
		_plot.visible = want == 0
	var lines := PackedStringArray()
	for item in goods:
		if int(delivered[item]) < int(goods[item]):
			lines.append("%s %d/%d" % [TvItems.label(str(item)), int(delivered[item]), int(goods[item])])
	var txt := "\n".join(lines)
	if txt != _sign_text:
		_sign_text = txt
		_sign.text = txt
	_sign.visible = txt != ""
	if f >= 1.0 and repeat:
		return
	if f >= 1.0 and not done:
		done = true
		for item in slots:
			(slots[item].zone as TvZone).remove_from_group("zones")
		# Finished: the stages bake into one mesh (one draw) once the last one has risen.
		if animate:
			get_tree().create_timer(RISE_S + 0.2).timeout.connect(func() -> void: TvMeshMerge.merge(_building))
			completed.emit(id)
		else:
			TvMeshMerge.merge(_building)


## Repeatable site: a copy of the finished hull goes to World for the launch slide, and the
## site starts over (every slot empty, every stage down).
func _launch() -> void:
	_since_launch = 0.0
	_wait_shown = -1
	var hull := _building.duplicate() as Node3D
	add_child(hull)
	for item in goods:
		delivered[item] = 0
	for st in stages:
		st.visible = false
	_shown = 0
	_refresh(false)
	launched.emit(id, hull)


## 12 dust puffs at the base of a rising stage (GDD 11).
func _dust() -> void:
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(2.2, 0.1, 2.0)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -1.5, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var m := SphereMesh.new()
	m.radius = 0.18
	m.height = 0.36
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.72, 0.56, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	p.position = Vector3(0, 0.2, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
