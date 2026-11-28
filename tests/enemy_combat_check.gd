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
	check_hit_reactions()
	check_alternating_skills()
	check_charge_obstacles()
	check_charge_escape()
	check_chainwarden()
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
		player.hit_kind = ""
	sim.built_walls.clear()
	sim.world.rebuild([], sim.towers, [])
	var e = sim.spawn(GameSim.GRUNT if type == GameSim.BOSS else type, 0, 0.0, false)
	if type == GameSim.BOSS:
		SimBosses.setup_boss(sim, e, kind)
		e.sig_cd = INF
		e.special_cd = INF
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
		e.act = "slam_impact" if kind == GameSim.JUGGERNAUT else "sweep_hit" if kind == GameSim.CHAINWARDEN else "slam"
		e.act_t = 0.01
		e.dashed = true
		step(0.05)
		check(e.act == "" and e.pos.distance_to(field) > 1, SimBosses.boss_title(kind) + " resumes pursuing on the very tick its committed animation ends")
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
		e.special_cd = 0.0
		SimBosses.boss_slam(sim, e, 0.05)
		check((e.act == "slam" and sim.tele.size() == 1) if kind == GameSim.JUGGERNAUT else (e.act == "" and sim.tele.is_empty()), SimBosses.boss_title(kind) + " only Juggernaut can trigger the proximity ground slam")
		if kind != GameSim.JUGGERNAUT:
			SimBosses.start_slam(sim, e)
			check(e.act == "" and sim.tele.is_empty(), SimBosses.boss_title(kind) + " rejects a direct ground-slam request")
	var e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	var p = sim.players[1]
	e.cd = INF
	SimBosses.start_slam(sim, e)
	check(sim.snapshot().tele.is_empty() and sim.tele.size() == 1, "Juggernaut's slam warning is hidden from every client without removing its damage timer")
	var before: float = p.hp
	for i in range(29):
		sim.clock += 0.05
		sim.tick_enemies(0.05)
		SimEnemies.tick_tele(sim, 0.05)
	check(p.hp == before and e.act == "slam", "Juggernaut gives the full 1.5-second warning before its slam damages anyone")
	for i in range(2):
		sim.clock += 0.05
		sim.tick_enemies(0.05)
		SimEnemies.tick_tele(sim, 0.05)
	var snap_: Array = sim.snapshot().en[0]
	check(p.hp == before - 40 and e.act == "slam_impact" and float(snap_[13]) < 0.1, "Slam hits once for 40 and keeps the longer ground-impact pose")
	check(EnemyView.boss_skill_animation(snap_)[0] == "slam_hit", "Client chooses the dedicated ground-impact sprite from authoritative timing")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	p.pos = field + Vector2(0, 6 * GameSim.T)
	e.next_skill = "charge"
	e.special_cd = 0.0
	step(0.05)
	check(e.act == "charge_wind" and sim.tele[0].kind == "line" and EnemyView.boss_skill_animation(sim.snapshot().en[0])[0] == "charge_wind", "Juggernaut prepares its dash with a line warning and crouching animation")
	check(sim.snapshot().tele.is_empty(), "Juggernaut's charge no longer displays the red line warning")
	SimBosses.add_telegraph(sim, "arc", field, GameSim.T, 0.0)
	check(sim.snapshot().tele.size() == 1 and sim.snapshot().tele[0][3] == "arc", "Other bosses' ground warnings remain visible")
	step(1.0)
	check(e.act == "charge" and EnemyView.boss_skill_animation(sim.snapshot().en[0])[0] == "charge_run", "Dash uses its own looping full-body animation instead of the normal walk cycle")
	step(1.3)
	check(e.act == "" and e.special_cd > 0 and not sim.tele.any(func(tl): return tl.kind == "circle"), "The dash ends without an automatic slam and starts the shared special cooldown")
	for look in ["slam", "charge_wind"]:
		var early: Array = [50, GameSim.BOSS, field, 100, 100, 35, GameSim.JUGGERNAUT, look, 0.0, false, false, false, 0.95, 99.0]
		var late: Array = early.duplicate()
		late[12] = 0.1
		var first: Array = EnemyView.boss_skill_animation(early)
		var last: Array = EnemyView.boss_skill_animation(late)
		check(float(first[1]) < float(last[1]) and last[0] == first[0], look + " progresses through its wind-up frames with server timing")

func check_hit_reactions() -> void:
	var e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	var p = sim.players[1]
	var ally = sim.players[2]
	ally.state = 0
	ally.pos = field + Vector2(0, 5 * GameSim.T)
	SimBosses.start_slam(sim, e)
	SimEnemies.tick_tele(sim, SimBosses.SLAM_WINDUP - 0.01)
	check(not SimPlayers.is_reacting(p), "Slam warning alone never launches a player")
	SimEnemies.tick_tele(sim, 0.02)
	check(p.hp == 960 and SimPlayers.is_reacting(p) and p.hit_kind == "slam", "A confirmed slam hit starts the launch reaction")
	check(not SimPlayers.is_reacting(ally), "A player outside the slam area is never launched")
	var hit: Array = sim.snapshot().hit_reactions[p.id]
	check(hit[1] == "slam" and is_equal_approx(hit[3], 0.7) and sim.snapshot().ps[p.id].size() == 36, "Snapshot sends reaction timing and direction without changing the 36 inventory/player fields")
	var initial: Vector2 = p.pos
	p.move_credit = 1000
	sim.input(p.id, p.pos + Vector2(100, 0), 0.0, true, true, true, p.tp, 500)
	sim.set_count(p, "bandage", 1)
	sim.action(p.id, "bandage", null)
	check(p.pos == initial and not p.atk and not p.inter and not p.ent and p.channel == 0, "Airborne players cannot steer, attack, interact or begin healing")
	for i in range(15):
		sim.clock += 0.05
		SimPlayers.tick_players(sim, 0.05)
	check(not SimPlayers.is_reacting(p) and p.pos.distance_to(initial) > 5 and p.pos.distance_to(initial) <= 0.6 * GameSim.T + 0.01, "Slam moves the player a short distance over time, lands, and restores control")
	sim.input(p.id, p.pos + Vector2(2, 0), 0.0, true, false, false, p.tp, 501)
	check(p.atk, "Normal attack input is accepted again after landing")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	p.invuln = 1.0
	SimBosses.start_slam(sim, e)
	SimEnemies.tick_tele(sim, SimBosses.SLAM_WINDUP + 0.01)
	check(p.hp == 1000 and not SimPlayers.is_reacting(p), "Invulnerability blocks both slam damage and launch")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	p.pos = field + Vector2(0, 4 * GameSim.T)
	SimBosses.start_slam(sim, e)
	SimEnemies.tick_tele(sim, SimBosses.SLAM_WINDUP + 0.01)
	check(p.hp == 1000 and not SimPlayers.is_reacting(p), "Dodging outside the red circle avoids the launch")
	e = reset(GameSim.BOSS, GameSim.BURROWER)
	SimBosses.add_telegraph(sim, "circle", p.pos, 2 * GameSim.T, 35)
	SimEnemies.tick_tele(sim, SimBosses.SLAM_WINDUP + 0.01)
	check(p.hp == 965 and not SimPlayers.is_reacting(p), "Another boss's circular attack does not trigger Juggernaut's launch")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	e.dash = Vector2(1, 0.25).normalized()
	e.dash_left = 5 * GameSim.T
	e.act = "charge"
	e.act_t = 10.0
	p.pos = field + e.dash * GameSim.T + e.dash.orthogonal() * 8
	initial = p.pos
	SimBosses.tick_charge(sim, e, 0.05)
	check(p.hp == 965 and p.hit_kind == "charge" and Vector2(p.hit_direction).is_equal_approx(e.dash) and p.pos == initial, "Charge starts a directional knockback on impact instead of teleporting the player")
	for i in range(12):
		sim.clock += 0.05
		SimPlayers.tick_players(sim, 0.05)
	var displacement: Vector2 = p.pos - initial
	check(not SimPlayers.is_reacting(p) and displacement.dot(e.dash) > 40 and displacement.length() <= 2 * GameSim.T + 0.01, "Charge throws the player two tiles along the dash over 0.55 seconds")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	p.pos = GameSim.DOOR_POS[0] + Vector2(-32, 0)
	SimPlayers.start_hit_reaction(sim, p, "charge", Vector2.RIGHT)
	for i in range(12):
		sim.clock += 0.05
		SimPlayers.tick_players(sim, 0.05)
	check(not SimWorld.inside_base(p.pos), "Knockback cannot throw a player through an intact base door")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	p.hp = 10
	SimBosses.start_slam(sim, e)
	SimEnemies.tick_tele(sim, SimBosses.SLAM_WINDUP + 0.01)
	check(p.state == 1 and not SimPlayers.is_reacting(p), "A fatal hit uses the normal downed state without leaving an airborne control lock")
	SimPlayers.reset_player(sim, p)
	check(not SimPlayers.is_reacting(p) and sim.snapshot().hit_reactions.is_empty(), "Respawning clears every hit-reaction state")
	check(is_equal_approx(AnimView.hit_height("slam", 0.5), 36) and is_equal_approx(AnimView.hit_height("charge", 0.5), 16) and absf(AnimView.hit_height("slam", 1)) < 0.001, "Launch and directional throw have distinct heights and both return to ground")

func check_alternating_skills() -> void:
	var e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	sim.audio_events.clear()
	var p = sim.players[1]
	e.special_cd = 0.0
	e.cd = INF
	var order: Array = []
	var previous: String = ""
	var completed: float = -99.0
	var gaps: Array = []
	var impact_start: float = -1
	var impact_duration: float = 0
	for frame in range(600):
		# Keep the queued skill reachable while exercising real 20 Hz decisions and telegraph expiry.
		p.pos = e.pos + Vector2(0, (2 if e.next_skill == "slam" and e.act == "" else 6) * GameSim.T)
		p.invuln = 0
		p.hp = 10000
		sim.clock += 0.05
		sim.tick_enemies(0.05)
		SimEnemies.tick_tele(sim, 0.05)
		var act: String = e.act
		if act != previous:
			if act in ["slam", "charge_wind"]:
				order.append(act)
				if completed > 0:
					gaps.append(sim.clock - completed)
			if act == "slam_impact":
				impact_start = sim.clock
			if previous in ["slam_impact", "charge"] and act == "":
				completed = sim.clock
				if previous == "slam_impact":
					impact_duration = sim.clock - impact_start
		previous = act
		if order.size() >= 4 and act == "charge":
			break
	check(order == ["slam", "charge_wind", "slam", "charge_wind"], "Juggernaut strictly alternates slam and charge across four complete selections")
	check(gaps.size() == 3 and gaps.all(func(g): return float(g) >= 2.95), "A shared three-second interval prevents back-to-back specials")
	check(impact_duration >= 0.6, "The boss holds the ground-impact animation for about 0.65 seconds")
	var slam_events: Array = sim.audio_events.filter(func(event): return event[1] == "boss_slam")
	check(slam_events.size() == 2, "Each actual ground impact emits exactly one slam sound, even on a miss (%d impacts)" % slam_events.size())
	var moving = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	moving.special_cd = 2.0
	moving.spd = 2 * GameSim.T
	p.pos = field + Vector2(0, 5 * GameSim.T)
	step(0.1)
	check(moving.act == "" and moving.pos.distance_to(field) > 1, "The special interval keeps the boss hunting instead of freezing it")

func begin_test_charge(e) -> void:
	e.dash = Vector2.DOWN
	e.dash_left = 10 * GameSim.T
	e.dash_hit = []
	e.special_cd = INF
	SimBosses.boss_act(sim, e, "charge", 10.0)

func check_charge_obstacles() -> void:
	var original_static: Array = sim.world.static_solids
	var e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	var rock: Vector2 = field + Vector2(0, 3 * GameSim.T)
	# A decorative rock and an actual harvestable trunk exercise the production collider tagging.
	sim.world.static_solids = original_static.duplicate()
	sim.world.static_solids.append([rock, 20.0, true, false])
	sim.nodes = [{"type": 0, "amount": 5, "pos": field + Vector2(0, 5 * GameSim.T), "radius": 20.0}]
	sim.world.rebuild(sim.nodes, sim.towers, [])
	check(Vector2(SimWorld.move_actor(sim, field, field + Vector2(0, 4 * GameSim.T), e.r)).distance_to(field) < 2 * GameSim.T, "The scenery fixture blocks ordinary movement")
	sim.players[1].pos = field + Vector2(0, 6 * GameSim.T)
	sim.audio_events.clear()
	begin_test_charge(e)
	step(1.15)
	check(e.pos.distance_to(field + Vector2(0, 10 * GameSim.T)) < 1 and e.act == "", "Juggernaut crosses rocks and harvestable trees for the full rush, including the separation pass")
	check(sim.players[1].hp == 965 and sim.nodes[0].amount == 5, "Rushing through scenery still hits the player once and preserves resources")
	check(sim.audio_events.filter(func(event): return event[1] == "boss_charge").size() == 1, "The rush emits exactly one sound at its start")
	sim.nodes.clear()
	sim.world.static_solids = original_static
	for label in ["building", "built wall", "tower"]:
		e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
		if label == "building":
			sim.world.static_solids = original_static.duplicate()
			sim.world.static_solids.append([rock, 24.0, true])
		elif label == "built wall":
			sim.built_walls = [{"pos": rock, "vert": false}]
		else:
			sim.towers[0] = {"pos": rock, "hp": 100, "slot": 0}
		sim.world.rebuild([], sim.towers, sim.built_walls)
		sim.players[1].pos = field + Vector2(0, 10 * GameSim.T)
		begin_test_charge(e)
		step(1.15)
		check(e.pos.y < rock.y - e.r and e.act == "", "A " + label + " stops Juggernaut's rush")
		sim.world.static_solids = original_static
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	e.pos = GameSim.DOOR_POS[0] + Vector2.LEFT * 3 * GameSim.T
	begin_test_charge(e)
	e.dash = Vector2.RIGHT
	step(1.15)
	check(e.pos.x < GameSim.DOOR_POS[0].x - e.r and e.act == "", "An intact base door stops the rush instead of allowing entry")
	e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	sim.world.static_solids = original_static.duplicate()
	var endpoint: Vector2 = field + Vector2(0, 10 * GameSim.T)
	sim.world.static_solids.append([endpoint, 20.0, true, false])
	sim.world.rebuild([], sim.towers, [])
	begin_test_charge(e)
	step(1.15)
	check(e.act == "" and e.scenery_escape and e.pos.distance_to(endpoint) < 1, "A rush landing inside a rock enables walking out instead of snapping into adjacent rocks")
	sim.world.static_solids = original_static
	sim.world.rebuild([], sim.towers, [])
	check(not WorldGeometry.charge_blocks_sprite("rock_1") and not WorldGeometry.charge_blocks_sprite("lm_palm_0") and not WorldGeometry.charge_blocks_sprite("lm_mangrove_0") and not WorldGeometry.charge_blocks_sprite("lm_rubble_0") and WorldGeometry.charge_blocks_sprite("lm_container_0"), "Sprite classification separates loose scenery and landmark trees from construction")

func check_charge_escape() -> void:
	var original_static: Array = sim.world.static_solids
	for with_wall in [false, true]:
		var e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
		e.spd = 2 * GameSim.T
		e.cd = INF
		sim.players[1].pos = field + Vector2(0, 22 * GameSim.T)
		sim.world.static_solids = original_static.duplicate()
		# Dense overlapping resource footprints reproduce a limestone farm landing.
		for y in range(9, 15):
			for x in range(-2, 3):
				sim.world.static_solids.append([field + Vector2(x, y) * GameSim.T, 20.0, true, false])
		if with_wall:
			sim.built_walls = [{"pos": field + Vector2(0, 12 * GameSim.T), "vert": false}]
		sim.world.rebuild([], sim.towers, sim.built_walls)
		begin_test_charge(e)
		step(1.15)
		var landing: Vector2 = e.pos
		check(e.act == "" and e.scenery_escape, "Dense resource landing enables escape (%s)" % ("wall" if with_wall else "open"))
		e.special_cd = INF
		step(0.2)
		check(e.pos.y > landing.y + 8, "Boss continues walking after its rush instead of freezing between rocks")
		step(3.8)
		if with_wall:
			check(e.pos.y < field.y + 12 * GameSim.T - e.r, "Escaping a dense rock cluster never permits crossing a built wall")
		else:
			check(e.pos.y > field.y + 16 * GameSim.T and not e.scenery_escape and not SimBosses.ignores_scenery(e), "Boss leaves the limestone cluster and automatically restores normal scenery collision")
		sim.world.static_solids = original_static
	var e = reset(GameSim.BOSS, GameSim.JUGGERNAUT)
	e.spd = 2 * GameSim.T
	e.cd = INF
	e.charge_exit_distance = 2 * GameSim.T
	sim.players[1].pos = field + Vector2(0, 10 * GameSim.T)
	sim.world.static_solids = original_static.duplicate()
	for i in range(16):
		sim.world.static_solids.append([field + Vector2.from_angle(i * TAU / 16) * 80, 20.0, true, false])
	sim.world.rebuild([], sim.towers, [])

	check(not sim.world.overlaps_scenery(e.pos, e.r), "A post-charge landing pocket can be empty but completely surrounded by rocks")
	step(3.0)
	check(e.pos.y > field.y + 140, "A boss trapped in an empty landing pocket detects the blocked route and walks through the surrounding rocks")
	sim.world.static_solids = original_static
	sim.world.rebuild([], sim.towers, [])

func chain_step(seconds: float) -> void:
	for i in range(roundi(seconds / 0.05)):
		sim.clock += 0.05
		SimPlayers.tick_players(sim, 0.05)
		sim.tick_enemies(0.05)
		SimEnemies.tick_tele(sim, 0.05)

func check_chainwarden() -> void:
	check(SimBosses.boss_title(GameSim.CHAINWARDEN) == "NOX-02 Chainwarden", "Boss 2 is renamed Chainwarden")
	var e = reset(GameSim.BOSS, GameSim.CHAINWARDEN)
	var p = sim.players[1]
	p.pos = field + Vector2(0, 3 * GameSim.T)
	var behind = sim.players[2]
	behind.state = 0
	behind.invuln = 0
	behind.hp = 1000
	behind.pos = field - Vector2(0, 3.5 * GameSim.T)
	e.next_chain_skill = "sweep"
	e.special_cd = 0.0
	e.cd = INF
	SimChainwarden.tick(sim, e, 0.05)
	check(e.act == "sweep_wind" and sim.tele[0].kind == "arc" and is_equal_approx(sim.tele[0].spread, deg_to_rad(120)), "Sweep winds up a locked 120-degree fan, not a full circle")
	chain_step(0.75)
	check(p.hp == 1000 and not SimPlayers.is_reacting(p), "The sweep respects its full 0.8-second wind-up")
	chain_step(0.1)
	check(p.hp == 982 and p.hit_kind == "stun" and is_equal_approx(p.hit_duration, 1.5), "A player inside the fan takes 18 damage and is stunned for 1.5 seconds")
	check(behind.hp == 1000 and not SimPlayers.is_reacting(behind), "A player behind the boss is outside the sweep")
	var initial: Vector2 = p.pos
	sim.input(1, p.pos + Vector2.RIGHT * 40, 0, true, true, true, p.tp, int(p.input_sequence) + 1)
	check(p.pos == initial and not p.atk and not p.inter and not p.ent, "Stun blocks movement and actions on the authoritative input path")
	check(sim.snapshot().hit_reactions[1][1] == "stun" and AnimView.hit_height("stun", .5) == 0, "Clients receive grounded stun feedback instead of a launch")
	chain_step(1.35)
	check(SimPlayers.is_reacting(p) and p.pos == initial, "The player remains stationary while the stun is active")
	chain_step(0.2)
	check(not SimPlayers.is_reacting(p), "Stun expires after 1.5 seconds without a permanent input lock")
	for offset in [Vector2(0, 4.2 * GameSim.T), Vector2(3 * GameSim.T, 0)]:
		e = reset(GameSim.BOSS, GameSim.CHAINWARDEN)
		p.pos = field + offset
		SimBosses.add_telegraph(sim, "arc", field, SimChainwarden.SWEEP_RANGE, 18, {"ang": PI / 2, "spread": SimChainwarden.SWEEP_ANGLE, "reaction": "stun"})
		SimEnemies.tick_tele(sim, 1.01)
		check(p.hp == 1000 and p.hit_kind == "", "Fan misses players outside its radius or angular edges")
	e = reset(GameSim.BOSS, GameSim.CHAINWARDEN)
	p.pos = field + Vector2(0, 7 * GameSim.T)
	e.special_cd = 0
	e.cd = INF
	SimChainwarden.tick(sim, e, .05)
	check(e.act == "chain_wind" and e.next_chain_skill == "sweep", "Hook locks its aim and queues the sweep as the next skill")
	chain_step(.5)
	check(p.hp == 1000, "The chain does not hit during its casting wind-up")
	for i in range(12):
		chain_step(.05)
		if p.hit_kind == "pull":
			break
	check(p.hp == 992 and p.hit_kind == "pull" and e.act == "chain_pull", "The fast moving hook hits and starts a timed pull")
	check(sim.snapshot().chains.size() == 1 and sim.snapshot().chains[0][2] == 1, "A hooked player is attached to the visible chain in snapshots")
	chain_step(.6)
	check(not SimPlayers.is_reacting(p) and p.pos.distance_to(e.pos) < 2 * GameSim.T and p.pos.distance_to(e.pos) >= e.r + .6 * GameSim.T, "Hook draws the player close over half a second without overlapping the boss")
	check(sim.snapshot().chains.is_empty() and e.special_cd > 0, "The tether disappears and the boss uses its shared special cooldown")
	for protection in ["wall", "invulnerable", "fatal", "miss"]:
		e = reset(GameSim.BOSS, GameSim.CHAINWARDEN)
		p.pos = field + Vector2(0, 7 * GameSim.T)
		e.face = PI / 2
		e.chain_tip = field + Vector2(0, e.r + 2)
		e.chain_left = SimChainwarden.HOOK_RANGE
		e.chain_target = -1
		if protection == "wall":
			sim.built_walls = [{"pos": field + Vector2(0, 4 * GameSim.T), "vert": false}]
			sim.world.rebuild([], sim.towers, sim.built_walls)
		elif protection == "invulnerable":
			p.invuln = 1.0
		elif protection == "fatal":
			p.hp = 1
		else:
			p.pos += Vector2(3 * GameSim.T, 0)
		SimBosses.boss_act(sim, e, "chain_fly", 1)
		SimChainwarden.tick_hook(sim, e, .5)
		check(p.hit_kind == "" and e.act != "chain_pull", "Hook respects " + protection + " and never leaves a stuck pull reaction")
	# Collision still applies during the forced movement, even if a wall appears after the hook hits.
	e = reset(GameSim.BOSS, GameSim.CHAINWARDEN)
	p.pos = field + Vector2(0, 7 * GameSim.T)
	SimPlayers.start_hit_reaction(sim, p, "pull", Vector2.UP)
	p.hit_distance = 6 * GameSim.T
	sim.built_walls = [{"pos": field + Vector2(0, 4 * GameSim.T), "vert": false}]
	sim.world.rebuild([], sim.towers, sim.built_walls)
	chain_step(.6)
	check(p.pos.y > field.y + 4 * GameSim.T and not SimPlayers.is_reacting(p), "Pull movement stops at walls and always releases player control")
	e = reset(GameSim.BOSS, GameSim.CHAINWARDEN)
	e.cd = INF
	e.special_cd = 0
	var order: Array = []
	var last: String = ""
	for i in range(520):
		if e.act == "":
			p.pos = e.pos + Vector2(0, 3 * GameSim.T)
		p.hp = 1000
		chain_step(.05)
		if e.act != last and e.act in ["chain_wind", "sweep_wind"]:
			order.append(e.act)
		last = e.act
		if order.size() == 4:
			break
	check(order == ["chain_wind", "sweep_wind", "chain_wind", "sweep_wind"], "Chainwarden strictly alternates its hook and fan sweep")
	check(sim.enemies.size() == 1 and not sim.enemies.any(func(x): return x.get("summon", false)), "Boss 2 no longer summons any Grunts")
	for act in ["sweep_wind", "sweep_hit", "chain_wind", "chain_fly", "chain_pull"]:
		e.act = act
		e.act_t = .2
		check(not EnemyView.boss_skill_animation(sim.snapshot().en[0]).is_empty(), act + " selects a dedicated full-body sprite animation")
