extends Control

## Start screen (DESIGN 2a): wordmark, one picture card per integrated game,
## adult corner top-right, decorative hills in the wrist strip. No music.

const TILE := Vector2(468, 440)
## Hit area = tile + 8 px each side (rule 5, DESIGN 2a note).
const HIT_PAD: float = 8.0
const GAP: float = 48.0
const ROW_Y: Array[float] = [232.0, 720.0, 1208.0]
const ART := Vector2(440, 318)
const ART_INSET: float = 14.0
const BANDS := {
	"ball-connect": Color(0.902, 0.867, 0.953),
	"water-sort": Color(0.827, 0.910, 0.961),
	"tile-explorer": Color(0.941, 0.863, 0.769),
	"spotless": Color(0.804, 0.933, 0.929),
	"timber-valley": Color(0.847, 0.925, 0.796),
}

var tiles: Dictionary = {}  # slug -> ShellTap (test hook)
var adult_corner: ShellTap
var _frame: Control


func _ready() -> void:
	_frame = ShellUi.screen_frame(self)
	var hills := Control.new()
	hills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hills.draw.connect(_draw_hills.bind(hills))
	_frame.add_child(hills)
	hills.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hills.resized.connect(hills.queue_redraw)

	var mark := ShellUi.label("MWM Play", "fredoka", 56, ShellUi.GREEN)
	mark.position = Vector2(56, 104 - 40)
	_frame.add_child(mark)

	_build_tiles()
	_build_adult_corner()


func _build_tiles() -> void:
	var vs := get_viewport_rect().size
	# Taller screens: the tile block centres between top items and the strip.
	var dy := maxf(0.0, (vs.y - ShellUi.DESIGN_H) * 0.5)
	var n := Shell.GAMES.size()
	for i in n:
		var slug: String = Shell.GAMES[i]
		var a: ShellAdapter = Shell.adapters[slug]
		var row := i / 2
		var x := 48.0 + (i % 2) * (TILE.x + GAP)
		if i == n - 1 and n % 2 == 1:
			x = (ShellUi.DESIGN_W - TILE.x) * 0.5
		var t := _make_tile(a)
		t.position = Vector2(x, ROW_Y[row] + dy) - Vector2(HIT_PAD, HIT_PAD)
		_frame.add_child(t)
		tiles[slug] = t


func _make_tile(a: ShellAdapter) -> ShellTap:
	var t := ShellTap.new()
	t.size = TILE + Vector2(HIT_PAD, HIT_PAD) * 2.0
	t.pivot_offset = t.size * 0.5
	var art: Texture2D = load(a.tile_art)
	var band: Color = BANDS.get(a.slug, ShellUi.LINE)
	var body := Panel.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.position = Vector2(HIT_PAD, HIT_PAD)
	body.size = TILE
	var normal := ShellUi.box(band, 40, ShellUi.EDGE, 3)
	normal.shadow_color = Color(0, 0, 0, 0.08)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 5)
	body.add_theme_stylebox_override("panel", normal)
	t.add_child(body)
	var pic := TextureRect.new()
	pic.texture = art
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.position = Vector2(ART_INSET, ART_INSET)
	pic.size = ART
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.add_child(pic)
	var name_label := ShellUi.label(a.title, "andika_bold", 50)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, ART_INSET + ART.y)
	name_label.size = Vector2(TILE.x, TILE.y - ART_INSET - ART.y - 4)
	body.add_child(name_label)
	var pressed := ShellUi.box(ShellUi.GREEN_SOFT, 40, ShellUi.EDGE, 3)
	t.set_meta("normal", normal)
	t.set_meta("pressed", pressed)
	t.tapped.connect(Shell.launch.bind(a.slug), CONNECT_DEFERRED)
	t.down_changed.connect(_on_tile_down.bind(t, body))
	return t


## Touch-down: scale to 96% in 80 ms, spring back in 120 ms; with "less motion"
## only the band colour changes (DESIGN 3 motion table, rule 39).
func _on_tile_down(down: bool, t: ShellTap, body: Panel) -> void:
	if Shell.settings.less_motion:
		body.add_theme_stylebox_override("panel", t.get_meta("pressed" if down else "normal"))
		return
	var tw := t.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if down:
		tw.tween_property(t, "scale", Vector2(0.96, 0.96), 0.08)
	else:
		tw.set_trans(Tween.TRANS_BACK)
		tw.tween_property(t, "scale", Vector2.ONE, 0.12)


func _build_adult_corner() -> void:
	# Small, muted, not inviting: 104 px disc, hit area 160x160 to the corner
	# (rule 7, rule 3 floor met through the hit area; DESIGN 2a).
	adult_corner = ShellTap.new()
	adult_corner.position = Vector2(get_viewport_rect().size.x - 160, 0)
	adult_corner.size = Vector2(160, 160)
	adult_corner.draw_fn = _draw_adult_disc
	adult_corner.tapped.connect(Shell.goto.bind("gate", ""))
	add_child(adult_corner)
	var word := ShellUi.label("Voksne", "andika", 30, ShellUi.INK_SOFT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.position = Vector2(get_viewport_rect().size.x - 176, 156)
	word.size = Vector2(176, 44)
	add_child(word)


func _draw_adult_disc(c: ShellTap) -> void:
	var center := Vector2(160 - 88, 96)
	c.draw_circle(center, 52, ShellUi.GREEN_SOFT if c.is_down else ShellUi.PAPER)
	c.draw_arc(center, 51, 0, TAU, 72, ShellUi.EDGE, 3.0, true)
	var hole := ShellUi.GREEN_SOFT if c.is_down else ShellUi.PAPER
	ShellUi.draw_gear(c, center, 46, ShellUi.INK_SOFT, hole)


func _draw_hills(ci: Control) -> void:
	var h := ci.size.y
	_ellipse(ci, Vector2(250, h + 230), Vector2(820, 470), ShellUi.HILL_1)
	_ellipse(ci, Vector2(980, h + 260), Vector2(720, 510), ShellUi.HILL_2)
	_ellipse(ci, Vector2(560, h + 150), Vector2(560, 260), ShellUi.SAND)


func _ellipse(ci: Control, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 96:
		var a := TAU * i / 96.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


func on_back() -> void:
	Shell.send_to_background()
