class_name ShellTap
extends Control

## A tap target for shell screens. Feedback on touch-down (sound plus visual,
## same frame), action on release inside the hit area (rules 15, 19). A finger
## that moves more than CANCEL_MOVE px cancels the tap, so dragging a scroll
## list never fires a row. The control rect IS the hit area; draw_fn paints
## whatever is inside it and reads is_down for the pressed look.

signal tapped
signal down_changed(down: bool)

const CANCEL_MOVE: float = 40.0

var is_down: bool = false
var draw_fn: Callable
var silent: bool = false
var _down_at: Vector2


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_down = true
			_down_at = event.global_position
			if not silent:
				Shell.play_tok()
			_changed()
		elif is_down:
			is_down = false
			_changed()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				tapped.emit()
	elif event is InputEventMouseMotion and is_down:
		if event.global_position.distance_to(_down_at) > CANCEL_MOVE:
			is_down = false
			_changed()


func _changed() -> void:
	down_changed.emit(is_down)
	queue_redraw()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
