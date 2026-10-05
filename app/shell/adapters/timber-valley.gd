extends ShellAdapter

## Timber Valley: autoloads TimberGame and TimberSfx, parked by the shell while
## the game is closed (no music, no 8 s autosave on other screens). Saves to
## user://timber_valley_save.json: every 8 s while playing, on pause, and once
## more here on exit. Offline earnings count from the save's saved_at, so
## calling load_game() on every enter pays time away exactly once (upstream
## tests/reentry_test.tscn). Its own menu (start over, sound, music) is hidden
## in the shell through the Engine meta below, so reload_current_scene() is
## never reached from here.

const SHELL_META := &"mwm_play_shell"
const SHADOW_SETTING := "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
## Timber's own project uses soft shadow quality 2 on phones.
const SOFT_SHADOWS := RenderingServer.SHADOW_QUALITY_SOFT_LOW
## Play limit stopping point (DESIGN.md open item 2, provisional until the
## game-designer decides): the next purchase, or this long after the limit.
const LIMIT_GRACE_MS: int = 5 * 60 * 1000

var _shell_shadows: int = 0
var _limit_seen_ms: int = -1
var _bought_since_limit: bool = false


func _init() -> void:
	slug = "timber-valley"
	title = "Timber Valley"
	main_scene = "res://games/timber-valley/scenes/Main.tscn"
	tile_art = "res://shell/tiles/timber-valley.png"
	autoloads = PackedStringArray(["TimberGame", "TimberSfx"])
	msaa_3d = Viewport.MSAA_2X
	clear_color = Color(0.55, 0.75, 0.85)
	tip = "La barnet bestemme hva dere kjøper neste gang, og spør hvorfor."


## The shell has re-added TimberGame and TimberSfx to /root before this runs.
func enter(_settings: Object) -> void:
	Engine.set_meta(SHELL_META, true)
	_clear_scene_refs()
	TimberGame.load_game()
	# Re-adding an AudioStreamPlayer does not restart it; with the meta set the
	# game always plays and the shell buses decide what is heard.
	for p in TimberSfx.get_children():
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).bus = bus_for(p)
	TimberSfx.apply_sound_setting()
	_shell_shadows = int(ProjectSettings.get_setting_with_override(SHADOW_SETTING))
	RenderingServer.directional_soft_shadow_filter_set_quality(SOFT_SHADOWS)
	_limit_seen_ms = -1
	_bought_since_limit = false
	if not TimberGame.money_changed.is_connected(_on_money_changed):
		TimberGame.money_changed.connect(_on_money_changed)


## Final save while the scene's coin piles still exist, then drop references to
## nodes that are freed with the scene. The shell parks the autoloads after this.
func exit(game: Node) -> void:
	TimberGame.save_game()
	super.exit(game)
	if TimberGame.money_changed.is_connected(_on_money_changed):
		TimberGame.money_changed.disconnect(_on_money_changed)
	_clear_scene_refs()
	Engine.remove_meta(SHELL_META)
	RenderingServer.directional_soft_shadow_filter_set_quality(_shell_shadows)


func _clear_scene_refs() -> void:
	TimberGame.world = null
	TimberGame.player = null
	TimberGame.hud = null


func _on_money_changed(_value: int, delta: int) -> void:
	if delta < 0 and _limit_seen_ms >= 0:
		_bought_since_limit = true


## Asked every frame once the play limit is reached.
func is_at_stopping_point(_game: Node) -> bool:
	if _limit_seen_ms < 0:
		_limit_seen_ms = Time.get_ticks_msec()
	return _bought_since_limit or Time.get_ticks_msec() - _limit_seen_ms >= LIMIT_GRACE_MS


## Music and the ambience loop go on the shell Music bus, everything else on Sfx.
func bus_for(player: Node) -> StringName:
	var stream: Variant = player.get("stream")
	if stream is AudioStream and "ambience" in (stream as AudioStream).resource_path.to_lower():
		return &"Music"
	return super.bus_for(player)
