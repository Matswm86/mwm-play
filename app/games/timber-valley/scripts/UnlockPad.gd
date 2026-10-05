class_name TvUnlockPad
extends Node3D

## Stand here to pay for the next building. Coins drain from your wallet into the pad.

signal paid(id: String)

## Height (m) the whole pad sits above the ground plane.
const LIFT := 0.025

var id: String
var cost: int
var paid_amount: int = 0
var title: String
var zone: TvZone
var _price: Label3D
var _fill: MeshInstance3D
var _bar_w: float = 2.0
var _tile: MeshInstance3D
var _arrow: MeshInstance3D
## Icon of the product the pad title names, next to the price (null when none).
var _icon: Sprite3D
var _price_x: float = 0.0
var _t: float = 0.0


func setup(pad_id: String, price: int, text: String, size: Vector2 = Vector2(2.6, 2.6)) -> TvUnlockPad:
	id = pad_id
	cost = price
	title = text
	name = "Pad_" + pad_id
	zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, size, "", Color(1.0, 0.82, 0.25))
	zone.interval = 0.0
	zone.on_carrier = _on_carrier
	add_child(zone)
	var t := Label3D.new()
	t.text = text
	t.font = TvFx.font()
	t.font_size = 52
	t.outline_size = 14
	t.outline_modulate = Color(0.12, 0.1, 0.04, 0.8)
	t.pixel_size = 0.0085
	t.rotation_degrees = Vector3(-60, 0, 0)
	t.position = Vector3(0, 0.35, -size.y * 0.5 - 0.1)
	t.width = 700
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(t)
	# Dark rounded tile with a plus sign and a green price bar along the front edge.
	zone.marker.visible = false
	# LIFT keeps the tile's underside off the ground plane (no coplanar faces to z-fight on phones).
	_tile = TvShapes.box_node(self, Vector3(size.x, 0.1, size.y), Vector3(0, 0.05 + LIFT, 0), TvShapes.mat(Color(0.28, 0.22, 0.19), 0.8), 0.25)
	var plus := TvShapes.mat(Color(0.95, 0.92, 0.86), 0.6)
	var plus_h := TvShapes.box_node(self, Vector3(0.9, 0.06, 0.2), Vector3(0, 0.12 + LIFT, -0.25), plus, 0.08)
	var plus_v := TvShapes.box_node(self, Vector3(0.2, 0.06, 0.9), Vector3(0, 0.12 + LIFT, -0.25), plus, 0.08)
	_bar_w = size.x * 0.86
	var bar := TvShapes.box_node(self, Vector3(_bar_w, 0.08, 0.62), Vector3(0, 0.1 + LIFT, size.y * 0.5 - 0.5), TvShapes.mat(Color(0.16, 0.4, 0.14), 0.6), 0.2)
	# The fill is 2 cm deeper than the bar so their front faces are never coplanar.
	_fill = TvShapes.box_node(self, Vector3(_bar_w, 0.1, 0.64), Vector3(0, 0.11 + LIFT, size.y * 0.5 - 0.5), TvShapes.mat(Color(0.35, 0.82, 0.25), 0.5), 0.2)
	# Flat pad parts sit a few cm off the ground: their shadows add nothing but acne risk.
	for mi in [_tile, plus_h, plus_v, bar, _fill]:
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_price = Label3D.new()
	_price.font = TvFx.font()
	_price.font_size = 72
	_price.outline_size = 16
	_price.modulate = Color(1.0, 0.88, 0.3)
	_price.outline_modulate = Color(0.25, 0.15, 0.0, 0.9)
	_price.pixel_size = 0.009
	_price.rotation_degrees = Vector3(-90, 0, 0)
	_price.position = Vector3(0, 0.17 + LIFT, size.y * 0.5 - 0.5)
	_price.modulate = Color(1, 1, 1)
	_price.outline_modulate = Color(0.1, 0.3, 0.08, 1.0)
	_price.pixel_size = 0.0075
	add_child(_price)
	var logs := {"r2_": "birch_log", "r3_": "maple_log", "r4_": "red_log", "r5_": "frost_log"}
	var log_type := str(logs.get(pad_id.left(3), "log"))
	var item := TvModels.item_in_title(text, log_type)
	var tex := TvModels.hud_icon(item) if item != "" else null
	if tex:
		_icon = Sprite3D.new()
		_icon.texture = tex
		_icon.pixel_size = 0.0078
		_icon.rotation_degrees = Vector3(-90, 0, 0)
		_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_icon.position = _price.position + Vector3(0, 0.005, 0)
		add_child(_icon)
	_arrow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.0
	cm.height = 0.55
	cm.radial_segments = 4
	_arrow.mesh = cm
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.8, 0.2)
	am.emission_enabled = true
	am.emission = Color(0.6, 0.4, 0.0)
	_arrow.material_override = am
	add_child(_arrow)
	# Plus sign and price bar bake into one mesh; the tile pulses and the fill grows, so they stay.
	TvMeshMerge.merge(self, [_tile, _fill, _arrow])
	_refresh()
	return self


func _refresh() -> void:
	_price.text = TimberGame.fmt(cost - paid_amount)
	if _icon:
		# Icon and price sit side by side, centred on the bar together.
		var w := _price.font.get_string_size(_price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _price.font_size).x * _price.pixel_size
		var iw := 0.5
		_price.position.x = (iw + 0.08) * 0.5
		_icon.position.x = _price.position.x - w * 0.5 - 0.08 - iw * 0.5
	var f := clampf(float(paid_amount) / float(cost), 0.0, 1.0)
	# The bright bar starts full-width but empty-coloured; it grows from the left as you pay.
	_fill.scale = Vector3(maxf(f, 0.001), 1, 1)
	_fill.position.x = -_bar_w * 0.5 * (1.0 - f)


func _process(delta: float) -> void:
	_t += delta
	var affordable := TimberGame.money > 0 and TimberGame.money + paid_amount >= cost
	_arrow.visible = affordable
	_arrow.position = Vector3(0, 2.1 + sin(_t * 4.0) * 0.18, 0)
	_arrow.rotation.y = _t * 1.5
	var pulse := 1.0 + (sin(_t * 5.0) * 0.03 if affordable else 0.0)
	_tile.scale = Vector3(pulse, 1, pulse)


func _on_carrier(carrier: Node, delta: float) -> bool:
	if not carrier.get("is_player") or TimberGame.money <= 0:
		return false
	var chunk := maxi(1, int(ceil(cost / 45.0)))
	chunk = mini(chunk, mini(TimberGame.money, cost - paid_amount))
	if chunk <= 0:
		return false
	TimberGame.spend(chunk)
	paid_amount += chunk
	if randf() < 0.5:
		var c := TvItems.make("coin")
		get_tree().current_scene.add_child(c)
		c.global_position = (carrier as Node3D).global_position + Vector3(0, 1.4, 0)
		var tw := c.create_tween()
		tw.tween_property(c, "global_position", global_position + Vector3(0, 0.1, 0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)
		TimberSfx.play("coin", -10.0, 1.0 + float(paid_amount) / cost * 0.6, 0.06)
	_refresh()
	if paid_amount >= cost:
		set_process(false)
		zone.remove_from_group("zones")
		TimberSfx.play("unlock", -2.0)
		TvFx.confetti(get_tree().current_scene, global_position + Vector3(0, 0.5, 0))
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
		paid.emit(id)
	return true
