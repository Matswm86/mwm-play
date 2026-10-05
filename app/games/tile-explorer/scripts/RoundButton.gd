extends Control

## Round button with a drawn icon and no text. The whole control rect is the
## hit area (216 px = 12.7 mm at 430 dpi); the disc is drawn smaller inside
## it. Touch-down only presses the disc in; the action fires on release inside
## the rect, so a resting palm or a finger sliding off does nothing. Charges
## show as pips under the disc: filled = left, hollow = used.

signal pressed

const UiGlyphs := preload("res://games/tile-explorer/scripts/UiGlyphs.gd")
const HIT: float = 216.0
const DISC: float = 0.36  # disc radius as a share of the hit side

var kind: String = "restart"
var accent: Color = Color(0.99, 0.97, 0.93)
var ink: Color = Color(1, 1, 1)
var disabled: bool = false:
	set(v):
		disabled = v
		queue_redraw()
## Charges left and the most there can be; max_charges 0 hides the pips.
var charges: int = 0:
	set(v):
		charges = v
		queue_redraw()
var max_charges: int = 0
## Extra hit area above the disc (px): a top-row button pushed below a camera
## cutout keeps its touch area running to the screen edge.
var top_pad: float = 0.0
var _held: bool = false
var _press: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(HIT, HIT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = not disabled
		elif _held:
			_held = false
			if not disabled and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		_set_press(1.0 if _held else 0.0)
		accept_event()
	elif event is InputEventMouseMotion and _held:
		_set_press(1.0 if Rect2(Vector2.ZERO, size).has_point(event.position) else 0.0)


func _set_press(v: float) -> void:
	if _press != v:
		_press = v
		queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, top_pad + (size.y - top_pad) * 0.5)
	var rad: float = minf(size.x, size.y - top_pad) * DISC * (1.0 - 0.1 * _press)
	var alpha: float = 0.4 if disabled else 1.0
	if max_charges > 0:
		c.y -= 14.0
	draw_circle(c + Vector2(0, 5), rad, Color(0.1, 0.05, 0.02, 0.35 * alpha))
	var fill: Color = accent.darkened(0.18) if _press > 0.0 else accent
	draw_circle(c, rad, Color(fill, alpha))
	draw_arc(c, rad, 0, TAU, 48, Color(1, 1, 1, 0.55 * alpha), 4.0, true)
	var k: float = rad / 50.0 * 0.95
	draw_set_transform(c, 0.0, Vector2(k, k))
	UiGlyphs.draw(self, kind, Color(ink, alpha))
	draw_set_transform(Vector2.ZERO)
	for i in max_charges:
		var p := Vector2(c.x + (i - (max_charges - 1) * 0.5) * 30.0, c.y + rad + 22.0)
		if i < charges:
			draw_circle(p, 10.0, Color(1, 1, 1, alpha))
		else:
			draw_arc(p, 9.0, 0, TAU, 20, Color(1, 1, 1, 0.8 * alpha), 3.0, true)
