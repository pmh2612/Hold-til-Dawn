class_name SimBosses
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/ai/GameSim.Bosses.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
# [code, name, HP at night 2 for 4 players on Medium, speed x Grunt, effective uptime u_b] (FML-02/03, BAL-39)
static var BOSS_KINDS = [["NOX-01", "Juggernaut", 4500.0, 1.0, 0.50], ["NOX-02", "Chainwarden", 4860.0, 0.75, 0.54], ["NOX-03", "Bio-Cannon", 4140.0, 1.0, 0.46], ["NOX-04", "Burrower", 3780.0, 1.0, 0.42], ["NOX-05", "Earthshaker", 4500.0, 1.0, 0.50], ["NOX-06", "Phantom", 3780.0, 1.0, 0.42], ["NOX-07", "Voltspire", 4140.0, 1.0, 0.46]]
const TELEGRAPH: float = 1.0  # damaging special moves warn before impact; basic hits use the attack sprite
const SLAM_WINDUP: float = 0.85
const CHARGE_WINDUP: float = 0.55
const SLAM_IMPACT: float = 0.65
const JUGGERNAUT_SPECIAL_GAP: float = 3.0
const SIGNATURE_HIT: float = 35.0
const BURROW_SPEED_MUL: float = 3.2
const BURROW_ERUPT_DMG: float = 10.0
const CLOAK_SPEED_MUL: float = 1.6
const PHANTOM_AMBUSH_WINDUP: float = 0.45
const MAX_SUMMONS: int = 4
const BASIC_DAMAGE: float = 12.0
const BASIC_INTERVAL: float = 1.2
const STRUCTURE_INTERVAL: float = 2.0
const HUNT_RADIUS: float = GameSim.SCOUT_NIGHT_SIGHT * 2.0
const BIO_BARRAGE_COUNT: int = 16
const BIO_BARRAGE_WINDUP: float = 0.5
const ACID_POOL_RADIUS: float = 2.2 * GameSim.T
const ACID_POOL_DURATION: float = 6.0
const ACID_POOL_IMPACT_DMG: float = 15.0
const ACID_POOL_TICK_DMG: float = 6.0
const ACID_POOL_TICK_INTERVAL: float = 1.0
const ACID_LOB_TIME: float = 0.55

# constants shared with GameSim
const BIO_CANNON = GameSim.BIO_CANNON
const BOSS = GameSim.BOSS
const BROODMOTHER = GameSim.BROODMOTHER
const BURROWER = GameSim.BURROWER
const GATEBREAKER = GameSim.GATEBREAKER
const GRUNT = GameSim.GRUNT
const IRONHIDE = GameSim.IRONHIDE
const JUGGERNAUT = GameSim.JUGGERNAUT
const MAX_ENEMIES = GameSim.MAX_ENEMIES
const PHANTOM = GameSim.PHANTOM
const T = GameSim.T

static func draw_bosses(sim: GameSim) -> void:
	var first: int = int(sim.rng.randi() % 7)
	var second: int = int(sim.rng.randi() % 6)
	if second >= first:
		second += 1
	sim.boss_plan = [first, second]

static func boss_kind_for(sim: GameSim, night_) -> int:
	return int(sim.boss_plan[1 if night_ >= 4 else 0])

static func boss_title(kind) -> Variant:
	var b = BOSS_KINDS[int(kind)]
	return "%s %s" % [b[0], b[1]]

# Night 4: damage x1.21 and cooldowns x0.9; mode scales damage and cooldowns, telegraphs unchanged.
static func boss_damage(sim: GameSim, base: float) -> float:
	return SimBalance.boss_damage(sim, base)

static func boss_cooldown(sim: GameSim, base: float) -> float:
	return SimBalance.boss_cooldown(sim, base)

static func setup_boss(sim: GameSim, e, kind: int) -> void:
	var b = BOSS_KINDS[kind]
	e.type = BOSS
	e.kind = kind
	# FML-02: HP scales with the team, x1.5625 on night 4, and with the mode
	e.hp = SimBalance.boss_hp(float(b[2]), int(sim.k), sim.players.size(), int(sim.mode))
	e.maxhp = e.hp
	e.spd = e.spd * b[3]
	# Smaller, more frequent structure hits preserve 15 base DPS. Gatebreaker's signature stays 120 / 8 s.
	e.dmg = boss_damage(sim, 30.0)
	e.slam = boss_damage(sim, 40.0)
	e.slam_at = -99.0
	e.next_skill = "slam"
	e.special_cd = 3.0 if kind == JUGGERNAUT else 0.0
	e.sig_cd = 4.0
	e.blow_cd = 0.0
	e.act = ""
	e.act_t = 0.0
	e.face = (GameSim.DOOR_POS[e.door] - e.pos).angle()
	# body radius: big enough to match the drawn boss (2x sprite, src/ai/view/enemy_view.gd), small enough to get
	# through a door gap (2.4 tiles) once the door is broken
	e.r = 1.1 * T
	e.dash_hit = []
	e.scenery_escape = false
	e.charge_exit_distance = 0.0
	e.next_chain_skill = "hook"
	e.next_bio_skill = "barrage"
	e.next_burrow_skill = "burrow"
	e.next_quake_skill = "fissure"
	e.next_phantom_skill = "cloak"
	e.next_volt_skill = "lightning"
	if kind == GameSim.CHAINWARDEN:
		e.special_cd = 3.0
	e.exposed_until = 0.0

# --- damage rules -------------------------------------------------------
static func hittable(sim: GameSim, e) -> bool:
	# a burrowed boss cannot be hit (Burrower, table 4.2)
	return not (e.type == BOSS and e.get("act", "") in ["burrow", "surface"])

static func boss_damage_taken(_sim: GameSim, _e, dmg, _from) -> Variant:
	# NOX-07 Voltspire no longer uses directional front-armour damage reduction.
	return dmg

static func boss_on_hit(sim: GameSim, e) -> void:
	# a hit reveals the Phantom
	if e.type == BOSS and int(e.kind) == PHANTOM and e.get("act", "") == "cloak":
		boss_act(sim, e, "", 0.0)
		e.shown = 3.0

static func boss_act(sim: GameSim, e, act, time: float) -> void:
	e.act = act
	e.act_t = time
	var cue: String = {"charge": "boss_charge", "burrow": "boss_burrow", "climb": "boss_surface", "cloak": "boss_cloak", "ambush": "boss_ambush", "stagger": "boss_stagger"}.get(act, "")
	if cue != "":
		SimAudio.emit(sim, cue, e.pos, -int(e.id) - 1)

# All seven bosses sense the nearest reachable living player in a 13-tile radius.
# Obstacles are navigated around; actual melee/projectile collision still enforces walls.
static func boss_target(sim: GameSim, e) -> Variant:
	return SimEnemies.nearest_player(sim, e.pos, HUNT_RADIUS, false)

# Cheap distance comparisons only. Navigation remains cached and budgeted by SimEnemies.
static func choose_target(sim: GameSim, e) -> void:
	var previous = [e.state, e.target, e.get("tw", -1), e.door]
	var p = boss_target(sim, e)
	e.target = 0
	e.goal_reach = e.r + T
	if p != null:
		e.state = 1
		e.target = p.id
		e.goal = p.pos
		e.goal_reach = e.r + 0.55 * T
	else:
		var distance: float = INF
		e.state = 0
		e.goal = e.pos
		var inside: bool = SimWorld.inside_base(e.pos)
		if inside and sim.base_hp > 0:
			distance = e.pos.length()
			e.state = 3
			e.goal = Vector2.ZERO
			e.goal_reach = 2.5 * T
		for i in range(GameSim.DOOR_POS.size()):
			var at: Vector2 = GameSim.DOOR_POS[i]
			if sim.doors[i] > 0:
				var d: float = e.pos.distance_to(at)
				if d < distance:
					distance = d
					e.state = 2
					e.door = i
					e.goal = at + GameSim.DOOR_DIR[i] * (e.r + 0.2 * T) * (-1.0 if inside else 1.0)
					e.goal_reach = e.r + T
			elif not inside and sim.base_hp > 0:
				# The generator is reachable through a breach; include the entry leg in distance.
				var d: float = e.pos.distance_to(at) + at.length()
				if d < distance:
					distance = d
					e.state = 3
					e.door = i
					e.goal = Vector2.ZERO
					e.goal_reach = 2.5 * T
		for tw in sim.towers:
			if tw == null or tw.hp <= 0:
				continue
			var d: float = e.pos.distance_to(tw.pos)
			if d < distance:
				distance = d
				e.state = 5
				e.tw = tw.slot
				e.goal = tw.pos
				e.goal_reach = e.r + 0.7 * T + 2.0
	if previous != [e.state, e.target, e.get("tw", -1), e.door]:
		e.nav_t = 0.0
		e.erase("nav_way")

static func tick_hunt(sim: GameSim, e, dt: float) -> void:
	if e.get("scenery_escape", false) and not sim.world.overlaps_scenery(e.pos, e.r + T):
		e.scenery_escape = false
		e.nav_t = 0.0
		e.erase("nav_way")
	# Finish committed telegraphs against their original target. Then resume hunting on this tick.
	var was_busy: bool = e.act != ""
	if not was_busy:
		choose_target(sim, e)
	if tick_boss(sim, e, dt):
		return
	if was_busy:
		choose_target(sim, e)
	var old: Vector2 = e.pos
	var p = sim.players.get(e.target) if e.state == 1 else null
	var arrived: bool
	if e.state == 2:
		arrived = e.pos.distance_to(GameSim.DOOR_POS[e.door]) <= e.goal_reach
	else:
		arrived = e.pos.distance_to(e.goal) <= e.goal_reach
		if e.state == 1:
			arrived = arrived and SimWorld.line_clear(sim, e.pos, p.pos)
		elif e.state == 5:
			arrived = arrived and SimWorld.line_clear(sim, e.pos, e.goal, e.goal)
		elif e.state == 3:
			arrived = arrived and SimWorld.inside_base(e.pos)
	if not arrived:
		# A boss embedded in a resource cluster cannot use its ordinary navigation grid to escape.
		var escaping: bool = ignores_scenery(e)
		var way: Vector2 = e.goal if escaping else SimEnemies.enemy_waypoint(sim, e, e.goal, false)
		e.pos = SimWorld.move_actor(sim, old, old + (way - old).normalized() * minf(e.spd * dt, old.distance_to(e.goal)), e.r, escaping)
	elif e.cd <= 0:
		var aim: Vector2 = GameSim.DOOR_POS[e.door] if e.state == 2 else e.goal
		e.face = (aim - e.pos).angle()
		if p != null:
			SimEnemies.melee_attack(sim, e, p)
		elif e.state == 5:
			SimEnemies.tower_attack(sim, e, sim.towers[e.tw])
		elif e.state in [2, 3]:
			SimEnemies.enemy_attack(sim, e, null)
	if e.pos.distance_to(old) > 0.5:
		e.face = (e.pos - old).angle()
	SimEnemies.tick_blocked(sim, e, old, arrived, dt)
	if int(e.kind) == JUGGERNAUT and e.get("charge_exit_distance", 0.0) > 0:
		e.charge_exit_distance = maxf(0.0, float(e.charge_exit_distance) - e.pos.distance_to(old))
		# Also handle a free landing pocket surrounded by rocks, where navigation returns no route.
		if e.get("stuck_t", 0.0) >= 0.4 and sim.world.overlaps_scenery(e.pos, e.r + T):
			e.scenery_escape = true

static func add_telegraph(sim: GameSim, kind, pos: Vector2, r: float, dmg: float, extra = null) -> void:
	var tl = {"kind": kind, "pos": pos, "r": r, "t": TELEGRAPH, "dur": TELEGRAPH, "dmg": dmg, "end": pos, "ang": 0.0, "spread": TAU}
	if extra != null:
		for key in extra:
			tl[key] = extra[key]
	sim.tele.append(tl)
	SimAudio.emit(sim, "boss_warn", pos)

# Juggernaut alone uses the 40-damage, three-tile ground slam.
static func boss_slam(sim: GameSim, e, dt) -> void:
	if int(e.kind) != JUGGERNAUT or e.next_skill != "slam" or e.special_cd > 0:
		return
	if e.act != "":
		return
	if SimEnemies.nearest_player(sim, e.pos, 3 * T) != null:
		start_slam(sim, e)

static func start_slam(sim: GameSim, e) -> void:
	if int(e.kind) != JUGGERNAUT or e.act != "":
		return
	add_telegraph(sim, "circle", e.pos, 3 * T, float(e.slam), {"reaction": "slam", "boss_id": int(e.id), "t": SLAM_WINDUP, "dur": SLAM_WINDUP, "fx_style": "jugg_slam"})
	e.next_skill = "charge"
	e.special_cd = INF
	boss_act(sim, e, "slam", SLAM_WINDUP)

static func juggernaut_special(sim: GameSim, e) -> bool:
	if e.special_cd > 0:
		return false
	if e.next_skill == "slam":
		boss_slam(sim, e, 0.0)
		return e.act != ""
	var p = boss_target(sim, e)
	if p == null or e.pos.distance_to(p.pos) > 10 * T:
		return false
	var dir: Vector2 = (p.pos - e.pos).normalized() if e.pos.distance_squared_to(p.pos) > 0.001 else Vector2.from_angle(e.face)
	e.dash = dir
	e.dash_left = 10.0 * T
	e.face = dir.angle()
	e.dash_hit = []
	add_telegraph(sim, "line", e.pos, 1.1 * T, 0.0, {"end": e.pos + dir * (10.0 * T), "t": CHARGE_WINDUP, "dur": CHARGE_WINDUP, "fx_style": "jugg_charge"})
	e.next_skill = "slam"
	e.special_cd = INF
	boss_act(sim, e, "charge_wind", CHARGE_WINDUP)
	return true

# Runs the boss's current move; returns true while the boss is busy (it then skips walking and door hits).
static func tick_boss(sim: GameSim, e, dt) -> bool:
	e.sig_cd -= dt
	e.special_cd = maxf(0.0, float(e.get("special_cd", 0.0)) - dt)
	e.blow_cd = maxf(0.0, float(e.get("blow_cd", 0.0)) - dt)
	e.shown = e.get("shown", 0.0) - dt
	var kind: int = int(e.kind)
	var act = e.act
	# Old saved/test states must not reintroduce a post-attack movement lock.
	if act in ["recover", "stagger", "climb"]:
		boss_act(sim, e, "", 0.0)
		return false
	if kind == GameSim.CHAINWARDEN:
		if act != "":
			e.act_t -= dt
		return SimChainwarden.tick(sim, e, dt)
	if act == "cloak":
		return tick_cloak(sim, e, dt)
	if act != "":
		e.act_t -= dt
		if act == "charge":
			return tick_charge(sim, e, dt)
		if act == "burrow":
			return tick_burrow(sim, e, dt)
		if act in ["volt_call", "mirage_dash", "beam_sweep"]:
			return SimBossSkills.tick_active_act(sim, e, float(dt))
		if e.act_t > 0:
			return true
		finish_act(sim, e, act)
		return e.act != ""
	if kind == JUGGERNAUT:
		return juggernaut_special(sim, e)
	if e.sig_cd > 0:
		return false
	var p = boss_target(sim, e)
	if kind == BIO_CANNON and p != null:
		if e.get("next_bio_skill", "barrage") == "barrage":
			SimAudio.emit(sim, "boss_acid_charge", e.pos, -int(e.id) - 1)
			boss_act(sim, e, "glow", BIO_BARRAGE_WINDUP)
			e.next_bio_skill = "pool"
		else:
			var target_pos: Vector2 = IslandMap.pull_inland(Vector2(p.pos), 8.0)
			e.face = (target_pos - e.pos).angle()
			e.acid_target = target_pos
			SimAudio.emit(sim, "boss_acid_lob", e.pos, -int(e.id) - 1)
			add_telegraph(sim, "circle", target_pos, ACID_POOL_RADIUS, 0.0, {"t": ACID_LOB_TIME, "dur": ACID_LOB_TIME, "acid_from": Vector2(e.pos), "acid_lob": true})
			boss_act(sim, e, "acid_lob", ACID_LOB_TIME)
			e.next_bio_skill = "barrage"
		e.sig_cd = boss_cooldown(sim, 5.0)
		return true
	if kind == BURROWER and p != null:
		return SimBossSkills.start_burrower_skill(sim, e, p)
	if kind == GATEBREAKER and p != null:
		return SimBossSkills.start_earthshaker_skill(sim, e, p)
	if kind == PHANTOM and p != null:
		return SimBossSkills.start_phantom_skill(sim, e, p)
	if kind == IRONHIDE and p != null:
		return SimBossSkills.start_voltspire_skill(sim, e, p)
	return false

static func finish_act(sim: GameSim, e, act) -> void:
	var kind: int = int(e.kind)
	boss_act(sim, e, "", 0.0)
	if act == "slam":
		e.dashed = false
		if kind == JUGGERNAUT:
			SimBossSkills.spawn_jugg_slam(sim, Vector2(e.pos))
			boss_act(sim, e, "slam_impact", SLAM_IMPACT)
	elif act == "slam_impact":
		e.special_cd = boss_cooldown(sim, JUGGERNAUT_SPECIAL_GAP)
	elif act == "charge_wind":
		boss_act(sim, e, "charge", 10.0)
	elif act == "glow" and kind == BIO_CANNON:
		SimAudio.emit(sim, "boss_barrage", e.pos, -int(e.id) - 1)
		SimBossSkills.spawn_bio_barrage(sim, Vector2(e.pos))
		# A ring of 16 acid orbs (22.5-degree gaps): 12 damage, 4 tiles/s, range 8 tiles, applies poison.
		for i in range(BIO_BARRAGE_COUNT):
			var dir: Vector2 = Vector2.from_angle(i * TAU / float(BIO_BARRAGE_COUNT))
			sim.proj.append({"pos": e.pos + dir * e.r, "vel": dir * 4.0 * T, "dmg": boss_damage(sim, 12.0), "ttl": 2.0, "kind": "orb", "poison": true})
	elif act == "acid_lob" and kind == BIO_CANNON:
		spawn_acid_pool(sim, e, Vector2(e.get("acid_target", e.pos)))
	elif act == "surface":
		e.pos = e.surface
		SimBossSkills.spawn_burrow_pop(sim, Vector2(e.pos))
		SimAudio.emit(sim, "boss_surface", e.pos, -int(e.id) - 1)
	elif act == "ambush":
		e.shown = 3.0
		SimAudio.emit(sim, "boss_phantom_slash", e.pos, -int(e.id) - 1)
		SimBossSkills.spawn_phantom_slash(sim, Vector2(e.pos), float(e.face))
	elif SimBossSkills.finish_skill_act(sim, e, Cs.s(act)):
		return

static func tick_charge(sim: GameSim, e, dt) -> bool:
	var old: Vector2 = Vector2(e.pos)
	var step: float = minf(9.0 * T * dt, e.dash_left)
	var want: Vector2 = old + e.dash * step
	e.pos = SimWorld.move_actor(sim, old, want, e.r, ignores_scenery(e))
	e.dash_left -= step
	# 35 damage and knockback to anyone on the line, once per dash
	for p in sim.players.values():
		if p.state == 0 and not p.id in e.dash_hit and p.pos.distance_to(e.pos) <= e.r + 0.5 * T:
			e.dash_hit.append(p.id)
			var hp_before: float = p.hp
			SimPlayers.hurt(sim, p, boss_damage(sim, SIGNATURE_HIT))
			if p.hp < hp_before and p.state == 0:
				SimPlayers.start_hit_reaction(sim, p, "charge", Vector2(e.dash))
	var blocked_: bool = e.pos.distance_to(want) > 2.0
	if e.dash_left <= 0 or blocked_:
		e.dashed = true
		boss_act(sim, e, "", 0.0)
		# Keep scenery collision disabled until the whole body leaves the landing cluster.
		# Buildings, walls, towers and water retain their collisions throughout the escape.
		e.scenery_escape = int(e.kind) == JUGGERNAUT and sim.world.overlaps_scenery(e.pos, e.r)
		e.charge_exit_distance = 2 * T if int(e.kind) == JUGGERNAUT else 0.0
		e.pos = SimWorld.move_actor(sim, e.pos, e.pos, e.r, ignores_scenery(e))
		e.nav_t = 0.0
		e.erase("nav_way")
		e.special_cd = boss_cooldown(sim, JUGGERNAUT_SPECIAL_GAP)
	return true

static func ignores_scenery(e) -> bool:
	return e.type == BOSS and int(e.kind) == JUGGERNAUT and (e.get("act", "") == "charge" or e.get("scenery_escape", false))

static func tick_burrow(sim: GameSim, e, dt) -> bool:
	var p = boss_target(sim, e)
	var lost: bool = p == null or p.state != 0
	var want: Vector2 = Vector2(e.pos)
	if not lost:
		# Underground it closes in rapidly right to the exact 1.5-tile emergence ring (no teleport jump on surfacing).
		var old: Vector2 = Vector2(e.pos)
		var away: Vector2 = (old - Vector2(p.pos)).normalized() if old.distance_to(p.pos) > 1.0 else Vector2.RIGHT
		want = Vector2(p.pos) + away * (1.5 * T)
		var step: Vector2 = (want - old).limit_length(e.spd * BURROW_SPEED_MUL * dt)
		e.pos = SimWorld.move_actor(sim, old, old + step, e.r)
		if e.pos.distance_to(old) > 0.5:
			e.face = (e.pos - old).angle()
	var reached: bool = lost or e.act_t <= 0 or e.pos.distance_to(want) <= 8.0 or (not lost and e.pos.distance_to(p.pos) <= 1.6 * T)
	if not reached:
		return true
	# Surface directly at the moving burrow mound so the boss sprite and eruption FX align 1:1.
	var spot: Vector2 = Vector2(e.pos)
	if not lost:
		e.face = (Vector2(p.pos) - spot).angle()
	e.surface = spot
	boss_act(sim, e, "", 0.0)
	SimBossSkills.spawn_burrow_pop(sim, spot)
	SimAudio.emit(sim, "boss_surface", spot, -int(e.id) - 1)
	var erupt_r: float = 2.2 * T
	var erupt_dmg: float = boss_damage(sim, BURROW_ERUPT_DMG)
	for q in sim.players.values():
		if int(q.state) != 0 or (q.inside and not SimPhases.any_breach(sim)):
			continue
		if Vector2(q.pos).distance_to(spot) <= erupt_r:
			var hp_before: float = float(q.hp)
			SimPlayers.hurt(sim, q, erupt_dmg)
			if float(q.hp) < hp_before and int(q.state) == 0:
				SimPlayers.start_hit_reaction(sim, q, "launch_short", Vector2(q.pos) - spot)
	return true

static func tick_cloak(sim: GameSim, e, dt) -> bool:
	var p = boss_target(sim, e)
	if p == null:
		# No ambush target remains: immediately return to attacking the nearest structure.
		boss_act(sim, e, "", 0.0)
		return false
	var old: Vector2 = Vector2(e.pos)
	if old.distance_to(p.pos) > 1.5 * T:
		var way: Vector2 = SimEnemies.enemy_waypoint(sim, e, p.pos, false)
		e.pos = SimWorld.move_actor(sim, old, old + (way - old).normalized() * e.spd * CLOAK_SPEED_MUL * dt, e.r)
		if e.pos.distance_to(old) > 0.5:
			e.face = (e.pos - old).angle()
	# Only exits cloak once it actually catches up to the player (never times out mid-chase).
	if e.pos.distance_to(p.pos) <= 2.0 * T:
		# Halved ambush telegraph delay (0.45 s arc), then 35 damage in a 1.5-tile arc.
		e.face = (Vector2(p.pos) - Vector2(e.pos)).angle()
		add_telegraph(sim, "arc", e.pos, e.r + 1.5 * T, boss_damage(sim, SIGNATURE_HIT), {"ang": e.face, "spread": deg_to_rad(120.0), "t": PHANTOM_AMBUSH_WINDUP, "dur": PHANTOM_AMBUSH_WINDUP, "fx_style": "phantom"})
		boss_act(sim, e, "ambush", PHANTOM_AMBUSH_WINDUP)
	return true

# Whether this boss hits doors and towers right now (not while burrowed or cloaked).
static func boss_hits_doors(sim: GameSim, e) -> bool:
	return not e.get("act", "") in ["burrow", "surface", "cloak"]

# NOX-05 Earthshaker uses active seismic skills instead of the old 120-damage door blow.
static func start_blow(_sim: GameSim, _e) -> bool:
	return false

# Boss state for the client: "" or the current move (cloak, burrow, glow, stagger, ...).
static func boss_look(sim: GameSim, e) -> Variant:
	if e.type != BOSS:
		return ""
	var act = e.act
	if act == "" and float(e.get("exposed_until", 0.0)) > sim.clock:
		return "exposed"
	if act == "" and e.get("shown", 0.0) > 0:
		return "shown"
	return act

static func spawn_acid_pool(sim: GameSim, e, spot: Vector2) -> void:
	var now: float = float(sim.clock)
	var impact_dmg: float = boss_damage(sim, ACID_POOL_IMPACT_DMG)
	var tick_dmg: float = boss_damage(sim, ACID_POOL_TICK_DMG)
	var next_hit: Dictionary = {}
	SimAudio.emit(sim, "boss_acid_splash", spot, -int(e.id) - 1)
	for q in sim.players.values():
		if int(q.state) != 0 or (q.inside and not SimPhases.any_breach(sim)):
			continue
		if Vector2(q.pos).distance_to(spot) <= ACID_POOL_RADIUS and SimWorld.line_clear(sim, spot, q.pos):
			var hp_before: float = float(q.hp)
			SimPlayers.hurt(sim, q, impact_dmg)
			if int(q.state) == 0 and float(q.hp) < hp_before:
				SimPlayers.apply_poison(sim, q)
			next_hit[q.id] = now + ACID_POOL_TICK_INTERVAL
	sim.acid_pools.append({"pos": spot, "r": ACID_POOL_RADIUS, "until": now + ACID_POOL_DURATION, "dur": ACID_POOL_DURATION, "dmg": tick_dmg, "next_hit": next_hit})

static func tick_acid_pools(sim: GameSim) -> void:
	if sim.acid_pools.is_empty():
		return
	var now: float = float(sim.clock)
	for i in range(sim.acid_pools.size() - 1, -1, -1):
		var pool = sim.acid_pools[i]
		if now >= float(pool.until):
			sim.acid_pools.remove_at(i)
			continue
		var spot: Vector2 = Vector2(pool.pos)
		var r: float = float(pool.r)
		for q in sim.players.values():
			if int(q.state) != 0 or (q.inside and not SimPhases.any_breach(sim)):
				continue
			if Vector2(q.pos).distance_to(spot) <= r and SimWorld.line_clear(sim, spot, q.pos):
				SimPlayers.apply_poison(sim, q)
				if now >= float(pool.next_hit.get(q.id, 0.0)):
					pool.next_hit[q.id] = now + ACID_POOL_TICK_INTERVAL
					SimPlayers.hurt(sim, q, float(pool.dmg))

static func acid_pools_snapshot(sim: GameSim) -> Array:
	var out: Array = []
	var now: float = float(sim.clock)
	for pool in sim.acid_pools:
		out.append([Vector2(pool.pos), float(pool.r), maxf(0.0, float(pool.until) - now), float(pool.dur)])
	return out
