class_name CraftPanelUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.CraftPanel.cs.
# Owner: Vu Duc Viet Anh. The workbench tab (MEC-10, BAL-19, recipe table in GDD section 3.2), opened with C.
# It takes the middle of the screen like the bag: on the left every recipe as a card with its icon, grouped by
# tier; on the right the picked recipe in detail (what it does, its numbers) and how it is made, drawn as
# ingredients + ingredients -> result, the steps to follow and a Craft button. A number key still crafts at once.
# The server decides (GameSim.CanCraft); the reasons shown here only mirror its rules.
# the recipe shown on the right
var craft_sel: int = 0
var craft_tier: int = 0
var radio_mode: bool = false

# constants shared with Main
const GOLD = Main.GOLD
const INK = Main.INK

var main: Main

func _init(host: Main) -> void:
	main = host

func craft_choices() -> Variant:
	var choices = []
	var i: int = 0
	while i < GameSim.RECIPES.size():
		if int(GameSim.RECIPES[i][2]) == craft_tier:
			choices.append(i)
		i += 1
	return choices

func craft_tier_button(vs: Vector2, tier: int) -> Rect2:
	var p: Rect2 = craft_panel_rect(vs)
	var w: float = (craft_left_w(p) - 12) / 3
	return Rect2(p.position.x + 20 + tier * (w + 4), p.position.y + HEAD_H + 4, w, 26)

func select_craft_tier(tier: int) -> void:
	craft_tier = clampi(tier, 0, 2)
	var choices = craft_choices()
	if not choices.has(craft_sel):
		craft_sel = choices[0]

const CARD_H: float = 92.0
const CARD_GAP: float = 8.0
const BOX: float = 52.0
# the title line
const HEAD_H: float = 48.0

# --- layout --------------------------------------------------------------
func craft_panel_rect(vs: Vector2) -> Rect2:
	# Leave the phase clock above the opaque panel, including at the 960 x 540 viewport.
	var w: float = minf(vs.x - 40.0, 940.0)
	var h: float = minf(vs.y - 92.0, 420.0)
	return Rect2(Cs.round_even((vs.x - w) / 2), maxf(68, Cs.round_even((vs.y - h) / 2)), w, h)

func craft_left_w(p: Rect2) -> float:
	return floorf(p.size.x * 0.54)

func craft_card(vs: Vector2, i: int) -> Rect2:
	var p: Rect2 = self.craft_panel_rect(vs)
	var lw: float = self.craft_left_w(p)
	var cw: float = floorf((lw - 3 * CARD_GAP) / 4)
	var r = GameSim.RECIPES[i]
	var tier: int = int(r[2])
	var k: int = 0
	for j in range(i):
		if int(GameSim.RECIPES[j][2]) == tier:
			k += 1
	var y: float = p.position.y + HEAD_H + 44 + k / 4 * (CARD_H + 12)
	return Rect2(p.position.x + 20 + k % 4 * (cw + CARD_GAP), y, cw, CARD_H)

func craft_detail(p: Rect2) -> Rect2:
	var x: float = p.position.x + 20 + self.craft_left_w(p) + 24
	return Rect2(x, p.position.y + HEAD_H + 4, p.end.x - 20 - x, p.size.y - HEAD_H - 4 - 16)

func craft_button(vs: Vector2) -> Rect2:
	var d: Rect2 = self.craft_detail(self.craft_panel_rect(vs))
	return Rect2(d.position.x, d.end.y - 38, d.size.x, 38)

# --- what the recipe is ----------------------------------------------------
# 8 -> "8", 1.5 -> "1.5"
static func num(v) -> Variant:
	var f: float = float(v)
	return str(int(f)) if f == floorf(f) else String.num(f, 1)

static func key_of(i: int) -> Variant:
	var n: int = 0
	var tier: int = int(GameSim.RECIPES[i][2])
	for j in range(i + 1):
		if int(GameSim.RECIPES[j][2]) == tier:
			n += 1
	return Cs.s(n % 10)

func craft_seconds(r) -> float:
	var me = main.snap.get("ps", {}).get(main.my_id, null)
	return (float(r[4]) / 20.0 if r[3] == "base" else GameSim.CRAFT_TIME) * (0.8 if me != null and InventoryUi.carried(me, "crafting_kit") > 0 else 1.0)

func craft_tag(id) -> Variant:
	if SimSupplies.rescue_kind(id) >= 0:
		return "RESCUE - TEAM EQUIPMENT"
	if id == "revive":
		return "TEAM"
	elif id == "base":
		return "BASE  -  ENGINEER ONLY"
	elif id == "bandage":
		return "HEALING"
	elif id == "arrow":
		return "AMMO"
	var kind = SimInventory.kind_of(id)
	if kind == "weapon":
		return "WEAPON  -  RANGED" if GameSim.WEAPON_STATS[id][3] else "WEAPON  -  MELEE"
	return kind.to_upper()

# one short line of numbers
func craft_desc(id) -> Variant:
	var out = []
	if SimSupplies.rescue_kind(id) >= 0:
		out.append("Required for the rescue helicopter")
		out.append("Craft by day. Installed for the whole team.")
		out.append("Find radio parts in any island chest.")
		return out
	var tactical = SimTacticalItems.tactical_description(id)
	if tactical.size() > 0:
		return Array(tactical).duplicate()
	if GameSim.WEAPON_STATS.has(id):
		var s = GameSim.WEAPON_STATS[id]
		var ranged: bool = s[3]
		out.append(num(s[0]) + " damage, " + num(s[1]) + "/s, " + ("range " if ranged else "reach ") + num(s[2]))
		if id == "bow":
			out.append("No arrows included. Craft ammunition separately.")
		return out
	var k: int = 1
	while k < GameSim.ARMOUR_ITEMS.size():
		if Cs.s(GameSim.ARMOUR_ITEMS[k]) == id:
			out.append("-%d%% damage taken" % [int(Cs.round_even(float(GameSim.ARMOUR[k]) * 100.0))])
			return out
		k += 1
	if id == "bandage":
		out.append("Q: +30 HP")
	elif id == "revive":
		out.append("Hold E on a dead teammate")
	elif id == "base":
		out.append("+100 generator HP, by day")
	return out

# why this recipe cannot be crafted right now ("" = it can), the same rules as GameSim.CanCraft
func craft_block(me, i: int) -> Variant:
	var r = GameSim.RECIPES[i]
	var id = Cs.s(r[3])
	var tier: int = int(r[2])
	var radio = main.snap.get("rescue", null)
	if radio != null and float(radio[2]) > 0 and Cs.s(me[22]) == "craft" and int(me[26]) < 0:
		return "Finish repairing the radio first"
	if tier != 3 and tier > main.snap.get("unlock", 0):
		return "Unlocks after night 1" if tier == 1 else "Unlocks after the first boss"
	if r[5] and me[1] != 2:
		return "Only an Engineer can do this"
	if SimInventory.kind_of(id) == "armour" and GameSim.ARMOUR_ITEMS.find(id) <= int(me[9]):
		return "Already worn"
	if id == "base":
		if main.snap.get("ph", "") == "night":
			return "The generator can only be repaired by day"
		if main.snap.get("base", 0.0) >= float(GameSim.BASE_HP):
			return "The generator is at full HP"
	for res in r[1]:
		var need: int = int(r[1][res])
		var have: int = main.survival_feedback.craft_have_local(me, Cs.s(res))
		if have < need:
			return "Need %d more %s" % [need - have, SimInventory.item_name(res)]
	if not main.inventory.at_bench_local(me):
		return "Walk to the workbench to craft"
	var busy: int = int(me[26])
	if busy >= 0 and busy != i:
		return "Already making %s" % [GameSim.RECIPES[busy][0]]
	return ""

# --- drawing ---------------------------------------------------------------
func draw_craft_panel(c, vs) -> void:
	if not main.craft_open:
		return
	var me = main.snap.ps.get(main.my_id)
	if me == null:
		return
	if radio_mode:
		draw_radio_panel(c, Vector2(vs), me)
		return
	var v: Vector2 = Vector2(vs)
	craft_sel = clampi(craft_sel, 0, GameSim.RECIPES.size() - 1)
	var mouse: Vector2 = Vector2(main.hud.get_local_mouse_position())
	# Opaque backing keeps world lights and scenery from competing with recipes.
	var p: Rect2 = self.craft_panel_rect(v)
	c.draw_rect(p, Color(0.06, 0.07, 0.1, 1.0))
	c.draw_rect(p, GOLD * Color(1, 1, 1, 0.7), false, 1.5)
	c.draw_line(Vector2(p.position.x + 16, p.position.y + HEAD_H - 8), Vector2(p.end.x - 16, p.position.y + HEAD_H - 8), Color(1, 1, 1, 0.1), 1.0)
	main.text(c, p.position + Vector2(20, 28), "WORKBENCH", 18, GOLD, 0, -1.0, true)
	# --- recipe cards, by tier
	var lw: float = self.craft_left_w(p)
	for t in range(3):
		var tab: Rect2 = craft_tier_button(v, t)
		var open: bool = t == 3 or t <= main.snap.get("unlock", 0)
		c.draw_rect(tab, Color(0.35, 0.29, 0.14, 0.95) if craft_tier == t else Color(0.08, 0.09, 0.12, 0.9))
		c.draw_rect(tab, GOLD if craft_tier == t else Color(1, 1, 1, 0.2), false, 1.0)
		main.text(c, Vector2(tab.position.x, tab.position.y + 18), ("BASIC" if t == 0 else "STONE" if t == 1 else "TITANIUM") + ("" if open else " [locked]"), 11, GOLD if open else Color.GRAY, 1, tab.size.x, true)
	var busy: int = int(me[26])
	for i in range(GameSim.RECIPES.size()):
		if int(GameSim.RECIPES[i][2]) == craft_tier:
			self.draw_craft_card(c, me, i, self.craft_card(v, i), mouse, busy)
	draw_craft_bag(c, v, me, mouse)
	c.draw_line(Vector2(p.position.x + 20 + lw + 12, p.position.y + HEAD_H), Vector2(p.position.x + 20 + lw + 12, p.end.y - 14), Color(1, 1, 1, 0.12), 1.0)
	self.draw_craft_detail(c, me, v, self.craft_detail(p), mouse, busy)

func craft_bag_slots(vs: Vector2) -> Array:
	var p = craft_panel_rect(vs)
	var slots: Array = []
	for i in range(GameSim.INV_SLOTS):
		slots.append(Rect2(p.position + Vector2(20 + i * (InventoryUi.SLOT + InventoryUi.SLOT_GAP), 344), Vector2.ONE * InventoryUi.SLOT))
	return slots

func craft_bag_slot_at(vs: Vector2, at: Vector2) -> int:
	var slots = craft_bag_slots(vs)
	for i in range(slots.size()):
		if slots[i].has_point(at):
			return i
	return -1

func draw_craft_bag(c, vs: Vector2, me, mouse: Vector2) -> void:
	var p = craft_panel_rect(vs)
	main.text(c, p.position + Vector2(20, 330), "YOUR BAG", 11, GOLD, 0, -1, true)
	var slots = craft_bag_slots(vs)
	var drag = main.inventory.drag_from
	for i in range(slots.size()):
		var item = me[7][i]
		var dragging: bool = drag != null and drag[0] == "inv" and drag[1] == i
		main.inventory.draw_slot(c, slots[i], null if dragging else item, int(me[25]) == i, str(i + 1) if i < GameSim.HOTBAR else "")
		if item != null and slots[i].has_point(mouse) and drag == null:
			main.text(c, p.position + Vector2(20, 408), SimInventory.item_name(item[0]), 11, Color.WHITE)
	if drag != null and drag[0] == "inv" and int(drag[1]) < me[7].size():
		main.inventory.draw_slot(c, Rect2(mouse - Vector2.ONE * InventoryUi.SLOT / 2, Vector2.ONE * InventoryUi.SLOT), me[7][int(drag[1])], true, "")

func craft_bag_mouse(vs: Vector2, mouse: Vector2, pressed: bool) -> bool:
	var hit: int = craft_bag_slot_at(vs, mouse)
	var drag = main.inventory.drag_from
	if pressed and hit >= 0:
		main.inventory.drag_from = ["inv", hit]
		return true
	if not pressed and drag != null:
		if hit >= 0:
			if int(drag[1]) == hit and hit < GameSim.HOTBAR:
				main.act("select", hit)
			else:
				main.act("move_item", ["inv", int(drag[1]), "inv", hit])
		main.inventory.drag_from = null
		return true
	return false

func radio_block(me) -> String:
	var rescue = main.snap.get("rescue", null)
	if rescue == null or me == null:
		return "Radio unavailable"
	if rescue[1]:
		return "Radio online"
	if int(me[5]) != 0:
		return "Cannot repair right now"
	if not main.inventory.in_base_local(me) or not SimWorld.near_radio(Vector2(main.local_pos)):
		return "Walk to the radio"
	if main.snap.get("ph", "") != "day":
		return "Repair by day, before night 5"
	if rescue[3].count(1) < 3:
		return "Find all 3 components"
	if float(rescue[2]) > 0:
		return "Repair in progress"
	if int(me[26]) >= 0 or float(me[13]) > 0 or float(me[31]) > 0:
		return "Finish the current action first"
	return ""

func repair_radio() -> void:
	var me = main.snap.get("ps", {}).get(main.my_id)
	if main.craft_open and radio_mode and radio_block(me) == "":
		main.act("radio_repair")

func draw_radio_panel(c, vs: Vector2, me) -> void:
	var rescue = main.snap.get("rescue", null)
	if rescue == null:
		return
	var p = craft_panel_rect(vs)
	c.draw_rect(p, Color("101219"))
	c.draw_rect(p, GOLD, false, 1.5)
	main.text(c, p.position + Vector2(20, 28), "LOCATOR RADIO", 18, GOLD, 0, -1, true)
	main.text(c, p.position + Vector2(p.size.x - 132, 28), "C / ESC: CLOSE", 11, Color.WHITE)
	c.draw_line(p.position + Vector2(16, HEAD_H - 8), Vector2(p.end.x - 16, p.position.y + HEAD_H - 8), Color(1, 1, 1, 0.15), 1)
	var lw: float = craft_left_w(p)
	var cw: float = floorf((lw - 16) / 3)
	for i in range(3):
		var card = Rect2(p.position + Vector2(20 + i * (cw + 8), HEAD_H + 28), Vector2(cw, 142))
		var placed: bool = rescue[3][i] > 0
		c.draw_rect(card, Color("1D302A") if placed else Color("171C24"))
		c.draw_rect(card, Color("7FD38A") if placed else Color("50565E"), false, 1.5)
		SuppliesView.draw_component_icon(c, i, card.position + Vector2(cw / 2, 42), 3)
		main.text(c, card.position + Vector2(0, 94), GameSim.SUPPLY_NAMES[i], 11, Color.WHITE, 1, cw)
		main.text(c, card.position + Vector2(0, 121), "INSTALLED" if placed else "MISSING", 11, Color("7FD38A") if placed else Color("A0A6AD"), 1, cw, true)
	main.text(c, p.position + Vector2(20, 262), "%d / 3 COMPONENTS" % [rescue[3].count(1)], 14, GOLD, 0, -1, true)
	main.text(c, p.position + Vector2(20, 290), "Find the missing parts in island chests.", 11, Color.WHITE)
	main.text(c, p.position + Vector2(20, 310), "Collected parts are installed when you open this panel.", 11, Color.WHITE)
	main.text(c, p.position + Vector2(20, p.size.y - 28), "Repair before night 5 to arrange the rescue.", 11, GOLD)
	var d = craft_detail(p)
	c.draw_line(Vector2(d.position.x - 12, d.position.y), Vector2(d.position.x - 12, d.end.y), Color(1, 1, 1, 0.15), 1)
	var icon = Rect2(d.position, Vector2(96, 96))
	c.draw_rect(icon, Color("1A2527"))
	c.draw_rect(icon, GOLD, false, 1.5)
	SuppliesView.draw_supply_icon(c, 0, icon.get_center(), 4)
	main.text(c, d.position + Vector2(110, 23), "Locator radio", 17, Color.WHITE, 0, -1, true)
	main.text(c, d.position + Vector2(110, 43), "RESCUE EQUIPMENT", 11, GOLD)
	main.text(c, d.position + Vector2(0, 132), "3 components  +  5 seconds", 13, GOLD)
	main.text(c, d.position + Vector2(0, 159), "Press E once to start repairing.", 11, Color.WHITE)
	main.text(c, d.position + Vector2(0, 180), "Stay still until the radio is ready.", 11, Color.WHITE)
	main.text(c, d.position + Vector2(0, 201), "Moving or taking damage interrupts repairs.", 11, Color.WHITE)
	var b = craft_button(vs)
	var progress: float = float(rescue[2])
	var blocked: String = radio_block(me)
	c.draw_rect(b, GOLD if blocked == "" else Color("33383F"))
	if progress > 0:
		c.draw_rect(Rect2(b.position, Vector2(b.size.x * progress, b.size.y)), GOLD)
	var label: String = "REPAIRING... %d%%" % [int(progress * 100)] if progress > 0 else "REPAIR RADIO  [E]" if blocked == "" else blocked.to_upper()
	main.text(c, b.position + Vector2(0, 25), label, 13, INK if blocked == "" else Color.WHITE, 1, b.size.x, true)

func draw_craft_card(c, me, i: int, card: Rect2, mouse: Vector2, busy: int) -> void:
	var r = GameSim.RECIPES[i]
	var id = Cs.s(r[3])
	var locked: bool = int(r[2]) != 3 and int(r[2]) > main.snap.get("unlock", 0)
	var why = self.craft_block(me, i)
	var ready: bool = why == ""
	var hover: bool = card.has_point(mouse)
	var sel: bool = i == craft_sel
	c.draw_rect(card, Color(0.14, 0.16, 0.21, 0.85) if hover else Color(0.05, 0.06, 0.09, 0.6))
	c.draw_rect(card, GOLD if sel else Color(0.5, 0.85, 0.55, 0.55) if ready else Color(1, 1, 1, 0.15), false, 2.0 if sel else 1.0)
	main.text(c, card.position + Vector2(5, 13), key_of(i), 10, Color(1, 1, 1, 0.55), 0, -1.0, true)
	if r[5]:
		main.text(c, card.position + Vector2(0, 13), "ENG", 9, Color("F28C38"), 2, card.size.x - 5, true)
	var icon = Vector2(card.get_center().x, card.position.y + 31)
	c.draw_circle(icon, 22.0, Color(1, 1, 1, 0.02 if locked else 0.05))
	main.inventory.draw_item_icon(c, id, icon, 2.0)
	var n: int = int(r[4])
	if n > 1 and id != "base":
		main.text(c, icon + Vector2(14, 19), "x" + str(n), 10, Color.WHITE, 0, -1.0, true)
	main.text(c, Vector2(card.position.x, card.position.y + 64), Cs.s(r[0]), 11, Color(1, 1, 1, 0.4) if locked else Color.WHITE, 1, card.size.x)
	# the cost as small icons, red where you carry too little
	var cost = r[1]
	var parts: int = cost.size()
	var each: float = minf(38.0, (card.size.x - 4) / parts)
	var x: float = card.get_center().x - parts * each / 2
	for res in cost:
		var need: int = int(cost[res])
		var enough: bool = main.survival_feedback.craft_have_local(me, Cs.s(res)) >= need
		main.inventory.draw_item_icon(c, res, Vector2(x + 10, card.position.y + 79), 1.0)
		main.text(c, Vector2(x + 20, card.position.y + 84), Cs.s(need), 10, Color.WHITE if enough else Color(1, 0.55, 0.5))
		x += each
	if locked:
		c.draw_rect(card, Color(0, 0, 0, 0.45))
		main.text(c, Vector2(card.position.x, card.position.y + 36), "LOCKED", 11, Color(1, 1, 1, 0.7), 1, card.size.x, true)
	if busy == i:
		var f: float = clampf(float(me[27]), 0.0, 1.0)
		c.draw_rect(Rect2(card.position.x, card.end.y - 4, card.size.x * f, 4), GOLD)

func draw_craft_detail(c, me, v: Vector2, d: Rect2, mouse: Vector2, busy: int) -> void:
	var i: int = craft_sel
	var r = GameSim.RECIPES[i]
	var id = Cs.s(r[3])
	var n: int = int(r[4])
	# big icon, name, kind and what it does
	var frame_ = Rect2(d.position, Vector2(96, 96))
	c.draw_rect(frame_, Color(0.05, 0.06, 0.09, 0.7))
	c.draw_rect(frame_, GOLD, false, 1.5)
	main.inventory.draw_item_icon(c, id, frame_.get_center(), 4.0)
	var tx: float = d.position.x + 110
	main.text(c, Vector2(tx, d.position.y + 20), Cs.s(r[0]), 17, Color.WHITE, 0, -1.0, true)
	main.text(c, Vector2(tx, d.position.y + 38), self.craft_tag(id), 10, GOLD, 0, -1.0, true)
	var ly: float = d.position.y + 114
	for line in self.craft_desc(id):
		main.text(c, Vector2(d.position.x, ly), line, 11, Color(1, 1, 1, 0.85))
		ly += 16
	# how it is made: ingredients + ingredients -> result
	var hy: float = d.position.y + 172
	main.text(c, Vector2(d.position.x, hy), "HOW TO CRAFT", 11, GOLD, 0, -1.0, true)
	var x: float = d.position.x
	var y: float = hy + 12
	var cost = r[1]
	var first: bool = true
	for res in cost:
		if not first:
			main.text(c, Vector2(x, y + BOX / 2 + 8), "+", 22, Color.WHITE, 1, 22.0, true)
			x += 22
		first = false
		var need: int = int(cost[res])
		var have: int = main.survival_feedback.craft_have_local(me, Cs.s(res))
		self.craft_box(c, Rect2(x, y, BOX, BOX), res, "x" + str(need), Color(1, 1, 1, 0.25) if have >= need else Color(1, 0.5, 0.45, 0.7))
		main.text(c, Vector2(x, y + BOX + 13), "have %d" % [have], 10, Color("7FD38A") if have >= need else Color(1, 0.6, 0.55), 1, BOX)
		x += BOX
	# the arrow, with the hammer and the time it takes
	var ax: float = x + 10
	var aw: float = 58.0
	var my: float = y + BOX / 2
	var arrow = Color(1, 1, 1, 0.8)
	c.draw_line(Vector2(ax, my), Vector2(ax + aw - 8, my), arrow, 3.0)
	c.draw_colored_polygon([Vector2(ax + aw, my), Vector2(ax + aw - 10, my - 7), Vector2(ax + aw - 10, my + 7)], arrow)
	main.inventory.draw_item_icon(c, "hammer", Vector2(ax + aw / 2 - 2, my - 16), 1.0)
	main.text(c, Vector2(ax, my + 20), num(self.craft_seconds(r)) + " s", 10, Color(1, 1, 1, 0.7), 1, aw)
	x = ax + aw + 10
	# The bow is crafted empty; ammunition is a separate recipe.
	var count = "x" + str(n) if n > 1 and id != "base" else "+100" if id == "base" else ""
	self.craft_box(c, Rect2(x, y, BOX, BOX), id, count, GOLD)
	# the button, or why not
	var b: Rect2 = self.craft_button(v)
	var why = self.craft_block(me, i)
	if busy == i:
		var f: float = clampf(float(me[27]), 0.0, 1.0)
		c.draw_rect(b, Color(0.05, 0.06, 0.09, 0.95))
		c.draw_rect(Rect2(b.position, Vector2(b.size.x * f, b.size.y)), GOLD * Color(1, 1, 1, 0.75))
		c.draw_rect(b, GOLD, false, 1.5)
		main.text(c, Vector2(b.position.x, b.position.y + 25), "MAKING...  %d%%" % [int(f * 100)], 13, Color.WHITE, 1, b.size.x, true)
		return
	var can: bool = why == ""
	var hover: bool = can and b.has_point(mouse)
	c.draw_rect(b, (GOLD.lightened(0.15) if hover else GOLD) if can else Color(0.2, 0.21, 0.25, 0.9))
	c.draw_rect(b, INK if can else Color(1, 1, 1, 0.15), false, 1.0)
	main.text(c, Vector2(b.position.x, b.position.y + 25), "CRAFT  [%s]" % [key_of(i)] if can else why.to_upper(), 13, INK if can else Color(1, 1, 1, 0.55), 1, b.size.x, true)

# one picture box of the recipe: an icon at 2x with its count in the corner
func craft_box(c, r: Rect2, id, count, edge: Color) -> void:
	c.draw_rect(r, Color(0.05, 0.06, 0.09, 0.7))
	c.draw_rect(r, edge, false, 1.5)
	main.inventory.draw_item_icon(c, id, r.get_center(), 2.0)
	if count != "":
		main.text(c, Vector2(r.position.x, r.end.y - 4), count, 11, Color.WHITE, 2, r.size.x - 4, true)

# --- mouse -----------------------------------------------------------------
func craft_mouse(ev) -> bool:
	if not main.craft_open or ev.button_index != 1:
		return false
	if radio_mode:
		if ev.pressed and craft_button(Vector2(main.hud.size)).has_point(main.hud.get_local_mouse_position()):
			repair_radio()
		return true
	if craft_bag_mouse(Vector2(main.hud.size), Vector2(main.hud.get_local_mouse_position()), ev.pressed):
		return true
	if ev.pressed:
		var vs: Vector2 = Vector2(main.hud.size)
		var mouse: Vector2 = Vector2(main.hud.get_local_mouse_position())
		for t in range(3):
			if craft_tier_button(vs, t).has_point(mouse):
				select_craft_tier(t)
				return true
		for i in craft_choices():
			if self.craft_card(vs, i).has_point(mouse):
				craft_sel = i
		var me = main.snap.ps.get(main.my_id)
		if me != null and self.craft_button(vs).has_point(mouse) and self.craft_block(me, craft_sel) == "":
			main.act("craft", craft_sel)
	return true
