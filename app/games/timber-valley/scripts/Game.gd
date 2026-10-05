extends Node

## Global game state: one shared wallet, unlocked buildings, upgrade levels, valley ledger, saving.

signal money_changed(value: int, delta: int)
signal unlocked(id: String)
signal upgraded(id: String, level: int)

## Own save name, so a host app (MWM Play) can keep several games' saves side by side.
const SAVE_PATH := "user://timber_valley_save.json"
## Save name before 2026-10-05; moved to SAVE_PATH on the first load.
const OLD_SAVE_PATH := "user://timber-valley_save.json"
## 1 = original single-valley save (no "version" key), 2 = M1 (valleys, ledger, offline),
## 3 = M2 (build sites), 4 = M3-M5 (cargo orders, Grand Timber Station finished).
const SAVE_VERSION := 4
## A host app (MWM Play) sets Engine.set_meta(&"mwm_play_shell", true) before it loads
## scenes/Main.tscn and removes it when the game closes. Inside the host the game hides its own
## menu (sound, music, start over) and always plays, so the host's switches decide what is heard.
const SHELL_META := &"mwm_play_shell"

const PRICES := TvBalance.PRICES
const UPGRADES := TvBalance.UPGRADES

var money: int = 0
var total_earned: int = 0
var unlocked_ids: Dictionary = {}
var upgrade_levels: Dictionary = {}
## "2": {"saws": 0, "crew": 0, "fame": 0}
var region_upgrades: Dictionary = {}
## "r2": average $/s the valley's automation paid while awake (paid while it sleeps).
var ledger: Dictionary = {}
## "1": {"time": seconds played there, "earned": money earned there}
var region_stats: Dictionary = {}
## Build sites: "r3_house1": {"beam": 30, "floorboard": 12} goods delivered so far.
var sites: Dictionary = {}
## Cargo order in progress (Redwood Coast): {"n": order number, "lines": {"timber": [need, have]}}.
var orders: Dictionary = {}
## The Grand Timber Station is finished and the finish panel was shown (it does not reopen).
var complete: bool = false
## Offline earnings waiting as a coin pile at the Valley 1 office.
var offline_pending: int = 0
var pile_counts: Dictionary = {}
var finished: bool = false
var sound_on: bool = true
## Background music on/off (menu), separate from all sound (2026-10-05).
var music_on: bool = true

var player: Node3D
var hud: Node
var world: Node3D

var _save_timer: float = 0.0
var _piles: Dictionary = {}


func _ready() -> void:
	for k in UPGRADES:
		upgrade_levels[k] = 0
	load_game()


func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer > 8.0:
		_save_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func in_shell() -> bool:
	return Engine.has_meta(SHELL_META) and bool(Engine.get_meta(SHELL_META))


## region > 0 books the income to that valley (shown on its "Valley complete" card).
func add_money(amount: int, region: int = 0) -> void:
	money += amount
	if amount > 0:
		total_earned += amount
		if region > 0:
			var st := stats(region)
			st["earned"] = int(st.get("earned", 0)) + amount
	money_changed.emit(money, amount)


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money, -amount)
	return true


func price_of(item: String) -> int:
	var base: int = PRICES.get(item, 1)
	var region: int = TvBalance.ITEM_REGION.get(item, 1)
	return int(round(base * (1.0 + 0.1 * level("prices")) * fame_mult(region)))


func is_unlocked(id: String) -> bool:
	return unlocked_ids.has(id)


func unlock(id: String) -> void:
	if unlocked_ids.has(id):
		return
	unlocked_ids[id] = true
	unlocked.emit(id)
	save_game()


func level(id: String) -> int:
	return upgrade_levels.get(id, 0)


## Highest level of a global upgrade. ext = the Riverside Office board, which sells the extra levels.
func max_level(id: String, ext: bool = false) -> int:
	var mx: int = UPGRADES[id].max
	if ext and TvBalance.GLOBAL_EXT.has(id) and is_unlocked("r2_office"):
		mx += int(TvBalance.GLOBAL_EXT[id][1])
	return mx


func upgrade_cost(id: String) -> int:
	var d: Dictionary = UPGRADES[id]
	var lv := level(id)
	if lv >= int(d.max) and TvBalance.GLOBAL_EXT.has(id):
		# Extended levels: cost of level L = base x 1.75^(L - first extended level).
		return int(round(float(TvBalance.GLOBAL_EXT[id][0]) * pow(TvBalance.UPGRADE_GROWTH, lv - int(d.max))))
	return int(round(d.base * pow(TvBalance.UPGRADE_GROWTH, lv)))


func can_upgrade(id: String, ext: bool = false) -> bool:
	return level(id) < max_level(id, ext)


func buy_upgrade(id: String, ext: bool = false) -> bool:
	if not can_upgrade(id, ext) or not spend(upgrade_cost(id)):
		return false
	upgrade_levels[id] = level(id) + 1
	upgraded.emit(id, upgrade_levels[id])
	save_game()
	return true


# ---------------------------------------------------------------- per-valley upgrades

func region_level(region: int, key: String) -> int:
	var d: Dictionary = region_upgrades.get(str(region), {})
	return int(d.get(key, 0))


func region_cost(region: int, key: String) -> int:
	var base: int = TvBalance.REGION_UPGRADES[region][key]
	return int(round(base * pow(TvBalance.REGION_UPGRADE_GROWTH, region_level(region, key))))


func can_region_upgrade(region: int, key: String) -> bool:
	return region_level(region, key) < TvBalance.REGION_UPGRADE_MAX


func buy_region_upgrade(region: int, key: String) -> bool:
	if not can_region_upgrade(region, key) or not spend(region_cost(region, key)):
		return false
	var k := str(region)
	if not region_upgrades.has(k):
		region_upgrades[k] = {}
	var lv := region_level(region, key) + 1
	(region_upgrades[k] as Dictionary)[key] = lv
	upgraded.emit("r%d_%s" % [region, key], lv)
	save_game()
	return true


func fame_mult(region: int) -> float:
	return 1.0 + 0.1 * region_level(region, "fame")


func stats(region: int) -> Dictionary:
	var k := str(region)
	if not region_stats.has(k):
		region_stats[k] = {"time": 0.0, "earned": 0}
	return region_stats[k]


# ---------------------------------------------------------------- derived stats

func player_capacity() -> int:
	return 8 + 4 * level("capacity")


func player_speed() -> float:
	return 5.2 * (1.0 + 0.12 * level("speed"))


func chop_time() -> float:
	return 0.32 * pow(0.8, level("axe"))


## region > 1 adds that valley's Sharp Saws.
func machine_speed(region: int = 1) -> float:
	return (1.0 + 0.25 * level("machines")) * (1.0 + 0.25 * region_level(region, "saws"))


func worker_speed(region: int = 1) -> float:
	return 3.2 * (1.0 + 0.15 * level("workers")) * (1.0 + 0.15 * region_level(region, "crew"))


func worker_capacity(region: int = 1) -> int:
	return 6 + 2 * level("workers") + 2 * region_level(region, "crew")


## $999, $12.5K, $3.40M, $1.20B (3 significant figures above 999).
static func fmt(amount: int) -> String:
	var sign_s := "-" if amount < 0 else ""
	var v := absf(float(amount))
	if v < 1000.0:
		return sign_s + "$%d" % int(v)
	var units := ["K", "M", "B", "T"]
	var u := 0
	v /= 1000.0
	while v >= 999.5 and u < units.size() - 1:
		v /= 1000.0
		u += 1
	var digits := 2 if v < 9.995 else (1 if v < 99.95 else 0)
	return sign_s + "$" + (("%." + str(digits) + "f") % v) + str(units[u])


func register_pile(id: String, pile: Node) -> void:
	_piles[id] = pile


func saved_pile_count(id: String) -> int:
	return int(pile_counts.get(id, 0))


func ledger_total() -> float:
	var t := 0.0
	for k in ledger:
		t += float(ledger[k])
	return t


## A build site whose every slot is full.
func site_done(id: String) -> bool:
	if not TvBalance.BUILD_SITES.has(id) or not sites.has(id):
		return false
	var goods: Dictionary = TvBalance.BUILD_SITES[id].goods
	var have: Dictionary = sites[id]
	for item in goods:
		if int(have.get(item, 0)) < int(goods[item]):
			return false
	return true


func houses_done() -> int:
	var n := 0
	for id in TvBalance.BUILD_SITES:
		if bool(TvBalance.BUILD_SITES[id].rent) and site_done(id):
			n += 1
	return n


## Village rent in $/s: paid straight to the wallet, awake or asleep (GDD 7.6 B, 10.4).
func rent_rate() -> float:
	return float(houses_done() * TvBalance.RENT_PER_HOUSE) * fame_mult(3)


func save_game() -> void:
	var piles := pile_counts.duplicate()
	for id in _piles:
		var p: Node = _piles[id]
		if is_instance_valid(p):
			piles[id] = p.count()
	pile_counts = piles
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"total_earned": total_earned,
		"unlocked": unlocked_ids.keys(),
		"upgrades": upgrade_levels,
		"region_upgrades": region_upgrades,
		"ledger": ledger,
		"region_stats": region_stats,
		"offline_pending": offline_pending,
		"sites": sites,
		"orders": orders,
		"complete": complete,
		"saved_at": int(Time.get_unix_time_from_system()),
		"piles": piles,
		"finished": finished,
		"sound_on": sound_on,
		"music_on": music_on,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


## Safe to call again at any time (MWM Play calls it on every enter): it replaces the state with
## the file, and offline earnings count from the file's saved_at, so nothing is paid twice.
func load_game() -> void:
	_move_old_save()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("save file unreadable, starting fresh")
		return
	apply_save(data)


## Moves user://save.json to SAVE_PATH once. If the move fails, the old file is copied and kept.
func _move_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH) or not FileAccess.file_exists(OLD_SAVE_PATH):
		return
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(OLD_SAVE_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err == OK:
		return
	push_warning("save move failed (%d), copying" % err)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(FileAccess.get_file_as_string(OLD_SAVE_PATH))


## Reads a save dictionary of any version. Version 1 (no "version" key) has only
## money, total_earned, unlocked, upgrades, piles, finished and sound_on; every new key defaults.
func apply_save(data: Dictionary) -> void:
	money = int(data.get("money", 0))
	total_earned = int(data.get("total_earned", 0))
	unlocked_ids.clear()
	for id in data.get("unlocked", []):
		unlocked_ids[str(id)] = true
	for k in UPGRADES:
		upgrade_levels[k] = 0
	var ups: Dictionary = data.get("upgrades", {})
	for k in ups:
		if UPGRADES.has(k):
			upgrade_levels[k] = int(ups[k])
	region_upgrades = {}
	var ru: Dictionary = data.get("region_upgrades", {})
	for r in ru:
		var lv := {}
		for key in (ru[r] as Dictionary):
			lv[str(key)] = int(ru[r][key])
		region_upgrades[str(r)] = lv
	ledger = {}
	var lg: Dictionary = data.get("ledger", {})
	for k in lg:
		ledger[str(k)] = float(lg[k])
	region_stats = {}
	var rs: Dictionary = data.get("region_stats", {})
	for k in rs:
		var d: Dictionary = rs[k]
		region_stats[str(k)] = {"time": float(d.get("time", 0.0)), "earned": int(d.get("earned", 0))}
	offline_pending = int(data.get("offline_pending", 0))
	sites = {}
	var sd: Dictionary = data.get("sites", {})
	for k in sd:
		var d := {}
		for item in (sd[k] as Dictionary):
			d[str(item)] = int(sd[k][item])
		sites[str(k)] = d
	orders = {}
	var od: Dictionary = data.get("orders", {})
	if od.has("lines"):
		var lines := {}
		for item in (od.lines as Dictionary):
			var l: Array = od.lines[item]
			lines[str(item)] = [int(l[0]), int(l[1])]
		orders = {"n": int(od.get("n", 0)), "lines": lines}
	complete = bool(data.get("complete", false))
	pile_counts = data.get("piles", {})
	# Old saves: finished = true means the Lodge is done; the finish panel does not reopen.
	finished = bool(data.get("finished", false))
	if finished:
		unlocked_ids["lodge"] = true
	sound_on = bool(data.get("sound_on", true))
	music_on = bool(data.get("music_on", true))
	# Offline earnings: up to 2 h at 50% of the ledger income, collected at the office.
	var saved_at := int(data.get("saved_at", 0))
	if saved_at > 0:
		var away := clampi(int(Time.get_unix_time_from_system()) - saved_at, 0, TvBalance.OFFLINE_MAX_S)
		# A quick restart is not "away": only count breaks of a minute or more.
		if away >= 60:
			offline_pending += int(away * (ledger_total() + rent_rate()) * TvBalance.OFFLINE_RATE)


func collect_offline() -> int:
	var v := offline_pending
	offline_pending = 0
	if v > 0:
		add_money(v)
		save_game()
	return v


func reset_game() -> void:
	for path in [SAVE_PATH, OLD_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	money = 0
	total_earned = 0
	unlocked_ids.clear()
	pile_counts.clear()
	region_upgrades.clear()
	ledger.clear()
	region_stats.clear()
	offline_pending = 0
	sites.clear()
	orders.clear()
	complete = false
	_piles.clear()
	finished = false
	for k in UPGRADES:
		upgrade_levels[k] = 0
	get_tree().reload_current_scene()
