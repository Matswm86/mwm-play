extends Node

## Entry scene for the screenshot bot: starts the runner under /root so it
## survives the shell's scene changes, which free this node.


func _ready() -> void:
	var runner: Node = load("res://tests/capture_runner.gd").new()
	runner.name = "CaptureRunner"
	get_tree().root.add_child.call_deferred(runner)
