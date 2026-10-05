extends ShellAdapter

## Water Sort: no autoloads; saves level and its own sound switch to
## user://water-sort_save.cfg at every level start and level complete.


func _init() -> void:
	slug = "water-sort"
	title = "Water Sort"
	main_scene = "res://games/water-sort/scenes/Game.tscn"
	tile_art = "res://shell/tiles/water-sort.png"
	msaa_3d = Viewport.MSAA_DISABLED
	clear_color = Color(0.06, 0.13, 0.2)
	tip = "Spør hvilken flaske som snart er full før dere heller, og la barnet forklare planen."


func is_at_stopping_point(game: Node) -> bool:
	return game.get("won") == true
