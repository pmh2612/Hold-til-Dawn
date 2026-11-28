class_name NightSpawnCheck
extends Node
var checks: int = 0

func check(pass_: bool, what) -> void:
	if not pass_:
		Cs.fail(what)
		return
	checks += 1
	print("ok   " + what)

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	run()
	get_tree().quit()
	# catch (Exception Error) dropped

func prepare(sim, night: int) -> void:
	sim.k = night
	sim.enemies = []
	sim.active = [0, 1, 2]
	sim.rng.seed = 42
	sim.radio_built = true
	sim.night()
	sim.boss_spawned = true

func arrivals(sim, night: int, kill: bool) -> Variant:
	prepare(sim, night)
	var events = []
	var alive_peak: int = 0
	for step in range(2400):
		var now: float = step * 0.25
		sim.elapsed = now
		sim.t = 1000.0  # exercise the director independently of combat/end conditions
		var before: int = int(sim.next_id)
		sim.tick_waves()
		var born: int = int(sim.next_id) - before
		if born > 1:
			Cs.fail("A tick created multiple regular enemies")
			return null
		if born != 0:
			var e = sim.enemies[sim.enemies.size() - 1]
			events.append([now, int(e.type), int(e.door)])
		alive_peak = maxi(alive_peak, sim.enemies.size())
		if kill:
			sim.enemies.clear()
	check(alive_peak <= sim.night_enemy_limit, "night %s: alive limit %s respected" % [night, sim.night_enemy_limit])
	for i in range(1, events.size()):
		if events[i][0] - events[i - 1][0] < sim.night_spawn_spacing - 0.001:
			Cs.fail("Spawn spacing was bypassed")
			return null
	check(events.size() > 0 and events[0][0] >= sim.night_first_wave_delay, "night %s: warm-up and per-enemy spacing respected" % [night])
	return events

func run() -> void:
	var sim = GameSim.new()
	for i in range(1, 4):
		sim.add_player(i, "Test", i - 1)
	sim.start_match()
	var previous: int = 0
	var first_night = null
	for night in range(1, 6):
		var events = arrivals(sim, night, true)
		var quota: int = sim.night_quota
		var spawned: int = sim.night_spawned
		print("PACING night=%s regular_births/600s=%s first=%ss wave_every=%ss spacing=%ss cap=%s" % [night, events.size(), Cs.s(sim.night_first_wave_delay), Cs.s(sim.night_wave_interval), Cs.s(sim.night_spawn_spacing), sim.night_enemy_limit])
		check(events.size() > previous, "night %s: more enemies than the previous night" % [night])
		previous = events.size()
		if night == 1:
			first_night = events
			check(events.size() <= 30 and events.all(func(e): return e[1] == GameSim.GRUNT), "first night stays light and only uses Grunts")
			# while the first enemies are still alive the next wave keeps its schedule
			var held = arrivals(sim, 1, false)
			check(held[0][0] == 20 and held[1][0] == 22 and held[2][0] == 24 and held[3][0] >= 78, "first night: three quick enemies, then most of a minute of rest while they live (three-player normal mode)")
			# an empty field brings the next wave forward instead
			check(events[3][0] < 24 + 5 + sim.night_spawn_spacing + 0.3, "first night: a cleared field brings the next wave in 5 s")
		check(events.all(func(e): return int(GameSim.ENEMY[e[1]][4]) <= night), "later enemy types remain locked to their night")
		if night == 2:
			check(events.any(func(e): return e[1] == GameSim.SPITTER) and not events.any(func(e): return e[1] == GameSim.WRECKER), "night 2 introduces Spitters while Wreckers remain locked")
		elif night == 3:
			check(events.any(func(e): return e[1] == GameSim.WRECKER), "night 3 introduces Wreckers")
		var boss: int = 1 if night == 2 or night == 4 else 0
		check(quota > boss and events.size() == quota - boss and spawned == events.size(), "night %s: exactly the night's quota of %s regular enemies comes%s" % [night, quota - boss, " (plus the boss)" if boss > 0 else ""])
		arrivals(sim, night, false)
	var replay = arrivals(sim, 1, true)
	check(first_night.size() == replay.size() and first_night.all(func(e): return replay.has(e)), "same seed produces the same paced arrivals")
	prepare(sim, 1)
	sim.elapsed = 500.0
	sim.tick_waves()
	check(int(sim.wave) == 1 and sim.enemies.size() == 1 and float(sim.next_wave) > 500, "a large clock jump never catches up missed waves in a burst")
	sim.tick_waves()
	check(sim.enemies.size() == 1, "repeated calls at the same time do not spawn twice")
	sim.dawn()
	sim.phase = "night"
	sim.next_wave = INF
	sim.elapsed = 510.0
	sim.tick_waves()
	check(sim.enemies.size() == 1, "dawn discards unfinished arrivals")
	prepare(sim, 1)
	sim.elapsed = 60.0
	sim.tick_waves()
	sim.end(false, "Test")
	sim.phase = "night"
	sim.t = 100
	sim.next_wave = INF
	sim.elapsed = 70.0
	sim.tick_waves()
	check(sim.enemies.size() == 0, "result screen discards unfinished arrivals")
	prepare(sim, 1)
	sim.elapsed = 60.0
	sim.tick_waves()
	sim.to_lobby()
	sim.phase = "night"
	sim.t = 100
	sim.next_wave = INF
	sim.elapsed = 70.0
	sim.tick_waves()
	check(sim.enemies.size() == 0, "lobby discards unfinished arrivals")
	prepare(sim, 1)
	sim.elapsed = 60.0
	sim.tick_waves()
	sim.t = 0
	sim.elapsed = 66.0
	sim.tick_waves()
	check(sim.enemies.size() == 1, "no final burst at the night deadline")
	# The night's quota: the HUD count, and dawn once every enemy of it is dead.
	prepare(sim, 1)
	sim.phase = "night"
	sim.base_hp = 1000
	sim.night_spawned = sim.night_quota - 1
	var last = sim.spawn(GameSim.GRUNT, 0, 30.0)
	last.quota = true
	sim.night_spawned += 1
	sim.check_end(0.1)
	check(sim.phase == "night" and sim.night_killed() == sim.night_quota - 1, "the night goes on while one of its enemies lives")
	last.hp = 0.0
	sim.enemies = sim.enemies.filter(func(e): return e.hp > 0)
	check(sim.night_killed() == sim.night_quota and sim.night_all_down(), "the bar is full once the last one dies")
	sim.check_end(0.1)
	check(sim.phase == "day" and int(sim.k) == 2, "clearing the enemy quota ends the night without fetch quests")
	prepare(sim, 2)
	sim.boss_spawned = false
	sim.phase = "night"
	sim.base_hp = 1000
	check(sim.night_quota >= 2, "the boss counts toward nights 2 and 4")
	sim.night_spawned = sim.night_quota - 1
	sim.elapsed = 100.0
	sim.tick_waves()
	sim.elapsed = 111.0
	sim.tick_waves()
	check(sim.boss_spawned and sim.night_spawned == sim.night_quota, "once the regular enemies are cleared the boss comes early")
	# All enemies ask for a route after a collider revision. The bounded rotating update must serve all.
	prepare(sim, 5)
	sim.next_wave = INF
	for i in range(16):
		sim.spawn(GameSim.GRUNT, i % 3, 30.0)
	var began = {}
	for e in sim.enemies:
		began[int(e.id)] = e.pos
	for i in range(24):
		sim.tick_enemies(0.05)
		check(sim.enemy_navigation_updates_this_tick <= 2, "at most two enemy navigation recalculations per tick")
	for e in sim.enemies:
		check(e.has("nav_way") and Vector2(e.pos).distance_to(began[int(e.id)]) > 1, "rotating navigation budget serves each enemy without starvation")
	# Compare the new typed route against the established implementation for the same geometry.
	var world = sim.world
	world.static_solids = [[Vector2(500, 0), 24.0, true]]
	sim.nodes = []
	sim.towers = []
	world.rebuild(sim.nodes, sim.towers)
	var walls = [Rect2(-Vector2(GameSim.HALF), Vector2(GameSim.HALF) * 2)]
	var legacy_walls = [walls[0]]
	for radius in [16.0, 20.0, 35.2]:
		for offset in [-24.0, 0.0, 24.0]:
			var from = Vector2(400, offset)
			var to = Vector2(650, 0)
			var expected: Vector2 = world.waypoint(from, to, radius, legacy_walls)
			check(world.waypoint_fast(from, to, radius, walls).is_equal_approx(expected), "typed navigation matches the original route around a rock")
	var builds: int = world.navigation_grid_builds
	var searches: int = world.navigation_path_searches
	for i in range(10):
		world.waypoint_fast(Vector2(400, 0), Vector2(650, 0), 16.0, walls)
	check(world.navigation_grid_builds == builds and world.navigation_path_searches == searches, "unchanged routes reuse native grid and path caches")
	world.static_solids = []
	world.rebuild(sim.nodes, sim.towers)
	check(world.waypoint_fast(Vector2(400, 0), Vector2(650, 0), 16.0, walls) == Vector2(650, 0), "removing a blocker invalidates the old navigation route")
	print("NIGHT SPAWN ALL OK: %s checks" % [checks])
