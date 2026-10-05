class_name ShellTextPage
extends Control

## Base for adult text screens (credits, privacy, tips): the parent-area top
## bar and one long vertical scroll (DESIGN 2e). Text Andika Regular 30 px,
## line height about 1.45, headings Andika Bold 40, 48 px side margins.

const SIDE: float = 48.0
const TEXT_W: float = 1080.0 - SIDE * 2.0

var scroll: ScrollContainer
var body: VBoxContainer


func build(title_text: String) -> void:
	var frame := ShellUi.screen_frame(self)
	var title := ShellUi.label(title_text, "fredoka", 60)
	title.position = Vector2(212, 104 - 44)
	frame.add_child(title)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(SIDE, 220)
	scroll.size = Vector2(TEXT_W, frame.size.y - 220)
	frame.add_child(scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.custom_minimum_size = Vector2(TEXT_W, 0)
	scroll.add_child(body)
	var home := ShellHomeButton.new()
	home.guard = false
	home.leave_requested.connect(Shell.goto.bind("start", ""))
	add_child(home)


func heading(text: String) -> void:
	var l := ShellUi.label(text, "andika_bold", 40)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_W, 0)
	body.add_child(l)


func para(text: String, size: int = 30) -> void:
	body.add_child(ShellUi.wrapped(text.strip_edges(), "andika", size, ShellUi.INK, TEXT_W))


## Licence files break lines at about 80 columns; join those so the text
## wraps to the phone width. Blank lines and list items stay as they are.
func reflow(text: String) -> String:
	var out := PackedStringArray()
	var prev_joinable := false
	for line in text.replace("\r", "").split("\n"):
		var t := line.strip_edges()
		var is_rule := t.length() > 3 and t.replace("-", "").replace("=", "") == ""
		var is_heading := t.length() < 60 and t == t.to_upper() and t.to_lower() != t
		var is_item := t.begins_with("- ") or t.begins_with("* ")
		is_item = is_item or (t.length() > 1 and t[0].is_valid_int() and t[1] in ").")
		if prev_joinable and t != "" and not (is_rule or is_heading or is_item):
			out[out.size() - 1] += " " + t
		else:
			out.append(t)
		prev_joinable = t != "" and not (is_rule or is_heading)
	return "\n".join(out)


func end_space() -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 200)
	body.add_child(c)


## Adult sub-pages go up one level on Android back.
func on_back() -> void:
	Shell.goto("parent")
