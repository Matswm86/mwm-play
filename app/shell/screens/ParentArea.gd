extends Control

## Parent area "For voksne" (DESIGN 2d). Adult screen behind the gate; it may
## scroll (rule 20 applies to child screens only). Billing is a stub in this
## build: the unlock button says "Kommer snart" and never charges.

const CARD_W: float = 984.0
const PAD: float = 44.0
const INNER_W: float = CARD_W - PAD * 2.0
const ROW_H: float = 112.0
const LIMITS: Array[int] = [0, 15, 30, 45, 60]

var scroll: ScrollContainer
var rows: Dictionary = {}  # name -> ShellTap (test hook)
var _status: Label
var _used_label: Label
var _restart: ShellTap
var _segments: Array[ShellTap] = []


func _ready() -> void:
	var frame := ShellUi.screen_frame(self)
	var title := ShellUi.label("For voksne", "fredoka", 60)
	title.position = Vector2(212, 104 - 44)
	frame.add_child(title)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(48, 200)
	scroll.size = Vector2(CARD_W, frame.size.y - 200)
	frame.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 24)
	list.custom_minimum_size = Vector2(CARD_W, 0)
	scroll.add_child(list)
	list.add_child(_spacer(2))

	list.add_child(_unlock_card())
	list.add_child(_sound_card())
	list.add_child(_limit_card())
	list.add_child(_together_card())
	list.add_child(_about_card())
	list.add_child(_spacer(120))

	var home := ShellHomeButton.new()
	home.guard = false
	home.leave_requested.connect(Shell.goto.bind("start", ""))
	add_child(home)
	_refresh()


# ---------------------------------------------------------------- cards


func _card(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := ShellUi.box(ShellUi.CARD, 36, ShellUi.LINE, 3)
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(CARD_W, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(ShellUi.label(title, "andika_bold", 46))
	box.set_meta("panel", panel)
	return box


func _wrap(text: String, size: int, color: Color) -> Label:
	return ShellUi.wrapped(text, "andika", size, color, INNER_W)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _unlock_card() -> Control:
	var box := _card("Lås opp alle spillene")
	box.add_child(
		_wrap(
			(
				"Prøveversjonen har de første banene i hvert spill. Én betaling låser opp "
				+ "alle baner i alle spill, også spill som kommer senere. Ingen abonnement "
				+ "og ingen reklame."
			),
			34,
			ShellUi.INK_SOFT
		)
	)
	box.add_child(_spacer(26))
	# Stub: the price must come from Google Play Billing, never hard-coded
	# (rule 25), so this build shows no price at all.
	var buy := ShellTap.new()
	buy.custom_minimum_size = Vector2(INNER_W, 110)
	buy.draw_fn = func(t: ShellTap) -> void:
		var col := ShellUi.GREEN.darkened(0.15) if t.is_down else ShellUi.GREEN
		t.draw_style_box(ShellUi.box(col, 55), Rect2(Vector2.ZERO, t.size))
	var buy_text := ShellUi.label("Lås opp", "andika_bold", 44, ShellUi.CARD)
	buy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buy_text.size = Vector2(INNER_W, 110)
	buy.add_child(buy_text)
	buy.tapped.connect(_coming_soon)
	box.add_child(buy)
	rows["unlock"] = buy
	var restore := _text_button("Gjenopprett kjøp")
	restore.tapped.connect(_coming_soon)
	box.add_child(restore)
	_status = _wrap("Kommer snart. Kjøp er ikke klart i denne versjonen.", 34, ShellUi.INK_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	box.add_child(_status)
	return box.get_meta("panel")


func _coming_soon() -> void:
	_status.visible = true


func _text_button(text: String) -> ShellTap:
	var t := ShellTap.new()
	t.custom_minimum_size = Vector2(INNER_W, 80)
	var l := ShellUi.label(text, "andika_bold", 38, ShellUi.GREEN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(INNER_W, 80)
	t.add_child(l)
	t.draw_fn = func(c: ShellTap) -> void:
		if c.is_down:
			c.draw_style_box(ShellUi.box(ShellUi.GREEN_SOFT, 40), Rect2(Vector2.ZERO, c.size))
	return t


func _sound_card() -> Control:
	var box := _card("Lyd og bevegelse")
	box.add_child(_toggle_row("sound", "Lydeffekter", ""))
	box.add_child(_line())
	box.add_child(_toggle_row("music", "Musikk", ""))
	box.add_child(_line())
	box.add_child(_toggle_row("vibration", "Vibrasjon", ""))
	box.add_child(_line())
	# rule 39: one switch turns off shake, parallax and particles.
	box.add_child(
		_toggle_row("less_motion", "Mindre bevegelse", "Ingen risting, parallakse eller partikler")
	)
	return box.get_meta("panel")


func _line() -> Control:
	var c := ColorRect.new()
	c.color = ShellUi.LINE
	c.custom_minimum_size = Vector2(INNER_W, 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Whole row is the hit area. State shows by knob side, a check mark and the
## word På/Av, never by colour alone (rule 36).
func _toggle_row(key: String, text: String, sub: String) -> ShellTap:
	var t := ShellTap.new()
	t.custom_minimum_size = Vector2(INNER_W, ROW_H)
	var name_label := ShellUi.label(text, "andika", 38)
	name_label.position = Vector2(0, 26 if sub == "" else 8)
	t.add_child(name_label)
	if sub != "":
		var s := ShellUi.label(sub, "andika", 30, ShellUi.INK_SOFT)
		s.position = Vector2(0, 60)
		t.add_child(s)
	var word := ShellUi.label("", "andika_bold", 34)
	word.name = "Word"
	word.position = Vector2(INNER_W - 128 - 72, 30)
	t.add_child(word)
	t.draw_fn = _draw_toggle.bind(key)
	t.tapped.connect(_on_toggle.bind(key))
	rows[key] = t
	return t


func _draw_toggle(t: ShellTap, key: String) -> void:
	var on: bool = Shell.settings.get(key)
	var r := Rect2(t.size.x - 128, (t.size.y - 72) * 0.5, 128, 72)
	if t.is_down:
		t.draw_style_box(ShellUi.box(ShellUi.GREEN_SOFT, 20), Rect2(-12, 4, t.size.x + 24, t.size.y - 8))
	if on:
		t.draw_style_box(ShellUi.box(ShellUi.GREEN, 36), r)
		var c := Vector2(r.end.x - 36, r.get_center().y)
		t.draw_circle(c, 29, ShellUi.CARD)
		ShellUi.draw_check(t, c, 30, ShellUi.GREEN, 5.0)
	else:
		t.draw_style_box(ShellUi.box(ShellUi.CARD, 36, ShellUi.EDGE, 4), r)
		t.draw_circle(Vector2(r.position.x + 36, r.get_center().y), 26, ShellUi.EDGE)
	var word: Label = t.get_node("Word")
	word.text = "På" if on else "Av"
	word.add_theme_color_override("font_color", ShellUi.GREEN if on else ShellUi.INK_SOFT)


func _on_toggle(key: String) -> void:
	Shell.settings.set(key, not Shell.settings.get(key))
	Shell.save_settings()
	rows[key].queue_redraw()


func _limit_card() -> Control:
	var box := _card("Grense for spilletid")
	box.add_child(_spacer(8))
	var seg_row := HBoxContainer.new()
	seg_row.add_theme_constant_override("separation", 10)
	box.add_child(seg_row)
	for m in LIMITS:
		var t := ShellTap.new()
		t.custom_minimum_size = Vector2(171, 110)
		var l := ShellUi.label("Av" if m == 0 else "%d min" % m, "andika_bold", 36)
		l.name = "Text"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = Vector2(171, 110)
		t.add_child(l)
		t.draw_fn = _draw_segment.bind(m)
		t.tapped.connect(_on_limit.bind(m))
		seg_row.add_child(t)
		_segments.append(t)
		rows["limit_%d" % m] = t
	box.add_child(_spacer(8))
	box.add_child(
		_wrap("Spillet stopper ved neste naturlige pause. Ingen nedtelling.", 32, ShellUi.INK_SOFT)
	)
	_used_label = _wrap("", 34, ShellUi.INK)
	box.add_child(_used_label)
	_restart = _text_button("Start på nytt")
	_restart.tapped.connect(func() -> void:
		Shell.reset_used_time()
		_refresh())
	box.add_child(_restart)
	return box.get_meta("panel")


func _draw_segment(t: ShellTap, minutes: int) -> void:
	var sel := Shell.settings.limit_minutes == minutes
	var r := Rect2(Vector2.ZERO, t.size)
	if sel:
		t.draw_style_box(ShellUi.box(ShellUi.GREEN, 28), r)
	else:
		var bg := ShellUi.GREEN_SOFT if t.is_down else ShellUi.CARD
		t.draw_style_box(ShellUi.box(bg, 28, ShellUi.EDGE, 3), r)
	var l: Label = t.get_node("Text")
	l.add_theme_color_override("font_color", ShellUi.CARD if sel else ShellUi.INK)


func _on_limit(minutes: int) -> void:
	Shell.settings.limit_minutes = minutes
	Shell.save_settings()
	_refresh()


func _refresh() -> void:
	for s in _segments:
		s.queue_redraw()
	var on := Shell.settings.limit_minutes > 0
	_used_label.visible = on
	_restart.visible = on
	_used_label.text = "Brukt i dag: %d min" % int(Shell.settings.used_seconds / 60.0)


func _together_card() -> Control:
	var box := _card("Spill sammen")
	for slug in Shell.GAMES:
		var a: ShellAdapter = Shell.adapters[slug]
		box.add_child(_nav_row("tips_" + slug, a.title, "Tips til å spille sammen", a.tile_art))
		rows["tips_" + slug].tapped.connect(Shell.goto.bind("tips", slug))
	return box.get_meta("panel")


func _about_card() -> Control:
	var box := _card("Om appen")
	box.add_child(_nav_row("privacy", "Personvern", "", ""))
	rows["privacy"].tapped.connect(Shell.goto.bind("privacy", ""))
	box.add_child(_line())
	box.add_child(_nav_row("licences", "Lisenser og takk", "", ""))
	rows["licences"].tapped.connect(Shell.goto.bind("licences", ""))
	box.add_child(_line())
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var v := ShellUi.label("Versjon %s" % version, "andika", 32, ShellUi.INK_SOFT)
	v.custom_minimum_size = Vector2(INNER_W, 72)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(v)
	return box.get_meta("panel")


func _nav_row(key: String, text: String, sub: String, thumb: String) -> ShellTap:
	var t := ShellTap.new()
	var h := 128.0 if thumb != "" else ROW_H
	t.custom_minimum_size = Vector2(INNER_W, h)
	var x := 0.0
	if thumb != "":
		var pic := TextureRect.new()
		pic.texture = load(thumb)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.position = Vector2(0, (h - 96) * 0.5)
		pic.size = Vector2(96, 96)
		pic.clip_contents = true
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_child(pic)
		x = 126.0
	var name_label := ShellUi.label(text, "andika", 38)
	name_label.position = Vector2(x, 14 if sub != "" else (h - 52) * 0.5)
	t.add_child(name_label)
	if sub != "":
		var s := ShellUi.label(sub, "andika", 30, ShellUi.INK_SOFT)
		s.position = Vector2(x, 66)
		t.add_child(s)
	t.draw_fn = func(c: ShellTap) -> void:
		if c.is_down:
			c.draw_style_box(ShellUi.box(ShellUi.GREEN_SOFT, 20), Rect2(-12, 4, c.size.x + 24, c.size.y - 8))
		ShellUi.draw_chevron(c, Vector2(c.size.x - 28, c.size.y * 0.5), 40, ShellUi.INK_SOFT, 5.0)
	rows[key] = t
	return t


func on_back() -> void:
	Shell.goto("start")
