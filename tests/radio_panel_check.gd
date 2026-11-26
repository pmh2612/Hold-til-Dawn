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
	s.rescue_components = [1, 0, 0]
	press(game, KEY_C)
	refresh(game, p)
	check(s.radio_parts_placed == [1, 0, 0] and s.radio_builder == null, "opening C installs available parts without starting a repair")
	press(game, KEY_C)
	s.rescue_components = [1, 1, 1]
	press(game, KEY_C)
	refresh(game, p)
	check(s.radio_parts_placed == [1, 1, 1] and game.craft_panel.radio_block(game.snap.ps[1]) == "", "all three parts enable E repair")
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
	game.craft_panel.select_craft_tier(1)
	refresh(game, p)
	press(game, KEY_2)
	check(p.craft_idx < 0 and p.note == "" and s.count(p, "wood") == 20, "locked-day recipe cannot be crafted by its shortcut even with enough materials")
	s.unlock = 1
	refresh(game, p)
	press(game, KEY_2)
	check(p.craft_idx == 2, "the same craft shortcut enables after its tier unlocks")
	s.tick_craft(p, 3)
	check(s.count(p, "bow") == 1 and s.count(p, "wood") == 14 and s.count(p, "titanium") == 18, "enabled recipe crafts normally and charges its material cost")
	p.note = ""
	p.note_t = 0
	refresh(game, p)
	press(game, KEY_5)
	check(p.craft_idx < 0 and p.note == "" and s.count(p, "herb") == 20, "Engineer flask shortcut stays disabled silently despite sufficient materials")
	p.role = 1
	refresh(game, p)
	press(game, KEY_5)
	check(p.craft_idx == 13, "Healer flask shortcut enables at the unlocked workbench")
	s.tick_craft(p, 3)
	check(s.count(p, "healing_flask") == 1 and s.count(p, "herb") == 14 and s.count(p, "titanium") == 16, "Healer crafts one flask with the normal recipe cost")
	p.role = 2
	game.craft_panel.select_craft_tier(0)
	p.inv = SimInventory.empty_slots(8)
	s.set_count(p, "wood", 7)
	s.set_count(p, "stone", 5)
	refresh(game, p)
	var slots = game.craft_panel.craft_bag_slots(Vector2(960, 540))
	check(slots.size() == 8 and slots[7].end.x < game.craft_panel.craft_detail(game.craft_panel.craft_panel_rect(Vector2(960, 540))).position.x, "craft panel fits all eight backpack slots beside the recipe detail")
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[0].get_center(), true)
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[1].get_center(), false)
	check(p.inv[0] == ["stone", 5] and p.inv[1] == ["wood", 7] and game.inventory.drag_from == null, "dragging inside the craft panel reorders actual inventory without losing materials")
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[1].get_center(), true)
	game.craft_panel.craft_bag_mouse(Vector2(960, 540), slots[1].get_center(), false)
	check(p.sel == 1, "clicking an embedded hotbar slot selects it")
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
