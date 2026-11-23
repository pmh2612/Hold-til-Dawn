class_name SurvivalWorldCheck
extends Node
var checks: int = 0

func check(pass_: bool, message) -> void:
	if not pass_:
		Cs.fail(message)
		return
	checks += 1
	print("ok   " + message)

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	run()
	print("SURVIVAL WORLD ALL OK: %s checks" % [checks])
	get_tree().quit()
	# catch (Exception Error) dropped

func run() -> void:
	var s = GameSim.new()
	s.add_player(1, "Engineer", 2)
	s.add_player(2, "Scout", 0)
	s.start_match()
	var w = s.world
	check(IslandMap.by_id(8).pos.y < -30 * 32 and w.swamp_centre.y < 0, "swamp marker, pools and scene moved north")
	check(w.harvest_sites.size() > 650 and Cs.sum(w.outside_after) < Cs.sum(w.outside_before), "concentrated home farms and sparser outer world: %s sites" % [w.harvest_sites.size()])
	check(IslandMap.rivers.size() == 2 and IslandMap.bridges.size() == 5 and w.ramps.size() >= 3, "two rivers with %s bridges and %s slopes" % [IslandMap.bridges.size(), w.ramps.size()])
	for r in range(2):
		var path = IslandMap.rivers[r]
		check(IslandMap.bridges.filter(func(b): return b[0] == r).size() == (3 if r == 0 else 2), "river %s has its exploration bridges" % [r])
		check(IslandMap.depth(path[0]) < 0 and IslandMap.depth(path[-1]) < 0 and path[0].y < -60 * 32 and path[-1].y > 60 * 32, "river %s runs from the north coast to the south coast" % [r])
		check(path.all(func(p): return p.x < -25 * 32) if r == 0 else path.all(func(p): return p.x > 25 * 32), "river %s keeps to its side of the island" % [r])
	for _it1 in IslandMap.bridges:
		var at = _it1[1]
		check(IslandMap.on_land(at, 35) and w.resolve_fast(at, 10).is_equal_approx(at) and w.terrain_at(at) == 5, "bridge deck is walkable, even for a boss")
		var beside: Vector2 = at + Vector2(0, IslandMap.BRIDGE_HALF_W + 1.5 * 32)
		check(not IslandMap.on_land(beside, 10) and not IslandMap.on_land(beside), "water beside a bridge stops bodies")
		var far: Vector2 = at + Vector2(IslandMap.BRIDGE_HALF_LEN + 32, 0)
		var near: Vector2 = at - Vector2(IslandMap.BRIDGE_HALF_LEN + 32, 0)
		check(IslandMap.on_land(far, 12) and IslandMap.on_land(near, 12), "both ends of a bridge reach dry land")
		var way = w.waypoint_fast(near, far, 0.5 * 32, [Rect2(-Vector2(GameSim.HALF), Vector2(GameSim.HALF) * 2)])
		check(way.distance_to(near) > 1 and absf(way.y - at.y) < IslandMap.BRIDGE_HALF_W, "enemies route straight over a bridge")
	check(not Cs.pairs(w.lm_at).any(func(l): return IslandMap.in_river(w.cave_centre if l[0] == 16 else l[1], 6 * 32)), "no landmark structure stands in or by a river")
	check(not IslandMap.in_river(w.cave_entrance, IslandMap.RIVER_BANK + 10), "the eastern cave mouth stays on dry land beside the bridge approach")
	var without_bridges = reachable_land(false)
	var with_bridges = reachable_land(true)
	for id in [5, 9]:
		var cell: Vector2i = Vector2i((w.lm_at[id] / 32).round())
		check(not without_bridges.has(cell) and with_bridges.has(cell), IslandMap.by_id(id).name + " is across the river and reachable by bridge")
	check(with_bridges.has(Vector2i((w.swamp_centre / 32).round())) and not IslandMap.in_river(w.swamp_centre, w.swamp_r), "relocated swamp leaves the expedition crossing clear")
	check(not w.lm_props.any(func(p): return IslandMap.in_river(p[0])) and not w.harvest_sites.any(func(s): return IslandMap.in_river(s.pos, 8)), "no prop, tree or rock stands in a river")
	var wet: int = 0
	for _it2 in w.trails:
		var path = _it2[0]
		var width = _it2[1]
		for pt in path:
			if IslandMap.in_river(pt) and not IslandMap.near_bridge(pt):
				wet += 1
				print("wet path point ", pt / 32, " width ", width / 32, " of ", path.size())
	check(wet == 0, "paths cross a river only on a bridge")
	# a body cannot swim across: walking straight at the river it stops at the bank
	var walker = GameSim.new()
	walker.add_player(1, "Scout", 0)
	walker.start_match()
	var wp = walker.players[1]
	var path = IslandMap.rivers[0]
	var mid: Vector2 = path[path.size() / 3]
	wp.pos = mid + Vector2(IslandMap.RIVER_HALF + 3 * 32, 0)
	for i in range(120):
		wp.pos = walker.move_actor(wp.pos, wp.pos + Vector2(-6, 0), 0.3 * 32)
	check(Vector2(wp.pos).x > mid.x + IslandMap.RIVER_HALF - 4, "players cannot walk through a river")
	for name in ["lm_tent_0", "lm_console_0", "lm_cart_0", "lm_warning_0", "lm_cargo_stack_0", "lm_waterpump_0"]:
		check(w.lm_props.any(func(p): return p[1] == name) and load("res://art/landmarks/%s.png" % [name]) != null, name + " is shipped and placed")
		check(not w.harvest_sites.any(func(p): return p.sprite == name), name + " cannot be farmed")
	check(SurvivalFeedbackUi.low_health_strength(90, 100) == 0 and SurvivalFeedbackUi.low_health_strength(10, 100) > SurvivalFeedbackUi.low_health_strength(35, 100), "red border increases as health falls")
	check(GameSim.ROAM_CHECK < 15 and GameSim.ROAM_MAX > 8 and SimRoamers.roam_chance(Vector2(0, 2200)) > 0.3, "daytime encounters are more frequent and bounded")
	check(s.exploration_chests.size() == 20 and s.exploration_chests.filter(func(c): return c.landmark > 4).size() == 10, "20 chests, ten at expedition landmarks and ten scattered")
	var p = s.players[1]
	var q = s.players[2]
	for c in Array(s.exploration_chests.filter(func(c): return c.component >= 0)).duplicate():
		p.pos = c.pos
		p.inter = true
		s.set_count(p, "chest_key", 1)
		s.interact(p, 2.0)
		var slot: int = range(8).filter(func(i):
			var a = c.slots[i]
			return c.slots[i] is Array and GameSim.COMPONENT_IDS.find(Cs.s(a[0])) >= 0
		)[0]
		# TODO(cs2gd): pattern variable A bound from a complex expression (check evaluation order)
		s.move_slot(p, ["chest:" + str(c.id), slot, "inv", 0])
	check(s.supplies_got() == 3 and not s.supplies_all_in(), "finding parts requires assembling the radio")
	s.dawn()
	check(s.supplies_got() == 3, "radio parts persist through dawn")
	p.pos = GameSim.RADIO_POS + Vector2(0, 24)
	s.action(p.id, "radio_open", null)
	s.try_build_radio(p, 5.1)
	check(s.radio_built and s.radio_parts_placed.count(1) == 3, "radio is assembled at its own table with three installed parts")
	s.k = 5
	s.night()
	s.t = 0.0
	s.enemies = []
	s.check_end(0.05)
	check(s.phase == "result" and s.result[0], "radio and clear pad allow night 5 rescue")
	s.start_match()
	s.k = 5
	s.night()
	check(s.phase == "result" and not s.result[0], "missing radio at the start of night 5 prevents rescue")
	s.to_lobby()
	s.start_match()
	p = s.players[1]
	q = s.players[2]
	# Isolate construction geometry from resource collisions.
	s.nodes = []
	w.rebuild(s.nodes, s.towers)
	p.pos = s.free_tower_spot(0)
	q.pos = Vector2.ZERO
	s.build_tower(p)
	check(s.construction.size() == 1 and s.towers[0] == null and s.free_tower, "tower starts as a reserved dirt foundation")
	s.tick_tower_construction(p, 5.9)
	check(s.towers[0] == null, "tower cannot fire before six seconds")
	s.tick_tower_construction(p, 0.2)
	check(s.towers[0] != null and not s.free_tower, "six seconds completes the free tower")
	s.unlock = 2
	p.pos = s.free_tower_spot(2)
	s.set_count(p, "wood", 20)
	s.set_count(p, "titanium", 10)
	s.build_tower(p)
	p.pos += Vector2(10, 0)
	s.tick_tower_construction(p, 1)
	check(s.construction.size() == 0 and s.count(p, "wood") == 20, "movement cancels construction without spending materials")
	p.pos = s.free_tower_spot(2)
	s.build_tower(p)
	p.taken += 1
	s.tick_tower_construction(p, 1)
	check(s.construction.size() == 0 and s.count(p, "titanium") == 10, "damage cancels construction without spending titanium")
	s.build_tower(p)
	s.tick_tower_construction(p, 6.1)
	check(s.towers[1] != null and s.count(p, "wood") == 10 and s.count(p, "titanium") == 5, "paid tower spends materials at completion")
	var before: int = s.enemy_body_steps
	for i in range(60):
		s.tick_enemy_simulation(1.0 / 60)
	check(s.enemy_body_steps - before == 20, "60Hz simulation runs expensive body/AI work only 20 times per second")

# Flood-fill land with and without decks: moving a map dot alone must not satisfy the crossing requirement.
static func reachable_land(bridges: bool) -> Variant:
	var seen = {Vector2i.ZERO: true}
	var queue = []
	queue.push_back(Vector2i.ZERO)
	var dirs = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while queue.size() > 0:
		var at: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = at + dir
			var p: Vector2 = Vector2(next) * 32
			if seen.has(next) or not IslandMap.on_land(p, 10) or not bridges and IslandMap.in_river(p, 10):
				continue
			Cs.set_add(seen, next)
			queue.push_back(next)
	return seen
