class_name SimEnemies
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/ai/GameSim.Enemies.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
static var ENEMY_SPEED_MUL: float = AiSettings.get_current().enemy_speed
const ENEMY_NAVIGATION_LIMIT: int = 2
const ROAM_SIGHT = 4.0 * T
const GRUNT_ATTACK_INTERVAL: float = 1.0
const SPITTER_ATTACK_INTERVAL: float = 1.25
const WRECKER_ATTACK_INTERVAL: float = 1.25

# constants shared with GameSim
const BOSS = GameSim.BOSS
const DOOR_HP = GameSim.DOOR_HP
const GRUNT = GameSim.GRUNT
const HALF = GameSim.HALF
const SPAWN_ALL_SIDES = GameSim.SPAWN_ALL_SIDES
const SPITTER = GameSim.SPITTER
const T = GameSim.T
const WRECKER = GameSim.WRECKER

# --- enemies ------------------------------------------------------------
static func tick_waves(sim: GameSim) -> void:
	if sim.phase != "night" or float(sim.t) <= 0:
		SimNightSpawns.reset_night_spawns(sim)
		return
	if float(sim.elapsed) >= float(sim.next_wave):
		sim.wave = int(sim.wave) + 1
		# Schedule from now; a long frame must never replay missed waves in a burst.
		sim.next_wave = float(sim.elapsed) + sim.night_wave_interval
		spawn_wave(sim)
	if sim.boss_night and not sim.boss_spawned and float(sim.elapsed) >= sim.boss_at:
		sim.boss_spawned = true
		spawn_boss(sim)
		return  # keep a regular birth off the boss's creation tick
	SimNightSpawns.tick_pending_night_spawn(sim)
	SimNightSpawns.pull_night_forward(sim)

static func spawn_wave(sim: GameSim) -> void:
	SimNightSpawns.plan_night_wave(sim)

static func spawn(sim: GameSim, ty, door, dist_tiles, any_side = null) -> Variant:
	return spawn_enemy(sim, int(ty), int(door), float(dist_tiles), SPAWN_ALL_SIDES if any_side == null else any_side)

static func spawn_enemy(sim: GameSim, type: int, door: int, distance: float, any_side: bool) -> Variant:
	var stats = GameSim.ENEMY[type]
	var mode_stats = GameSim.MODE_MUL[int(sim.mode)]
	var night_: int = int(sim.k)
	var id: int = int(sim.next_id)
	var growth: float = pow(1.1, night_ - 1)
	var radius: float = (0.625 if type == WRECKER else 0.5) * T
	var hp: float = float(stats[0]) * growth * float(mode_stats[1])
	var pos: Vector2 = spawn_position(sim, door, distance, any_side)
	pos = sim.world.resolve_fast(pos, radius)
	var enemy = {"id": id, "type": type, "pos": pos, "hp": hp, "maxhp": hp, "dmg": float(stats[1]) * growth * float(mode_stats[2]), "spd": minf(3.0, float(stats[2]) * pow(1.08, night_ - 1)) * T * ENEMY_SPEED_MUL, "door": door, "state": 0, "cd": 0.0, "hits": [], "target": 0, "anchor": Vector2.ZERO, "nodmg": 0.0, "r": radius}
	sim.next_id = id + 1
	sim.enemies.append(enemy)
	return enemy

static func spawn_boss(sim: GameSim) -> void:
	var door: int = int(sim.active[sim.rng.randi() % sim.active.size()])
	var e = spawn(sim, GRUNT, door, 60.0, false)
	# BAL-34: 60 tiles in front of its door; BAL-39: a Grunt's speed of this night
	e.pos = IslandMap.pull_inland(Vector2(GameSim.DOOR_POS[door] + GameSim.DOOR_DIR[door] * 60.0 * T), 2 * T)
	SimBosses.setup_boss(sim, e, SimBosses.boss_kind_for(sim, sim.k))
	# the boss is the last enemy of the night's quota
	e.quota = true
	sim.night_spawned += 1
	SimPlayers.say(sim, "%s: door %s" % [SimBosses.boss_title(e.kind).to_upper(), GameSim.DOOR_NAMES[door]])

static func boss(sim: GameSim) -> Variant:
	for e in sim.enemies:
		if e.type == BOSS:
			return e
	return null

# Fixed-rate entry for real-time simulation; the explicit TickEnemies(dt) helper retains exact-step semantics.
static func tick_enemy_simulation(sim: GameSim, dt: float) -> void:
	sim.enemy_navigation_updates_this_tick = 0
	sim.enemy_step_accumulator += dt
	if sim.enemy_step_accumulator < sim.enemy_body_interval - 0.000001:
		return
	var step: float = sim.enemy_step_accumulator
	sim.enemy_step_accumulator = 0
	sim.enemy_body_steps += 1
	tick_enemies(sim, step)

static func tick_enemies(sim: GameSim, dt) -> void:
	sim.enemy_navigation_updates_this_tick = 0
	sim.limit_enemy_navigation = true
	# try (GDScript has no exceptions; the body runs unguarded)
	tick_enemy_bodies(sim, dt)
	sim.limit_enemy_navigation = false

static func tick_enemy_bodies(sim: GameSim, dt) -> void:
	# a copy: a Broodmother's summons join the list during the loop
	var frame_dt: float = float(dt)
	var batch = sim.enemy_batch
	batch.clear()
	for enemy in sim.enemies:
		batch.append(enemy)
	var start: int = 0 if batch.size() == 0 else sim.enemy_think_cursor % batch.size()
	sim.enemy_think_cursor = start + 1
	var index: int = 0
	while index < batch.size():
		dt = frame_dt
		var e = batch[(start + index) % batch.size()]
		var old_pos: Vector2 = Vector2(e.pos)
		e.nav_t = e.get("nav_t", 0.0) - dt
		e.cd -= dt
		e.nodmg += dt
		e.swing = e.get("swing", 0.0) - dt
		if e.has("home") and sim.phase == "day":
			var near: bool = false
			for p in sim.players.values():
				if int(p.get("state")) == 0 and Vector2(p.get("pos")).distance_squared_to(Vector2(e.pos)) < 45 * T * 45 * T:
					near = true
					break
			e.unseen = 0.0 if near else e.get("unseen", 0.0) + float(dt)
			if e.unseen > 25.0:
				e.hp = 0.0
				index += 1
				continue
		if e.hp <= 0 or e.get("stun_until", 0.0) > sim.clock:
			index += 1
			continue
		if e.get("slow_until", 0.0) > sim.clock:
			dt = frame_dt * 0.75
		if e.type == BOSS and SimBosses.tick_boss(sim, e, dt):
			index += 1
			continue
		# a Broodmother's summons vanish with it (BAL-43)
		if e.get("summon", false) and not sim.enemies.any(func(x): return x.id == e.owner and x.hp > 0):
			e.hp = 0.0
			index += 1
			continue
		if e.type == SPITTER:
			tick_spitter(sim, e, dt)
			e.pos = SimWorld.move_actor(sim, old_pos, e.pos, e.r)
			index += 1
			continue
		if e.state == 4:
			var seen = nearest_player(sim, e.pos, ROAM_SIGHT)
			if seen == null:
				SimRoamers.wander(sim, e, dt)
				e.pos = SimWorld.move_actor(sim, old_pos, e.pos, e.r)
				index += 1
				continue
			e.state = 1
			e.target = seen.id
			e.anchor = e.pos
			e.nodmg = 0.0
		var target_p = null
		e.calm = e.get("calm", 0.0) - dt
		if e.state == 1:
			# FML-09: re-evaluate the top threat every 0.25 s
			e.retarget_t = e.get("retarget_t", 0.0) - dt
			if e.retarget_t <= 0:
				e.retarget_t = 0.25
				SimPlayers.retarget(sim, e)
			target_p = sim.players.get(e.target)
			if target_p == null or target_p.state != 0 or target_p.inside and not SimPhases.any_breach(sim) or e.nodmg > 5.0 or e.pos.distance_to(e.anchor) > 12 * T:
				# roamers go back to wandering by day; a boss ignores new threat for 10 s (BAL-35)
				e.state = 4 if e.has("home") else 0
				e.hits.clear()
				if e.type == BOSS:
					e.calm = 10.0
				target_p = null
				if e.state == 4:
					index += 1
					continue
		# Strike players in reach even while marching to a door or guarding a tower. Bosses used to
		# have no basic player attack at all, leaving long idle gaps between their special moves.
		var close_player = nearest_player(sim, e.pos, e.r + 0.55 * T)
		if close_player != null:
			if e.cd <= 0:
				melee_attack(sim, e, close_player)
			if e.type == BOSS:
				SimBosses.boss_slam(sim, e, dt)
			index += 1
			continue
		if e.state == 0 and sim.phase == "night":
			var lit = SimTowers.tower_in_light(sim, e.pos)
			if lit != null:
				e.state = 5
				e.tw = lit.slot
		if e.state == 5:
			var tw = sim.towers[e.tw]
			if tw == null or tw.hp <= 0:
				e.state = 0
			else:
				if e.pos.distance_to(tw.pos) > e.r + 0.7 * T + 2.0:
					e.pos += (enemy_waypoint(sim, e, tw.pos) - e.pos).normalized() * minf(e.spd * dt, e.pos.distance_to(tw.pos))
				elif e.cd <= 0:
					tower_attack(sim, e, tw)
				if e.type == BOSS:
					SimBosses.boss_slam(sim, e, dt)
				e.pos = SimWorld.push_out(SimWorld.move_actor(sim, old_pos, e.pos, e.r), e.r)
				index += 1
				continue
		if (e.state == 0 or e.state == 2) and sim.doors[e.door] <= 0:
			e.state = 3
		var door_pos: Vector2 = Vector2(GameSim.DOOR_POS[e.door])
		# anywhere along the door gap
		var near_door: bool = e.pos.distance_to(door_pos) <= e.r + T
		var goal: Vector2 = door_pos + GameSim.DOOR_DIR[e.door] * (e.r + 0.2 * T)
		var arrived = near_door
		var outside = true
		if e.state == 1:
			goal = target_p.pos
			arrived = e.pos.distance_to(goal) <= e.r + 0.4 * T
		elif e.state == 3 and (SimWorld.inside_base(e.pos, e.r + 2) or near_door):
			# through the broken door to the generator
			goal = Vector2.ZERO
			arrived = e.pos.length() <= 2.5 * T
			outside = false
		if not arrived:
			var way = enemy_waypoint(sim, e, goal, outside)
			e.pos += (way - e.pos).normalized() * minf(e.spd * dt, e.pos.distance_to(goal))
		elif e.cd <= 0:
			enemy_attack(sim, e, target_p)
		if e.type == BOSS:
			SimBosses.boss_slam(sim, e, dt)
			if e.pos.distance_to(old_pos) > 0.5:
				e.face = (e.pos - old_pos).angle()
		e.pos = SimWorld.move_actor(sim, old_pos, e.pos, e.r)
		if outside:
			e.pos = SimWorld.push_out(e.pos, e.r)
		tick_blocked(sim, e, old_pos, arrived, dt)
		index += 1
	sim.enemies = sim.enemies.filter(func(e): return e.hp > 0)
	separate(sim)

static func enemy_attack(sim: GameSim, e, p) -> void:
	var boss_: bool = e.type == BOSS
	if e.state == 1:
		melee_attack(sim, e, p)
		return
	if boss_ and (not SimBosses.boss_hits_doors(sim, e) or SimBosses.start_blow(sim, e)):
		return
	damage_door(sim, e, e.dmg)
	e.cd = attack_interval(e)

static func attack_interval(e) -> float:
	if e.type == BOSS:
		return SimBosses.STRUCTURE_INTERVAL
	return WRECKER_ATTACK_INTERVAL if e.type == WRECKER else GRUNT_ATTACK_INTERVAL

static func melee_attack(sim: GameSim, e, p) -> bool:
	if e.cd > 0 or p == null or p.state != 0 or p.inside and not SimPhases.any_breach(sim):
		return false
	if e.pos.distance_squared_to(p.pos) > pow(e.r + 0.55 * T, 2) or not SimWorld.line_clear(sim, e.pos, p.pos):
		return false
	if e.type == BOSS and e.get("act", "") != "":
		return false
	e.face = (p.pos - e.pos).angle()
	SimPlayers.hurt(sim, p, SimBosses.boss_damage(sim, SimBosses.BASIC_DAMAGE) if e.type == BOSS else e.dmg)
	e.cd = SimBosses.BASIC_INTERVAL if e.type == BOSS else attack_interval(e)
	swung(sim, e)
	return true

# An enemy just struck (or spat): the snapshot flags it for 0.4 s so clients play its attack frames.
static func swung(sim: GameSim, e) -> void:
	e.swing = 0.4
	var cue: String = "boss_swing" if e.type == BOSS else "spit" if e.type == SPITTER else "wrecker_atk" if e.type == WRECKER else "growl"
	SimAudio.emit(sim, cue, e.pos, -int(e.id) - 1)

# FML-07: a hit on an intact door also hurts the generator, more as the door degrades; through a broken
# door the damage goes to the generator in full. Wreckers deal double damage to doors and towers.
static func damage_door(sim: GameSim, e, dmg) -> void:
	swung(sim, e)
	var d: float = float(dmg * (2.0 if e.type == WRECKER else 1.0))
	if e.state == 3:
		sim.base_hp -= d
	else:
		var x: float = float(1.0 - sim.doors[e.door] / DOOR_HP)
		sim.doors[e.door] = maxf(0.0, sim.doors[e.door] - d)
		sim.base_hp -= 0.3 * d * (1.0 + x)
		sim.door_pause[e.door] = 2.0
		e.state = 2
		if sim.doors[e.door] <= 0 and not sim.broken[e.door]:
			sim.broken[e.door] = true
			SimPlayers.say(sim, "Door %s broken!" % [GameSim.DOOR_NAMES[e.door]])
	# the result screen names the door where the generator took its last hit
	sim.last_door = e.door
	sim.base_hp = maxf(0.0, sim.base_hp)

# MEC-11: an enemy that cannot get past a built wall for a second attacks it (as it would a door).
static func tick_blocked(sim: GameSim, e, old_pos: Vector2, arrived, dt) -> void:
	var stuck: bool = not arrived and e.pos.distance_to(old_pos) < maxf(e.spd * dt * 0.3, 0.2)
	e.stuck_t = e.get("stuck_t", 0.0) + dt if stuck else 0.0
	if e.stuck_t < 1.0 or e.cd > 0:
		return
	var w = SimWalls.wall_touching(sim, e.pos, e.r)
	if w != null:
		swung(sim, e)
		SimWalls.damage_wall(sim, e, w, e.dmg)
		e.cd = attack_interval(e)

static func tower_attack(sim: GameSim, e, tw) -> void:
	if e.type == BOSS and (not SimBosses.boss_hits_doors(sim, e) or SimBosses.start_blow(sim, e)):
		return
	damage_tower(sim, e, tw, e.dmg)
	e.cd = attack_interval(e)

static func damage_tower(sim: GameSim, e, tw, dmg) -> void:
	swung(sim, e)
	tw.hp = maxf(0.0, tw.hp - dmg * (2.0 if e.type == WRECKER else 1.0))
	# FML-08: a hit blocks repair for 2 s
	tw.pause = 2.0
	if tw.hp <= 0 and not tw.wrecked:
		tw.wrecked = true
		SimPlayers.say(sim, "Tower destroyed")

static func enemy_near(sim: GameSim, pos, radius) -> Variant:
	for e in sim.enemies:
		if e.pos.distance_to(pos) <= radius:
			return true
	return false

static func tick_spitter(sim: GameSim, e, dt) -> void:
	var best = nearest_player(sim, e.pos, ROAM_SIGHT if e.state == 4 else 8.0 * T, false)
	var bd: float = best.pos.distance_to(e.pos) if best != null else INF
	if best == null and e.state == 4:
		SimRoamers.wander(sim, e, dt)
	elif best == null:
		var front: Vector2 = Vector2(GameSim.DOOR_POS[e.door] + GameSim.DOOR_DIR[e.door] * 4 * T)
		if e.pos.distance_to(front) > 0.5 * T:
			e.pos += (enemy_waypoint(sim, e, front) - e.pos).normalized() * e.spd * dt
			e.pos = SimWorld.push_out(e.pos, e.r)
	elif bd > 5.5 * T or not SimWorld.line_clear(sim, e.pos, best.pos):
		e.pos += (enemy_waypoint(sim, e, best.pos) - e.pos).normalized() * e.spd * dt
		e.pos = SimWorld.push_out(e.pos, e.r)
	elif e.cd <= 0:
		e.cd = SPITTER_ATTACK_INTERVAL
		swung(sim, e)
		sim.proj.append({"pos": e.pos, "vel": (best.pos - e.pos).normalized() * 8 * T, "dmg": e.dmg, "ttl": 1.0})

static func nearest_player(sim: GameSim, pos, radius, require_sight: bool = true) -> Variant:
	var best = null
	var bd = radius
	for p in sim.players.values():
		# an Engineer inside the base can only be reached through a broken door
		if p.state == 0 and (not p.inside or SimPhases.any_breach(sim)):
			var d: float = float(p.pos.distance_to(pos))
			if d <= bd and (not require_sight or SimWorld.line_clear(sim, pos, p.pos)):
				bd = d
				best = p
	return best

static func nearest_active_door(sim: GameSim, pos) -> Variant:
	var best: int = int(sim.active[0])
	for i in sim.active:
		if pos.distance_to(GameSim.DOOR_POS[i]) < pos.distance_to(GameSim.DOOR_POS[best]):
			best = i
	return best

static func tick_proj(sim: GameSim, dt) -> void:
	for b in sim.proj:
		var start: Vector2 = Vector2(b.pos)
		var end_: Vector2 = start + b.vel * minf(dt, maxf(0.0, b.ttl))
		var first = SimWorld.obstacle_hit(sim, start, end_, 3.5)
		var victim = null
		for p in sim.players.values():
			if p.state != 0:
				continue
			var hit_ = WorldGeometry.circle_hit(start, end_, p.pos, 0.5 * T + 3.5)
			if hit_ < first:
				first = hit_
				victim = p
		b.pos = start.lerp(end_, first) if first < INF else end_
		b.ttl -= dt
		if first < INF:
			if victim != null:
				SimPlayers.hurt(sim, victim, b.dmg)
			b.ttl = 0.0
	sim.proj = sim.proj.filter(func(b): return b.ttl > 0)

static func tick_tele(sim: GameSim, dt) -> void:
	for tl in sim.tele:
		tl.t -= dt
		if tl.t <= 0 and tl.dmg > 0:
			for p in sim.players.values():
				var d: Vector2 = Vector2(p.pos - tl.pos)
				var in_: bool = d.length() <= tl.r
				if in_ and tl.kind == "arc":
					in_ = absf(angle_difference(float(tl.ang), d.angle())) <= tl.spread / 2
				if in_:
					SimPlayers.hurt(sim, p, tl.dmg)
	sim.tele = sim.tele.filter(func(tl): return tl.t > 0)

static func separate(sim: GameSim) -> void:
	# Typed: with dozens of enemies at night this ran every tick on dynamic dictionaries. Same cells, same
	# pairs in the same order and the same pushes as before.
	var n: int = sim.enemies.size()
	if sim.sep_pos.size() < n:
		sim.sep_pos = Cs.arr(n, Vector2.ZERO)
		sim.sep_r = Cs.arr(n, 0.0)
	for i in range(n):
		var e = sim.enemies[i]
		sim.sep_pos[i] = Vector2(e.pos)
		sim.sep_r[i] = float(e.r)
	# Broad phase: circles cover every overlapping cell, including negative coordinates.
	for list in sim.sep_cells.values():
		list.clear()
	sim.sep_pairs.clear()
	sim.sep_seen.clear()
	for i in range(n):
		var lo = Vector2i(((sim.sep_pos[i] - Vector2.ONE * sim.sep_r[i]) / 64.0).floor())
		var hi = Vector2i(((sim.sep_pos[i] + Vector2.ONE * sim.sep_r[i]) / 64.0).floor())
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var cell = Vector2i(x, y)
				var in_ = sim.sep_cells.get(cell, null)
				if not sim.sep_cells.has(cell):
					in_ = []
					sim.sep_cells[cell] = in_
				for j in in_:
					if Cs.set_add(sim.sep_seen, [j, i]):
						sim.sep_pairs.append([j, i])
				in_.append(i)
	# cells nobody stood in this tick are dropped, so the table does not grow all night
	if sim.sep_cells.size() > 4 * n + 64:
		var empty = []
		for cell in sim.sep_cells:
			var list = sim.sep_cells[cell]
			if list.size() == 0:
				empty.append(cell)
		for cell in empty:
			sim.sep_cells.erase(cell)
	for _it1 in sim.sep_pairs:
		var a = _it1[0]
		var b = _it1[1]
		var d: Vector2 = sim.sep_pos[b] - sim.sep_pos[a]
		var need: float = sim.sep_r[a] + sim.sep_r[b]
		if d.length_squared() >= need * need:
			continue
		var length: float = d.length()
		var normal: Vector2 = d / length if length > 0.001 else Vector2.RIGHT
		var push: Vector2 = normal * (need - length) * 0.5
		sim.sep_pos[a] -= push
		sim.sep_pos[b] += push
	# Resolve scenery once per body after all pair corrections, not once per pair.
	for i in range(n):
		var e = sim.enemies[i]
		e.pos = SimWorld.move_actor(sim, sim.sep_pos[i], sim.sep_pos[i], sim.sep_r[i])

static func spawn_pos(sim: GameSim, door, dist_tiles, any_side) -> Variant:
	return spawn_position(sim, int(door), float(dist_tiles), any_side)

static func spawn_position(sim: GameSim, door: int, distance: float, any_side: bool) -> Vector2:
	var random = sim.rng
	if not any_side:
		var direction: Vector2 = Vector2(GameSim.DOOR_DIR[door])
		var at: Vector2 = Vector2(GameSim.DOOR_POS[door]) + direction * distance * T + Vector2(-direction.y, direction.x) * random.randf_range(-5.0, 5.0) * T
		return IslandMap.pull_inland(at, 2 * T)
	var dir: Vector2 = Vector2.from_angle(random.randf() * TAU)
	var pos: Vector2 = dir * (distance * T + Vector2(HALF).length())
	while float(SimWorld.wall_dist(pos)) < distance * T:
		pos += dir * T
	return pos

static func enemy_waypoint(sim: GameSim, e, goal, outside = null) -> Variant:
	if outside == null: outside = true
	if e.get("nav_t", 0.0) <= 0 or not e.has("nav_way") or e.pos.distance_to(e.nav_way) < 4.0 or e.get("nav_revision", -1) != sim.world.revision or e.get("nav_goal", Vector2.INF).distance_to(goal) > T:
		if sim.limit_enemy_navigation and sim.enemy_navigation_updates_this_tick >= ENEMY_NAVIGATION_LIMIT:
			# Never follow an obsolete route through newly built walls; wait for a fair turn instead.
			return e.nav_way if e.has("nav_way") and e.get("nav_revision", -1) == sim.world.revision and e.get("nav_outside", true) == outside and e.pos.distance_to(e.nav_way) >= 4.0 else e.pos
		sim.enemy_navigation_updates_this_tick += 1
		e.nav_way = SimWorld.navigate(sim, e.pos, goal, e.r, outside)
		e.nav_goal = goal
		e.nav_revision = sim.world.revision
		e.nav_outside = outside
		e.nav_t = 0.4 + int(e.id) % 7 * 0.03
	return e.nav_way
