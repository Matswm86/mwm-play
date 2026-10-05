extends Control

## A wordless icon that only displays (never takes touches). Optionally sits
## on a filled disc.

const UiGlyphs := preload("res://games/tile-explorer/scripts/UiGlyphs.gd")

var kind: String = "star"
var ink: Color = Color(1, 1, 1)
var disc: Color = Color(0, 0, 0, 0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	if disc.a > 0.0:
		draw_circle(c, r, disc)
		r *= 0.8
	draw_set_transform(c, 0.0, Vector2(r / 50.0, r / 50.0))
	UiGlyphs.draw(self, kind, ink)
	draw_set_transform(Vector2.ZERO)
