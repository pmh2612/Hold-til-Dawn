class_name InventoryUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.Inventory.cs.
# Owner: Pham Minh Hieu. Hotbar, inventory and storage panels with drag and drop (MEC-09, HUD element 8),
# and the item art: icons from art/items (tools/PixelItems.cs), projectiles from art/fx.
const SLOT: float = 44.0
const SLOT_GAP: float = 4.0
const ITEM_ART = "res://art/items/"
const FX_ART = "res://art/fx/"
var item_tex = {}
var fx_tex = {}

# constants shared with Main
const GOLD = Main.GOLD
const INK = Main.INK
const NEON_RED = Main.NEON_RED
const RADIO_PART_EDGE = Color("F16A61")

var main: Main

func _init(host: Main) -> void:
	main = host

func load_item_art() -> void:
	for id in GameSim.ITEMS:
		if id == "chest_key":
			continue  # native pixel icons below
		# the Revival kit's art is named after the kit, its item id is the recipe's ("revive")
		item_tex[id] = load(ITEM_ART + ("revival_kit" if id == "revive" else id) + ".png")
	# the generator repair makes no item but has an icon too (workbench panel), under its recipe id
	item_tex["base"] = load(ITEM_ART + "base_repair.png")
	for n in ["arrow", "spit", "orb", "explosive_arrow"]:
		fx_tex[n] = load(FX_ART + Cs.s(n) + ".png")

# An item icon centred on a point, at a whole-number scale so the pixels stay square.
func draw_item_icon(canvas, id, centre: Vector2, scale: float) -> void:
	var item_id = Cs.s(id)
	if item_id == "chest_key":
		ExplorationChestsUi.draw_workshop_icon(canvas, item_id, centre, scale)
		return
	var rescue: int = SimSupplies.rescue_kind(item_id)
	var component: int = GameSim.COMPONENT_IDS.find(item_id)
	if rescue >= 0 or component >= 0:
		if component >= 0:
			SuppliesView.draw_component_icon(canvas, component, centre, scale)
		else:
			SuppliesView.draw_supply_icon(canvas, rescue, centre, scale)
		return
	var tex = item_tex.get(id)
	if tex == null:
		return
	var size: Vector2 = tex.get_size() * scale
	canvas.draw_texture_rect(main.pixel(tex), Rect2((centre - size / 2).round(), size), false)

# A projectile sprite in the world, turned to its flight direction.
func draw_fx(n, pos: Vector2, angle: float) -> void:
	var tex = fx_tex.get(n)
	if tex == null:
		return
	main.draw_set_transform(pos, angle, Vector2.ONE)
	main.draw_texture(tex, (-tex.get_size() / 2).round())
	main.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var bag_open = false
# [box, index] of the slot being dragged, or null
var drag_from
static var ARMOUR_SHORT = ["No armour", "Light", "Stone", "Titanium"]

# The stats beside the HP hexagon: the armour worn, as its icon and name (armour takes no bag slot), then the
# bandages and healing flasks in the bag with their counts, and the Healer's own flasks.
func draw_stat_slots(c, vs: Vector2, me) -> void:
	var cw = c
	var x: float = 92
	var y: float = vs.y - 38
	var tier: int = int(me[9])
	_draw_stat_slots_box(78, tier > 0, c, x, y)
	if tier > 0:
		self.draw_item_icon(cw, GameSim.ARMOUR_ITEMS[tier], Vector2(x + 13, y + 13), 1.0)
	main.text(cw, Vector2(x + (26 if tier > 0 else 6), y + 17), ARMOUR_SHORT[tier], 10, Color.WHITE if tier > 0 else Color(1, 1, 1, 0.45))
	x += 82
	for id in ["bandage", "healing_flask"]:
		var n: int = carried(me, id)
		_draw_stat_slots_box(36, n > 0, c, x, y)
		self.draw_item_icon(cw, id, Vector2(x + 13, y + 13), 1.0)
		if n <= 0:
			c.draw_rect(Rect2(x + 1, y + 1, 34, 24), Color(0.08, 0.07, 0.1, 0.6))
		main.text(cw, Vector2(x + 18, y + 23), Cs.s(n), 10, Color.WHITE if n > 0 else Color(1, 1, 1, 0.45), 2, 16)
		x += 40
	if me[1] == 1:
		# the Healer's own flasks (not an item)
		_draw_stat_slots_box(36, me[10] > 0, c, x, y)
		main.hex(cw, Vector2(x + 18, y + 13), 9, Color("3DBE5A"))
		main.text(cw, Vector2(x, y + 17), "+%d" % [me[10]], 10, Color.WHITE, 1, 36)

# local function Box of the method above
func _draw_stat_slots_box(w: float, lit: bool, c, x, y) -> void:
	var r = Rect2(x, y, w, 26)
	c.draw_rect(r, Color(0.08, 0.07, 0.1, 0.85))
	c.draw_rect(r, Color(GOLD, 0.8) if lit else Color(1, 1, 1, 0.25), false, 1)

static func carried(me, id) -> int:
	return 0 if me == null else SimInventory.count_in(me[7], id)

# Crafting is at the workbench, storage at the chest, both by the base's north wall: inside the base by day, or
# as the Engineer inside at night (the server checks the same, GameSim.AtBench / AtStorage).
func in_base_local(me) -> bool:
	var ph = main.snap.get("ph", "")
	return me != null and (SimWorld.inside_base(main.local_pos) if ph == "day" or ph == "dusk" else ph == "night" and me[19])

func at_bench_local(me) -> bool:
	return self.in_base_local(me) and SimWorld.near_bench(Vector2(main.local_pos))

func at_storage_local(me) -> bool:
	return self.in_base_local(me) and SimWorld.near_storage(Vector2(main.local_pos))

# Panels close by themselves out of reach: the workbench tab, and the bag when it was opened as the chest. The tab
# keeps half a tile of slack past the reach, so a step back while crafting does not flick it shut.
var bag_at_chest: bool = false
const PANEL_SLACK: float = 0.5 * GameSim.T

func keep_panels_in_reach(me) -> void:
	if me == null:
		return
	var in_base: bool = self.in_base_local(me)
	if bag_open and main.exploration_chests.bag_exploration_chest >= 0 and not main.exploration_chests.at_exploration_chest_local(me, main.exploration_chests.bag_exploration_chest):
		bag_open = false
		main.exploration_chests.bag_exploration_chest = -1
		drag_from = null
	var station: Vector2 = GameSim.RADIO_POS if main.craft_panel.radio_mode else GameSim.WORKBENCH_POS
	var reach: float = GameSim.RADIO_REACH if main.craft_panel.radio_mode else GameSim.BENCH_REACH
	if main.craft_open and (int(me[5]) != 0 or not (in_base and Vector2(main.local_pos).distance_to(station) <= reach + PANEL_SLACK)):
		main.craft_open = false
		drag_from = null
	# the chest has no slack: past its reach its slots go (the server refuses them there too)
	if bag_open and bag_at_chest and not self.at_storage_local(me):
		bag_open = false
		bag_at_chest = false
		drag_from = null
	# an item picked up from the chest is let go once the chest is out of reach
	if drag_from != null and drag_from[0] == "sto" and not self.at_storage_local(me):
		drag_from = null

func ui_captures_mouse() -> bool:
	return bag_open or main.craft_open or main.build_menu.build_open or main.pause_menu.paused or main.gameplay_hud.help_open

func draw_slot(c, r: Rect2, s, selected: bool, key_) -> void:
	var radio_part: bool = s != null and GameSim.COMPONENT_IDS.has(Cs.s(s[0]))
	c.draw_rect(r, Color("351E26") if radio_part else Color(0.05, 0.06, 0.09, 0.85))
	c.draw_rect(r, RADIO_PART_EDGE if radio_part else GOLD if selected else Color(1, 1, 1, 0.18), false, 3.0 if radio_part else 2.0 if selected else 1.0)
	if radio_part:
		c.draw_rect(r.grow(-4), Color(RADIO_PART_EDGE, 0.3), false, 1)
	if key_ != "":
		main.text(c, r.position + Vector2(3, 10), key_, 9, Color(1, 1, 1, 0.5))
	if s == null:
		return
	self.draw_item_icon(c, s[0], r.get_center(), 2.0)
	if s[1] > 1:
		main.text(c, Vector2(r.position.x, r.end.y - 3), Cs.s(s[1]), 11, Color.WHITE, 2, r.size.x - 3, true)
	if SimInventory.is_bow(s):
		# the arrows loaded in the bow: a small arrow and the count, red when it is empty
		var n: int = SimInventory.loaded(s)
		self.draw_item_icon(c, "arrow", r.end - Vector2(30, 8), 1.0)
		main.text(c, Vector2(r.position.x, r.end.y - 3), Cs.s(n), 11, GOLD if n > 0 else NEON_RED, 2, r.size.x - 3, true)
	elif s[0] == "starter_bow":
		main.text(c, Vector2(r.position.x, r.end.y - 3), "INF", 9, GOLD, 2, r.size.x - 3, true)

func item_label(s) -> String:
	var name_: String = SimInventory.item_name(s[0])
	if s[0] == "starter_bow":
		return name_ + " | Infinite arrows"
	if s[0] == "bow":
		return name_ + " | %d / %d arrows" % [SimInventory.loaded(s), SimInventory.QUIVER]
	if s[0] == "explosive_arrow":
		return name_ + " | Bow in bag + LMB"
	return name_

# HUD element 8: the first four inventory slots, keys 1-4 or the mouse wheel.
func draw_hotbar(c, vs, me) -> void:
	var w: float = GameSim.HOTBAR * SLOT + (GameSim.HOTBAR - 1) * SLOT_GAP
	var x0: float = (vs.x - w) / 2
	var y0: float = vs.y - SLOT - 10
	for i in range(GameSim.HOTBAR):
		self.draw_slot(c, Rect2(x0 + i * (SLOT + SLOT_GAP), y0, SLOT, SLOT), me[7][i], i == int(me[25]), Cs.s(i + 1))
	var selected = me[7][int(me[25])]
	if selected != null and (SimTacticalItems.is_tactical_use(Cs.s(selected[0])) or selected[0] in ["bow", "starter_bow"]):
		main.text(c, Vector2(0, y0 - 8), item_label(selected), 11, GOLD, 1, vs.x)
	if me.size() > 30 and me[30]:
		main.text(c, Vector2(0, y0 - 42), "HASTE +20%", 11, Color("F0C76B"), 1, vs.x)
	if me.size() > 31 and float(me[31]) > 0:
		main.text(c, Vector2(0, y0 - 30), "Repairing", 11, GOLD, 1, vs.x)
		c.draw_rect(Rect2(vs.x / 2 - 60, y0 - 22, 120, 5), INK)
		c.draw_rect(Rect2(vs.x / 2 - 60, y0 - 22, 120 * (1 - float(me[31]) / 3.0), 5), GOLD)
	# bandage and craft channels above the hotbar
	if me[26] >= 0:
		var r = GameSim.RECIPES[int(me[26])]
		main.text(c, Vector2(0, y0 - 30), "Crafting %s..." % [r[0]], 11, GOLD, 1, vs.x)
		c.draw_rect(Rect2(vs.x / 2 - 60, y0 - 24, 120, 5), INK)
		c.draw_rect(Rect2(vs.x / 2 - 60, y0 - 24, 120 * clampf(me[27], 0, 1), 5), GOLD)

# [box, index, rect] for every slot of the open bag panel: inventory (4 x 2) and, at the chest, storage (8 x 5).
func bag_slots(vs, me) -> Variant:
	var out = []
	var expedition: bool = main.exploration_chests.bag_exploration_chest >= 0 and main.exploration_chests.at_exploration_chest_local(me, main.exploration_chests.bag_exploration_chest)
	var sto: bool = expedition or self.at_storage_local(me)
	var columns: int = 4 if expedition else 8
	var count: int = GameSim.EXPLORATION_CHEST_SLOTS if expedition else GameSim.STORAGE_SLOTS
	var inv_w: float = 4 * SLOT + 3 * SLOT_GAP
	var sto_w: float = columns * SLOT + (columns - 1) * SLOT_GAP if sto else 0.0
	var gap: float = 28.0 if sto else 0.0
	var x0: float = (vs.x - (inv_w + gap + sto_w)) / 2
	var y0: float = vs.y / 2 - 110
	for i in range(GameSim.INV_SLOTS):
		# the hotbar row sits apart at the top
		var y: float = y0 + i / 4 * (SLOT + SLOT_GAP) + (8.0 if i >= 4 else 0.0)
		out.append(["inv", i, Rect2(x0 + i % 4 * (SLOT + SLOT_GAP), y, SLOT, SLOT)])
	if sto:
		var sx: float = x0 + inv_w + gap
		var i: int = 0
		while i < count:
			out.append(["chest:" + str(main.exploration_chests.bag_exploration_chest) if expedition else "sto", i, Rect2(sx + i % columns * (SLOT + SLOT_GAP), y0 + i / columns * (SLOT + SLOT_GAP), SLOT, SLOT)])
			i += 1
	return out

func draw_bag(c, vs, me) -> void:
	if not bag_open:
		return
	var slots = self.bag_slots(vs, me)
	var all: Rect2 = Rect2(slots[0][2])
	for s in slots:
		all = all.merge(s[2])
	# wide enough for the two help lines under the slots
	var frame_: Rect2 = all.grow(14).grow_side(SIDE_TOP, 16).grow_side(SIDE_BOTTOM, 30)
	var extra: float = maxf(0.0, (330.0 - frame_.size.x) / 2)
	frame_ = frame_.grow_individual(extra, 0, extra, 0)
	c.draw_rect(frame_, Color("10151C"))
	c.draw_rect(frame_, GOLD, false, 1.5)
	main.text(c, all.position + Vector2(0, -14), "YOUR BAG", 11, GOLD, 0, -1.0, true)
	main.text(c, Vector2(frame_.position.x, all.end.y + 28), "Drag: transfer | Tab: close", 10, Color(1, 1, 1, 0.6), 1, frame_.size.x)
	if slots.size() > GameSim.INV_SLOTS:
		var first: Rect2 = Rect2(slots[GameSim.INV_SLOTS][2])
		main.text(c, first.position + Vector2(0, -14), "CHEST" if main.exploration_chests.bag_exploration_chest >= 0 else "SHARED STORAGE", 11, GOLD, 0, -1.0, true)
	var sto = main.exploration_chests.exploration_chest_slots() if main.exploration_chests.bag_exploration_chest >= 0 else main.snap.get("sto", [])
	var mouse: Vector2 = Vector2(main.hud.get_local_mouse_position())
	for s in slots:
		var is_inv: bool = s[0] == "inv"
		var i: int = int(s[1])
		var item = me[7][i] if is_inv else sto[i] if i < sto.size() else null
		var dragged: bool = drag_from != null and drag_from[0] == s[0] and drag_from[1] == i
		self.draw_slot(c, s[2], null if dragged else item, is_inv and i == int(me[25]), Cs.s(i + 1) if is_inv and i < GameSim.HOTBAR else "")
		if item != null and Rect2(s[2]).has_point(mouse) and drag_from == null:
			main.text(c, Vector2(frame_.position.x, all.end.y + 14), item_label(item), 11, Color.WHITE, 1, frame_.size.x)
	if drag_from != null:
		var box_ = me[7] if drag_from[0] == "inv" else sto
		var i: int = int(drag_from[1])
		if i < box_.size():
			self.draw_slot(c, Rect2(mouse - Vector2.ONE * (SLOT / 2), Vector2.ONE * SLOT), box_[i], true, "")

func slot_at(vs, me, at: Vector2) -> Variant:
	for s in self.bag_slots(vs, me):
		if Rect2(s[2]).has_point(at):
			return s
	return null

# Left mouse in the bag panel: press picks a slot up, release drops it on another slot.
func inventory_mouse(ev) -> bool:
	if not bag_open or ev.button_index != 1:
		return false
	var me = main.snap.ps.get(main.my_id)
	if me == null:
		return false
	var vs = main.hud.size
	var hit = self.slot_at(vs, me, Vector2(main.hud.get_local_mouse_position()))
	if ev.pressed:
		drag_from = [hit[0], hit[1]] if hit != null else null
		return true
	if drag_from != null and hit != null:
		main.act("move_item", [drag_from[0], drag_from[1], hit[0], hit[1]])
	drag_from = null
	return true
