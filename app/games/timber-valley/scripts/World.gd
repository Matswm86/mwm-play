class_name TvWorld
extends Node3D

## Builds the valley: lighting, ground, river, forests, buildings, unlock pads and the camera.

const ROAD_X := 17.0
const GROUND_SHADER := preload("res://games/timber-valley/scripts/ground.gdshader")
const WATER_SHADER := preload("res://games/timber-valley/scripts/water.gdshader")
const ROOF_SHADER := preload("res://games/timber-valley/scripts/roof.gdshader")
const IMPOSTER_SHADER := preload("res://games/timber-valley/scripts/imposter.gdshader")
const RIVER_X := -27.0
const RIVER_HALF := 3.2
## Scenery MultiMeshes are split into square chunks of this size (m) so off-screen ones cull.
const CHUNK_SIZE := 16.0
## Chunks further than this from the camera are hidden (m).
const CHUNK_VIS_END := 60.0
## Ground-scatter atlas: cells of DECO_CELL px with a DECO_PAD gutter, DECO_COLS per row.
const DECO_CELL := 256
const DECO_PAD := 8
const DECO_COLS := 5

## Pads live in Balance.UNLOCKS (kept here as an alias for older callers).
const UNLOCKS := TvBalance.UNLOCKS
## Border-forest imposter atlas: kind order = border_trees_atlas.json, cell = kind_index * 4 + facing.
const IMPOSTER_KINDS := [
	"tree_pineTallA_detailed", "tree_pineTallB_detailed", "tree_pineTallC_detailed", "tree_pineTallD_detailed",
	"tree_pineRoundA", "tree_pineRoundC", "tree_default_dark", "tree_default", "tree_detailed", "tree_oak",
	"tree_fat", "tree_pineDefaultB", "tree_birchA", "tree_birchB", "tree_birchC",
]
## Maple Highlands edge atlas (border_trees_atlas_m2.json): 4 x 4 cells, cell = kind_index * 4 + facing.
const IMPOSTER_KINDS_M2 := ["tree_mapleA", "tree_mapleB", "tree_mapleC", "tree_pineTallB_detailed"]
## Redwood Coast and Frost Peaks edge atlases (4 x 4 cells each): bucket keys "m3:<kind>", "m4:<kind>".
const IMPOSTER_KINDS_M3 := ["tree_redwoodA", "tree_redwoodB", "tree_redwoodC", "tree_pineTallB_detailed"]
const IMPOSTER_KINDS_M4 := ["tree_frostfirA", "tree_frostfirB", "tree_frostfirC", "tree_frostfirD"]
## false = the old chunked _far meshes (fallback).
const USE_IMPOSTERS := true
## Birch Bend layout (world coords, GDD 9.2; nudged off paths where noted).
const V2_GROVE1 := Vector3(-55, 0, -2)
const V2_GROVE2 := Vector3(-55, 0, 6)
const V2_GROVE_NORTH := Vector3(-62, 0, -31)
const V2_GROVE_WEST := Vector3(-71, 0, -20)
const V2_MARKET := Vector3(-40, 0, 6)
const V2_LATHE := Vector3(-45, 0, -6)
const V2_PRESS := Vector3(-45, 0, -18)
const V2_PRESS2 := Vector3(-45, 0, -28)
const V2_BOATSHOP := Vector3(-41.5, 0, -38)
const V2_BARGE := Vector3(-33, 0, -36)
const V2_OFFICE := Vector3(-34, 0, 10.2)
const V2_BOATHOUSE := Vector3(-68, 0, 6)
## Flume: hopper (the DROP square) and the water route to the lathe input pile.
const V2_CHUTE := Vector3(-60.7, 0, -24)
const V2_FLUME_PTS := [Vector3(-60.7, 0, -24), Vector3(-51.5, 0, -24), Vector3(-51.5, 0, -6), Vector3(-48.0, 0, -6)]
## Opening in the river walls for the bridge (z range).
const BRIDGE_Z := -6.0
const BRIDGE_HALF := 1.3
## Offline earnings coin pile next to the Valley 1 office.
const OFFLINE_PILE := Vector3(-0.6, 0, 11.0)
## Maple Highlands layout (world coords, GDD 9.2 and the CSV, nudged as listed in GDD "M2 layout").
const V3_GROVE1 := Vector3(-7, 0, -65)
const V3_GROVE2 := Vector3(-8, 0, -72)
const V3_GROVE_NORTH := Vector3(-7, 0, -101)
const V3_GROVE_RIDGE := Vector3(2, 0, -114)
const V3_BEAMSAW := Vector3(2.5, 0, -64.5)
const V3_PLANER := Vector3(2.5, 0, -78)
const V3_KITFACTORY := Vector3(6, 0, -90)
const V3_MARKET := Vector3(11.5, 0, -66)
const V3_OFFICE := Vector3(6.5, 0, -59.5)
## Rail platform turned 90 deg (designer flag a): the track runs east-west at z V3_RAIL_Z, north of
## the road end, instead of along the road. The train comes in from the east and backs out.
const V3_RAIL_DOCK := Vector3(9.5, 0, -101.5)
const V3_RAIL_Z := -105.0
const V3_RAIL_WEST := 1.0
## Highland Gate in the Home Valley north palisade; the corridor through the border forest.
const GATE3 := Vector3(0, 0, -46.6)
const GATE3_HALF := 1.4
const V3_SOUTH := -55.0
const V3_NORTH := -119.0

var rng := RandomNumberGenerator.new()
var shop: TvShop
var machines: Dictionary = {}
var forests: Dictionary = {
	"a": [], "pine": [], "birch": [], "birch_north": [], "birch_west": [],
	"maple": [], "maple_north": [], "maple_ridge": [],
	"redwood": [], "redwood_north": [], "redwood_far": [], "redwood_cliff": [],
	"frost": [], "frost_north": [], "frost_far": [],
}
var pads: Dictionary = {}
var ground_mat: ShaderMaterial
var paths: Array = []
var plazas: Array = []
var camera: Camera3D
var player: TvPlayer
var guide: MeshInstance3D
var office_zone: TvZone
var _cam_pos: Vector3
var _loading: bool = true
var _noise_tex: NoiseTexture2D
## Valleys by id. Everything a valley owns is a child of its Region (sleep/wake, GDD 10).
var regions: Dictionary = {}
var r1: TvRegion
var r2: TvRegion
var r3: TvRegion
var r4: TvRegion
var r5: TvRegion
## Redwood Coast, Frost Peaks and the Grand Timber Station build and run in their own scripts.
var coast: TvRedwoodCoast
var frost: TvFrostPeaks
var station: TvGrandStation
var rng4 := RandomNumberGenerator.new()
var rng5 := RandomNumberGenerator.new()
## While the first three valleys scatter their deco, later valleys' pads, forests and paths are
## ignored, so the grass layout of Valleys 1-3 does not move when later content exists.
var _busy_skip_new: bool = false
## Border-forest imposters on the Station rail line: [MultiMesh, index], cleared when it is built.
var _station_trees: Array = []
## Discard bins built so far, by valley id.
var _bins: Dictionary = {}
var sun: DirectionalLight3D
## Per-valley ground: {"mat": ShaderMaterial, "paths": [], "plazas": []}. paths/plazas above = Valley 1's.
var grounds: Dictionary = {}
## Future belts, flume and buildings in Birch Bend: kept clear of grass and rocks.
var _reserved_lines: Array = []
var _reserved_rects: Array = []
## Valley 2 content uses its own seed so Valley 1's layout does not shift with V2 progress.
var rng2 := RandomNumberGenerator.new()
var shop2: TvShop
var office2_zone: TvZone
var flume_chute: TvItemStack
var flume_zone: TvZone
var _belt_lp: TvConveyor
var _gate_body: StaticBody3D
var _gate_prop: Node3D
var _offline_zone: TvZone
var _offline_pile: TvItemStack
var _offline_label: Label3D
var _cur_region: int = 1
## Camera offset from the focus point (GDD 10: unchanged at (0, 8.4, 6.6)).
var cam_offset: Vector3 = Vector3(0, 8.4, 6.6)
var _chip_timer: float = 0.0
## Ground scatter collected by _scatter_deco*, baked once by _build_deco: [path, xforms, shadows].
var _deco: Array = []
## Gateway glow (arch over the pad, glowing gate, floating motes) per gateway pad id.
var _gateway_fx: Dictionary = {}
## Camera pan to the next gateway after the valley card closes: 0 = on the player, 1 = on the pad.
var _pan_w: float = 0.0
var _pan_to: Vector3 = Vector3.ZERO
## Maple Highlands (Valley 3).
var rng3 := RandomNumberGenerator.new()
var shop3: TvShop
var office3_zone: TvZone
var sites: Dictionary = {}
var forklift: TvWorker
var _gate3_body: StaticBody3D
var _gate3_doors: Node3D
## The Highland Gate arch (retired when the Grand Timber Station takes its place).
var _gate3_model: Node3D
var _rent_t: float = 0.0
var _rent_carry: float = 0.0
## Handcar stops by valley id (built with the Highland Gate) and the tile hold timers.
var _stops: Dictionary = {}
var _tile_hold: Dictionary = {}


func _ready() -> void:
	TimberGame.world = self
	add_child(TvShadowCull.new())
	rng.seed = 20260929
	rng2.seed = 20261001
	rng3.seed = 20261002
	rng4.seed = 20261003
	rng5.seed = 20261004
	_environment()
	_make_regions()
	coast = TvRedwoodCoast.new(self)
	frost = TvFrostPeaks.new(self)
	station = TvGrandStation.new(self)
	_ground()
	_river()
	_road()
	coast.sea()
	_base_paths()
	_reserve_v2()
	_reserve_v3()
	_border_forest()
	_build_forest("a", Vector3(-9, 0, 1.0), 3, 2, 2.5, "broad")
	_build_sawmill1()
	_build_shop()
	player = TvPlayer.new()
	player.position = Vector3(0, 0, 4)
	add_child(player)
	_camera()
	_guide_arrow()
	for u in UNLOCKS:
		if TimberGame.is_unlocked(u.id):
			_apply_unlock(u.id, false)
	if TimberGame.is_unlocked("r3_gate"):
		_rebuild_handcar_stops(false)
	frost.build_rail_v3()
	station.restore()
	_refresh_pads()
	_busy_skip_new = true
	_scatter_deco()
	_scatter_deco_v2()
	_scatter_deco_v3()
	_busy_skip_new = false
	_filter_deco_v123()
	coast.reserve()
	frost.reserve()
	coast.scatter()
	frost.scatter()
	_build_deco()
	_update_ground_uniforms()
	_bounds()
	_palisades()
	_palisades_v2()
	_palisades_v3()
	coast.palisades()
	frost.palisades()
	_build_offline_pile()
	_update_regions(0.0, true)
	_build_bins()
	TimberGame.unlocked.connect(_on_unlocked)
	_loading = false


# ---------------------------------------------------------------- environment

func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.62, 0.95)
	sm.sky_horizon_color = Color(0.82, 0.9, 0.95)
	sm.ground_horizon_color = Color(0.78, 0.86, 0.9)
	sm.ground_bottom_color = Color(0.4, 0.5, 0.4)
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.84, 0.9)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 30.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_opacity = 0.85
	add_child(sun)
	self.sun = sun


func _make_regions() -> void:
	for rid in TvBalance.REGIONS:
		var r := TvRegion.new().setup(int(rid))
		add_child(r)
		regions[int(rid)] = r
	r1 = regions[1]
	r2 = regions[2]
	r3 = regions[3]
	r4 = regions[4]
	r5 = regions[5]


## One ground plane and material per valley (the shader holds 32 paths and 24 plazas each).
## Valley 1 covers x > river centre, Birch Bend x < river centre (the river hides the seam), and
## Maple Highlands everything north of z -47 (the seam runs under the north palisade and gate).
func _ground() -> void:
	_noise_tex = NoiseTexture2D.new()
	_noise_tex.seamless = true
	_noise_tex.width = 256
	_noise_tex.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 3
	_noise_tex.noise = fn
	var detail := NoiseTexture2D.new()
	detail.seamless = true
	detail.width = 256
	detail.height = 256
	var fn2 := FastNoiseLite.new()
	fn2.frequency = 0.12
	fn2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.noise = fn2
	# Valleys 4 and 5 take everything east of x 21 (the seam runs under the border forest
	# between the road wall and their west palisade).
	var planes := {
		1: Rect2(RIVER_X, -47.0, 21.0 - RIVER_X, 117.0),
		2: Rect2(-110.0, -47.0, RIVER_X + 110.0, 117.0),
		3: Rect2(-110.0, -145.0, 131.0, 98.0),
		4: Rect2(21.0, -47.0, 120.0, 117.0),
		5: Rect2(21.0, -145.0, 120.0, 98.0),
	}
	for rid in planes:
		var mat := ShaderMaterial.new()
		mat.shader = GROUND_SHADER
		mat.set_shader_parameter("noise_tex", _noise_tex)
		mat.set_shader_parameter("detail_tex", detail)
		mat.set_shader_parameter("river_x", RIVER_X)
		mat.set_shader_parameter("river_half", RIVER_HALF)
		mat.set_shader_parameter("grass_tex", load(TvModels.GROUND[rid]))
		if rid == 4:
			coast.ground_look(mat)
		elif rid == 5:
			frost.ground_look(mat)
		mat.set_shader_parameter("dirt_tex", load(TvModels.GROUND["dirt"]))
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		var rect: Rect2 = planes[rid]
		pm.size = rect.size
		pm.subdivide_width = 2
		pm.subdivide_depth = 2
		mi.mesh = pm
		mi.material_override = mat
		var c := rect.get_center()
		mi.position = Vector3(c.x, 0, c.y)
		# The ground only receives shadows; casting would add a shadow-pass draw for nothing.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		grounds[rid] = {"mat": mat, "paths": [], "plazas": []}
	ground_mat = grounds[1].mat
	paths = grounds[1].paths
	plazas = grounds[1].plazas
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	sb.add_child(col)
	add_child(sb)


func _river() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	# Runs on north past the Highlands (z 70 to -145) so it never ends in view.
	pm.size = Vector2(RIVER_HALF * 2.0 + 1.0, 215)
	pm.subdivide_depth = 76
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("noise_tex", _noise_tex)
	mi.material_override = mat
	mi.position = Vector3(RIVER_X, 0.06, -37.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# One-piece v3 bridge (ASSETS_LEFTOVER.md 2.12): deck top y 0.10, 2.6 m walkway, handrails
	# inside the corridor walls.
	var bridge := _model(TvModels.path("bridge_river"), Vector3(RIVER_X, 0, BRIDGE_Z), 1.0)
	bridge.name = "Bridge"


func _road() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.6, 170)
	mi.mesh = pm
	# Painted road tile (ASSETS_LEFTOVER.md 2.13): full width x 4 m, one cream dash per tile.
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _road_texture()
	mat.uv1_scale = Vector3(1, 170.0 / 4.0, 1)
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.95
	mi.material_override = mat
	mi.position = Vector3(ROAD_X, 0.03, -15)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	paths.append([Vector4(ROAD_X, 70, ROAD_X, -100), 2.6])


## The road tile with mipmaps built here (import settings are not in git), so the dashes do
## not shimmer in the distance.
func _road_texture() -> Texture2D:
	var tex: Texture2D = load(TvModels.ROAD_TILE)
	var img := tex.get_image()
	if img == null:
		return tex
	if img.has_mipmaps():
		return tex
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _base_paths() -> void:
	paths.append([Vector4(0, 12, 0, -44), 1.0])
	paths.append([Vector4(-9, 1, 0, -1.5), 0.8])
	paths.append([Vector4(2.5, -3.5, 8.5, 3), 0.8])
	paths.append([Vector4(8.5, -1.2, ROAD_X, -1.2), 0.9])
	plazas.append(Vector4(0, -4, 4.8, 2.2))
	plazas.append(Vector4(10.5, 2.5, 3.2, 5.6))


func _bounds() -> void:
	var bank_e := RIVER_X + RIVER_HALF + 0.3
	var bank_w := RIVER_X - RIVER_HALF - 0.3
	var z0 := BRIDGE_Z - BRIDGE_HALF
	var z1 := BRIDGE_Z + BRIDGE_HALF
	# Both river banks are walls except at the bridge; the corridor walls keep you on the bridge.
	for x in [bank_e, bank_w]:
		_wall(Vector2(x, 70), Vector2(x, z1))
		_wall(Vector2(x, z0), Vector2(x, -125))
	_wall(Vector2(bank_w, z0 - 0.1), Vector2(bank_e, z0 - 0.1))
	_wall(Vector2(bank_w, z1 + 0.1), Vector2(bank_e, z1 + 0.1))
	# Road wall, open only at the Level Crossing (z -20) once it is bought.
	_wall(Vector2(ROAD_X + 2.2, 70), Vector2(ROAD_X + 2.2, TvRedwoodCoast.CROSSING_Z + TvRedwoodCoast.CROSSING_HALF))
	_wall(Vector2(ROAD_X + 2.2, TvRedwoodCoast.CROSSING_Z - TvRedwoodCoast.CROSSING_HALF), Vector2(ROAD_X + 2.2, -125))
	coast.bounds()
	frost.bounds()
	_wall(Vector2(-80, 15.5), Vector2(40, 15.5))
	# North edge of Home Valley and Birch Bend, open only at the Highland Gate.
	var gx := GATE3_HALF + 0.5
	_wall(Vector2(-80, -47), Vector2(-gx, -47))
	_wall(Vector2(gx, -47), Vector2(40, -47))
	_wall(Vector2(-79.3, 20), Vector2(-79.3, -50))
	# Maple Highlands: a corridor through the border forest, the south and north edges.
	for x in [-gx, gx]:
		_wall(Vector2(x, -47), Vector2(x, V3_SOUTH))
	_wall(Vector2(-24, V3_SOUTH), Vector2(-gx, V3_SOUTH))
	_wall(Vector2(gx, V3_SOUTH), Vector2(ROAD_X + 2.4, V3_SOUTH))
	_wall(Vector2(-24, V3_NORTH), Vector2(ROAD_X + 2.4, V3_NORTH))
	# Closed gate in the Valley 1 bank until the River Bridge is bought.
	if not TimberGame.is_unlocked("r2_bridge"):
		_gate_body = _wall(Vector2(bank_e, z0), Vector2(bank_e, z1))
	# Closed Highland Gate until it is bought.
	if not TimberGame.is_unlocked("r3_gate"):
		_gate3_body = _wall(Vector2(-gx, -47), Vector2(gx, -47))


func _wall(a: Vector2, b: Vector2) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(maxf(absf(b.x - a.x), 1.0), 2, maxf(absf(b.y - a.y), 1.0))
	col.shape = bs
	sb.position = Vector3((a.x + b.x) * 0.5, 1, (a.y + b.y) * 0.5)
	sb.add_child(col)
	add_child(sb)
	return sb


func _update_ground_uniforms() -> void:
	for rid in grounds:
		var g: Dictionary = grounds[rid]
		var mat: ShaderMaterial = g.mat
		var ps: Array[Vector4] = []
		var ws: Array[float] = []
		for p in g.paths:
			ps.append(p[0])
			ws.append(p[1])
		while ps.size() < 32:
			ps.append(Vector4.ZERO)
			ws.append(-10.0)
		mat.set_shader_parameter("paths", ps)
		mat.set_shader_parameter("path_widths", PackedFloat32Array(ws))
		mat.set_shader_parameter("path_count", mini(g.paths.size(), 32))
		var pl: Array[Vector4] = []
		for p in g.plazas:
			pl.append(p)
		while pl.size() < 24:
			pl.append(Vector4(9999, 9999, 0, 0))
		mat.set_shader_parameter("plazas", pl)
		mat.set_shader_parameter("plaza_count", mini(g.plazas.size(), 24))


# ---------------------------------------------------------------- helpers

func _model(path: String, pos: Vector3, scl: float, rot_y: float = 0.0, parent: Node3D = null) -> Node3D:
	var inst: Node3D = load(path).instantiate()
	inst.position = pos
	inst.scale = Vector3.ONE * scl
	inst.rotation_degrees.y = rot_y
	(parent if parent else self).add_child(inst)
	return inst


func _first_mesh(path: String) -> Array:
	var inst: Node3D = load(path).instantiate()
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	var out := []
	if not mis.is_empty():
		var mi: MeshInstance3D = mis[0]
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != inst and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		out = [mi.mesh, xf]
	inst.free()
	return out


func _multimesh(path: String, xforms: Array, shadows: bool = true, parent: Node3D = null) -> void:
	if xforms.is_empty():
		return
	var mm_info := _first_mesh(path)
	if mm_info.is_empty():
		return
	# Godot culls a MultiMesh only as a whole, so bucket instances into CHUNK_SIZE squares.
	var chunks := {}
	for x in xforms:
		var xf: Transform3D = x
		var key := Vector2i(floori(xf.origin.x / CHUNK_SIZE), floori(xf.origin.z / CHUNK_SIZE))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(xf)
	var mesh: Mesh = mm_info[0]
	var local: Transform3D = mm_info[1]
	var mesh_aabb := mesh.get_aabb()
	for key in chunks:
		var list: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		var box := AABB()
		for i in list.size():
			var t: Transform3D = (list[i] as Transform3D) * local
			mm.set_instance_transform(i, t)
			var b := t * mesh_aabb
			box = b if i == 0 else box.merge(b)
		mm.custom_aabb = box
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = CHUNK_VIS_END
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(parent if parent else self).add_child(mmi)


## Ground scatter (grass, flowers, small rocks, bushes, reeds, lily pads) is baked per 16 m chunk
## into two meshes that share one texture atlas: one double-sided without shadows, one with
## shadows (bushes, big rocks). Was one MultiMesh per kind per chunk (14+ draws per chunk).
func _build_deco() -> void:
	var kinds := {}
	for e in _deco:
		var path: String = e[0]
		if kinds.has(path):
			continue
		var info := _first_mesh(path)
		if info.is_empty():
			continue
		kinds[path] = {"mesh": info[0], "local": info[1]}
	var atlas := _deco_atlas(kinds)
	if atlas == null:
		for e in _deco:
			_multimesh(e[0], e[1], e[2])
		return
	var size := Vector2(atlas.get_width(), atlas.get_height())
	var inner := float(DECO_CELL - DECO_PAD * 2)
	var base_mat: BaseMaterial3D = null
	for path in kinds:
		var k: Dictionary = kinds[path]
		var src: Mesh = k.mesh
		if base_mat == null:
			base_mat = src.surface_get_material(0) as BaseMaterial3D
		var arr := src.surface_get_arrays(0)
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var cell: Vector2 = k.cell
		for i in uvs.size():
			uvs[i] = (cell + uvs[i] * inner) / size
		arr[Mesh.ARRAY_TEX_UV] = uvs
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		k["remapped"] = am
	var tools := {}
	for e in _deco:
		if not kinds.has(e[0]):
			continue
		var k: Dictionary = kinds[e[0]]
		# One mesh per chunk, no shadow (draw budget, 2026-10-03): bushes and big rocks used to
		# be a second, shadow-casting mesh per chunk; their baked contact AO stays.
		var sh: int = 0
		for x in e[1]:
			var xf: Transform3D = x
			var key := Vector3i(floori(xf.origin.x / CHUNK_SIZE), floori(xf.origin.z / CHUNK_SIZE), sh)
			if not tools.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = st
			(tools[key] as SurfaceTool).append_from(k.remapped, 0, xf * (k.local as Transform3D))
	var mat_open := base_mat.duplicate() as BaseMaterial3D
	mat_open.albedo_texture = atlas
	mat_open.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_solid := base_mat.duplicate() as BaseMaterial3D
	mat_solid.albedo_texture = atlas
	mat_solid.cull_mode = BaseMaterial3D.CULL_BACK
	for key in tools:
		var kk: Vector3i = key
		var mi := MeshInstance3D.new()
		mi.name = "Deco_%d_%d_%d" % [kk.x, kk.y, kk.z]
		mi.mesh = (tools[key] as SurfaceTool).commit()
		mi.material_override = mat_solid if kk.z == 1 else mat_open
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kk.z == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = CHUNK_VIS_END
		add_child(mi)
		TvShadowCull.track(mi)
	_deco.clear()


## Valley 1-3 scatter that now lands inside Redwood Coast (its strip east of the road), on the
## Level Crossing, the Station rail line and pad, or under the bigger handcar stops is removed
## after the fact, so the random draws (and every other tuft) stay where they were.
func _filter_deco_v123() -> void:
	var circles := []
	for id in ["r4_crossing", "cap_station"]:
		for u in UNLOCKS:
			if u.id == id:
				circles.append([Vector2(u.pad.x, u.pad.z), 2.6])
	var rects := [
		Rect2(22.6, -47.5, 60.0, 64.0),
		Rect2(ROAD_X + 1.0, TvRedwoodCoast.CROSSING_Z - 2.0, 6.0, 4.0),
		Rect2(-76.0, TvBalance.STATION.rail_z - 1.6, 152.0, 3.2),
	]
	for rid in TvBalance.HANDCAR_STOPS:
		var st: Vector3 = TvBalance.HANDCAR_STOPS[rid].pos
		rects.append(Rect2(st.x - 5.0, st.z - 1.6, 10.0, 3.6))
	for e in _deco:
		var keep := []
		for x in e[1]:
			var o: Vector3 = (x as Transform3D).origin
			var q := Vector2(o.x, o.z)
			var cut := false
			for r in rects:
				if (r as Rect2).has_point(q):
					cut = true
					break
			if not cut:
				for c in circles:
					if q.distance_to(c[0]) < float(c[1]):
						cut = true
						break
			if not cut:
				keep.append(x)
		e[1] = keep


## Packs every scatter kind's texture into one atlas (DECO_CELL cells; each cell's gutter is the
## same texture stretched, so mip levels do not bleed in a neighbour's colours). Null on failure.
func _deco_atlas(kinds: Dictionary) -> ImageTexture:
	var rows := ceili(float(kinds.size()) / DECO_COLS)
	var img := Image.create_empty(DECO_COLS * DECO_CELL, rows * DECO_CELL, false, Image.FORMAT_RGBA8)
	var inner := DECO_CELL - DECO_PAD * 2
	var i := 0
	for path in kinds:
		var m := (kinds[path].mesh as Mesh).surface_get_material(0) as BaseMaterial3D
		if m == null or m.albedo_texture == null:
			return null
		var src := m.albedo_texture.get_image()
		if src == null:
			return null
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var o := Vector2i((i % DECO_COLS) * DECO_CELL, (i / DECO_COLS) * DECO_CELL)
		var bg := src.duplicate() as Image
		bg.resize(DECO_CELL, DECO_CELL, Image.INTERPOLATE_BILINEAR)
		img.blit_rect(bg, Rect2i(0, 0, DECO_CELL, DECO_CELL), o)
		var fg := src.duplicate() as Image
		fg.resize(inner, inner, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(fg, Rect2i(0, 0, inner, inner), o + Vector2i(DECO_PAD, DECO_PAD))
		kinds[path]["cell"] = Vector2(o + Vector2i(DECO_PAD, DECO_PAD))
		i += 1
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _busy(p: Vector2, margin: float) -> bool:
	var lines: Array = _reserved_lines.duplicate()
	var rects: Array = _reserved_rects.duplicate()
	for rid in grounds:
		if _busy_skip_new and int(rid) >= 4:
			continue
		lines.append_array(grounds[rid].paths)
		rects.append_array(grounds[rid].plazas)
	for pa in lines:
		var s: Vector4 = pa[0]
		var a := Vector2(s.x, s.y)
		var b := Vector2(s.z, s.w)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < float(pa[1]) + margin:
			return true
	for pl in rects:
		var v: Vector4 = pl
		if absf(p.x - v.x) < v.z + margin + 0.6 and absf(p.y - v.y) < v.w + margin + 0.6:
			return true
	for u in UNLOCKS:
		if _busy_skip_new and region_of_unlock(u.id) >= 4:
			continue
		var pp: Vector3 = u.pad
		if Vector2(pp.x, pp.z).distance_to(p) < 3.2 + margin:
			return true
	if absf(p.x - RIVER_X) < RIVER_HALF + 0.8:
		return true
	for key in forests:
		if _busy_skip_new and (str(key).begins_with("redwood") or str(key).begins_with("frost")):
			continue
		for t in forests[key]:
			var tp: Vector3 = (t as Node3D).position
			if Vector2(tp.x, tp.z).distance_to(p) < 1.3 + margin:
				return true
	return false


# ---------------------------------------------------------------- scenery

func _border_forest() -> void:
	var kinds := [
		"tree_pineTallA_detailed", "tree_pineTallB_detailed", "tree_pineTallC_detailed",
		"tree_pineTallD_detailed", "tree_pineRoundA", "tree_pineRoundC", "tree_default_dark",
		"tree_default", "tree_detailed", "tree_oak", "tree_fat", "tree_pineDefaultB",
	]
	var birches := ["tree_birchA", "tree_birchB", "tree_birchC"]
	var buckets := {}
	for k in kinds + birches:
		buckets[k] = []
	for k in IMPOSTER_KINDS_M2:
		buckets["m2:" + k] = []
	for k in IMPOSTER_KINDS_M3:
		buckets["m3:" + k] = []
	for k in IMPOSTER_KINDS_M4:
		buckets["m4:" + k] = []
	# Outer edges of the three-valley map plus the strip inside Valley 1's west palisade.
	var areas := [
		Rect2(-101, 18, 161, 16),
		Rect2(-101, -66, 70.5, 18),
		Rect2(-101, -48, 21, 66),
		Rect2(ROAD_X + 3.2, -141, 30, 173),
		Rect2(RIVER_X + RIVER_HALF + 0.8, -50, 5.0, 66),
		# The belt between Home Valley and the Highlands, west across the river, and the north edge.
		Rect2(-23.5, V3_SOUTH, 42.5, 8),
		Rect2(-60, -141, 29.5, 75),
		Rect2(-31, -141, 51, 141 + V3_NORTH),
	]
	for r in areas:
		var rect: Rect2 = r
		var n := int(rect.get_area() / 3.2)
		for i in n:
			var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
			if absf(p.x - RIVER_X) < RIVER_HALF + 1.0:
				continue
			if absf(p.x - ROAD_X) < 3.0:
				continue
			# Keep the way to the River Bridge open.
			if p.x > RIVER_X and p.x < -15.0 and absf(p.y - BRIDGE_Z) < 3.4:
				continue
			# ... and the Highland Gate corridor and the railway into the east forest.
			if p.y < -45.0 and p.y > V3_SOUTH - 1.0 and absf(p.x - GATE3.x) < 3.4:
				continue
			if p.x > ROAD_X and absf(p.y - V3_RAIL_Z) < 2.8:
				continue
			var ki := rng.randi() % kinds.size()
			var k: String = kinds[ki]
			if p.y < -48.0 and p.x > -60.0:
				# Around Maple Highlands: maples and tall pines from the M2 atlas (east of the road:
				# frost firs from the M4 atlas; same draw, so the layout does not move).
				var mi := rng.randi() % IMPOSTER_KINDS_M2.size()
				k = ("m4:" + str(IMPOSTER_KINDS_M4[mi])) if p.x > ROAD_X + 2.0 else ("m2:" + str(IMPOSTER_KINDS_M2[mi]))
			elif p.x > ROAD_X + 2.0 and p.y < 16.0:
				# Next to Redwood Coast: redwoods from the M3 atlas (picked from the draw above).
				k = "m3:" + str(IMPOSTER_KINDS_M3[ki % IMPOSTER_KINDS_M3.size()])
			elif p.x < RIVER_X and rng.randf() < 0.5:
				# Birch Bend's edges are half birch.
				k = birches[rng.randi() % birches.size()]
			var s := rng.randf_range(2.4, 3.6)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y))
			# Redwood Coast and Frost Peaks now stand where this forest was; the draws above
			# still run, so every other tree keeps its place.
			if _border_cut(p):
				continue
			(buckets[k] as Array).append(xf)
	# The forest around Redwood Coast and Frost Peaks (own seed).
	coast.border_forest(buckets, kinds)
	frost.border_forest(buckets, kinds)
	if USE_IMPOSTERS:
		_imposters(buckets)
		return
	for k in buckets:
		var name_k: String = str(k).trim_prefix("m2:")
		var dir := "birch" if name_k.begins_with("tree_birch") else ("maple" if name_k.begins_with("tree_maple") else "nature")
		_multimesh("res://games/timber-valley/assets/models_v3/%s/%s_far.glb" % [dir, name_k], buckets[k])


## Border trees that would stand inside Redwood Coast / Frost Peaks or on their crossings.
func _border_cut(p: Vector2) -> bool:
	for rid in [4, 5]:
		var rect: Rect2 = TvBalance.REGIONS[rid].rect
		if rect.grow(0.2).has_point(p):
			return true
	# Level Crossing corridor through the strip between the road wall and Redwood Coast.
	if p.x > ROAD_X + 1.0 and p.x < 24.0 and absf(p.y - TvRedwoodCoast.CROSSING_Z) < 2.4:
		return true
	return false


## Camera-facing cards from one atlas (ASSETS_M1.md section 5): one MultiMesh per 16 m chunk,
## no Y rotation (the four facings give the variety), no shadows.
func _imposters(buckets: Dictionary) -> void:
	var w := 256.0 / 140.0
	var bottom := -(256.0 - 246.0) / 256.0 * w
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-52.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		[Vector3(-w * 0.5, bottom + w, 0), Vector2(0, 0)], [Vector3(w * 0.5, bottom + w, 0), Vector2(1, 0)],
		[Vector3(w * 0.5, bottom, 0), Vector2(1, 1)], [Vector3(-w * 0.5, bottom, 0), Vector2(0, 1)],
	]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(corners[i][1])
		st.add_vertex(tilt * (corners[i][0] as Vector3))
	var card := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = IMPOSTER_SHADER
	mat.set_shader_parameter("atlas", load(TvModels.IMPOSTER_ATLAS))
	mat.set_shader_parameter("grid", 8.0)
	# Maple Highlands edges use the M2 atlas (4 x 4 cells): a second material.
	# Valley edge atlases (4 x 4 cells): one material each; chunk key z = the atlas index.
	var sets := {"m2:": [IMPOSTER_KINDS_M2, TvModels.IMPOSTER_ATLAS_M2], "m3:": [IMPOSTER_KINDS_M3, TvModels.IMPOSTER_ATLAS_M3], "m4:": [IMPOSTER_KINDS_M4, TvModels.IMPOSTER_ATLAS_M4]}
	var mats: Array = [mat]
	for pre in sets:
		var mx := ShaderMaterial.new()
		mx.shader = IMPOSTER_SHADER
		mx.set_shader_parameter("atlas", load(str(sets[pre][1])))
		mx.set_shader_parameter("grid", 4.0)
		mats.append(mx)
	var chunks := {}
	for k in buckets:
		var ks := str(k)
		var si := 0
		var base: int = IMPOSTER_KINDS.find(k) * 4
		var n := 1
		for pre in sets:
			if ks.begins_with(pre):
				si = n
				base = (sets[pre][0] as Array).find(ks.trim_prefix(pre)) * 4
			n += 1
		for x in buckets[k]:
			var xf: Transform3D = x
			# Drop the random yaw: cards must face the camera. Keep the scale.
			var sc := xf.basis.get_scale().x
			var key := Vector3i(floori(xf.origin.x / CHUNK_SIZE), floori(xf.origin.z / CHUNK_SIZE), si)
			if not chunks.has(key):
				chunks[key] = []
			(chunks[key] as Array).append([Transform3D(Basis().scaled(Vector3.ONE * sc), xf.origin), base + rng.randi() % 4])
	var aabb := card.get_aabb()
	for key in chunks:
		var list: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = card
		mm.instance_count = list.size()
		var box := AABB()
		for i in list.size():
			var t: Transform3D = list[i][0]
			mm.set_instance_transform(i, t)
			mm.set_instance_custom_data(i, Color(float(list[i][1]) / 255.0, 0, 0, 0))
			var b := t * aabb
			box = b if i == 0 else box.merge(b)
			if station.on_clearing(t.origin):
				_station_trees.append([mm, i])
		mm.custom_aabb = box
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[(key as Vector3i).z]
		mmi.visibility_range_end = CHUNK_VIS_END
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _scatter_deco() -> void:
	var sets := [
		["grass", 260, 2.4, false], ["grass_large", 160, 2.4, false], ["grass_leafs", 110, 2.6, false],
		["flower_redA", 110, 2.6, false], ["flower_yellowA", 120, 2.6, false], ["flower_yellowB", 60, 2.4, false],
		["flower_redC", 50, 2.4, false], ["plant_bush", 110, 2.8, true], ["plant_bushDetailed", 90, 2.6, true],
		["rock_smallA", 40, 2.2, false], ["rock_smallC", 40, 2.2, false], ["mushroom_redGroup", 25, 2.2, false],
		["mushroom_tanGroup", 20, 2.2, false], ["rock_largeA", 10, 2.4, true],
	]
	var area := Rect2(RIVER_X - 10, -50, (ROAD_X + 12) - (RIVER_X - 10), 68)
	for s in sets:
		var list := []
		var tries: int = s[1] * 3
		while list.size() < int(s[1]) and tries > 0:
			tries -= 1
			var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			if absf(p.x - ROAD_X) < 2.4:
				continue
			if _busy(p, 0.6):
				continue
			var sc: float = s[2] * rng.randf_range(0.75, 1.3)
			list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, 0, p.y)))
		_deco.append(["res://games/timber-valley/assets/models_v3/nature/%s.glb" % s[0], list, s[3]])
	# Tall rocks and reeds on the river banks.
	var rocks := []
	for i in 26:
		var z := rng.randf_range(-60, 20)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := RIVER_X + side * (RIVER_HALF + rng.randf_range(0.2, 0.9))
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.6, 2.6)), Vector3(x, -0.05, z)))
	_deco.append(["res://games/timber-valley/assets/models_v3/nature/rock_smallD.glb", rocks, false])
	# A few props around the starting yard (baked into one mesh per texture).
	var props := Node3D.new()
	props.name = "YardProps"
	r1.add_child(props)
	_model("res://games/timber-valley/assets/models_v3/nature/log_stackLarge.glb", Vector3(-3.6, 0, -6.8), 2.2, 10, props)
	_model("res://games/timber-valley/assets/models_v3/survival/barrel.glb", Vector3(3.8, 0, -6.4), 2.4, 0, props)
	_model("res://games/timber-valley/assets/models_v3/survival/box-large.glb", Vector3(4.6, 0, -6.6), 2.2, 20, props)
	_model("res://games/timber-valley/assets/models_v3/survival/signpost.glb", Vector3(1.4, 0, 6.0), 2.6, -20, props)
	_model("res://games/timber-valley/assets/models_v3/nature/campfire_logs.glb", Vector3(-4.5, 0, 12.5), 3.0, 0, props)
	for i in 6:
		_model("res://games/timber-valley/assets/models_v3/nature/fence_simple.glb", Vector3(-12.5 + i * 2.0, 0, 13.5), 2.0, 0, props)
	TvMeshMerge.merge(props)


func _build_forest(key: String, center: Vector3, cols: int, rows: int, spacing: float, kind: String, animate: bool = false, region: int = 1) -> void:
	var g: RandomNumberGenerator = [rng, rng, rng2, rng3, rng4, rng5][clampi(region, 0, 5)]
	for r in rows:
		for c in cols:
			var p := center + Vector3((c - (cols - 1) * 0.5) * spacing, 0, (r - (rows - 1) * 0.5) * spacing)
			p += Vector3(g.randf_range(-0.35, 0.35), 0, g.randf_range(-0.35, 0.35))
			var t := TvChopTree.new().setup(kind, g)
			t.position = p
			(regions[region] as TvRegion).add_child(t)
			(forests[key] as Array).append(t)
			if animate:
				TvFx.pop_in(t, 0.5 + 0.05 * (r * cols + c))


# ---------------------------------------------------------------- buildings

func _machine(id: String, pos: Vector3, i_t: String, o_t: String, i_n: int, o_n: int, t: float) -> TvMachine:
	var m := TvMachine.new().setup(id, i_t, o_t, i_n, o_n, t)
	m.position = pos
	machines[id] = m
	return m


func _build_sawmill1() -> void:
	var m := _machine("sawmill1", Vector3(0, 0, -4), "log", "plank", 1, 2, 1.0)
	_dress_sawmill(m, Color(1.0, 0.45, 0.12))
	r1.add_child(m)


func _dress_sawmill(m: TvMachine, frame: Color) -> void:
	m.input.position.x = -3.4
	m.in_zone.position.x = -3.4
	m.output.position.x = 3.4
	m.out_zone.position.x = 3.4
	# v3 body (ASSETS_LEFTOVER.md 2.2): bed, rails, feet, frame, control box and log pile.
	m.add_model(TvModels.path("sawmill_body_orange" if frame.r > 0.6 else "sawmill_body_green"), Vector3.ZERO, 1.0)
	var belt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.05, 4.3)
	belt.mesh = bm
	var bmat := ShaderMaterial.new()
	bmat.shader = TvConveyor.BELT_SHADER
	bmat.set_shader_parameter("length", 4.3)
	bmat.set_shader_parameter("speed", -1.0)
	belt.material_override = bmat
	belt.position = Vector3(0, 0.52, 0.2)
	belt.rotation_degrees.y = 90
	m.body.add_child(belt)
	var saw := TvChainSaw.new()
	saw.bar_len = 1.55
	saw.setup(m, frame)
	saw.rotation_degrees = Vector3(90, 90, 0)
	saw.position = Vector3(0, 1.28, 0.2)
	m.body.add_child(saw)
	m.mouth_in = Vector3(-2.0, 0.55, 0.2)
	m.mouth_out = Vector3(1.9, 0.55, 0.2)
	m.cut_point = Vector3(0, 0.55, 0.2)
	m.add_dust(Vector3(0.1, 0.75, 0.3), Color(0.98, 0.78, 0.45))
	m.dust.amount = 48
	m.dust.initial_velocity_min = 2.5
	m.dust.initial_velocity_max = 5.0
	m.dust.direction = Vector3(0.6, 1, 0.3)
	m.dust.spread = 50
	m.dust.gravity = Vector3(0, -9, 0)
	m.dust.lifetime = 1.0
	(m.dust.mesh as BoxMesh).size = Vector3(0.09, 0.04, 0.05)
	m.add_blocker(Vector3(4.4, 1.2, 1.3), Vector3(0, 0, 0.2))
	TvMeshMerge.merge(m.body)


## Log palisade fences: rows of upright logs around the valley and behind the first forest.
func _palisades() -> void:
	var lines := [
		[Vector2(-23.2, 15.3), Vector2(14.8, 15.3)],
		# North run, open for the Highland Gate (its model is 5.5 m wide).
		[Vector2(-23.2, -46.6), Vector2(-2.8, -46.6)],
		[Vector2(2.8, -46.6), Vector2(14.8, -46.6)],
		[Vector2(-23.2, 15.3), Vector2(-23.2, BRIDGE_Z + BRIDGE_HALF)],
		[Vector2(-23.2, BRIDGE_Z - BRIDGE_HALF), Vector2(-23.2, -46.6)],
		[Vector2(-13.3, -1.5), Vector2(-13.3, 9.5)],
	]
	var xforms := []
	for ln in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		var n := int(a.distance_to(b) / 0.31)
		for k in n + 1:
			var p := a.lerp(b, float(k) / maxf(n, 1))
			var hgt := rng.randf_range(0.95, 1.3)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, hgt, 1))
			basis = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0, 0.04)) * basis
			xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	# v3 post (ASSETS_LEFTOVER.md 2.11): base at y 0, 56 tris, chunked so off-screen runs cull.
	_multimesh(TvModels.path("palisade_post"), xforms, true, r1)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.4, 2, 11)
	col.shape = bs
	sb.position = Vector3(-13.3, 1, 4)
	sb.add_child(col)
	r1.add_child(sb)


func _build_shop() -> void:
	shop = TvShop.new().setup()
	shop.position = Vector3(10, 0, 4)
	shop.road_x = ROAD_X - 10.0
	shop.region_node = r1
	shop.add_shelf("plank", 2.6)
	shop.add_shelf("chair", 0.0)
	shop.add_shelf("table", -2.6)
	r1.add_child(shop)
	shop.open_shelf("plank", false)


func _spawn_lumberjack(look: String, forest: Array, m: TvMachine, home: Vector3, animate: bool) -> void:
	_spawn_jack_to(look, forest, m.input, m.in_zone.global_position, home, animate, 1)


## Lumberjack that delivers to any pile (a machine input or the flume chute).
func _spawn_jack_to(look: String, forest: Array, dst: TvItemStack, dst_pos: Vector3, home: Vector3, animate: bool, region: int) -> void:
	var w := TvWorker.new().as_lumberjack(look, forest, dst, dst_pos, home)
	w.region = region
	(regions[region] as TvRegion).add_child(w)
	if animate:
		TvFx.pop_in(w)


func _spawn_hauler(look: String, src: TvItemStack, src_zone: TvZone, dst: TvItemStack, dst_zone: TvZone, animate: bool, region: int = 1) -> void:
	var w := TvWorker.new().as_hauler(look, src, src_zone.global_position, dst, dst_zone.global_position)
	w.region = region
	(regions[region] as TvRegion).add_child(w)
	if animate:
		TvFx.pop_in(w)


func _apply_unlock(id: String, animate: bool) -> void:
	if id.begins_with("r4_") or id.begins_with("r5_") or id.begins_with("cap_"):
		if id.begins_with("r4_"):
			coast.apply_unlock(id, animate)
		elif id.begins_with("r5_"):
			frost.apply_unlock(id, animate)
		else:
			station.apply_unlock(id, animate)
		if not _loading:
			_update_ground_uniforms()
		return
	if id.begins_with("r2_") or id.begins_with("r3_"):
		if id.begins_with("r2_"):
			_apply_unlock_r2(id, animate)
		else:
			_apply_unlock_r3(id, animate)
		if not _loading:
			_update_ground_uniforms()
		return
	match id:
		"trees2":
			_build_forest("a", Vector3(-9, 0, 6.2), 3, 2, 2.5, "broad", animate)
		"office":
			_build_office(animate)
		"jack1":
			_spawn_lumberjack("character-male-c", forests.a, machines.sawmill1, Vector3(-5, 0, 3), animate)
		"hauler1":
			_spawn_hauler("character-female-d", machines.sawmill1.output, machines.sawmill1.out_zone, shop.shelf("plank"), shop.shelf_zone("plank"), animate)
		"carpentry":
			_build_carpentry(animate)
			shop.open_shelf("chair", animate)
		"hauler3":
			_spawn_hauler("character-male-b", machines.carpentry.output, machines.carpentry.out_zone, shop.shelf("chair"), shop.shelf_zone("chair"), animate)
		"pine":
			_build_forest("pine", Vector3(-13.5, 0, -15), 4, 3, 2.6, "pine", animate)
			paths.append([Vector4(0, -12, -9, -14), 0.7])
		"cashier":
			shop.hire_cashier(animate)
		"sawmill2":
			var m := _machine("sawmill2", Vector3(-3, 0, -24), "log", "plank", 1, 2, 0.8)
			_dress_sawmill(m, Color(0.3, 0.75, 0.3))
			r1.add_child(m)
			plazas.append(Vector4(-3, -24, 4.8, 2.2))
			if animate:
				TvFx.pop_in(m, 0.7)
		"jack2":
			_spawn_lumberjack("character-male-d", forests.pine, machines.sawmill2, Vector3(-8, 0, -20), animate)
		"hauler2":
			_spawn_hauler("character-female-c", machines.sawmill2.output, machines.sawmill2.out_zone, machines.carpentry.input, machines.carpentry.in_zone, animate)
		"cnc":
			_build_cnc(animate)
			shop.open_shelf("table", animate)
		"conveyor1":
			var c := TvConveyor.new().setup(machines.sawmill2.output, machines.cnc.input, PackedVector3Array([
				Vector3(0.4, 0, -25.6), Vector3(6.0, 0, -25.6), Vector3(6.0, 0, -24.4)]))
			r1.add_child(c)
			if animate:
				TvFx.pop_in(c, 0.6)
		"hauler4":
			_spawn_hauler("character-female-b", machines.cnc.output, machines.cnc.out_zone, shop.shelf("table"), shop.shelf_zone("table"), animate)
		"factory":
			_build_factory(animate)
		"jack3":
			forests["north"] = []
			_build_forest("north", Vector3(-13.5, 0, -31), 4, 2, 2.6, "pine", animate)
			_spawn_lumberjack("character-male-a", forests.north, machines.factory, Vector3(-8, 0, -30), animate)
			_spawn_lumberjack("character-female-a", forests.north, machines.factory, Vector3(-8, 0, -32), animate)
		"dock":
			var d := TvTruckDock.new().setup("bookcase", ROAD_X)
			d.region_node = r1
			d.position = Vector3(13.5, 0, -36)
			r1.add_child(d)
			machines["dock"] = d
			plazas.append(Vector4(13.5, -36, 2.6, 3.0))
			paths.append([Vector4(3, -36, 12, -36), 0.8])
			if animate:
				TvFx.pop_in(d, 0.6)
		"conveyor2":
			var d: TvTruckDock = machines.dock
			var c := TvConveyor.new().setup(machines.factory.output, d.pile, PackedVector3Array([
				Vector3(3.9, 0, -37.8), Vector3(14.4, 0, -37.8), Vector3(14.4, 0, -36.6)]))
			r1.add_child(c)
			if animate:
				TvFx.pop_in(c, 0.6)
		"roadsign":
			var sg := Node3D.new()
			sg.position = Vector3(15.0, 0, 10.5)
			r1.add_child(sg)
			# v3 sign (ASSETS_LEFTOVER.md 2.14): board face z +0.07, centre y 2.1.
			sg.add_child(TvModels.make("road_sign"))
			var lbl := Label3D.new()
			lbl.font = TvFx.font()
			lbl.text = "TIMBER\nVALLEY"
			lbl.font_size = 64
			lbl.outline_size = 14
			lbl.modulate = Color(1, 0.96, 0.85)
			lbl.outline_modulate = Color(0.35, 0.2, 0.08)
			lbl.pixel_size = 0.006
			lbl.position = Vector3(0, 2.1, 0.09)
			sg.add_child(lbl)
			TvMeshMerge.merge(sg)
			if animate:
				TvFx.pop_in(sg, 0.6)
		"belt_planks":
			_belt(machines.sawmill1.output, shop.shelf("plank"), [Vector3(4.8, 0, -3.8), Vector3(4.8, 0, 6.6), Vector3(9.1, 0, 6.6)], animate)
		"belt_saw2":
			_belt(machines.sawmill2.output, machines.carpentry.input, [Vector3(0.4, 0, -22.3), Vector3(0.4, 0, -15.2), Vector3(-0.7, 0, -15.2), Vector3(-0.7, 0, -14.2)], animate)
		"belt_chairs":
			_belt(machines.carpentry.output, shop.shelf("chair"), [Vector3(5.9, 0, -12.8), Vector3(5.9, 0, 4.0), Vector3(9.1, 0, 4.0)], animate)
		"megasaw":
			var ms := TvMegaSaw.new().setup()
			ms.position = Vector3(10.2, 0, -13.2)
			r1.add_child(ms)
			machines["megasaw"] = ms
			plazas.append(Vector4(11.0, -12.6, 5.0, 2.8))
			if animate:
				TvFx.pop_in(ms, 0.9)
		"belt_tables":
			_belt(machines.cnc.output, shop.shelf("table"), V1_BELT_TABLES, animate)
		"belt_mega":
			var ms: TvMegaSaw = machines.megasaw
			_belt(ms.output, machines.cnc.input, [Vector3(15.1, 0, -12.9), Vector3(15.1, 0, -27.4), Vector3(6.9, 0, -27.4), Vector3(6.9, 0, -24.7)], animate)
		"lodge":
			_build_lodge(animate)
	if not _loading:
		_update_ground_uniforms()


func _belt(src: TvItemStack, dst: TvItemStack, pts: Array, animate: bool, region: int = 1) -> TvConveyor:
	var c := TvConveyor.new()
	c.region = region
	c.setup(src, dst, PackedVector3Array(pts))
	(regions[region] as TvRegion).add_child(c)
	if animate:
		TvFx.pop_in(c, 0.6)
	return c


func _build_office(animate: bool) -> void:
	var root := Node3D.new()
	root.position = Vector3(-3.5, 0, 12.5)
	r1.add_child(root)
	# v3 hut (ASSETS_LEFTOVER.md 2.3): desk, cash chest and notice board; same 3.2 x 2.4 footprint.
	_model(TvModels.path("office_hut"), Vector3.ZERO, 1.0, 0, root)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 2, 2.4)
	col.shape = bs
	col.position.y = 1
	sb.add_child(col)
	root.add_child(sb)
	TvMeshMerge.merge(root)
	office_zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.4, 2.0), "UPGRADES", Color(0.6, 0.95, 1.0))
	office_zone.position = Vector3(-3.5, 0, 10.0)
	office_zone.on_enter = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.open_upgrades()
	office_zone.on_exit = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.close_upgrades()
	r1.add_child(office_zone)
	plazas.append(Vector4(-3.5, 11.5, 2.4, 2.2))
	if animate:
		TvFx.pop_in(root, 0.6)


func _build_carpentry(animate: bool) -> void:
	var m := _machine("carpentry", Vector3(2, 0, -13), "plank", "chair", 2, 1, 1.4)
	# v3 shed (ASSETS_LEFTOVER.md 2.4): saw bench top y 0.95 with a slot the blade sticks through.
	m.add_model(TvModels.path("carpentry_shed"), Vector3.ZERO, 1.0)
	var saw := m.add_saw_blade(Vector3(0.8, 1.05, 0.35), 0.3)
	saw.rotation_degrees.y = 90
	m.mouth_in = Vector3(-0.8, 1.1, 0.2)
	m.mouth_out = Vector3(1.0, 1.0, 0.2)
	m.add_dust(Vector3(0, 1.1, 0.3), Color(0.9, 0.75, 0.5))
	m.add_blocker(Vector3(3.6, 2.2, 2.6))
	TvMeshMerge.merge(m.body, m.spinners)
	r1.add_child(m)
	plazas.append(Vector4(2, -13, 4.3, 2.0))
	if animate:
		TvFx.pop_in(m, 0.7)


func _build_cnc(animate: bool) -> void:
	var m := _machine("cnc", Vector3(9, 0, -24), "plank", "table", 3, 1, 1.6)
	# v3 gantry router (ASSETS_LEFTOVER.md 2.5); the cog faces the camera and spins about local Z.
	m.add_model(TvModels.path("cnc_router"), Vector3.ZERO, 1.0)
	var cog := m.add_model(TvModels.path("cnc_cog"), Vector3(0, 2.45, 0), 1.0)
	m.spinners.append(cog)
	m.mouth_in = Vector3(-1.1, 1.0, 0)
	m.mouth_out = Vector3(1.1, 0.8, 0)
	m.add_dust(Vector3(0, 1.4, 0.8), Color(0.95, 0.85, 0.65))
	m.add_blocker(Vector3(3.0, 2.2, 2.6))
	TvMeshMerge.merge(m.body, m.spinners)
	r1.add_child(m)
	plazas.append(Vector4(9, -24, 4.3, 2.0))
	paths.append([Vector4(0, -24, 9, -24), 0.7])
	if animate:
		TvFx.pop_in(m, 0.7)


func _build_factory(animate: bool) -> void:
	var m := _machine("factory", Vector3(0, 0, -36), "log", "bookcase", 3, 1, 1.8)
	m.input.position = Vector3(-3.6, 0, 0.3)
	m.in_zone.position = m.input.position
	m.output.position = Vector3(3.6, 0, 0.3)
	m.out_zone.position = m.output.position
	# v3 hall (ASSETS_LEFTOVER.md 2.6): chimney, hopper, saw unit, press and roller table.
	m.add_model(TvModels.path("bookcase_factory"), Vector3.ZERO, 1.0)
	# Arms pivot at the base and reach into the hall (-Z); Machine swings them +-0.9 rad.
	m.arms.append(m.add_model(TvModels.path("factory_arm"), Vector3(-2.3, 0.22, 1.2), 1.0))
	m.arms.append(m.add_model(TvModels.path("factory_arm"), Vector3(2.4, 0.22, 1.2), 1.0))
	m.add_smoke(Vector3(-1.9, 3.8, -1.5))
	m.mouth_in = Vector3(-2.2, 1.4, -0.4)
	m.mouth_out = Vector3(2.2, 0.9, 0.4)
	m.add_blocker(Vector3(5.0, 2.4, 3.2))
	TvMeshMerge.merge(m.body, m.spinners + m.arms)
	r1.add_child(m)
	plazas.append(Vector4(0, -36, 5.6, 2.6))
	if animate:
		TvFx.pop_in(m, 0.8)


func _build_lodge(animate: bool) -> void:
	var root := Node3D.new()
	root.position = Vector3(-12, 0, -39)
	r1.add_child(root)
	# v3 log cabin (ASSETS_LEFTOVER.md 2.7): 7 x 5 walls, red roof, porch, bench and rocking chair.
	_model(TvModels.path("grand_lodge"), Vector3.ZERO, 1.0, 0, root)
	# Warm window panes are emissive, not baked, and cast no shadow.
	var win := _model(TvModels.path("lodge_windows"), Vector3.ZERO, 1.0, 0, root)
	for mi in win.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var w := 7.0
	var d := 5.0
	var smoke := CPUParticles3D.new()
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)
	smoke.position = Vector3(2.2, 6.4, -0.8)
	smoke.amount = 10
	smoke.lifetime = 3.5
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.3, 0.1, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.9, 0.9, 0.9, 0.5)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	smoke.mesh = sm
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w + 0.4, 4, d + 0.4)
	col.shape = bs
	col.position.y = 2
	sb.add_child(col)
	root.add_child(sb)
	TvMeshMerge.merge(root)
	plazas.append(Vector4(-12, -37.5, 5.0, 4.0))
	if animate:
		TvFx.pop_in(root, 1.0)


# ---------------------------------------------------------------- pads + camera

func _refresh_pads() -> void:
	for u in UNLOCKS:
		var id: String = u.id
		if TimberGame.is_unlocked(id) or pads.has(id):
			continue
		var ok := true
		for r in u.req:
			if not TimberGame.is_unlocked(r):
				ok = false
			# A landmark build site opens the next gateway when the building is finished (GDD 6).
			elif TvBalance.LANDMARKS.has(r) and TvBalance.BUILD_SITES.has(r) and not TimberGame.site_done(r):
				ok = false
		if not ok:
			continue
		var big: bool = id in TvBalance.BIG_PADS
		var pad := TvUnlockPad.new().setup(id, u.cost, u.title, Vector2(3.2, 3.2) if big else Vector2(2.4, 2.4))
		pad.position = u.pad
		_pad_region(id).add_child(pad)
		pad.paid.connect(func(pid: String) -> void: TimberGame.unlock(pid))
		pads[id] = pad
		if TvBalance.GATEWAYS.has(id):
			_build_gateway_fx(id)
		if not _loading:
			TvFx.pop_in(pad, 0.5)


func _on_unlocked(id: String) -> void:
	if pads.has(id):
		var pad: TvUnlockPad = pads[id]
		if is_instance_valid(pad) and not pad.is_queued_for_deletion() and pad.paid_amount < pad.cost:
			pad.queue_free()
		pads.erase(id)
	if _gateway_fx.has(id):
		_open_gateway_fx(id)
	_apply_unlock(id, true)
	_eject_soon()
	if id in TvBalance.VALLEY_GATE.values():
		_build_bins()
	var title := id
	for u in UNLOCKS:
		if u.id == id:
			title = u.title
	if TimberGame.hud:
		TimberGame.hud.toast(title + "!")
	_refresh_pads()
	# Landmarks no longer end the game: they show the "Valley complete" card (GDD 6, rule 2).
	# A build-site landmark (Clock Tower) shows it when the building is finished instead.
	if TvBalance.LANDMARKS.has(id) and not TvBalance.BUILD_SITES.has(id):
		_landmark_done(id)


## Valley complete: confetti over the landmark, the card, then the pan to the next gateway.
func _landmark_done(id: String) -> void:
	var where: Vector3 = Vector3(-12, 0, -39)
	if id == "r2_boathouse":
		where = V2_BOATHOUSE
	elif TvBalance.BUILD_SITES.has(id):
		where = TvBalance.BUILD_SITES[id].pos
	if id == "lodge":
		TimberGame.finished = true
	TimberGame.save_game()
	for i in 6:
		get_tree().create_timer(0.3 * i).timeout.connect(func() -> void:
			TvFx.confetti(self, where + Vector3(randf_range(-4, 4), 5, randf_range(-3, 3))))
	if TimberGame.hud:
		if not TimberGame.hud.valley_card_closed.is_connected(pan_to_gateway):
			TimberGame.hud.valley_card_closed.connect(pan_to_gateway)
		TimberGame.hud.show_valley_card(int(TvBalance.LANDMARKS[id]), gateway_line(id))


func _camera() -> void:
	camera = Camera3D.new()
	camera.fov = 52.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 0.5
	# GDD 10: 110 (was 160), so the far valleys' ground and scenery drop out of the frustum.
	camera.far = 110.0
	add_child(camera)
	_cam_pos = player.global_position
	_place_camera(1.0)
	camera.current = true


func _place_camera(t: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.y > vp.x
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.fov = 45.0 if portrait else 36.0
	var focus := player.global_position
	if _pan_w > 0.0:
		focus = focus.lerp(_pan_to, _pan_w)
		t = 1.0
	_cam_pos = _cam_pos.lerp(focus, t)
	camera.global_position = _cam_pos + cam_offset
	camera.look_at(_cam_pos + Vector3(0, 0.6, 0), Vector3.UP)


# ---------------------------------------------------------------- valley gateways

## The unpaid gateway pad that is on the map now, or null.
func gateway_pad() -> TvUnlockPad:
	for id in TvBalance.GATEWAYS:
		if pads.has(id) and is_instance_valid(pads[id]) and not TimberGame.is_unlocked(id):
			return pads[id]
	return null


## Valley card line after a landmark: names the gateway it opens and its price.
func gateway_line(landmark: String) -> String:
	for u in UNLOCKS:
		if TvBalance.GATEWAYS.has(u.id) and landmark in u.req and not TimberGame.is_unlocked(u.id):
			return "Next: %s, %s.\nFollow the arrow." % [u.title, TimberGame.fmt(u.cost)]
	return "Your crews keep working in every valley, even while you are away."


## About 1.5 s: the camera glides to the gateway pad, holds, and comes back to the player.
func pan_to_gateway() -> void:
	var gate := gateway_pad()
	if gate == null:
		return
	_pan_to = gate.global_position
	var tw := create_tween()
	tw.tween_property(self, "_pan_w", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(self, "_pan_w", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Lit archway over the gateway pad, a glowing frame on the closed gate and floating motes.
## One emissive material, no shadow casters; the arch and frame bake into one mesh.
func _build_gateway_fx(id: String) -> void:
	if _gateway_fx.has(id):
		return
	var info: Dictionary = TvBalance.GATEWAYS[id]
	var pad_pos: Vector3 = (pads[id] as Node3D).position
	var gate: Vector3 = info.gate
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.66, 0.16)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.1)
	mat.emission_energy_multiplier = 1.8
	mat.roughness = 0.6
	var root := Node3D.new()
	root.name = "Gateway_" + id
	_pad_region(id).add_child(root)
	var frame := Node3D.new()
	root.add_child(frame)
	# Arch at the back edge of the pad, facing the camera.
	var back := pad_pos + Vector3(0, 0, -1.85)
	var ah := float(info.get("arch_h", 3.0))
	var parts := [
		[Vector3(0.26, ah, 0.26), back + Vector3(-1.95, ah * 0.5, 0)],
		[Vector3(0.26, ah, 0.26), back + Vector3(1.95, ah * 0.5, 0)],
		[Vector3(4.5, 0.3, 0.34), back + Vector3(0, ah + 0.1, 0)],
		[Vector3(1.0, 0.36, 0.4), back + Vector3(0, ah + 0.42, 0)],
	]
	# Frame around the closed gate: the river gate spans z, the Highland Gate spans x.
	if str(info.get("along", "z")) == "z":
		parts.append([Vector3(0.2, 2.4, 0.2), gate + Vector3(0, 1.2, -1.5)])
		parts.append([Vector3(0.2, 2.4, 0.2), gate + Vector3(0, 1.2, 1.5)])
		parts.append([Vector3(0.22, 0.2, 3.2), gate + Vector3(0, 2.4, 0)])
	else:
		parts.append([Vector3(0.2, 2.6, 0.2), gate + Vector3(-1.45, 1.3, 1.25)])
		parts.append([Vector3(0.2, 2.6, 0.2), gate + Vector3(1.45, 1.3, 1.25)])
		parts.append([Vector3(3.1, 0.2, 0.22), gate + Vector3(0, 2.6, 1.25)])
	for p in parts:
		var mi := TvShapes.box_node(frame, p[0], p[1], mat, 0.08)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	TvMeshMerge.merge(frame)
	var motes := CPUParticles3D.new()
	motes.name = "Motes"
	motes.position = pad_pos + Vector3(0, 0.3, 0)
	motes.amount = 18
	motes.lifetime = 1.8
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(1.4, 0.1, 1.4)
	motes.direction = Vector3.UP
	motes.spread = 12.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.6
	motes.initial_velocity_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	motes.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = mat
	motes.mesh = sm
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(motes)
	_gateway_fx[id] = root


## Paid: the arch and frame shrink away and the motes drift along the bridge into the new valley.
func _open_gateway_fx(id: String) -> void:
	var root: Node3D = _gateway_fx[id]
	_gateway_fx.erase(id)
	var motes: CPUParticles3D = root.get_node("Motes")
	motes.reparent(self)
	var path: Array = TvBalance.GATEWAYS[id].path
	var tw := motes.create_tween()
	for i in range(1, path.size()):
		var seg: float = (path[i] as Vector3).distance_to(path[i - 1])
		tw.tween_property(motes, "global_position", (path[i] as Vector3) + Vector3(0, 0.6, 0), seg / 9.0)
	tw.tween_callback(func() -> void: motes.emitting = false)
	tw.tween_interval(motes.lifetime)
	tw.tween_callback(motes.queue_free)
	var fade := root.create_tween()
	fade.tween_property(root, "scale", Vector3(1, 0.01, 1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	fade.tween_callback(root.queue_free)


func _guide_arrow() -> void:
	guide = MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0, -0.55), Vector3(0.38, 0, 0.1), Vector3(0.14, 0, 0.1), Vector3(0.14, 0, 0.45), Vector3(-0.14, 0, 0.45), Vector3(-0.14, 0, 0.1), Vector3(-0.38, 0, 0.1)]
	for tri in [[0, 1, 6], [2, 3, 4], [2, 4, 5]]:
		for i in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[i])
	guide.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.25, 0.9)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	guide.material_override = m
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(guide)


## Where the guide arrow should point, plus a hint line. Beginners get step-by-step help.
func _goal() -> Array:
	var p := player.global_position
	var back := player.stack
	var saw: TvMachine = machines.sawmill1
	var tutorial := not TimberGame.is_unlocked("jack1")
	var cheapest: TvUnlockPad = null
	for id in pads:
		var pad: TvUnlockPad = pads[id]
		if cheapest == null or pad.cost - pad.paid_amount < cheapest.cost - cheapest.paid_amount:
			cheapest = pad
	var v2_tutorial := _cur_region == 2 and not TimberGame.is_unlocked("r2_jack1")
	var v3_tutorial := _cur_region == 3 and TimberGame.is_unlocked("r3_gate") and not TimberGame.is_unlocked("r3_jack1")
	var v4_tutorial := _cur_region == 4 and TimberGame.is_unlocked("r4_crossing") and not TimberGame.is_unlocked("r4_jack1")
	var v5_tutorial := _cur_region == 5 and TimberGame.is_unlocked("r5_cablecar") and not TimberGame.is_unlocked("r5_jack1")
	var any_tut := tutorial or v2_tutorial or v3_tutorial or v4_tutorial or v5_tutorial
	if station.cutscene:
		return [null, ""]
	# The way into the next valley is always shown, even before the player can pay for it.
	var gate := gateway_pad()
	if gate and not any_tut:
		var what := "Next valley" if gate.id != "cap_station" else "Finale"
		return [gate.global_position, "%s: %s - %s" % [what, gate.title, TimberGame.fmt(gate.cost - gate.paid_amount)]]
	# The finale: point at the platforms still to load (the owner 2026-10-04: "buy it, then nothing").
	var can_buy := cheapest != null and TimberGame.money >= cheapest.cost - cheapest.paid_amount
	if station.built and not TimberGame.complete and not can_buy:
		return station.goal(p, _cur_region)
	if cheapest and TimberGame.money >= cheapest.cost - cheapest.paid_amount:
		return [cheapest.global_position, "Buy %s!" % cheapest.title if any_tut else ""]
	if v2_tutorial:
		return _goal_v2(p)
	if v3_tutorial:
		return _goal_v3(p)
	if v4_tutorial:
		return coast.goal(p)
	if v5_tutorial:
		return frost.goal(p)
	if not tutorial:
		return [null, ""]
	if shop.coin_value > 0 and back.is_empty():
		return [shop.coin_zone.global_position, "Collect your cash"]
	if back.top_type() == "log" and saw.in_zone.contains(p):
		return [saw.in_zone.global_position, "Bring logs to the sawmill"]
	if back.top_type() == "log":
		if back.count() >= player.capacity() or _nearest_tree(p) == null or back.count() >= 6:
			return [saw.in_zone.global_position, "Bring logs to the sawmill"]
		return [_nearest_tree(p).global_position, "Chop trees: just walk up to one"]
	if back.top_type() == "plank":
		if saw.out_zone.contains(p) and not saw.output.is_empty() and back.count() < player.capacity():
			return [saw.out_zone.global_position, "Pick up the planks"]
		return [shop.shelf_zone("plank").global_position, "Put planks on the counter"]
	if saw.output.count() >= 4:
		return [saw.out_zone.global_position, "Pick up the planks"]
	var t := _nearest_tree(p)
	if t:
		return [t.global_position, "Chop trees: just walk up to one"]
	return [null, ""]


func _nearest_tree(p: Vector3, key: String = "a") -> TvChopTree:
	var best: TvChopTree = null
	var bd := INF
	for t in forests[key]:
		var tree: TvChopTree = t
		if tree.is_ready():
			var d := tree.global_position.distance_squared_to(p)
			if d < bd:
				bd = d
				best = tree
	return best


func _process(delta: float) -> void:
	_place_camera(1.0 - exp(-6.0 * delta))
	_update_regions(delta, false)
	_pay_rent(delta)
	coast.tick(delta)
	station.tick(delta)
	var g := _goal()
	var target = g[0]
	if TimberGame.hud:
		TimberGame.hud.set_hint(g[1])
	if target == null:
		guide.visible = false
		return
	var p := player.global_position
	var dir: Vector3 = (target as Vector3) - p
	dir.y = 0
	var dist := dir.length()
	guide.visible = dist > 2.4
	if guide.visible:
		dir /= dist
		guide.global_position = p + dir * 1.35 + Vector3(0, 0.06, 0)
		guide.rotation.y = atan2(-dir.x, -dir.z)
		var s := 1.0 + sin(Time.get_ticks_msec() / 150.0) * 0.08
		guide.scale = Vector3.ONE * s


# ---------------------------------------------------------------- valleys: sleep/wake, chip

## Wake/sleep rules (GDD 10): awake inside rect + 24 m, asleep beyond rect + 30 m, at most 2 awake.
func _update_regions(delta: float, force: bool) -> void:
	var focus := _cam_pos
	var want: Array = []
	for rid in regions:
		var r: TvRegion = regions[rid]
		var d := r.distance_outside(focus)
		var on := d <= TvBalance.WAKE_MARGIN if (force or not r.awake) else d <= TvBalance.SLEEP_MARGIN
		if on:
			want.append(r)
	want.sort_custom(func(a: TvRegion, b: TvRegion) -> bool: return a.center().distance_to(focus) < b.center().distance_to(focus))
	want = want.slice(0, TvBalance.MAX_AWAKE)
	for rid in regions:
		var r: TvRegion = regions[rid]
		r.set_awake(r in want)
		r.tick(delta)
	var cur := _cur_region
	for rid in regions:
		if (regions[rid] as TvRegion).contains_point(player.global_position):
			cur = rid
	if cur != _cur_region:
		_cur_region = cur
		if cur > 1 and float(TimberGame.stats(cur).get("time", 0.0)) <= 0.0 and TimberGame.hud:
			TimberGame.hud.toast("Valley %d: %s" % [cur, str(TvBalance.REGIONS[cur].name)])
	var st := TimberGame.stats(_cur_region)
	st["time"] = float(st.get("time", 0.0)) + delta
	_chip_timer -= delta
	if _chip_timer <= 0.0 and TimberGame.hud:
		_chip_timer = 0.5
		TimberGame.hud.set_valley(_valley_chip())


func region_of_unlock(id: String) -> int:
	if id.begins_with("cap_"):
		return 6
	if id.length() > 3 and id[0] == "r" and id[1].is_valid_int() and id[2] == "_":
		return int(id[1])
	return 1


func _valley_chip() -> String:
	var r: TvRegion = regions[_cur_region]
	var own := 0
	var total := 0
	for u in UNLOCKS:
		if region_of_unlock(u.id) == _cur_region:
			total += 1
			if TimberGame.is_unlocked(u.id):
				own += 1
	return "%s %d/%d" % [r.title, own, total]


func current_region() -> int:
	return _cur_region


# ---------------------------------------------------------------- offline earnings

## Offline income waits as a coin pile next to the Valley 1 office; walk over it to collect.
func _build_offline_pile() -> void:
	if TimberGame.offline_pending <= 0:
		return
	_offline_pile = TvItemStack.new().setup("coin", 60, 3, 3)
	_offline_pile.position = OFFLINE_PILE
	r1.add_child(_offline_pile)
	for i in clampi(TimberGame.offline_pending / 50, 6, 45):
		_offline_pile.push(TvItems.make("coin"), false)
	_offline_label = Label3D.new()
	_offline_label.font = TvFx.font()
	_offline_label.text = "%s\nwhile away" % TimberGame.fmt(TimberGame.offline_pending)
	_offline_label.font_size = 52
	_offline_label.outline_size = 14
	_offline_label.modulate = Color(1.0, 0.9, 0.35)
	_offline_label.outline_modulate = Color(0.25, 0.15, 0.0, 0.9)
	_offline_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_offline_label.pixel_size = 0.006
	_offline_label.position = OFFLINE_PILE + Vector3(0, 1.7, 0)
	r1.add_child(_offline_label)
	_offline_zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.0, 2.0), "OFFLINE", Color(1.0, 0.85, 0.3))
	_offline_zone.position = OFFLINE_PILE
	_offline_zone.interval = 0.0
	_offline_zone.on_carrier = _collect_offline
	r1.add_child(_offline_zone)


func _collect_offline(carrier: Node, _delta: float) -> bool:
	if not carrier.get("is_player") or TimberGame.offline_pending <= 0:
		return false
	var v := TimberGame.collect_offline()
	var i := 0
	while not _offline_pile.is_empty():
		TvFx.fly_to_and_free(_offline_pile.pop(), carrier as Node3D, 0.02 * i)
		i += 1
	TimberSfx.play("coins", -2.0)
	TvFx.float_text(get_tree().current_scene, (carrier as Node3D).global_position + Vector3(0, 2.6, 0), "+" + TimberGame.fmt(v), Color(1.0, 0.85, 0.2), 1.3)
	_offline_zone.queue_free()
	_offline_label.queue_free()
	return true


# ---------------------------------------------------------------- Birch Bend (Valley 2)

## CNC tables to the market (2026-10-05). The Mega Sawmill closes the way south, so the belt runs
## west of the carpentry and bridges the Sawmill 2 belt (x 0.4) and the chair belt (x 5.9).
const V1_BELT_TABLES := [
	Vector3(11.7, 0, -22.6), Vector3(11.7, 0, -19.8), Vector3(3.0, 0, -19.8),
	Vector3(1.4, 0.8, -19.8), Vector3(-0.6, 0.8, -19.8), Vector3(-2.2, 0, -19.8),
	Vector3(-2.2, 0, -9.0), Vector3(3.8, 0, -9.0), Vector3(5.2, 0.8, -9.0), Vector3(6.8, 0.8, -9.0),
	Vector3(6.8, 0, -7.0), Vector3(6.8, 0, 1.4), Vector3(9.1, 0, 1.4),
]
const V2_BELT_LP := [Vector3(-42.3, 0, -7.4), Vector3(-42.3, 0, -11.5), Vector3(-49.6, 0, -11.5), Vector3(-49.6, 0, -17.8), Vector3(-48.9, 0, -17.8)]
## The second press hangs off the same belt: shared up to index 3, then on to press 2.
const V2_BELT_LP2 := [Vector3(-42.3, 0, -7.4), Vector3(-42.3, 0, -11.5), Vector3(-49.6, 0, -11.5), Vector3(-49.6, 0, -17.8), Vector3(-49.6, 0, -27.8), Vector3(-48.9, 0, -27.8)]
const V2_BELT_P1B := [Vector3(-41.0, 0, -17.8), Vector3(-40.0, 0, -17.8), Vector3(-40.0, 0, -34.4), Vector3(-44.2, 0, -34.4), Vector3(-44.2, 0, -36.3)]
const V2_BELT_P2B := [Vector3(-42.3, 0, -29.4), Vector3(-42.3, 0, -32.6), Vector3(-45.6, 0, -32.6), Vector3(-45.6, 0, -36.3)]
const V2_BELT_BB := [Vector3(-38.1, 0, -39.4), Vector3(-38.1, 0, -40.2), Vector3(-32.4, 0, -40.2), Vector3(-32.4, 0, -38.4)]


func _pad_region(id: String) -> TvRegion:
	if id == "r5_cablecar":
		return r4
	if id.begins_with("r5_"):
		return r5
	if id.begins_with("r4_") and id != "r4_crossing":
		return r4
	if id.begins_with("r3_") and id != "r3_gate":
		return r3
	return r2 if id.begins_with("r2_") and id != "r2_bridge" else r1


func _path2(a: Vector2, b: Vector2, w: float) -> void:
	(grounds[2].paths as Array).append([Vector4(a.x, a.y, b.x, b.y), w])


func _plaza2(c: Vector2, half: Vector2) -> void:
	(grounds[2].plazas as Array).append(Vector4(c.x, c.y, half.x, half.y))


## Keeps grass and rocks off where Birch Bend's belts, flume, groves and buildings will stand.
func _reserve_v2() -> void:
	for line in [V2_FLUME_PTS, V2_BELT_LP, V2_BELT_LP2, V2_BELT_P1B, V2_BELT_P2B, V2_BELT_BB]:
		for i in range(1, line.size()):
			var a: Vector3 = line[i - 1]
			var b: Vector3 = line[i]
			_reserved_lines.append([Vector4(a.x, a.z, b.x, b.z), 0.8])
	_reserved_lines.append([Vector4(-80, 14.6, -44.5, 14.2), 1.0])
	_reserved_lines.append([Vector4(RIVER_X - RIVER_HALF, BRIDGE_Z, -41, BRIDGE_Z), 1.0])
	# Valley 1 side: the path from the main road to the bridge appears with the bridge.
	_reserved_lines.append([Vector4(RIVER_X + RIVER_HALF, BRIDGE_Z, 0, BRIDGE_Z), 1.2])
	_reserved_lines.append([Vector4(-40, -1, -40, -38), 0.9])
	for g in [[V2_GROVE1, 3, 3], [V2_GROVE2, 3, 2], [V2_GROVE_NORTH, 4, 3], [V2_GROVE_WEST, 3, 4]]:
		var c: Vector3 = g[0]
		_reserved_rects.append(Vector4(c.x, c.z, int(g[1]) * 1.3 + 0.4, int(g[2]) * 1.3 + 0.4))
	for m in [V2_LATHE, V2_PRESS, V2_PRESS2]:
		_reserved_rects.append(Vector4(m.x, m.z, 4.2, 1.8))
	_reserved_rects.append(Vector4(V2_MARKET.x - 0.5, V2_MARKET.z - 1.5, 3.4, 5.8))
	_reserved_rects.append(Vector4(V2_OFFICE.x, V2_OFFICE.z + 1.0, 2.4, 3.4))
	_reserved_rects.append(Vector4(V2_BOATHOUSE.x, V2_BOATHOUSE.z + 1.5, 3.6, 5.8))
	_reserved_rects.append(Vector4(V2_BOATSHOP.x, V2_BOATSHOP.z, 5.0, 2.0))
	_reserved_rects.append(Vector4(V2_BARGE.x - 0.6, V2_BARGE.z, 3.0, 2.8))
	_reserved_rects.append(Vector4(V2_CHUTE.x, V2_CHUTE.z + 0.8, 1.8, 2.0))


func _apply_unlock_r2(id: String, animate: bool) -> void:
	match id:
		"r2_bridge":
			_open_bridge(animate)
			_build_forest("birch", V2_GROVE1, 3, 3, 2.6, "birch", animate, 2)
			paths.append([Vector4(RIVER_X + RIVER_HALF, BRIDGE_Z, 0, BRIDGE_Z), 0.9])
			_path2(Vector2(RIVER_X - RIVER_HALF, BRIDGE_Z), Vector2(-41, BRIDGE_Z), 1.0)
		"r2_lathe":
			_build_lathe(animate)
			_build_shop2(animate)
		"r2_grove2":
			_build_forest("birch", V2_GROVE2, 3, 2, 2.6, "birch", animate, 2)
		"r2_office":
			_build_office2(animate)
		"r2_jack1":
			var lathe: TvMachine = machines.lathe
			_spawn_jack_to("character-male-a", forests.birch, lathe.input, lathe.in_zone.global_position, Vector3(-50, 0, 2), animate, 2)
		"r2_hauler1":
			var lathe: TvMachine = machines.lathe
			_spawn_hauler("character-female-b", lathe.output, lathe.out_zone, shop2.shelf("veneer"), shop2.shelf_zone("veneer"), animate, 2)
		"r2_flume":
			_build_flume(animate)
			_build_forest("birch_north", V2_GROVE_NORTH, 4, 3, 2.6, "birch", animate, 2)
		"r2_cashier":
			shop2.hire_cashier(animate)
		"r2_press":
			_build_press("press", V2_PRESS, animate)
			shop2.open_shelf("plywood", animate)
			_path2(Vector2(-40, -6), Vector2(-40, -18), 0.8)
		"r2_jack2":
			for k in 2:
				_spawn_jack_to(["character-male-d", "character-female-a"][k], forests.birch_north, flume_chute, flume_zone.global_position, Vector3(-57, 0, -25 - k * 2), animate, 2)
		"r2_belt_lp":
			_belt_lp = _belt(machines.lathe.output, machines.press.input, V2_BELT_LP, animate, 2)
		"r2_hauler2":
			var press: TvMachine = machines.press
			_spawn_hauler("character-female-c", press.output, press.out_zone, shop2.shelf("plywood"), shop2.shelf_zone("plywood"), animate, 2)
		"r2_press2":
			_build_press("press2", V2_PRESS2, animate)
			_path2(Vector2(-40, -18), Vector2(-40, -28), 0.8)
			# The lathe belt splits 50/50 between the two presses.
			if _belt_lp:
				_belt_lp.add_split(machines.press2.input, PackedVector3Array(V2_BELT_LP2), 3)
		"r2_boatshop":
			_build_boatshop(animate)
			_path2(Vector2(-40, -28), Vector2(-40, -35.5), 0.8)
		"r2_barge":
			var d := TvTruckDock.new().setup("canoe", RIVER_X, "barge", 2)
			d.position = V2_BARGE
			d.region_node = r2
			r2.add_child(d)
			machines["barge"] = d
			_plaza2(Vector2(V2_BARGE.x - 1.2, V2_BARGE.z), Vector2(2.0, 2.6))
			if animate:
				TvFx.pop_in(d, 0.6)
		"r2_belt_pb":
			_belt(machines.press.output, machines.boatshop.input, V2_BELT_P1B, animate, 2)
			_belt(machines.press2.output, machines.boatshop.input, V2_BELT_P2B, animate, 2)
		"r2_belt_bb":
			var dock: TvTruckDock = machines.barge
			_belt(machines.boatshop.output, dock.pile, V2_BELT_BB, animate, 2)
		"r2_jack3":
			_build_forest("birch_west", V2_GROVE_WEST, 3, 4, 2.6, "birch", animate, 2)
			var lathe: TvMachine = machines.lathe
			var dst: TvItemStack = flume_chute if flume_chute else lathe.input
			var dst_pos: Vector3 = flume_zone.global_position if flume_zone else lathe.in_zone.global_position
			var looks := ["character-male-c", "character-female-d", "character-male-b"]
			for k in int(TvBalance.FORESTER_CAMP.crew):
				_spawn_jack_to(looks[k % looks.size()], forests.birch_west, dst, dst_pos, Vector3(-67, 0, -13 - k * 1.5), animate, 2)
			_model(TvModels.path("log_stack_birch"), Vector3(-65.5, 0, -12.0), 2.4, -15, r2)
		"r2_boathouse":
			_build_boathouse(animate)


func _open_bridge(animate: bool) -> void:
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


func _machine2(id: String, recipe: String, pos: Vector3, region: int = 2) -> TvMachine:
	var r: Array = TvBalance.MACHINES[recipe]
	var m := TvMachine.new().setup(id, str(r[0]), str(r[4]), int(r[1]), int(r[5]), float(r[6]), region, int(TvBalance.MACHINE_OUT_CAP.get(recipe, 48)))
	m.position = pos
	machines[id] = m
	return m


func _build_lathe(animate: bool) -> void:
	var m := _machine2("lathe", "lathe", V2_LATHE)
	m.add_model(TvModels.path("lathe"), Vector3.ZERO, 1.0)
	# The birch log spins around X: the pivot turns local Z onto world X.
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.98, 0)
	pivot.rotation_degrees.y = 90
	m.body.add_child(pivot)
	var lg := TvModels.make("lathe_log")
	lg.rotation_degrees.y = -90
	pivot.add_child(lg)
	m.spinners.append(pivot)
	m.mouth_in = Vector3(-1.2, 1.0, 0)
	m.mouth_out = Vector3(0.6, 0.9, 0.78)
	m.add_dust(Vector3(0, 1.1, 0.5), Color(0.96, 0.9, 0.75))
	m.add_blocker(Vector3(3.0, 1.6, 1.95))
	TvMeshMerge.merge(m.body, m.spinners)
	r2.add_child(m)
	_plaza2(Vector2(V2_LATHE.x, V2_LATHE.z), Vector2(4.8, 2.2))
	_model(TvModels.path("log_stack_birch"), V2_LATHE + Vector3(-1.4, 0, -2.4), 2.2, 10, r2)
	if animate:
		TvFx.pop_in(m, 0.7)


func _build_press(id: String, pos: Vector3, animate: bool) -> void:
	var m := _machine2(id, "press", pos)
	m.add_model(TvModels.path("press"), Vector3.ZERO, 1.0)
	m.plates.append(m.add_model(TvModels.path("press_plate"), Vector3(0, 1.35, 0), 1.0))
	m.mouth_in = Vector3(-0.9, 0.8, 0)
	m.mouth_out = Vector3(0.9, 0.75, 0)
	m.add_blocker(Vector3(2.2, 3.2, 1.67))
	TvMeshMerge.merge(m.body, m.plates)
	r2.add_child(m)
	_plaza2(Vector2(pos.x, pos.z), Vector2(4.8, 2.2))
	if animate:
		TvFx.pop_in(m, 0.7)


func _build_boatshop(animate: bool) -> void:
	var m := _machine2("boatshop", "boatshop", V2_BOATSHOP)
	m.input.position.x = -3.4
	m.in_zone.position.x = -3.4
	m.output.position.x = 3.4
	m.out_zone.position.x = 3.4
	m.add_model(TvModels.path("boatshop"), Vector3.ZERO, 1.0)
	m.mouth_in = Vector3(-1.6, 0.9, 0.6)
	m.mouth_out = Vector3(1.6, 0.9, 0.6)
	m.add_dust(Vector3(0, 1.2, 0.6), Color(0.95, 0.85, 0.65))
	m.add_blocker(Vector3(4.5, 2.8, 3.0))
	TvMeshMerge.merge(m.body)
	r2.add_child(m)
	_plaza2(Vector2(V2_BOATSHOP.x, V2_BOATSHOP.z), Vector2(5.6, 2.4))
	if animate:
		TvFx.pop_in(m, 0.8)


func _build_shop2(animate: bool) -> void:
	# Mirrored market: the player serves from the east, shoppers walk in along a lane from the west.
	shop2 = TvShop.new().setup(2, -1.0)
	shop2.position = V2_MARKET
	# Lane along z 14.5, south of the boathouse jetty (it reaches z 12.6).
	shop2.spawn_local = Vector3(-79.5, 0, 13.6) - V2_MARKET
	shop2.exit_local = Vector3(-79.5, 0, 14.6) - V2_MARKET
	shop2.lane_via = Vector3(-44.5, 0, 14.2)
	shop2.sign_unlock = ""
	shop2.region_node = r2
	shop2.add_shelf("veneer", 2.6)
	shop2.add_shelf("plywood", 0.0)
	r2.add_child(shop2)
	shop2.open_shelf("veneer", animate)
	_plaza2(Vector2(V2_MARKET.x + 0.5, V2_MARKET.z - 1.5), Vector2(3.2, 5.6))
	_path2(Vector2(-80, 14.6), Vector2(-44.5, 14.2), 0.9)
	_path2(Vector2(-40, -1), Vector2(-40, -6), 0.8)


func _build_office2(animate: bool) -> void:
	var root := Node3D.new()
	root.position = V2_OFFICE
	r2.add_child(root)
	root.add_child(TvModels.make("riverside_office"))
	TvMeshMerge.merge(root)
	var lbl := Label3D.new()
	lbl.font = TvFx.font()
	lbl.text = "OFFICE"
	lbl.font_size = 56
	lbl.outline_size = 12
	lbl.modulate = Color(0.25, 0.16, 0.08)
	lbl.outline_modulate = Color(1, 0.95, 0.75)
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, 2.05, 1.40)
	root.add_child(lbl)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.9, 3.0, 3.3)
	col.shape = bs
	col.position = Vector3(0, 1.5, -0.2)
	sb.add_child(col)
	root.add_child(sb)
	office2_zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.4, 2.0), "UPGRADES", Color(0.6, 0.95, 1.0))
	office2_zone.position = V2_OFFICE + Vector3(0, 0, 3.2)
	office2_zone.on_enter = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.open_upgrades(2)
	office2_zone.on_exit = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.close_upgrades()
	r2.add_child(office2_zone)
	_plaza2(Vector2(V2_OFFICE.x, V2_OFFICE.z + 2.6), Vector2(2.2, 1.6))
	_path2(Vector2(-38.3, 1.0), Vector2(-34, 12.6), 0.7)
	if animate:
		TvFx.pop_in(root, 0.6)


## Log flume: chute by the North Grove, water trough to the lathe input (GDD 7.6 A).
func _build_flume(animate: bool) -> void:
	var root := Node3D.new()
	root.name = "Flume"
	r2.add_child(root)
	var chute := TvModels.make("flume_chute")
	chute.position = V2_CHUTE + Vector3(0.7, 0, 0)
	root.add_child(chute)
	var xf := []
	for x in [-58.0, -56.0, -54.0, -52.0]:
		xf.append(Transform3D(Basis(), Vector3(x, 0, -24)))
	var along_z := Basis(Vector3.UP, deg_to_rad(-90))
	for i in 9:
		xf.append(Transform3D(along_z, Vector3(-51.5, 0, -23.5 + i * 2.0)))
	xf.append(Transform3D(Basis(), Vector3(-50.7, 0, -6)))
	_multimesh(TvModels.path("flume_straight"), xf, true, root)
	var end := TvModels.make("flume_end")
	end.position = Vector3(-48.7, 0, -6)
	root.add_child(end)
	TvMeshMerge.merge(root)
	flume_chute = TvItemStack.new().setup("birch_log", 16, 2, 2, "flume:in")
	flume_chute.position = V2_CHUTE + Vector3(0, 0.75, 0)
	r2.add_child(flume_chute)
	flume_zone = TvZone.new().setup(TvZone.Kind.DROP, flume_chute, Vector2(2.2, 2.0), "FLUME", Color(1, 1, 1))
	flume_zone.position = V2_CHUTE + Vector3(0, 0, 1.9)
	r2.add_child(flume_zone)
	var c := TvConveyor.new()
	c.region = 2
	c.setup_flume(flume_chute, (machines.lathe as TvMachine).input, PackedVector3Array(V2_FLUME_PTS), 0.95)
	root.add_child(c)
	_plaza2(Vector2(V2_CHUTE.x, V2_CHUTE.z + 1.4), Vector2(1.6, 1.8))
	if animate:
		TvFx.pop_in(root, 0.7)


func _build_boathouse(animate: bool) -> void:
	var root := Node3D.new()
	root.position = V2_BOATHOUSE
	r2.add_child(root)
	root.add_child(TvModels.make("boathouse"))
	TvMeshMerge.merge(root)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.4, 3.0, 8.4)
	col.shape = bs
	col.position.y = 1.5
	sb.add_child(col)
	root.add_child(sb)
	_plaza2(Vector2(V2_BOATHOUSE.x, V2_BOATHOUSE.z + 5.0), Vector2(1.6, 2.0))
	if animate:
		TvFx.pop_in(root, 1.0)


## Grass, flowers and rocks across Birch Bend (same density as Valley 1), reeds on the bank,
## lily pads on the river. Scenery stays outside the Region nodes (it culls by chunk).
func _scatter_deco_v2() -> void:
	var sets := [
		["grass", 260, 2.4, false], ["grass_large", 160, 2.4, false], ["grass_leafs", 110, 2.6, false],
		["flower_redA", 110, 2.6, false], ["flower_yellowA", 120, 2.6, false], ["flower_yellowB", 60, 2.4, false],
		["flower_redC", 50, 2.4, false], ["plant_bush", 110, 2.8, true], ["plant_bushDetailed", 90, 2.6, true],
		["rock_smallA", 40, 2.2, false], ["rock_smallC", 40, 2.2, false], ["mushroom_redGroup", 25, 2.2, false],
		["mushroom_tanGroup", 20, 2.2, false], ["rock_largeA", 10, 2.4, true],
	]
	var area := Rect2(-78.5, -46.5, 47.0, 61.5)
	var scale_n := area.get_area() / (66.0 * 68.0)
	for s in sets:
		var list := []
		var want := int(float(s[1]) * scale_n)
		var tries: int = want * 3
		while list.size() < want and tries > 0:
			tries -= 1
			var p := Vector2(rng2.randf_range(area.position.x, area.end.x), rng2.randf_range(area.position.y, area.end.y))
			if _busy(p, 0.6):
				continue
			var sc: float = s[2] * rng2.randf_range(0.75, 1.3)
			list.append(Transform3D(Basis(Vector3.UP, rng2.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, 0, p.y)))
		_deco.append(["res://games/timber-valley/assets/models_v3/nature/%s.glb" % s[0], list, s[3]])
	var reeds := []
	for i in 40:
		var z := rng2.randf_range(-46, 15)
		if absf(z - BRIDGE_Z) < 2.0 or absf(z - V2_BARGE.z) < 3.5:
			continue
		reeds.append(Transform3D(Basis(Vector3.UP, rng2.randf() * TAU).scaled(Vector3.ONE * rng2.randf_range(2.2, 3.0)), Vector3(RIVER_X - RIVER_HALF - rng2.randf_range(-0.2, 0.6), 0, z)))
	_deco.append([TvModels.path("reeds"), reeds, false])
	var pads_x := []
	for i in 14:
		var z := rng2.randf_range(-60, 15)
		if absf(z - BRIDGE_Z) < 2.0:
			continue
		pads_x.append(Transform3D(Basis(Vector3.UP, rng2.randf() * TAU).scaled(Vector3.ONE * rng2.randf_range(2.0, 2.8)), Vector3(RIVER_X + rng2.randf_range(-2.4, -1.2), 0.09, z)))
	_deco.append([TvModels.path("lilypads"), pads_x, false])


## Log palisade around Birch Bend (sleeps with the valley), plus the closed gate at the bridge.
func _palisades_v2() -> void:
	var lines := [
		[Vector2(-78.8, 15.3), Vector2(-31.0, 15.3)],
		[Vector2(-78.8, -46.6), Vector2(-31.0, -46.6)],
		[Vector2(-78.8, 15.3), Vector2(-78.8, -46.6)],
	]
	var xforms := []
	for ln in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		var n := int(a.distance_to(b) / 0.31)
		for k in n + 1:
			var p := a.lerp(b, float(k) / maxf(n, 1))
			var hgt := rng2.randf_range(0.95, 1.3)
			var basis := Basis(Vector3.UP, rng2.randf() * TAU).scaled(Vector3(1, hgt, 1))
			xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	_multimesh(TvModels.path("palisade_post"), xforms, true, r2)
	if not TimberGame.is_unlocked("r2_bridge"):
		_gate_prop = _model(TvModels.path("gate_fence"), Vector3(RIVER_X + RIVER_HALF + 0.6, 0, BRIDGE_Z), 2.6, 90, r1)


## Birch Bend mini-tutorial until its first lumberjack (GDD 12): chop, feed the lathe, stock the counter.
func _goal_v2(p: Vector3) -> Array:
	var back := player.stack
	if not TimberGame.is_unlocked("r2_lathe"):
		if pads.has("r2_lathe"):
			return [(pads.r2_lathe as Node3D).global_position, "Build the veneer lathe"]
		return [null, ""]
	var lathe: TvMachine = machines.lathe
	if shop2.coin_value > 0 and back.is_empty():
		return [shop2.coin_zone.global_position, "Collect your cash"]
	if back.top_type() == "birch_log":
		var t := _nearest_tree(p, "birch")
		if lathe.in_zone.contains(p) or back.count() >= player.capacity() or t == null or back.count() >= 8:
			return [lathe.in_zone.global_position, "Feed the veneer lathe"]
		return [t.global_position, "Chop the birch trees"]
	if back.top_type() == "veneer":
		if lathe.out_zone.contains(p) and not lathe.output.is_empty() and back.count() < player.capacity():
			return [lathe.out_zone.global_position, "Pick up the veneer"]
		return [shop2.shelf_zone("veneer").global_position, "Stock the veneer counter"]
	if not back.is_empty():
		return [null, ""]
	if lathe.output.count() >= 6:
		return [lathe.out_zone.global_position, "Pick up the veneer"]
	var t2 := _nearest_tree(p, "birch")
	if t2:
		return [t2.global_position, "Chop the birch trees"]
	return [null, ""]


# ---------------------------------------------------------------- Maple Highlands (Valley 3)

## Belts (GDD 7.6 / CSV): saw and planer to the Yard counters, the two kit-factory feeds, kits to the train.
const V3_BELT_BEAMS := [Vector3(6.5, 0, -63.4), Vector3(10.6, 0, -63.4)]
const V3_BELT_FLOOR := [Vector3(6.4, 0, -77.8), Vector3(8.0, 0, -77.8), Vector3(8.0, 0, -66.0), Vector3(10.6, 0, -66.0)]
const V3_BELT_KIT_BEAMS := [Vector3(5.4, 0, -65.9), Vector3(5.4, 0, -71.0), Vector3(-2.0, 0, -71.0), Vector3(-2.0, 0, -91.45), Vector3(1.0, 0, -91.45)]
const V3_BELT_KIT_FLOOR := [Vector3(5.4, 0, -79.2), Vector3(5.4, 0, -84.6), Vector3(2.8, 0, -84.6), Vector3(2.8, 0, -86.6)]
const V3_BELT_KIT_RAIL := [Vector3(9.5, 0, -92.3), Vector3(9.5, 0, -99.5)]
## Train stop: loco centre (wagons couple behind it to the east) and where it waits out of sight.
const V3_TRAIN_STOP_X := 4.0
## The train runs on through Frost Peaks and out of sight in the east forest.
const V3_TRAIN_AWAY_X := 104.0

## Forklift drops alternate between the counter/export pile and a build site that needs the item.
var _route_flip: Dictionary = {}


## Static sign text joins its valley's GroundLabels atlas (one draw for all of them).
func _batch_label(l: Label3D) -> void:
	var gl := TvGroundLabels.find_for(l)
	if gl:
		gl.add(l)


func _path3(a: Vector2, b: Vector2, w: float) -> void:
	(grounds[3].paths as Array).append([Vector4(a.x, a.y, b.x, b.y), w])


func _plaza3(c: Vector2, half: Vector2) -> void:
	(grounds[3].plazas as Array).append(Vector4(c.x, c.y, half.x, half.y))


## Keeps grass and rocks off the Highlands' future belts, track, groves, plots and buildings.
## The road runs through the valley from the start, so its dirt verge is drawn now.
func _reserve_v3() -> void:
	_path3(Vector2(ROAD_X, -47), Vector2(ROAD_X, -100), 2.6)
	var lines := [V3_BELT_BEAMS, V3_BELT_FLOOR, V3_BELT_KIT_BEAMS, V3_BELT_KIT_FLOOR, V3_BELT_KIT_RAIL]
	for line in lines:
		for i in range(1, line.size()):
			var a: Vector3 = line[i - 1]
			var b: Vector3 = line[i]
			_reserved_lines.append([Vector4(a.x, a.z, b.x, b.z), 0.8])
	for l in [
		[Vector4(V3_RAIL_WEST, V3_RAIL_Z, ROAD_X + 3.0, V3_RAIL_Z), 1.3],
		[Vector4(0, -47, 0, -104), 1.2], [Vector4(-12, -58, -12, -110), 1.2], [Vector4(-12, -58, 0, -58), 1.0],
		[Vector4(0, -61.5, 9.0, -61.5), 1.0], [Vector4(0, -102.1, 5.1, -102.1), 1.0],
	]:
		_reserved_lines.append(l)
	for g in [[V3_GROVE1, 3, 3], [V3_GROVE2, 3, 2], [V3_GROVE_NORTH, 4, 3], [V3_GROVE_RIDGE, 4, 2]]:
		var c: Vector3 = g[0]
		_reserved_rects.append(Vector4(c.x, c.z, int(g[1]) * 1.3 + 0.4, int(g[2]) * 1.3 + 0.4))
	for m in [V3_BEAMSAW, V3_PLANER]:
		_reserved_rects.append(Vector4(m.x, m.z - 0.4, 4.6, 2.2))
	_reserved_rects.append(Vector4(V3_KITFACTORY.x, V3_KITFACTORY.z, 5.2, 2.6))
	_reserved_rects.append(Vector4(V3_MARKET.x - 0.5, V3_MARKET.z - 1.5, 3.4, 5.8))
	_reserved_rects.append(Vector4(V3_OFFICE.x, V3_OFFICE.z + 1.2, 2.6, 3.4))
	_reserved_rects.append(Vector4(V3_RAIL_DOCK.x - 1.0, V3_RAIL_DOCK.z, 4.6, 2.6))
	for id in TvBalance.BUILD_SITES:
		var p: Vector3 = TvBalance.BUILD_SITES[id].pos
		_reserved_rects.append(Vector4(p.x + 1.0, p.z, 4.6, 3.4) if id != "r3_clocktower" else Vector4(p.x, p.z + 2.0, 3.6, 4.0))
	# Handcar stops: sign, tiles and the track beside them stay clear of scatter. These are the M2
	# spots, kept as they were so the scatter draws do not move; _filter_deco_v123 clears the
	# wider four-tile stops.
	for st in [[Vector3(-8.5, 0, 11.2), -1.0], [Vector3(-35.6, 0, 3.4), 1.0], [Vector3(-6.0, 0, -57.8), -1.0]]:
		var sp: Vector3 = st[0]
		_reserved_rects.append(Vector4(sp.x + float(st[1]) * 0.6, sp.z, 3.6, 2.0))


func _apply_unlock_r3(id: String, animate: bool) -> void:
	if TvBalance.BUILD_SITES.has(id):
		_build_site(id, animate)
		return
	match id:
		"r3_gate":
			_open_gate3(animate)
			_build_forest("maple", V3_GROVE1, 3, 3, 2.6, "maple", animate, 3)
			paths.append([Vector4(0, -44, 0, -47.5), 1.0])
			_path3(Vector2(0, -46.5), Vector2(0, -104), 1.0)
			_path3(Vector2(-12, -58), Vector2(-12, -110), 1.0)
			_path3(Vector2(-12, -58), Vector2(0, -58), 0.9)
			if not _loading:
				_rebuild_handcar_stops(animate)
		"r3_beamsaw":
			_build_beamsaw(animate)
			_build_shop3(animate)
		"r3_grove2":
			_build_forest("maple", V3_GROVE2, 3, 2, 2.6, "maple", animate, 3)
		"r3_office":
			_build_office3(animate)
		"r3_jack1":
			var saw: TvMachine = machines.beamsaw
			_spawn_jack_to("character-male-b", forests.maple, saw.input, saw.in_zone.global_position, Vector3(-3, 0, -63), animate, 3)
		"r3_forklift1":
			forklift = TvWorker.new().as_forklift(_forklift_route, Vector3(7.5, 0, -68.5))
			forklift.region = 3
			r3.add_child(forklift)
			for mid in ["beamsaw", "planer", "kitfactory"]:
				_forklift_source(mid)
			if animate:
				TvFx.pop_in(forklift)
		"r3_cashier":
			shop3.hire_cashier(animate)
		"r3_planer":
			_build_planer(animate)
			shop3.open_shelf("floorboard", animate)
			_forklift_source("planer")
		"r3_jack2":
			_build_forest("maple_north", V3_GROVE_NORTH, 4, 3, 2.6, "maple", animate, 3)
			var pl: TvMachine = machines.planer
			for k in 2:
				_spawn_jack_to(["character-female-c", "character-male-d"][k], forests.maple_north, pl.input, pl.in_zone.global_position, Vector3(-3.5, 0, -97.0 - k * 1.6), animate, 3)
		"r3_belt_bp":
			# The yard belts leave a reserve while a village site needs that item, so the forklift
			# finds beams and floorboards to take there (2026-10-04: with these belts and the
			# kit-factory belts emptying both outputs, houses and the Clock Tower got no more beams).
			var bs: TvItemStack = (machines.beamsaw as TvMachine).output
			var bb := _belt(bs, shop3.shelf("beam"), V3_BELT_BEAMS, animate, 3)
			bb.hold = _site_reserve(bs, "beam")
			var ps: TvItemStack = (machines.planer as TvMachine).output
			var bf := _belt(ps, shop3.shelf("floorboard"), V3_BELT_FLOOR, animate, 3)
			bf.hold = _site_reserve(ps, "floorboard")
		"r3_kitfactory":
			_build_kitfactory(animate)
			_forklift_source("kitfactory")
		"r3_rail":
			_build_rail(animate)
		"r3_belt_kit":
			var kf: TvMachine = machines.kitfactory
			var kb := _belt((machines.beamsaw as TvMachine).output, kf.input, V3_BELT_KIT_BEAMS, animate, 3)
			kb.hold = _site_reserve((machines.beamsaw as TvMachine).output, "beam")
			var kfl := _belt((machines.planer as TvMachine).output, kf.input_b, V3_BELT_KIT_FLOOR, animate, 3)
			kfl.hold = _site_reserve((machines.planer as TvMachine).output, "floorboard")
			# Kits to the train leave a reserve while a village site needs kits (as r3_belt_bp).
			var bk := _belt(kf.output, (machines.rail as TvTruckDock).pile, V3_BELT_KIT_RAIL, animate, 3)
			bk.hold = _site_reserve(kf.output, "cabin_kit")
		"r3_jack3":
			_build_forest("maple_ridge", V3_GROVE_RIDGE, 4, 2, 2.6, "maple", animate, 3)
			var looks := ["character-female-a", "character-male-c", "character-female-d"]
			for k in 3:
				var m: TvMachine = machines.beamsaw if k < 2 else machines.planer
				_spawn_jack_to(looks[k], forests.maple_ridge, m.input, m.in_zone.global_position, Vector3(-2.5 + k * 1.5, 0, -111.0), animate, 3)
			_model(TvModels.path("log_stack_maple"), Vector3(-3.0, 0, -113.5), 2.4, 20, r3)
		"r3_rail2":
			(machines.rail as TvTruckDock).add_wagons(TvBalance.RAIL2_WAGONS)


## The Highland Gate stands in the Home Valley north palisade from the start, closed by doors.
func _palisades_v3() -> void:
	var gx := GATE3_HALF + 0.5
	var lines := [
		[Vector2(-23.2, V3_SOUTH - 0.4), Vector2(-23.2, V3_NORTH + 0.4)],
		[Vector2(-23.2, V3_NORTH + 0.4), Vector2(14.8, V3_NORTH + 0.4)],
		[Vector2(-23.2, V3_SOUTH - 0.4), Vector2(-gx, V3_SOUTH - 0.4)],
		[Vector2(gx, V3_SOUTH - 0.4), Vector2(14.8, V3_SOUTH - 0.4)],
		# Both sides of the corridor through the border forest.
		[Vector2(-gx, -47.9), Vector2(-gx, V3_SOUTH - 0.4)],
		[Vector2(gx, -47.9), Vector2(gx, V3_SOUTH - 0.4)],
	]
	var xforms := []
	for ln in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		var n := int(a.distance_to(b) / 0.31)
		for k in n + 1:
			var p := a.lerp(b, float(k) / maxf(n, 1))
			var hgt := rng3.randf_range(0.95, 1.3)
			var basis := Basis(Vector3.UP, rng3.randf() * TAU).scaled(Vector3(1, hgt, 1))
			xforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	_multimesh(TvModels.path("palisade_post"), xforms, true, r3)
	# Once the Grand Timber Station stands, its walk-through arch is the gate (ASSETS_M5.md, option A).
	if TimberGame.is_unlocked("cap_station"):
		return
	var gate := _model(TvModels.path("highland_gate"), GATE3, 1.0, 0, r1)
	gate.name = "HighlandGate"
	_gate3_model = gate
	var lbl := Label3D.new()
	lbl.font = TvFx.font()
	lbl.text = "MAPLE HIGHLANDS"
	lbl.font_size = 44
	lbl.outline_size = 10
	lbl.modulate = Color(0.25, 0.16, 0.08)
	lbl.outline_modulate = Color(1, 0.95, 0.75)
	lbl.pixel_size = 0.005
	lbl.position = Vector3(0, 2.95, 1.16)
	gate.add_child(lbl)
	_batch_label(lbl)
	if not TimberGame.is_unlocked("r3_gate"):
		_gate3_doors = _model(TvModels.path("highland_gate_doors"), GATE3, 1.0, 0, r1)


## The station replaces the Highland Gate: the arch (and its sign) shrinks away.
func retire_highland_gate(animate: bool) -> void:
	if _gate3_model == null:
		return
	var g := _gate3_model
	_gate3_model = null
	var gl := TvGroundLabels.find_for(g)
	for l in g.find_children("*", "Label3D", true, false):
		if gl:
			gl.remove(l as Label3D)
	if animate:
		var tw := g.create_tween()
		tw.tween_property(g, "scale", Vector3.ONE * 0.01, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(g.queue_free)
	else:
		g.queue_free()


func _open_gate3(animate: bool) -> void:
	if _gate3_body:
		_gate3_body.queue_free()
		_gate3_body = null
	if _gate3_doors:
		var gd := _gate3_doors
		_gate3_doors = null
		if animate:
			var tw := gd.create_tween()
			tw.tween_property(gd, "scale", Vector3.ONE * 0.01, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(gd.queue_free)
		else:
			gd.queue_free()


## Grass, leaf piles and autumn bushes across the Highlands (GDD 9.3 / ASSETS_M2.md section 5):
## the V2 counts with the flowers swapped for leaf piles and bushes, and half the green grass.
func _scatter_deco_v3() -> void:
	var nature := "res://games/timber-valley/assets/models_v3/nature/%s.glb"
	var sets := [
		[nature % "grass", 130, 2.4, false], [nature % "grass_large", 80, 2.4, false],
		[nature % "grass_leafs", 110, 2.6, false], [TvModels.path("leaf_pile"), 110, 2.6, false],
		[TvModels.path("bush_autumn"), 90, 2.6, true], [nature % "plant_bushDetailed", 40, 2.6, true],
		[nature % "rock_smallA", 40, 2.2, false], [nature % "rock_smallC", 40, 2.2, false],
		[nature % "mushroom_redGroup", 25, 2.2, false], [nature % "mushroom_tanGroup", 20, 2.2, false],
		[nature % "rock_largeA", 10, 2.4, true],
	]
	var area := Rect2(-23.0, V3_NORTH + 0.5, 41.5, V3_SOUTH - V3_NORTH - 1.0)
	var scale_n := area.get_area() / (66.0 * 68.0)
	for s in sets:
		var list := []
		var want := int(float(s[1]) * scale_n)
		var tries: int = want * 3
		while list.size() < want and tries > 0:
			tries -= 1
			var p := Vector2(rng3.randf_range(area.position.x, area.end.x), rng3.randf_range(area.position.y, area.end.y))
			if absf(p.x - ROAD_X) < 2.4 or _busy(p, 0.6):
				continue
			var sc: float = s[2] * rng3.randf_range(0.75, 1.3)
			list.append(Transform3D(Basis(Vector3.UP, rng3.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, 0, p.y)))
		_deco.append([s[0], list, s[3]])


## Every teal machine stands on a dirt plaza (DESIGN.md 13).
func _build_beamsaw(animate: bool) -> void:
	var m := _machine2("beamsaw", "beamsaw", V3_BEAMSAW, 3)
	m.add_model(TvModels.path("beamsaw"), Vector3.ZERO, 1.0)
	m.spinners.append(m.add_model(TvModels.path("beamsaw_blade"), Vector3(0, 0.95, 0.05), 1.0))
	m.mouth_in = Vector3(-1.6, 0.7, 0)
	m.cut_point = Vector3(0, 0.7, 0)
	m.mouth_out = Vector3(1.3, 0.75, 0)
	m.add_dust(Vector3(0, 0.9, 0.35), Color(0.96, 0.85, 0.66))
	m.add_blocker(Vector3(3.9, 1.4, 1.4), Vector3(0, 0, -0.1))
	TvMeshMerge.merge(m.body, m.spinners)
	r3.add_child(m)
	_plaza3(Vector2(V3_BEAMSAW.x, V3_BEAMSAW.z), Vector2(4.8, 2.2))
	_path3(Vector2(0, -61.5), Vector2(9.0, -61.5), 0.8)
	_model(TvModels.path("log_stack_maple"), V3_BEAMSAW + Vector3(-1.4, 0, -2.4), 2.3, 10, r3)
	if animate:
		TvFx.pop_in(m, 0.7)


func _build_planer(animate: bool) -> void:
	var m := _machine2("planer", "planer", V3_PLANER, 3)
	m.add_model(TvModels.path("planer"), Vector3.ZERO, 1.0)
	m.spinners.append(m.add_model(TvModels.path("planer_roller"), Vector3(-0.66, 1.0, 0), 1.0))
	m.mouth_in = Vector3(-1.4, 0.95, 0)
	m.mouth_out = Vector3(1.2, 0.95, 0)
	m.add_dust(Vector3(0, 1.1, 0.4), Color(0.96, 0.88, 0.7))
	m.add_blocker(Vector3(3.6, 1.5, 1.4))
	m.add_blocker(Vector3(0.9, 3.0, 0.9), Vector3(1.1, 0, -1.15))
	TvMeshMerge.merge(m.body, m.spinners)
	r3.add_child(m)
	_plaza3(Vector2(V3_PLANER.x, V3_PLANER.z - 0.4), Vector2(4.8, 2.4))
	if animate:
		TvFx.pop_in(m, 0.7)


## Assembler (GDD 7.4): beams in at the back square, floorboards at the front, kits out east.
func _build_kitfactory(animate: bool) -> void:
	var r: Array = TvBalance.MACHINES["kitfactory"]
	var m := _machine2("kitfactory", "kitfactory", V3_KITFACTORY, 3)
	m.input.position = Vector3(-3.2, 0, -1.45)
	m.in_zone.position = m.input.position
	m.in_zone.half = Vector2(1.1, 1.2)
	# The beam square's label goes behind it, so it does not land in the floorboard square.
	if m.in_zone.label:
		m.in_zone.label.position.z = -1.6
	m.add_second_input(str(r[2]), int(r[3]), Vector3(-3.2, 0, 1.45))
	m.output.position = Vector3(3.2, 0, 0)
	m.out_zone.position = m.output.position
	m.add_model(TvModels.path("kitfactory"), Vector3.ZERO, 1.0)
	m.plates.append(m.add_model(TvModels.path("kitfactory_press"), Vector3(0.1, 1.75, 0), 1.0))
	m.plate_up = 1.75
	m.plate_down = 1.5
	m.mouth_in = Vector3(-2.1, 0.9, -1.2)
	m.mouth_in_b = Vector3(-2.1, 0.9, 1.2)
	m.mouth_out = Vector3(2.3, 0.9, 0)
	m.add_blocker(Vector3(4.6, 3.2, 4.0))
	TvMeshMerge.merge(m.body, m.plates)
	r3.add_child(m)
	_plaza3(Vector2(V3_KITFACTORY.x, V3_KITFACTORY.z), Vector2(5.6, 2.8))
	if animate:
		TvFx.pop_in(m, 0.8)


## Highland Railway: platform turned 90 deg so the track runs east-west north of the road end.
func _build_rail(animate: bool) -> void:
	var d := TvTruckDock.new().setup("cabin_kit", 0.0, "train", 3)
	d.position = V3_RAIL_DOCK
	d.rotation_degrees.y = 90
	d.region_node = r3
	# Export square west of the deck (dock-local -Z = world -X), turned back so its label reads.
	d.zone.position = Vector3(0.6, 0, -4.4)
	d.zone.rotation_degrees.y = -90
	d.set_route(Vector3(V3_TRAIN_STOP_X, 0, V3_RAIL_Z), Vector3(V3_TRAIN_AWAY_X, 0, V3_RAIL_Z), Vector3(V3_TRAIN_AWAY_X, 0, V3_RAIL_Z), PI * 0.5)
	r3.add_child(d)
	machines["rail"] = d
	var track := Node3D.new()
	track.name = "Track"
	r3.add_child(track)
	var xf := []
	var along_x := Basis(Vector3.UP, PI * 0.5)
	var x := V3_RAIL_WEST + 2.0
	# Up to the road wall; Frost Peaks owns the rest of the line (FrostPeaks.build_rail_v3).
	while x < 21.0:
		xf.append(Transform3D(along_x, Vector3(x, 0, V3_RAIL_Z)))
		x += 4.0
	_multimesh(TvModels.path("rail"), xf, true, track)
	var bumper := TvModels.make("rail_bumper")
	bumper.position = Vector3(V3_RAIL_WEST + 0.4, 0, V3_RAIL_Z)
	bumper.rotation_degrees.y = 90
	track.add_child(bumper)
	TvMeshMerge.merge(track)
	_plaza3(Vector2(V3_RAIL_DOCK.x - 1.2, V3_RAIL_DOCK.z - 0.4), Vector2(4.4, 2.4))
	_path3(Vector2(0, -102.1), Vector2(5.1, -102.1), 0.8)
	if animate:
		TvFx.pop_in(d, 0.6)


func _build_shop3(animate: bool) -> void:
	# Builders' Yard: shoppers come along the road (x = 17), like Valley 1.
	shop3 = TvShop.new().setup(3, 1.0)
	shop3.position = V3_MARKET
	shop3.road_x = ROAD_X - V3_MARKET.x
	shop3.sign_unlock = ""
	shop3.region_node = r3
	shop3.add_shelf("beam", 2.6)
	shop3.add_shelf("floorboard", 0.0)
	shop3.spawn_bonus = 1.0 + 0.1 * TimberGame.houses_done()
	r3.add_child(shop3)
	shop3.open_shelf("beam", animate)
	_plaza3(Vector2(V3_MARKET.x - 0.3, V3_MARKET.z - 1.5), Vector2(2.8, 5.8))


func _build_office3(animate: bool) -> void:
	var root := Node3D.new()
	root.position = V3_OFFICE
	r3.add_child(root)
	root.add_child(TvModels.make("highland_office"))
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
	_batch_label(lbl)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.8, 3.0, 3.2)
	col.shape = bs
	col.position = Vector3(0, 1.5, -0.2)
	sb.add_child(col)
	root.add_child(sb)
	office3_zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.4, 2.0), "UPGRADES", Color(0.6, 0.95, 1.0))
	office3_zone.position = V3_OFFICE + Vector3(0, 0, 3.4)
	office3_zone.on_enter = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.open_upgrades(3)
	office3_zone.on_exit = func(_c: Node) -> void:
		if TimberGame.hud:
			TimberGame.hud.close_upgrades()
	r3.add_child(office3_zone)
	_plaza3(Vector2(V3_OFFICE.x, V3_OFFICE.z + 2.6), Vector2(2.2, 1.6))
	if animate:
		TvFx.pop_in(root, 0.6)


# ---------------------------------------------------------------- build sites, rent, forklift

## Village houses: slot squares on the street side (+X), stacked along z. Clock Tower: in front.
func _build_site(id: String, animate: bool, origin: Vector3 = Vector3.INF, step: Vector3 = Vector3.INF, sign_at: Vector3 = Vector3.INF) -> TvBuildSite:
	var info: Dictionary = TvBalance.BUILD_SITES[id]
	var tower := id == "r3_clocktower"
	if origin == Vector3.INF:
		origin = Vector3(-2.6, 0, 4.4) if tower else Vector3(4.2, 0, -2.6)
	if step == Vector3.INF:
		step = Vector3(2.6, 0, 0) if tower else Vector3(0, 0, 2.6)
	if sign_at == Vector3.INF:
		sign_at = Vector3(0, 4.2, 2.6) if tower else Vector3(0, 3.2, 2.4)
	var site := TvBuildSite.new().setup(id, info, origin, step, sign_at)
	site.position = info.pos
	(regions[int(info.get("region", 3))] as TvRegion).add_child(site)
	sites[id] = site
	site.completed.connect(_on_site_completed)
	if int(info.get("region", 3)) != 3:
		if animate:
			TvFx.pop_in(site, 0.6)
		return site
	if tower:
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(4.0, 6.0, 4.0)
		col.shape = bs
		col.position.y = 3.0
		sb.add_child(col)
		site.add_child(sb)
		var p: Vector3 = info.pos
		_plaza3(Vector2(p.x, p.z + 2.6), Vector2(3.8, 3.6))
	if animate:
		TvFx.pop_in(site, 0.6)
	return site


func _on_site_completed(id: String) -> void:
	var info: Dictionary = TvBalance.BUILD_SITES[id]
	var p: Vector3 = info.pos
	TimberSfx.play("unlock", -2.0)
	TvFx.confetti(self, p + Vector3(0, 3.0, 0))
	_pull_out()
	_eject_soon()
	if bool(info.get("platform", false)):
		station.platform_done(id)
	if bool(info.rent):
		if shop3:
			shop3.spawn_bonus = 1.0 + 0.1 * TimberGame.houses_done()
		var rent := int(round(TvBalance.RENT_PER_HOUSE * TimberGame.fame_mult(3)))
		TvFx.float_text(get_tree().current_scene, p + Vector3(0, 4.5, 0), "+%s/s" % TimberGame.fmt(rent), Color(1.0, 0.9, 0.35), 1.3)
		if TimberGame.hud:
			TimberGame.hud.toast("%s built: rent +%s/s" % [_title_of(id).trim_prefix("Village Plot ").get_slice(": ", 1), TimberGame.fmt(rent)])
	TimberGame.save_game()
	if TvBalance.LANDMARKS.has(id):
		_landmark_done(id)
		# The next gateway pad appears once the landmark building stands.
		_refresh_pads()


func _title_of(id: String) -> String:
	for u in UNLOCKS:
		if u.id == id:
			return str(u.title)
	return id


## Build complete: the camera pulls out 20% for 1.2 s (GDD 7.6 B).
func _pull_out() -> void:
	var base := Vector3(0, 8.4, 6.6)
	var tw := create_tween()
	tw.tween_property(self, "cam_offset", base * 1.2, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.4)
	tw.tween_property(self, "cam_offset", base, 0.4).set_trans(Tween.TRANS_SINE)


## Village rent, once a second, straight to the wallet, whether the Highlands are awake or not.
func _pay_rent(delta: float) -> void:
	_rent_t += delta
	if _rent_t < 1.0:
		return
	_rent_t -= 1.0
	var r := TimberGame.rent_rate()
	if r <= 0.0:
		return
	_rent_carry += r
	var whole := int(_rent_carry)
	if whole > 0:
		_rent_carry -= whole
		TimberGame.add_money(whole, 3)


## First unfinished site (in plot order) in valley `region` with room for `item`, or null.
func _site_needing(item: String, region: int = 3) -> TvBuildSite:
	for id in TvBalance.BUILD_SITES:
		if int(TvBalance.BUILD_SITES[id].get("region", 3)) != region:
			continue
		if sites.has(id):
			var s: TvBuildSite = sites[id]
			if s.room(item) > 0:
				return s
	return null


## Belt hold: keep Balance.SITE_RESERVE[item] on `src` while a village site needs `item`.
func _site_reserve(src: TvItemStack, item: String) -> Callable:
	var keep := int(TvBalance.SITE_RESERVE[item])
	return func() -> bool: return src.count() <= keep and _site_needing(item, 3) != null


func _forklift_source(machine_id: String) -> void:
	if forklift == null or not machines.has(machine_id):
		return
	var m: TvMachine = machines[machine_id]
	forklift.add_source(m.output, m.out_zone.global_position)


## Where a forklift load of `item` goes: the Yard counter (beams, floorboards) or the train
## platform (kits), alternating with a build site that needs it. [] = nowhere right now.
## commit = this load is leaving now (flips the alternation).
func _forklift_route(item: String, commit: bool = false) -> Array:
	var main: Array = []
	if item in ["beam", "floorboard"] and shop3 and shop3.is_open(item) and not shop3.shelf(item).is_full():
		main = [shop3.shelf(item), shop3.shelf_zone(item).global_position]
	elif item == "cabin_kit" and machines.has("rail") and not (machines.rail as TvTruckDock).pile.is_full():
		var d: TvTruckDock = machines.rail
		main = [d.pile, d.zone.global_position]
	var site := _site_needing(item, 3)
	# Once a belt feeds the item's counter or train (r3_belt_bp, r3_belt_kit), the forklift takes
	# every load a site needs there instead of alternating (2026-10-04).
	var belt_pad := "r3_belt_kit" if item == "cabin_kit" else "r3_belt_bp"
	var belt_fed := TimberGame.is_unlocked(belt_pad)
	var to_site := site != null and (main.is_empty() or belt_fed or bool(_route_flip.get(item, false)))
	if commit:
		_route_flip[item] = not bool(_route_flip.get(item, false))
	if to_site:
		return [site.intake_of(item), site.zone_of(item).global_position]
	return main


# ---------------------------------------------------------------- handcar stops

## TruckDock asks: the Valley 1 truck waits before the Level Crossing while the player is on it.
func crossing_holds(pos: Vector3) -> bool:
	return coast.crossing_holds(pos)


# ---------------------------------------------------------------- player safety (stuck, discard)

## A building that appears (or grows in with its pop-in) around the player pushes them out to
## the nearest free spot: once right away and once after the pop-in has finished. Workers and
## shoppers have no collision, so they cannot be trapped.
func _eject_soon() -> void:
	for t in [0.15, 1.2]:
		get_tree().create_timer(t).timeout.connect(func() -> void:
			if player and _overlaps(player.global_position):
				_place_free(player, 0.0))


## Player capsule overlaps any collision at p.
func _overlaps(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	# A touch smaller than the player's own capsule (0.38), so resting against a wall is not "inside".
	cap.radius = 0.34
	cap.height = 1.4
	q.shape = cap
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.8, 0))
	q.exclude = [player.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _walkable(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	for rid in regions:
		if (regions[rid] as TvRegion).rect.grow(-0.5).has_point(q):
			return not _overlaps(p)
	return false


## Moves the player to the nearest free walkable spot at least min_r away (rings of 0.5 m).
func _place_free(who: Node3D, min_r: float) -> void:
	var o := who.global_position
	var r := maxf(min_r, 0.5)
	while r <= 12.0:
		var n := maxi(8, int(r * 6.0))
		for i in n:
			# Start toward the camera (+z), so the player lands in view.
			var a := PI * 0.5 + TAU * float(i) / n
			var c := o + Vector3(cos(a) * r, 0, sin(a) * r)
			if _walkable(c):
				who.global_position = c
				if who == player:
					player.velocity = Vector3.ZERO
				return
		r += 0.5


## Safety net (Player calls it after 2 s of input without moving): wedged inside collision or
## boxed in on every side -> nearest free spot. Pushing against a plain wall does nothing.
func unstick(who: Node3D) -> void:
	var p := who.global_position
	if _overlaps(p):
		_place_free(who, 0.0)
		return
	for i in 8:
		var a := TAU * i / 8.0
		if _walkable(p + Vector3(cos(a), 0, sin(a)) * 0.9):
			return
	_place_free(who, 1.0)


## While a large panel covers the screen (upgrade board, valley card, finish panel) the sun's
## shadow pass is skipped: the panel's own draws would otherwise push the frame over budget.
func set_ui_cover(on: bool) -> void:
	if sun:
		sun.shadow_enabled = not on


## Discard bin per open valley (Balance.DISCARD_BINS): stand on it to throw away the stack.
func _build_bins() -> void:
	for rid in TvBalance.DISCARD_BINS:
		if _bins.has(rid) or not valley_open(int(rid)):
			continue
		var at: Vector3 = TvBalance.DISCARD_BINS[rid]
		var root := Node3D.new()
		root.name = "DiscardBin%d" % rid
		root.position = at
		(regions[int(rid)] as TvRegion).add_child(root)
		var bin := TvModels.make_path("res://games/timber-valley/assets/models_v3/survival/barrel.glb", Color(0.62, 0.64, 0.66))
		bin.scale = Vector3.ONE * 2.0
		bin.position = Vector3(0, 0, -1.25)
		root.add_child(bin)
		TvMeshMerge.merge(root)
		var z := TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(1.8, 1.8), "DISCARD", Color(1.0, 0.55, 0.45))
		z.interval = 0.0
		# Only after standing on it for a moment, so walking past never empties the stack.
		var still := [0.0]
		z.on_carrier = func(c: Node, d: float) -> bool:
			if not c.get("is_player") or (c as TvPlayer).stack.is_empty():
				still[0] = 0.0
				return false
			var v: Vector3 = (c as TvPlayer).velocity
			still[0] = still[0] + d if Vector2(v.x, v.z).length() < 0.6 else 0.0
			if still[0] < TvZone.PICK_STILL_S:
				return false
			still[0] = 0.0
			(c as TvPlayer).dump()
			return true
		root.add_child(z)
		_bins[rid] = root


func valley_open(rid: int) -> bool:
	var gate: String = TvBalance.VALLEY_GATE.get(rid, "")
	return gate == "" or TimberGame.is_unlocked(gate)


## Every open valley's stop, rebuilt when a new valley opens (each stop gets a tile for it).
func _rebuild_handcar_stops(animate: bool) -> void:
	for rid in _stops.keys():
		var old: Node3D = _stops[rid]
		if is_instance_valid(old):
			var gl := TvGroundLabels.find_for(old)
			for l in old.find_children("*", "Label3D", true, false):
				if gl:
					gl.remove(l as Label3D)
			old.queue_free()
	_stops.clear()
	_tile_hold.clear()
	for rid in TvBalance.HANDCAR_STOPS:
		if valley_open(int(rid)):
			_build_handcar_stop(int(rid), animate)


## Tile offset along the stop for tile i of n (one row; closer together with 3-4 tiles).
func _tile_x(i: int, n: int) -> float:
	var step := float(TvBalance.HANDCAR_TILE_STEP[2] if n <= 2 else TvBalance.HANDCAR_TILE_STEP[4])
	return (i - (n - 1) * 0.5) * step


## Sign, a short track with the handcar, and one tile per other open valley (GDD 7.6 E).
func _build_handcar_stop(rid: int, animate: bool) -> void:
	if _stops.has(rid):
		return
	var info: Dictionary = TvBalance.HANDCAR_STOPS[rid]
	var region: TvRegion = regions[rid]
	var root := Node3D.new()
	root.name = "HandcarStop%d" % rid
	root.position = info.pos
	region.add_child(root)
	_stops[rid] = root
	# Each valley may have its own colour of stop (Redwood Coast: navy, ASSETS_M3.md 1.5).
	var sign := TvModels.make(str({4: "handcar_stop_navy", 5: "handcar_stop_alpine"}.get(rid, "handcar_stop")))
	sign.position = Vector3(0, 0, -1.2)
	root.add_child(sign)
	var side := float(info.side)
	var rail := TvModels.make("rail")
	rail.position = Vector3(3.1 * side, 0, 0)
	root.add_child(rail)
	var car := TvModels.make(str({4: "handcar_navy", 5: "handcar_alpine"}.get(rid, "handcar")))
	car.position = Vector3(3.1 * side, 0, -0.6)
	root.add_child(car)
	var dests := []
	for other in TvBalance.HANDCAR_STOPS:
		if int(other) != rid and valley_open(int(other)):
			dests.append(int(other))
	for i in dests.size():
		var tile := TvModels.make("handcar_tile")
		tile.position = Vector3(_tile_x(i, dests.size()), 0, 0.4)
		root.add_child(tile)
	TvMeshMerge.merge(root)
	var title := Label3D.new()
	title.font = TvFx.font()
	title.text = "HANDCAR"
	title.font_size = 48
	title.outline_size = 10
	title.modulate = Color(0.25, 0.16, 0.08)
	title.outline_modulate = Color(1, 0.95, 0.75)
	title.pixel_size = 0.006
	title.position = Vector3(0, 2.0, -1.11)
	root.add_child(title)
	_batch_label(title)
	for i in dests.size():
		var dst: int = dests[i]
		var pos := Vector3(_tile_x(i, dests.size()), 0, 0.4)
		var vname := str(TvBalance.REGIONS[dst].name).to_upper()
		var z := TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(1.6, 1.6), vname, Color(1.0, 0.85, 0.3))
		z.position = pos
		z.marker.visible = false
		z.interval = 0.0
		var key := "%d>%d" % [rid, dst]
		z.on_carrier = func(c: Node, delta: float) -> bool:
			if not c.get("is_player"):
				return false
			var t: float = float(_tile_hold.get(key, 0.0)) + delta
			_tile_hold[key] = t
			if t >= float(TvBalance.HANDCAR.hold_s) and t - delta < float(TvBalance.HANDCAR.hold_s):
				_ride(dst)
			return false
		z.on_exit = func(_c: Node) -> void:
			_tile_hold[key] = 0.0
		root.add_child(z)
		if z.label:
			# Three or four tiles sit closer together: a smaller name keeps them apart.
			z.label.font_size = 40 if dests.size() <= 2 else 30
			z.label.pixel_size = 0.0075
			z.label.position.z = 1.3 if dests.size() <= 2 else 1.2
	if animate:
		TvFx.pop_in(root, 0.6)


## 0.8 s on a tile: fade out 0.3 s, move player and camera to that valley's stop, fade in 0.3 s.
func _ride(dst: int) -> void:
	# The tile left behind may sleep with its valley before it sees the player leave.
	_tile_hold.clear()
	TimberSfx.play("machine", -3.0, 0.7)
	var land: Vector3 = TvBalance.HANDCAR_STOPS[dst].land
	var go := func() -> void:
		player.global_position = land
		player.velocity = Vector3.ZERO
		_cam_pos = land
		_update_regions(0.0, true)
		TimberSfx.play("machine", -3.0, 0.8)
	if TimberGame.hud:
		TimberGame.hud.fade_travel(go)
	else:
		go.call()


## Maple Highlands mini-tutorial until its first lumberjack (GDD 12): chop, feed the saw, stock the counter.
func _goal_v3(p: Vector3) -> Array:
	var back := player.stack
	if not TimberGame.is_unlocked("r3_beamsaw"):
		if pads.has("r3_beamsaw"):
			return [(pads.r3_beamsaw as Node3D).global_position, "Build the beam saw"]
		return [null, ""]
	var saw: TvMachine = machines.beamsaw
	if shop3.coin_value > 0 and back.is_empty():
		return [shop3.coin_zone.global_position, "Collect your cash"]
	if back.top_type() == "maple_log":
		var t := _nearest_tree(p, "maple")
		if saw.in_zone.contains(p) or back.count() >= player.capacity() or t == null or back.count() >= 10:
			return [saw.in_zone.global_position, "Feed the beam saw"]
		return [t.global_position, "Chop the maple trees"]
	if back.top_type() == "beam":
		if saw.out_zone.contains(p) and not saw.output.is_empty() and back.count() < player.capacity():
			return [saw.out_zone.global_position, "Pick up the beams"]
		return [shop3.shelf_zone("beam").global_position, "Stock the beam counter"]
	if not back.is_empty():
		return [null, ""]
	if saw.output.count() >= 4:
		return [saw.out_zone.global_position, "Pick up the beams"]
	var t2 := _nearest_tree(p, "maple")
	if t2:
		return [t2.global_position, "Chop the maple trees"]
	return [null, ""]
