extends Node

## Dev-only: loads every script so parse errors in lazily loaded screens show
## up (the --quit load check only loads the start screen).
func _ready() -> void:
	var bad := 0
	var n := 0
	var stack: Array[String] = ["res://shell", "res://games", "res://tests"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				n += 1
				var s: Script = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					bad += 1
					print("BAD ", d + "/" + f)
	print("PARSED %d scripts, %d failed" % [n, bad])
	get_tree().quit()
