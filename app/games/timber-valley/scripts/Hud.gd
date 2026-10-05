class_name TvHud
extends CanvasLayer

## Screen overlay: money counter, hints, toasts, upgrade shop, menu, finish screen and joystick.

## Emitted when the player closes the "Valley complete" card (World pans to the next gateway).
signal valley_card_closed

const CREAM := Color(1.0, 0.97, 0.9)
const INK := Color(0.2, 0.15, 0.1)
const GREEN := Color(0.33, 0.66, 0.34)
const GOLD := Color(1.0, 0.78, 0.22)
## Every tappable control is at least HIT x HIT px: 12.7 mm at 430 dpi (216 / 16.93 px per mm),
## the child touch floor MWM Play uses (docs: CHILD_UX_RESEARCH rule 1).
const HIT := 216.0
## Nothing tappable in the bottom strip (16 mm = 256 px at 1080x1920): a resting wrist.
const WRIST := 256.0
## Upgrade -> icon on its tile.
const UPGRADE_GLYPH := {
	"capacity": "backpack", "speed": "speed", "axe": "axe", "machines": "gear", "workers": "cup",
	"prices": "star", "saws": "blade", "crew": "cup", "fame": "star",
}
const HudGlyph := preload("res://games/timber-valley/scripts/HudGlyph.gd")
## The money pill and menu disc sit this far below the top edge; a camera cutout deeper than
## this pushes them down by the difference (touch areas still start at the top edge).
const TOP_CLEAR := 30.0

var font: Font
var money_label: Label
var money_pill: PanelContainer
var hint: Label
var hint_pill: PanelContainer
var toast_label: Label
var toast_pill: PanelContainer
var upgrades_panel: PanelContainer
var upgrade_rows: Dictionary = {}
## Which office board is open: 1 = Valley 1 (global), 2 = Riverside Office (V2 + extended global),
## 3 = Highland Office (V3).
var upgrade_board: int = 1
var _up_title: Label
var _up_list: GridContainer
var valley_label: Label
var valley_pill: PanelContainer
var valley_card: PanelContainer
var menu_panel: PanelContainer
var finish_panel: PanelContainer
var sound_btn: Button
var music_btn: Button
var menu_btn: Button
## Test hook: a fake top safe-area inset in window px; < 0 = ask the display.
var fake_safe_top: float = -1.0
var _top_box: VBoxContainer
var joy_base: Control
## Carried stack: item icon + "count/capacity" (top left, hidden when empty).
var carry_pill: PanelContainer
var carry_icon: TextureRect
var carry_label: Label
## Bottom-corner button that throws the whole carried stack away (only while carrying).
var drop_btn: Button
var _carry_key: String = ""
var joy_knob: Control
var _shown_money: float = 0.0
var _touch_index: int = -1
var _joy_origin: Vector2
var _toast_tween: Tween
## Full-screen fade for handcar rides.
var _fade: ColorRect
var _fading: bool = false
var _covered: bool = false
const JOY_RADIUS := 110.0


func _ready() -> void:
	TimberGame.hud = self
	font = TvFx.font()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top(root)
	_build_joystick(root)
	_build_upgrades(root)
	_build_menu(root)
	_build_finish(root)
	_build_valley_card(root)
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.06, 0.04, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	root.add_child(_fade)
	# Inside a host app the menu (sound, music, start over) belongs to the host's parent area.
	var in_shell := TimberGame.in_shell()
	menu_btn.visible = not in_shell
	sound_btn.visible = not in_shell
	music_btn.visible = not in_shell
	apply_safe_area()
	get_viewport().size_changed.connect(apply_safe_area)
	_shown_money = TimberGame.money
	TimberGame.money_changed.connect(_on_money)
	TimberGame.upgraded.connect(func(_i: String, _l: int) -> void: _refresh_upgrades())
	_update_money_text()


func _style(bg: Color, radius: int, pad: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 8
	sb.content_margin_right = pad + 8
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, bg: Color, size: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	var n := _style(bg, 26, 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.08), 26, 12))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.12), 26, 12))
	b.add_theme_stylebox_override("disabled", _style(Color(0.62, 0.6, 0.56), 26, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: TimberSfx.play("click", -6.0))
	return b


## Icon-only button, HIT x HIT or larger, acting on release (Button default). bg = rounded
## coloured button; disc = transparent button with a round coloured disc inside the hit area.
func _glyph_button(kind: String, bg: Color, disc: Color = Color(0, 0, 0, 0)) -> Button:
	var b := _button("", bg if bg.a > 0.0 else GREEN)
	b.custom_minimum_size = Vector2(HIT, HIT)
	b.focus_mode = Control.FOCUS_NONE
	if bg.a <= 0.0:
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var g := HudGlyph.new()
	g.kind = kind
	g.disc = disc
	b.add_child(g)
	return b


func _set_glyph(b: Button, kind: String) -> void:
	for c in b.get_children():
		if c.get_script() == HudGlyph:
			c.set("kind", kind)
			(c as Control).queue_redraw()


func _build_top(root: Control) -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 70
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	_top_box = top
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	money_pill = PanelContainer.new()
	money_pill.add_theme_stylebox_override("panel", _style(CREAM, 40, 12))
	money_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(money_pill)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 14)
	money_pill.add_child(mrow)
	var coin := TvCoinIcon.new()
	coin.custom_minimum_size = Vector2(58, 58)
	mrow.add_child(coin)
	money_label = _label("$0", 58)
	mrow.add_child(money_label)
	# Valley chip under the money pill: "Birch Bend 7/19".
	valley_pill = PanelContainer.new()
	valley_pill.add_theme_stylebox_override("panel", _style(Color(0.18, 0.3, 0.16, 0.75), 24, 6))
	valley_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	valley_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(valley_pill)
	valley_label = _label("", 32, Color.WHITE)
	valley_pill.add_child(valley_label)
	valley_pill.visible = false
	hint_pill = PanelContainer.new()
	hint_pill.add_theme_stylebox_override("panel", _style(Color(0.1, 0.12, 0.08, 0.6), 30, 10))
	hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(hint_pill)
	hint = _label("", 40, Color.WHITE)
	hint_pill.add_child(hint)
	hint_pill.visible = false
	toast_pill = PanelContainer.new()
	toast_pill.add_theme_stylebox_override("panel", _style(GREEN, 34, 14))
	toast_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(toast_pill)
	toast_label = _label("", 46, Color.WHITE)
	toast_pill.add_child(toast_label)
	toast_pill.modulate.a = 0.0
	_build_carry(root)
	drop_btn = _glyph_button("drop", Color(0, 0, 0, 0), Color(0.72, 0.36, 0.28, 0.92))
	drop_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# HIT square on the right edge, just above the wrist strip; the drawn disc sits inside it.
	drop_btn.offset_left = -HIT
	drop_btn.offset_top = -WRIST - HIT
	drop_btn.offset_right = 0
	drop_btn.offset_bottom = -WRIST
	drop_btn.visible = false
	drop_btn.pressed.connect(func() -> void:
		if TimberGame.player and TimberGame.player.has_method("dump"):
			TimberGame.player.dump())
	root.add_child(drop_btn)
	# Top-right corner, hit area running to both screen edges (the top-left corner stays free).
	menu_btn = _glyph_button("menu", Color(0, 0, 0, 0), Color(0.25, 0.3, 0.22, 0.85))
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.offset_left = -HIT
	menu_btn.offset_top = 0
	menu_btn.offset_right = 0
	menu_btn.offset_bottom = HIT
	menu_btn.pressed.connect(func() -> void: menu_panel.visible = not menu_panel.visible)
	root.add_child(menu_btn)


func _build_carry(root: Control) -> void:
	carry_pill = PanelContainer.new()
	carry_pill.add_theme_stylebox_override("panel", _style(CREAM, 34, 8))
	carry_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Right side, just above the DROP button (the top-left corner stays free for a host app).
	carry_pill.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	carry_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	carry_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	carry_pill.offset_right = -30
	carry_pill.offset_left = -30
	carry_pill.offset_bottom = -WRIST - HIT - 12
	carry_pill.offset_top = -WRIST - HIT - 12
	carry_pill.custom_minimum_size = Vector2(0, 80)
	carry_pill.visible = false
	root.add_child(carry_pill)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	carry_pill.add_child(r)
	carry_icon = TextureRect.new()
	carry_icon.custom_minimum_size = Vector2(64, 64)
	carry_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carry_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	carry_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(carry_icon)
	carry_label = _label("", 44)
	r.add_child(carry_label)


## Moves the top row below a notch or punch-hole camera; the menu's touch area keeps the top edge.
func apply_safe_area() -> void:
	var dy := maxf(0.0, safe_top_inset() - TOP_CLEAR)
	_top_box.offset_top = 70 + dy
	menu_btn.offset_bottom = HIT + dy
	for c in menu_btn.get_children():
		if c.get_script() == HudGlyph:
			c.set("top_pad", dy)
			(c as Control).queue_redraw()


## Depth of the top screen cutout in viewport px (0 on desktop and on phones without one).
func safe_top_inset() -> float:
	var top_px := fake_safe_top
	if top_px < 0.0:
		if not OS.has_feature("mobile"):
			return 0.0
		top_px = float(DisplayServer.get_display_safe_area().position.y)
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return maxf(0.0, top_px * get_viewport().get_visible_rect().size.y / float(win.y))


## Called every frame: shows what the player carries, "MAX" in deep red when the stack is full.
func _update_carry() -> void:
	if TimberGame.player == null or not is_instance_valid(TimberGame.player):
		return
	var p: TvPlayer = TimberGame.player as TvPlayer
	if p == null or p.stack == null:
		return
	var n: int = p.stack.count()
	var t: String = p.stack.top_type()
	var cap: int = p.capacity()
	var key := "%s|%d|%d" % [t, n, cap]
	if key == _carry_key:
		return
	_carry_key = key
	carry_pill.visible = n > 0
	drop_btn.visible = n > 0
	if n == 0:
		return
	carry_icon.texture = TvModels.hud_icon(t)
	carry_icon.visible = carry_icon.texture != null
	var full: bool = n >= cap
	carry_label.text = ("MAX %d" % n) if full else ("%d/%d" % [n, cap])
	# Contrast on cream (my calc): deep red about 7:1, ink about 14:1.
	carry_label.add_theme_color_override("font_color", Color(0.66, 0.13, 0.08) if full else INK)


func _build_joystick(root: Control) -> void:
	joy_base = TvJoyCircle.new()
	(joy_base as TvJoyCircle).radius = JOY_RADIUS
	(joy_base as TvJoyCircle).fill = Color(1, 1, 1, 0.18)
	(joy_base as TvJoyCircle).ring = Color(1, 1, 1, 0.55)
	joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_base.visible = false
	root.add_child(joy_base)
	joy_knob = TvJoyCircle.new()
	(joy_knob as TvJoyCircle).radius = 48
	(joy_knob as TvJoyCircle).fill = Color(1, 1, 1, 0.85)
	(joy_knob as TvJoyCircle).ring = Color(1, 1, 1, 0.0)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_knob.visible = false
	root.add_child(joy_knob)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		# A tap on the DROP button must not also start the joystick.
		if t.pressed and drop_btn.visible and drop_btn.get_global_rect().has_point(t.position):
			return
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			_joy_origin = t.position
			joy_base.position = _joy_origin
			joy_knob.position = _joy_origin
			joy_base.visible = true
			joy_knob.visible = true
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			joy_base.visible = false
			joy_knob.visible = false
			if TimberGame.player:
				TimberGame.player.input_vector = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != _touch_index:
			return
		var off := d.position - _joy_origin
		if off.length() > JOY_RADIUS * 1.4:
			_joy_origin = d.position - off.normalized() * JOY_RADIUS * 1.4
			joy_base.position = _joy_origin
			off = d.position - _joy_origin
		var v := off.limit_length(JOY_RADIUS)
		joy_knob.position = _joy_origin + v
		if TimberGame.player:
			var raw := v / JOY_RADIUS
			TimberGame.player.input_vector = raw.normalized() * smoothstep(0.1, 0.55, raw.length()) if raw.length() > 0.08 else Vector2.ZERO


func _panel_base(root: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(CREAM, 42, 26))
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.anchor_left = 0.04
	p.anchor_right = 0.96
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -WRIST
	p.visible = false
	root.add_child(p)
	return p


func _build_upgrades(root: Control) -> void:
	upgrades_panel = _panel_base(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	upgrades_panel.add_child(v)
	_up_title = _label("Upgrades", 56)
	_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_up_title)
	_up_list = GridContainer.new()
	_up_list.columns = 2
	_up_list.add_theme_constant_override("h_separation", 16)
	_up_list.add_theme_constant_override("v_separation", 16)
	v.add_child(_up_list)
	_build_board(1)
	TimberGame.money_changed.connect(func(_v: int, _d: int) -> void:
		if upgrades_panel.visible:
			_refresh_upgrades())


## Board 1: the six global upgrades. Board 2: Birch Bend upgrades plus the extended global levels.
## Board 3: Maple Highlands upgrades.
func _build_board(board: int) -> void:
	upgrade_board = board
	upgrade_rows.clear()
	for c in _up_list.get_children():
		c.queue_free()
	_up_title.text = {1: "Upgrades", 2: "Riverside Office", 3: "Highland Office", 4: "Harbor Office", 5: "Mountain Office"}.get(board, "Upgrades")
	var specs: Array = []
	if board == 1:
		for id in TimberGame.UPGRADES:
			specs.append({"key": id, "region": 0, "ext": false, "name": TimberGame.UPGRADES[id].name, "desc": TimberGame.UPGRADES[id].desc})
	else:
		for key in ["saws", "crew", "fame"]:
			var info: Dictionary = TvBalance.REGION_UPGRADE_INFO[key]
			specs.append({"key": key, "region": board, "ext": false, "name": info.name, "desc": info.desc})
		for id in (TvBalance.GLOBAL_EXT if board == 2 else {}):
			specs.append({"key": id, "region": 0, "ext": true, "name": TimberGame.UPGRADES[id].name, "desc": TimberGame.UPGRADES[id].desc + " (all valleys)"})
	for spec in specs:
		var sp: Dictionary = spec
		var t := _upgrade_tile(sp)
		var btn: Button = t.btn
		btn.pressed.connect(func() -> void:
			var ok := false
			if int(sp.region) > 0:
				ok = TimberGame.buy_region_upgrade(int(sp.region), str(sp.key))
			else:
				ok = TimberGame.buy_upgrade(str(sp.key), bool(sp.ext))
			if ok:
				TimberSfx.play("upgrade", -3.0)
			_refresh_upgrades())
		_up_list.add_child(btn)
		upgrade_rows["%d:%s" % [sp.region, sp.key]] = t


## One upgrade = one tile: the whole tile is the buy button (HIT tall). Icon, name, a short
## line, level pips (filled vs hollow) and the price with a coin.
func _upgrade_tile(sp: Dictionary) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, HIT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _tile_style(Color.WHITE))
	btn.add_theme_stylebox_override("hover", _tile_style(Color.WHITE))
	btn.add_theme_stylebox_override("pressed", _tile_style(Color(0.89, 0.94, 0.92)))
	btn.add_theme_stylebox_override("disabled", _tile_style(Color(0.93, 0.91, 0.87)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(func() -> void: TimberSfx.play("click", -6.0))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 10
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	var g := HudGlyph.new()
	g.kind = str(UPGRADE_GLYPH.get(str(sp.key), "star"))
	g.ink = INK
	g.scale_k = 0.42
	g.custom_minimum_size = Vector2(96, 96)
	row.add_child(g)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var name_l := _label(str(sp.name), 34)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(name_l)
	var desc := _label(str(sp.desc), 24, Color(0.42, 0.36, 0.3))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(bottom)
	var pips := _label("", 28, GREEN)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(pips)
	var coin := TvCoinIcon.new()
	coin.custom_minimum_size = Vector2(38, 38)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(coin)
	var price := _label("", 38)
	bottom.add_child(price)
	return {"btn": btn, "pips": pips, "price": price, "coin": coin, "spec": sp}


func _tile_style(bg: Color) -> StyleBoxFlat:
	var sb := _style(bg, 26, 0)
	sb.border_color = Color(0.56, 0.51, 0.44)
	sb.set_border_width_all(3)
	return sb


func _refresh_upgrades() -> void:
	for k in upgrade_rows:
		var r: Dictionary = upgrade_rows[k]
		var sp: Dictionary = r.spec
		var region := int(sp.region)
		var key := str(sp.key)
		var lvl := 0
		var mx := 0
		var can := false
		var cost := 0
		if region > 0:
			lvl = TimberGame.region_level(region, key)
			mx = TvBalance.REGION_UPGRADE_MAX
			can = TimberGame.can_region_upgrade(region, key)
			cost = TimberGame.region_cost(region, key) if can else 0
		else:
			lvl = TimberGame.level(key)
			mx = TimberGame.max_level(key, bool(sp.ext))
			can = TimberGame.can_upgrade(key, bool(sp.ext))
			cost = TimberGame.upgrade_cost(key) if can else 0
		(r.pips as Label).text = "●".repeat(lvl) + "○".repeat(maxi(mx - lvl, 0))
		var btn: Button = r.btn
		var price: Label = r.price
		(r.coin as Control).visible = can
		if not can:
			price.text = "MAX"
			btn.disabled = true
			btn.modulate.a = 1.0
		else:
			price.text = TimberGame.fmt(cost)
			btn.disabled = TimberGame.money < cost
			# Not affordable yet: greyed and faded, so it reads without colour.
			btn.modulate.a = 0.55 if btn.disabled else 1.0


func open_upgrades(board: int = 1) -> void:
	if board != upgrade_board:
		_build_board(board)
	_refresh_upgrades()
	TimberSfx.play("open", -4.0)
	upgrades_panel.visible = true
	_cover()
	upgrades_panel.pivot_offset = upgrades_panel.size * Vector2(0.5, 1.0)
	upgrades_panel.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(upgrades_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func close_upgrades() -> void:
	upgrades_panel.visible = false
	_cover()


## Tells World whether a big panel covers the screen (it skips the shadow pass meanwhile).
## Also checked every frame, so a panel hidden any other way restores the shadows.
func _cover() -> void:
	var on := upgrades_panel.visible or valley_card.visible or finish_panel.visible
	if on != _covered and TimberGame.world and TimberGame.world.has_method("set_ui_cover"):
		_covered = on
		TimberGame.world.set_ui_cover(on)


func _build_menu(root: Control) -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _style(CREAM, 42, 28))
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.anchor_left = 0.12
	menu_panel.anchor_right = 0.88
	menu_panel.anchor_top = 0.3
	menu_panel.anchor_bottom = 0.3
	menu_panel.visible = false
	root.add_child(menu_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	menu_panel.add_child(v)
	var t := _label("Timber Valley", 58)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var info := _label("A calm lumber mill. No ads, no timers.\nProgress saves on its own.", 30, Color(0.42, 0.36, 0.3))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 40)
	v.add_child(toggles)
	sound_btn = _glyph_button("sound_on", GREEN)
	sound_btn.pressed.connect(func() -> void:
		TimberGame.sound_on = not TimberGame.sound_on
		TimberSfx.apply_sound_setting()
		_sound_text()
		TimberGame.save_game())
	toggles.add_child(sound_btn)
	music_btn = _glyph_button("music_on", GREEN)
	music_btn.pressed.connect(func() -> void:
		TimberGame.music_on = not TimberGame.music_on
		TimberSfx.apply_sound_setting()
		_sound_text()
		TimberGame.save_game())
	toggles.add_child(music_btn)
	_sound_text()
	var reset := _button("Start over", Color(0.75, 0.38, 0.3), 36)
	reset.custom_minimum_size.y = HIT
	var confirm_state := [false]
	reset.pressed.connect(func() -> void:
		if confirm_state[0]:
			TimberGame.reset_game()
		else:
			confirm_state[0] = true
			reset.text = "Tap again to erase your valley")
	v.add_child(reset)
	var close := _button("Back to the valley", Color(0.35, 0.45, 0.3), 40)
	close.custom_minimum_size.y = HIT
	close.pressed.connect(func() -> void:
		menu_panel.visible = false
		confirm_state[0] = false
		reset.text = "Start over")
	v.add_child(close)


## Sound and music show as a speaker and a note; "off" adds a cross or a slash (shape, not colour).
func _sound_text() -> void:
	_set_glyph(sound_btn, "sound_on" if TimberGame.sound_on else "sound_off")
	_set_glyph(music_btn, "music_on" if TimberGame.music_on else "music_off")


func _build_finish(root: Control) -> void:
	finish_panel = PanelContainer.new()
	finish_panel.add_theme_stylebox_override("panel", _style(CREAM, 42, 34))
	finish_panel.set_anchors_preset(Control.PRESET_CENTER)
	finish_panel.anchor_left = 0.08
	finish_panel.anchor_right = 0.92
	finish_panel.anchor_top = 0.28
	finish_panel.anchor_bottom = 0.28
	finish_panel.visible = false
	root.add_child(finish_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	finish_panel.add_child(v)
	var t := _label("The Grand Timber Station is open!", 52, GREEN)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var body := _label("", 34)
	body.name = "Body"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var keep := _glyph_button("next", GREEN)
	keep.pressed.connect(func() -> void:
		finish_panel.visible = false
		_cover())
	v.add_child(keep)


func _build_valley_card(root: Control) -> void:
	valley_card = PanelContainer.new()
	valley_card.add_theme_stylebox_override("panel", _style(CREAM, 42, 34))
	valley_card.set_anchors_preset(Control.PRESET_CENTER)
	valley_card.anchor_left = 0.08
	valley_card.anchor_right = 0.92
	valley_card.anchor_top = 0.28
	valley_card.anchor_bottom = 0.28
	valley_card.visible = false
	root.add_child(valley_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	valley_card.add_child(v)
	var t := _label("", 54, GREEN)
	t.name = "Title"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var body := _label("", 36)
	body.name = "Body"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var ok := _glyph_button("next", GREEN)
	ok.pressed.connect(close_valley_card)
	v.add_child(ok)


## "Valley complete" card (Lodge, Boathouse): name, time played there, money earned there.
func show_valley_card(region: int, next_line: String) -> void:
	var st: Dictionary = TimberGame.stats(region)
	var secs := int(float(st.get("time", 0.0)))
	var when := "%dh %02dm" % [secs / 3600, (secs / 60) % 60] if secs >= 3600 else "%d min" % maxi(secs / 60, 1)
	(valley_card.find_child("Title", true, false) as Label).text = "%s complete!" % str(TvBalance.REGIONS[region].name)
	(valley_card.find_child("Body", true, false) as Label).text = "Time here: %s\nEarned here: %s\n\n%s" % [when, TimberGame.fmt(int(st.get("earned", 0))), next_line]
	valley_card.visible = true
	_cover()
	TimberSfx.play("upgrade", 0.0)
	get_tree().create_timer(0.35).timeout.connect(func() -> void: TimberSfx.play("upgrade", 0.0))


func close_valley_card() -> void:
	if not valley_card.visible:
		return
	valley_card.visible = false
	_cover()
	valley_card_closed.emit()


## Fade out (fade_s), run `mid` (move the player and camera), fade back in. Ignored while one runs.
func fade_travel(mid: Callable) -> void:
	if _fading:
		return
	_fading = true
	var t := float(TvBalance.HANDCAR.fade_s)
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	tw.tween_callback(mid)
	tw.tween_interval(0.05)
	tw.tween_property(_fade, "color:a", 0.0, t)
	tw.tween_callback(func() -> void:
		_fade.visible = false
		_fading = false)


func set_valley(text: String) -> void:
	valley_pill.visible = text != ""
	if valley_label.text != text:
		valley_label.text = text


func show_finish() -> void:
	var body: Label = finish_panel.find_child("Body", true, false)
	var secs := 0
	for k in TimberGame.region_stats:
		secs += int(float(TimberGame.region_stats[k].get("time", 0.0)))
	body.text = "All five valleys are connected.\nYou earned %s in %dh %02dm.\n\nOrders and ships keep running, so feel free to stay." % [TimberGame.fmt(TimberGame.total_earned), secs / 3600, (secs / 60) % 60]
	finish_panel.visible = true
	_cover()
	TimberSfx.play("upgrade", 0.0)


func set_hint(text: String) -> void:
	hint_pill.visible = text != ""
	if hint.text != text:
		hint.text = text


func toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_pill.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_pill, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_pill, "modulate:a", 0.0, 0.5)


func _on_money(_value: int, delta: int) -> void:
	if delta > 0:
		money_pill.pivot_offset = money_pill.size * 0.5
		var tw := create_tween()
		tw.tween_property(money_pill, "scale", Vector2(1.12, 1.12), 0.08)
		tw.tween_property(money_pill, "scale", Vector2.ONE, 0.15)


func _process(delta: float) -> void:
	var target := float(TimberGame.money)
	if absf(_shown_money - target) > 0.5:
		_shown_money = lerpf(_shown_money, target, 1.0 - exp(-10.0 * delta))
	else:
		_shown_money = target
	_update_money_text()
	_update_carry()
	_cover()


func _update_money_text() -> void:
	money_label.text = TimberGame.fmt(int(round(_shown_money)))
