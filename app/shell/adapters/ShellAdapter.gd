class_name ShellAdapter
extends RefCounted

## What the shell needs to know about one game (MERGE_PLAN section 3).
## One subclass per game in res://shell/adapters/<slug>.gd, written in MWM
## Play; the sync script never touches adapters. Game code stays as its own
## repo has it.

var slug: String = ""
var title: String = ""
var main_scene: String = ""
var tile_art: String = ""
## Renamed game autoloads, parked while the game is not running.
var autoloads: PackedStringArray = []
var msaa_3d: Viewport.MSAA = Viewport.MSAA_DISABLED
var clear_color: Color = Color(0, 0, 0)
var aspect: Window.ContentScaleAspect = Window.CONTENT_SCALE_ASPECT_EXPAND
## "Play together" tip for the parent area (rule 42).
var tip: String = ""


## Before the game scene loads. Gets the shell settings (sound, music,
## vibration, less motion); games that cannot read one yet ignore it.
func enter(_settings: Object) -> void:
	pass


## Before the game scene is freed. The default tells every node the app is
## going to the background, which is when the games already save.
func exit(game: Node) -> void:
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)


## True on a level-complete screen: where the play limit may stop the game.
func is_at_stopping_point(_game: Node) -> bool:
	return false


## Shell audio bus for a game sound player: "Music" or "Sfx".
func bus_for(player: Node) -> StringName:
	var stream: Variant = player.get("stream")
	if stream is AudioStream and "music" in (stream as AudioStream).resource_path.to_lower():
		return &"Music"
	return &"Sfx"
