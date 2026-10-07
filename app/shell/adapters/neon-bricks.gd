extends ShellAdapter

## MWM Neon Bricks: autoload NeonBricks (scripts/NbState.gd), parked by the
## shell while the game is closed. Saves to user://neon_bricks_save.json on a
## level clear, on settings changes, on pause and once more here on exit.
## With the Engine meta below set, its own home disc and settings gears are
## hidden and it leaves Android back to the shell (upstream GDD 11). The free
## part is levels 1-3: set_full_unlock() follows Shell.is_unlocked(); the
## locked map shows only levels 1-3 and no endless page, and the level 3 win
## card has no "next" disc (upstream GDD 6.1).

const SHELL_META := &"mwm_play_shell"


func _init() -> void:
	slug = "neon-bricks"
	title = "Neon Bricks"
	main_scene = "res://games/neon-bricks/scenes/Main.tscn"
	tile_art = "res://shell/tiles/neon-bricks.png"
	autoloads = PackedStringArray(["NeonBricks"])
	# The game's own project uses 2x MSAA; the shell sets it on enter and puts
	# its own (off) back on leave.
	msaa_3d = Viewport.MSAA_2X
	clear_color = Color(0.043, 0.024, 0.188)
	tip = "Bytt på: når en kloss med stjerne faller ned, er det den andres tur å styre."


## The shell has re-added NeonBricks to /root before this runs.
func enter(settings: Object) -> void:
	Engine.set_meta(SHELL_META, true)
	NeonBricks.load_game()
	NeonBricks.set_full_unlock(Shell.is_unlocked())
	NeonBricks.set_sfx_on(bool(settings.get("sound")))
	NeonBricks.set_music_on(bool(settings.get("music")))
	NeonBricks.set_haptics_on(bool(settings.get("vibration")))
	NeonBricks.set_less_motion(bool(settings.get("less_motion")))


func exit(game: Node) -> void:
	NeonBricks.save_game()
	super.exit(game)
	Engine.remove_meta(SHELL_META)


## Natural stopping points (upstream GDD 8.3): the win card or the map.
func is_at_stopping_point(game: Node) -> bool:
	if game.get("screen") == "map":
		return true
	var play: Object = game.get("play")
	return play != null and bool(play.call("card_visible"))
