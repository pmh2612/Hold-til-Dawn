class_name ExplorationChestCheck
extends Node
var checks: int = 0

func check(pass_: bool, label) -> void:
	if not pass_:
		Cs.fail(label)
		return
	checks += 1
	print("ok   " + label)

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	run()
	print("EXPLORATION CHESTS ALL OK: %s checks" % [checks])
	get_tree().quit()
	# catch (Exception E) dropped

func run() -> void:
	var s = GameSim.new()
	s.add_player(1, "Scout", 0)
	s.add_player(2, "Engineer", 2)
	s.add_player(-1, "Bot helper", 1)
	s.start_match()
	var w = s.world
	var seen = {}
	var amounts = {}
	check(w.lm_at.keys().filter(func(id): return id != 1).size() == 17, "all 17 expedition and farm landmarks remain built outside the outpost")
	var resource_positions = Array(s.nodes.map(func(n): return Vector2(n.get("pos")))).duplicate()
	for seed_ in range(64):
		s.rng.seed = seed_
		s.place_supplies()
		if s.exploration_chests.size() != 20 or s.exploration_chests.filter(func(c): return c.landmark == 0).size() != 10 or s.exploration_chests.filter(func(c): return c.landmark > 4).size() != 10 or Cs.group_by(s.exploration_chests.filter(func(c): return c.landmark != 0), func(c): return c.landmark).any(func(g): return g.size() != 1 or g.key <= 4):
			Cs.fail("Expected ten distinct remote landmark chests and ten scattered chests")
			return
		var parts = Array(s.exploration_chests.filter(func(c): return c.component >= 0)).duplicate()
		if parts.size() != 3 or Cs.distinct(parts.map(func(c): return c.component)).size() != 3 or Cs.distinct(parts.map(func(c): return c.id)).size() != 3:
			Cs.fail("Radio parts must belong to three distinct chests")
			return
		for c in s.exploration_chests:
			if not IslandMap.on_land(c.pos, 32) or not w.resolve_fast(c.pos, 26).is_equal_approx(c.pos) or Cs.has_point(w.weather_room.grow(48), c.pos) or IslandMap.in_bridge_approach(c.pos, 32):
				Cs.fail("Chest obstructed, wet, inside the weather display or on a bridge approach")
				return
			if resource_positions.any(func(p): return p.distance_squared_to(c.pos) < 44 * 44):
				Cs.fail("Chest overlaps a harvestable resource")
				return
			if c.slots.size() != 8 or c.slots.any(func(a):
				var item = a
				return a is Array and int(item[1]) > SimInventory.stack_of(item[0])
			):
				Cs.fail("Eight bounded storage slots required")
				return
			for id in ["wood", "stone", "herb", "titanium"]:
				if SimInventory.count_in(c.slots, id) < 1:
					Cs.fail("Every chest needs all four resources")
					return
			if c.landmark == 0 and w.lm_at.values().any(func(at): return at.distance_squared_to(c.pos) < 520 * 520):
				Cs.fail("Scattered chest too near a landmark or home farm")
				return
			if c.component >= 0 and SimInventory.count_in(c.slots, GameSim.COMPONENT_IDS[c.component]) != 1:
				Cs.fail("Part missing from physical storage")
				return
			Cs.set_add(amounts, SimInventory.count_in(c.slots, "wood"))
		if not GameSim.CHEST_SUPPORT.all(func(id): return s.exploration_chests.any(func(c): return SimInventory.count_in(c.slots, id) > 0)):
			Cs.fail("Every loot-only support item must have a source")
			return
		for c in parts:
			Cs.set_add(seen, c.landmark)
		for row in s.supply_snapshot():
			if row.size() != 7 or int(row[0]) != s.exploration_chests[int(row[0])].id or row.any(func(a): return a is Array):
				Cs.fail("Public chest snapshot leaks loot")
				return
		if s.chest_contents_snapshot().size() != 0:
			Cs.fail("Locked contents leaked into the UI")
			return
	check(seen.size() == 15 and amounts.size() > 4, "64 seeds: 20 accessible eight-slot chests, ten named / ten scattered, parts visit all named sites and scattered chests")
	check(s.exploration_chests.all(func(c): return not c.opened), "walking near a chest never unlocks or collects it")
	var p = s.players[1]
	var q = s.players[2]
	var part_chest = s.exploration_chests.filter(func(c): return c.component >= 0)[0]
	var part: int = part_chest.component
	p.pos = part_chest.pos + Vector2(100, 0)
	p.inter = true
	check(not s.try_loot_chest(p, 3), "holding E cannot unlock a distant chest")
	p.pos = part_chest.pos
	p.inv = SimInventory.empty_slots(8)
	p.inter = true
	s.try_loot_chest(p, 3)
	check(not part_chest.opened and s.chest_contents_snapshot().size() == 0, "a key is mandatory and locked contents stay hidden")
	s.set_count(p, "chest_key", 2)
	p.inter = true
	s.try_loot_chest(p, 1)
	check(not part_chest.opened and p.unlock_t == 1 and s.count(p, "chest_key") == 2, "first second only progresses the lock without consuming a key")
	q.pos = part_chest.pos
	q.inter = true
	s.set_count(q, "chest_key", 1)
	s.try_loot_chest(q, 2)
	check(not part_chest.opened and p.unlock_t == 1 and s.count(q, "chest_key") == 1, "another teammate cannot accelerate or pay for the same lock")
	q.pos = GameSim.WORKBENCH_POS
	q.inter = false
	p.inter = false
	s.tick_players(0.01)
	check(p.unlock_t == 0 and part_chest.unlocker == null and s.count(p, "chest_key") == 2, "release E cancels lock progress and keeps the key")
	p.inter = true
	s.try_loot_chest(p, 1)
	p.pos += Vector2(8, 0)
	s.tick_players(0.01)
	check(p.unlock_t == 0 and not part_chest.opened, "moving interrupts unlocking")
	p.pos = part_chest.pos
	p.inter = true
	s.try_loot_chest(p, 1)
	p.invuln = 0
	s.hurt(p, 1)
	check(p.unlock_t == 0 and s.count(p, "chest_key") == 2, "damage cancels unlocking without spending keys")
	p.inter = true
	s.try_loot_chest(p, 1)
	p.atk = true
	s.tick_players(0.01)
	p.atk = false
	check(p.unlock_t == 0 and not part_chest.opened, "attacking interrupts unlocking")
	p.inter = true
	s.phase = "night"
	s.try_loot_chest(p, 1.99)
	check(not part_chest.opened and s.count(p, "chest_key") == 2, "lock requires the full two seconds, including at night")
	s.try_loot_chest(p, 0.01)
	check(part_chest.opened and s.count(p, "chest_key") == 1 and p.open_chest == part_chest.id, "two seconds consumes exactly one key and opens the selection panel")
	check(s.supplies_got() == 0 and s.count(p, "wood") == 0 and SimInventory.count_in(part_chest.slots, "wood") > 0, "unlocking takes no resources or radio parts automatically")
	var view = s.chest_contents_snapshot().get(1)
	check(view != null and view[1].size() == 8, "reachable unlocked chest publishes exactly eight slots")
	view[1][0] = null
	check(part_chest.slots[0] != null, "UI snapshot cannot mutate the chest inventory")
	var wood: int = SimInventory.count_in(part_chest.slots, "wood")
	s.move_slot(p, ["chest:" + str(part_chest.id), 0, "inv", 4])
	check(s.count(p, "wood") == wood and SimInventory.count_in(part_chest.slots, "wood") == 0 and s.count(p, "stone") == 0, "dragging takes only the selected stack")
	s.move_slot(p, ["inv", 4, "chest:" + str(part_chest.id), 0])
	check(s.count(p, "wood") == 0 and SimInventory.count_in(part_chest.slots, "wood") == wood, "items can be stored back in a chest")
	p.inv = Array(range(8).map(func(_unused): return ["wood", 20])).duplicate()
	var part_slot: int = range(8).filter(func(i):
		var a = part_chest.slots[i]
		return part_chest.slots[i] is Array and Cs.s(a[0]) == GameSim.COMPONENT_IDS[part]
	)[0]
	# TODO(cs2gd): pattern variable A bound from a complex expression (check evaluation order)
	s.move_slot(p, ["chest:" + str(part_chest.id), part_slot, "inv", 0])
	check(s.rescue_components[part] == 1 and part_chest.component == -1 and s.count(p, "wood") == 160, "explicitly taking a radio part shares it even with a full bag without replacing items")
	check(s.snapshot().msg == "1/3 - " + GameSim.SUPPLY_NAMES[part], "radio pickup announcement contains only the collected count and component name")
	s.move_slot(p, ["chest:" + str(part_chest.id), part_slot, "inv", 0])
	check(s.rescue_components[part] == 1 and SimInventory.count_in(part_chest.slots, "stone") > 0, "repeat drags cannot duplicate parts or take unrelated loot")
	p.inv = SimInventory.empty_slots(8)
	p.inter = true
	s.try_loot_chest(p, 10)
	check(part_chest.opened and s.count(p, "chest_key") == 0, "unlocked chests reopen instantly without another key")
	p.pos += Vector2(100, 0)
	s.move_slot(p, ["chest:" + str(part_chest.id), 0, "inv", 0])
	check(s.count(p, "wood") == 0 and s.chest_contents_snapshot().size() == 0, "walking away hides contents and denies remote transfers")
	var other = s.exploration_chests.filter(func(c): return c.component >= 0)[0]
	p.state = 1
	p.pos = other.pos
	check(not s.try_loot_chest(p, 3) and not other.opened, "downed players cannot unlock chests")
	p.state = 0
	s.phase = "day"
	s.move_slot(p, ["chest:" + str(other.id), 0, "inv", 0])
	check(s.count(p, "wood") == 0, "a crafted transfer request cannot bypass the lock")
	s.move_slot(p, ["nonsense", 0, "inv", 1])
	check(s.count(p, "wood") == 0, "unknown container names cannot fall back to the backpack")
	for c in Array(s.exploration_chests.filter(func(c): return c.component >= 0)).duplicate():
		p.pos = c.pos
		s.set_count(p, "chest_key", 1)
		p.inter = true
		s.try_loot_chest(p, 2)
		var slot: int = range(8).filter(func(i):
			var a = c.slots[i]
			return c.slots[i] is Array and GameSim.COMPONENT_IDS.find(Cs.s(a[0])) >= 0
		)[0]
		# TODO(cs2gd): pattern variable A bound from a complex expression (check evaluation order)
		s.move_slot(p, ["chest:" + str(c.id), slot, "inv", 0])
	check(s.supplies_got() == 3 and not s.radio_built and s.radio_parts_placed.count(1) == 0, "collected parts remain in the team pouch until placed at the radio table")
	s.dawn()
	check(s.supplies_got() == 3 and part_chest.opened and SimInventory.count_in(part_chest.slots, "wood") == wood, "dawn preserves unlocked storage, remaining loot and team parts")
	s.reset_player(p)
	check(s.supplies_got() == 3, "parts survive player death and reset")
	var helper = s.players[-1]
	q.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	s.try_build_radio(q, 10)
	check(not s.radio_built and s.radio_parts_placed.count(1) == 0, "the crafting workbench cannot install or assemble radio parts")
	helper.pos = GameSim.RADIO_POS + Vector2(-12, 24)
	helper.inter = true
	q.pos = GameSim.RADIO_POS + Vector2(0, 24)
	s.rescue_components = [1, 0, 0]
	s.action(helper.id, "radio_open", null)
	s.try_build_radio(helper, 10)
	check(s.radio_parts_placed == [1, 0, 0] and not s.radio_built and s.radio_build_t == 0, "partial delivery fills one table slot but cannot start assembly")
	s.rescue_components = [1, 1, 1]
	s.action(helper.id, "radio_open", null)
	s.try_build_radio(helper, 1)
	s.try_build_radio(q, 1)
	check(s.radio_parts_placed.count(1) == 3 and s.snapshot().rescue[3] == [1, 1, 1], "opening the radio panel deposits available parts and publishes three occupied slots")
	check(s.radio_builder == -1 and s.radio_build_t == 1, "negative bot IDs own the channel and a second teammate cannot speed it up")
	s.set_count(helper, "wood", 1)
	s.set_count(q, "wood", 1)
	q.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	check(not s.can_craft(helper, 0, false) and s.can_craft(q, 0, false), "only the radio builder is prevented from crafting another item at the same time")
	helper.inter = false
	s.tick_players(0.01)
	check(s.radio_builder == -1 and s.radio_build_t > 1, "radio repair continues without holding E")
	helper.pos += Vector2(8, 0)
	s.tick_players(0.01)
	check(s.radio_builder == null and s.radio_build_t == 0, "moving cancels the shared assembly channel")
	q.pos = GameSim.RADIO_POS + Vector2(0, 24)
	s.phase = "night"
	q.inside = true
	s.try_build_radio(q, 10)
	check(not s.radio_built and s.radio_build_t == 0, "radio cannot be assembled at night")
	s.phase = "day"
	q.inside = false
	q.inter = true
	s.interact(q, 1)
	check(s.radio_build_t == 0 and s.radio_builder == null, "ordinary world interaction does not start radio repairs")
	s.action(q.id, "radio_repair", null)
	s.tick_players(1)
	q.inter = false
	s.tick_players(0.01)
	check(s.radio_build_t > 1 and s.supplies_got() == 3 and s.radio_parts_placed.count(1) == 3, "one repair action keeps running after E is released without losing installed parts")
	q.pos += Vector2(8, 0)
	s.tick_players(0.01)
	check(s.radio_build_t == 0, "moving cancels radio assembly")
	q.pos = GameSim.RADIO_POS + Vector2(0, 24)
	s.action(q.id, "radio_repair", null)
	s.tick_players(1)
	q.invuln = 0
	s.hurt(q, 2)
	check(s.radio_build_t == 0 and not s.radio_built, "damage interrupts assembly")
	s.k = 5
	s.phase = "day"
	q.inter = false
	s.action(q.id, "radio_repair", null)
	for i in range(49):
		s.tick_players(0.1)
	check(not s.radio_built, "day 5 is allowed but assembly takes its full five seconds")
	s.tick_players(0.1)
	check(s.radio_built and s.radio_build_t == 0, "one assembled radio uses all three team parts")
	s.interact(q, 10)
	check(s.radio_built and s.supplies_got() == 3, "assembled radio cannot be duplicated or lose parts")
	s.night()
	check(s.phase == "night", "an online radio allows the final night to begin")
	s.enemies = []
	s.t = 0
	s.check_end(0.05)
	check(s.phase == "result" and s.result[0], "radio plus a clear pad leads to rescue")
	s.start_match()
	s.k = 5
	s.night()
	check(s.phase == "result" and not s.result[0], "night 5 enforces the radio deadline")
	s.start_match()
	check(not s.radio_built and s.supplies_got() == 0 and s.radio_parts_placed.count(1) == 0 and s.exploration_chests.all(func(c): return not c.opened), "new match resets the radio table and rerolls sealed chests")
	var allowed = ["light_armour", "stone_armour", "titanium_armour", "bandage", "revive", "base", "healing_flask", "repair_kit", "gathering_kit", "crafting_kit", "chest_key"]
	check(allowed.all(func(id): return GameSim.RECIPES.any(func(r): return Cs.s(r[3]) == id)), "armour, medicine, maintenance and workshop kits and keys are craftable")
	check(["haste_tonic", "poison_flask", "vine_trap"].all(func(id): return not GameSim.RECIPES.any(func(r): return Cs.s(r[3]) == id)), "speed, poison and traps remain loot only")
	q.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	q.inv = SimInventory.empty_slots(8)
	s.unlock = 2
	s.set_count(q, "wood", 6)
	s.set_count(q, "titanium", 2)
	s.finish_craft(q, 2)
	check(s.count(q, "bow") == 1 and s.count(q, "arrow") == 0, "crafting a bow gives no free arrows")
	s.set_count(q, "wood", 1)
	s.finish_craft(q, 0)
	check(s.count(q, "arrow") == 5, "arrows are crafted separately and load into the empty bow")
	s.set_count(q, "crafting_kit", 1)
	check(is_equal_approx(s.player_craft_duration(q, 0), 2.4), "carried workshop kit reduces crafting time twenty percent")
	s.set_count(q, "crafting_kit", 2)
	check(is_equal_approx(s.player_craft_duration(q, 0), 2.4), "workshop kit speed does not stack")
	s.base_hp = 500
	s.set_count(q, "stone", 5)
	s.finish_craft(q, 10)
	check(s.base_hp == 600 and s.count(q, "stone") == 0, "restored generator repair really restores HP and spends stone")
