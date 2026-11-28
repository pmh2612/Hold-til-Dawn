class_name SimChainwarden
extends RefCounted

# NOX-02: alternate a physical hook and a frontal chain sweep. IDs/legacy atlas keys stay stable.
const SWEEP_RANGE: float = 4.0 * GameSim.T
const SWEEP_ANGLE: float = PI * 2.0 / 3.0
const SWEEP_WIND: float = 0.8
const SWEEP_HIT: float = 0.35
const STUN_TIME: float = 1.5
const HOOK_WIND: float = 0.0
const HOOK_RANGE: float = 10.0 * GameSim.T
const HOOK_SPEED: float = 18.0 * GameSim.T
const HOOK_RADIUS: float = 6.0
const PULL_TIME: float = 0.55
const SPECIAL_GAP: float = 3.0

static func tick(sim: GameSim, e, dt: float) -> bool:
	var act: String = e.act
	if act == "chain_fly":
		tick_hook(sim, e, dt)
		return true
	if act == "chain_pull":
		var p = sim.players.get(e.get("chain_target", -1))
		if p != null:
			e.chain_tip = p.pos
	if act in ["sweep_wind", "sweep_hit", "chain_wind", "chain_pull", "chain_return"]:
		if e.act_t > 0:
			return true
		if act == "sweep_wind":
			SimBosses.boss_act(sim, e, "sweep_hit", SWEEP_HIT)
			SimAudio.emit(sim, "chain_sweep", e.pos, -int(e.id) - 1)
		elif act == "chain_wind":
			e.chain_tip = e.pos + Vector2.from_angle(e.face) * (e.r + 2.0)
			e.chain_left = HOOK_RANGE - e.r - 2.0
			e.chain_target = -1
			SimBosses.boss_act(sim, e, "chain_fly", HOOK_RANGE / HOOK_SPEED)
			SimAudio.emit(sim, "chain_throw", e.pos, -int(e.id) - 1)
		else:
			SimBosses.boss_act(sim, e, "", 0.0)
			e.special_cd = SimBosses.boss_cooldown(sim, SPECIAL_GAP)
		return e.act != ""
	if e.special_cd > 0:
		return false
	var p = SimBosses.boss_target(sim, e)
	if p == null:
		return false
	var range_: float = SWEEP_RANGE if e.next_chain_skill == "sweep" else HOOK_RANGE
	if e.pos.distance_to(p.pos) > range_:
		return false
	e.face = (p.pos - e.pos).angle()
	e.special_cd = INF
	if e.next_chain_skill == "sweep":
		SimBosses.add_telegraph(sim, "arc", e.pos, SWEEP_RANGE, SimBosses.boss_damage(sim, 18.0),
			{"ang": e.face, "spread": SWEEP_ANGLE, "t": SWEEP_WIND, "dur": SWEEP_WIND, "reaction": "stun"})
		SimBosses.boss_act(sim, e, "sweep_wind", SWEEP_WIND)
		e.next_chain_skill = "hook"
	else:
		e.chain_tip = e.pos + Vector2.from_angle(e.face) * (e.r + 2.0)
		e.chain_left = HOOK_RANGE - e.r - 2.0
		e.chain_target = -1
		SimBosses.boss_act(sim, e, "chain_fly", HOOK_RANGE / HOOK_SPEED)
		SimAudio.emit(sim, "chain_throw", e.pos, -int(e.id) - 1)
		e.next_chain_skill = "sweep"
	return true

static func tick_hook(sim: GameSim, e, dt: float) -> void:
	var start: Vector2 = e.chain_tip
	var distance: float = minf(HOOK_SPEED * dt, e.chain_left)
	var end: Vector2 = start + Vector2.from_angle(e.face) * distance
	var first: float = SimWorld.obstacle_hit(sim, start, end, HOOK_RADIUS)
	var victim = null
	for p in sim.players.values():
		if p.state != 0:
			continue
		var hit: float = WorldGeometry.circle_hit(start, end, p.pos, 0.4 * GameSim.T + HOOK_RADIUS)
		if hit < first:
			first = hit
			victim = p
	e.chain_tip = start.lerp(end, first) if first < INF else end
	e.chain_left -= distance
	if first < INF:
		if victim != null:
			var hp: float = victim.hp
			SimPlayers.hurt(sim, victim, SimBosses.boss_damage(sim, 8.0))
			if victim.hp < hp and victim.state == 0:
				SimPlayers.start_hit_reaction(sim, victim, "pull", e.pos - victim.pos)
				victim.hit_distance = maxf(0.0, Vector2(victim.pos).distance_to(e.pos) - e.r - 0.8 * GameSim.T)
				e.chain_target = victim.id
				e.chain_tip = Vector2(victim.pos)
				SimBosses.boss_act(sim, e, "chain_pull", PULL_TIME)
				SimAudio.emit(sim, "chain_catch", victim.pos, -int(e.id) - 1)
				return
		SimBosses.boss_act(sim, e, "chain_return", 0.2)
		SimAudio.emit(sim, "chain_ready", e.pos, -int(e.id) - 1)
	elif e.chain_left <= 0:
		SimBosses.boss_act(sim, e, "chain_return", 0.2)
		SimAudio.emit(sim, "chain_ready", e.pos, -int(e.id) - 1)

static func snapshot(sim: GameSim) -> Array:
	var chains: Array = []
	for e in sim.enemies:
		if e.type != GameSim.BOSS or int(e.kind) != GameSim.CHAINWARDEN or not e.act in ["chain_fly", "chain_pull", "chain_return"]:
			continue
		var tip: Vector2 = e.get("chain_tip", e.pos)
		if e.act == "chain_return":
			tip = Vector2(e.pos).lerp(tip, clampf(e.act_t / 0.2, 0, 1))
		chains.append([e.pos, tip, e.get("chain_target", -1), int(e.id), e.act, float(e.face)])
	return chains
