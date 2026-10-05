class_name TvBalance
extends RefCounted

## Every cost, price and rate in one place (GDD section 8.2). Pads for Valley 2 come from
## docs/balance/unlocks_regions.csv; positions nudged where a pad sat in the river or on a zone
## (Maple Highlands moves are listed in docs/GDD.md, "M2 layout").

const PRICES := {
	"plank": 3, "chair": 8, "table": 20, "bookcase": 45,
	"veneer": 8, "plywood": 40, "canoe": 300,
	"beam": 30, "floorboard": 12, "cabin_kit": 260,
	"timber": 70, "deckboard": 30, "mast": 500,
	"dry_lumber": 90, "skis": 400, "sled": 1500, "guitar": 2000,
}
## Which valley sells an item (its Local Fame applies to the price).
const ITEM_REGION := {
	"plank": 1, "chair": 1, "table": 1, "bookcase": 1,
	"veneer": 2, "plywood": 2, "canoe": 2,
	"beam": 3, "floorboard": 3, "cabin_kit": 3,
	"timber": 4, "deckboard": 4, "mast": 4,
	"dry_lumber": 5, "skis": 5, "sled": 5, "guitar": 5,
}
## pine regrow stays 8.0 s: that is what Valley 1 ships today (GDD block says 7.0).
const TREES := {
	"broad": {"log": "log", "logs": 3, "hits": 3, "regrow": 7.0, "scale": 1.0},
	"pine": {"log": "log", "logs": 4, "hits": 4, "regrow": 8.0, "scale": 1.0},
	"birch": {"log": "birch_log", "logs": 4, "hits": 4, "regrow": 8.0, "scale": 1.0},
	"maple": {"log": "maple_log", "logs": 5, "hits": 5, "regrow": 9.0, "scale": 1.1},
	"redwood": {"log": "red_log", "logs": 8, "hits": 7, "regrow": 14.0, "scale": 1.6},
	"frost": {"log": "frost_log", "logs": 6, "hits": 6, "regrow": 12.0, "scale": 1.15},
}
## Per-model scale factor that replaces the kind's "scale" (designer flag b, 2026-10-01): the
## wide maple C stays at 1.0 so paths and the guide arrow stay visible next to groves.
const TREE_SCALE_OVERRIDE := {"tree_mapleC": 1.0}
## Trunk collision radius per kind (default 0.22; GDD 7.2: redwood 0.45).
const TREE_RADIUS := {"redwood": 0.45}
# id: [in_a, n_a, in_b, n_b, out, n_out, cycle_s]  ("" = no second input)
const MACHINES := {
	# lathe 1.2 -> 0.8 s (2026-10-04): with 6 crews it was the Birch Bend bottleneck (88-92% busy).
	"lathe": ["birch_log", 2, "", 0, "veneer", 6, 0.8],
	"press": ["veneer", 3, "", 0, "plywood", 1, 1.5],
	"boatshop": ["plywood", 4, "", 0, "canoe", 1, 3.0],
	"beamsaw": ["maple_log", 1, "", 0, "beam", 2, 1.4],
	# planer 1.6 -> 1.1 s (2026-10-04): input 87-98% full from r3_jack2 on, kit factory
	# short of floorboards.
	"planer": ["maple_log", 1, "", 0, "floorboard", 4, 1.1],
	"kitfactory": ["beam", 2, "floorboard", 4, "cabin_kit", 1, 2.0],
	"redmill": ["red_log", 1, "", 0, "timber", 2, 1.5],
	"decksaw": ["timber", 1, "", 0, "deckboard", 3, 1.2],
	"mastlathe": ["red_log", 3, "", 0, "mast", 1, 4.0],
	"skiworks": ["dry_lumber", 2, "", 0, "skis", 1, 2.0],
	"sledshop": ["dry_lumber", 3, "skis", 1, "sled", 1, 3.0],
	"luthier": ["dry_lumber", 4, "", 0, "guitar", 1, 5.0],
}
## Output pile size per machine id when it differs from the default 48.
const MACHINE_OUT_CAP := {"boatshop": 12, "mastlathe": 12, "luthier": 12}
const KILN := {"batch": 20, "bake_s": 16.0, "idle_start_s": 6.0}
const RENT_PER_HOUSE := 15  # $/s base, x Local Fame
const SHIP_REWARD := 14000
const SHIP_MIN_INTERVAL := 45.0
const ORDER := {"lines_min": 2, "lines_max": 3, "base_qty": 10, "qty_per_order": 4, "qty_cap": 60, "pay_mult": 1.6, "gap_s": 15.0}
# region upgrades: base cost per valley, growth 1.8, max 5 (rebalance 2026-10-01,
# docs/balance/rebalance_2026-10-01.md)
const REGION_UPGRADES := {
	2: {"saws": 2200, "crew": 1400, "fame": 3400},
	3: {"saws": 13000, "crew": 8000, "fame": 19000},
	# Valleys 4-5 re-derived 2026-10-03 from measured income (docs/balance/m345_2026-10-03.md).
	4: {"saws": 54000, "crew": 34000, "fame": 82000},
	5: {"saws": 150000, "crew": 95000, "fame": 230000},
}
const REGION_UPGRADE_GROWTH := 1.8
const REGION_UPGRADE_MAX := 5
const REGION_UPGRADE_INFO := {
	"saws": {"name": "Sharp Saws", "desc": "Machines here 25% faster"},
	"crew": {"name": "Crew Coffee", "desc": "Crew here faster, +2 carry"},
	"fame": {"name": "Local Fame", "desc": "+10% prices and shoppers here"},
}
const GLOBAL_EXT := {"capacity": [2500, 4], "speed": [3000, 2], "axe": [2000, 3]}  # [base, extra levels], growth 1.75
const CUSTOMERS_PER_REGION := 20

## Global upgrades (office in Valley 1). Cost = base x 1.75^level.
const UPGRADES := {
	"capacity": {"name": "Bigger Backpack", "desc": "Carry 4 more items", "base": 30, "max": 6},
	"speed": {"name": "Running Shoes", "desc": "Walk 12% faster", "base": 40, "max": 5},
	"axe": {"name": "Sharper Axe", "desc": "Chop trees faster", "base": 35, "max": 5},
	"machines": {"name": "Oiled Machines", "desc": "Machines work 25% faster", "base": 90, "max": 5},
	"workers": {"name": "Coffee Break", "desc": "Workers walk faster, carry more", "base": 120, "max": 5},
	"prices": {"name": "Good Reputation", "desc": "Customers pay 10% more", "base": 150, "max": 5},
}
const UPGRADE_GROWTH := 1.75

## Exports (generalised TruckDock): items per trip, seconds away between trips.
const EXPORTS := {
	"truck": {"cap": 8, "away": 5.0},
	# barge 6 -> 12 (2026-10-04): at the Forester Camp the canoe dock sat full 71-80% of the time
	# (barge 0.32 canoes/s vs ~0.42 built); 12 = two layers on its 3x2 bed.
	"barge": {"cap": 12, "away": 8.0},
	# 3 wagons x 4 kits = 12 per trip; Longer Train (r3_rail2) couples 2 more (20 per trip).
	"train": {"cap": 12, "away": 10.0, "wagons": 3},
	# Frost Peaks mountain train (GDD 7.9): 10 guitars per trip in 2 wagons of 5.
	"mtrain": {"cap": 10, "away": 12.0, "wagons": 2, "per_wagon": 5},
}
## Train travel speed (m/s). The Highland train now runs on through Frost Peaks to x 104 (it used
## to vanish at x 52, which is inside Frost Peaks now), so it runs twice as fast and each trip
## takes the same time as before.
const TRAIN_SPEED := 18.0
const RAIL2_WAGONS := 2
## Forklift hauler (GDD 7.5): faster, carries more, serves several piles (the fullest first).
## max_load_h caps a load of bulky items (cabin kits) at this stack height in metres.
const FORKLIFT := {"speed": 4.5, "cap": 20, "max_load_h": 2.4}
## Per-valley forklift override (2026-10-04): the one Redwood Coast forklift serves three machines
## about 45 m from the harbor; at 4.5 m/s x 20 the deck saw output sat full 300+ s of 360.
const FORKLIFT_BY_REGION := {4: {"speed": 6.0, "cap": 36, "max_load_h": 2.4}}
## A cabin kit is 724 tris: piles draw at most this many (designer flag d: a full 48-kit pile
## was about 35k tris). The pile keeps its real count; only the drawn tower is capped.
const KIT_PILE_DRAWN := 12
## Vehicle workers (GDD 7.5): skidder = lumberjack, snowcat = hauler. Speed m/s, carry at
## Coffee Break 0 (+2 per level), model = Models key.
const VEHICLES := {
	"skidder": {"speed": 4.8, "cap": 16, "model": "skidder"},
	"snowcat": {"speed": 4.5, "cap": 24, "model": "snowcat"},
}
## Shipwrights (GDD 7.5): builders that fill slipway slots, the least-full slot first. Carry 10 (+2/lvl).
const SHIPWRIGHT_CAP := 10
## Station porters: one per valley platform, carrying that valley's export to its platform.
const PORTER_CAP := 10
## Handcar fast travel (GDD 7.6 E): stand on a tile hold_s, fade out, move, fade in.
const HANDCAR := {"hold_s": 0.8, "fade_s": 0.3}
## One stop per valley hub: "pos" = sign + tiles, "land" = where a rider arrives (off the tiles),
## "side" = which side (-1 west, 1 east) the handcar track sits on.
## GDD 7.6 E spots nudged off buildings and pads (V1 office, V2 office, V3 gate road).
const HANDCAR_STOPS := {
	1: {"pos": Vector3(-9.7, 0, 11.2), "land": Vector3(-5.6, 0, 10.0), "side": -1},
	2: {"pos": Vector3(-35.6, 0, 3.4), "land": Vector3(-35.6, 0, 6.6), "side": 1},
	3: {"pos": Vector3(-7.0, 0, -57.8), "land": Vector3(-1.4, 0, -57.4), "side": -1},
	4: {"pos": Vector3(37.0, 0, 11.0), "land": Vector3(33.0, 0, 8.6), "side": 1},
	5: {"pos": Vector3(41.0, 0, -60.5), "land": Vector3(43.4, 0, -57.6), "side": -1},
}
## Tile spacing at a stop: one row, 3.4 m apart for up to 2 tiles (M2 look), 2.4 m with a
## smaller valley name once a stop has 3 or 4 tiles (the V1 and V3 stops moved 1.2 / 1 m west
## so four tiles clear the Home Valley office and the gate road).
const HANDCAR_TILE_STEP := {2: 3.4, 4: 2.4}
## Discard bins (the owner 2026-10-03): one square per valley by its main path; standing on it throws
## away everything carried (nothing is paid).
const DISCARD_BINS := {
	1: Vector3(-2.4, 0, 7.4), 2: Vector3(-35.0, 0, -9.6), 3: Vector3(2.9, 0, -57.2),
	4: Vector3(25.6, 0, -16.4), 5: Vector3(51.6, 0, -62.8),
}
## Valley open = its gateway is paid (Home Valley always).
const VALLEY_GATE := {1: "", 2: "r2_bridge", 3: "r3_gate", 4: "r4_crossing", 5: "r5_cablecar"}
## Build sites (GDD 7.6 B): the pad pays the money slot, then goods fill the slots; stage k of N
## rises at k/N of the goods. Houses pay rent (+10% Builders' Yard shoppers each) once done.
## slot_x/slot_z: where the slot squares start (world), stepped along z (houses) or x (tower).
const BUILD_SITES := {
	"r3_house1": {"model": "house_cottage", "pos": Vector3(-17, 0, -62), "goods": {"beam": 30, "floorboard": 40}, "stages": 4, "rent": true},
	"r3_house2": {"model": "house_farmhouse", "pos": Vector3(-17, 0, -70), "goods": {"beam": 40, "floorboard": 50, "cabin_kit": 2}, "stages": 4, "rent": true},
	"r3_house3": {"model": "house_barn", "pos": Vector3(-17, 0, -78), "goods": {"beam": 50, "floorboard": 60, "cabin_kit": 4}, "stages": 4, "rent": true},
	"r3_house4": {"model": "house_school", "pos": Vector3(-17, 0, -86), "goods": {"beam": 60, "floorboard": 70, "cabin_kit": 6}, "stages": 4, "rent": true},
	"r3_house5": {"model": "house_inn", "pos": Vector3(-17, 0, -94), "goods": {"beam": 70, "floorboard": 80, "cabin_kit": 8}, "stages": 4, "rent": true},
	"r3_clocktower": {"model": "clock_tower", "pos": Vector3(-10, 0, -112), "goods": {"beam": 120, "floorboard": 100, "cabin_kit": 12}, "stages": 6, "rent": false},
	# Redwood Coast: repeatable ship slipways (launch east into the sea) and the Lighthouse.
	"r4_slipway": {"model": "ship_hull", "pos": Vector3(67, 0, -26), "goods": {"timber": 60, "deckboard": 80, "mast": 3}, "stages": 4, "rent": false, "repeat": true, "region": 4},
	"r4_slipway2": {"model": "ship_hull", "pos": Vector3(67, 0, -36), "goods": {"timber": 60, "deckboard": 80, "mast": 3}, "stages": 4, "rent": false, "repeat": true, "region": 4},
	"r4_lighthouse": {"model": "lighthouse", "pos": Vector3(71, 0, -43), "goods": {"timber": 200, "deckboard": 150, "mast": 10}, "stages": 6, "rent": false, "region": 4},
	# Frost Peaks landmark.
	"r5_observatory": {"model": "observatory", "pos": Vector3(68, 0, -113), "goods": {"dry_lumber": 200, "skis": 60, "sled": 20, "guitar": 10}, "stages": 6, "rent": false, "region": 5},
	# Grand Timber Station: one platform per valley next to its handcar stop (GDD 7.7).
	"cap_p1": {"model": "platform_slot_v1", "pos": Vector3(-18.0, 0, 8.0), "goods": {"bookcase": 120}, "stages": 0, "rent": false, "region": 1, "platform": true},
	"cap_p2": {"model": "platform_slot_v2", "pos": Vector3(-33.6, 0, -1.6), "goods": {"canoe": 40}, "stages": 0, "rent": false, "region": 2, "platform": true},
	"cap_p3": {"model": "platform_slot_v3", "pos": Vector3(-18.6, 0, -57.6), "goods": {"cabin_kit": 40}, "stages": 0, "rent": false, "region": 3, "platform": true},
	"cap_p4": {"model": "platform_slot_v4", "pos": Vector3(26.4, 0, 11.0), "goods": {"mast": 30}, "stages": 0, "rent": false, "region": 4, "platform": true},
	"cap_p5": {"model": "platform_slot_v5", "pos": Vector3(28.6, 0, -58.4), "goods": {"guitar": 20}, "stages": 0, "rent": false, "region": 5, "platform": true},
}
## Ship launch (GDD 7.6 B / 11): the hull slides this far east into the sea over LAUNCH_S.
const SHIP_LAUNCH := {"slide_m": 8.0, "launch_s": 4.0}
## Cargo orders: the cargo ship ties up at ORDER_SHIP; masts join a manifest only as its third
## line and only once the Mast Lathe stands, at a fifth of the line size (GDD 7.6 C is silent on
## per-item size; 60 masts would be 48 000 base for one line).
const ORDER_MAST_DIV := 5
## Kiln look: the chimney glow ramps over the bake.
const KILN_GLOW_MAX := 3.0
## Forester Camp (r2_jack3, the owner 2026-10-01): its crew size, and every birch regrows this much
## faster once it is bought.
const FORESTER_CAMP := {"crew": 3, "birch_regrow_mult": 0.6}
## Thin goods carry by height, not by count (the owner 2026-10-04, Birch Bend stalls): workers, the
## player and belts move this many of the item per carried slot. Items not listed = 1.
const CARRY_MULT := {"veneer": 3}
## Shoppers buy this many times their usual amount (veneer sells in bundles, so the counter keeps
## up with a carrier that brings 3x as much; docs/balance/birch_redwood_pacing_2026-10-04.md).
const SHOPPER_QTY_MULT := {"veneer": 5}
## Landmark/village site reserve (2026-10-04): while a Maple Highlands village site or the Summit
## Observatory needs an item, the belts that empty its source pile leave this many on the pile for
## the forklift/snowcat (belts emptied the piles, so sites got no beams, kits, sleds or guitars).
const SITE_RESERVE := {
	"beam": 12, "floorboard": 12, "cabin_kit": 4, "dry_lumber": 20, "sled": 4, "guitar": 2,
}
## Redwood Coast timber carriers (r4_hauler1): one walked the 40 m mill-to-harbor trip busy 100%
## and shoppers still waited at an empty counter 26% of the time (2026-10-05).
const TIMBER_CARRIERS := 2
## Log flume (Valley 2): a Conveyor with a water look. 2026-10-04: spacing 0.5 -> 0.25 s (2 -> 4
## logs/s; at 0.5 the five flume crews stood at a full chute while the lathe ran dry) and speed
## 3.5 -> 7.0 m/s (logs in the water hold lathe-input room, so fewer riders = fewer stalls).
const FLUME := {"speed": 7.0, "spacing": 0.25, "bob_m": 0.06, "bob_hz": 3.0}

## Valley sleep and ledger (GDD section 10).
const WAKE_MARGIN := 24.0
const SLEEP_MARGIN := 30.0
const MAX_AWAKE := 2
const LEDGER_WINDOW_S := 120
## Offline earnings (the owner, 2026-09-30): up to 2 h at 50% of the ledger income.
const OFFLINE_MAX_S := 7200
const OFFLINE_RATE := 0.5

## Valleys: name and walkable interior (x, z, width, depth) in world metres.
const REGIONS := {
	1: {"name": "Home Valley", "rect": Rect2(-23.5, -47.0, 42.5, 62.5)},
	2: {"name": "Birch Bend", "rect": Rect2(-79.0, -47.0, 48.0, 62.5)},
	3: {"name": "Maple Highlands", "rect": Rect2(-23.5, -119.0, 42.5, 64.0)},
	4: {"name": "Redwood Coast", "rect": Rect2(23.0, -47.0, 54.0, 62.5)},
	5: {"name": "Frost Peaks", "rect": Rect2(23.0, -119.0, 54.0, 64.0)},
}

# Every purchasable step. Pads show once all "req" ids are owned.
const UNLOCKS := [
	{"id": "trees2", "cost": 10, "req": [], "title": "More Trees", "pad": Vector3(-9, 0, 5.8)},
	{"id": "office", "cost": 25, "req": [], "title": "Upgrade Office", "pad": Vector3(-3.5, 0, 10.5)},
	{"id": "jack1", "cost": 50, "req": ["trees2"], "title": "Hire a Lumberjack", "pad": Vector3(-4.6, 0, 2.5)},
	{"id": "hauler1", "cost": 70, "req": ["jack1"], "title": "Hire a Plank Carrier", "pad": Vector3(5.0, 0, -0.5)},
	{"id": "carpentry", "cost": 120, "req": ["hauler1"], "title": "Carpentry: Chairs", "pad": Vector3(2, 0, -13)},
	{"id": "hauler3", "cost": 160, "req": ["carpentry"], "title": "Hire a Chair Carrier", "pad": Vector3(6.5, 0, -8.5)},
	{"id": "pine", "cost": 180, "req": ["carpentry"], "title": "Pine Forest", "pad": Vector3(-9.5, 0, -10.5)},
	{"id": "cashier", "cost": 220, "req": ["carpentry"], "title": "Hire a Cashier", "pad": Vector3(7.0, 0, -3.8)},
	{"id": "sawmill2", "cost": 260, "req": ["pine"], "title": "Second Sawmill", "pad": Vector3(-3, 0, -24)},
	{"id": "jack2", "cost": 300, "req": ["sawmill2"], "title": "Hire a Lumberjack", "pad": Vector3(-8.0, 0, -20.5)},
	{"id": "hauler2", "cost": 320, "req": ["sawmill2"], "title": "Hire a Carrier: Sawmill to Carpentry", "pad": Vector3(0.6, 0, -18.8)},
	{"id": "cnc", "cost": 600, "req": ["hauler2"], "title": "CNC Workshop: Tables", "pad": Vector3(9, 0, -24)},
	{"id": "conveyor1", "cost": 700, "req": ["cnc"], "title": "Conveyor Belt", "pad": Vector3(3.0, 0, -20.2)},
	{"id": "hauler4", "cost": 750, "req": ["cnc"], "title": "Hire a Table Carrier", "pad": Vector3(13.0, 0, -19.5)},
	{"id": "factory", "cost": 1200, "req": ["conveyor1"], "title": "Robot Furniture Factory", "pad": Vector3(0, 0, -36)},
	{"id": "jack3", "cost": 900, "req": ["factory"], "title": "North Forest + 2 Lumberjacks", "pad": Vector3(-8.5, 0, -29.0)},
	{"id": "dock", "cost": 1500, "req": ["factory"], "title": "Truck Loading Dock", "pad": Vector3(13.5, 0, -36)},
	{"id": "conveyor2", "cost": 1300, "req": ["dock"], "title": "Factory Conveyor", "pad": Vector3(8.0, 0, -41.0)},
	{"id": "roadsign", "cost": 200, "req": ["carpentry"], "title": "Road Sign: More Shoppers", "pad": Vector3(13.0, 0, 9.5)},
	{"id": "belt_planks", "cost": 350, "req": ["cashier"], "title": "Conveyor: Sawmill to Market", "pad": Vector3(3.2, 0, 9.6)},
	{"id": "belt_saw2", "cost": 500, "req": ["hauler2"], "title": "Conveyor: Sawmill 2 to Carpentry", "pad": Vector3(-2.6, 0, -18.4)},
	{"id": "belt_chairs", "cost": 650, "req": ["hauler3", "belt_planks"], "title": "Conveyor: Chairs to Market", "pad": Vector3(8.0, 0, -8.0)},
	# Tables had only a carrier (the owner 2026-10-05). Priced between the chair and mega-saw belts.
	{"id": "belt_tables", "cost": 800, "req": ["hauler4", "belt_chairs"], "title": "Conveyor: Tables to Market", "pad": Vector3(13.6, 0, -19.5)},
	{"id": "megasaw", "cost": 2500, "req": ["factory"], "title": "MEGA Sawmill", "pad": Vector3(11.0, 0, -13.5)},
	{"id": "belt_mega", "cost": 1000, "req": ["megasaw"], "title": "Conveyor: Mega Sawmill to CNC", "pad": Vector3(9.5, 0, -18.4)},
	{"id": "lodge", "cost": 6000, "req": ["conveyor2", "jack3", "belt_mega", "belt_tables"], "title": "Build the Grand Lodge", "pad": Vector3(-12, 0, -39)},
	# ---- Valley 2: Birch Bend (unlocks_regions.csv). Bridge pad moved from the river (-27) to the V1 bank.
	{"id": "r2_bridge", "cost": 2800, "req": ["lodge"], "title": "River Bridge to Birch Bend", "pad": Vector3(-20.5, 0, -6)},
	{"id": "r2_lathe", "cost": 3600, "req": ["r2_bridge"], "title": "Veneer Lathe", "pad": Vector3(-45, 0, -6)},
	{"id": "r2_grove2", "cost": 3200, "req": ["r2_lathe"], "title": "More Birches", "pad": Vector3(-55, 0, 6)},
	{"id": "r2_office", "cost": 3400, "req": ["r2_lathe"], "title": "Riverside Office", "pad": Vector3(-34, 0, 11)},
	{"id": "r2_jack1", "cost": 4700, "req": ["r2_grove2"], "title": "Hire a Birch Lumberjack", "pad": Vector3(-50, 0, 2)},
	{"id": "r2_hauler1", "cost": 5400, "req": ["r2_jack1"], "title": "Hire a Veneer Carrier", "pad": Vector3(-40, 0, -2)},
	{"id": "r2_flume", "cost": 6000, "req": ["r2_jack1"], "title": "Log Flume", "pad": Vector3(-60, 0, -22)},
	{"id": "r2_cashier", "cost": 6400, "req": ["r2_hauler1"], "title": "Riverside Cashier", "pad": Vector3(-35, 0, 0)},
	{"id": "r2_press", "cost": 8700, "req": ["r2_hauler1"], "title": "Plywood Press", "pad": Vector3(-45, 0, -18)},
	# r2_jack2 9500 -> 13500 (2026-10-04): the flume crews come after the press line, which is
	# the only place their logs can go; before it they stood at a full chute 85-90% of the time.
	{"id": "r2_jack2", "cost": 13500, "req": ["r2_flume"], "title": "Hire 2 Flume Lumberjacks", "pad": Vector3(-56, 0, -26)},
	{"id": "r2_belt_lp", "cost": 11000, "req": ["r2_press"], "title": "Conveyor: Lathe to Press", "pad": Vector3(-42, 0, -12)},
	{"id": "r2_hauler2", "cost": 13000, "req": ["r2_press"], "title": "Hire a Plywood Carrier", "pad": Vector3(-38.5, 0, -14.5)},
	{"id": "r2_press2", "cost": 17000, "req": ["r2_belt_lp"], "title": "Second Plywood Press", "pad": Vector3(-45, 0, -28)},
	{"id": "r2_boatshop", "cost": 19000, "req": ["r2_press2"], "title": "Boat Workshop: Canoes", "pad": Vector3(-40, 0, -38)},
	{"id": "r2_barge", "cost": 21000, "req": ["r2_boatshop"], "title": "Barge Landing", "pad": Vector3(-33, 0, -36)},
	{"id": "r2_belt_pb", "cost": 23000, "req": ["r2_barge"], "title": "Conveyor: Presses to Boat Workshop", "pad": Vector3(-43, 0, -33)},
	{"id": "r2_belt_bb", "cost": 30000, "req": ["r2_barge"], "title": "Conveyor: Boat Workshop to Barge", "pad": Vector3(-35, 0, -41.5)},
	{"id": "r2_jack3", "cost": 37000, "req": ["r2_belt_pb"], "title": "Forester Camp: 3 Lumberjacks + Faster Birches", "pad": Vector3(-68, 0, -14)},
	{"id": "r2_boathouse", "cost": 63000, "req": ["r2_belt_bb", "r2_jack3"], "title": "Build the Boathouse", "pad": Vector3(-68, 0, 8)},
	# ---- Valley 3: Maple Highlands (unlocks_regions.csv). Gate pad on the Home Valley side, like the bridge.
	{"id": "r3_gate", "cost": 16000, "req": ["r2_boathouse"], "title": "Highland Gate", "pad": Vector3(0, 0, -42.4)},
	# r3_beamsaw 20000 -> 8000 (2026-10-04): the player stood 71 s at the gateway with nothing to do.
	{"id": "r3_beamsaw", "cost": 8000, "req": ["r3_gate"], "title": "Beam Saw", "pad": Vector3(2.5, 0, -64.5)},
	{"id": "r3_grove2", "cost": 16000, "req": ["r3_beamsaw"], "title": "More Maples", "pad": Vector3(-8, 0, -72)},
	{"id": "r3_office", "cost": 17000, "req": ["r3_beamsaw"], "title": "Highland Office", "pad": Vector3(6.5, 0, -59.5)},
	{"id": "r3_jack1", "cost": 23000, "req": ["r3_grove2"], "title": "Hire a Maple Lumberjack", "pad": Vector3(-2.0, 0, -61.2)},
	{"id": "r3_forklift1", "cost": 28000, "req": ["r3_jack1"], "title": "Hire a Forklift: Beams", "pad": Vector3(6, 0, -69)},
	{"id": "r3_cashier", "cost": 37000, "req": ["r3_forklift1"], "title": "Builders' Yard Cashier", "pad": Vector3(12, 0, -58)},
	{"id": "r3_planer", "cost": 42000, "req": ["r3_forklift1"], "title": "Planer Mill: Floorboards", "pad": Vector3(2.5, 0, -78)},
	{"id": "r3_jack2", "cost": 46000, "req": ["r3_belt_bp"], "title": "Hire 2 Lumberjacks + North Maples", "pad": Vector3(-8, 0, -96)},
	{"id": "r3_house1", "cost": 42000, "req": ["r3_planer"], "title": "Village Plot 1: Cottage", "pad": Vector3(-17, 0, -62)},
	{"id": "r3_belt_bp", "cost": 45000, "req": ["r3_house1"], "title": "Conveyor: Beam Saw + Planer to Yard", "pad": Vector3(8, 0, -72)},
	{"id": "r3_kitfactory", "cost": 63000, "req": ["r3_belt_bp"], "title": "Cabin Kit Factory", "pad": Vector3(6, 0, -90)},
	{"id": "r3_house2", "cost": 63000, "req": ["r3_kitfactory"], "title": "Village Plot 2: Farmhouse", "pad": Vector3(-17, 0, -70)},
	{"id": "r3_rail", "cost": 72000, "req": ["r3_kitfactory"], "title": "Highland Railway", "pad": Vector3(13, 0, -100)},
	{"id": "r3_belt_kit", "cost": 75000, "req": ["r3_rail"], "title": "Conveyors: Kit Factory Feed + Rail", "pad": Vector3(9, 0, -94)},
	{"id": "r3_house3", "cost": 100000, "req": ["r3_belt_kit"], "title": "Village Plot 3: Barn", "pad": Vector3(-17, 0, -78)},
	{"id": "r3_jack3", "cost": 110000, "req": ["r3_belt_kit"], "title": "Hire 3 Lumberjacks + Ridge Maples", "pad": Vector3(-4, 0, -110)},
	{"id": "r3_rail2", "cost": 120000, "req": ["r3_jack3"], "title": "Longer Train", "pad": Vector3(15, 0, -102)},
	{"id": "r3_house4", "cost": 140000, "req": ["r3_rail2"], "title": "Village Plot 4: School", "pad": Vector3(-17, 0, -86)},
	{"id": "r3_house5", "cost": 150000, "req": ["r3_house4"], "title": "Village Plot 5: Inn", "pad": Vector3(-17, 0, -94)},
	{"id": "r3_clocktower", "cost": 280000, "req": ["r3_house5"], "title": "Build the Clock Tower", "pad": Vector3(-10, 0, -112)},
	# ---- Valley 4: Redwood Coast (unlocks_regions.csv; moves listed in docs/GDD.md "M3 layout").
	# Opening pads redwood mill .. Harbor Cashier cut 2026-10-04 (the owner: too much waiting early;
	# docs/balance/birch_redwood_pacing_2026-10-04.md). Deck Saw on unchanged.
	{"id": "r4_crossing", "cost": 68000, "req": ["r3_clocktower"], "title": "Level Crossing to Redwood Coast", "pad": Vector3(13.0, 0, -19.5)},
	{"id": "r4_redmill", "cost": 20000, "req": ["r4_crossing"], "title": "Redwood Mill: Timber", "pad": Vector3(32, 0, -20)},
	{"id": "r4_grove2", "cost": 40000, "req": ["r4_redmill"], "title": "More Redwoods", "pad": Vector3(45, 0, 4)},
	{"id": "r4_office", "cost": 45000, "req": ["r4_redmill"], "title": "Harbor Office", "pad": Vector3(28, 0, 7.4)},
	{"id": "r4_jack1", "cost": 55000, "req": ["r4_grove2"], "title": "Hire a Redwood Lumberjack", "pad": Vector3(37, 0, -2)},
	# the owner 2026-10-05: nothing carried timber to the counter before the forklift (pad 12), so
	# shoppers queued at an empty counter 52-54% of the time. A plain carrier right after jack1.
	{"id": "r4_hauler1", "cost": 50000, "req": ["r4_jack1"], "title": "Hire 2 Timber Carriers", "pad": Vector3(36.5, 0, -16.5)},
	{"id": "r4_skidder1", "cost": 65000, "req": ["r4_jack1"], "title": "Hire a Log Skidder", "pad": Vector3(38, 0, -14)},
	{"id": "r4_harbor", "cost": 75000, "req": ["r4_skidder1"], "title": "Fishing Pier: More Shoppers", "pad": Vector3(70, 0, 4)},
	{"id": "r4_cashier", "cost": 85000, "req": ["r4_harbor"], "title": "Harbor Cashier", "pad": Vector3(61.5, 0, -9.5)},
	{"id": "r4_decksaw", "cost": 130000, "req": ["r4_cashier"], "title": "Deck Saw: Deckboards", "pad": Vector3(32, 0, -32)},
	{"id": "r4_jack2", "cost": 140000, "req": ["r4_decksaw"], "title": "Hire 2 Lumberjacks + North Redwoods", "pad": Vector3(56, 0, -38)},
	{"id": "r4_belt_rd", "cost": 140000, "req": ["r4_jack2"], "title": "Conveyor: Mill to Deck Saw", "pad": Vector3(30, 0, -26)},
	{"id": "r4_forklift", "cost": 150000, "req": ["r4_belt_rd"], "title": "Hire a Forklift: Harbor", "pad": Vector3(44, 0, -14)},
	{"id": "r4_mastlathe", "cost": 170000, "req": ["r4_forklift"], "title": "Mast Lathe", "pad": Vector3(50, 0, -24)},
	{"id": "r4_slipway", "cost": 180000, "req": ["r4_mastlathe"], "title": "Shipyard Slipway", "pad": Vector3(67, 0, -26)},
	{"id": "r4_orders", "cost": 190000, "req": ["r4_slipway"], "title": "Cargo Order Board", "pad": Vector3(64, 0, 12)},
	{"id": "r4_skidder2", "cost": 210000, "req": ["r4_orders"], "title": "Hire 2 Skidders + Far Redwoods", "pad": Vector3(36, 0, -37)},
	{"id": "r4_builders", "cost": 210000, "req": ["r4_skidder2"], "title": "Hire 2 Shipwrights", "pad": Vector3(58, 0, -20)},
	{"id": "r4_belt_ds", "cost": 300000, "req": ["r4_builders"], "title": "Conveyors: Deck Saw + Lathe to Slipway", "pad": Vector3(46, 0, -30)},
	{"id": "r4_jack3", "cost": 350000, "req": ["r4_belt_ds"], "title": "Hire 3 Lumberjacks + Cliff Redwoods", "pad": Vector3(27, 0, -34.5)},
	{"id": "r4_slipway2", "cost": 400000, "req": ["r4_jack3"], "title": "Second Slipway", "pad": Vector3(67, 0, -36)},
	{"id": "r4_lighthouse", "cost": 630000, "req": ["r4_slipway2"], "title": "Build the Lighthouse", "pad": Vector3(71, 0, -43)},
	# ---- Valley 5: Frost Peaks. The cable car pad stands in Redwood Coast, below its station.
	{"id": "r5_cablecar", "cost": 190000, "req": ["r4_lighthouse"], "title": "Cable Car to Frost Peaks", "pad": Vector3(47, 0, -40.0)},
	# Frost Peaks opening cut 2026-10-04 (kiln 230K, grove2 170K, office 180K, jack1 250K, ski lodge
	# 280K): nothing sells before the Ski Lodge, so the first 8.3 min were 61-99% waiting.
	{"id": "r5_kiln", "cost": 80000, "req": ["r5_cablecar"], "title": "Drying Kiln", "pad": Vector3(40, 0, -66)},
	{"id": "r5_grove2", "cost": 60000, "req": ["r5_kiln"], "title": "More Frost Firs", "pad": Vector3(30, 0, -76)},
	{"id": "r5_office", "cost": 70000, "req": ["r5_kiln"], "title": "Mountain Office", "pad": Vector3(35, 0, -58.4)},
	{"id": "r5_jack1", "cost": 90000, "req": ["r5_grove2"], "title": "Hire a Mountain Lumberjack", "pad": Vector3(32, 0, -70.5)},
	{"id": "r5_skilodge", "cost": 110000, "req": ["r5_jack1"], "title": "Ski Lodge Shop", "pad": Vector3(60, 0, -62)},
	{"id": "r5_skiworks", "cost": 320000, "req": ["r5_skilodge"], "title": "Ski Workshop", "pad": Vector3(48, 0, -76)},
	{"id": "r5_cashier", "cost": 330000, "req": ["r5_skiworks"], "title": "Ski Lodge Cashier", "pad": Vector3(56.5, 0, -70)},
	{"id": "r5_jack2", "cost": 380000, "req": ["r5_cashier"], "title": "Hire 2 Lumberjacks + North Firs", "pad": Vector3(31, 0, -101)},
	{"id": "r5_kiln2", "cost": 400000, "req": ["r5_jack2"], "title": "Second Kiln", "pad": Vector3(40, 0, -82)},
	{"id": "r5_belt_ks", "cost": 410000, "req": ["r5_kiln2"], "title": "Conveyor: Kilns to Ski Workshop", "pad": Vector3(46, 0, -70)},
	{"id": "r5_sledshop", "cost": 450000, "req": ["r5_belt_ks"], "title": "Sled Workshop", "pad": Vector3(56, 0, -88)},
	{"id": "r5_snowcat", "cost": 460000, "req": ["r5_sledshop"], "title": "Hire a Snowcat", "pad": Vector3(51, 0, -82)},
	{"id": "r5_luthier", "cost": 650000, "req": ["r5_snowcat"], "title": "Luthier Workshop: Guitars", "pad": Vector3(52, 0, -98)},
	{"id": "r5_express_r5", "cost": 670000, "req": ["r5_luthier"], "title": "Express Platform: Guitars", "pad": Vector3(70, 0, -80)},
	{"id": "r5_belt_sl", "cost": 740000, "req": ["r5_express_r5"], "title": "Conveyors: Sleds + Guitars", "pad": Vector3(62, 0, -92)},
	{"id": "r5_jack3", "cost": 770000, "req": ["r5_belt_sl"], "title": "Hire 3 Lumberjacks + Far Firs", "pad": Vector3(62, 0, -109)},
	{"id": "r5_kiln3", "cost": 940000, "req": ["r5_jack3"], "title": "Third Kiln", "pad": Vector3(40, 0, -98)},
	{"id": "r5_observatory", "cost": 1200000, "req": ["r5_kiln3"], "title": "Build the Summit Observatory", "pad": Vector3(68, 0, -113)},
	# ---- Grand Timber Station (finale). Pad in Home Valley by the Highland Gate, not in the gate
	# corridor at (0, -52): standing there would pay into it on every walk between the valleys.
	{"id": "cap_station", "cost": 1200000, "req": ["r5_observatory"], "title": "Grand Timber Station", "pad": Vector3(5.5, 0, -42.6)},
]
## Pads drawn at the large 3.2 m size.
const BIG_PADS := [
	"carpentry", "sawmill2", "cnc", "factory", "dock", "lodge", "office",
	"r2_bridge", "r2_lathe", "r2_office", "r2_press", "r2_press2", "r2_boatshop", "r2_barge", "r2_boathouse",
	"r3_gate", "r3_beamsaw", "r3_office", "r3_planer", "r3_kitfactory", "r3_rail",
	"r3_house1", "r3_house2", "r3_house3", "r3_house4", "r3_house5", "r3_clocktower",
	"r4_crossing", "r4_redmill", "r4_office", "r4_decksaw", "r4_mastlathe", "r4_slipway", "r4_orders", "r4_slipway2", "r4_lighthouse",
	"r5_cablecar", "r5_kiln", "r5_office", "r5_skilodge", "r5_skiworks", "r5_kiln2", "r5_sledshop", "r5_luthier", "r5_express_r5",
	"r5_kiln3", "r5_observatory", "cap_station",
]
## Landmarks that finish a valley and show the "Valley complete" card. A landmark that is a build
## site (the Clock Tower) shows it when the building is finished, not when its pad is paid.
const LANDMARKS := {"lodge": 1, "r2_boathouse": 2, "r3_clocktower": 3, "r4_lighthouse": 4, "r5_observatory": 5}
## Valley gateways: the pad that opens the next valley (later gates go here too). Outside the
## tutorials the guide arrow always points at an unpaid gateway, affordable or not.
## "gate" = the closed gate in the valley wall that glows; "path" = the route the glow takes
## into the new valley once the gateway is paid; "along" = the axis the closed gate spans;
## "arch_h" = height of the gold arch over the pad (default 3.0; lower where it would hide a gate sign).
const GATEWAYS := {
	"r2_bridge": {"region": 2, "gate": Vector3(-23.2, 0, -6), "along": "z", "path": [Vector3(-20.5, 0, -6), Vector3(-30.2, 0, -6), Vector3(-41.0, 0, -6)]},
	"r3_gate": {"region": 3, "gate": Vector3(0, 0, -46.6), "along": "x", "arch_h": 2.0, "path": [Vector3(0, 0, -42.4), Vector3(0, 0, -52.0), Vector3(0, 0, -60.0)]},
	"r4_crossing": {"region": 4, "gate": Vector3(19.2, 0, -20), "along": "z", "path": [Vector3(13.0, 0, -19.5), Vector3(17.0, 0, -20.0), Vector3(21.0, 0, -20.0), Vector3(27.0, 0, -20.0)]},
	"r5_cablecar": {"region": 5, "gate": Vector3(47, 0, -45.6), "along": "x", "path": [Vector3(47, 0, -40.0), Vector3(47, 0, -50.0), Vector3(47, 0, -59.0)]},
	"cap_station": {"region": 1, "gate": Vector3(0, 0, -46.6), "along": "x", "arch_h": 2.4, "path": [Vector3(5.5, 0, -42.6), Vector3(1.0, 0, -45.0), Vector3(0, 0, -52.0)]},
}
## Ship launches, cargo orders and the finale (GDD 7.7): money counts toward the valley ledger.
## The Grand Timber Station (ASSETS_M5.md 1.1): a through-station at (0, -52) over the rail line
## at z -51; its walk-through arches (x -1.4..1.4) replace the Highland Gate once it is bought
## (designer option A).
const STATION := {"pos": Vector3(0, 0, -52), "rail_z": -51.0, "rail_x": [-75.0, 75.0], "express_s": 12.0}
