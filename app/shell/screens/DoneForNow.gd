extends Control

## "Ferdig for nå" (DESIGN 2f): shown by the parent play limit at a natural
## stopping point, never with a countdown (rules 26, 27, 29). Progress is saved
## before it appears (rule 28). Nothing moves. The check closes the app.

const STARS := [
	[Vector2(180, 260), 6.0],
	[Vector2(250, 420), 8.0],
	[Vector2(820, 330), 10.0],
	[Vector2(860, 640), 7.0],
	[Vector2(300, 700), 6.0],
]

var check: ShellTap
var adult_corner: ShellTap


func _ready() -> void:
	var frame := ShellUi.screen_frame(self, ShellUi.DUSK)
	var sky := Control.new()
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.size = Vector2(ShellUi.DESIGN_W, 800)
	sky.draw.connect(_draw_sky.bind(sky))
	frame.add_child(sky)

	var title := ShellUi.label("Ferdig for nå", "fredoka", 96, ShellUi.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 862 - 70)
	title.size = Vector2(ShellUi.DESIGN_W, 140)
	frame.add_child(title)
	var saved := ShellUi.label("Alt er lagret.", "andika", 44, ShellUi.MOON)
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saved.position = Vector2(0, 962 - 34)
	saved.size = Vector2(ShellUi.DESIGN_W, 68)
	frame.add_child(saved)

	# 240 px button (15.2 mm), 320 px hit area.
	check = ShellTap.new()
	check.position = Vector2(540 - 160, 1300 - 160)
	check.size = Vector2(320, 320)
	check.draw_fn = func(t: ShellTap) -> void:
		var c := t.size * 0.5
		t.draw_circle(c, 120, ShellUi.MOON if t.is_down else ShellUi.PAPER)
		ShellUi.draw_check(t, c, 120, ShellUi.DUSK, 16.0)
	check.tapped.connect(_close)
	frame.add_child(check)

	adult_corner = ShellTap.new()
	adult_corner.position = Vector2(get_viewport_rect().size.x - 160, 0)
	adult_corner.size = Vector2(160, 160)
	adult_corner.draw_fn = func(t: ShellTap) -> void:
		var c := Vector2(72, 96)
		t.draw_circle(c, 52, ShellUi.DUSK.lightened(0.1) if t.is_down else ShellUi.DUSK)
		t.draw_arc(c, 51, 0, TAU, 72, ShellUi.MOON.darkened(0.3), 3.0, true)
		ShellUi.draw_gear(t, c, 46, ShellUi.MOON, ShellUi.DUSK)
	adult_corner.tapped.connect(Shell.goto.bind("gate", ""))
	add_child(adult_corner)


func _draw_sky(c: Control) -> void:
	for s in STARS:
		c.draw_circle(s[0], s[1], ShellUi.MOON)
	c.draw_circle(Vector2(540, 460), 160, ShellUi.MOON)
	c.draw_circle(Vector2(630, 400), 150, ShellUi.DUSK)


func _close() -> void:
	Shell.save_settings()
	get_tree().quit()


func on_back() -> void:
	_close()
