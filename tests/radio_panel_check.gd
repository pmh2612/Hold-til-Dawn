extends Node

var checks: int = 0
var failed: bool = false

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: " + label)
	else:
		checks += 1
		print("ok   " + label)

func press(game: Main, key: int) -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	game._unhandled_input(event)

func refresh(game: Main, p) -> void:
	game.local_pos = p.pos
	game.local_tp = p.tp
	game.pending_inputs.clear()
	game.on_snap(game.sim.snapshot())
	# Main normally calls this from _process, which this fixture disables.
	game.inventory.keep_panels_in_reach(game.snap.ps.get(game.my_id))

func _ready() -> void:
	var game = Main.new()
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sim = GameSim.new()
	var s: GameSim = game.sim
	s.add_player(1, "Engineer", 2)
	s.start_match()
	game.my_id = 1
	var p = s.players[1]
	p.pos = GameSim.RADIO_POS + Vector2(0, 24)
	refresh(game, p)
	press(game, KEY_E)
	check(s.radio_builder == null, "E beside a closed radio panel does not start repairs")
	press(game, KEY_C)
	refresh(game, p)
	check(game.craft_open and game.craft_panel.radio_mode, "C beside the radio opens its crafting-style panel")
	check(not game.craft_panel.radio_block(game.snap.ps[1]).is_empty(), "the repair button is disabled with missing components")
	press(game, KEY_E)
	check(s.radio_builder == null, "E cannot repair with missing components")
	press(game, KEY_1)
	check(p.craft_idx < 0, "radio panel number keys cannot trigger workbench recipes")
	game.inventory.keep_panels_in_reach(game.snap.ps[1])
	check(game.craft_open, "the radio panel stays open at its own table")
	press(game, KEY_C)
	check(not game.craft_open, "C closes the radio panel")
	s.set_count(p, GameSim.COMPONENT_IDS[0], 1)
	press(game, KEY_C)
	refresh(game, p)
	check(s.radio_parts_placed == [0, 0, 0] and s.count(p, GameSim.COMPONENT_IDS[0]) == 1 and s.radio_builder == null, "opening C does not auto-install carried parts")
	press(game, KEY_E)
	refresh(game, p)
	check(s.radio_parts_placed == [1, 0, 0] and s.count(p, GameSim.COMPONENT_IDS[0]) == 0 and s.radio_builder == null, "pressing E at radio panel inserts carried parts without starting repair")
	press(game, KEY_C)
	s.set_count(p, GameSim.COMPONENT_IDS[1], 1)
	s.set_count(p, GameSim.COMPONENT_IDS[2], 1)
	press(game, KEY_C)
	refresh(game, p)
	check(s.radio_parts_placed == [1, 0, 0], "remaining carried parts wait for explicit insertion")
	press(game, KEY_E)
	refresh(game, p)
	check(s.radio_parts_placed == [1, 1, 1] and s.count(p, GameSim.COMPONENT_IDS[1]) == 0 and s.count(p, GameSim.COMPONENT_IDS[2]) == 0 and game.craft_panel.radio_block(game.snap.ps[1]) == "", "inserting all three parts enables E repair")
	press(game, KEY_E)
	check(s.radio_builder == 1 and s.radio_build_t == 0 and not p.inter, "one E press starts the five-second job without held interaction")
	for i in range(20):
		s.tick_players(0.1)
	check(not s.radio_built and is_equal_approx(s.radio_build_t, 2), "repair advances automatically while E is released")
	s.action(1, "radio_repair", null)
	check(is_equal_approx(s.radio_build_t, 2), "repeated E cannot accelerate or restart the current job")
	p.pos += Vector2(8, 0)
	s.tick_players(0.1)
	check(s.radio_builder == null and s.radio_build_t == 0 and s.radio_parts_placed == [1, 1, 1], "movement cancels progress and preserves installed components")
	refresh(game, p)
	press(game, KEY_E)
	s.tick_players(0.5)
	p.invuln = 0
	s.hurt(p, 2)
	check(s.radio_builder == null and not s.radio_built, "taking damage interrupts radio repairs")
	refresh(game, p)
	press(game, KEY_E)
	p.atk = true
	s.tick_players(0.1)
	check(s.radio_builder == null, "attacking interrupts radio repairs")
	p.atk = false
	refresh(game, p)
	press(game, KEY_E)
	for i in range(49):
		s.tick_players(0.1)
	check(not s.radio_built, "radio does not complete before five seconds")
	s.tick_players(0.1)
	refresh(game, p)
	check(s.radio_built and s.radio_builder == null, "radio comes online after five seconds without holding E")
	check(game.craft_panel.radio_block(game.snap.ps[1]) == "Radio online", "completed radio disables further repairs")
	press(game, KEY_ESCAPE)
	check(not game.craft_open and not game.pause_menu.paused, "Esc closes the station panel before pausing")
	p.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	refresh(game, p)
	press(game, KEY_C)
	check(game.craft_open and not game.craft_panel.radio_mode, "C at the workbench still opens ordinary recipes")
	var panel = game.craft_panel
	var seen: Array = []
	var vs = Vector2(960, 540)
	for category in range(3):
		panel.select_craft_category(category)
		var choices: Array = panel.craft_choices()
		check(not choices.is_empty() and choices.has(panel.craft_sel), "category %d selects a visible recipe" % category)
		for k in range(choices.size()):
			var i: int = choices[k]
			var kind: String = SimInventory.kind_of(GameSim.RECIPES[i][3])
			check(CraftPanelUi.category_of(i) == category and not seen.has(i), "recipe %d appears once in its correct category" % i)
			seen.append(i)
			check(panel.key_of(i) == str(k + 1), "recipe %d shortcut matches its visible position" % i)
			var rect: Rect2 = panel.craft_card(vs, i)
			check(rect.position.y > panel.craft_category_button(vs, category).end.y and rect.end.y < panel.craft_panel_rect(vs).position.y + 330 and rect.end.x < panel.craft_detail(panel.craft_panel_rect(vs)).position.x, "recipe %d fits between the two tabs and bag" % i)
			for other in choices:
				check(other == i or not rect.intersects(panel.craft_card(vs, other)), "recipe %d does not overlap recipe %d" % [i, other])
	check(seen.size() == GameSim.RECIPES.size() and seen.size() == 18, "all 18 recipes are visible across Weapons, Equipment and Armor, independent of unlock level")
	check(game.inventory.item_label(["starter_bow", 1]).contains("Infinite") and game.inventory.item_label(["bow", 1, 7]).contains("7 / 30"), "starter and crafted bow show distinct ammunition information")
	check(game.inventory.item_label(["explosive_arrow", 3]).contains("LMB") and panel.craft_desc("explosive_arrow").size() == 2, "explosive ammo explains bow requirement and firing control")
	panel.select_craft_category(0)
	p.inv = SimInventory.empty_slots(8)
	p.note = ""
	p.note_t = 0
	s.unlock = 0
	refresh(game, p)
	press(game, KEY_1)
	check(p.craft_idx < 0 and p.note == "", "unaffordable craft shortcut stays disabled without a Need-materials message")
	s.action(1, "craft", 0)
	check(p.craft_idx < 0 and p.note == "", "a stale craft request is rejected silently without spending materials")
	for id in GameSim.RES:
		s.set_count(p, id, 20)
	refresh(game, p)
	press(game, KEY_6)
	check(p.craft_idx < 0 and p.note == "" and s.count(p, "wood") == 20, "locked-day recipe cannot be crafted by its shortcut even with enough materials")
	s.unlock = 0
	refresh(game, p)
	press(game, KEY_4)
	check(p.craft_idx == 2, "bow is craftable from day one without titanium")
	s.tick_craft(p, 3)
	check(s.count(p, "bow") == 1 and s.count(p, "wood") == 12 and s.count(p, "stone") == 16 and s.count(p, "titanium") == 20, "bow charges 8 wood + 4 stone and zero titanium")
	p.note = ""
	p.note_t = 0
	refresh(game, p)
	game.craft_panel.select_craft_category(1)
	press(game, KEY_4)
	check(p.craft_idx < 0 and p.note == "" and s.count(p, "herb") == 20, "Engineer flask shortcut stays disabled silently despite sufficient materials")
	p.role = 1
	refresh(game, p)
	press(game, KEY_4)
	check(p.craft_idx == 13, "Healer flask shortcut enables at the unlocked workbench")
	s.tick_craft(p, 3)
	check(s.count(p, "healing_flask") == 1 and s.count(p, "herb") == 14 and s.count(p, "titanium") == 18, "Healer crafts one flask with the normal recipe cost")
	p.role = 2
	p.inv = SimInventory.empty_slots(8)
	s.set_count(p, "wood", 7)
	s.set_count(p, "stone", 5)
	check(p.inv[0] == null and p.inv[4] == ["wood", 7] and p.inv[5] == ["stone", 5], "raw resources land in the inner bag rather than hotbar slots 1-4")
	refresh(game, p)
	var slots = game.craft_panel.craft_bag_slots(Vector2(960, 540))
	check(slots.size() == 8 and slots[7].end.x < game.craft_panel.craft_detail(game.craft_panel.craft_panel_rect(Vector2(960, 540))).position.x, "craft panel fits all eight bag slots beside the recipe detail")
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[4].get_center(), true)
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[5].get_center(), false)
	check(p.inv[4] == ["stone", 5] and p.inv[5] == ["wood", 7] and game.inventory.drag_from == null, "dragging inside the craft panel reorders actual inventory without losing materials")
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[1].get_center(), true)
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[1].get_center(), false)
	check(p.sel == 1, "clicking an embedded hotbar slot selects it")
	panel.select_craft_category(0)
	p.inv = SimInventory.empty_slots(8)
	s.unlock = 0
	s.set_count(p, "wood", 6)
	s.set_count(p, "stone", 4)
	refresh(game, p)
	press(game, KEY_1)
	check(p.craft_idx == 16, "first Weapons shortcut starts the day-one hammer recipe")
	s.tick_craft(p, 3)
	check(s.count(p, "hammer") == 1 and s.count(p, "wood") == 0 and s.count(p, "stone") == 0, "hammer crafts in three seconds for six wood and four stone")
	panel.select_craft_category(1)
	p.inv = SimInventory.empty_slots(8)
	s.set_count(p, "wood", 2)
	s.set_count(p, "stone", 2)
	refresh(game, p)
	press(game, KEY_6)
	check(p.craft_idx == 15, "sixth Equipment shortcut starts the chest key recipe")
	s.tick_craft(p, 3)
	press(game, KEY_C)
	p.pos = GameSim.RADIO_POS + Vector2(0, 24)
	refresh(game, p)
	press(game, KEY_C)
	p.pos = Vector2(0, 300)
	refresh(game, p)
	check(not game.craft_open, "walking away closes the radio panel")
	s.radio_built = false
	s.radio_parts_placed = [0, 0, 0]
	s.action(1, "radio_open", null)
	s.action(1, "radio_repair", null)
	check(s.radio_parts_placed == [0, 0, 0] and s.radio_builder == null, "remote requests cannot install parts or start repairs")
	s.k = 1
	s.dawn()
	check(s.snapshot().msg == "", "dawn uses the clock instead of a duplicate phase banner")
	SimPhases.dusk(s)
	check(s.snapshot().msg == "", "dusk does not add phase chatter")
	s.night()
	s.night_spawned = s.night_quota
	s.enemies.clear()
	s.check_end(0.05)
	check(s.phase == "day" and s.k == 2 and s.snapshot().msg == "", "clearing a night still advances dawn without Dawn comes early text")
	check_inventory_upgrades(game, p)
	game.rivers.build_river_looks()
	for r in game.rivers.river_looks:
		var points = r.water_mesh.points
		var colors = r.water_mesh.colors
		var transparent_caps: bool = true
		for i in range(5):
			transparent_caps = transparent_caps and colors[i].a == 0 and colors[colors.size() - 1 - i].a == 0
		check(transparent_caps, "both sea endpoints fade fully before the river mesh ends")
		var transition_samples: int = 0
		var dry_land_clear: bool = true
		for i in range(points.size()):
			if colors[i].a > 0 and colors[i].a < 1:
				transition_samples += 1
			if IslandMap.depth(points[i]) > 0 and IslandMap.river_dist(points[i]) > IslandMap.RIVER_HALF + 8:
				dry_land_clear = dry_land_clear and colors[i].a < 0.01
		check(transition_samples > 10 and dry_land_clear, "estuary water blends into the sea without widening the walkable land channel")
	game.queue_free()
	await get_tree().process_frame
	print("RADIO PANEL FAILED" if failed else "RADIO PANEL ALL OK: %d checks" % checks)
	get_tree().quit(1 if failed else 0)

func check_inventory_upgrades(game: Main, p) -> void:
	var s: GameSim = game.sim
	var panel = game.craft_panel
	s.phase = "day"
	s.unlock = 0
	p.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	p.role = 2
	p.inv = SimInventory.empty_slots(8)
	p.bag_tier = 0
	p.inv[0] = ["bandage", 3]
	for res in GameSim.RES:
		s.set_count(p, res, 20)
	s.craft(p, 17)
	s.tick_craft(p, 3)
	check(p.bag_tier == 1 and p.inv.size() == 12, "cargo frame expands inventory from eight to twelve slots")
	check(p.inv[0] == ["bandage", 3] and s.count(p, "cargo_frame") == 0, "cargo frame equips without losing items or consuming a slot")
	check(GameSim.BAG_ITEMS == ["", "cargo_frame"] and GameSim.ITEMS.keys().filter(func(id): return SimInventory.kind_of(id) == "bag").size() == 1, "exactly one bag upgrade (cargo_frame) exists in the item catalog")
	check(not s.can_craft(p, 17, false), "equipped cargo frame cannot be crafted repeatedly")
	var contents: Array = p.inv.duplicate(true)
	SimInventory.equip_bag(p, "cargo_frame")
	check(p.inv.size() == 12 and p.inv == contents, "equipping the cargo frame twice adds no slots and changes no items")
	# Hotbar priority check: weapons/equipment prefer 1-4, raw resources prefer inner bag 5+.
	p.inv = SimInventory.empty_slots(12)
	s.add_item(p, "wood", 5)
	s.add_item(p, "stone", 4)
	s.add_item(p, "herb", 3)
	s.add_item(p, "titanium", 2)
	check(p.inv[0] == null and p.inv[1] == null and p.inv[2] == null and p.inv[3] == null and p.inv[4] == ["wood", 5] and p.inv[5] == ["stone", 4] and p.inv[6] == ["herb", 3] and p.inv[7] == ["titanium", 2], "farming wood, stone, herb, titanium routes them into the inner bag")
	s.add_item(p, "stone_spear", 1)
	s.add_item(p, "bandage", 2)
	s.add_item(p, "chest_key", 1)
	check(p.inv[0] == ["stone_spear", 1] and p.inv[1] == ["bandage", 2] and p.inv[2] == ["chest_key", 1], "weapons and equipment fill hotbar slots 1-4 first")
	refresh(game, p)
	var slots: Array = panel.craft_bag_slots(Vector2(960, 540))
	check(slots.size() == 12 and slots[-1].end.y < panel.craft_panel_rect(Vector2(960, 540)).end.y, "craft panel fits all twelve backpack slots")
	game.inventory.bag_open = true
	var bag_slots: Array = game.inventory.bag_slots(Vector2(960, 540), game.snap.ps[1])
	check(bag_slots.filter(func(slot): return slot[0] == "inv").size() == 12, "Tab bag shows all twelve slots")
	game.inventory.bag_open = false
	p.inv[11] = ["herb", 1]
	p.inv[10] = null
	s.move_slot(p, ["inv", 11, "inv", 10])
	check(p.inv[10] == ["herb", 1] and p.inv[11] == null, "the last expanded slot supports actual transfers")
	p.inv = SimInventory.empty_slots(12)
	p.inv[0] = ["bow", 1, 12]
	p.inv[1] = ["arrow", 20]
	s.move_slot(p, ["inv", 1, "inv", 0])
	check(p.inv[0] == ["bow", 1, 30] and p.inv[1] == ["arrow", 2], "dragging arrows onto a bow fills it to 30 and keeps the remainder")
	s.move_slot(p, ["inv", 1, "inv", 0])
	check(p.inv[0] == ["bow", 1, 30] and p.inv[1] == ["arrow", 2], "a full bow never swaps with its ammo stack")
	p.sel = 0
	p.weapon = "bow"
	p.atk_cd = 0
	s.attack(p)
	check(SimInventory.loaded(p.inv[0]) == 29 and p.inv[1] == ["arrow", 2], "shooting decrements the selected bow counter before loose ammo")
	p.inv[0] = ["starter_bow", 1]
	s.move_slot(p, ["inv", 1, "inv", 0])
	check(p.inv[0] == ["starter_bow", 1] and p.inv[1] == ["arrow", 2], "Scout starter bow never accepts or swaps with normal arrows")
	p.weapon = "starter_bow"
	p.atk_cd = 0
	s.attack(p)
	check(p.inv[1] == ["arrow", 2], "Scout infinite bow does not consume normal arrows")
	game.craft_open = false
	refresh(game, p)
	for slot in range(4):
		var centre := Vector2((960 - 188) / 2.0 + slot * 48 + 22, 540 - 32)
		check(game.inventory.begin_hotbar_selection(Vector2(960, 540), centre) and p.sel == slot, "clicking hotbar slot %d selects it" % (slot + 1))
		check(not game.inventory.filter_primary_attack(true), "holding a hotbar click cannot attack or use an item")
		game.inventory.filter_primary_attack(false)
		check(game.inventory.filter_primary_attack(true), "a fresh world click can attack after releasing the hotbar")
	game.craft_open = true
	check(not game.inventory.begin_hotbar_selection(Vector2(960, 540), Vector2(408, 508)), "craft panel captures clicks before the world hotbar")
	game.craft_open = false
	p.pos = Vector2(0, 640)
	for phase_ in ["day", "dusk", "night"]:
		for role in range(3):
			s.phase = phase_
			p.role = role
			p.inv = SimInventory.empty_slots(12)
			s.set_count(p, "herb", 4)
			s.set_count(p, "titanium", 4)
			refresh(game, p)
			press(game, KEY_C)
			check(game.craft_open and panel.field_mode and panel.craft_sel == 9, "C outside base opens field Revival kit for %s during %s" % [GameSim.ROLES[role], phase_])
			check(panel.craft_block(game.snap.ps[1], 9) == "" and not s.can_craft(p, 16, false), "field crafting permits revival while other equipment still needs the bench")
			s.craft(p, 9)
			s.tick_craft(p, 3)
			check(s.count(p, "revive") == 1 and s.count(p, "herb") == 0, "Revival kit completes outside base by day or night for all roles")
			press(game, KEY_C)
	s.craft(p, 9)
	SimPlayers.reset_player(s, p)
	check(p.bag_tier == 0 and p.inv.size() == 8, "new player reset restores the starting eight-slot bag")
