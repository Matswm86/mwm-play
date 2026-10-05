extends RefCounted

## Wordless HUD icons for children who cannot read yet. Each glyph is drawn
## around the origin in a 100 px design box; the caller sets a transform that
## centres and scales it. Every glyph has its own shape, so no button is told
## apart by colour alone.


static func draw(ci: CanvasItem, kind: String, ink: Color) -> void:
	match kind:
		"restart":
			ci.draw_arc(Vector2.ZERO, 26, PI * 0.35, PI * 1.95, 28, ink, 8.0, true)
			var tip := Vector2(26, -4)
			_tri(ci, tip + Vector2(-14, -7), tip + Vector2(14, -7), tip + Vector2(0, 12), ink)
		"undo":
			ci.draw_arc(Vector2(4, 6), 24, PI * 1.05, PI * 2.25, 24, ink, 8.0, true)
			var tip := Vector2(-20, 2)
			_tri(ci, tip + Vector2(-14, 2), tip + Vector2(14, -2), tip + Vector2(-2, 20), ink)
		"clear3":
			# Three tiles with burst lines: three tiles go away.
			for i in 3:
				_tile(ci, Vector2(-30 + 30 * i, 14), 24.0, ink)
			for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				var d := Vector2.from_angle(-PI * 0.5 + a * 1.6)
				ci.draw_line(Vector2(0, -2) + d * 20, Vector2(0, -2) + d * 38, ink, 5.0, true)
		"shuffle":
			# Two arrows that cross.
			ci.draw_line(Vector2(-34, 18), Vector2(22, -18), ink, 7.0, true)
			ci.draw_line(Vector2(-34, -18), Vector2(22, 18), ink, 7.0, true)
			_tri(ci, Vector2(18, -30), Vector2(36, -20), Vector2(22, -4), ink)
			_tri(ci, Vector2(18, 30), Vector2(36, 20), Vector2(22, 4), ink)
		"next":
			ci.draw_line(Vector2(-28, 0), Vector2(8, 0), ink, 16.0)
			_tri(ci, Vector2(0, -30), Vector2(34, 0), Vector2(0, 30), ink)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + PI * i / 5.0
				pts.append(Vector2.from_angle(a) * (44.0 if i % 2 == 0 else 19.0))
			ci.draw_colored_polygon(pts, ink)
		"flag":
			ci.draw_line(Vector2(-22, -38), Vector2(-22, 40), ink, 7.0)
			ci.draw_colored_polygon(
				PackedVector2Array([Vector2(-19, -38), Vector2(32, -24), Vector2(-19, -8)]), ink
			)
		"tile":
			_tile(ci, Vector2.ZERO, 64.0, ink)
			ci.draw_circle(Vector2.ZERO, 11.0, Color(ink, ink.a * 0.55))
		"tray_full":
			# A tray with all seven slots taken.
			ci.draw_rect(Rect2(-48, -14, 96, 28), ink, false, 4.0)
			for i in 7:
				ci.draw_rect(Rect2(-44 + i * 12.6, -10, 10, 20), ink)


static func _tile(ci: CanvasItem, c: Vector2, side: float, ink: Color) -> void:
	var r := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
	ci.draw_rect(r, ink, false, maxf(3.0, side * 0.1))


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, ink: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), ink)
