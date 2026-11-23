class_name GameplayHudUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.GameplayHud.cs.

# constants shared with Main
const GOLD = Main.GOLD
const T = Main.T

var main: Main
var help_open: bool = false

func _init(host: Main) -> void:
	main = host

# Owner: Pham Minh Hieu. Gameplay widgets and keys plugged into the HUD shell of Main.cs:
# context hints and gameplay key bindings.

# Context hint above the hotbar: towers, gathering, door repair and night entry.
func draw_interaction_hint(c, vs, me, ph) -> void:
	if help_open:
		return
	var hint = me[16]
	for job in main.snap.get("construction", []):
		if job[2] == main.my_id:
			hint = "Building tower: %.0f%% - stand still" % [float(job[1]) * 100]
	if hint == "" and main.build_menu.local_note_t > 0:
		hint = main.build_menu.local_note
	# a downed teammate, or a dead one (with a Revival kit in the bag)
	if hint == "" and me[5] == 0:
		for qid in main.snap.ps:
			var q = main.snap.ps[qid]
			if qid == main.my_id or q[5] == 0 or main.local_pos.distance_to(Vector2(main.shown_p.get(qid, q[2]))) > 1.5 * T:
				continue
			if q[5] == 1:
				hint = "E: revive"
			else:
				hint = "E: use Revival kit" if InventoryUi.carried(me, "revive") > 0 else "Needs a Revival kit"
			break
	# standing at the base furniture
	if hint == "" and me[5] == 0:
		if main.inventory.in_base_local(me) and SimWorld.near_radio(Vector2(main.local_pos)):
			hint = "C: radio"
		elif main.inventory.at_bench_local(me):
			hint = "C: craft"
		elif main.inventory.at_storage_local(me):
			hint = "Tab: storage"
	var gathering_hint = false
	if hint == "" and me[1] == 2 and me[5] == 0 and not me[19]:
		var tws = main.snap.get("tw", [])
		for tw in tws:
			if main.local_pos.distance_to(tw[1]) <= 1.5 * T:
				var tcap: float = float(GameSim.TOWER_HP * (0.3 if tw[3] else 1.0))
				hint = "Tower %d/%d" % [tw[2], tcap] + ("  |  E: repair" if tw[2] < tcap else "")
				break
		if hint == "" and main.free_tower_here():
			hint = "T: choose tower position (6s build)"
	if hint == "" and ph in ["day", "dusk"] and me[5] == 0:
		for nd in main.snap.nodes:
			if nd[2] > 0 and main.local_pos.distance_to(nd[1]) <= 1.5 * T:
				gathering_hint = true
				break
	if hint == "" and ph in ["day", "dusk", "night"] and me[1] == 2 and me[5] == 0 and not me[19] and not SimWorld.inside_base(main.local_pos):
		for i in 3:
			if main.local_pos.distance_to(GameSim.DOOR_POS[i]) > 1.5 * T:
				continue
			var dn = GameSim.DOOR_NAMES[i]
			var cap: float = float(GameSim.DOOR_HP * (0.3 if main.snap.broken[i] else 1.0))
			var dur: float = float(main.snap.doors[i])
			if dur >= cap:
				hint = ""
			elif main.snap.broken[i] and main.snap.inside_en:
				hint = "Clear the enemies inside first"
			elif InventoryUi.carried(me, "wood") <= 0:
				hint = "Need wood"
			elif Input.is_physical_key_pressed(69):
				hint = "Interrupted!" if main.snap.dpause[i] else "Door %s %d/%d" % [dn, dur, cap]
			else:
				hint = "E: repair door %s" % [dn]
			if ph == "night" and dur > 0:
				hint += "F: enter" if hint == "" else "  |  F: enter"
			break
	if hint == "" and ph == "night" and me[1] == 2 and me[5] == 0:
		if me[19]:
			hint = "F at a door: leave"
		else:
			for i in 3:
				if main.snap.doors[i] > 0 and main.local_pos.distance_to(GameSim.DOOR_POS[i]) <= 2.0 * T:
					hint = "F: enter"
	if hint != "":
		if not gathering_hint and me[22] != "gather":
			main.text(c, Vector2(0, vs.y - 74), hint, 13, GOLD, 1, vs.x)

# Gameplay keys (F3 and zoom stay in Main.cs). Each key sends one action string to GameSim.Action.
func gameplay_key(code) -> void:
	if help_open and code != KEY_H:
		return
	if code == KEY_E and main.craft_open and main.craft_panel.radio_mode:
		main.craft_panel.repair_radio()
		return
	if code == KEY_H:
		help_open = not help_open
		if help_open:
			main.build_menu.close_build()
			main.inventory.bag_open = false
			main.craft_open = false
			main.minimap.map_big = false
	elif code == 81:
		main.act("bandage")
	elif code == 84:
		main.build_menu.toggle_build()
	elif code == 86:
		main.act("vote")
	elif code == 71:
		main.act("give")
	elif code == 77:
		main.minimap.toggle_map()
	elif code == 67:
		var me = main.snap.ps.get(main.my_id)
		if not main.craft_open:
			var at_radio: bool = me != null and int(me[5]) == 0 and main.inventory.in_base_local(me) and SimWorld.near_radio(Vector2(main.local_pos))
			if not at_radio and not main.inventory.at_bench_local(me):
				return
			main.craft_panel.radio_mode = at_radio
			if at_radio:
				main.act("radio_open")
		main.craft_open = not main.craft_open
		main.build_menu.close_build()
		main.minimap.map_big = false
		main.craft_panel.select_craft_tier(main.craft_panel.craft_tier)
		main.inventory.bag_open = false
		main.exploration_chests.bag_exploration_chest = -1
		main.inventory.drag_from = null
	elif code == 4194306:
		# the bag opens anywhere; opened at the chest it is the chest, and closes when you walk away from it
		main.inventory.bag_open = not main.inventory.bag_open
		main.exploration_chests.bag_exploration_chest = -1
		if main.inventory.bag_open:
			for chest in main.supplies.supply_rows():
				if chest[4] and Vector2(main.local_pos).distance_squared_to(Vector2(chest[1])) <= GameSim.CHEST_REACH * GameSim.CHEST_REACH:
					main.act("open_chest", int(chest[0]))
					break
		main.inventory.bag_at_chest = main.inventory.bag_open and main.inventory.at_storage_local(main.snap.ps.get(main.my_id))
		main.inventory.drag_from = null
		main.craft_open = false
	elif code == 4194340:
		main.act("skip")
	else:
		var n: int = int(code - 49)
		if code == 48:
			n = 9
		if main.craft_open:
			if main.craft_panel.radio_mode:
				return
			# a number key shows that recipe and crafts it at once (ui/gameplay/craft_panel.gd)
			var choices = main.craft_panel.craft_choices()
			if n >= 0 and n < choices.size():
				main.craft_panel.craft_sel = choices[n]
				main.act("craft", main.craft_panel.craft_sel)
		elif n >= 0 and n < GameSim.HOTBAR:
			main.act("select", n)

# Mouse wheel picks the hotbar slot (MEC-09).
func hotbar_wheel(step: int) -> void:
	var me = main.snap.ps.get(main.my_id)
	if me != null:
		main.act("select", (int(me[25]) + step + GameSim.HOTBAR) % GameSim.HOTBAR)

func gameplay_right_click() -> void:
	if main.inventory.ui_captures_mouse():
		return
	var me = main.snap.ps.get(main.my_id)
	var slot = null if me == null else me[7][int(me[25])]
	var use: bool = slot != null and SimTacticalItems.is_tactical_use(Cs.s(slot[0]))
	main.act("use_item" if use else "flask", main.get_global_mouse_position())

func draw_controls(c, vs: Vector2, me) -> void:
	if help_open:
		var box_ = Rect2((vs.x - 470) / 2, 92, 470, 310)
		c.draw_rect(box_, Color("111820"))
		c.draw_rect(box_, GOLD, false, 2)
		main.text(c, box_.position + Vector2(16, 26), "CONTROLS - H / ESC to close", 16, GOLD)
		for i in range(PauseMenuUi.CONTROLS.size()):
			main.text(c, box_.position + Vector2(16, 57 + i * 25), PauseMenuUi.CONTROLS[i], 12, Color.WHITE)
		return
	if main.inventory.bag_open or main.build_menu.build_open:
		return
	var hint = "E interact  |  Tab bag  |  1-4 select  |  LMB use  |  M map  |  H help"
	if me[1] == 2:
		hint = "T place tower  |  Hold E repair / revive  |  Tab bag  |  M map  |  H help"
	main.text(c, Vector2(0, vs.y - 8), hint, 10, Color("D9DCD3"), 1, vs.x)
