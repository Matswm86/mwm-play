extends Node3D

# Game flow for the 3D presentation. The rules, level format, power-up
# semantics and win/lose conditions are ported unchanged from the shipped
# 2D version — only the rendering and animation layer is new.

const POWERUP_CHARGES_PER_LEVEL: int = 3
const SAVE_PATH: String = "user://tile_explorer_save.json"
const SAVE_VERSION: int = 1
const RoundButton := preload("res://games/tile-explorer/scripts/RoundButton.gd")
const GlyphView := preload("res://games/tile-explorer/scripts/GlyphView.gd")
## HUD layout at 1080 px wide. Touch areas are RoundButton.HIT (216 px). The
## top-left square stays empty for the MWM Play home button, and nothing
## tappable sits in the bottom wrist strip (16 mm = 256 px).
const SHELL_CORNER: float = 232.0
const WRIST: float = 256.0
const BUTTON_GAP: float = 44.0
## Top of the restart disc. A camera cutout deeper than this pushes the top
## row down by the difference; the touch areas still start at the top edge.
const TOP_ROW_CLEAR: float = 30.0
## Design frame the camera was tuned for (widest level at ndc x +-0.92).
const DESIGN_ASPECT: float = 1920.0 / 1080.0
const CAMERA_FOV: float = 60.0  # vertical, over the 1920 px design height

@export var levels_path: String = "res://games/tile-explorer/data/levels/"
@export var start_level: int = 1
@export var max_level: int = 30

@onready var board: TeBoard3D = $Board
@onready var tray: TeTray3D = $Tray
@onready var ui: CanvasLayer = $UI
@onready var level_label: Label = $UI/HeaderCard/LevelLabel
@onready var progress_label: Label = $UI/HeaderCard/ProgressLabel
@onready var win_panel: Panel = $UI/WinPanel
@onready var win_label: Label = $UI/WinPanel/WinLabel
@onready var lose_panel: Panel = $UI/LosePanel
@onready var lose_label: Label = $UI/LosePanel/LoseLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var header_card: Panel = $UI/HeaderCard

enum GameState { IDLE, BUSY, WON, LOST }

var current_level: int = 1
var state: int = GameState.BUSY
var move_stack: Array[TeTile3D] = []  # tray tiles in arrival order (recent last)
var undo_left: int = 0
var remove3_left: int = 0
var shuffle_left: int = 0
var highest_level: int = 1
var _panel_touch: int = -1  # touch index that went down on a win/lose panel
## Test hook: a fake top safe-area inset in window px; < 0 = ask the display.
var fake_safe_top: float = -1.0
var reset_button: RoundButton
var undo_button: RoundButton
var remove3_button: RoundButton
var shuffle_button: RoundButton


func _ready() -> void:
	# Camera + sun orientation set here (matrices in .tscn are unreadable).
	var cam: Camera3D = $Camera
	# -68 pitch frames the widest level (world x +-3.7, 7-layer stacks) at
	# ndc x +-0.92 on the 1080x1920 portrait frustum; -50 clipped corners.
	cam.position = Vector3(0, 14.9, 5.5)
	cam.rotation_degrees = Vector3(-68, 0, 0)
	$Sun.rotation_degrees = Vector3(-50, -30, 0)
	current_level = start_level
	_load_progress()
	board.tile_tapped.connect(_on_tile_tapped)
	board.blocked_tapped.connect(func(t: TeTile3D) -> void: t.shake())
	_build_hud()
	_build_table()
	_build_tray_base()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	# Bake the 12 procedural icons into textures, then install the shared
	# tile mesh + materials. Must complete before the first level loads.
	var icon_textures: Array = await TeIconBaker.bake_icons(self)
	TeTile3D.install_shared(icon_textures)
	load_level(current_level)
	_maybe_devshot()


func load_level(n: int) -> void:
	state = GameState.BUSY
	move_stack.clear()
	undo_left = POWERUP_CHARGES_PER_LEVEL
	remove3_left = POWERUP_CHARGES_PER_LEVEL
	shuffle_left = POWERUP_CHARGES_PER_LEVEL
	for t in tray.tiles:
		t.queue_free()
	tray.tiles.clear()
	win_panel.visible = false
	lose_panel.visible = false
	hint_label.visible = false
	reset_button.visible = true
	var path: String = "%slevel_%02d.json" % [levels_path, n]
	if not FileAccess.file_exists(path):
		level_label.text = "All levels complete"
		hint_label.text = "Tap to restart from level 1"
		hint_label.visible = true
		state = GameState.WON
		board.input_locked = true
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if data == null or not (data is Dictionary):
		level_label.text = "Bad level JSON"
		state = GameState.LOST
		return
	level_label.text = "%d" % n
	board.load_tiles(data["tiles"])
	_update_progress()
	_update_powerup_labels()
	board.input_locked = false
	state = GameState.IDLE


func _update_progress() -> void:
	progress_label.text = "%d" % board.remaining_count()


func _update_powerup_labels() -> void:
	undo_button.charges = undo_left
	remove3_button.charges = remove3_left
	shuffle_button.charges = shuffle_left
	undo_button.disabled = undo_left <= 0 or move_stack.is_empty()
	remove3_button.disabled = remove3_left <= 0 or tray.size() < 3
	shuffle_button.disabled = shuffle_left <= 0 or board.remaining_count() == 0


func _on_tile_tapped(t: TeTile3D) -> void:
	if state != GameState.IDLE:
		return
	if tray.is_full():
		return
	state = GameState.BUSY
	board.input_locked = true
	move_stack.append(t)
	# Quick scale-punch on tap, in parallel with the flight start.
	var punch: Tween = create_tween()
	(
		punch
		. tween_property(t, "scale", Vector3(1.14, 1.14, 1.14), 0.06)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	punch.tween_property(t, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await tray.add_tile(t).finished
	# Resolve any triples (loops in the rare case a clear exposes another).
	while true:
		var match_info: Dictionary = tray.resolve_matches()
		if match_info.is_empty():
			break
		await match_info["tween"].finished
		TeFx3D.match_burst(self, match_info["centroid"], TeIcons.color_of(int(match_info["icon"])))
		for r in match_info["tiles"]:
			move_stack.erase(r)
			board.tiles.erase(r)
			r.queue_free()
	board.recompute_blocking()
	_update_progress()
	_update_powerup_labels()
	if board.remaining_count() == 0 and tray.is_empty():
		_win()
		return
	if tray.is_full():
		_lose()
		return
	state = GameState.IDLE
	board.input_locked = false


func _win() -> void:
	state = GameState.WON
	board.input_locked = true
	TeFx3D.win_confetti(self, Vector3(0, 4.0, 0))
	_save_progress(_next_level())
	_show_panel(win_panel)
	reset_button.visible = false


func _lose() -> void:
	state = GameState.LOST
	board.input_locked = true
	_show_panel(lose_panel)


func _show_panel(panel: Panel) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	panel.visible = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)


# Win and lose panels continue on a tap that starts while the panel is up and
# ends with the finger lifted (action on release, like the tiles). Touches
# that start in the wrist strip or the shell's home corner do not count.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	if state != GameState.WON and state != GameState.LOST:
		_panel_touch = -1
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		if _panel_touch < 0 and not _in_dead_zone(touch.position):
			_panel_touch = touch.index
		get_viewport().set_input_as_handled()
		return
	if touch.index != _panel_touch:
		return
	_panel_touch = -1
	get_viewport().set_input_as_handled()
	if state == GameState.WON:
		current_level = _next_level()
		load_level(current_level)
	else:
		load_level(current_level)


func _on_reset_pressed() -> void:
	load_level(current_level)


func _on_undo_pressed() -> void:
	if state != GameState.IDLE or undo_left <= 0 or move_stack.is_empty():
		return
	state = GameState.BUSY
	board.input_locked = true
	undo_left -= 1
	var t: TeTile3D = move_stack.pop_back()
	t.in_tray = false
	var slide: Tween = tray.remove_tile(t)
	# Fly back to the board along a reverse arc.
	var target: Vector3 = TeBoard3D.px_to_world(t.board_position, t.layer)
	var start: Vector3 = t.position
	var fly: Tween = create_tween()
	(
		fly
		. tween_method(
			func(s: float) -> void:
				var p: Vector3 = start.lerp(target, s)
				p.y += TeTray3D.ARC_HEIGHT * 4.0 * s * (1.0 - s)
				t.position = p,
			0.0,
			1.0,
			0.30
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await fly.finished
	if slide.is_valid():
		await slide.finished
	board.recompute_blocking()
	_update_progress()
	_update_powerup_labels()
	state = GameState.IDLE
	board.input_locked = false


func _on_remove3_pressed() -> void:
	if state != GameState.IDLE or remove3_left <= 0 or tray.size() < 3:
		return
	state = GameState.BUSY
	board.input_locked = true
	remove3_left -= 1
	# Step 1: pick the 3 leftmost tray tiles.
	var tray_kill: Array[TeTile3D] = []
	for i in 3:
		tray_kill.append(tray.tiles[i])
	# Step 2: for each icon among those 3, kill enough additional tiles
	# (board first, then leftover tray) so the icon's total remaining count
	# stays a multiple of 3 — otherwise the level becomes unsolvable.
	var killed_by_icon: Dictionary = {}
	for t in tray_kill:
		killed_by_icon[t.icon_id] = int(killed_by_icon.get(t.icon_id, 0)) + 1
	var extra_kill: Array[TeTile3D] = []
	for icon_id in killed_by_icon.keys():
		var remaining: int = 0
		for t in board.tiles:
			if t.icon_id == int(icon_id) and not (t in tray_kill):
				remaining += 1
		var need: int = remaining % 3
		if need == 0:
			continue
		# Prefer board (not in tray) so the visible board cleans up.
		var found: int = 0
		for t in board.tiles:
			if found >= need:
				break
			if (
				t.icon_id == int(icon_id)
				and not t.in_tray
				and not (t in tray_kill)
				and not (t in extra_kill)
			):
				extra_kill.append(t)
				found += 1
		# Fallback to tray tiles outside the leftmost-3 cut.
		if found < need:
			for t in tray.tiles:
				if found >= need:
					break
				if t.icon_id == int(icon_id) and not (t in tray_kill) and not (t in extra_kill):
					extra_kill.append(t)
					found += 1
	var all_kill: Array[TeTile3D] = []
	for t in tray_kill:
		all_kill.append(t)
	for t in extra_kill:
		all_kill.append(t)
	# Step 3: drop refs from every collection.
	for t in all_kill:
		tray.tiles.erase(t)
		move_stack.erase(t)
		board.tiles.erase(t)
	# Step 4: animate everything shrinking out, slide tray closed.
	var tw: Tween = create_tween().set_parallel(true)
	for t in all_kill:
		(
			tw
			. tween_property(t, "scale", Vector3(0.05, 0.05, 0.05), 0.28)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN)
		)
		tw.tween_property(t, "rotation:y", t.rotation.y + 2.5, 0.28)
	for i in tray.tiles.size():
		tw.tween_property(tray.tiles[i], "position", tray.slot_position(i), 0.20)
	await tw.finished
	for t in all_kill:
		t.queue_free()
	board.recompute_blocking()
	_update_progress()
	_update_powerup_labels()
	if board.remaining_count() == 0 and tray.is_empty():
		_win()
		return
	state = GameState.IDLE
	board.input_locked = false


func _on_shuffle_pressed() -> void:
	if state != GameState.IDLE or shuffle_left <= 0:
		return
	var board_tiles: Array[TeTile3D] = []
	for t in board.tiles:
		if not t.in_tray:
			board_tiles.append(t)
	if board_tiles.is_empty():
		return
	state = GameState.BUSY
	board.input_locked = true
	shuffle_left -= 1
	var ids: Array[int] = []
	for t in board_tiles:
		ids.append(t.icon_id)
	ids.shuffle()
	# Spin-flip every board tile while the icons swap at half-spin.
	var tw: Tween = create_tween().set_parallel(true)
	for i in board_tiles.size():
		var t: TeTile3D = board_tiles[i]
		(
			tw
			. tween_property(t, "rotation:y", t.rotation.y + TAU, 0.40)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN_OUT)
		)
	var swap: Tween = create_tween()
	swap.tween_interval(0.20)
	swap.tween_callback(
		func() -> void:
			for i in board_tiles.size():
				board_tiles[i].icon_id = ids[i]
	)
	await tw.finished
	_update_powerup_labels()
	state = GameState.IDLE
	board.input_locked = false


# --- static scene dressing (table + tray base), built in code -------------


func _build_table() -> void:
	# Walnut table filling the whole view, with a green felt mat under the board.
	var table := MeshInstance3D.new()
	table.mesh = TeRoundedBox.build(Vector3(40.0, 0.5, 40.0), 0.18, 4)
	table.position = Vector3(0, -0.25, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _grain_texture(Color(0.16, 0.10, 0.07), Color(0.27, 0.17, 0.11), 40)
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.025, 0.12, 0.5)
	wood.roughness = 0.75
	table.material_override = wood
	add_child(table)
	var mat_mesh := MeshInstance3D.new()
	mat_mesh.mesh = TeRoundedBox.build(Vector3(8.5, 0.06, 7.1), 0.03, 4)
	mat_mesh.position = Vector3(0, 0.0, -0.95)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.08, 0.26, 0.22)
	felt.roughness = 1.0
	mat_mesh.material_override = felt
	add_child(mat_mesh)


# Wood grain: low-frequency noise stretched along one axis, mapped between two browns.
func _grain_texture(dark: Color, light: Color, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	# Stretch the noise 1:14 so it reads as long grain lines, not blotches.
	tex.normalize = true
	var aniso := noise.duplicate() as FastNoiseLite
	aniso.frequency = 0.004
	aniso.domain_warp_enabled = true
	aniso.domain_warp_amplitude = 40.0
	aniso.domain_warp_frequency = 0.08
	tex.noise = aniso
	return tex


func _build_tray_base() -> void:
	# Rimmed wooden rack: a base plank plus four walls, lighter than the table.
	var rack := StandardMaterial3D.new()
	rack.albedo_texture = _grain_texture(Color(0.36, 0.23, 0.14), Color(0.50, 0.33, 0.20), 11)
	rack.uv1_triplanar = true
	rack.uv1_scale = Vector3(0.08, 0.35, 1.2)
	rack.roughness = 0.55
	var parts: Array = [
		[Vector3(7.15, 0.28, 1.24), Vector3(0, 0.0, TeTray3D.TRAY_Z)],
		[Vector3(7.35, 0.44, 0.12), Vector3(0, 0.08, TeTray3D.TRAY_Z - 0.66)],
		[Vector3(7.35, 0.44, 0.12), Vector3(0, 0.08, TeTray3D.TRAY_Z + 0.66)],
		[Vector3(0.12, 0.44, 1.44), Vector3(-3.66, 0.08, TeTray3D.TRAY_Z)],
		[Vector3(0.12, 0.44, 1.44), Vector3(3.66, 0.08, TeTray3D.TRAY_Z)],
	]
	for part in parts:
		var m := MeshInstance3D.new()
		m.mesh = TeRoundedBox.build(part[0], 0.05, 4)
		m.position = part[1]
		m.material_override = rack
		add_child(m)
	# 7 slot markers on the shelf top.
	var slot_tex: ImageTexture = await TeIconBaker.bake_slot(self)
	var slot_mat := StandardMaterial3D.new()
	slot_mat.albedo_texture = slot_tex
	slot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in TeTray3D.SLOTS:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.84, 0.84)
		q.mesh = quad
		q.material_override = slot_mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p: Vector3 = tray.slot_position(i)
		q.position = Vector3(p.x, 0.146, p.z)
		q.rotation_degrees = Vector3(-90, 0, 0)
		add_child(q)


# --- HUD: wordless buttons and icons, laid out for the MWM Play shell -------


func _build_hud() -> void:
	reset_button = _make_button("restart", Color(0.99, 0.97, 0.93), Color(0.30, 0.19, 0.11))
	reset_button.pressed.connect(_on_reset_pressed)
	undo_button = _make_button("undo", Color(0.85, 0.62, 0.20), Color(1, 1, 1))
	undo_button.pressed.connect(_on_undo_pressed)
	remove3_button = _make_button("clear3", Color(0.78, 0.33, 0.24), Color(1, 1, 1))
	remove3_button.pressed.connect(_on_remove3_pressed)
	shuffle_button = _make_button("shuffle", Color(0.18, 0.55, 0.47), Color(1, 1, 1))
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	for b in [undo_button, remove3_button, shuffle_button]:
		b.max_charges = POWERUP_CHARGES_PER_LEVEL
	# Header: flag + level number, tile + tiles left. Digits, no words.
	var brown := Color(0.23, 0.14, 0.08)
	_add_glyph(header_card, "flag", brown, Color(0, 0, 0, 0), Rect2(16, 24, 112, 112))
	_add_glyph(header_card, "tile", brown, Color(0, 0, 0, 0), Rect2(312, 24, 112, 112))
	for l in [level_label, progress_label]:
		l.add_theme_font_size_override("font_size", 84)
		l.add_theme_color_override("font_color", brown)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.position = Vector2(136, 0)
	level_label.size = Vector2(160, 160)
	progress_label.position = Vector2(432, 0)
	progress_label.size = Vector2(160, 160)
	# Win: a star and a "next" arrow. Lose: a full tray and a "try again" arrow.
	win_label.visible = false
	lose_label.visible = false
	# The panels only display; the tap that continues is read in
	# _unhandled_input, so the GUI must not swallow it.
	win_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lose_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_glyph(
		win_panel, "star", Color(0.96, 0.72, 0.12), Color(0, 0, 0, 0), Rect2(150, 30, 220, 220)
	)
	_add_glyph(win_panel, "next", Color(1, 1, 1), Color(0.10, 0.42, 0.20), Rect2(560, 40, 200, 200))
	var red := Color(0.58, 0.12, 0.12)
	_add_glyph(lose_panel, "tray_full", red, Color(0, 0, 0, 0), Rect2(110, 30, 340, 220))
	_add_glyph(lose_panel, "restart", Color(1, 1, 1), red, Rect2(560, 40, 200, 200))


func _make_button(kind: String, accent: Color, ink: Color) -> RoundButton:
	var b := RoundButton.new()
	b.kind = kind
	b.accent = accent
	b.ink = ink
	ui.add_child(b)
	return b


func _add_glyph(parent: Control, kind: String, ink: Color, disc: Color, r: Rect2) -> void:
	var g := GlyphView.new()
	g.kind = kind
	g.ink = ink
	g.disc = disc
	g.position = r.position
	g.size = r.size
	parent.add_child(g)


func _layout_ui() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	# Taller screens show more table above and below, wider ones more at the
	# sides; the 1080x1920 design frame always stays in view.
	var cam: Camera3D = $Camera
	# Under KEEP_WIDTH the fov is horizontal, so convert the design fov.
	if vs.y / vs.x > DESIGN_ASPECT:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		var half: float = tan(deg_to_rad(CAMERA_FOV * 0.5)) / DESIGN_ASPECT
		cam.fov = rad_to_deg(2.0 * atan(half))
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = CAMERA_FOV
	var hit: float = RoundButton.HIT
	var dy: float = maxf(0.0, safe_top_inset() - TOP_ROW_CLEAR)
	# Restart in the top-right corner, its touch area running to both edges.
	reset_button.top_pad = dy
	reset_button.size = Vector2(hit, hit + dy)
	reset_button.position = Vector2(vs.x - hit, 0)
	reset_button.queue_redraw()
	# Header between the free top-left square and the restart button.
	header_card.position = Vector2(SHELL_CORNER + 16.0, 40.0 + dy)
	header_card.size = Vector2(vs.x - hit - 16.0 - header_card.position.x, 160.0)
	# Power-ups just under the tray rack, never into the wrist strip.
	var rim_y: float = cam.unproject_position(Vector3(0, 0.3, TeTray3D.TRAY_Z + 0.72)).y
	var row_y: float = minf(rim_y + 2.0, vs.y - WRIST - hit)
	var row_w: float = hit * 3.0 + BUTTON_GAP * 2.0
	var bx: float = (vs.x - row_w) * 0.5
	for b in [undo_button, remove3_button, shuffle_button]:
		b.position = Vector2(bx, row_y)
		bx += hit + BUTTON_GAP
	for p in [win_panel, lose_panel]:
		p.position = Vector2((vs.x - p.size.x) * 0.5, (vs.y - p.size.y) * 0.5)
	hint_label.position = Vector2((vs.x - hint_label.size.x) * 0.5, vs.y - 70.0)


func _in_dead_zone(p: Vector2) -> bool:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	return p.y >= vs.y - WRIST or (p.x < SHELL_CORNER and p.y < SHELL_CORNER)


## Depth of the top screen cutout in viewport px (0 on desktop and on phones
## without a cutout). Uses the display safe area on phones, or fake_safe_top.
func safe_top_inset() -> float:
	var top_px: float = fake_safe_top
	if top_px < 0.0:
		if not OS.has_feature("mobile"):
			return 0.0
		top_px = float(DisplayServer.get_display_safe_area().position.y)
	var win: Vector2i = DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return maxf(0.0, top_px * get_viewport().get_visible_rect().size.y / float(win.y))


func _next_level() -> int:
	return 1 if current_level + 1 > max_level else current_level + 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress(_next_level() if state == GameState.WON else current_level)


# Level progress survives app restarts. Board, tray and power-up state are
# not saved: the player resumes at the start of the level they were on.
func _save_progress(level: int) -> void:
	highest_level = maxi(highest_level, level)
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	var data: Dictionary = {
		"version": SAVE_VERSION, "current_level": level, "highest_level": highest_level
	}
	f.store_string(JSON.stringify(data))
	f.close()


# Missing, unreadable or corrupt save: keep the defaults and start fresh.
func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		push_warning("Save file unreadable, starting fresh")
		return
	var data: Dictionary = json.data
	var level: Variant = data.get("current_level")
	if not (level is float or level is int):
		push_warning("Save file has no level, starting fresh")
		return
	current_level = clampi(int(level), 1, max_level)
	var best: Variant = data.get("highest_level", current_level)
	highest_level = (
		clampi(int(best), current_level, max_level)
		if (best is float or best is int)
		else current_level
	)
	print("Save: resuming at level %d (highest %d)" % [current_level, highest_level])


# --- dev harness: TILE_DEVSHOT=/path.png [TILE_DEVTAPS=N] ------------------
# Runs only when the env var is set. Optionally simulates N taps through the
# real picking path, asserts the board shrank when a triple was tapped, saves
# a screenshot and exits. Used for local visual iteration; inert in release.


func _maybe_devshot() -> void:
	var shot_path: String = OS.get_environment("TILE_DEVSHOT")
	if shot_path == "":
		return
	var dev_level: int = int(OS.get_environment("TILE_DEVLEVEL"))
	if dev_level > 0:
		load_level(dev_level)
		current_level = dev_level
	var taps: int = int(OS.get_environment("TILE_DEVTAPS"))
	await get_tree().create_timer(0.8).timeout
	var mode: String = OS.get_environment("TILE_DEVMODE")
	if mode == "power":
		await _devshot_power()
	elif mode == "lose":
		await _devshot_lose()
	var before: int = board.remaining_count()
	var tapped: int = 0
	for i in taps:
		var target: TeTile3D = _devshot_pick_target()
		if target == null:
			break
		var screen: Vector2 = board.camera.unproject_position(target.global_position)
		var hit: TeTile3D = board.pick_tile(screen)
		if hit == null or hit.blocked:
			print("DEVSHOT: pick mismatch at tap %d" % i)
			break
		_on_tile_tapped(hit)
		tapped += 1
		while state == GameState.BUSY:
			await get_tree().process_frame
		if state != GameState.IDLE:
			break
	await get_tree().create_timer(0.5).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	if taps > 0:
		var after: int = board.remaining_count()
		# Tiles that left the tray again were cleared as triples: at least one
		# triple, and always whole triples. 5 taps = 1 triple + 2 in the tray.
		var cleared: int = tapped - tray.size()
		var ok: bool = (
			tapped >= 3 and after == before - tapped and cleared >= 3 and cleared % 3 == 0
		)
		print(
			(
				"DEVSHOT: taps=%d board %d->%d tray=%d => %s"
				% [tapped, before, after, tray.size(), "PASS" if ok else "FAIL"]
			)
		)
	else:
		print("DEVSHOT: screenshot saved")
	get_tree().quit(0)


func _devshot_wait_idle() -> void:
	while state == GameState.BUSY:
		await get_tree().process_frame


# Exercise Undo, Clear 3 and Shuffle through their real handlers.
func _devshot_power() -> void:
	_on_tile_tapped(_devshot_pick_no_triple())
	await _devshot_wait_idle()
	_on_undo_pressed()
	await _devshot_wait_idle()
	var ok_undo: bool = tray.is_empty() and undo_left == 2 and move_stack.is_empty()
	print("DEVSHOT undo => %s" % ("PASS" if ok_undo else "FAIL"))
	for i in 3:
		_on_tile_tapped(_devshot_pick_no_triple())
		await _devshot_wait_idle()
	var ok_fill: bool = tray.size() == 3
	_on_remove3_pressed()
	await _devshot_wait_idle()
	var ok_r3: bool = ok_fill and tray.is_empty() and remove3_left == 2
	print("DEVSHOT clear3 => %s" % ("PASS" if ok_r3 else "FAIL"))
	_on_shuffle_pressed()
	await _devshot_wait_idle()
	print("DEVSHOT shuffle => %s" % ("PASS" if shuffle_left == 2 else "FAIL"))


# Fill the tray with pairs only (never a third copy) until it overflows.
func _devshot_lose() -> void:
	while state == GameState.IDLE:
		var t: TeTile3D = _devshot_pick_no_triple()
		if t == null:
			break
		_on_tile_tapped(t)
		await _devshot_wait_idle()
	print("DEVSHOT lose => %s" % ("PASS" if state == GameState.LOST else "FAIL"))


# An unblocked board tile whose icon has at most 1 copy in the tray.
func _devshot_pick_no_triple() -> TeTile3D:
	for t in board.tiles:
		if t.in_tray or t.blocked:
			continue
		var in_tray_count: int = 0
		for o in tray.tiles:
			if o.icon_id == t.icon_id:
				in_tray_count += 1
		if in_tray_count < 2:
			return t
	return null


# Prefer completing a triple: pick an icon with >=3 unblocked tiles.
func _devshot_pick_target() -> TeTile3D:
	var by_icon: Dictionary = {}
	for t in board.tiles:
		if t.in_tray or t.blocked:
			continue
		if not by_icon.has(t.icon_id):
			by_icon[t.icon_id] = []
		by_icon[t.icon_id].append(t)
	# Continue an icon already started in the tray.
	for t in tray.tiles:
		if by_icon.has(t.icon_id):
			return by_icon[t.icon_id][0]
	for k in by_icon.keys():
		if by_icon[k].size() >= 3:
			return by_icon[k][0]
	for k in by_icon.keys():
		return by_icon[k][0]
	return null
