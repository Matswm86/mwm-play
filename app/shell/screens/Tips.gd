extends ShellTextPage

## "Spill sammen": a short how-to-play-together page per game (rule 42).


func _ready() -> void:
	var a: ShellAdapter = Shell.adapters.get(Shell.screen_arg)
	build(a.title if a != null else "Spill sammen")
	heading("Tips til å spille sammen")
	para(a.tip if a != null else "", 38)
