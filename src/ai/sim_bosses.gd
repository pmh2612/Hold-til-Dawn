class_name SimBosses
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/ai/GameSim.Bosses.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
# [code, name, HP at night 2 for 4 players on Medium, speed x Grunt] (table 4.2, BAL-39)
static var BOSS_KINDS = [["NOX-01", "Juggernaut", 3900.0, 1.0], ["NOX-02", "Broodmother", 4680.0, 0.75], ["NOX-03", "Bio-Cannon", 3510.0, 1.0], ["NOX-04", "Burrower", 3120.0, 1.0], ["NOX-05", "Gatebreaker", 4290.0, 1.0], ["NOX-06", "Phantom", 3120.0, 1.0], ["NOX-07", "Ironhide", 2730.0, 1.0]]
const TELEGRAPH: float = 1.0  # damaging special moves warn 1.0 s before impact; basic hits use the attack sprite
const SIGNATURE_HIT: float = 35.0
const MAX_SUMMONS: int = 4
const BASIC_DAMAGE: float = 12.0
const BASIC_INTERVAL: float = 1.2
const STRUCTURE_INTERVAL: float = 2.0

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

# Night 4: damage x1.21 and cooldowns x0.9, telegraphs unchanged (section 4.1).
static func boss_damage(sim: GameSim, base: float) -> float:
	return base * (1.21 if sim.k >= 4 else 1.0) * float(GameSim.MODE_MUL[sim.mode][2])

static func boss_cooldown(sim: GameSim, base: float) -> float:
	return base * (0.9 if sim.k >= 4 else 1.0)

static func setup_boss(sim: GameSim, e, kind: int) -> void:
	var b = BOSS_KINDS[kind]
	e.type = BOSS
	e.kind = kind
	# FML-02: HP scales with the team, x1.5625 on night 4, and with the mode
	e.hp = b[2] * (1 + 0.8 * (sim.players.size() - 1)) / 3.4 * (1.5625 if sim.k == 4 else 1.0) * GameSim.MODE_MUL[sim.mode][1]
	e.maxhp = e.hp
	e.spd = e.spd * b[3]
	# Smaller, more frequent structure hits preserve 15 base DPS. Gatebreaker's signature stays 120 / 8 s.
	e.dmg = boss_damage(sim, 30.0)
	e.slam = boss_damage(sim, 40.0)
	e.slam_cd = 3.0
	e.sig_cd = 4.0
	e.act = ""
	e.act_t = 0.0
	e.face = (GameSim.DOOR_POS[e.door] - e.pos).angle()
	# body radius: big enough to match the drawn boss (2x sprite, src/ai/view/enemy_view.gd), small enough to get
	# through a door gap (2.4 tiles) once the door is broken
	e.r = 1.1 * T
	e.dash_hit = []

# --- damage rules -------------------------------------------------------
static func hittable(sim: GameSim, e) -> bool:
	# a burrowed boss cannot be hit (Burrower, table 4.2)
	return not (e.type == BOSS and e.get("act", "") in ["burrow", "surface"])

static func boss_damage_taken(sim: GameSim, e, dmg, from) -> Variant:
	if e.type != BOSS or int(e.kind) != IRONHIDE or e.get("act", "") == "stagger":
		return dmg
	# Ironhide: hits from its front 120 degrees deal 30% damage
	var off: float = absf(angle_difference(float(e.face), (from - e.pos).angle()))
	return dmg * 0.3 if off <= deg_to_rad(60.0) else dmg

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

# Whom the boss's signature move aims at: the player it retaliates against, else the nearest one it sees.
static func boss_target(sim: GameSim, e) -> Variant:
	var p = sim.players.get(e.target) if e.state == 1 else null
	if p != null and p.state == 0:
		return p
	return SimEnemies.nearest_player(sim, e.pos, 8.0 * T)

static func add_telegraph(sim: GameSim, kind, pos: Vector2, r: float, dmg: float, extra = null) -> void:
	var tl = {"kind": kind, "pos": pos, "r": r, "t": TELEGRAPH, "dur": TELEGRAPH, "dmg": dmg, "end": pos, "ang": 0.0, "spread": TAU}
	if extra != null:
		for key in extra:
			tl[key] = extra[key]
	sim.tele.append(tl)
	SimAudio.emit(sim, "boss_warn", pos)

# BAL-38: a 40-damage slam of radius 3 every 6 s when a player is close; the boss stands still while it lands.
static func boss_slam(sim: GameSim, e, dt) -> void:
	e.slam_cd -= dt
	if e.slam_cd > 0 or e.act != "":
		return
	for p in sim.players.values():
		if p.state == 0 and p.pos.distance_to(e.pos) < 3 * T:
			start_slam(sim, e)
			return

static func start_slam(sim: GameSim, e) -> void:
	add_telegraph(sim, "circle", e.pos, 3 * T, float(e.slam))
	e.slam_cd = boss_cooldown(sim, 6.0)
	boss_act(sim, e, "slam", TELEGRAPH)

# Runs the boss's current move; returns true while the boss is busy (it then skips walking and door hits).
static func tick_boss(sim: GameSim, e, dt) -> bool:
	e.sig_cd -= dt
	e.shown = e.get("shown", 0.0) - dt
	var kind: int = int(e.kind)
	var act = e.act
	if act == "cloak":
		return tick_cloak(sim, e, dt)
	if act != "":
		e.act_t -= dt
		if act == "charge":
			return tick_charge(sim, e, dt)
		if act == "burrow":
			return tick_burrow(sim, e, dt)
		if e.act_t > 0:
			return true
		finish_act(sim, e, act)
		return e.act != ""
	if e.sig_cd > 0:
		return false
	var p = boss_target(sim, e)
	var d: float = p.pos.distance_to(e.pos) if p != null else INF
	if kind == JUGGERNAUT and d >= 3 * T and d <= 10 * T:
		# charge: 1.0 s line telegraph 1.5 tiles wide, then a dash of up to 10 tiles at 9 tiles/s
		var dir: Vector2 = (p.pos - e.pos).normalized()
		e.dash = dir
		e.dash_left = 10.0 * T
		e.face = dir.angle()
		e.dash_hit = []
		add_telegraph(sim, "line", e.pos, 0.75 * T, 0.0, {"end": e.pos + dir * (10.0 * T)})
		boss_act(sim, e, "charge_wind", TELEGRAPH)
		e.sig_cd = boss_cooldown(sim, 8.0)
		return true
	if kind == BROODMOTHER:
		boss_act(sim, e, "glow", TELEGRAPH)
		e.sig_cd = boss_cooldown(sim, 12.0)
		return true
	if kind == BIO_CANNON and p != null:
		boss_act(sim, e, "glow", TELEGRAPH)
		e.sig_cd = boss_cooldown(sim, 5.0)
		return true
	if kind == BURROWER and p != null:
		e.burrow = p.id
		boss_act(sim, e, "burrow", 3.0)
		e.sig_cd = boss_cooldown(sim, 10.0)
		return true
	if kind == PHANTOM:
		e.burrow = p.id if p != null else 0
		boss_act(sim, e, "cloak", 4.0)
		e.sig_cd = boss_cooldown(sim, 12.0)
		return false
	return false

static func finish_act(sim: GameSim, e, act) -> void:
	var kind: int = int(e.kind)
	boss_act(sim, e, "", 0.0)
	if act == "slam":
		SimAudio.emit(sim, "boss_slam", e.pos, -int(e.id) - 1)
		# Juggernaut: 2 s recovery after the slam; Ironhide: 3 s stagger with full damage from every side
		if kind == JUGGERNAUT and e.get("dashed", false):
			e.dashed = false
			boss_act(sim, e, "recover", 2.0)
		elif kind == IRONHIDE:
			boss_act(sim, e, "stagger", 3.0)
	elif act == "charge_wind":
		boss_act(sim, e, "charge", 10.0)
	elif act == "glow" and kind == BROODMOTHER:
		SimAudio.emit(sim, "boss_summon", e.pos, -int(e.id) - 1)
		summon(sim, e)
	elif act == "glow" and kind == BIO_CANNON:
		SimAudio.emit(sim, "boss_barrage", e.pos, -int(e.id) - 1)
		# a ring of 8 projectiles with 45-degree gaps: 12 damage, 4 tiles/s, range 8 tiles
		for i in range(8):
			var dir: Vector2 = Vector2.from_angle(i * TAU / 8.0)
			sim.proj.append({"pos": e.pos + dir * e.r, "vel": dir * 4.0 * T, "dmg": boss_damage(sim, 12.0), "ttl": 2.0, "kind": "orb"})
	elif act == "surface":
		e.pos = e.surface
		boss_act(sim, e, "climb", 1.5)
	elif act == "ambush":
		e.shown = 3.0
	elif act == "blow":
		var tw = sim.towers[e.tw] if e.state == 5 else null
		if tw != null and tw.hp > 0:
			SimEnemies.damage_tower(sim, e, tw, boss_damage(sim, 120.0))
		elif e.state != 5:
			SimEnemies.damage_door(sim, e, boss_damage(sim, 120.0))

static func tick_charge(sim: GameSim, e, dt) -> bool:
	var old: Vector2 = Vector2(e.pos)
	var step: float = minf(9.0 * T * dt, e.dash_left)
	var want: Vector2 = old + e.dash * step
	e.pos = SimWorld.push_out(SimWorld.move_actor(sim, old, want, e.r), e.r)
	e.dash_left -= step
	# 35 damage and knockback to anyone on the line, once per dash
	for p in sim.players.values():
		if p.state == 0 and not p.id in e.dash_hit and p.pos.distance_to(e.pos) <= e.r + 0.5 * T:
			e.dash_hit.append(p.id)
			SimPlayers.hurt(sim, p, boss_damage(sim, SIGNATURE_HIT))
			knockback(sim, p, e.pos, 2.0 * T)
	var blocked_: bool = e.pos.distance_to(want) > 2.0
	if e.dash_left <= 0 or blocked_:
		e.dashed = true
		start_slam(sim, e)
	return true

static func tick_burrow(sim: GameSim, e, dt) -> bool:
	var p = sim.players.get(e.burrow)
	var lost: bool = p == null or p.state != 0
	if not lost:
		# underground it closes in fast and cannot be hit or hit doors
		var old: Vector2 = Vector2(e.pos)
		e.pos = SimWorld.push_out(SimWorld.move_actor(sim, old, old + (p.pos - old).limit_length(e.spd * 2.0 * dt), e.r), e.r)
	if e.act_t > 0 and not lost and e.pos.distance_to(p.pos) > 2.5 * T:
		return true
	# surfaces at least 1.5 tiles from its target behind a 1.0 s dirt telegraph of radius 2 tiles
	var spot: Vector2 = Vector2(e.pos)
	if not lost:
		var away: Vector2 = (e.pos - p.pos).normalized() if e.pos.distance_to(p.pos) > 1.0 else Vector2.RIGHT
		spot = SimWorld.push_out(sim.world.resolve(p.pos + away * (1.5 * T), e.r), e.r)
	e.surface = spot
	add_telegraph(sim, "circle", spot, 2.0 * T, boss_damage(sim, SIGNATURE_HIT))
	boss_act(sim, e, "surface", TELEGRAPH)
	return true

static func tick_cloak(sim: GameSim, e, dt) -> bool:
	e.act_t -= dt
	var p = sim.players.get(e.burrow)
	if p == null or p.state != 0:
		p = boss_target(sim, e)
	if p == null:
		if e.act_t <= 0:
			boss_act(sim, e, "", 0.0)
		# invisible but still walking to its door; it does not hit doors while cloaked
		return false
	var old: Vector2 = Vector2(e.pos)
	if old.distance_to(p.pos) > 1.5 * T:
		e.pos = SimWorld.move_actor(sim, old, old + (SimEnemies.enemy_waypoint(sim, e, p.pos) - old).normalized() * e.spd * dt, e.r)
		e.pos = SimWorld.push_out(e.pos, e.r)
	if old.distance_to(p.pos) <= 2.0 * T or e.act_t <= 0:
		# the ambush telegraph reveals it: a 1.0 s arc, then 35 damage in a 1.5-tile arc
		e.face = (p.pos - e.pos).angle()
		add_telegraph(sim, "arc", e.pos, e.r + 1.5 * T, boss_damage(sim, SIGNATURE_HIT), {"ang": e.face, "spread": deg_to_rad(120.0)})
		boss_act(sim, e, "ambush", TELEGRAPH)
	return true

# Broodmother: 2 Grunts of the current night appear beside it (at most 4 alive, no drops, vanish with it).
static func summon(sim: GameSim, e) -> void:
	var mine = sim.enemies.filter(func(x): return x.get("owner", -1) == e.id)
	var room_: int = min(MAX_SUMMONS - mine.size(), MAX_ENEMIES - sim.enemies.size())
	for i in range(mini(2, room_)):
		var g = SimEnemies.spawn(sim, GRUNT, e.door, 0.0, false)
		var side: Vector2 = Vector2.from_angle(e.face + (PI / 2 if i == 0 else -PI / 2))
		g.pos = SimWorld.push_out(sim.world.resolve(e.pos + side * (e.r + 0.7 * T), g.r), g.r)
		g.owner = e.id
		g.summon = true

static func knockback(sim: GameSim, p, from: Vector2, dist: float) -> void:
	var dir: Vector2 = (p.pos - from).normalized() if p.pos.distance_to(from) > 1.0 else Vector2.RIGHT
	var to: Vector2 = SimWorld.move_actor(sim, p.pos, p.pos + dir * dist, 0.3 * T)
	if not p.inside:
		to = SimWorld.push_out(to, 0.4 * T)
	SimPhases.teleport(sim, p, to)

# Whether this boss hits doors and towers right now (not while burrowed or cloaked).
static func boss_hits_doors(sim: GameSim, e) -> bool:
	return not e.get("act", "") in ["burrow", "surface", "cloak"]

# The Gatebreaker's door blow: a 1.0 s wind-up, then 120 damage in one hit, every 8 s.
static func start_blow(sim: GameSim, e) -> bool:
	if e.type != BOSS or int(e.kind) != GATEBREAKER:
		return false
	add_telegraph(sim, "circle", e.pos + Vector2.from_angle(float(e.face)) * e.r, 1.0 * T, 0.0)
	boss_act(sim, e, "blow", TELEGRAPH)
	e.cd = boss_cooldown(sim, 8.0)
	return true

# Boss state for the client: "" or the current move (cloak, burrow, glow, stagger, ...).
static func boss_look(sim: GameSim, e) -> Variant:
	if e.type != BOSS:
		return ""
	var act = e.act
	if act == "" and e.get("shown", 0.0) > 0:
		return "shown"
	return act
