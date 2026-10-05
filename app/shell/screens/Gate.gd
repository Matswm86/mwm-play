extends Control

## Parent gate (DESIGN 2c, rule 23): three random digits 2-9, no repeats,
## written as Norwegian words; type them on the keypad. No per-digit hint, no
## red, no shake, no lock-out; a wrong answer clears the boxes and shows a new
## code. Every visit to the parent area asks again (rule 22).

const WORDS := {2: "to", 3: "tre", 4: "fire", 5: "fem", 6: "seks", 7: "sju", 8: "åtte", 9: "ni"}
const KEY := Vector2(290, 150)
const KEY_GAP: float = 28.0
const KEY_X: float = 78.0
## Mockup keypad starts at y 1010 and ends at 1694, inside the 256 px wrist
## strip (rule 6). Moved up 30 px so the last row ends at 1664.
const KEY_Y: float = 980.0
const BOX := Vector2(150, 140)
const BOX_GAP: float = 30.0
const BOX_Y: float = 820.0

var code: Array[int] = []
var typed: Array[int] = []
var keys: Dictionary = {}  # "0".."9", "del" -> ShellTap (test hook)
var _code_label: Label
var _hint: Label
var _boxes: Array[Control] = []
var _frame: Control


func _ready() -> void:
	_frame = ShellUi.screen_frame(self)
	var home := ShellHomeButton.new()
	home.guard = false  # leaving the gate is harmless: one tap
	home.leave_requested.connect(Shell.goto.bind("start", ""))
	add_child(home)

	var figures := Control.new()
	figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figures.size = Vector2(ShellUi.DESIGN_W, 440)
	figures.draw.connect(_draw_figures.bind(figures))
	_frame.add_child(figures)

	var title := ShellUi.label("Hent en voksen", "fredoka", 76)
	_center(title, 500, 100)
	_hint = ShellUi.label("Voksne: skriv tallene med sifre", "andika", 40, ShellUi.INK_SOFT)
	_center(_hint, 582, 56)

	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(120, 630)
	card.size = Vector2(840, 150)
	card.add_theme_stylebox_override("panel", ShellUi.box(ShellUi.CARD, 40, ShellUi.LINE, 3))
	_frame.add_child(card)
	_code_label = ShellUi.label("", "andika_bold", 84)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_code_label.size = card.size
	card.add_child(_code_label)

	var bx := (ShellUi.DESIGN_W - (BOX.x * 3 + BOX_GAP * 2)) * 0.5
	for i in 3:
		var b := Control.new()
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.position = Vector2(bx + i * (BOX.x + BOX_GAP), BOX_Y)
		b.size = BOX
		b.draw.connect(_draw_box.bind(b, i))
		_frame.add_child(b)
		_boxes.append(b)

	var layout := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "del"]
	for i in layout.size():
		var k: String = layout[i]
		if k == "":
			continue
		var t := ShellTap.new()
		t.position = Vector2(KEY_X + (i % 3) * (KEY.x + KEY_GAP), KEY_Y + (i / 3) * (KEY.y + KEY_GAP))
		t.size = KEY
		t.draw_fn = _draw_key.bind(k)
		t.tapped.connect(_on_key.bind(k))
		_frame.add_child(t)
		keys[k] = t
	_new_code(false)


func _center(l: Label, center_y: float, h: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, center_y - h * 0.5)
	l.size = Vector2(ShellUi.DESIGN_W, h)
	_frame.add_child(l)


func _new_code(fade: bool) -> void:
	var pool: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9]
	pool.shuffle()
	code = pool.slice(0, 3)
	typed.clear()
	var words := "  ·  ".join(code.map(func(d: int) -> String: return WORDS[d]))
	if fade and not Shell.settings.less_motion:
		var tw := create_tween()
		tw.tween_property(_code_label, "modulate:a", 0.0, 0.1)
		tw.tween_callback(func() -> void: _code_label.text = words)
		tw.tween_property(_code_label, "modulate:a", 1.0, 0.1)
	else:
		_code_label.text = words
	_redraw_boxes()


func _on_key(k: String) -> void:
	if k == "del":
		if not typed.is_empty():
			typed.pop_back()
	elif typed.size() < 3:
		typed.append(int(k))
	_redraw_boxes()
	if typed.size() < 3:
		return
	if typed == code:
		Shell.goto("parent")
	else:
		_hint.text = "Prøv igjen med de nye tallene"
		_new_code(true)


func _redraw_boxes() -> void:
	for b in _boxes:
		b.queue_redraw()


func _draw_box(b: Control, i: int) -> void:
	var filled := i < typed.size()
	var edge := ShellUi.INK if filled else ShellUi.EDGE
	var sb := ShellUi.box(ShellUi.CARD, 24, edge, 4 if filled else 3)
	b.draw_style_box(sb, Rect2(Vector2.ZERO, b.size))
	if filled:
		var f := ShellUi.font("fredoka")
		var s := str(typed[i])
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
		var at := Vector2((b.size.x - w) * 0.5, 96)
		b.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, ShellUi.INK)


func _draw_key(t: ShellTap, k: String) -> void:
	var sb := ShellUi.box(ShellUi.GREEN_SOFT if t.is_down else ShellUi.CARD, 36, ShellUi.EDGE, 3)
	t.draw_style_box(sb, Rect2(Vector2.ZERO, t.size))
	if k == "del":
		ShellUi.draw_backspace(t, t.size * 0.5, 80, ShellUi.INK, 6.0)
		return
	var f := ShellUi.font("fredoka")
	var w := f.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	var at := Vector2((t.size.x - w) * 0.5, 98)
	t.draw_string(f, at, k, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, ShellUi.INK)


func _draw_figures(c: Control) -> void:
	# Adult (plum) and child (green): "get a grown-up" without words.
	c.draw_circle(Vector2(470, 214), 34, ShellUi.PLUM)
	c.draw_style_box(ShellUi.box(ShellUi.PLUM, 56), Rect2(414, 260, 112, 130))
	c.draw_circle(Vector2(610, 280), 24, ShellUi.GREEN)
	c.draw_style_box(ShellUi.box(ShellUi.GREEN, 40), Rect2(570, 312, 80, 92))


func on_back() -> void:
	Shell.goto("start")
