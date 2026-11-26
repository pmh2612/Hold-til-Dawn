class_name KeyboardHelpUi
extends RefCounted

# A code-drawn keyboard keeps keycaps, arrow labels and hover targets aligned at every HUD size.
const SIZE = Vector2(900, 480)
const UNIT = 39.0
const MUTED = Color("89939E")
const PAPER = Color("E7EDF2")
const MOVE = Color("59C9BD")
const ACTION = Color("D9B36B")
const SUPPORT = Color("91C985")
const ENGINEER = Color("E9A373")
const MENU = Color("9DAFE4")

const ACTIONS = {
	"Esc": ["Pause", MENU, "PAUSE / CLOSE", "Close panel / pause."],
	"Tab": ["Bag", MENU, "BAG / STORAGE", "Bag / nearby chest."],
	"Q": ["Bandage", SUPPORT, "BANDAGE", "+30 HP"],
	"W": ["Move", MOVE, "MOVE FORWARD", "WASD: move\nMouse: aim"],
	"A": ["Move", MOVE, "MOVE LEFT", "WASD: move\nMouse: aim"],
	"S": ["Move", MOVE, "MOVE BACK", "WASD: move\nMouse: aim"],
	"D": ["Move", MOVE, "MOVE RIGHT", "WASD: move\nMouse: aim"],
	"E": ["Interact", ACTION, "INTERACT", "Hold: gather / repair / revive\nChest: key + hold 2s\nTap: pick up / radio repair"],
	"T": ["Tower", ENGINEER, "PLACE TOWER", "Engineer | Build: 6s\nLMB: place; stay still\nRMB / Esc: cancel"],
	"F": ["Enter", ENGINEER, "ENTER / LEAVE", "Engineer | Night only\nHold F at intact door"],
	"G": ["Give/drop", ACTION, "GIVE / DROP", "Give stack to nearby ally.\nNo ally: drop stack."],
	"H": ["Help", MENU, "CONTROLS", "H / Esc: close"],
	"C": ["Craft", SUPPORT, "CRAFT / RADIO", "Workbench / radio nearby"],
	"V": ["Vote", ACTION, "SKIP DAY", "Vote when available"],
	"M": ["Map", MENU, "ISLAND MAP", "M: open / close"],
	"Ctrl": ["Zoom", MENU, "ZOOM", "Ctrl + wheel"]
}

var main: Main
var keys: Array = []

func _init(host: Main) -> void:
	main = host
	var functions: Array = [["Esc", 1], ["", 0.5]]
	for i in range(1, 13):
		functions.append(["F%d" % i, 1])
	add_row(functions, 100)
	add_row([["`", 1], ["1", 1], ["2", 1], ["3", 1], ["4", 1], ["5", 1], ["6", 1], ["7", 1], ["8", 1], ["9", 1], ["0", 1], ["-", 1], ["=", 1], ["Back", 2]], 155)
	add_row([["Tab", 1.5], ["Q", 1], ["W", 1], ["E", 1], ["R", 1], ["T", 1], ["Y", 1], ["U", 1], ["I", 1], ["O", 1], ["P", 1], ["[", 1], ["]", 1], ["\\", 1.5]], 210)
	add_row([["Caps", 1.75], ["A", 1], ["S", 1], ["D", 1], ["F", 1], ["G", 1], ["H", 1], ["J", 1], ["K", 1], ["L", 1], [";", 1], ["'", 1], ["Enter", 2.25]], 265)
	add_row([["Shift", 2.25], ["Z", 1], ["X", 1], ["C", 1], ["V", 1], ["B", 1], ["N", 1], ["M", 1], [",", 1], [".", 1], ["/", 1], ["Shift", 2.75]], 320)
	add_row([["Ctrl", 1.25], ["Win", 1.25], ["Alt", 1.25], ["Space", 6.25], ["Alt", 1.25], ["Fn", 1.25], ["Ctrl", 1.5]], 375)

func add_row(row: Array, y: float) -> void:
	var x := 36.0
	for entry in row:
		if entry[0] != "":
			keys.append({"name": entry[0], "box": Rect2(x, y, float(entry[1]) * UNIT - 4, 29)})
		x += float(entry[1]) * UNIT

func action_for(key: String) -> Array:
	if key.is_valid_int() and int(key) >= 1 and int(key) <= 6:
		var n := int(key)
		var detail := "Hotbar: slot %d\nWorkbench: craft %d" % [n, n] if n <= 4 else "Workbench: craft %d" % n
		return [("Slot %d" if n <= 4 else "Craft %d") % n, ACTION, "HOTBAR / CRAFT" if n <= 4 else "CRAFT RECIPE", detail]
	return ACTIONS.get(key, [])

func draw_guide(c: Control, viewport: Vector2) -> void:
	var scale_: float = minf((viewport.x - 24) / SIZE.x, (viewport.y - 24) / SIZE.y)
	var origin: Vector2 = (viewport - SIZE * scale_) * 0.5
	var mouse: Vector2 = (c.get_local_mouse_position() - origin) / scale_
	c.draw_rect(Rect2(Vector2.ZERO, viewport), Color(0, 0, 0, 0.66))
	c.draw_set_transform(origin, 0, Vector2.ONE * scale_)
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("10171F"))
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Main.GOLD, false, 2)
	main.text(c, Vector2(24, 33), "KEYBOARD & MOUSE", 23, PAPER, 0, -1, true)
	main.text(c, Vector2(24, 58), "Hover a key for details", 11, MUTED)
	main.text(c, Vector2(691, 33), "H / ESC  CLOSE", 12, Main.GOLD, 2, 184)
	c.draw_line(Vector2(24, 73), Vector2(876, 73), Color("34404D"), 1)
	# The full keyboard silhouette, including unused keys, makes physical positions easy to recognize.
	c.draw_rect(Rect2(24, 88, 610, 350), Color("090E14"))
	c.draw_rect(Rect2(24, 88, 610, 350), Color("34404D"), false, 1)
	var hovered: Array = []
	for key in keys:
		var action := action_for(key.name)
		var hit: bool = not action.is_empty() and key.box.grow(3).has_point(mouse)
		if hit:
			hovered = action
		draw_key(c, key, action, hit)
	draw_mouse(c)
	draw_details(c, hovered)
	main.text(c, Vector2(24, 461), "WASD  MOVE", 10, MOVE)
	main.text(c, Vector2(185, 461), "GOLD  ACTIONS", 10, ACTION)
	main.text(c, Vector2(371, 461), "GREEN  SUPPORT", 10, SUPPORT)
	main.text(c, Vector2(578, 461), "ORANGE  ENGINEER", 10, ENGINEER)
	main.text(c, Vector2(766, 461), "BLUE  PANELS", 10, MENU)
	c.draw_set_transform(Vector2.ZERO)

func draw_key(c: Control, key: Dictionary, action: Array, hovered: bool) -> void:
	var box_: Rect2 = key.box
	var active := not action.is_empty()
	var col: Color = action[1] if active else Color("434C58")
	c.draw_rect(Rect2(box_.position + Vector2(0, 3), box_.size), Color("04080D"))
	c.draw_rect(box_, col.darkened(0.48 if hovered else 0.73) if active else Color("171F29"))
	c.draw_rect(box_, col if active else Color("2B3541"), false, 2 if hovered else 1)
	c.draw_line(box_.position + Vector2(4, 3), box_.position + Vector2(box_.size.x - 4, 3), Color(col, 0.5), 1)
	main.text(c, box_.position + Vector2(0, 19), key.name, 11, PAPER if active else Color("636E7C"), 1, box_.size.x)
	if active:
		var mid: Vector2 = box_.get_center()
		# Every used key has its own arrow, rather than a shared line crossing other keycaps.
		arrow(c, Vector2(mid.x, box_.end.y + 13), Vector2(mid.x, box_.end.y + 3), col)
		main.text(c, Vector2(box_.position.x - 4, box_.end.y + 23), action[0], 8, col, 1, box_.size.x + 8)

func arrow(c: Control, from: Vector2, to: Vector2, colour: Color) -> void:
	c.draw_line(from, to, colour, 1.4)
	var dir: Vector2 = (to - from).normalized()
	c.draw_colored_polygon(PackedVector2Array([to, to - dir * 5 + dir.orthogonal() * 3, to - dir * 5 - dir.orthogonal() * 3]), colour)

func draw_mouse(c: Control) -> void:
	main.text(c, Vector2(658, 102), "MOUSE", 12, PAPER, 1, 218, true)
	var body := PackedVector2Array([Vector2(735, 126), Vector2(747, 114), Vector2(787, 114), Vector2(799, 126), Vector2(799, 195), Vector2(787, 209), Vector2(747, 209), Vector2(735, 195)])
	c.draw_colored_polygon(body, Color("222D39"))
	c.draw_polyline(body + PackedVector2Array([body[0]]), Color("667688"), 2)
	c.draw_rect(Rect2(740, 122, 24, 37), Color("785C35"))
	c.draw_rect(Rect2(770, 122, 24, 37), Color("455C86"))
	c.draw_line(Vector2(767, 115), Vector2(767, 164), Color("10171F"), 3)
	c.draw_rect(Rect2(762, 129, 10, 23), PAPER)
	main.text(c, Vector2(656, 139), "LMB", 12, ACTION, 1, 60)
	arrow(c, Vector2(710, 138), Vector2(749, 138), ACTION)
	main.text(c, Vector2(814, 139), "RMB", 12, MENU, 1, 65)
	arrow(c, Vector2(821, 148), Vector2(789, 148), MENU)
	main.text(c, Vector2(649, 178), "Attack /", 10, ACTION, 1, 82)
	main.text(c, Vector2(649, 193), "use item", 10, ACTION, 1, 82)
	main.text(c, Vector2(804, 178), "Flask /", 10, MENU, 1, 80)
	main.text(c, Vector2(804, 193), "use item", 10, MENU, 1, 80)
	arrow(c, Vector2(767, 229), Vector2(767, 155), PAPER)
	main.text(c, Vector2(649, 246), "Wheel: select slot", 10, PAPER, 1, 235)
	main.text(c, Vector2(649, 263), "Ctrl + wheel: zoom", 10, MUTED, 1, 235)

func draw_details(c: Control, action: Array) -> void:
	var col: Color = action[1] if not action.is_empty() else MENU
	c.draw_rect(Rect2(650, 283, 226, 155), Color("18222D"))
	c.draw_rect(Rect2(650, 283, 3, 155), col)
	main.text(c, Vector2(665, 307), action[2] if not action.is_empty() else "POINT TO A KEY", 12, col, 0, -1, true)
	var detail: String = action[3] if not action.is_empty() else "Hover a highlighted key"
	var lines := detail.split("\n")
	for i in lines.size():
		main.text(c, Vector2(665, 332 + i * 18), lines[i], 10, PAPER)
