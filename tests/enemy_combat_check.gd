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
	sim.add_player(2, "Nearer", 1)
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
	check_hunting()
	check_nearest_structures()
	check_no_recovery()
	check_juggernaut_skills()
	print(("ENEMY COMBAT FAILED" if failed else "ENEMY COMBAT ALL OK") + ": %d checks" % checks)
	get_tree().quit(1 if failed else 0)

func reset(type: int, kind: int = 0) -> Variant:
	sim.enemies.clear()
	sim.proj.clear()
	sim.tele.clear()
	sim.clock = 0
	sim.k = 1
	sim.doors = [GameSim.DOOR_HP, GameSim.DOOR_HP, GameSim.DOOR_HP]
	sim.broken = [false, false, false]
	sim.base_hp = GameSim.BASE_HP
	sim.towers = [null, null, null]
	for player in sim.players.values():
		player.state = 2
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
	e.act = "charge_wind"
	e.act_t = 2.0
	step(0.5)
	check(p.hp == hp, name_ + " cannot basic-attack during a committed special wind-up")

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
	step(2.0)
	check(is_equal_approx(GameSim.DOOR_HP - float(sim.doors[0]), 150.0) and e.blow_cd > 0, "Gatebreaker uses ordinary structure attacks between special blows instead of idling for eight seconds")

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

func check_hunting() -> void:
	check(is_equal_approx(SimBosses.HUNT_RADIUS, 13 * GameSim.T), "boss detection is twice Scout night sight (13 tiles)")
	for kind in range(7):
		var e = reset(GameSim.BOSS, kind)
		var p = sim.players[1]
		var ally = sim.players[2]
		var name_: String = SimBosses.boss_title(kind)
		e.spd = 2 * GameSim.T
		p.pos = field + Vector2(0, 8 * GameSim.T)
		e.nodmg = 99.0
		e.calm = 99.0
		e.anchor = Vector2(9999, 9999)
		step(0.2)
		check(e.state == 1 and e.target == p.id and e.pos.distance_to(p.pos) < field.distance_to(p.pos) - 5, name_ + " hunts an unprovoked player beyond the old eight-tile range, without a leash or calm delay")
		ally.state = 0
		ally.inside = false
		ally.pos = e.pos + Vector2(0, 4 * GameSim.T)
		step(0.05)
		check(e.target == ally.id, name_ + " switches immediately to the nearer living player")
		SimPlayers.hit(sim, e, 10.0, p)
		step(0.05)
		check(e.target == ally.id and SimBosses.boss_target(sim, e) == ally, name_ + " ignores damage threat when choosing both basic and special targets")
		ally.state = 1
		step(0.05)
		check(e.target == p.id, name_ + " skips a downed nearer player")
		p.pos = e.pos + Vector2(0, 14 * GameSim.T)
		step(0.05)
		check(e.state != 1 and e.target == 0, name_ + " returns to structures when every player leaves the detection radius")
		p.pos = e.pos + Vector2(0, 2 * GameSim.T)
		step(0.05)
		check(e.state == 1 and e.target == p.id, name_ + " abandons its structure target as soon as a player comes back")
		p.pos = Vector2.ZERO
		p.inside = true
		e.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 3 * GameSim.T
		SimBosses.choose_target(sim, e)
		check(e.pos.distance_to(p.pos) < SimBosses.HUNT_RADIUS and e.state != 1, name_ + " does not chase an unreachable Engineer through an intact base even within detection range")

func check_nearest_structures() -> void:
	var e = reset(GameSim.BOSS, GameSim.IRONHIDE)
	var p = sim.players[1]
	p.state = 2
	e.spd = 2 * GameSim.T
	e.pos = GameSim.DOOR_POS[2] + GameSim.DOOR_DIR[2] * 4 * GameSim.T
	sim.active = [0]
	step(0.05)
	check(e.state == 2 and e.door == 2, "boss chooses the closest intact door, independently of its spawn door or active wave side")
	sim.place_tower(0, e.pos + Vector2(0, 8 * GameSim.T))
	SimBosses.choose_target(sim, e)
	check(e.state == 2, "a nearer base door wins over a farther tower")
	e.pos = field
	sim.towers[0].pos = e.pos + Vector2(0, 7 * GameSim.T)
	step(0.05)
	check(e.state == 5 and e.tw == 0 and e.pos != field, "boss approaches a closer tower even from outside the tower's light")
	e.pos = sim.towers[0].pos + Vector2(0, e.r + 0.7 * GameSim.T)
	e.cd = 0
	step(0.05)
	check(sim.towers[0].hp == GameSim.TOWER_HP - 30 and e.state == 5, "boss attacks its selected tower on reaching it")
	sim.towers[0].hp = 0
	SimBosses.choose_target(sim, e)
	check(e.state == 2, "a destroyed tower is not selected")
	sim.towers = [null, null, null]
	e.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 2 * GameSim.T
	sim.doors[0] = 0
	sim.broken[0] = true
	SimBosses.choose_target(sim, e)
	check(e.state == 3 and e.door == 0, "boss chooses the generator through the nearest breach when that route is shorter than intact doors")
	step(4.0)
	check(SimWorld.inside_base(e.pos) and sim.base_hp < GameSim.BASE_HP, "boss crosses the broken door and attacks the generator inside instead of being pushed outside")
	e.pos = Vector2(0, 30)
	SimBosses.choose_target(sim, e)
	check(e.state == 3, "inside the base the nearer generator is selected")
	p.state = 0
	p.inside = true
	p.pos = Vector2(0, -30)
	SimBosses.choose_target(sim, e)
	check(e.state == 1 and e.target == p.id, "a reachable player inside a breached base takes priority over the generator")

func check_no_recovery() -> void:
	for kind in range(7):
		var e = reset(GameSim.BOSS, kind)
		e.spd = 2 * GameSim.T
		sim.players[1].pos = field + Vector2(0, 4 * GameSim.T)
		e.act = "slam"
		e.act_t = 0.01
		e.dashed = true
		step(0.05)
		check(e.act == "" and e.pos.distance_to(field) > 1, SimBosses.boss_title(kind) + " resumes pursuing on the very tick its slam ends")
	var e = reset(GameSim.BOSS, GameSim.BURROWER)
	e.spd = 2 * GameSim.T
	sim.players[1].pos = field + Vector2(0, 4 * GameSim.T)
	e.surface = field
	e.act = "surface"
	e.act_t = 0.01
	step(0.05)
	check(e.act == "" and e.pos.distance_to(field) > 1, "Burrower resumes movement immediately after surfacing without a climb pause")
	e = reset(GameSim.BOSS, GameSim.PHANTOM)
	e.spd = 2 * GameSim.T
	e.act = "cloak"
	e.act_t = 4.0
	sim.players[1].pos = field + Vector2(0, 14 * GameSim.T)
	step(0.05)
	check(e.act == "" and e.state != 1 and e.pos.distance_to(field) > 1, "Phantom cancels an ambush with no player in range and immediately resumes its structure approach")

func check_juggernaut_skills() -> void:
	for kind in range(7):
		var e = reset(GameSim.BOSS, kind)
		e.slam_cd = 0.0
		SimBosses.boss_slam(sim, e, 0.05)
		check((e.act == "slam" and sim.tele.size() == 1) if kind == GameSim.JUGGERNAUT else (e.act == "" and sim.tele.is_empty()), SimBosses.boss_title(kind) + " only Juggernaut can trigger the proximity ground slam")
		if kind != GameSim.JUGGERNAUT:
			SimBosses.start_slam(sim, e)
			check(e.act == "" and sim.tele.is_empty(), SimBosses.boss_title(kind) + " rejects a direct ground-slam request")
	var e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	var p = sim.players[1]
	e.cd = INF
	SimBosses.start_slam(sim, e)
	var before: float = p.hp
	for i in range(19):
		sim.clock += 0.05
		sim.tick_enemies(0.05)
		SimEnemies.tick_tele(sim, 0.05)
	check(p.hp == before and e.act == "slam", "Juggernaut gives the full one-second warning before its slam damages anyone")
	for i in range(2):
		sim.clock += 0.05
		sim.tick_enemies(0.05)
		SimEnemies.tick_tele(sim, 0.05)
	var snap_: Array = sim.snapshot().en[0]
	check(p.hp == before - 40 and e.act == "" and float(snap_[13]) < 0.1, "Slam hits once for 40 and snapshots expose the matching impact frame without a recovery lock")
	check(EnemyView.boss_skill_animation(snap_)[0] == "slam_hit", "Client chooses the dedicated ground-impact sprite from authoritative timing")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	p.pos = field + Vector2(0, 6 * GameSim.T)
	e.sig_cd = 0.0
	step(0.05)
	check(e.act == "charge_wind" and sim.tele[0].kind == "line" and EnemyView.boss_skill_animation(sim.snapshot().en[0])[0] == "charge_wind", "Juggernaut prepares its dash with a line warning and crouching animation")
	step(1.0)
	check(e.act == "charge" and EnemyView.boss_skill_animation(sim.snapshot().en[0])[0] == "charge_run", "Dash uses its own looping full-body animation instead of the normal walk cycle")
	step(1.3)
	check(e.act == "slam" and sim.tele.any(func(tl): return tl.kind == "circle"), "The committed dash ends in Juggernaut's ground-slam follow-up")
	for look in ["slam", "charge_wind"]:
		var early: Array = [50, GameSim.BOSS, field, 100, 100, 35, GameSim.JUGGERNAUT, look, 0.0, false, false, false, 0.95, 99.0]
		var late: Array = early.duplicate()
		late[12] = 0.1
		var first: Array = EnemyView.boss_skill_animation(early)
		var last: Array = EnemyView.boss_skill_animation(late)
		check(float(first[1]) < float(last[1]) and last[0] == first[0], look + " progresses through its wind-up frames with server timing")
