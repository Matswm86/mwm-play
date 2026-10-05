extends ShellAdapter

## Ball Connect: no autoloads; saves its level to user://ball_connect_save.json
## on NOTIFICATION_APPLICATION_PAUSED and on every level complete.


func _init() -> void:
	slug = "ball-connect"
	title = "Ball Connect"
	main_scene = "res://games/ball-connect/scenes/Game.tscn"
	tile_art = "res://shell/tiles/ball-connect.png"
	msaa_3d = Viewport.MSAA_2X
	clear_color = Color(0, 0, 0)
	tip = (
		"Ta annenhver linje: barnet viser hvilke baller som hører sammen, "
		+ "du drar, så bytter dere."
	)


func is_at_stopping_point(game: Node) -> bool:
	return game.get("won") == true
