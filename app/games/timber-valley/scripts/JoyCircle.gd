class_name TvJoyCircle
extends Control

## A circle centred on this control's position, for the floating joystick.

var radius: float = 100.0
var fill: Color = Color(1, 1, 1, 0.2)
var ring: Color = Color(1, 1, 1, 0.6)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill)
	if ring.a > 0.0:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, ring, 5.0, true)
