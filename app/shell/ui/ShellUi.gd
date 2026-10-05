class_name ShellUi
extends RefCounted

## Palette, fonts and small builders for the shell screens (docs/DESIGN.md).
## Shell styling never reaches a game: fonts are set per shell screen through
## a Theme, never as the project-wide default.

const PAPER := Color(0.984, 0.973, 0.949)
const CARD := Color(1.0, 1.0, 1.0)
const INK := Color(0.141, 0.129, 0.114)
const INK_SOFT := Color(0.361, 0.329, 0.286)
const LINE := Color(0.902, 0.875, 0.824)
const EDGE := Color(0.561, 0.514, 0.443)
const GREEN := Color(0.122, 0.478, 0.353)
const GREEN_SOFT := Color(0.890, 0.941, 0.918)
const PLUM := Color(0.357, 0.247, 0.549)
const DUSK := Color(0.180, 0.169, 0.310)
const MOON := Color(0.788, 0.765, 0.902)
const HILL_1 := Color(0.894, 0.925, 0.847)
const HILL_2 := Color(0.835, 0.890, 0.776)
const SAND := Color(0.945, 0.906, 0.839)

## Design canvas width; wider screens get side margins (DESIGN 2, units).
const DESIGN_W: float = 1080.0
const DESIGN_H: float = 1920.0
## Bottom wrist strip with no targets: 256 px = 16.3 mm at 400 dpi (rule 6).
const WRIST_STRIP: float = 256.0

static var _fonts: Dictionary = {}


static func font(key: String) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	match key:
		"andika":
			f = load("res://shell/fonts/Andika-Regular.ttf")
		"andika_bold":
			f = load("res://shell/fonts/Andika-Bold.ttf")
		"fredoka", "fredoka_medium":
			var v := FontVariation.new()
			v.base_font = load("res://shell/fonts/Fredoka.ttf")
			var weight: int = 600 if key == "fredoka" else 500
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			f = v
	_fonts[key] = f
	return f


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("andika")
	t.default_font_size = 34
	t.set_color("font_color", "Label", INK)
	return t


static func label(
	text: String, font_key: String, size: int, color: Color = INK
) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_key))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Wrapping body text with the spec line height of about 1.45 (DESIGN 2e).
static func wrapped(
	text: String, font_key: String, size: int, color: Color, width: float
) -> Label:
	var l := label(text, font_key, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	var natural := font(font_key).get_height(size)
	l.add_theme_constant_override("line_spacing", roundi(size * 1.45 - natural))
	return l


static func box(
	bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.anti_aliasing = true
	return s


## Paper background plus a centred 1080-wide frame for the screen's content.
## Corner widgets go on the root so they stay in the real screen corners.
static func screen_frame(root: Control, bg: Color = PAPER) -> Control:
	root.theme = make_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = bg
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var fit := func() -> void:
		var vs: Vector2 = root.get_viewport_rect().size
		frame.position = Vector2(floorf((vs.x - DESIGN_W) * 0.5), 0)
		frame.size = Vector2(DESIGN_W, vs.y)
	fit.call()
	root.get_viewport().size_changed.connect(fit)
	return frame


## Draws a filled house, centred at c, about s px tall (home icon, rule 20).
static func draw_house(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var h := s * 0.5
	var roof := PackedVector2Array(
		[c + Vector2(-h, -0.02 * s), c + Vector2(0, -h), c + Vector2(h, -0.02 * s)]
	)
	ci.draw_colored_polygon(roof, col)
	ci.draw_polyline(roof, col, s * 0.1, true)
	ci.draw_rect(Rect2(c + Vector2(-0.34 * s, -0.08 * s), Vector2(0.68 * s, 0.56 * s)), col)
	ci.draw_rect(Rect2(c + Vector2(-0.1 * s, 0.16 * s), Vector2(0.2 * s, 0.32 * s)), CARD)


static func draw_gear(ci: CanvasItem, c: Vector2, s: float, col: Color, hole: Color) -> void:
	var r_out := s * 0.5
	var r_in := s * 0.36
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 4:
		var a := TAU * float(i) / float(teeth * 4) - PI / 2.0
		var r := r_out if (i % 4 == 1 or i % 4 == 2) else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c, s * 0.14, hole)


static func draw_check(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array(
		[c + Vector2(-0.42, 0.0) * s, c + Vector2(-0.12, 0.3) * s, c + Vector2(0.45, -0.32) * s]
	)
	ci.draw_polyline(pts, col, w, true)


static func draw_chevron(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array(
		[c + Vector2(-0.2, -0.45) * s, c + Vector2(0.25, 0.0) * s, c + Vector2(-0.2, 0.45) * s]
	)
	ci.draw_polyline(pts, col, w, true)


static func draw_backspace(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array(
		[
			c + Vector2(-0.6, 0.0) * s,
			c + Vector2(-0.3, -0.35) * s,
			c + Vector2(0.55, -0.35) * s,
			c + Vector2(0.55, 0.35) * s,
			c + Vector2(-0.3, 0.35) * s,
			c + Vector2(-0.6, 0.0) * s,
		]
	)
	ci.draw_polyline(pts, col, w, true)
	ci.draw_line(c + Vector2(-0.05, -0.15) * s, c + Vector2(0.27, 0.15) * s, col, w, true)
	ci.draw_line(c + Vector2(0.27, -0.15) * s, c + Vector2(-0.05, 0.15) * s, col, w, true)


static func draw_ring(
	ci: CanvasItem, c: Vector2, r: float, col: Color, w: float, from: float, to: float
) -> void:
	if to - from <= 0.001:
		return
	var segs := maxi(8, int(96.0 * (to - from) / TAU))
	ci.draw_arc(c, r, from, to, segs, col, w, true)
