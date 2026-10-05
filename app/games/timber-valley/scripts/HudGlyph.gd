extends Control

## Vector icon drawn in code, placed inside a Button so a child who cannot read can use it.
## The parent Button is the hit area and acts on release; this only draws, and shrinks the
## disc a little while the button is held. No class_name (Hud preloads it), so a host app that
## merges several games gets one global name less to rename.

## menu, sound_on, sound_off, music_on, music_off, drop, next, restart,
## backpack, speed, axe, gear, blade, cup, star
var kind: String = ""
var ink: Color = Color.WHITE
## Disc behind the icon (transparent = no disc): round corner buttons.
var disc: Color = Color(0, 0, 0, 0)
## Extra space above the icon: a top-row button pushed below a camera cutout keeps its
## hit area running to the screen edge while the drawing moves down.
var top_pad: float = 0.0
## Icon size as a share of the smaller side of the drawing area.
var scale_k: float = 0.36


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := get_parent() as BaseButton
	if b:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.button_down.connect(queue_redraw)
		b.button_up.connect(queue_redraw)
		b.mouse_exited.connect(queue_redraw)


func _held() -> bool:
	var b := get_parent() as BaseButton
	return b != null and b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]


func _draw() -> void:
	var b := get_parent() as BaseButton
	var dim := 0.45 if b != null and b.disabled else 1.0
	var h := size.y - top_pad
	var c := Vector2(size.x * 0.5, top_pad + h * 0.5)
	var rad := minf(size.x, h) * scale_k * (0.9 if _held() else 1.0)
	if disc.a > 0.0:
		var fill := disc.darkened(0.25) if _held() else disc
		draw_circle(c, rad, Color(fill, fill.a * dim))
		draw_arc(c, rad, 0, TAU, 48, Color(1, 1, 1, 0.75 * dim), 4.0, true)
	# Icons are drawn in a 100 px design box around the centre, then scaled.
	var k := rad / 50.0 * (0.8 if disc.a > 0.0 else 1.0)
	draw_set_transform(c, 0.0, Vector2(k, k))
	var col := Color(ink, ink.a * dim)
	match kind:
		"menu":
			for y in [-18.0, 0.0, 18.0]:
				draw_line(Vector2(-26, y), Vector2(26, y), col, 9.0)
		"sound_on", "sound_off":
			_speaker(col)
		"music_on", "music_off":
			draw_circle(Vector2(-10, 20), 11, col)
			draw_line(Vector2(0, 20), Vector2(0, -26), col, 6.0)
			draw_line(Vector2(-2, -25), Vector2(20, -14), col, 8.0)
			if kind == "music_off":
				_slash(col)
		"drop":
			draw_line(Vector2(0, -30), Vector2(0, 2), col, 12.0)
			_tri(Vector2(-22, -2), Vector2(22, -2), Vector2(0, 22), col)
			draw_line(Vector2(-30, 32), Vector2(30, 32), col, 7.0)
		"next":
			draw_line(Vector2(-28, 0), Vector2(6, 0), col, 14.0)
			_tri(Vector2(0, -26), Vector2(30, 0), Vector2(0, 26), col)
		"restart":
			draw_arc(Vector2.ZERO, 24, PI * 0.35, PI * 1.95, 28, col, 8.0, true)
			var tip := Vector2(24, -4)
			_tri(tip + Vector2(-13, -6), tip + Vector2(13, -6), tip + Vector2(0, 12), col)
		"backpack":
			draw_rect(Rect2(-22, -16, 44, 46), col)
			draw_arc(Vector2(0, -16), 12, PI, TAU, 12, col, 6.0, true)
			draw_line(Vector2(-14, 8), Vector2(14, 8), Color(1, 1, 1, col.a), 4.0)
		"speed":
			for x in [-16.0, 8.0]:
				var v := PackedVector2Array([Vector2(x - 8, -24), Vector2(x + 12, 0), Vector2(x - 8, 24)])
				draw_polyline(v, col, 9.0, true)
		"axe":
			draw_line(Vector2(-20, 30), Vector2(10, -22), col, 8.0)
			_quad(Vector2(2, -32), Vector2(30, -18), Vector2(22, 0), Vector2(0, -14), col)
		"gear":
			_teeth(8, 30.0, 21.0, true, col)
			draw_arc(Vector2.ZERO, 9, 0, TAU, 20, Color(1, 1, 1, col.a), 6.0, true)
		"blade":
			_teeth(12, 32.0, 22.0, false, col)
			draw_circle(Vector2.ZERO, 6, Color(1, 1, 1, col.a))
		"cup":
			_quad(Vector2(-20, -8), Vector2(16, -8), Vector2(12, 26), Vector2(-16, 26), col)
			draw_arc(Vector2(18, 7), 9, -PI * 0.5, PI * 0.5, 12, col, 6.0, true)
			for x in [-10.0, 4.0]:
				draw_line(Vector2(x, -16), Vector2(x + 4, -28), col, 4.0)
		"star":
			var pts := PackedVector2Array()
			for i in range(10):
				var a := -PI * 0.5 + PI * i / 5.0
				var rr := 34.0 if i % 2 == 0 else 14.0
				pts.append(Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)
	draw_set_transform(Vector2.ZERO)


func _speaker(col: Color) -> void:
	var sp := PackedVector2Array([
		Vector2(-28, -10), Vector2(-16, -10), Vector2(0, -24),
		Vector2(0, 24), Vector2(-16, 10), Vector2(-28, 10)])
	draw_colored_polygon(sp, col)
	if kind == "sound_on":
		draw_arc(Vector2(2, 0), 14, -0.9, 0.9, 12, col, 6.0, true)
		draw_arc(Vector2(2, 0), 26, -0.9, 0.9, 16, col, 6.0, true)
	else:
		draw_line(Vector2(10, -12), Vector2(30, 12), col, 7.0)
		draw_line(Vector2(30, -12), Vector2(10, 12), col, 7.0)


## Diagonal line through the icon: "off" by shape, not by colour.
func _slash(col: Color) -> void:
	draw_line(Vector2(-30, -30), Vector2(30, 30), col, 7.0)


## Gear (square teeth) or saw blade (pointed teeth) outline, filled.
func _teeth(n: int, r_out: float, r_in: float, square: bool, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a0 := TAU * i / n
		var step := TAU / n
		if square:
			pts.append(Vector2.from_angle(a0) * r_in)
			pts.append(Vector2.from_angle(a0 + step * 0.15) * r_out)
			pts.append(Vector2.from_angle(a0 + step * 0.45) * r_out)
			pts.append(Vector2.from_angle(a0 + step * 0.6) * r_in)
		else:
			pts.append(Vector2.from_angle(a0) * r_in)
			pts.append(Vector2.from_angle(a0 + step * 0.2) * r_out)
	draw_colored_polygon(pts, col)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)


func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), col)
