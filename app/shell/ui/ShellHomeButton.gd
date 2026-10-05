class_name ShellHomeButton
extends ShellTap

## Home disc, always top-left (rule 20). The hit area runs from the screen
## corner to 216 px on both axes (rule 7, 13.7 mm at 400 dpi, rule 1).
## In games it uses the "tap again" guard (rule 10): the first tap starts a
## 2.0 s ring, a second tap between 300 ms (holdover floor, rule 8) and
## 2.0 s leaves. On shell screens guard = false and one tap leaves.
## With back_arrow = true the disc shows a left arrow instead of the house:
## adult sub-pages use it to go up one level (same disc, same hit area).

signal leave_requested

const HIT: float = 216.0
const CENTER := Vector2(104, 104)
const DISC_D: float = 136.0
const GUARD_DISC_D: float = 164.0
const HALO_D: float = 208.0
const GUARD_MS: int = 2000
const HOLDOVER_MS: int = 300
const FADE_S: float = 0.25

var guard: bool = true
var back_arrow: bool = false
var _guard_start: int = -1
var _fade: float = 0.0
var _pop: float = 0.0
var _safe_dy: float = 0.0


func _ready() -> void:
	silent = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_safe_area()
	tapped.connect(trigger)


## On phones with a top-left camera cutout the disc moves below the safe area;
## the hit area still runs to the screen edge.
func _fit_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vs := get_viewport_rect().size
	if win.y > 0:
		var top_px: float = float(safe.position.y) * vs.y / float(win.y)
		_safe_dy = maxf(0.0, top_px - 36.0)
	position = Vector2.ZERO
	size = Vector2(HIT, HIT + _safe_dy)


## A home tap or an Android back press.
func trigger() -> void:
	var now := Time.get_ticks_msec()
	if not guard:
		leave_requested.emit()
		return
	if _guard_start >= 0 and now - _guard_start <= GUARD_MS:
		if now - _guard_start >= HOLDOVER_MS:
			_guard_start = -1
			_fade = 0.0
			leave_requested.emit()
		return
	_guard_start = now
	_fade = 1.0
	_pop = 0.0
	Shell.play_pling()
	set_process(true)


func reset_guard() -> void:
	_guard_start = -1
	_fade = 0.0
	queue_redraw()


func guard_active() -> bool:
	return _guard_start >= 0


func _process(delta: float) -> void:
	if _guard_start >= 0:
		_pop = minf(1.0, _pop + delta / 0.12)
		if Time.get_ticks_msec() - _guard_start > GUARD_MS:
			_guard_start = -1
	elif _fade > 0.0:
		_fade = maxf(0.0, _fade - delta / FADE_S)
	else:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var c := CENTER + Vector2(0, _safe_dy)
	var less: bool = Shell.settings.less_motion
	var active := _guard_start >= 0 or _fade > 0.0
	var k: float = 1.0 if less else ease(_pop, -2.0)
	var disc_d := DISC_D
	if active:
		disc_d = lerpf(DISC_D, GUARD_DISC_D, k * _fade if _guard_start < 0 else k)
		var a: float = 1.0 if _guard_start >= 0 else _fade
		draw_circle(c, HALO_D * 0.5, Color(ShellUi.CARD, a))
		draw_arc(c, HALO_D * 0.5 - 1.5, 0, TAU, 96, Color(ShellUi.INK, a), 3.0, true)
		var t: float = 1.0
		if _guard_start >= 0 and not less:
			t = clampf(float(Time.get_ticks_msec() - _guard_start) / GUARD_MS, 0.0, 1.0)
		var r := (HALO_D * 0.5 + disc_d * 0.5) * 0.5
		ShellUi.draw_ring(self, c, r, Color(ShellUi.GREEN, a), 12.0, -PI / 2.0, -PI / 2.0 + TAU * t)
	else:
		draw_circle(c + Vector2(0, 6), DISC_D * 0.5 + 2.0, Color(0, 0, 0, 0.12))
	draw_circle(c, disc_d * 0.5, ShellUi.GREEN_SOFT if is_down else ShellUi.CARD)
	draw_arc(c, disc_d * 0.5 - 2.5, 0, TAU, 96, ShellUi.INK, 5.0, true)
	if back_arrow:
		ShellUi.draw_back_arrow(self, c, 68.0 * disc_d / DISC_D, ShellUi.INK)
	else:
		ShellUi.draw_house(self, c + Vector2(0, -2), 68.0 * disc_d / DISC_D, ShellUi.INK)
