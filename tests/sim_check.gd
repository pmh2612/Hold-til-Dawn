extends SceneTree
## Headless check of the server rules: godot --headless --path . -s tests/sim_check.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func run(s, seconds: float, until_phase := "") -> void:
	for i in int(seconds * 60):
		s.tick(1.0 / 60)
		if until_phase != "" and s.phase == until_phase:
			return


func new_match():
	var s = preload("res://game.gd").new()
	s.add_player(1, "Eng", 2)
	s.add_player(2, "Scout", 0)
	s.action(1, "start", 0)
	return s


func _init() -> void:
	var s = new_match()
	check(s.phase == "day" and s.active.size() == 1, "match starts on day 1 with one attacked door")
	check(s.nodes.filter(func(n): return n.type == 0).size() == (4 + 3 * 2) * s.NODE_MUL, "4 + 3n nodes per type (x NODE_MUL)")

	var eng = s.players[1]
	var wood = s.nodes.filter(func(n): return n.type == 0)[0]
	eng.pos = wood.pos
	eng.inter = true
	run(s, 15)
	check(eng.inv.wood == 5 and wood.amount == 0, "gathering at 0.35/s empties a 5-unit node in ~15 s")
	eng.inter = false
	var stone = s.nodes.filter(func(n): return n.type == 1)[0]
	eng.pos = stone.pos
	eng.inter = true
	for i in 60 * 6:  # wiggle 1.2 tiles back and forth while holding E
		eng.pos = stone.pos + Vector2(20.0 * sin(i * 0.2), 0)
		s.tick(1.0 / 60)
	check(eng.inv.stone == 0 and stone.amount == 5, "moving while holding E gathers nothing (MEC-08)")
	eng.pos = stone.pos
	run(s, 1.5)
	check(eng.gather_acc > 0.4 and eng.gather_acc < 0.6 and s.snapshot().ps[1][21] == eng.gather_acc, "gather progress is in the snapshot")
	eng.inter = false
	run(s, 0.1)
	check(eng.gather_acc == 0.0, "releasing E resets gather progress")

	eng.pos = Vector2.ZERO
	eng.inv.wood = 6
	s.action(1, "craft", 0)
	check(eng.armour == 1 and eng.inv.wood == 0, "light armour crafted at workbench")
	s.action(1, "craft", 4)
	check(eng.weapon == 0, "stone spear locked before night 1")

	s.t = 0
	run(s, 0.1)
	check(s.phase == "dusk", "day -> dusk")
	run(s, 16, "night")
	check(s.phase == "night" and not s.inside_base(eng.pos), "night starts, players moved outside")

	# A team that never defends loses night 1: the door breaks, then Grunts drain the generator.
	for p in s.players.values():
		p.pos = Vector2(0, 40 * 32)
	run(s, 601, "result")
	check(s.phase == "result" and "Generator" in s.msg, "idle team loses night 1: " + s.msg)

	# Progression path (debug skip), with an unkillable base so the boss timer can be tested.
	s = new_match()
	s.base_hp = 1e9
	s.action(1, "skip", 0)
	run(s, 0.1)
	run(s, 16, "night")
	s.action(1, "skip", 0)
	run(s, 0.1)
	check(s.k == 2 and s.phase == "day" and s.unlock == 1, "night 1 cleared, stone tier unlocked")
	s.action(1, "skip", 0)
	run(s, 0.1)
	run(s, 16, "night")
	for p in s.players.values():
		p.pos = Vector2(0, 40 * 32)
	run(s, 305)
	var boss = s._boss()
	check(boss != null, "boss spawned on night 2")
	if boss:
		boss.hp = 1
		var sc = s.players[2]
		sc.pos = boss.pos - Vector2(32, 0)
		sc.aim = 0.0
		sc.atk = true
		run(s, 0.2)
		sc.atk = false
		check(s.k == 3 and s.unlock == 2, "killing the boss ends night 2 and unlocks metal tier")

	# Engineer night entry (MEC-15)
	s = new_match()
	s.action(1, "skip", 0)
	run(s, 0.1)
	run(s, 16, "night")
	var e1 = s.players[1]
	var sc2 = s.players[2]
	e1.pos = s.DOOR_POS[0] + s.DOOR_DIR[0] * 32
	e1.ent = true
	run(s, 2.1)
	e1.ent = false
	check(e1.inside and s.inside_base(e1.pos), "Engineer holds F 2 s at a closed door and gets inside")
	e1.inv.herb = 2
	s.action(1, "craft", 1)
	check(e1.inv.bandage == 1, "Engineer crafts at night inside")
	sc2.pos = s.DOOR_POS[1] + s.DOOR_DIR[1] * 32
	sc2.ent = true
	run(s, 2.1)
	check(not sc2.inside and not s.inside_base(sc2.pos), "Scout cannot enter at night")
	e1.ent = true
	run(s, 2.1)
	e1.ent = false
	check(not e1.inside and not s.inside_base(e1.pos), "Engineer leaves the same way")
	# Engineer repairs a door at night from outside (MEC-12, FML-08)
	e1.pos = s.DOOR_POS[0] + s.DOOR_DIR[0] * 24
	s.doors[0] = 300.0
	s.door_pause[0] = 0.0
	e1.inv.wood = 0
	e1.inter = true
	run(s, 1.0)
	check(s.doors[0] == 300.0, "no repair without wood")
	e1.inv.wood = 10
	run(s, 2.0)
	check(s.doors[0] > 328.0 and s.doors[0] < 332.0 and e1.inv.wood == 7, "night repair: +15/s and 1 wood per 10 (%.1f, wood %d)" % [s.doors[0], e1.inv.wood])
	s.door_pause[0] = 2.0
	var before: float = s.doors[0]
	run(s, 1.0)
	check(s.doors[0] == before, "a hit on the door pauses repair for 2 s")
	e1.inter = false
	check(s.snapshot().has("dpause") and s.snapshot().has("broken"), "repair state is in the snapshot")
	# enemies from the far side reach their door around the walls
	var G2 = preload("res://game.gd")
	var ep := Vector2(0, 30 * 32)
	var goal: Vector2 = G2.DOOR_POS[0] + G2.DOOR_DIR[0] * 22
	for i in 2000:
		ep += (G2._route(ep, goal, 16.0) - ep).normalized() * 3.0
		ep = G2.push_out(ep, 16.0)
		if ep.distance_to(goal) < 4:
			break
	check(ep.distance_to(goal) < 4, "enemy spawned behind the base walks around to door A")

	# Daytime roamers (MEC-26, FML-16)
	var G3 = preload("res://game.gd")
	var wall: float = G3.HALF.y  # points straight south of the base: wall distance = y - HALF.y
	check(G3.roam_chance(Vector2(0, wall + 19 * 32)) == 0.0, "no roamer chance inside 20 tiles")
	check(absf(G3.roam_chance(Vector2(0, wall + 40 * 32)) - 0.15) < 0.001, "roamer chance 15% at 40 tiles")
	check(absf(G3.roam_chance(Vector2(0, wall + 65 * 32)) - 0.3) < 0.001, "roamer chance capped at 30%")
	s = new_match()
	var far = s.players[2]
	var near = s.players[1]
	far.pos = Vector2(0, wall + 55 * 32)
	near.pos = Vector2(0, -(wall + 10 * 32))
	run(s, 300)
	var roam = s.enemies.filter(func(e): return e.has("home"))
	check(roam.size() >= 2 and roam.size() <= s.ROAM_MAX, "roamers met far from the base (%d alive)" % roam.size())
	check(roam.all(func(e): return e.pos.distance_to(near.pos) > 20 * 32), "no roamer near the player in the safe zone")
	check(roam.all(func(e): return e.state == 4 or e.state == 1), "roamers wander or chase by day, never go to a door")
	check(far.state == 0, "a player standing still out of their sight is left alone")
	s.t = 0
	run(s, 0.1)
	check(s.phase == "dusk" and roam.all(func(e): return e.state == 0 and e.door in s.active and not e.has("home")), "at dusk roamers head for an attacked door")
	# a roamer that spots a player chases and hurts them
	s = new_match()
	var vic = s.players[2]
	vic.pos = Vector2(0, wall + 50 * 32)
	s._spawn_roamers(vic)
	var r0 = s.enemies.filter(func(e): return e.has("home"))
	check(r0.size() == 2, "a roamer group is a pair")
	if r0.size() > 0:
		r0[0].pos = vic.pos + Vector2(3 * 32, 0)
		run(s, 3)
		check(vic.hp < vic.maxhp, "roamer within 4 tiles chases and hits")
	# team wiped by day is a loss
	for p in s.players.values():
		p.state = 1
		p.bleed = 30.0
	run(s, 0.1)
	check(s.phase == "result" and "wiped" in s.msg, "team wiped by day loses")

	# Drops (BAL-41, FML-15)
	s = new_match()
	for i in 10000:
		s._drop({"type": 0, "pos": Vector2.ZERO})
	var want: float = 1000.0 * s.DROP_MUL  # BAL-41: 10% x playtest multiplier
	check(absf(s.drops.size() - want) <= 0.1 * want, "Grunt drop rate %d%% +-10%% (%d / 10000)" % [want / 100, s.drops.size()])
	check(s.drops.all(func(d): return d.item in ["wood", "stone", "herb"] and d.n >= 1 and d.n <= 2), "Grunt drops 1-2 wood/stone/herb")
	s.drops.clear()
	s._drop({"type": s.BOSS, "pos": Vector2(0, 30 * 32)})
	var pick = s.players[2]
	pick.pos = Vector2(0, 30 * 32)
	run(s, 0.1)
	check(pick.inv.metal == 10, "boss drop collected by walking over it (+10 metal)")
	s.drops.clear()
	s._add_drop(Vector2(0, 30 * 32 + 300), "wood", 2)
	run(s, 31)
	check(s.drops.is_empty(), "uncollected drop vanishes after 30 s")
	s._add_drop(Vector2.ZERO, "wood", 2)
	pick.pos = Vector2.ZERO
	var w0 = pick.inv.wood
	run(s, 0.5)
	check(pick.inv.wood == w0, "drops cannot be collected from inside the base")

	# Walls: only doors let players in.
	var G = preload("res://game.gd")
	var walk = func(start: Vector2, step: Vector2, open: Array) -> Vector2:
		var pos := start
		for i in 200:
			pos = G.collide(pos + step, 12.8, open)
		return pos
	check(walk.call(Vector2(0, G.HALF.y + 40), Vector2(0, -2), [true, true, true]).y > G.HALF.y, "bottom wall blocks (no door)")
	check(walk.call(Vector2(0, -G.HALF.y - 40), Vector2(0, 2), [true, true, true]).y > 0, "open door B (north) lets you in")
	check(walk.call(Vector2(0, -G.HALF.y - 40), Vector2(0, 2), [true, false, true]).y < -G.HALF.y, "closed door B blocks")
	check(walk.call(Vector2(-G.HALF.x - 40, 0), Vector2(2, 0), [true, true, true]).x > 0, "open door A (west) lets you in")
	check(walk.call(Vector2(G.HALF.x + 40, 0), Vector2(-2, 0), [true, true, false]).x > G.HALF.x, "closed door C (east) blocks")
	check(walk.call(Vector2(-G.HALF.x - 40, 60), Vector2(2, 0), [true, true, true]).x < -G.HALF.x, "west wall beside door A blocks")

	# Geometry from the GDD (BAL-21, BAL-34, section 4.3)
	check(G.HALF == Vector2(15, 10) * 16 and G.DOOR_POS[0].x < 0 and G.DOOR_POS[1].y < 0 and G.DOOR_POS[2].x > 0, "15 x 10 base, doors A west, B north, C east")
	s = new_match()
	s.k = 3
	s.active = [0, 1, 2]
	s._spawn_wave()
	var in_band = func(e) -> bool:  # 25-35 tiles in front of its door, within 22 tiles to the side (fig. 4.1)
		var rel: Vector2 = e.pos - G.DOOR_POS[e.door]
		var dd: Vector2 = G.DOOR_DIR[e.door]
		var fwd := rel.dot(dd) / 32.0
		return fwd >= 24.99 and fwd <= 35.01 and absf(rel.dot(Vector2(-dd.y, dd.x))) <= 22.01 * 32
	var south = func(e) -> bool: return absf(e.pos.x) < G.HALF.x and e.pos.y > G.HALF.y
	check(s.enemies.size() > 0 and (G.SPAWN_ALL_SIDES or s.enemies.all(in_band)), "night spawns in a band 25-35 tiles in front of each active door")
	check(G.SPAWN_ALL_SIDES or not s.enemies.any(south), "no night spawn south of the base")
	check(s.nodes.all(func(n): return not G.in_door_lane(n.pos) and (G.wall_dist(n.pos) <= 20 * 32 if n.type < 3 else G.wall_dist(n.pos) > 20 * 32)), "resource nodes in the safe zone, metal beyond it, door corridors clear")
	s.k = 2
	s.active = [1]
	s._spawn_boss()
	var b = s._boss()
	check(b != null and b.pos.distance_to(G.DOOR_POS[1] + G.DOOR_DIR[1] * 60 * 32) < 1.0, "boss starts 60 tiles in front of its door")

	var snap = s.snapshot()
	check(snap.has("ps") and snap.ps.size() == 2, "snapshot has both players")
	print("FAILED %d" % fails if fails else "ALL OK")
	quit(1 if fails else 0)
