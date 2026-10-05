extends ShellAdapter

## Spotless: autoloads SpotlessGame and SpotlessSfx, parked by the shell while
## the game is closed (no music or tool loops on other screens). Saves the
## level to user://spotless_save.json at every finished object, on pause, and
## once more here on exit. With the Engine meta below set, its own sound and
## music buttons are hidden and it never mutes the Master bus (upstream
## README, "Inside MWM Play"); SpotlessGame.in_shell() reads the meta at call
## time, so setting it here before the scene loads is enough.

const SHELL_META := &"mwm_play_shell"
const SHADOW_SETTING := "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
## Spotless's own project uses soft shadow quality 2 on phones.
const SOFT_SHADOWS := RenderingServer.SHADOW_QUALITY_SOFT_LOW

var _shell_shadows: int = 0


func _init() -> void:
	slug = "spotless"
	title = "Spotless"
	main_scene = "res://games/spotless/scenes/Main.tscn"
	tile_art = "res://shell/tiles/spotless.png"
	autoloads = PackedStringArray(["SpotlessGame", "SpotlessSfx"])
	msaa_3d = Viewport.MSAA_2X
	clear_color = Color(0.9, 0.88, 0.85)
	tip = "Spør hvilket verktøy som trengs nå, og la barnet velge fargen til slutt."


## The shell has re-added SpotlessGame and SpotlessSfx to /root before this runs.
func enter(_settings: Object) -> void:
	Engine.set_meta(SHELL_META, true)
	SpotlessGame.load_game()
	# The players were made at app start, before the shell routed new nodes to
	# its buses: music goes on Music, one-shots and tool loops on Sfx.
	for p in SpotlessSfx.get_children():
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).bus = bus_for(p)
	# Re-adding an AudioStreamPlayer does not restart it; with the meta set the
	# music always plays and the shell's Music switch decides if it is heard.
	SpotlessSfx.apply_settings()
	_shell_shadows = int(ProjectSettings.get_setting_with_override(SHADOW_SETTING))
	RenderingServer.directional_soft_shadow_filter_set_quality(SOFT_SHADOWS)


func exit(game: Node) -> void:
	SpotlessSfx.stop_loops()
	SpotlessGame.save_game()
	super.exit(game)
	Engine.remove_meta(SHELL_META)
	RenderingServer.directional_soft_shadow_filter_set_quality(_shell_shadows)


## Play limit stopping point (provisional until the game-designer decides):
## the win card after the next finished object.
func is_at_stopping_point(game: Node) -> bool:
	return game.get("state") == "complete"
