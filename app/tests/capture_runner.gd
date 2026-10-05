extends Node

## Dev-only screenshot bot for the shell. Walks: start -> Ball Connect ->
## home (two taps) -> start -> Water Sort -> Android back (twice) -> start ->
## Timber Valley (joystick vs home tap, earn money) -> home -> Water Sort ->
## home -> Timber Valley again (money and offline earnings kept) -> start ->
## Spotless (finish an object, win card) -> home -> Timber Valley -> home ->
## Spotless again (level kept, own sound-off setting kept, Master unmuted) ->
## gear -> gate -> wrong code -> right code -> parent area -> licences, then
## checks saved progress and the play-limit stop. Taps are real touch events;
## Android back is the real window notification. Run under Xvfb with
## CAPTURE_DIR set. Wipes this app's own test saves at start.

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var n_shot: int = 0


func _ready() -> void:
	get_tree().create_timer(500.0).timeout.connect(func() -> void:
		print("CAPTURE TIMEOUT after 500 s")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	for f in [
		"mwm_play_settings.json",
		"water-sort_save.cfg",
		"ball_connect_save.json",
		"timber_valley_save.json",
		"spotless_save.json",
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	# Seed Ball Connect at old level 3 (save v1) to prove the merged game reads
	# its own save; v2 renumbering maps it to level 6.
	var seed := FileAccess.open("user://ball_connect_save.json", FileAccess.WRITE)
	seed.store_string('{"version": 1, "current_level": 3, "highest_level": 3}')
	seed.close()
	# Seed Timber Valley: $5000 and a valley earning $10/s, saved one hour ago,
	# so the first enter pays 3600 s x $10 x 50% = $18000 offline, once.
	var tv := FileAccess.open("user://timber_valley_save.json", FileAccess.WRITE)
	tv.store_string(JSON.stringify({
		"version": 4, "money": 5000, "total_earned": 5000, "ledger": {"2": 10.0},
		"saved_at": int(Time.get_unix_time_from_system()) - 3600,
	}))
	tv.close()
	# Seed Spotless at level 2 with its own sound switch off (set standalone):
	# inside the shell that switch is hidden and must not mute anything.
	var sp := FileAccess.open("user://spotless_save.json", FileAccess.WRITE)
	sp.store_string('{"level": 2, "sound": false, "music": true}')
	sp.close()
	Shell.reset_settings()

	Shell.goto("start", "", false)
	await _wait(0.8)
	_music_check("start screen at boot")
	await _shot("start")

	# ---- Ball Connect: launch from the card, play one pair, leave with two taps
	await _tap(_center(_scene().tiles["ball-connect"]))
	await _wait(1.5)
	print("SCENE ", _scene().scene_file_path, "  level: ", _scene().current_level)
	await _shot("ball_connect")
	await _play_ball_connect_pair()
	await _shot("ball_connect_played")
	await _tap(Vector2(104, 104))
	await _wait(0.7)
	print("GUARD active after first home tap: ", Shell._home.guard_active())
	print("  scene: ", _scene().name)
	await _shot("ball_connect_home_guard")
	await _tap(Vector2(104, 104))
	await _wait(0.9)
	print("AFTER second home tap: screen=", Shell.current_screen, " scene=", _scene().name)
	_print_file("user://ball_connect_save.json")
	_music_check("start screen after Ball Connect")
	await _shot("start_after_ball_connect")

	# ---- Water Sort: launch, solve a level, leave with Android back twice
	await _tap(_center(_scene().tiles["water-sort"]))
	await _wait(1.5)
	var ws: Node = _scene()
	print("SCENE ", ws.scene_file_path, "  level label: ", ws.level_label.text)
	for p in Shell.playing_players():
		var path: String = p.get("stream").resource_path
		print("  playing in game: ", p.name, " stream=", path, " bus=", p.get("bus"))
	await _shot("water_sort")
	await _solve_water_sort(ws)
	await _wait(1.6)
	await _shot("water_sort_won")
	var next_btn: Control = ws.btn_next
	await _tap(_center(next_btn))
	await _wait(0.6)
	print("WATER SORT after Next: ", ws.level_label.text)
	_back()
	await _wait(0.7)
	print("GUARD active after first back: ", Shell._home.guard_active(), "  scene: ", _scene().name)
	await _shot("water_sort_back_guard")
	_back()
	await _wait(0.9)
	print("AFTER second back: screen=", Shell.current_screen, " scene=", _scene().name)
	_print_file("user://water-sort_save.cfg")
	_music_check("start screen after Water Sort")
	await _shot("start_after_water_sort")

	await _timber_round_trip()
	await _spotless_round_trip()

	# ---- Parent gate and parent area
	await _tap(_center(_scene().adult_corner))
	await _wait(0.8)
	var gate: Node = _scene()
	print("GATE code: ", gate.code, " shown as: ", gate._code_label.text)
	await _shot("gate")
	var wrong: Array = gate.code.duplicate()
	wrong.reverse()
	for d in wrong:
		await _tap(_center(gate.keys[str(d)]))
		await _wait(0.15)
	await _wait(0.4)
	print("GATE after wrong code: screen=", Shell.current_screen, " new code: ", gate.code)
	print("  hint: ", gate._hint.text)
	await _shot("gate_wrong_new_code")
	await _tap(_center(gate.keys[str(gate.code[0])]))
	await _wait(0.2)
	await _shot("gate_one_digit")
	for d in gate.code.slice(1):
		await _tap(_center(gate.keys[str(d)]))
		await _wait(0.15)
	await _wait(0.9)
	var parent: Node = _scene()
	print("AFTER right code: screen=", Shell.current_screen)
	await _tap(_center(parent.rows["limit_30"]))
	await _wait(0.3)
	await _shot("parent_area")
	await _tap(_center(parent.rows["less_motion"]))
	await _wait(0.3)
	_print_file("user://mwm_play_settings.json")
	await _tap(_center(parent.rows["less_motion"]))
	await _tap(_center(parent.rows["limit_0"]))
	await _tap(_center(parent.rows["unlock"]))
	await _wait(0.3)
	print("UNLOCK stub status visible: ", parent._status.visible, " text: ", parent._status.text)
	await _shot("parent_area_unlock_stub")
	parent.scroll.scroll_vertical = 100000
	await _wait(0.4)
	await _shot("parent_area_bottom")
	await _tap(_center(parent.rows["licences"]))
	await _wait(1.2)
	var lic: Node = _scene()
	print("LICENCES screen=", Shell.current_screen, " paragraphs: ", lic.body.get_child_count())
	await _shot("licences")
	for l in lic.body.get_children():
		if l is Label and (l as Label).text == "Fonts":
			lic.scroll.scroll_vertical = int(l.position.y) - 20
	await _wait(0.4)
	await _shot("licences_fonts")
	_back()
	await _wait(0.8)
	print("BACK from licences: screen=", Shell.current_screen)
	_back()
	await _wait(0.8)
	print("BACK from parent area: screen=", Shell.current_screen)

	# ---- Progress kept: relaunch both games
	await _tap(_center(_scene().tiles["ball-connect"]))
	await _wait(1.5)
	print("RELAUNCH Ball Connect level: ", _scene().current_level)
	await _shot("ball_connect_relaunch")
	await _tap(Vector2(104, 104))
	await _wait(0.5)
	await _tap(Vector2(104, 104))
	await _wait(0.9)
	await _tap(_center(_scene().tiles["water-sort"]))
	await _wait(1.5)
	print("RELAUNCH Water Sort level label: ", _scene().level_label.text)
	await _shot("water_sort_relaunch")

	# ---- Play limit: used up, so the game stops after the next level complete
	Shell.settings.limit_minutes = 15
	Shell.settings.used_seconds = 15 * 60.0 + 1.0
	await _solve_water_sort(_scene())
	await _wait(3.0)
	print("PLAY LIMIT: screen=", Shell.current_screen, " scene=", _scene().name)
	_music_check("done-for-now screen")
	await _shot("done_for_now")

	Shell.reset_settings()
	print("CAPTURE DONE, ", n_shot, " shots")
	get_tree().quit()


# ---------------------------------------------------------------- Timber Valley


func _timber_round_trip() -> void:
	await _tap(_center(_scene().tiles["timber-valley"]))
	await _wait(3.0)
	print("SCENE ", _scene().scene_file_path)
	_timber_state("TIMBER first enter")
	for p in Shell.playing_players():
		var sp: String = p.get("stream").resource_path
		print("  playing in game: ", p.name, " stream=", sp, " bus=", p.get("bus"))
	print("  msaa_3d=", get_tree().root.msaa_3d, " meta=", Engine.get_meta(&"mwm_play_shell", false))
	await _shot("timber")

	# Joystick probe. Control: a touch in open grass starts the joystick.
	var hud: Node = TimberGame.hud
	await _touch(Vector2(540, 1300), true)
	print("JOY control touch (540,1300): ", _joy(hud))
	await _shot("timber_joystick_control")
	await _touch(Vector2(540, 1300), false)
	print("JOY after release: ", _joy(hud))
	await _wait(0.5)
	# The home disc: first tap starts the guard and must never start the joystick.
	await _touch(Vector2(104, 104), true)
	print("JOY during home press (104,104): ", _joy(hud))
	await _touch(Vector2(104, 104), false)
	print("HOME guard active=", Shell._home.guard_active(), "  JOY after home tap: ", _joy(hud))
	await _shot("timber_home_guard")
	TimberGame.add_money(250, 1)
	print("TIMBER earned 250 in game: money=", TimberGame.money)
	await _wait(0.5)
	# The shot above can take longer than the 2 s guard on a busy laptop; the
	# guard was proven above, so re-arm it instead of failing the whole walk.
	if not Shell._home.guard_active():
		print("  guard expired during the shot; re-arming")
		await _tap(Vector2(104, 104))
		await _wait(0.3)
	await _tap(Vector2(104, 104))
	await _wait(1.0)
	print("AFTER Timber home: screen=", Shell.current_screen, " scene=", _scene().name)
	print("  parked: ", Shell._parked.keys(), " in tree: ", TimberGame.is_inside_tree())
	print("  refs nulled: ", [TimberGame.world, TimberGame.player, TimberGame.hud])
	print("  msaa_3d=", get_tree().root.msaa_3d, " meta=", Engine.has_meta(&"mwm_play_shell"))
	_print_file("user://timber_valley_save.json")
	_music_check("start screen after Timber Valley")

	await _tap(_center(_scene().tiles["water-sort"]))
	await _wait(1.5)
	print("WATER SORT between Timber visits: ", _scene().level_label.text)
	_music_check("Water Sort after Timber (no Timber music)")
	await _shot("water_sort_after_timber")
	await _tap(Vector2(104, 104))
	await _wait(0.5)
	await _tap(Vector2(104, 104))
	await _wait(1.0)

	await _tap(_center(_scene().tiles["timber-valley"]))
	await _wait(3.0)
	_timber_state("TIMBER re-enter")
	var refs: Array[bool] = []
	for r in [TimberGame.world, TimberGame.player, TimberGame.hud]:
		refs.append(is_instance_valid(r))
	print("  refs set again (world, player, hud): ", refs)
	await _shot("timber_reenter")
	await _tap(Vector2(104, 104))
	await _wait(0.5)
	await _tap(Vector2(104, 104))
	await _wait(1.0)
	print("AFTER second Timber home: screen=", Shell.current_screen)
	_music_check("start screen after Timber again")
	await _shot("start_after_timber")


# ---------------------------------------------------------------- Spotless


func _spotless_round_trip() -> void:
	await _tap(_center(_scene().tiles["spotless"]))
	await _wait(3.0)
	_spotless_state("SPOTLESS first enter")
	await _shot("spotless")
	# Dev shortcut: finish the current object, which shows the win card (the
	# play-limit stopping point) and saves the next level.
	_scene().call("_complete")
	await _wait(2.0)
	print("  stopping point: ", Shell.adapters["spotless"].is_at_stopping_point(_scene()))
	_spotless_state("SPOTLESS after win")
	await _shot("spotless_win")
	await _tap(Vector2(104, 104))
	await _wait(0.5)
	await _tap(Vector2(104, 104))
	await _wait(1.0)
	print("AFTER Spotless home: screen=", Shell.current_screen, " scene=", _scene().name)
	print("  parked: ", Shell._parked.keys(), " in tree: ", SpotlessGame.is_inside_tree())
	print("  msaa_3d=", get_tree().root.msaa_3d, " meta=", Engine.has_meta(&"mwm_play_shell"))
	_print_file("user://spotless_save.json")
	_music_check("start screen after Spotless")

	await _tap(_center(_scene().tiles["timber-valley"]))
	await _wait(3.0)
	_music_check("Timber after Spotless (no Spotless music)")
	await _shot("timber_after_spotless")
	await _tap(Vector2(104, 104))
	await _wait(0.5)
	await _tap(Vector2(104, 104))
	await _wait(1.0)
	_music_check("start screen after Timber, before Spotless again")

	await _tap(_center(_scene().tiles["spotless"]))
	await _wait(3.0)
	_spotless_state("SPOTLESS re-enter")
	await _shot("spotless_reenter")
	await _tap(Vector2(104, 104))
	await _wait(0.5)
	await _tap(Vector2(104, 104))
	await _wait(1.0)
	print("AFTER second Spotless home: screen=", Shell.current_screen)
	_music_check("start screen after Spotless again")
	await _shot("start_after_spotless")


func _spotless_state(tag: String) -> void:
	var g: Node = SpotlessGame
	var main: Node = _scene()
	var hud: Node = main.get("hud")
	print(
		tag, ": scene=", main.scene_file_path, " Game.level=", g.level,
		" Main.level_index=", main.get("level_index"), " state=", main.get("state"),
		" sound_on=", g.sound_on, " music_on=", g.music_on,
	)
	print(
		"  in_shell=", g.in_shell(), " Master muted=", AudioServer.is_bus_mute(0),
		" sound/music buttons visible=", [hud.sound_btn.visible, hud.music_btn.visible],
		" msaa_3d=", get_tree().root.msaa_3d,
	)
	for p in Shell.playing_players():
		print("  playing in game: ", p.get_path(), " stream=", p.get("stream").resource_path,
			" bus=", p.get("bus"))


func _timber_state(tag: String) -> void:
	var g: Node = TimberGame
	print(tag, ": money=", g.money, " offline_pending=", g.offline_pending, " total=", g.total_earned)


func _joy(hud: Node) -> String:
	return "active=%s visible=%s" % [hud._touch_index != -1, hud.joy_base.visible]


# ---------------------------------------------------------------- helpers


func _touch(p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = pressed
	ev.position = p
	Input.parse_input_event(ev)
	await _frames(3)


func _scene() -> Node:
	return get_tree().current_scene


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _tap(p: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = p
	Input.parse_input_event(down)
	await _frames(3)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = p
	Input.parse_input_event(up)
	await _frames(2)


func _back() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)


func _music_check(where: String) -> void:
	var playing := Shell.playing_players()
	var names: Array[String] = []
	for p in playing:
		names.append(str(p.get_path()))
	print("MUSIC CHECK (%s): %d players playing %s" % [where, playing.size(), names])


func _print_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	print("FILE ", path, ": ", f.get_as_text().replace("\n", " ") if f else "(missing)")


func _play_ball_connect_pair() -> void:
	var game: Node = _scene()
	var board: Node3D = game.get_node("Board3D")
	var cam: Camera3D = get_viewport().get_camera_3d()
	var pts: Array[Vector2] = []
	# Level 6 (seeded save): the red pair is one straight line along the top.
	for px in [Vector2(280, 380), Vector2(540, 380), Vector2(800, 380)]:
		pts.append(cam.unproject_position(board.px_to_world(px, board.TUBE_HEIGHT)))
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = pts[0]
	Input.parse_input_event(down)
	await _frames(2)
	for i in pts.size() - 1:
		for k in range(1, 21):
			var ev := InputEventScreenDrag.new()
			ev.position = pts[i].lerp(pts[i + 1], k / 20.0)
			Input.parse_input_event(ev)
			await _frames(1)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = pts[2]
	Input.parse_input_event(up)
	await _frames(20)
	print("BALL CONNECT pairs completed: ", game.line_drawer.completed_pair_count())


func _solve_water_sort(game: Node) -> void:
	var moves: Variant = WsPuzzle.solve(game.tubes)
	for m in moves:
		while game.bottles[m[0]].busy or game.bottles[m[1]].busy:
			await _frames(1)
		game.tap(m[0])
		await _frames(3)
		game.tap(m[1])
	while game._any_busy():
		await _frames(1)
	await _frames(10)
	var solved := WsPuzzle.is_solved(game.tubes)
	print("WATER SORT solved: ", solved, " won: ", game.won, " moves: ", moves.size())


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	n_shot += 1
	await RenderingServer.frame_post_draw
	var path := "%s/%02d_%s.png" % [out_dir, n_shot, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
