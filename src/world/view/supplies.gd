class_name SuppliesView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.Supplies.cs.
# Expedition chests have no objective beams or extra lights. Their hidden loot is server-owned.
const SUPPLY_COL: Color = Color("FFD45C")

var main: Main

func _init(host: Main) -> void:
	main = host

# [id, position, empty, landmark, unlocked, lock progress, lid progress]; no hidden contents.
func supply_rows() -> Variant:
	var _v1 = main.snap.get("sup", null)
	return _v1 if _v1 != null else []

func exploration_items(items, view: Rect2) -> void:
	for c in supply_rows():
		var at: Vector2 = Vector2(c[1])
		if Cs.has_point(view.grow(60), at) and not main.weather_station.hidden_outside_interior(at):
			items.append([at.y, 21, c])
	items.append([GameSim.RADIO_POS.y, 22])

func draw_exploration_chest(c) -> void:
	var at: Vector2 = Vector2(c[1])
	var open: bool = c[4]
	var empty: bool = c[2]
	var unlock: float = float(c[5])
	var lid: float = smoothstep(0, 1, float(c[6])) if open else 0
	main.draw_set_transform(at)
	main.draw_rect(Rect2(-18, -3, 36, 9), Color(ExpeditionSitesView.ep("232820"), 0.4))
	main.draw_rect(Rect2(-17, -19, 34, 24), ExpeditionSitesView.ep("222D2C"))
	main.draw_rect(Rect2(-15, -17, 30, 20), ExpeditionSitesView.ep("555B55") if empty else ExpeditionSitesView.ep("6D754F"))
	main.draw_rect(Rect2(-12, -16, 4, 19), ExpeditionSitesView.ep("AFAF91"))
	main.draw_rect(Rect2(8, -16, 4, 19), ExpeditionSitesView.ep("AFAF91"))
	main.draw_rect(Rect2(-15, -5, 30, 2), ExpeditionSitesView.ep("414D3C"))
	if open:
		var top: float = Cs.round_even(lerpf(-24, -36, lid))
		main.draw_rect(Rect2(-17, top, 34, lerpf(9, 19, lid)), ExpeditionSitesView.ep("222D2C"))
		main.draw_rect(Rect2(-14, top + 3, 28, lerpf(3, 13, lid)), ExpeditionSitesView.ep("53624D"))
		main.draw_rect(Rect2(-12, top + 4, 24, lerpf(1, 9, lid)), ExpeditionSitesView.ep("2D3831"))
		main.draw_rect(Rect2(-14, -17, 28, 6), ExpeditionSitesView.ep("172721"))
		if not empty:
			main.draw_rect(Rect2(-10, -16, 8, 4), ExpeditionSitesView.ep("D2BD79"))
			main.draw_rect(Rect2(3, -16, 6, 3), ExpeditionSitesView.ep("8BA7A0"))
		# A broken latch and green corner remain visible after the opening animation finishes.
		main.draw_rect(Rect2(7, -5, 5, 3), ExpeditionSitesView.ep("89C793"))
		main.draw_line(Vector2(-4, -12), Vector2(-8, -7), ExpeditionSitesView.ep("D7B76E"), 2)
	else:
		main.draw_rect(Rect2(-18, -24, 36, 9), ExpeditionSitesView.ep("303D32"))
		main.draw_rect(Rect2(-16, -23, 32, 5), ExpeditionSitesView.ep("88916A"))
		main.draw_rect(Rect2(-3, -20, 6, 10), ExpeditionSitesView.ep("D7B76E"))
		main.draw_rect(Rect2(-1, -17, 2, 3), ExpeditionSitesView.ep("4D4936"))
		main.draw_arc(Vector2(0, -22), 4, PI, TAU, 8, ExpeditionSitesView.ep("E7D19B"), 2)
		if unlock > 0:
			main.draw_arc(Vector2(0, -16), 9, -PI / 2, -PI / 2 + TAU * unlock, 24, SUPPLY_COL, 2)
			main.draw_rect(Rect2(-25, -43, 50, 5), ExpeditionSitesView.ep("202826"))
			main.draw_rect(Rect2(-25, -43, 50 * unlock, 5), SUPPLY_COL)
	main.draw_set_transform(Vector2.ZERO)

static func draw_supply_icon(c, kind: int, at: Vector2, s: float, a_: float = 1) -> void:
	c.draw_rect(Rect2(at + Vector2(-8, -6) * s, Vector2(16, 12) * s), Color(0.13, 0.2, 0.2, a_))
	c.draw_rect(Rect2(at + Vector2(-6, -4) * s, Vector2(7, 4) * s), Color(0.55, 0.8, 0.55, a_))
	c.draw_rect(Rect2(at + Vector2(5, -12) * s, Vector2(1, 8) * s), Color(0.8, 0.82, 0.72, a_))
	c.draw_circle(at + Vector2(4, 2) * s, 2 * s, Color(0.9, 0.73, 0.37, a_))

func draw_installed_radio() -> void:
	var rescue = main.snap.get("rescue", null)
	if rescue == null:
		return
	var built: bool = rescue[1]
	var at: Vector2 = GameSim.RADIO_POS
	main.draw_set_transform(at)
	# Separate oak worktable, bolted metal edge, visible legs and a radio chassis from day one.
	main.draw_rect(Rect2(-35, -2, 70, 10), Color(Color("242B28"), 0.5))
	for x in [-29, 23]:
		main.draw_rect(Rect2(x, -8, 6, 13), Color("3B3026"))
		main.draw_rect(Rect2(x + 1, -8, 2, 11), Color("80613C"))
	main.draw_rect(Rect2(-35, -27, 70, 25), Color("252F32"))
	main.draw_rect(Rect2(-33, -25, 66, 19), Color("947044"))
	for y in [-20, -13]:
		main.draw_line(Vector2(-31, y), Vector2(31, y), Color("655034"), 1)
	main.draw_rect(Rect2(-34, -6, 68, 4), Color("B19667"))
	main.draw_rect(Rect2(-26, -47, 48, 20), Color("1C282D"))
	main.draw_rect(Rect2(-24, -45, 44, 16), Color("526C63"))
	main.draw_rect(Rect2(-21, -42, 21, 9), Color("182E31"))
	main.draw_rect(Rect2(-19, -40, 16, 4), Color("89D99A") if built else Color("677A68"))
	for x in [5, 13]:
		main.draw_circle(Vector2(x, -37), 3, Color("CBBA8D"))
	for x in range(-19, -2, 4):
		main.draw_line(Vector2(x, -34), Vector2(x, -31), Color("273C3C"), 1)
	main.draw_line(Vector2(17, -45), Vector2(22, -67), Color("BFCBC6"), 2)
	main.draw_circle(Vector2(22, -67), 2, Color("F6D78B"))
	for i in range(3):
		var slot = Rect2(-29 + i * 20, -24, 18, 16)
		main.draw_rect(slot, Color("23312F"))
		main.draw_rect(slot, Color("83BD93") if rescue[3][i] > 0 else Color("C2A66D"), false, 1)
		if rescue[3][i] > 0:
			draw_component_icon(main, i, slot.get_center(), 0.85)
	if built:
		main.draw_circle(Vector2(16, -31), 2, Color("8FFF9C"))
	var progress: float = float(rescue[2])
	if progress > 0:
		main.draw_rect(Rect2(-33, 9, 66, 5), Color("18242A"))
		main.draw_rect(Rect2(-33, 9, 66 * progress, 5), SUPPLY_COL)
	main.draw_set_transform(Vector2.ZERO)

static func draw_component_icon(c, kind: int, at: Vector2, scale: float) -> void:
	if kind == 0:
		for x in [-5, 1]:
			_draw_component_icon_box(x - 1, -5, 6, 11, "171D22", at, c, scale)
			_draw_component_icon_box(x, -4, 4, 9, "AAB7B6", at, c, scale)
			_draw_component_icon_box(x + 1, -6, 2, 2, "D8DFD5", at, c, scale)
			_draw_component_icon_box(x, 1, 4, 3, "507856", at, c, scale)
	elif kind == 1:
		_draw_component_icon_box(-5, 1, 10, 5, "3B4D51", at, c, scale)
		_draw_component_icon_box(-3, 2, 6, 3, "C3CCB2", at, c, scale)
		_draw_component_icon_box(-1, -7, 2, 9, "B9C6C3", at, c, scale)
		_draw_component_icon_box(-6, -5, 12, 2, "9CADA8", at, c, scale)
		_draw_component_icon_box(-4, -8, 8, 2, "D5DED0", at, c, scale)
	else:
		_draw_component_icon_box(-6, -5, 12, 10, "171D22", at, c, scale)
		_draw_component_icon_box(-5, -4, 10, 8, "386C4C", at, c, scale)
		_draw_component_icon_box(-2, -2, 4, 4, "222D36", at, c, scale)
		_draw_component_icon_box(-4, -3, 2, 1, "C2A45D", at, c, scale)
		_draw_component_icon_box(2, 1, 2, 1, "C2A45D", at, c, scale)
		for x in range(-4, 4, 2):
			_draw_component_icon_box(x, 4, 1, 2, "C2A45D", at, c, scale)

# local function Box of the method above
static func _draw_component_icon_box(x: float, y: float, w: float, h: float, hex_, at, c, scale) -> void:
	c.draw_rect(Rect2(at + Vector2(x, y) * scale, Vector2(w, h) * scale), Color(hex_))

func draw_supply_row(c, right: float, y: float) -> void:
	var rescue = main.snap.get("rescue", null)
	if rescue == null:
		return
	var built: bool = rescue[1]
	var box_ = Rect2(right - 232, y + 12, 232, 48)
	var cw = c
	c.draw_rect(box_, ExpeditionSitesView.ep("192027"))
	c.draw_rect(box_, SUPPLY_COL, false, 1)
	main.text(cw, box_.position + Vector2(6, 13), "LOCATOR RADIO", 10, Color.LIGHT_GREEN if built else SUPPLY_COL)
	for i in range(3):
		var installed: bool = int(rescue[3][i]) > 0
		var found: bool = int(rescue[0][i]) > 0
		var slot = Rect2(box_.position + Vector2(6 + i * 74, 19), Vector2(70, 22))
		var bg: Color = ExpeditionSitesView.ep("285637") if installed else ExpeditionSitesView.ep("7A5E22") if found else ExpeditionSitesView.ep("30363D")
		c.draw_rect(slot, bg)
		draw_component_icon(c, i, slot.get_center(), 1)
	var progress: float = float(rescue[2])
	if progress > 0:
		c.draw_rect(Rect2(box_.position + Vector2(6, 43), Vector2(220 * progress, 3)), SUPPLY_COL)
