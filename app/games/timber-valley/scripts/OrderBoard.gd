class_name TvOrderBoard
extends Node3D

## Cargo orders (GDD 7.6 C): a cargo ship ties up with a 2-3 line manifest of Redwood Coast goods.
## The CARGO square takes any manifest item until that line is full and refuses the rest. A full
## manifest pays Balance.ORDER.pay_mult x the sale value, the ship sounds its horn and sails, and
## the next one ties up gap_s later. No deadline, no failure, one order at a time. The order in
## progress lives in Game.orders, so it survives a restart. Workers that deliver count toward
## the valley ledger (the share of the order they carried).

signal filled(value: int)

var region: int = 4
var region_node: TvRegion
var zone: TvZone
## item -> ItemStack the delivered goods land on (one pile per manifest line).
var intakes: Dictionary = {}
var ship: Node3D
var docked: bool = false
## Mast Lathe built: masts may join the manifest.
var masts_ok: Callable
var _board: Label3D
var _gap: float = 0.0
## Items the player carried in (workers drop straight onto the line piles).
var _by_player: int = 0
var _by_all: int = 0
var _text: String = ""
var _ship_at: Vector3
var _ship_away: Vector3


## ship_local: where the cargo ship ties up (local); it sails in from and out to +X.
func setup(ship_local: Vector3) -> TvOrderBoard:
	name = "OrderBoard"
	var sign_node := TvModels.make("order_board")
	sign_node.position = Vector3(-1.4, 0, -1.8)
	add_child(sign_node)
	TvMeshMerge.merge(self)
	_board = Label3D.new()
	_board.font = TvFx.font()
	_board.font_size = 40
	_board.outline_size = 12
	_board.modulate = Color(1, 0.97, 0.88)
	_board.outline_modulate = Color(0.3, 0.18, 0.08)
	# On the board face (ASSETS_M3.md 1.3: face z +0.07, rows from y 2.42 down to 1.39).
	_board.pixel_size = 0.0042
	_board.modulate = Color(0.25, 0.16, 0.08)
	_board.outline_modulate = Color(1, 0.95, 0.8)
	_board.outline_size = 8
	_board.position = Vector3(-1.4, 1.92, -1.8 + 0.1)
	add_child(_board)
	zone = TvZone.new().setup(TvZone.Kind.CUSTOM, null, Vector2(2.4, 2.4), "CARGO", Color(0.7, 1.0, 0.8))
	zone.interval = 0.06
	zone.on_carrier = _on_carrier
	add_child(zone)
	ship = TvModels.make("cargo_ship")
	# Bow at -Z: turned -90 deg it lies along the quay with the bow out to sea.
	ship.rotation_degrees.y = -90.0
	_ship_at = ship_local
	_ship_away = ship_local + Vector3(40, 0, 0)
	ship.position = _ship_away
	ship.visible = false
	add_child(ship)
	return self


func _ready() -> void:
	if TimberGame.orders.has("lines"):
		_dock(false)
	else:
		_new_order()


## Room left on a manifest line (0 = full, not wanted, or no ship).
func room(item: String) -> int:
	if not docked or not intakes.has(item):
		return 0
	var l: Array = TimberGame.orders.lines[item]
	return int(l[0]) - int(l[1]) - (intakes[item] as TvItemStack).count()


func intake_of(item: String) -> TvItemStack:
	return intakes[item]


func _on_carrier(carrier: Node, _delta: float) -> bool:
	var back: TvItemStack = carrier.stack
	var t := back.top_type()
	if t == "" or room(t) <= 0:
		return false
	back.transfer_to(intakes[t])
	TimberSfx.play("wood", -8.0, 1.1)
	if carrier.get("is_player"):
		_by_player += 1
	return true


func _process(delta: float) -> void:
	if not docked:
		_gap -= delta
		if _gap <= 0.0 and TimberGame.orders.has("lines"):
			_dock(true)
		return
	var changed := false
	for item in intakes:
		var st: TvItemStack = intakes[item]
		var l0: Array = TimberGame.orders.lines[item]
		st.capacity = maxi(int(l0[0]) - int(l0[1]), 0)
		var got := st.take_landed()
		if got > 0:
			var l: Array = TimberGame.orders.lines[item]
			l[1] = mini(int(l[1]) + got, int(l[0]))
			_by_all += got
			changed = true
	if changed:
		_refresh()
		if _full():
			_pay()


func _full() -> bool:
	for item in TimberGame.orders.lines:
		var l: Array = TimberGame.orders.lines[item]
		if int(l[1]) < int(l[0]):
			return false
	return true


## Next manifest: 2-3 lines; each line needs base_qty + qty_per_order x n, capped (GDD 7.6 C).
func _new_order() -> void:
	var o: Dictionary = TvBalance.ORDER
	var n := int(TimberGame.orders.get("n", 0)) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * n + 13
	var qty := mini(int(o.base_qty) + int(o.qty_per_order) * n, int(o.qty_cap))
	var lines := {"timber": [qty, 0], "deckboard": [qty, 0]}
	var three := rng.randi_range(int(o.lines_min), int(o.lines_max)) >= 3
	if three and masts_ok.is_valid() and bool(masts_ok.call()):
		lines["mast"] = [maxi(int(ceil(float(qty) / TvBalance.ORDER_MAST_DIV)), 1), 0]
	TimberGame.orders = {"n": n, "lines": lines}
	_gap = float(o.gap_s)
	_by_player = 0
	_by_all = 0


func _dock(animate: bool) -> void:
	for item in intakes:
		(intakes[item] as TvItemStack).queue_free()
	intakes.clear()
	var i := 0
	for item in TimberGame.orders.lines:
		var st := TvItemStack.new().setup(item, 999, 2, 2)
		st.position = Vector3(1.6 + i * 1.4, 0.1, 0)
		add_child(st)
		intakes[item] = st
		i += 1
	docked = true
	ship.visible = true
	if animate:
		ship.position = _ship_away
		var tw := ship.create_tween()
		tw.tween_property(ship, "position", _ship_at, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		TimberSfx.play("bell", -6.0, 0.55)
	else:
		ship.position = _ship_at
	_refresh()


func _pay() -> void:
	var value := 0.0
	for item in TimberGame.orders.lines:
		value += float(TimberGame.orders.lines[item][0]) * TimberGame.price_of(item)
	var pay := int(round(value * float(TvBalance.ORDER.pay_mult)))
	TimberGame.add_money(pay, region)
	if region_node:
		region_node.record(int(pay * float(maxi(_by_all - _by_player, 0)) / maxf(_by_all, 1)))
	TimberSfx.play("bell", -2.0, 0.5)
	TimberSfx.play("coins", -2.0)
	TvFx.float_text(get_tree().current_scene, global_position + Vector3(0, 3.0, 0), "+" + TimberGame.fmt(pay), Color(1.0, 0.9, 0.35), 1.5)
	if TimberGame.hud:
		TimberGame.hud.toast("Cargo order %d filled: +%s" % [int(TimberGame.orders.n), TimberGame.fmt(pay)])
	filled.emit(pay)
	docked = false
	for item in intakes:
		(intakes[item] as TvItemStack).queue_free()
	intakes.clear()
	var tw := ship.create_tween()
	tw.tween_property(ship, "position", _ship_away, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: ship.visible = false)
	_new_order()
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray()
	if docked:
		lines.append("CARGO ORDER %d" % int(TimberGame.orders.get("n", 0)))
		for item in TimberGame.orders.lines:
			var l: Array = TimberGame.orders.lines[item]
			lines.append("%s %d/%d" % [TvItems.label(str(item)), int(l[1]), int(l[0])])
	else:
		lines.append("NEXT SHIP SOON")
	var txt := "\n".join(lines)
	if txt != _text:
		_text = txt
		_board.text = txt
