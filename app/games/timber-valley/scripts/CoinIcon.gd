class_name TvCoinIcon
extends Control

## Gold coin drawn with circles, used in the money counter.


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c + Vector2(0, 3), r, Color(0.7, 0.45, 0.05))
	draw_circle(c, r, Color(1.0, 0.78, 0.2))
	draw_circle(c, r * 0.72, Color(1.0, 0.86, 0.4))
	draw_arc(c, r * 0.72, 0, TAU, 32, Color(0.85, 0.6, 0.1), 3.0, true)
