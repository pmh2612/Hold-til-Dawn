extends Node

var checks: int = 0
var failed: bool = false
var sim: GameSim
var field: Vector2

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("FAIL (exception): " + what)
	else:
		print("ok   " + what)

func _ready() -> void:
	sim = GameSim.new()
	sim.add_player(1, "Test", 0)
	sim.start_match()
	sim.nodes.clear()
	sim.towers = [null, null, null]
	sim.world.rebuild([], sim.towers, [])
	sim.phase = "night"
	sim.k = 1
	field = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 12 * GameSim.T
	for kind in range(7):
		check_boss(kind)
	for type in [GameSim.GRUNT, GameSim.WRECKER]:
		check_regular(type)
	check_spitter()
	check_safety()
	check_structure_damage()
	check_real_tick_cadence()
	print(("ENEMY COMBAT FAILED" if failed else "ENEMY COMBAT ALL OK") + ": %d checks" % checks)
	get_tree().quit(1 if failed else 0)

func reset(type: int, kind: int = 0) -> Variant:
	sim.enemies.clear()
	sim.proj.clear()
	sim.tele.clear()
	sim.clock = 0
	sim.k = 1
	sim.built_walls.clear()
	sim.world.rebuild([], sim.towers, [])
	var e = sim.spawn(GameSim.GRUNT if type == GameSim.BOSS else type, 0, 0.0, false)
	if type == GameSim.BOSS:
		SimBosses.setup_boss(sim, e, kind)
		e.sig_cd = INF
		e.slam_cd = INF
	e.pos = field
	e.spd = 0.0
	var p = sim.players[1]
	p.state = 0
	p.inside = false
	p.hp = 1000.0
	p.maxhp = 1000.0
	p.armour = 0
	p.invuln = 0
	p.pos = field + Vector2(0, e.r + 0.5 * GameSim.T)
	return e

# Use real enemy ticks and the existing one-second player invulnerability, with spawning disabled.
func step(seconds: float) -> Array:
	var impacts: Array = []
	var p = sim.players[1]
	for i in range(roundi(seconds / 0.05)):
		sim.clock += 0.05
		p.invuln = maxf(0, p.invuln - 0.05)
		var hp: float = p.hp
		sim.tick_enemies(0.05)
		if p.hp < hp:
			impacts.append([sim.clock, hp - float(p.hp), sim.snapshot().en[0][9]])
	return impacts

func check_boss(kind: int) -> void:
	var e = reset(GameSim.BOSS, kind)
	var hits = step(3.0)
	var name_: String = SimBosses.boss_title(kind)
	check(hits.size() == 3 and hits.all(func(h): return h[1] == 12), name_ + " attacks a nearby player three times between specials, for 12 per hit")
	check(hits.size() >= 2 and hits[1][0] - hits[0][0] >= 1.19, name_ + " respects the 1.2-second basic cooldown")
	check(hits.size() > 0 and hits.all(func(h): return h[2]), name_ + " exposes the ordinary strike animation in snapshots")
	var p = sim.players[1]
	e.cd = 0.0
	var hp: float = p.hp
	e.act = "recover"
	e.act_t = 2.0
	step(0.5)
	check(p.hp == hp, name_ + " cannot basic-attack during a special recovery")

func check_regular(type: int) -> void:
	var e = reset(type)
	var hits = step(3.0)
	var expected: int = 4 if type == GameSim.GRUNT else 5
	check(hits.size() == 3 and hits.all(func(h): return h[1] == expected), "regular type %d attacks repeatedly with reduced damage, without waiting to be hit" % type)
	check(hits.size() >= 2 and hits[1][0] - hits[0][0] < 1.3, "regular type %d has no old two-second idle gap" % type)
	check(sim.snapshot().en[0][9] or e.cd > 0, "regular type %d remains in a valid strike/cooldown state" % type)

func check_spitter() -> void:
	var e = reset(GameSim.SPITTER)
	var p = sim.players[1]
	p.pos = field + Vector2(0, 4 * GameSim.T)
	step(3.0)
	check(sim.proj.size() == 3 and sim.proj.all(func(b): return b.dmg == 4), "Spitter fires every 1.25 seconds with four-damage projectiles")
	# A wall within shooting range must trigger navigation rather than an idle or a shot through it.
	var wall = {"id": 999, "kind": "stone", "pos": field + Vector2(0, 2 * GameSim.T), "vert": false, "hp": 400.0, "maxhp": 400.0}
	sim.built_walls.append(wall)
	sim.world.rebuild([], sim.towers, sim.built_walls)
	e.spd = 2 * GameSim.T
	e.cd = 0
	sim.proj.clear()
	var old: Vector2 = e.pos
	check(not SimWorld.line_clear(sim, old, p.pos), "Spitter test wall actually blocks sight")
	step(0.2)
	check(sim.proj.is_empty() and e.pos.distance_to(old) > 1, "Spitter approaches an obstructed target instead of standing idle or shooting through walls")

func check_safety() -> void:
	var e = reset(GameSim.BOSS, GameSim.IRONHIDE)
	var p = sim.players[1]
	p.pos += Vector2(0, 4 * GameSim.T)
	check(not SimEnemies.melee_attack(sim, e, p) and p.hp == 1000, "boss melee cannot hit outside its reach")
	p.pos = field + Vector2(0, e.r + 0.5 * GameSim.T)
	e.act = "charge_wind"
	check(not SimEnemies.melee_attack(sim, e, p), "boss cannot add a basic hit during a special wind-up")
	e.act = ""
	e.stun_until = sim.clock + 5.0
	step(0.5)
	check(p.hp == 1000, "stunned enemies cannot start ordinary attacks")
	e.stun_until = 0
	p.state = 1
	check(not SimEnemies.melee_attack(sim, e, p), "ordinary melee ignores downed players")
	p.state = 0
	p.inside = true
	check(not SimEnemies.melee_attack(sim, e, p), "an intact base still protects an Engineer inside")
	p.inside = false
	var wall = {"id": 999, "kind": "stone", "pos": field + Vector2(0, 24), "vert": false, "hp": 400.0, "maxhp": 400.0}
	sim.built_walls.append(wall)
	sim.world.rebuild([], sim.towers, sim.built_walls)
	check(not SimWorld.line_clear(sim, e.pos, p.pos) and not SimEnemies.melee_attack(sim, e, p), "ordinary boss attacks cannot pass through solid walls")

func check_structure_damage() -> void:
	var e = reset(GameSim.BOSS, GameSim.IRONHIDE)
	sim.players[1].pos = field + Vector2(0, 10 * GameSim.T)
	e.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * (e.r + 6)
	sim.doors[0] = GameSim.DOOR_HP
	step(4.0)
	check(is_equal_approx(GameSim.DOOR_HP - float(sim.doors[0]), 60.0), "ordinary boss structure hits are 30 damage every two seconds, preserving long-term damage")
	e = reset(GameSim.BOSS, GameSim.GATEBREAKER)
	e.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * (e.r + 6)
	sim.players[1].pos = field + Vector2(0, 10 * GameSim.T)
	sim.doors[0] = GameSim.DOOR_HP
	step(0.5)
	check(sim.doors[0] == GameSim.DOOR_HP and e.act == "blow", "Gatebreaker's signature still waits for its warning")
	step(0.7)
	check(is_equal_approx(GameSim.DOOR_HP - float(sim.doors[0]), 120.0), "Gatebreaker's signature still deals 120 damage after the warning")

func check_real_tick_cadence() -> void:
	# The player's immunity runs at 60 Hz while enemies run at 20 Hz. A cooldown must not waste
	# every other strike on the final fraction of a one-second immunity window.
	for type in [GameSim.GRUNT, GameSim.WRECKER, GameSim.BOSS]:
		reset(type, GameSim.IRONHIDE)
		sim.t = 1000
		sim.elapsed = 0
		sim.next_wave = INF
		sim.pending_wave_budget = 0
		sim.boss_spawned = true
		sim.enemy_step_accumulator = 0
		var p = sim.players[1]
		var hits: int = 0
		for frame in range(360):
			var hp: float = p.hp
			sim.tick(1.0 / 60)
			if p.hp < hp:
				hits += 1
		check(hits >= (6 if type == GameSim.GRUNT else 5), "enemy type %d maintains its attack cadence with real 60 Hz player / 20 Hz AI updates (%d hits / 6 s)" % [type, hits])
