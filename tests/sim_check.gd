class_name SimCheck
extends Node

# ---- tests/SimCheck.cs
# Headless check of the server rules: godot --headless --path . tests/SimCheck.tscn
var fails = 0

func check(ok, what) -> void:
	print(("ok   " if ok else "FAIL ") + Cs.s(what))
	if not ok:
		fails += 1

func run(s, seconds, until_phase = null) -> void:
	if until_phase == null: until_phase = ""
	for i in int(seconds * 60):
		s.tick(1.0 / 60)
		if until_phase != "" and s.phase == until_phase:
			return

func new_match() -> Variant:
	var s = GameSim.new()
	s.add_player(1, "Eng", 2)
	s.add_player(2, "Scout", 0)
	s.action(1, "start", 0)
	return s

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	run_checks()
	# catch (Exception error) dropped

func run_checks() -> void:
	var arguments = OS.get_cmdline_user_args()
	if arguments.has("--bosses-only"):
		check_bosses()
		print("FAILED %d" % [fails] if fails else "ALL OK")
		get_tree().quit(1 if fails else 0)
		return
	if not arguments.has("--mechanics-only"):
		check_progression()
	if not arguments.has("--progression-only"):
		check_mechanics()
	if not arguments.has("--progression-only"):
		check_bots()
	if not arguments.has("--progression-only"):
		check_items()
	if not arguments.has("--progression-only"):
		check_bosses()
	print("FAILED %d" % [fails] if fails else "ALL OK")
	get_tree().quit(1 if fails else 0)

func check_progression() -> void:
	var s = self.new_match()
	self.check(s.phase == "day" and s.active.size() == 1, "match starts on day 1 with one attacked door")
	self.check(s.nodes.filter(func(n): return n.type == 0 and not n.get("ambient", false)).size() == (4 + 3 * 2) * GameSim.NODE_MUL, "4 + 3n primary nodes per type, plus harvestable world scenery")
	var eng = s.players[1]
	var wood = s.nodes.filter(func(n): return n.type == 0)[0]
	eng.pos = wood.pos
	eng.inter = true
	self.run(s, 15)
	self.check(s.count(eng, "wood") == 5 and wood.amount == 0, "gathering at 0.35/s empties a 5-unit node in ~15 s")
	eng.inter = false
	var stone = s.nodes.filter(func(n): return n.type == 1)[0]
	eng.pos = stone.pos
	eng.inter = true
	for i in 60 * 6:
		eng.pos = stone.pos + Vector2(20.0 * sin(i * 0.2), 0)
		s.tick(1.0 / 60)
	self.check(s.count(eng, "stone") == 0 and stone.amount == 5, "moving while holding E gathers nothing (MEC-08)")
	eng.pos = stone.pos
	self.run(s, 1.5)
	self.check(eng.gather_acc > 0.4 and eng.gather_acc < 0.6 and s.snapshot().ps[1][21] == eng.gather_acc, "gather progress is in the snapshot")
	eng.inter = false
	self.run(s, 0.1)
	self.check(eng.gather_acc == 0.0, "releasing E resets gather progress")
	eng.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	s.set_count(eng, "wood", 1)
	s.action(1, "craft", 0)
	self.run(s, 2.9)
	self.check(s.count(eng, "arrow") == 0, "crafting takes 3 s (BAL-19)")
	self.run(s, 0.2)
	self.check(s.count(eng, "arrow") == 5 and s.count(eng, "wood") == 0, "combat ammo crafted at workbench")
	s.add_item(eng, "light_armour", 1)
	self.check(eng.armour == 1 and s.count(eng, "light_armour") == 0, "looted armour is worn and takes no bag slot")
	# a3f6a63 added armour, healing, kits and chest keys to the workbench; base repairs restore the base, not an item
	self.check(GameSim.RECIPES.all(func(r): return GameSim.ITEMS.has(r[3]) or r[3] == "base"), "every recipe makes a known item (or repairs the base)")
	s.set_count(eng, "wood", 8)
	s.set_count(eng, "stone", 12)
	s.action(1, "craft", 1)
	self.run(s, 3.1)
	self.check(s.count(eng, "stone_spear") == 1, "stone spear can be crafted on day one")
	s.t = 0
	self.run(s, 0.1)
	self.check(s.phase == "dusk", "day -> dusk")
	self.run(s, 16, "night")
	self.check(s.phase == "night" and not SimWorld.inside_base(eng.pos), "night starts, players moved outside")
	# An undefended base loses: isolate door/generator rules from the free automatic tower,
	# which can now hold the deliberately sparse first-night waves on its own.
	s.towers = [null, null, null]
	for p in s.players.values():
		p.pos = Vector2(0, 40 * 32)
	self.run(s, 601, "result")
	self.check(s.phase == "result" and "Generator" in s.msg, "idle team loses night 1: " + Cs.s(s.msg))
	# Progression path (debug skip), with an unkillable base so the boss timer can be tested.
	s = self.new_match()
	s.base_hp = 1000000000.0
	s.action(1, "skip", 0)
	self.run(s, 0.1)
	self.run(s, 16, "night")
	s.action(1, "skip", 0)
	self.run(s, 0.1)
	self.check(s.k == 2 and s.phase == "day" and s.unlock == 1, "night 1 cleared and progression advances")
	s.action(1, "skip", 0)
	self.run(s, 0.1)
	self.run(s, 16, "night")
	for p in s.players.values():
		p.pos = Vector2(0, 40 * 32)
	self.run(s, 305)
	var boss = s.boss()
	self.check(boss != null, "boss spawned on night 2")
	if boss:
		boss.hp = 1
		# up above ground and not about to dig in (a burrowed Burrower cannot be hit)
		s.boss_act(boss, "", 0.0)
		boss.sig_cd = 99.0
		var sc = s.players[2]
		sc.pos = boss.pos - Vector2(32, 0)
		sc.aim = 0.0
		sc.atk = true
		self.run(s, 0.2)
		sc.atk = false
		self.check(s.k == 2 and s.phase == "night" and s.unlock == 2, "killing the boss unlocks titanium tier; the night goes on until its enemy quota is cleared")

func check_mechanics() -> void:
	var s = null
	# Engineer night entry (MEC-15)
	s = self.new_match()
	s.action(1, "skip", 0)
	self.run(s, 0.1)
	self.run(s, 16, "night")
	# isolate door entry and repair from the faster night waves
	s.next_wave = INF
	var e1 = s.players[1]
	var sc2 = s.players[2]
	e1.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 32
	e1.ent = true
	self.run(s, 2.1)
	e1.ent = false
	self.check(e1.inside and SimWorld.inside_base(e1.pos), "Engineer holds F 2 s at a closed door and gets inside")
	# walks over to the workbench by the north wall
	e1.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	s.set_count(e1, "wood", 1)
	s.action(1, "craft", 0)
	self.run(s, 3.1)
	self.check(s.count(e1, "arrow") == 5, "Engineer crafts combat ammo at night inside")
	sc2.pos = GameSim.DOOR_POS[1] + GameSim.DOOR_DIR[1] * 32
	sc2.ent = true
	self.run(s, 2.1)
	self.check(not sc2.inside and not SimWorld.inside_base(sc2.pos), "Scout cannot enter at night")
	# back to door A, just inside
	e1.pos = GameSim.DOOR_POS[0] - GameSim.DOOR_DIR[0] * 1.2 * 32
	e1.ent = true
	self.run(s, 2.1)
	e1.ent = false
	self.check(not e1.inside and not SimWorld.inside_base(e1.pos), "Engineer leaves the same way")
	# Engineer repairs a door at night from outside (MEC-12, FML-08)
	e1.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 24
	s.doors[0] = 300.0
	s.door_pause[0] = 0.0
	s.set_count(e1, "wood", 0)
	e1.inter = true
	self.run(s, 1.0)
	self.check(s.doors[0] == 300.0, "no repair without wood")
	s.set_count(e1, "wood", 10)
	self.run(s, 2.0)
	self.check(s.doors[0] > 328.0 and s.doors[0] < 332.0 and s.count(e1, "wood") == 7, "night repair: +15/s and 1 wood per 10 (%.1f, wood %d)" % [s.doors[0], s.count(e1, "wood")])
	s.door_pause[0] = 2.0
	var before: float = float(s.doors[0])
	self.run(s, 1.0)
	self.check(s.doors[0] == before, "a hit on the door pauses repair for 2 s")
	e1.inter = false
	self.check(s.snapshot().has("dpause") and s.snapshot().has("broken"), "repair state is in the snapshot")
	# enemies from the far side reach their door around the walls
	var ep = Vector2(0, 30 * 32)
	var goal: Vector2 = Vector2(GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 22)
	for i in 2000:
		ep += (SimWorld.route(ep, goal, 16.0) - ep).normalized() * 3.0
		ep = SimWorld.push_out(ep, 16.0)
		if ep.distance_to(goal) < 4:
			break
	self.check(ep.distance_to(goal) < 4, "enemy spawned behind the base walks around to door A")
	# Daytime roamers (MEC-26, FML-16)
	# points straight south of the base: wall distance = y - HALF.y
	var wall: float = float(GameSim.HALF.y)
	self.check(SimRoamers.roam_chance(Vector2(0, wall + 9 * 32)) == 0.0, "no roamer chance inside 10 tiles")
	self.check(absf(SimRoamers.roam_chance(Vector2(0, wall + 40 * 32)) - 0.65 * 30 / 35) < 0.001, "roamer chance scales toward 65% at 45 tiles")
	self.check(absf(SimRoamers.roam_chance(Vector2(0, wall + 65 * 32)) - 0.65) < 0.001, "roamer chance capped at 65%")
	s = self.new_match()
	# Test ambient roaming separately from the intentional encounters at unopened chests.
	for chest in s.exploration_chests:
		chest.opened = true
	var far = s.players[2]
	var near = s.players[1]
	far.pos = Vector2(0, wall + 55 * 32)
	near.pos = Vector2(0, -(wall + 10 * 32))
	self.run(s, 300)
	var roam = s.enemies.filter(func(e): return e.has("home"))
	self.check(roam.size() >= 2 and roam.size() <= GameSim.ROAM_MAX, "roamers met far from the base (%d alive)" % [roam.size()])
	self.check(roam.all(func(e): return e.pos.distance_to(near.pos) > 20 * 32), "no roamer near the player in the safe zone")
	self.check(roam.all(func(e): return e.state == 4 or e.state == 1), "roamers wander or chase by day, never go to a door")
	self.check(far.state == 0, "a player standing still out of their sight is left alone")
	s.t = 0
	self.run(s, 0.1)
	self.check(s.phase == "dusk" and roam.all(func(e): return e.state == 0 and e.door in s.active and not e.has("home")), "at dusk roamers head for an attacked door")
	# a roamer that spots a player chases and hurts them
	s = self.new_match()
	var vic = s.players[2]
	vic.pos = Vector2(0, wall + 50 * 32)
	# a clear spot near there (the scenery is dense), with open ground 3 tiles to the east
	for try in range(40):
		var spot: Vector2 = s.world.resolve_fast(Vector2(try % 8 * 64, wall + (50 + try / 8 * 2) * 32), 0.3 * 32)
		if s.line_clear(spot, spot + Vector2(3 * 32, 0)) and s.world.resolve_fast(spot + Vector2(3 * 32, 0), 16.0).is_equal_approx(spot + Vector2(3 * 32, 0)):
			vic.pos = spot
			break
	s.spawn_roamers(vic)
	var r0 = s.enemies.filter(func(e): return e.has("home"))
	self.check(r0.size() == 2, "a roamer group is a pair")
	if r0.size() > 0:
		r0[0].pos = vic.pos + Vector2(3 * 32, 0)
		self.run(s, 3)
		self.check(vic.hp < vic.maxhp, "roamer within 4 tiles chases and hits")
	# team wiped by day is a loss
	for p in s.players.values():
		p.state = 1
		p.bleed = 30.0
	self.run(s, 0.1)
	self.check(s.phase == "result" and "wiped" in s.msg, "team wiped by day loses")
	# Drops (BAL-41, FML-15)
	s = self.new_match()
	for i in 10000:
		s.drop({"type": 0, "pos": Vector2.ZERO})
	# BAL-41: 10% x playtest multiplier
	var want: float = 1000.0 * GameSim.DROP_MUL
	self.check(absf(s.drops.size() - want) <= 0.1 * want, "Grunt drop rate %d%% +-10%% (%d / 10000)" % [want / 100, s.drops.size()])
	self.check(s.drops.all(func(d): return d.item in ["wood", "stone", "herb"] and d.n >= 1 and d.n <= 2), "Grunt drops 1-2 wood/stone/herb")
	s.drops.clear()
	s.drop({"type": GameSim.BOSS, "pos": Vector2(0, 30 * 32)})
	var pick = s.players[2]
	pick.pos = Vector2(0, 30 * 32)
	self.run(s, 0.1)
	self.check(s.count(pick, "titanium") == 10, "boss drop collected by walking over it (+10 titanium)")
	s.drops.clear()
	s.add_drop(Vector2(0, 30 * 32 + 300), "wood", 2)
	self.run(s, 31)
	self.check(s.drops.is_empty(), "uncollected drop vanishes after 30 s")
	s.add_drop(Vector2.ZERO, "wood", 2)
	pick.pos = Vector2.ZERO
	var w0 = s.count(pick, "wood")
	self.run(s, 0.5)
	self.check(s.count(pick, "wood") == w0, "drops cannot be collected from inside the base")
	# Walls: only doors let players in.
	var walk = func(start, step, open):
		var pos = start
		for i in 200:
			pos = SimWorld.collide(pos + step, 12.8, open)
		return pos
	self.check(walk.call(Vector2(0, GameSim.HALF.y + 40), Vector2(0, -2), [true, true, true]).y > GameSim.HALF.y, "bottom wall blocks (no door)")
	self.check(walk.call(Vector2(0, -GameSim.HALF.y - 40), Vector2(0, 2), [true, true, true]).y > 0, "open door B (north) lets you in")
	self.check(walk.call(Vector2(0, -GameSim.HALF.y - 40), Vector2(0, 2), [true, false, true]).y < -GameSim.HALF.y, "closed door B blocks")
	self.check(walk.call(Vector2(-GameSim.HALF.x - 40, 0), Vector2(2, 0), [true, true, true]).x > 0, "open door A (west) lets you in")
	self.check(walk.call(Vector2(GameSim.HALF.x + 40, 0), Vector2(-2, 0), [true, true, false]).x > GameSim.HALF.x, "closed door C (east) blocks")
	self.check(walk.call(Vector2(-GameSim.HALF.x - 40, 60), Vector2(2, 0), [true, true, true]).x < -GameSim.HALF.x, "west wall beside door A blocks")
	# Geometry from the GDD (BAL-21, BAL-34, section 4.3)
	self.check(GameSim.HALF == Vector2(11, 7) * 16 and GameSim.DOOR_POS[0].x < 0 and GameSim.DOOR_POS[1].y < 0 and GameSim.DOOR_POS[2].x > 0, "11 x 7 base, doors A west, B north, C east")
	s = self.new_match()
	s.rng.seed = 42
	# random resource nodes would nudge spawns out of the band; scenery stays (it is fixed)
	var kept_nodes = s.nodes
	s.nodes = []
	s.world.rebuild(s.nodes, s.towers)
	s.k = 3
	s.active = [0, 1, 2]
	s.night()
	s.next_wave = INF
	s.spawn_wave()
	for spawn_step in range(100):
		s.elapsed = spawn_step * 0.5
		s.tick_waves()
	var in_band = func(e):
		var rel: Vector2 = Vector2(e.pos - GameSim.DOOR_POS[e.door])
		var dd: Vector2 = Vector2(GameSim.DOOR_DIR[e.door])
		var fwd = rel.dot(dd) / 32.0
		return fwd >= 24.99 and fwd <= 35.01 and absf(rel.dot(Vector2(-dd.y, dd.x))) <= 5.01 * 32
	var south = func(e): return absf(e.pos.x) < GameSim.HALF.x and e.pos.y > GameSim.HALF.y
	self.check(not s.enemies.is_empty(), "night wave spawns enemies")
	if GameSim.SPAWN_ALL_SIDES:
		self.check(s.enemies.all(func(e): return IslandMap.on_land(Vector2(e.pos)) and SimWorld.wall_dist(e.pos) >= 8 * GameSim.T), "wave spawns stay on the island and outside the base")
		self.check(s.enemies.any(func(e): return e.pos.x < -GameSim.HALF.x) and s.enemies.any(func(e): return e.pos.x > GameSim.HALF.x) and s.enemies.any(func(e): return e.pos.y < -GameSim.HALF.y) and s.enemies.any(func(e): return e.pos.y > GameSim.HALF.y), "night wave comes from west, east, north and south")
		self.check(s.enemies.any(func(e): return SimWorld.wall_dist(e.pos) < 20 * GameSim.T) and s.enemies.any(func(e): return SimWorld.wall_dist(e.pos) > 45 * GameSim.T), "night wave spreads from near the base to the outer island")
		self.check(s.enemies.all(func(e): return e.door == s.nearest_active_door(e.pos)), "each enemy heads for its nearest attacked door")
	else:
		self.check(s.enemies.all(in_band), "night spawns in a 10 x 10 tile band 25-35 tiles in front of each active door")
		self.check(not s.enemies.any(south), "no night spawn south of the base")
	s.nodes = kept_nodes
	# island map (src/world/IslandMap.cs): most wood, stone and herbs round the three clusters in the safe zone,
	# a few at outer landmarks; all titanium past it; every node on land, off the door corridors
	self.check(s.nodes.all(func(n): return not SimWorld.in_door_lane(n.pos) and IslandMap.on_land(Vector2(n.pos)) and (n.type < 3 or SimWorld.wall_dist(n.pos) > 20 * 32)), "resource nodes on land, titanium beyond the safe zone, door corridors clear")
	var basic: int = 0
	var in_safe: int = 0
	for n in s.nodes:
		if n.type < 3 and not n.get("ambient", false):
			basic += 1
			in_safe += 1 if SimWorld.wall_dist(n.pos) <= 20 * 32 else 0
	self.check(in_safe >= 0.7 * basic, "most primary resource clusters remain in the safe zone")
	# the landmarks (src/world/world_landmarks.gd): all 17 built, the pier walkable out over the sea, and
	# titanium still at every salvage site
	var wld = s.world
	self.check(wld.lm_at.keys().filter(func(id): return id != 1).size() == 17, "all 17 landmarks outside the outpost are built")
	var pier_end: Vector2 = wld.lm_at[10] + Vector2(-200, 0)
	self.check(IslandMap.depth(pier_end) < 0 and IslandMap.on_land(pier_end, 10) and IslandMap.keep(wld.lm_at[10], pier_end, 10) == pier_end, "the Old Fishing Pier can be walked out over the sea")
	var every_site: bool = true
	for site in [5, 6, 7, 13, 14]:
		var sp: Vector2 = IslandMap.by_id(site).pos
		every_site = every_site and s.nodes.any(func(n): return n.type == 3 and Vector2(n.pos).distance_to(sp) < 9 * 32 * IslandMap.SCALE)
	self.check(every_site, "titanium nodes at all five salvage sites, round their structures")
	s.k = 2
	s.active = [1]
	# a Juggernaut: the Broodmother is slower on purpose (BAL-39)
	s.boss_plan = [0, 1]
	s.spawn_boss()
	var b = s.boss()
	self.check(b != null and b.pos.distance_to(GameSim.DOOR_POS[1] + GameSim.DOOR_DIR[1] * 60 * 32) < 1.0, "boss starts 60 tiles in front of its door")
	self.check(absf(b.spd - 2.16 * GameSim.T) < 0.01, "night-2 boss moves at a night-2 Grunt's speed, 2.16 tiles/s (BAL-39)")
	var snap = s.snapshot()
	self.check(snap.has("ps") and snap.ps.size() == 2, "snapshot has both players")
	# Movement and wave timing (BAL-04, BAL-29, FML-01).
	s = self.new_match()
	var slow = s.spawn(GameSim.GRUNT, 0, 20.0, false)
	var origin: Vector2 = Vector2(slow.pos)
	s.tick_enemies(1.0)
	self.check(absf(slow.pos.distance_to(origin) - 64.0) < 0.01, "night-1 Grunt travels 2 tiles per second")
	s.enemies.clear()
	s.night()
	s.elapsed = 19.99
	s.tick_waves()
	self.check(s.wave == 0 and s.enemies.is_empty(), "no first-night wave before 20 seconds")
	s.elapsed = 20.0
	s.tick_waves()
	self.check(s.wave == 1 and not s.enemies.is_empty(), "first-night wave begins with one enemy at 20 seconds")
	s.elapsed = 79.99
	s.tick_waves()
	self.check(s.wave == 1, "first-night waves wait 60 seconds")
	s.elapsed = 80.0
	s.tick_waves()
	self.check(s.wave == 2, "second first-night wave arrives at 80 seconds")
	s.k = 5
	s.radio_built = true  # isolate final-night spawn timing from expedition preparation
	s.enemies.clear()
	s.night()
	s.elapsed = 30.0
	s.tick_waves()
	s.elapsed = 59.99
	s.tick_waves()
	self.check(s.wave == 1, "final-night waves wait 30 seconds")
	s.elapsed = 60.0
	s.tick_waves()
	self.check(s.wave == 2, "final-night second wave arrives at 60 seconds")
	# Towers (AGT-12, MEC-11, MEC-28, BAL-28)
	s = self.new_match()
	# Isolate tower rules from randomly placed line-of-sight blockers.
	s.nodes.clear()
	s.world.rebuild(s.nodes, s.towers)
	var te = s.players[1]
	var ts = s.players[2]
	te.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 1.5 * 32
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	self.check(s.towers[0] == null and s.free_tower, "no tower right at a door")
	te.pos = SimWorld.pad_pos(0)
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	self.check(s.towers[0] == null and s.free_tower, "no tower on a landing pad")
	self.check(SimTowers.tower_spot_problem(Vector2.ZERO, null) != "" and SimTowers.tower_spot_problem(s.free_tower_spot(1), s.world) == "", "towers go outside the base, anywhere off the pads")
	ts.pos = s.free_tower_spot(0)
	s.action(2, "tower", 0)
	self.check(s.towers[0] == null, "only an Engineer builds towers")
	ts.pos = Vector2.ZERO
	te.pos = s.free_tower_spot(0)
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	var tw = s.towers[0]
	self.check(tw != null and tw.hp == 300.0 and not s.free_tower and s.count(te, "wood") == 0, "the free tower is placed beside door A's landing pad at no cost")
	te.pos = s.free_tower_spot(2)
	s.set_count(te, "wood", 20)
	s.set_count(te, "titanium", 10)
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	self.check(s.towers[1] == null and s.count(te, "wood") == 20, "a second tower is locked until the first boss is killed")
	s.unlock = 2
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	self.check(s.towers[1] != null and s.count(te, "wood") == 10 and s.count(te, "titanium") == 5, "an unlocked tower costs 10 wood + 5 titanium")
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	self.check(s.towers[2] == null and s.count(te, "wood") == 10, "towers do not stack on one spot")
	te.pos = s.free_tower_spot(1)
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	s.set_count(te, "wood", 20)
	s.set_count(te, "titanium", 10)
	te.pos = s.free_tower_spot(1) + Vector2(0, 3 * 32)
	s.action(1, "tower", 0)
	s.tick_tower_construction(s.players[1], 6.1)
	self.check(s.towers[2] != null and s.count(te, "wood") == 20, "the team has at most %d towers" % [GameSim.MAX_TOWERS])
	s.towers[1] = null
	var tg = s.spawn(GameSim.GRUNT, 0, 0.0)
	tg.pos = tw.pos + Vector2(0, 4 * 32)
	tg.state = 4
	# A stationary target keeps the DPS/range check deterministic.
	tg.spd = 0.0
	tg.home = tg.pos
	tg.wander = tg.pos
	te.pos = Vector2.ZERO
	ts.pos = Vector2.ZERO
	self.run(s, 3.0)
	self.check(tg.hp < tg.maxhp - 20 and tg.hp > tg.maxhp - 28, "a tower shoots the nearest enemy within 6 tiles at 8 DPS (%.1f)" % [tg.maxhp - tg.hp])
	self.run(s, 6.0)
	self.check(not s.enemies.has(tg), "a tower kills on its own")
	var far_e = s.spawn(GameSim.GRUNT, 0, 0.0)
	far_e.pos = tw.pos + Vector2(0, 7 * 32)
	far_e.state = 4
	far_e.spd = 0.0
	far_e.home = far_e.pos
	far_e.wander = far_e.pos
	var hp0: float = float(far_e.hp)
	self.run(s, 1.0)
	self.check(far_e.hp == hp0, "nothing beyond 6 tiles is shot")
	s.enemies.clear()
	s.phase = "night"
	# tower behaviour is checked without unrelated wave attackers
	s.next_wave = INF
	s.towers[2] = null
	var g2 = s.spawn(GameSim.GRUNT, 0, 0.0)
	g2.pos = tw.pos + GameSim.DOOR_DIR[0] * 10 * 32
	g2.hp = 1000.0
	# the enemy must cross the light and reach the tower before hitting it
	self.run(s, 8.0)
	self.check(g2.state == 5 and tw.hp < 300.0 and s.doors[0] == GameSim.DOOR_HP, "at night an enemy entering the light attacks the tower before its door")
	g2.cd = 99.0
	te.pos = tw.pos + Vector2(0, 32)
	s.set_count(te, "wood", 5)
	te.inter = true
	var thp: float = float(tw.hp)
	# a hit blocks repair for 2 s (FML-08)
	self.run(s, 3.0)
	self.check(tw.hp > thp, "the Engineer repairs a tower like a door")
	te.inter = false
	g2.cd = 0.0
	tw.hp = 5.0
	self.run(s, 0.5)
	self.check(tw.hp == 0.0 and tw.wrecked and s.snapshot().tw[0][3], "a tower at 0 HP is destroyed")
	self.run(s, 0.2)
	self.check(g2.state != 5, "enemies locked on a fallen tower walk on to their door")
	te.inter = true
	self.run(s, 1.0)
	self.check(tw.hp == 0.0, "a destroyed tower cannot be repaired while an enemy is in its light")
	s.enemies.clear()
	s.set_count(te, "wood", 20)
	self.run(s, 10.0)
	self.check(absf(tw.hp - 90.0) < 0.01, "a destroyed tower is repaired only to 30%% (%.1f)" % [tw.hp])
	te.inter = false
	var g3 = s.spawn(GameSim.SPITTER, 0, 0.0)
	g3.pos = tw.pos + Vector2(0, 2 * 32)
	self.run(s, 0.2)
	self.check(g3.state != 5, "Spitters never attack towers")
	s = self.new_match()
	s.action(1, "vote", 0)
	s.action(2, "vote", 0)
	self.run(s, 179.0, "dusk")
	self.check(s.phase == "day", "T-FML14: a unanimous vote does not skip the day before 180 s")
	self.run(s, 1.1, "dusk")
	self.check(s.phase == "dusk", "the vote skips the day once 180 s have passed")
	self.check(absf(s.t - 15.0) < 0.05, "dusk warning lasts 15 s (BAL-05)")
	self.check(s.towers.all(func(tw): return tw == null) and s.free_tower, "dusk preserves the free tower for manual placement")

# ---- tests/ai/SimCheck.Bosses.cs
# Owner: Vu Duc Viet Anh. Boss archetype and threat checks (AGT-05..11, table 4.2, FML-05, FML-09).

# Night 2 with one boss of the given kind 12 tiles in front of door A, no waves, nodes cleared.
func boss_match(kind: int) -> Variant:
	var s = self.new_match()
	s.nodes.clear()
	s.world.rebuild(s.nodes, s.towers)
	s.k = 2
	s.phase = "night"
	s.t = 720.0
	s.next_wave = INF
	s.boss_spawned = true
	s.active = [0]
	s.boss_plan = [kind, (kind + 1) % 7]
	s.spawn_boss()
	var b = s.boss()
	b.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 12 * 32
	b.slam_cd = 99.0
	for p in s.players.values():
		p.pos = Vector2(0, -15 * 32)
	return s

func check_bosses() -> void:
	# FML-05: night 4 never repeats night 2, and every archetype can come first
	var s = GameSim.new()
	var seen = {}
	var repeat: bool = false
	for i in range(300):
		s.rng.seed = i + 1
		s.draw_bosses()
		seen[s.boss_plan[0]] = true
		repeat = repeat or s.boss_plan[0] == s.boss_plan[1]
	self.check(seen.size() == 7 and not repeat, "all seven archetypes are drawn; night 4 never repeats night 2 (T-FML05)")
	s.rng.seed = 5
	s.draw_bosses()
	var first = s.boss_plan.duplicate()
	s.rng.seed = 5
	s.draw_bosses()
	self.check(s.boss_plan == first, "the same seed draws the same bosses")
	# FML-02 / table 4.2: HP for 4 players on Medium, night 2
	s = GameSim.new()
	for i in 4:
		s.add_player(i + 1, "P", 2 if i == 0 else 0)
	s.action(1, "start", 0)
	s.k = 2
	s.active = [0]
	var hp = []
	for kind in 7:
		s.boss_plan = [kind, 0]
		s.enemies.clear()
		s.spawn_boss()
		hp.append(roundi(s.boss().maxhp))
	self.check(hp == [3900, 4680, 3510, 3120, 4290, 3120, 2730], "boss HP per archetype at n = 4 matches table 4.2: " + Cs.s(hp))
	# Juggernaut: line telegraph, dash, 35 damage and knockback, then a slam and immediate pursuit
	s = self.boss_match(GameSim.JUGGERNAUT)
	var b = s.boss()
	var v = s.players[2]
	v.pos = b.pos + Vector2(0, 6 * 32)
	b.sig_cd = 0.0
	self.run(s, 0.1)
	self.check(s.tele.any(func(tl): return tl.kind == "line") and b.act == "charge_wind", "Juggernaut shows a line telegraph before its charge")
	self.check(v.hp == v.maxhp, "nothing is hit during the 1.0 s telegraph")
	self.run(s, 2.0)
	self.check(v.hp <= v.maxhp - 35, "the charge hits the player on the line for 35 (hp %d)" % [v.hp])
	self.run(s, 1.5)
	self.check(b.act != "recover", "after the dash and slam it resumes hunting without a recovery pause")
	# Broodmother: 2 Grunts per summon, at most 4, gone with the boss, no drops
	s = self.boss_match(GameSim.BROODMOTHER)
	b = s.boss()
	self.check(absf(b.spd - 0.75 * 2.16 * 32) < 0.01, "Broodmother moves at 0.75 x Grunt speed")
	b.spd = 0.0
	b.sig_cd = 0.0
	self.run(s, 1.1)
	var summons = func(): return s.enemies.filter(func(e): return e.get("summon", false)).size()
	self.check(summons.call() == 2, "Broodmother summons 2 Grunts after a 1.0 s glow")
	b.sig_cd = 0.0
	self.run(s, 1.1)
	b.sig_cd = 0.0
	self.run(s, 1.1)
	self.check(summons.call() == 4, "never more than 4 summons alive")
	var killer = s.players[1]
	killer.pos = b.pos + Vector2(40, 0)
	killer.aim = PI
	b.hp = 1.0
	s.hit(b, 10, killer)
	s.drops.clear()
	s.phase = "day"
	s.tick_enemies(0.016)
	self.check(summons.call() == 0 and s.drops.is_empty(), "summons vanish with the Broodmother and drop nothing")
	# Bio-Cannon: a ring of 8 projectiles
	s = self.boss_match(GameSim.BIO_CANNON)
	b = s.boss()
	s.players[2].pos = b.pos + Vector2(0, 6 * 32)
	b.sig_cd = 0.0
	self.run(s, 0.9)
	self.check(s.proj.size() == 0, "Bio-Cannon respects the full one-second wind-up")
	self.run(s, 0.25)  # allow two 20Hz decision steps around the one-second boundary
	self.check(s.proj.size() == 8, "Bio-Cannon fires a ring of 8 projectiles (%d)" % [s.proj.size()])
	# Burrower: cannot be hit underground, surfaces next to its target
	s = self.boss_match(GameSim.BURROWER)
	b = s.boss()
	v = s.players[2]
	v.pos = b.pos + Vector2(0, 6 * 32)
	b.sig_cd = 0.0
	self.run(s, 0.1)
	var hp0: float = float(b.hp)
	s.hit(b, 50, v)
	self.check(b.act == "burrow" and b.hp == hp0, "a burrowed Burrower cannot be hit")
	self.run(s, 4.0)
	self.check(v.hp <= v.maxhp - 35 and b.pos.distance_to(v.pos) >= 1.4 * 32, "it surfaces at least 1.5 tiles away and hits a player who stays")
	# Gatebreaker: one 120-point door blow after a 1.0 s wind-up
	s = self.boss_match(GameSim.GATEBREAKER)
	b = s.boss()
	b.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * (b.r + 6)
	b.cd = 0.0
	self.run(s, 0.5)
	self.check(s.doors[0] == GameSim.DOOR_HP, "the door blow waits for its wind-up")
	self.run(s, 0.7)
	self.check(absf(s.doors[0] - (GameSim.DOOR_HP - 120.0)) < 0.01, "Gatebreaker deals 120 door damage in one blow (%.1f)" % [s.doors[0]])
	# Phantom: cloaks, a hit reveals it
	s = self.boss_match(GameSim.PHANTOM)
	b = s.boss()
	v = s.players[2]
	v.pos = b.pos + Vector2(0, 7 * 32)
	b.sig_cd = 0.0
	self.run(s, 0.1)
	var en = s.snapshot().en[0]
	self.check(b.act == "cloak" and en[7] == "cloak", "Phantom turns invisible")
	s.hit(b, 10, v)
	self.check(b.act == "" and s.boss_look(b) == "shown", "a hit reveals the Phantom")
	# Ironhide: 30% damage from the front, full from behind or while staggered
	s = self.boss_match(GameSim.IRONHIDE)
	b = s.boss()
	b.face = 0.0
	v = s.players[2]
	hp0 = float(b.hp)
	v.pos = b.pos + Vector2(40, 0)
	s.hit(b, 100, v)
	var front: float = hp0 - float(b.hp)
	v.pos = b.pos - Vector2(40, 0)
	hp0 = float(b.hp)
	s.hit(b, 100, v)
	var back: float = hp0 - float(b.hp)
	self.check(absf(front - 30) < 0.01 and absf(back - 100) < 0.01, "Ironhide takes 30%% from the front, full from behind (%.0f / %.0f)" % [front, back])
	s.boss_act(b, "stagger", 3.0)
	v.pos = b.pos + Vector2(40, 0)
	hp0 = float(b.hp)
	s.hit(b, 100, v)
	self.check(absf(hp0 - float(b.hp) - 100) < 0.01, "a staggered Ironhide takes full damage from the front")
	# FML-09: threat counts the last 5 s only; switching needs 20% more than the current target
	s = self.new_match()
	s.nodes.clear()
	s.world.rebuild(s.nodes, s.towers)
	var a = s.players[1]
	var c = s.players[2]
	var g = s.spawn(GameSim.GRUNT, 0, 0.0)
	g.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 10 * 32
	g.spd = 0.0
	g.hp = 1000.0
	a.pos = g.pos + Vector2(0, 40)
	c.pos = g.pos + Vector2(0, -40)
	s.hit(g, 45, a)
	s.hit(g, 30, c)
	self.check(g.target == 1, "45 vs 30 damage: the enemy keeps chasing the bigger threat")
	s.hit(g, 25, c)
	self.check(g.target == 2, "55 > 1.2 x 45: it switches")
	s.clock += 4.0
	s.hit(g, 10, a)
	s.clock += 2.0
	s.retarget(g)
	self.check(s.threat(g, 2) == 0.0 and s.threat(g, 1) == 10.0 and g.target == 1, "hits older than 5 s no longer count")

# ---- tests/ai/SimCheck.Bots.cs
# Owner: Vu Duc Viet Anh. Bot teammate checks (Bots.cs; bot takeover cards A19-A21), run by tests/SimCheck.tscn.

func check_bots() -> void:
	var s = GameSim.new()
	s.add_player(1, "Me", 2)
	s.action(1, "add_bot", 0)
	s.action(1, "add_bot", 0)
	var bots = s.players.values().filter(func(p): return p.bot)
	self.check(bots.size() == 2 and bots.map(func(p): return p.role) == [1, 0] and s.leader() == 1, "two bots fill the missing roles (Healer, Scout); the person stays leader")
	s.action(1, "remove_bot", 0)
	s.action(1, "add_bot", 0)
	self.check(s.players.size() == 3, "bots can be removed and added in the lobby")
	s.action(1, "start", 0)
	self.run(s, 60)
	self.check(s.players.values().filter(func(p): return p.bot and s.count(p, "wood") + s.count(p, "stone") + s.count(p, "herb") > 0).size() >= 1, "gathering bot collects resources while Scout explores by day")
	self.check(s.snapshot().need == 1, "only people count for the day-skip vote")
	s.action(1, "vote", 0)
	self.run(s, 400, "night")
	# check idle guard positions before introducing enemies explicitly below
	s.next_wave = INF
	self.run(s, 8)
	var dn: int = int(s.active[0])
	var at_post = s.players.values().filter(func(p): return p.bot and not SimWorld.inside_base(p.pos) and p.pos.distance_to(GameSim.DOOR_POS[dn]) < 6 * 32)
	self.check(at_post.any(func(p): return p.role == 1), "at night the Healer bot holds the attacked door")
	# Both bots defend at night; objectives are collected only during the day.
	self.run(s, 40)
	at_post = s.players.values().filter(func(p): return p.bot and not SimWorld.inside_base(p.pos) and p.pos.distance_to(GameSim.DOOR_POS[dn]) < 6 * 32)
	self.check(at_post.size() == 2, "both bots return to guard the door without a night fetch quest")
	var hb = s.players.values().filter(func(p): return p.bot and p.role == 1)[0]
	var sb = s.players.values().filter(func(p): return p.bot and p.role == 0)[0]
	s.enemies.clear()
	var gb = s.spawn(GameSim.GRUNT, dn, 0.0)
	gb.pos = sb.pos + GameSim.DOOR_DIR[dn] * 2 * 32
	var ghp: float = float(gb.hp)
	self.run(s, 2.0)
	self.check(gb.hp < ghp or not s.enemies.has(gb), "a bot fights an enemy near its post")
	s.enemies.clear()
	var me = s.players[1]
	# Healing now requires a carried consumable, including for bots.
	s.set_count(hb, "healing_flask", 1)
	hb.bot_cd = 0.0
	hb.hp = hb.maxhp
	sb.hp = sb.maxhp
	me.pos = hb.pos + Vector2(32, 0)
	me.hp = 20.0
	self.run(s, 1.5)
	self.check(me.hp >= 28.0 and s.count(hb, "healing_flask") == 0, "the Healer bot consumes a crafted flask to heal a hurt teammate over time")
	me.state = 1
	me.bleed = 60.0
	me.pos = hb.pos + GameSim.DOOR_DIR[dn] * 5 * 32
	self.run(s, 14.0)
	self.check(me.state == 0, "a bot walks over and revives a downed teammate")
	s.remove_player(1)
	self.check(s.players.is_empty() and s.phase == "lobby", "when the last person leaves the bots go too")

# ---- tests/gameplay/SimCheck.Items.cs
# Owner: Pham Minh Hieu. Inventory, crafting time, bow, walls and result screen checks, run by tests/SimCheck.tscn.

func check_items() -> void:
	# Starting kits and the 8-slot inventory (BAL-18, BAL-42, MEC-09)
	var s = GameSim.new()
	s.add_player(1, "Eng", 2)
	s.add_player(2, "Scout", 0)
	s.add_player(3, "Healer", 1)
	s.action(1, "start", 0)
	var eng = s.players[1]
	var sc = s.players[2]
	var he = s.players[3]
	self.check(eng.inv.size() == 8 and eng.inv[0][0] == "hammer" and eng.inv.filter(func(x): return x != null).size() == 1, "Engineer starts with only the hammer in 8 slots")
	self.check(sc.inv[0][0] == "starter_bow" and he.inv.all(func(x): return x == null) and not he.has("flasks"), "Scout starts with a starter bow; Healer starts empty-handed with no free healing charges")
	self.check(he.weapon == "fists" and GameSim.WEAPON_STATS["fists"][0] == 15.0, "an empty hand fights bare-handed with the basic weapon's numbers (BAL-08)")
	s.set_count(eng, "wood", 45)
	self.check(s.count(eng, "wood") == 45 and eng.inv[2][1] == 20 and s.room(eng, "wood") == 15 + 4 * 20, "stacks hold 20 units")
	s.set_count(eng, "stone", 200)
	self.check(s.count(eng, "stone") == 80 and s.room(eng, "herb") == 0, "a full inventory takes no more")
	var herb = s.nodes.filter(func(n): return n.type == 2)[0]
	eng.pos = herb.pos
	eng.inter = true
	self.run(s, 4.0)
	eng.inter = false
	self.check(s.count(eng, "herb") == 0 and herb.amount == 5, "gathering stops when the inventory is full")
	# move to storage and back (needs the storage chest)
	s.set_count(eng, "stone", 0)
	s.set_count(eng, "wood", 20)
	eng.pos = GameSim.STORAGE_POS + Vector2(0, 24)
	var wood_slot: int = eng.inv.map(func(x): return x[0] if x != null else "").find("wood")
	s.action(1, "move_item", ["inv", wood_slot, "sto", 0])
	self.check(s.count(eng, "wood") == 0 and SimInventory.count_in(s.storage, "wood") == 20, "wood moved into base storage at the chest")
	eng.pos = Vector2(0, 15 * 32)
	s.action(1, "move_item", ["sto", 0, "inv", 5])
	self.check(SimInventory.count_in(s.storage, "wood") == 20, "storage cannot be reached from outside the base")
	eng.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	s.action(1, "move_item", ["sto", 0, "inv", 5])
	self.check(SimInventory.count_in(s.storage, "wood") == 20, "nor from elsewhere in the base (the workbench is not the chest)")
	eng.pos = GameSim.STORAGE_POS + Vector2(0, 24)
	s.action(1, "move_item", ["sto", 0, "inv", 5])
	self.check(s.count(eng, "wood") == 20 and eng.inv[5][0] == "wood", "and taken back into a chosen slot")
	s.action(1, "move_item", ["inv", 5, "inv", 0])
	self.check(eng.inv[0][0] == "wood" and eng.inv[5][0] == "hammer", "dragging onto a hotbar slot swaps the items")
	s.action(1, "select", 1)
	self.check(eng.sel == 1, "1-4 select the hotbar slot")
	# G gives the selected stack to a teammate in reach, otherwise drops it
	s.action(1, "select", 0)
	sc.pos = eng.pos + Vector2(32, 0)
	he.pos = Vector2(0, -15 * 32)
	s.action(1, "give", 0)
	self.check(s.count(eng, "wood") == 0 and s.count(sc, "wood") == 20, "G gives the selected stack to the nearest teammate")
	sc.pos = Vector2(0, -15 * 32)
	eng.pos = Vector2(0, 15 * 32)
	s.set_count(eng, "herb", 3)
	var herb_slot: int = eng.inv.map(func(x): return x[0] if x != null else "").find("herb")
	s.action(1, "move_item", ["inv", herb_slot, "inv", 3])
	s.action(1, "select", 3)
	s.action(1, "give", 0)
	self.check(s.count(eng, "herb") == 0 and s.drops.any(func(d): return d.item == "herb" and d.player), "with nobody in reach G drops the stack")
	self.run(s, 40.0)
	self.check(s.drops.size() == 1, "items dropped by players do not vanish")
	eng.inter = true
	self.run(s, 0.1)
	eng.inter = false
	self.check(s.count(eng, "herb") == 3 and s.drops.is_empty(), "E picks a dropped item back up")
	s.set_count(eng, "wood", 1)
	# Crafting is a 3 s channel at the workbench; leaving cancels it (BAL-19)
	eng.pos = GameSim.STORAGE_POS + Vector2(0, 24)
	s.set_count(eng, "herb", 2)
	self.check(not s.can_craft(eng, 0, false), "no crafting in the base away from the workbench")
	eng.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	s.action(1, "craft", 0)
	self.run(s, 1.0)
	eng.pos = Vector2(0, 15 * 32)
	self.run(s, 2.5)
	self.check(s.count(eng, "arrow") == 0 and s.count(eng, "wood") == 1 and eng.craft_idx == -1, "leaving the workbench cancels a craft and keeps the materials")
	# Bow and arrows (MEC-03, BAL-10, BAL-42)
	s.unlock = 1
	eng.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	s.set_count(eng, "wood", 8)
	s.set_count(eng, "titanium", 2)
	s.action(1, "craft", 2)
	self.run(s, 3.1)
	self.check(s.count(eng, "bow") == 1 and s.count(eng, "arrow") == 0 and s.count(eng, "wood") == 2, "Bow alone costs 6 wood + 2 titanium")
	s.action(1, "craft", 0)
	self.run(s, 3.1)
	self.check(s.count(eng, "arrow") == 5 and s.count(eng, "wood") == 1, "5 arrows cost 1 wood separately")
	s.action(1, "craft", 0)
	self.run(s, 3.1)
	var the_bow = eng.inv.filter(func(x): return SimInventory.is_bow(x))[0]
	self.check(SimInventory.loaded(the_bow) == 10 and not eng.inv.any(func(x): return x != null and x[0] == "arrow"), "the bow holds its arrows: all 10 loaded, no slot spent on arrows")
	s.nodes.clear()
	s.world.rebuild(s.nodes, s.towers)
	eng.pos = Vector2(0, 15 * 32)
	var bow_slot: int = eng.inv.map(func(x): return x[0] if x != null else "").find("bow")
	s.action(1, "move_item", ["inv", bow_slot, "inv", 2])
	s.action(1, "select", 2)
	var target = s.spawn(GameSim.GRUNT, 0, 0.0)
	target.pos = eng.pos + Vector2(7.5 * 32, 0)
	target.spd = 0.0
	target.state = 4
	target.home = target.pos
	target.wander = target.pos
	target.hp = 100.0
	eng.aim = 0.0
	eng.atk = true
	self.run(s, 0.05)
	eng.atk = false
	self.run(s, 1.0)
	self.check(target.hp == 88.0 and s.count(eng, "arrow") == 9, "an arrow hits an enemy 7.5 tiles away for 12 and uses one arrow (hp %.1f)" % [target.hp])
	target.pos = eng.pos + Vector2(9 * 32, 0)
	target.home = target.pos
	target.wander = target.pos
	eng.atk = true
	self.run(s, 0.05)
	eng.atk = false
	self.run(s, 1.0)
	self.check(target.hp == 88.0, "an arrow stops at its 8-tile range")
	s.set_count(eng, "arrow", 0)
	eng.atk = true
	self.run(s, 1.0)
	eng.atk = false
	self.check(s.arrows.is_empty(), "the crafted bow cannot fire without arrows")
	# loose arrows dragged onto the bow load into it, up to 30; the rest stays in its slot
	var q1: int = eng.inv.find(null)
	eng.inv[q1] = ["arrow", 20]
	var q2: int = eng.inv.find(null)
	eng.inv[q2] = ["arrow", 20]
	s.action(1, "move_item", ["inv", q1, "inv", 2])
	s.action(1, "move_item", ["inv", q2, "inv", 2])
	self.check(SimInventory.loaded(eng.inv[2]) == 30 and eng.inv[q1] == null and int(eng.inv[q2][1]) == 10, "arrows dragged onto the bow load it up to 30, the rest stays in its slot")
	# a dropped bow drops its arrows beside it; picked up again they go back in
	s.action(1, "give", null)
	self.check(s.count(eng, "bow") == 0 and s.count(eng, "arrow") == 10 and s.drops.any(func(d): return d.item == "arrow" and d.n == 30), "dropping the bow drops its 30 arrows with it")
	s.pick_up(eng)
	s.pick_up(eng)
	var again = eng.inv.filter(func(x): return SimInventory.is_bow(x))[0]
	self.check(again != null and SimInventory.loaded(again) == 30 and s.count(eng, "arrow") == 40, "picked up again, the bow is refilled from the bag first and the rest stays loose")
	s.set_count(eng, "arrow", 0)
	sc.pos = target.pos - Vector2(7.5 * 32, 0)
	s.action(2, "select", 0)
	sc.aim = 0.0
	sc.atk = true
	self.run(s, 0.05)
	sc.atk = false
	self.run(s, 1.0)
	self.check(target.hp == 76.0, "the Scout's starter bow needs no arrows and hits like the crafted bow (12 damage, 8 tiles; hp %.1f)" % [target.hp])
	# Wall construction was removed; malformed / old requests cannot spend resources.
	s.set_count(eng, "wood", 10)
	s.set_count(eng, "stone", 5)
	for kind in ["wood", "stone"]:
		s.action(1, "build", [kind, eng.pos + Vector2(0, 192), true])
	self.check(s.built_walls.is_empty() and s.count(eng, "wood") == 10 and s.count(eng, "stone") == 5, "wall construction is disabled for the Engineer")
	# Revival kit: looted into the bag, carried to the dead teammate and used there (hold E)
	s = self.new_match()
	var dead = s.players[2]
	dead.state = 2
	dead.pos = GameSim.DOOR_POS[2] + Vector2(10 * 32, 0)
	var fell: Vector2 = Vector2(dead.pos)
	var crafter = s.players[1]
	crafter.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	s.set_count(crafter, "herb", 4)
	s.set_count(crafter, "titanium", 4)
	s.craft(crafter, 9)
	self.run(s, 3.1)
	self.check(dead.state == 2 and s.count(crafter, "revive") == 1, "a crafted Revival kit is carried and revives nobody by itself")
	crafter.pos = fell + Vector2(24, 0)
	crafter.inter = true
	self.run(s, 1.0)
	self.check(dead.state == 2, "using the kit takes a few seconds")
	self.run(s, 2.2)
	crafter.inter = false
	self.check(dead.state == 0 and dead.hp == 0.5 * dead.maxhp and Vector2(dead.pos).distance_to(fell) < 2.0 and s.count(crafter, "revive") == 0, "the kit used on the body brings them back where they fell with 50% HP")
	# Result screen (section 2.5)
	s.base_hp = 0.0
	s.last_door = 1
	s.phase = "night"
	self.run(s, 0.1)
	self.check(s.phase == "result" and s.result[1] == "Generator destroyed at door B", "a loss names its cause and door: " + Cs.s(s.result))
	self.run(s, 30.0)
	self.check(s.phase == "result", "the result screen stays until Back to lobby")
	s.action(1, "lobby", 0)
	self.check(s.phase == "lobby" and s.result == null, "Back to lobby returns the team to the lobby")
