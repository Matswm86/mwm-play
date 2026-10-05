extends RefCounted
class_name TeIcons

# 12 chibi-style themed icons. All drawn procedurally — no bitmap assets.
# Layout per icon: outline first (slightly larger), body, then features
# (eyes, highlights, etc). Designed to fit within radius `r` on a tile.

const TABLE: Array = [
	{"name": "soccer", "primary": Color(0.96, 0.96, 0.96)},
	{"name": "apple", "primary": Color(0.94, 0.22, 0.30)},
	{"name": "cat", "primary": Color(0.99, 0.78, 0.20)},
	{"name": "fish", "primary": Color(0.32, 0.74, 0.92)},
	{"name": "cherry", "primary": Color(0.92, 0.20, 0.32)},
	{"name": "watermelon", "primary": Color(0.92, 0.36, 0.42)},
	{"name": "bone", "primary": Color(0.96, 0.94, 0.84)},
	{"name": "mushroom", "primary": Color(0.92, 0.28, 0.30)},
	{"name": "ghost", "primary": Color(0.96, 0.96, 1.00)},
	{"name": "banana", "primary": Color(0.99, 0.84, 0.16)},
	{"name": "carrot", "primary": Color(1.00, 0.55, 0.20)},
	{"name": "donut", "primary": Color(0.98, 0.62, 0.78)},
]

const OUTLINE: Color = Color(0.16, 0.14, 0.18)
const TILE_BODY: Color = Color(1.0, 0.99, 0.94)  # must match Tile.BODY_TOP


static func count() -> int:
	return TABLE.size()


static func name_of(id: int) -> String:
	return String(TABLE[id]["name"])


static func color_of(id: int) -> Color:
	return TABLE[id]["primary"]


static func _stroke_poly(node: CanvasItem, pts: PackedVector2Array, w: float, col: Color) -> void:
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	node.draw_polyline(loop, col, w, true)


static func _shine(node: CanvasItem, p: Vector2, r: float, alpha: float = 0.7) -> void:
	node.draw_circle(p, r, Color(1, 1, 1, alpha))


static func draw_icon(node: CanvasItem, id: int, r: float) -> void:
	var name: String = name_of(id)
	match name:
		"soccer":
			_draw_soccer(node, r)
		"apple":
			_draw_apple(node, r)
		"cat":
			_draw_cat(node, r)
		"fish":
			_draw_fish(node, r)
		"cherry":
			_draw_cherry(node, r)
		"watermelon":
			_draw_watermelon(node, r)
		"bone":
			_draw_bone(node, r)
		"mushroom":
			_draw_mushroom(node, r)
		"ghost":
			_draw_ghost(node, r)
		"banana":
			_draw_banana(node, r)
		"carrot":
			_draw_carrot(node, r)
		"donut":
			_draw_donut(node, r)


# --- 1: soccer ball -------------------------------------------------------


static func _draw_soccer(node: CanvasItem, r: float) -> void:
	node.draw_circle(Vector2.ZERO, r + 1.5, OUTLINE)
	node.draw_circle(Vector2.ZERO, r, Color(0.97, 0.97, 0.97))
	# Central black pentagon.
	var pent := PackedVector2Array()
	for i in 5:
		var a: float = -PI / 2.0 + TAU * float(i) / 5.0
		pent.append(Vector2(cos(a), sin(a)) * r * 0.30)
	node.draw_colored_polygon(pent, OUTLINE)
	# 5 black spokes from pentagon vertices to rim.
	for i in 5:
		var a: float = -PI / 2.0 + TAU * float(i) / 5.0
		var dir := Vector2(cos(a), sin(a))
		node.draw_line(dir * r * 0.30, dir * r * 0.92, OUTLINE, 3.5)
	_shine(node, Vector2(-r * 0.32, -r * 0.32), r * 0.18, 0.85)


# --- 2: apple -------------------------------------------------------------


static func _draw_apple(node: CanvasItem, r: float) -> void:
	# Stem first so body covers its base.
	node.draw_line(
		Vector2(0, -r * 0.62), Vector2(r * 0.05, -r * 0.30), Color(0.42, 0.26, 0.18), 6.0
	)
	# Leaf on the right of stem.
	var leaf := PackedVector2Array(
		[
			Vector2(r * 0.05, -r * 0.50),
			Vector2(r * 0.55, -r * 0.70),
			Vector2(r * 0.45, -r * 0.32),
		]
	)
	node.draw_colored_polygon(leaf, Color(0.30, 0.78, 0.32))
	_stroke_poly(node, leaf, 2.5, Color(0.10, 0.40, 0.16))
	# Apple body — slightly taller than wide via two overlapping circles.
	var body_col := Color(0.92, 0.22, 0.28)
	node.draw_circle(Vector2(-r * 0.16, r * 0.06), r * 0.78 + 1.5, OUTLINE)
	node.draw_circle(Vector2(r * 0.16, r * 0.06), r * 0.78 + 1.5, OUTLINE)
	node.draw_circle(Vector2(-r * 0.16, r * 0.06), r * 0.78, body_col)
	node.draw_circle(Vector2(r * 0.16, r * 0.06), r * 0.78, body_col)
	# Highlight.
	_shine(node, Vector2(-r * 0.32, -r * 0.18), r * 0.16, 0.7)


# --- 3: cat face ----------------------------------------------------------


static func _draw_cat(node: CanvasItem, r: float) -> void:
	var body := Color(1.0, 0.80, 0.26)
	var pink := Color(0.96, 0.62, 0.66)
	# Face first, so ears can overlap on top.
	node.draw_circle(Vector2.ZERO, r * 0.92 + 1.5, OUTLINE)
	node.draw_circle(Vector2.ZERO, r * 0.92, body)
	# Ears (peaks well above face).
	var ear_l := PackedVector2Array(
		[
			Vector2(-r * 0.95, -r * 0.55),
			Vector2(-r * 0.55, -r * 1.10),
			Vector2(-r * 0.18, -r * 0.62),
		]
	)
	var ear_r := PackedVector2Array(
		[
			Vector2(r * 0.95, -r * 0.55),
			Vector2(r * 0.55, -r * 1.10),
			Vector2(r * 0.18, -r * 0.62),
		]
	)
	node.draw_colored_polygon(ear_l, body)
	node.draw_colored_polygon(ear_r, body)
	_stroke_poly(node, ear_l, 2.5, OUTLINE)
	_stroke_poly(node, ear_r, 2.5, OUTLINE)
	# Inner-ear pink (smaller, inset).
	var ear_in_l := PackedVector2Array(
		[
			Vector2(-r * 0.78, -r * 0.62),
			Vector2(-r * 0.55, -r * 0.96),
			Vector2(-r * 0.30, -r * 0.66),
		]
	)
	var ear_in_r := PackedVector2Array(
		[
			Vector2(r * 0.78, -r * 0.62),
			Vector2(r * 0.55, -r * 0.96),
			Vector2(r * 0.30, -r * 0.66),
		]
	)
	node.draw_colored_polygon(ear_in_l, pink)
	node.draw_colored_polygon(ear_in_r, pink)
	# Eyes.
	node.draw_circle(Vector2(-r * 0.30, -r * 0.10), r * 0.11, OUTLINE)
	node.draw_circle(Vector2(r * 0.30, -r * 0.10), r * 0.11, OUTLINE)
	node.draw_circle(Vector2(-r * 0.27, -r * 0.13), r * 0.04, Color(1, 1, 1))
	node.draw_circle(Vector2(r * 0.33, -r * 0.13), r * 0.04, Color(1, 1, 1))
	# Pink nose triangle.
	var nose := PackedVector2Array(
		[
			Vector2(-r * 0.10, r * 0.10),
			Vector2(r * 0.10, r * 0.10),
			Vector2(0, r * 0.22),
		]
	)
	node.draw_colored_polygon(nose, pink)
	_stroke_poly(node, nose, 2.0, OUTLINE)
	# Smile (two short arcs forming a w).
	node.draw_arc(Vector2(-r * 0.10, r * 0.30), r * 0.10, 0.0, PI, 8, OUTLINE, 2.5)
	node.draw_arc(Vector2(r * 0.10, r * 0.30), r * 0.10, 0.0, PI, 8, OUTLINE, 2.5)
	# Whiskers.
	node.draw_line(Vector2(-r * 0.45, r * 0.20), Vector2(-r * 0.85, r * 0.18), OUTLINE, 2.0)
	node.draw_line(Vector2(-r * 0.45, r * 0.30), Vector2(-r * 0.85, r * 0.34), OUTLINE, 2.0)
	node.draw_line(Vector2(r * 0.45, r * 0.20), Vector2(r * 0.85, r * 0.18), OUTLINE, 2.0)
	node.draw_line(Vector2(r * 0.45, r * 0.30), Vector2(r * 0.85, r * 0.34), OUTLINE, 2.0)


# --- 4: fish --------------------------------------------------------------


static func _draw_fish(node: CanvasItem, r: float) -> void:
	var body_col := Color(0.32, 0.74, 0.92)
	var dark := Color(0.16, 0.40, 0.62)
	# Body — front round + tail wedge.
	var body := PackedVector2Array()
	# Front semicircle on the left.
	for i in 17:
		var t: float = PI / 2.0 + PI * float(i) / 16.0
		body.append(Vector2(cos(t) * r * 0.65 - r * 0.05, sin(t) * r * 0.55))
	# Tail.
	body.append(Vector2(r * 0.55, -r * 0.50))
	body.append(Vector2(r * 0.95, -r * 0.55))
	body.append(Vector2(r * 0.70, 0.0))
	body.append(Vector2(r * 0.95, r * 0.55))
	body.append(Vector2(r * 0.55, r * 0.50))
	node.draw_colored_polygon(body, body_col)
	_stroke_poly(node, body, 3.0, dark)
	# Eye.
	node.draw_circle(Vector2(-r * 0.25, -r * 0.10), r * 0.15, Color(1, 1, 1))
	node.draw_circle(Vector2(-r * 0.25, -r * 0.10), r * 0.10, OUTLINE)
	node.draw_circle(Vector2(-r * 0.22, -r * 0.13), r * 0.04, Color(1, 1, 1))
	# Smile.
	node.draw_arc(Vector2(-r * 0.05, r * 0.10), r * 0.18, PI * 0.20, PI * 0.85, 10, dark, 2.5)
	# Side fin.
	var fin := PackedVector2Array(
		[
			Vector2(-r * 0.10, r * 0.05),
			Vector2(r * 0.20, r * 0.32),
			Vector2(r * 0.05, r * 0.05),
		]
	)
	node.draw_colored_polygon(fin, dark.lightened(0.30))


# --- 5: cherry ------------------------------------------------------------


static func _draw_cherry(node: CanvasItem, r: float) -> void:
	var red := Color(0.92, 0.20, 0.32)
	var dark := Color(0.50, 0.10, 0.18)
	var brown := Color(0.42, 0.28, 0.16)
	# Stems converging at the top.
	node.draw_line(Vector2(-r * 0.25, r * 0.32), Vector2(r * 0.05, -r * 0.55), brown, 5.0)
	node.draw_line(Vector2(r * 0.30, r * 0.20), Vector2(r * 0.05, -r * 0.55), brown, 5.0)
	# Small leaf.
	var leaf := PackedVector2Array(
		[
			Vector2(r * 0.05, -r * 0.55),
			Vector2(r * 0.50, -r * 0.78),
			Vector2(r * 0.45, -r * 0.40),
		]
	)
	node.draw_colored_polygon(leaf, Color(0.30, 0.80, 0.34))
	_stroke_poly(node, leaf, 2.0, Color(0.10, 0.40, 0.16))
	# Two cherries.
	node.draw_circle(Vector2(-r * 0.30, r * 0.40), r * 0.42 + 1.5, OUTLINE)
	node.draw_circle(Vector2(-r * 0.30, r * 0.40), r * 0.42, red)
	node.draw_circle(Vector2(r * 0.32, r * 0.32), r * 0.42 + 1.5, OUTLINE)
	node.draw_circle(Vector2(r * 0.32, r * 0.32), r * 0.42, red)
	# Highlights.
	_shine(node, Vector2(-r * 0.42, r * 0.28), r * 0.10, 0.6)
	_shine(node, Vector2(r * 0.20, r * 0.20), r * 0.10, 0.6)


# --- 6: watermelon slice --------------------------------------------------


static func _draw_watermelon(node: CanvasItem, r: float) -> void:
	# Nested wedges: dark green rind, light green, white rim, red flesh.
	var outer := PackedVector2Array(
		[
			Vector2(-r * 0.95, r * 0.45),
			Vector2(0, -r * 0.75),
			Vector2(r * 0.95, r * 0.45),
		]
	)
	node.draw_colored_polygon(outer, Color(0.18, 0.46, 0.20))
	_stroke_poly(node, outer, 3.0, OUTLINE)
	var light_rind := PackedVector2Array(
		[
			Vector2(-r * 0.85, r * 0.35),
			Vector2(0, -r * 0.62),
			Vector2(r * 0.85, r * 0.35),
		]
	)
	node.draw_colored_polygon(light_rind, Color(0.62, 0.84, 0.40))
	var white_rim := PackedVector2Array(
		[
			Vector2(-r * 0.78, r * 0.28),
			Vector2(0, -r * 0.52),
			Vector2(r * 0.78, r * 0.28),
		]
	)
	node.draw_colored_polygon(white_rim, Color(0.96, 0.96, 0.92))
	var flesh := PackedVector2Array(
		[
			Vector2(-r * 0.68, r * 0.22),
			Vector2(0, -r * 0.40),
			Vector2(r * 0.68, r * 0.22),
		]
	)
	node.draw_colored_polygon(flesh, Color(0.94, 0.30, 0.36))
	# Black seeds.
	node.draw_circle(Vector2(0, r * 0.05), r * 0.06, OUTLINE)
	node.draw_circle(Vector2(-r * 0.20, -r * 0.10), r * 0.05, OUTLINE)
	node.draw_circle(Vector2(r * 0.20, -r * 0.10), r * 0.05, OUTLINE)
	node.draw_circle(Vector2(-r * 0.32, r * 0.12), r * 0.05, OUTLINE)
	node.draw_circle(Vector2(r * 0.32, r * 0.12), r * 0.05, OUTLINE)


# --- 7: bone --------------------------------------------------------------


static func _draw_bone(node: CanvasItem, r: float) -> void:
	var bone_col := Color(0.99, 0.97, 0.88)
	var ow: float = 3.0
	# Outline pass — slightly larger pieces in dark colour.
	node.draw_rect(
		Rect2(-r * 0.55 - ow, -r * 0.18 - ow, r * 1.10 + ow * 2.0, r * 0.36 + ow * 2.0), OUTLINE
	)
	node.draw_circle(Vector2(-r * 0.55, -r * 0.36), r * 0.30 + ow, OUTLINE)
	node.draw_circle(Vector2(-r * 0.55, r * 0.36), r * 0.30 + ow, OUTLINE)
	node.draw_circle(Vector2(r * 0.55, -r * 0.36), r * 0.30 + ow, OUTLINE)
	node.draw_circle(Vector2(r * 0.55, r * 0.36), r * 0.30 + ow, OUTLINE)
	# Body pass.
	node.draw_rect(Rect2(-r * 0.55, -r * 0.18, r * 1.10, r * 0.36), bone_col)
	node.draw_circle(Vector2(-r * 0.55, -r * 0.36), r * 0.30, bone_col)
	node.draw_circle(Vector2(-r * 0.55, r * 0.36), r * 0.30, bone_col)
	node.draw_circle(Vector2(r * 0.55, -r * 0.36), r * 0.30, bone_col)
	node.draw_circle(Vector2(r * 0.55, r * 0.36), r * 0.30, bone_col)
	# Subtle shadow stripe along bottom.
	node.draw_rect(Rect2(-r * 0.40, r * 0.05, r * 0.80, r * 0.10), Color(0.78, 0.72, 0.58, 0.45))


# --- 8: mushroom ----------------------------------------------------------


static func _draw_mushroom(node: CanvasItem, r: float) -> void:
	var stem_col := Color(0.99, 0.95, 0.86)
	var stem_dark := Color(0.74, 0.62, 0.46)
	var cap_col := Color(0.92, 0.26, 0.30)
	var cap_dark := Color(0.50, 0.10, 0.14)
	# Stem — gently flared rectangle.
	var stem := PackedVector2Array(
		[
			Vector2(-r * 0.30, r * 0.10),
			Vector2(r * 0.30, r * 0.10),
			Vector2(r * 0.36, r * 0.78),
			Vector2(-r * 0.36, r * 0.78),
		]
	)
	node.draw_colored_polygon(stem, stem_col)
	_stroke_poly(node, stem, 2.5, stem_dark)
	# Cap — top half of an ellipse.
	var cap := PackedVector2Array()
	var seg: int = 24
	for i in seg + 1:
		var t: float = PI + PI * float(i) / float(seg)
		cap.append(Vector2(cos(t) * r * 0.92, sin(t) * r * 0.55 + r * 0.10))
	cap.append(Vector2(-r * 0.92, r * 0.10))
	node.draw_colored_polygon(cap, cap_col)
	_stroke_poly(node, cap, 3.0, cap_dark)
	# White spots on cap.
	node.draw_circle(Vector2(-r * 0.30, -r * 0.20), r * 0.16, Color(1, 1, 1))
	node.draw_circle(Vector2(r * 0.20, -r * 0.30), r * 0.13, Color(1, 1, 1))
	node.draw_circle(Vector2(r * 0.45, -r * 0.05), r * 0.10, Color(1, 1, 1))


# --- 9: ghost -------------------------------------------------------------


static func _draw_ghost(node: CanvasItem, r: float) -> void:
	var ghost_col := Color(0.98, 0.98, 1.0)
	var ghost := PackedVector2Array()
	# Top semicircle.
	var seg: int = 18
	for i in seg + 1:
		var t: float = PI + PI * float(i) / float(seg)
		ghost.append(Vector2(cos(t) * r * 0.85, sin(t) * r * 0.85 - r * 0.05))
	# Wavy bottom — three bumps.
	ghost.append(Vector2(r * 0.85, r * 0.40))
	ghost.append(Vector2(r * 0.55, r * 0.65))
	ghost.append(Vector2(r * 0.30, r * 0.40))
	ghost.append(Vector2(0, r * 0.65))
	ghost.append(Vector2(-r * 0.30, r * 0.40))
	ghost.append(Vector2(-r * 0.55, r * 0.65))
	ghost.append(Vector2(-r * 0.85, r * 0.40))
	node.draw_colored_polygon(ghost, ghost_col)
	_stroke_poly(node, ghost, 3.0, OUTLINE)
	# Eyes.
	node.draw_circle(Vector2(-r * 0.25, -r * 0.10), r * 0.16, OUTLINE)
	node.draw_circle(Vector2(r * 0.25, -r * 0.10), r * 0.16, OUTLINE)
	node.draw_circle(Vector2(-r * 0.20, -r * 0.16), r * 0.06, Color(1, 1, 1))
	node.draw_circle(Vector2(r * 0.30, -r * 0.16), r * 0.06, Color(1, 1, 1))
	# Mouth (oh expression).
	node.draw_circle(Vector2(0, r * 0.18), r * 0.10, OUTLINE)


# --- 10: banana -----------------------------------------------------------


static func _draw_banana(node: CanvasItem, r: float) -> void:
	var path := PackedVector2Array()
	# Curve from top-left down through bottom-right.
	for i in 18:
		var t: float = PI * 1.05 + PI * 0.55 * float(i) / 17.0
		path.append(Vector2(cos(t) * r * 0.78, sin(t) * r * 0.78))
	# Outline first (thicker), then yellow body.
	node.draw_polyline(path, Color(0.50, 0.36, 0.10), 24.0, true)
	node.draw_polyline(path, Color(0.99, 0.84, 0.16), 18.0, true)
	# Tip caps.
	node.draw_circle(path[0], 6.0, Color(0.50, 0.36, 0.10))
	node.draw_circle(path[path.size() - 1], 6.0, Color(0.50, 0.36, 0.10))
	# Subtle highlight stripe along the inside curve.
	var hi_path := PackedVector2Array()
	for i in 18:
		var t: float = PI * 1.05 + PI * 0.55 * float(i) / 17.0
		hi_path.append(Vector2(cos(t) * r * 0.66, sin(t) * r * 0.66))
	node.draw_polyline(hi_path, Color(1, 0.96, 0.55, 0.7), 4.0, true)


# --- 11: carrot -----------------------------------------------------------


static func _draw_carrot(node: CanvasItem, r: float) -> void:
	var orange := Color(0.99, 0.55, 0.16)
	var orange_dark := Color(0.62, 0.30, 0.06)
	var leaf := Color(0.30, 0.78, 0.34)
	var leaf_dark := Color(0.10, 0.40, 0.16)
	# Body — pointed-down triangle.
	var body := PackedVector2Array(
		[
			Vector2(-r * 0.45, -r * 0.20),
			Vector2(r * 0.45, -r * 0.20),
			Vector2(r * 0.05, r * 0.92),
		]
	)
	node.draw_colored_polygon(body, orange)
	_stroke_poly(node, body, 3.0, orange_dark)
	# Ridges — three thin diagonal lines across the body.
	for i in 3:
		var y: float = -r * 0.05 + float(i) * r * 0.30
		node.draw_line(
			Vector2(-r * 0.32, y),
			Vector2(r * 0.32 - float(i) * r * 0.10, y + r * 0.04),
			orange_dark,
			2.0
		)
	# Three leaf clusters at the top.
	for i in 3:
		var dx: float = (float(i) - 1.0) * r * 0.22
		var lf := PackedVector2Array(
			[
				Vector2(dx - r * 0.12, -r * 0.30),
				Vector2(dx + r * 0.12, -r * 0.30),
				Vector2(dx + (float(i) - 1.0) * r * 0.05, -r * 0.92),
			]
		)
		node.draw_colored_polygon(lf, leaf)
		_stroke_poly(node, lf, 2.0, leaf_dark)


# --- 12: donut ------------------------------------------------------------


static func _draw_donut(node: CanvasItem, r: float) -> void:
	var pink := Color(0.98, 0.62, 0.78)
	var pink_dark := Color(0.62, 0.20, 0.40)
	# Outer ring — outline + body.
	node.draw_circle(Vector2.ZERO, r * 0.95 + 2.0, pink_dark)
	node.draw_circle(Vector2.ZERO, r * 0.95, pink)
	# Inner hole — pink_dark "rim" then tile-body fill.
	node.draw_circle(Vector2.ZERO, r * 0.40 + 2.0, pink_dark)
	node.draw_circle(Vector2.ZERO, r * 0.40, TILE_BODY)
	# Frosting drip around top half (slightly darker pink).
	node.draw_arc(
		Vector2.ZERO, r * 0.86, PI * 0.15, PI * 0.85, 24, Color(0.96, 0.50, 0.66), r * 0.12
	)
	# Sprinkles — short coloured strokes scattered on top half.
	var sprinkles: Array = [
		[Vector2(-r * 0.55, -r * 0.10), Vector2(-r * 0.40, -r * 0.05), Color(0.20, 0.62, 0.92)],
		[Vector2(-r * 0.10, -r * 0.65), Vector2(0, -r * 0.50), Color(0.99, 0.84, 0.16)],
		[Vector2(r * 0.30, -r * 0.45), Vector2(r * 0.40, -r * 0.30), Color(0.20, 0.78, 0.36)],
		[Vector2(r * 0.55, -r * 0.10), Vector2(r * 0.42, -r * 0.05), Color(0.96, 0.30, 0.62)],
		[Vector2(-r * 0.30, -r * 0.50), Vector2(-r * 0.18, -r * 0.36), Color(0.74, 0.36, 0.92)],
		[Vector2(r * 0.10, -r * 0.65), Vector2(r * 0.22, -r * 0.50), Color(0.20, 0.62, 0.92)],
	]
	for s in sprinkles:
		node.draw_line(s[0], s[1], s[2], 4.5)
	# Tiny shine on top-left.
	_shine(node, Vector2(-r * 0.50, -r * 0.50), r * 0.10, 0.6)
