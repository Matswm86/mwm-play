extends ShellTextPage

## "Lisenser og takk" (DESIGN 2e). Godot texts are read at runtime so they
## always match the engine build; font licences come from the OFL files.
## Plain text only, no links out (rule 45).


func _ready() -> void:
	build("Lisenser og takk")
	heading("MWM Play")
	para("Made by MWM. No ads, no tracking.")

	heading("Godot Engine")
	para(reflow(Engine.get_license_text()))

	heading("Third-party components in Godot")
	var used: Array[String] = []
	for info: Dictionary in Engine.get_copyright_info():
		var lines: Array[String] = [str(info.get("name", ""))]
		for part: Dictionary in info.get("parts", []):
			for c in part.get("copyright", []):
				lines.append("© " + str(c))
			var lic := str(part.get("license", ""))
			lines.append("License: " + lic)
			for id in lic.replace("(", " ").replace(")", " ").split(" ", false):
				if id not in ["and", "or", "with"] and id not in used:
					used.append(id)
		para("\n".join(lines))
	var texts: Dictionary = Engine.get_license_info()
	for id in used:
		if texts.has(id):
			heading(id)
			para(reflow(str(texts[id])))

	heading("Fonts")
	para("Andika: Copyright SIL Global. SIL Open Font License 1.1.")
	para(reflow(_read("res://shell/fonts/Andika-OFL.txt")))
	para("Fredoka: Copyright 2016 The Fredoka Project Authors. SIL Open Font License 1.1.")
	para(reflow(_read("res://shell/fonts/Fredoka-OFL.txt")))

	heading("Game assets")
	para(
		"Ball Connect and Water Sort use no third-party art or sound. Water Sort's music "
		+ "and sound effects are made by its own tools."
	)
	end_space()


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Licence text missing: %s" % path)
		return "(licence text missing)"
	return f.get_as_text()
