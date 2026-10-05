extends Node

## Dev-only screenshot bot for the shell. Walks: start -> Ball Connect ->
## home (two taps) -> start -> Water Sort -> Android back (twice) -> start ->
## gear -> gate -> wrong code -> right code -> parent area -> licences, then
## checks saved progress and the play-limit stop. Taps are real touch events;
## Android back is the real window notification. Run under Xvfb with
## CAPTURE_DIR set. Wipes this app's own test saves at start.

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var n_shot: int = 0


func _ready() -> void:
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		print("CAPTURE TIMEOUT after 180 s")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	for f in ["mwm_play_settings.json", "water-sort_save.cfg", "ball_connect_save.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	# Seed Ball Connect at level 3 to prove the merged game reads its own save.
	var seed := FileAccess.open("user://ball_connect_save.json", FileAccess.WRITE)
	seed.store_string('{"version": 1, "current_level": 3, "highest_level": 3}')
	seed.close()
	Shell.reset_settings()

	Shell.goto("start", "", false)
	await _wait(0.8)
	_music_check("start screen at boot")
	await _shot("start")

	# ---- Ball Connect: launch from the card, play one pair, leave with two taps
	await _tap(_center(_scene().tiles["ball-connect"]))
	await _wait(1.5)
	print("SCENE ", _scene().scene_file_path, "  level label: ", _scene().level_label.text)
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
	var next_btn: Control = ws.win_panel.find_children("*", "Button", true, false)[0]
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
	print("RELAUNCH Ball Connect level label: ", _scene().level_label.text)
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


# ---------------------------------------------------------------- helpers


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
	# Level 3 (seeded save): the red pair is one straight line along the top.
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
