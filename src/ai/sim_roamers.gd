class_name SimRoamers
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/ai/GameSim.Roamers.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
# Owner: Vu Duc Viet Anh. Daytime roamers (MEC-26, FML-16, BAL-44).
static var ROAM_MUL: float = AiSettings.get_current().roamer_multiplier
const ROAM_D0 = 10.0
const ROAM_D1 = 45.0
const ROAM_PMAX = 0.65
const VIEW_HALF = Vector2(15.0, 8.5) * T
const CHEST_ACTIVATION_RANGE: float = 18.0 * T
const CHEST_SPAWN_GAP: float = 0.8

# constants shared with GameSim
const GRUNT = GameSim.GRUNT
const MAX_ENEMIES = GameSim.MAX_ENEMIES
const ROAM_CHECK = GameSim.ROAM_CHECK
const ROAM_MAX = GameSim.ROAM_MAX
const SPITTER = GameSim.SPITTER
const T = GameSim.T

static func tick_roamers(sim: GameSim, dt) -> void:
	if sim.phase != "day":
		return
	tick_chest_patrols(sim, float(dt))
	for p in sim.players.values():
		p.roam_t -= dt
		if p.roam_t > 0:
			continue
		p.roam_t = ROAM_CHECK
		if p.state != 0 or SimWorld.inside_base(p.pos) or roamer_count(sim) >= ROAM_MAX or sim.enemies.size() > MAX_ENEMIES - 2:
			continue
		# Around unopened chests, spend the same enemy budget on local patrols instead.
		if sim.exploration_chests.any(func(c): return not c.opened and Vector2(p.pos).distance_squared_to(c.pos) <= CHEST_ACTIVATION_RANGE * CHEST_ACTIVATION_RANGE):
			continue
		if sim.rng.randf() < roam_chance(p.pos) * ROAM_MUL * (1.4 if sim.world.swamp_centre.distance_to(Vector2(p.pos)) < 14 * T else 1.0):
			spawn_roamers(sim, p)

# Activate only approached chests. One birth per interval, including after a long frame.
static func tick_chest_patrols(sim: GameSim, dt: float) -> void:
	if sim.phase != "day":
		return
	sim.chest_roam_spawn_left = maxf(0, sim.chest_roam_spawn_left - dt)
	sim.chest_roam_scan_left -= dt
	if sim.chest_roam_scan_left > 0:
		return
	sim.chest_roam_scan_left = 0.5
	if sim.chest_roam_spawn_left > 0 or ROAM_MUL <= 0 or roamer_count(sim) >= ROAM_MAX or sim.enemies.size() >= MAX_ENEMIES:
		return
	var target = null
	var best: float = CHEST_ACTIVATION_RANGE * CHEST_ACTIVATION_RANGE
	var quota: int = 2 if int(sim.k) < 3 else 3
	for c in sim.exploration_chests:
		if c.opened:
			continue
		if c.patrol_day != int(sim.k):
			c.patrol_day = int(sim.k)
			c.patrol_spawned = 0
		if c.patrol_spawned >= quota:
			continue
		for p in sim.players.values():
			if p.state != 0 or SimWorld.inside_base(p.pos):
				continue
			var d: float = Vector2(p.pos).distance_squared_to(c.pos)
			if d < best:
				best = d
				target = c
	if target == null:
		return
	var at: Vector2 = chest_patrol_spot(sim, target.pos)
	# A cramped site gets a bounded retry, rather than an unbounded placement loop.
	sim.chest_roam_spawn_left = CHEST_SPAWN_GAP
	if not at.is_finite():
		return
	var type: int = SPITTER if sim.k >= 4 and target.patrol_spawned == quota - 1 else GRUNT
	var e = SimEnemies.spawn(sim, type, SimEnemies.nearest_active_door(sim, at), 0.0)
	e.pos = at
	e.home = target.pos
	e.wander = at
	e.state = 4
	e.chest_patrol = target.id
	target.patrol_spawned += 1

static func chest_patrol_spot(sim: GameSim, centre: Vector2) -> Vector2:
	var angle: float = sim.rng.randf_range(0, TAU)
	for i in range(32):
		var radius: float = (2.0 + (i % 4) * 0.7) * T
		var at: Vector2 = (centre + Vector2.from_angle(angle + i * 2.399963) * radius).round()
		if not IslandMap.on_land(at, 0.5 * T) or SimWorld.inside_base(at, T) or IslandMap.in_bridge_approach(at, T):
			continue
		if Vector2(sim.world.resolve_fast(at, 0.5 * T)).distance_squared_to(at) > 1 or not SimWorld.line_clear(sim, centre, at):
			continue
		if sim.players.values().any(func(p): return p.state == 0 and Vector2(p.pos).distance_squared_to(at) < pow(1.5 * T, 2)):
			continue
		if sim.enemies.any(func(e): return e.hp > 0 and Vector2(e.pos).distance_squared_to(at) < pow(float(e.r) + 0.5 * T + 6, 2)):
			continue
		return at
	return Vector2.INF

static func roam_chance(pos) -> Variant:
	# tiles from the nearest base wall (FML-16)
	var d = SimWorld.wall_dist(pos) / T
	return ROAM_PMAX * clampf((d - ROAM_D0) / (ROAM_D1 - ROAM_D0), 0.0, 1.0)

static func spawn_roamers(sim: GameSim, p) -> void:
	# Just outside this player's camera view, on the side away from the base.
	var away: Vector2 = Vector2(p.pos.normalized())
	var side = Vector2(-away.y, away.x)
	var at: Vector2 = p.pos + away * (VIEW_HALF.x + 2 * T) + side * sim.rng.randf_range(-4.0, 4.0) * T
	if not IslandMap.on_land(at, 2 * T):
		at = p.pos + side * (VIEW_HALF.x + 2 * T) * (1.0 if sim.rng.randf() < 0.5 else -1.0)
	at = IslandMap.pull_inland(at, 2 * T)
	for q in sim.players.values():
		if absf(q.pos.x - at.x) < VIEW_HALF.x + T and absf(q.pos.y - at.y) < VIEW_HALF.y + T:
			return
	for i in mini(2, ROAM_MAX - roamer_count(sim)):
		var ty: int = SPITTER if sim.k >= 4 and i == 1 and sim.rng.randf() < 0.5 else GRUNT
		# stats of night k on day k
		var e = SimEnemies.spawn(sim, ty, SimEnemies.nearest_active_door(sim, at), 0.0)
		e.pos = sim.world.resolve_fast(at + Vector2(int(i) * 1.3 * T, 0), float(e.r))
		e.home = at
		e.wander = e.pos
		e.state = 4

static func roamer_count(sim: GameSim) -> Variant:
	return sim.enemies.filter(func(e): return e.has("home")).size()

static func wander(sim: GameSim, e, dt) -> void:
	if e.pos.distance_to(e.wander) < 4.0:
		e.wander = e.home + Vector2.from_angle(sim.rng.randf() * TAU) * sim.rng.randf_range(0.0, 3.0) * T
	e.pos += (SimEnemies.enemy_waypoint(sim, e, e.wander) - e.pos).normalized() * minf(e.spd * 0.4 * dt, e.pos.distance_to(e.wander))
	e.pos = SimWorld.push_out(e.pos, e.r)
