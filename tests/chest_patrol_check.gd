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

func reset_patrol(s: GameSim, chest, p, day: int = 1) -> void:
	s.phase = "day"
	s.k = day
	s.enemies.clear()
	s.chest_roam_scan_left = 0
	s.chest_roam_spawn_left = 0
	chest.opened = false
	chest.patrol_day = 0
	chest.patrol_spawned = 0
	p.pos = chest.pos + Vector2(0, 6 * GameSim.T)
	p.state = 0
	p.atk = false
	p.inter = false

func _ready() -> void:
	var s = GameSim.new()
	s.add_player(1, "Engineer", 2)
	s.start_match()
	var p = s.players[1]
	var chests = s.exploration_chests.duplicate()
	for i in range(30):
		SimRoamers.tick_chest_patrols(s, 0.5)
	check(s.enemies.is_empty(), "no patrols spawn across the island while the player stays home")
	for chest in chests:
		s.exploration_chests = [chest]
		reset_patrol(s, chest, p)
		SimRoamers.tick_chest_patrols(s, 0.1)
		check(s.enemies.size() == 1, "chest %d starts with one paced arrival" % chest.id)
		for i in range(6):
			SimRoamers.tick_chest_patrols(s, 0.5)
		check(s.enemies.size() == 2, "chest %d has two patrol enemies on day one" % chest.id)
		check(s.enemies.all(func(e): return e.chest_patrol == chest.id and Vector2(e.home) == chest.pos and Vector2(e.pos).distance_to(chest.pos) <= 4.2 * GameSim.T and IslandMap.on_land(e.pos, e.r) and Vector2(s.world.resolve_fast(e.pos, e.r)).distance_squared_to(e.pos) <= 1 and SimWorld.line_clear(s, chest.pos, e.pos)), "chest %d patrols stand close on accessible land" % chest.id)
	var c = chests[0]
	s.exploration_chests = chests
	reset_patrol(s, c, p)
	# Keep other sites out of the director while testing one chest's limits.
	for other in chests:
		other.opened = other != c
	p.pos = c.pos
	SimRoamers.tick_chest_patrols(s, 0.1)
	SimRoamers.tick_chest_patrols(s, 60.0)
	check(s.enemies.size() == 2, "a long frame adds at most one patrol enemy")
	for e in s.enemies:
		s.hit(e, 10000, p)
	s.enemies.clear()
	SimRoamers.tick_chest_patrols(s, 60.0)
	check(s.enemies.is_empty(), "clearing a patrol does not create endless same-day replacements")
	reset_patrol(s, c, p, 3)
	for i in range(8):
		SimRoamers.tick_chest_patrols(s, 0.5)
	check(s.enemies.size() == 3, "later days increase unopened chest patrols to three")
	reset_patrol(s, c, p, 4)
	for i in range(8):
		SimRoamers.tick_chest_patrols(s, 0.5)
	check(s.enemies.filter(func(e): return e.type == GameSim.SPITTER).size() == 1, "day four mixes in one Spitter")
	var before: int = s.enemies.size()
	p.pos = c.pos
	p.inter = true
	s.set_count(p, "chest_key", 1)
	check(s.try_loot_chest(p, 2.0) and c.opened and s.enemies.size() == before, "living patrol enemies never block unlocking a chest")
	SimRoamers.tick_chest_patrols(s, 60.0)
	check(s.enemies.size() == before, "opened chests do not request reinforcements")
	reset_patrol(s, c, p)
	for i in range(GameSim.ROAM_MAX):
		var e = s.spawn(GameSim.GRUNT, 0, 0.0)
		e.home = e.pos
	SimRoamers.tick_chest_patrols(s, 10.0)
	check(s.enemies.size() == GameSim.ROAM_MAX and c.patrol_spawned == 0, "patrols share the existing fourteen-roamer CPU cap")
	s.enemies.clear()
	s.phase = "night"
	SimRoamers.tick_chest_patrols(s, 10.0)
	check(s.enemies.is_empty(), "chest patrol spawning stays inactive at night")
	print(("CHEST PATROL FAILED" if failed else "CHEST PATROL ALL OK") + ": %d checks" % checks)
	get_tree().quit(1 if failed else 0)
