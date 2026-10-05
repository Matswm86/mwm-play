extends RefCounted
class_name TeDrawing


# Build a closed polygon outline of a rounded rectangle. Useful for both
# filled draws (draw_colored_polygon) and stroked draws (draw_polyline with
# the array re-closed by appending the first point).
static func rounded_rect_points(
	rect: Rect2, radius: float, steps_per_corner: int = 8
) -> PackedVector2Array:
	var r: float = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	# Corner centres in TL, TR, BR, BL order.
	var centres := [
		Vector2(rect.position.x + r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
	]
	# Sweep each corner: TL goes from PI to 1.5*PI (top-left arc), TR from 1.5*PI to 2*PI, etc.
	var starts := [PI, -PI / 2.0, 0.0, PI / 2.0]
	for c in 4:
		for i in steps_per_corner + 1:
			var a: float = starts[c] + (PI / 2.0) * float(i) / float(steps_per_corner)
			pts.append(centres[c] + Vector2(cos(a), sin(a)) * r)
	return pts


static func draw_rounded_rect(
	node: CanvasItem, rect: Rect2, radius: float, color: Color, steps: int = 8
) -> void:
	var pts: PackedVector2Array = rounded_rect_points(rect, radius, steps)
	node.draw_colored_polygon(pts, color)


static func stroke_rounded_rect(
	node: CanvasItem, rect: Rect2, radius: float, width: float, color: Color, steps: int = 8
) -> void:
	var pts: PackedVector2Array = rounded_rect_points(rect, radius, steps)
	# Close the loop for draw_polyline.
	pts.append(pts[0])
	node.draw_polyline(pts, color, width, true)


# Vertical gradient drawn as N stacked horizontal strips.
static func draw_vertical_gradient(
	node: CanvasItem, rect: Rect2, top: Color, bottom: Color, strips: int = 24
) -> void:
	var step_h: float = rect.size.y / float(strips)
	for i in strips:
		var t: float = float(i) / float(strips - 1) if strips > 1 else 0.0
		var col: Color = top.lerp(bottom, t)
		# +1 pixel overlap to avoid hairline seams under canvas_items stretch.
		node.draw_rect(
			Rect2(rect.position.x, rect.position.y + step_h * float(i), rect.size.x, step_h + 1.0),
			col
		)
