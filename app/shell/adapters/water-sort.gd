extends ShellAdapter

## Water Sort: no autoloads; saves its level to user://water-sort_save.cfg at
## every level complete. Its own sound switch is hidden in the shell: the
## Engine meta below tells the game to always play and leave Music and Sfx to
## the shell buses (documented in the water-sort README).

const SHELL_META := &"mwm_play_shell"


func _init() -> void:
	slug = "water-sort"
	title = "Water Sort"
	main_scene = "res://games/water-sort/scenes/Game.tscn"
	tile_art = "res://shell/tiles/water-sort.png"
	msaa_3d = Viewport.MSAA_DISABLED
	clear_color = Color(0.06, 0.13, 0.2)
	tip = "Spør hvilken flaske som snart er full før dere heller, og la barnet forklare planen."


func enter(_settings: Object) -> void:
	Engine.set_meta(SHELL_META, true)


func exit(game: Node) -> void:
	super.exit(game)
	Engine.remove_meta(SHELL_META)


func is_at_stopping_point(game: Node) -> bool:
	return game.get("won") == true
