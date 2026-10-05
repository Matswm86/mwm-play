extends Node

## MWM Play shell (autoload "Shell"). Owns settings, screen changes, game
## launch and return, the in-game home button, Android back, game autoload
## parking and the parent play limit. See docs/MERGE_PLAN.md section 3 and
## docs/DESIGN.md section 2.

const SETTINGS_PATH := "user://mwm_play_settings.json"
const SCREENS := {
	"start": "res://shell/screens/Launcher.tscn",
	"gate": "res://shell/screens/Gate.tscn",
	"parent": "res://shell/screens/ParentArea.tscn",
	"licences": "res://shell/screens/Licences.tscn",
	"privacy": "res://shell/screens/Privacy.tscn",
	"tips": "res://shell/screens/Tips.tscn",
	"done": "res://shell/screens/DoneForNow.tscn",
}
## Games integrated in this build, in tile order. Cards exist only for these.
const GAMES := ["ball-connect", "water-sort", "spotless", "timber-valley"]
## Ignore every touch for this long after a screen change (rule 8).
const HOLDOVER_MS: int = 300
const CROSSFADE_S: float = 0.18
## Music sits at least 6 dB under effects (DESIGN 3, rule 33).
const MUSIC_DB: float = -6.0
## Used play time resets after the app has been closed this long (DESIGN 2f).
const LIMIT_RESET_S: int = 3600
## Seconds the level-complete screen stays up before "done for now".
const STOP_DELAY_S: float = 1.5
const PERSIST_EVERY_S: float = 10.0


class Settings:
	var sound: bool = true
	var music: bool = true
	var vibration: bool = false  # rule 33: haptics off by default
	var less_motion: bool = false
	var limit_minutes: int = 0
	var used_seconds: float = 0.0
	var last_active_unix: int = 0

	func to_dict() -> Dictionary:
		return {
			"version": 1,
			"sound": sound,
			"music": music,
			"vibration": vibration,
			"less_motion": less_motion,
			"limit_minutes": limit_minutes,
			"used_seconds": used_seconds,
			"last_active_unix": last_active_unix,
		}

	func from_dict(d: Dictionary) -> void:
		sound = bool(d.get("sound", sound))
		music = bool(d.get("music", music))
		vibration = bool(d.get("vibration", vibration))
		less_motion = bool(d.get("less_motion", less_motion))
		var lim: int = int(d.get("limit_minutes", 0))
		limit_minutes = lim if lim in [0, 15, 30, 45, 60] else 0
		used_seconds = maxf(0.0, float(d.get("used_seconds", 0.0)))
		last_active_unix = int(d.get("last_active_unix", 0))


var settings := Settings.new()
var adapters: Dictionary = {}  # slug -> ShellAdapter
var screen_arg: String = ""
var current_screen: String = "start"
var active_game: String = ""

var _parked: Dictionary = {}  # autoload name -> Node
var _changed_at: int = 0
var _home_layer: CanvasLayer
var _home: ShellHomeButton
var _fade_layer: CanvasLayer
var _fade_rect: TextureRect
var _tok: AudioStreamPlayer
var _pling: AudioStreamPlayer
var _stop_timer: float = -1.0
var _persist_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_setup_buses()
	_setup_sounds()
	for slug in GAMES:
		var a: ShellAdapter = load("res://shell/adapters/%s.gd" % slug).new()
		adapters[slug] = a
	_build_home_overlay()
	_build_fade_layer()
	_changed_at = Time.get_ticks_msec()
	# Game autoloads run their _ready at app start; park them after one frame
	# so no game music, autosave or bus mute runs on the start screen.
	await get_tree().process_frame
	_park_all()
	AudioServer.set_bus_mute(0, false)
	if limit_reached():
		goto("done", "", false)


# ---------------------------------------------------------------- settings


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f != null:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				settings.from_dict(json.data)
			else:
				push_warning("MWM Play settings unreadable, using defaults")
	var now := int(Time.get_unix_time_from_system())
	if settings.last_active_unix > 0 and now - settings.last_active_unix > LIMIT_RESET_S:
		settings.used_seconds = 0.0
	settings.last_active_unix = now


func save_settings() -> void:
	settings.last_active_unix = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("MWM Play settings not saved: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(settings.to_dict(), "  "))
	f.close()
	apply_audio_settings()


func reset_settings() -> void:
	settings = Settings.new()
	save_settings()


func limit_reached() -> bool:
	return settings.limit_minutes > 0 and settings.used_seconds >= settings.limit_minutes * 60.0


func reset_used_time() -> void:
	settings.used_seconds = 0.0
	save_settings()


# ---------------------------------------------------------------- audio


func _setup_buses() -> void:
	for bus_name in ["Sfx", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), MUSIC_DB)
	apply_audio_settings()


func apply_audio_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sfx"), not settings.sound)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not settings.music)


func _setup_sounds() -> void:
	_tok = _make_player(_synth([[520.0, 1.0], [910.0, 0.5]], 0.07, 60.0, 0.125))
	_pling = _make_player(_synth([[1568.0, 1.0], [3136.0, 0.25]], 0.35, 9.0, 0.1))


func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Sfx"
	add_child(p)
	return p


## Short decaying tone made in code; peak amplitude 0.125 is about -18 dBFS.
func _synth(partials: Array, length: float, decay: float, peak: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(length * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for p in partials:
			v += sin(TAU * float(p[0]) * t) * float(p[1])
		v *= peak * exp(-decay * t) * minf(1.0, t * 2000.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


## Touch-down sound on any shell control (DESIGN 3, rule 19).
func play_tok() -> void:
	_tok.play()


func play_pling() -> void:
	_pling.play()


# ---------------------------------------------------------------- screens


func goto(screen: String, arg: String = "", fade: bool = true) -> void:
	screen_arg = arg
	current_screen = screen
	_change_scene(SCREENS[screen], fade)


func _change_scene(path: String, fade: bool) -> void:
	if fade and not settings.less_motion:
		var img := get_viewport().get_texture().get_image()
		_fade_rect.texture = ImageTexture.create_from_image(img)
		_fade_rect.modulate.a = 1.0
		_fade_rect.visible = true
		var tw := create_tween()
		tw.tween_interval(0.03)
		tw.tween_property(_fade_rect, "modulate:a", 0.0, CROSSFADE_S)
		tw.tween_callback(func() -> void: _fade_rect.visible = false)
	_changed_at = Time.get_ticks_msec()
	get_tree().change_scene_to_file(path)


func _build_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 110
	add_child(_fade_layer)
	_fade_rect = TextureRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)


func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _changed_at >= HOLDOVER_MS:
		return
	if (
		event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventMouseButton
	):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Arrives while the notification walks the whole tree; changing scene
			# inside that walk fails, so handle it right after.
			_on_back.call_deferred()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			save_settings()
		NOTIFICATION_APPLICATION_RESUMED:
			var now := int(Time.get_unix_time_from_system())
			if now - settings.last_active_unix > LIMIT_RESET_S:
				settings.used_seconds = 0.0


## Android back (button or edge swipe). In a game it does exactly what a home
## tap does, guard included (DESIGN 2b); shell screens go up one level.
func _on_back() -> void:
	if active_game != "":
		_home.trigger()
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("on_back"):
		scene.call("on_back")


## Start screen back: the app goes to the background, nothing is lost.
func send_to_background() -> void:
	save_settings()
	if Engine.has_singleton("AndroidRuntime"):
		var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
		if activity != null:
			activity.call("moveTaskToBack", true)
			return
	get_tree().quit()


# ---------------------------------------------------------------- games


func _build_home_overlay() -> void:
	_home_layer = CanvasLayer.new()
	_home_layer.layer = 100
	add_child(_home_layer)
	_home = ShellHomeButton.new()
	_home.guard = true
	_home.leave_requested.connect(leave_game)
	_home_layer.add_child(_home)
	_home_layer.visible = false


func launch(slug: String) -> void:
	if active_game != "" or not adapters.has(slug):
		return
	var a: ShellAdapter = adapters[slug]
	active_game = slug
	_stop_timer = -1.0
	for name in a.autoloads:
		_unpark(name)
	AudioServer.set_bus_mute(0, false)
	get_tree().node_added.connect(_route_audio)
	a.enter(settings)
	var root := get_tree().root
	root.msaa_3d = a.msaa_3d
	root.content_scale_aspect = a.aspect
	RenderingServer.set_default_clear_color(a.clear_color)
	_home.reset_guard()
	_home_layer.visible = true
	current_screen = "game"
	_change_scene(a.main_scene, true)


## Leaves the running game: save, park its autoloads, restore shell settings.
func leave_game() -> void:
	if active_game == "":
		return
	var a: ShellAdapter = adapters[active_game]
	var game := get_tree().current_scene
	if game != null:
		a.exit(game)
	for name in a.autoloads:
		_park(name)
	if get_tree().node_added.is_connected(_route_audio):
		get_tree().node_added.disconnect(_route_audio)
	Engine.time_scale = 1.0
	get_tree().paused = false
	AudioServer.set_bus_mute(0, false)
	apply_audio_settings()
	var root := get_tree().root
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	RenderingServer.set_default_clear_color(ShellUi.PAPER)
	_home_layer.visible = false
	_home.reset_guard()
	active_game = ""
	save_settings()
	goto("done" if limit_reached() else "start")


func _route_audio(node: Node) -> void:
	if active_game == "":
		return
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.set("bus", adapters[active_game].bus_for(node))


func _park_all() -> void:
	for a in adapters.values():
		for name in a.autoloads:
			_park(name)


func _park(name: String) -> void:
	var node := get_tree().root.get_node_or_null(NodePath(name))
	if node != null and node != self:
		get_tree().root.remove_child(node)
		_parked[name] = node


## Parked autoloads are outside the tree, so the engine would not free them
## at quit (leaked music streams in the log).
func _exit_tree() -> void:
	for node in _parked.values():
		(node as Node).free()
	_parked.clear()


func _unpark(name: String) -> void:
	if _parked.has(name):
		get_tree().root.add_child(_parked[name])
		_parked.erase(name)


## Every AudioStreamPlayer in the tree that is playing right now (test hook).
func playing_players() -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == self:
			continue
		if (
			(n is AudioStreamPlayer or n is AudioStreamPlayer2D or n is AudioStreamPlayer3D)
			and n.get("playing")
		):
			out.append(n)
		stack.append_array(n.get_children())
	return out


func _process(delta: float) -> void:
	if active_game == "":
		return
	settings.used_seconds += delta
	_persist_timer += delta
	if _persist_timer >= PERSIST_EVERY_S:
		_persist_timer = 0.0
		save_settings()
	if not limit_reached():
		return
	# Play limit: stop only at the next natural stopping point, never with a
	# countdown (rules 26, 27, 29).
	var game := get_tree().current_scene
	if _stop_timer < 0.0:
		if game != null and adapters[active_game].is_at_stopping_point(game):
			_stop_timer = STOP_DELAY_S
	else:
		_stop_timer -= delta
		if _stop_timer <= 0.0:
			_stop_timer = -1.0
			leave_game()
