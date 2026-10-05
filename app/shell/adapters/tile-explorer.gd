extends ShellAdapter

## Tile Explorer: no autoloads, no audio and no sound button. Saves the level
## to user://tile_explorer_save.json on every win and on
## NOTIFICATION_APPLICATION_PAUSED, which the default exit() sends. Runs
## without MSAA on its pale sky clear colour; the shell restores its own
## MSAA and clear colour when the game is left. Its HUD keeps the top-left
## 232 px square free for the home disc (upstream README, "Running inside a
## host app").

## GameManager3D.GameState: IDLE, BUSY, WON, LOST.
const STATE_WON: int = 2
const STATE_LOST: int = 3


func _init() -> void:
	slug = "tile-explorer"
	title = "Tile Explorer"
	main_scene = "res://games/tile-explorer/scenes/Game3D.tscn"
	tile_art = "res://shell/tiles/tile-explorer.png"
	msaa_3d = Viewport.MSAA_DISABLED
	clear_color = Color(0.92, 0.95, 1.0)
	tip = "Si navnet på bildene dere plukker. Barnet finner den tredje som er lik."


## Play limit stopping point (provisional until the game-designer decides):
## the next win or lose card.
func is_at_stopping_point(game: Node) -> bool:
	var state: Variant = game.get("state")
	return state == STATE_WON or state == STATE_LOST
