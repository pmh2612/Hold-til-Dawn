class_name ExplorationChestsUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.ExplorationChests.cs.
var bag_exploration_chest: int = -1

var main: Main

func _init(host: Main) -> void:
	main = host

func at_exploration_chest_local(me, id: int) -> bool:
	if me == null or int(me[5]) != 0 or me[19]:
		return false
	for c in main.supplies.supply_rows():
		if int(c[0]) == id and c[4] and Vector2(main.local_pos).distance_squared_to(Vector2(c[1])) <= GameSim.CHEST_REACH * GameSim.CHEST_REACH:
			var view = main.snap.get("chests", {}).get(main.my_id, null)
			return view != null and int(view[0]) == id
	return false

func exploration_chest_slots() -> Variant:
	var view = main.snap.get("chests", {}).get(main.my_id, null)
	return view[1] if view != null and int(view[0]) == bag_exploration_chest else []

func sync_chest_panel(me, previous) -> void:
	if me == null or me.size() <= 35 or int(me[32]) < 0:
		return
	if previous != null and previous.size() > 35 and me[35] == previous[35]:
		return
	bag_exploration_chest = int(me[32])
	main.inventory.bag_at_chest = false
	main.inventory.bag_open = true
	main.craft_open = false
	main.minimap.map_big = false
	main.build_menu.close_build()
	main.inventory.drag_from = null

# Drawn on the same whole-pixel grid as the existing item icons, without external texture loads.
static func draw_workshop_icon(c, id, at: Vector2, s: float) -> void:
	if id == "chest_key":
		_draw_workshop_icon_box(-8, -5, 8, 8, "242526", at, c, s)
		_draw_workshop_icon_box(-7, -4, 6, 6, "E3BC61", at, c, s)
		_draw_workshop_icon_box(-5, -2, 2, 2, "33372E", at, c, s)
		_draw_workshop_icon_box(-1, -2, 9, 3, "E3BC61", at, c, s)
		_draw_workshop_icon_box(4, 1, 2, 4, "E3BC61", at, c, s)
		_draw_workshop_icon_box(7, 0, 2, 3, "E3BC61", at, c, s)
		_draw_workshop_icon_box(-6, -4, 3, 1, "FFDD8B", at, c, s)
	else:
		_draw_workshop_icon_box(-8, -5, 16, 12, "242B33", at, c, s)
		_draw_workshop_icon_box(-7, -4, 14, 10, "527B89", at, c, s)
		_draw_workshop_icon_box(-6, 1, 12, 4, "345460", at, c, s)
		_draw_workshop_icon_box(-4, -8, 8, 4, "AFB6A7", at, c, s)
		_draw_workshop_icon_box(-2, -7, 4, 2, "242B33", at, c, s)
		_draw_workshop_icon_box(-7, -1, 14, 2, "B9C5B3", at, c, s)
		_draw_workshop_icon_box(2, -3, 2, 6, "E8BE6D", at, c, s)
		_draw_workshop_icon_box(0, -1, 6, 2, "E8BE6D", at, c, s)
		_draw_workshop_icon_box(-5, 2, 4, 1, "9AAEA7", at, c, s)

# local function Box of the method above
static func _draw_workshop_icon_box(x: float, y: float, w: float, h: float, hex_, at, c, s) -> void:
	c.draw_rect(Rect2((at + Vector2(x, y) * s).round(), Vector2(w, h) * s), Color(hex_))
