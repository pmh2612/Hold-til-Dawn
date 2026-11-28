class_name SimBossSkills
extends RefCounted

# Active skill state machines and world hazards for NOX-04 Burrower, NOX-05 Earthshaker,
# NOX-06 Phantom and NOX-07 Voltspire. Match state lives on GameSim (`sim`).
const T = GameSim.T

# NOX-04 Burrower: Spine Eruption
const SPINE_WIND: float = 0.8
const SPINE_RANGE: float = 8.0 * T
const SPINE_HALF_WIDTH: float = 0.85 * T
const SPINE_SPREAD: float = 0.488692 # 28 deg
const SPINE_WAVE_TIME: float = 0.55
const SPINE_TOTAL_TIME: float = 1.0
const SPINE_DAMAGE: float = 22.0
const ROOT_TIME: float = 1.0

# NOX-05 Earthshaker: Shockwave Fissure + Tremor Ring (Donut AoE)
const QUAKE_WIND: float = 0.9
const QUAKE_STEP_DIST: float = 2.2 * T
const QUAKE_BLASTS: int = 4
const QUAKE_BLAST_RADIUS: float = 1.6 * T
const QUAKE_BLAST_GAP: float = 0.14
const QUAKE_DAMAGE: float = 26.0
const RING_WIND: float = 0.8
const RING_MIN_R: float = 2.0 * T
const RING_MAX_R: float = 7.5 * T
const RING_BAND_HALF: float = 0.85 * T
const RING_DURATION: float = 1.1
const RING_DAMAGE: float = 24.0

# NOX-06 Phantom: Mirage Cross
const MIRAGE_WIND: float = 1.0
const MIRAGE_DASH: float = 0.35
const MIRAGE_FLANK_DIST: float = 4.5 * T
const MIRAGE_DAMAGE: float = 20.0
const FROST_SLOW_TIME: float = 2.5

# NOX-07 Voltspire: Lightning Call + Arc Beam Sweep
const VOLT_CALL_COUNT: int = 4
const VOLT_CALL_GAP: float = 0.5
const VOLT_BOLT_WARN: float = 0.85
const VOLT_BOLT_FLASH: float = 0.35
const VOLT_BOLT_RADIUS: float = 1.8 * T
const VOLT_BOLT_DAMAGE: float = 22.0
const SHOCK_TIME: float = 0.5
const BEAM_WIND: float = 1.0
const BEAM_SWEEP: float = 1.2
const BEAM_RANGE: float = 9.0 * T
const BEAM_ARC: float = 1.396263 # 80 deg
const BEAM_DAMAGE: float = 25.0

static func start_burrower_skill(sim: GameSim, e, p) -> bool:
	if e.get("next_burrow_skill", "burrow") == "burrow":
		e.burrow = p.id
		e.next_burrow_skill = "spines"
		SimBosses.boss_act(sim, e, "burrow", 3.0)
		e.sig_cd = SimBosses.boss_cooldown(sim, 6.0)
		return true
	var ang: float = (Vector2(p.pos) - Vector2(e.pos)).angle()
	e.face = ang
	e.spine_ang = ang
	e.spine_origin = Vector2(e.pos)
	e.next_burrow_skill = "burrow"
	for off in [-SPINE_SPREAD, 0.0, SPINE_SPREAD]:
		var dir: Vector2 = Vector2.from_angle(ang + off)
		SimBosses.add_telegraph(sim, "line", Vector2(e.pos), SPINE_HALF_WIDTH, 0.0,
			{"end": Vector2(e.pos) + dir * SPINE_RANGE, "t": SPINE_WIND, "dur": SPINE_WIND, "fx_style": "spine"})
	SimBosses.boss_act(sim, e, "spine_wind", SPINE_WIND)
	e.sig_cd = SimBosses.boss_cooldown(sim, 6.0)
	return true

static func start_earthshaker_skill(sim: GameSim, e, p) -> bool:
	if e.get("next_quake_skill", "fissure") == "fissure":
		var ang: float = (Vector2(p.pos) - Vector2(e.pos)).angle()
		e.face = ang
		e.quake_ang = ang
		e.quake_origin = Vector2(e.pos)
		e.next_quake_skill = "ring"
		SimBosses.add_telegraph(sim, "line", Vector2(e.pos), QUAKE_BLAST_RADIUS * 0.85, 0.0,
			{"end": Vector2(e.pos) + Vector2.from_angle(ang) * (QUAKE_STEP_DIST * QUAKE_BLASTS), "t": QUAKE_WIND, "dur": QUAKE_WIND, "fx_style": "quake"})
		SimBosses.boss_act(sim, e, "quake_wind", QUAKE_WIND)
		e.sig_cd = SimBosses.boss_cooldown(sim, 5.5)
		return true
	e.quake_origin = Vector2(e.pos)
	e.next_quake_skill = "fissure"
	SimBosses.add_telegraph(sim, "circle", Vector2(e.pos), RING_MAX_R, 0.0,
		{"t": RING_WIND, "dur": RING_WIND, "fx_style": "ring", "ring_inner": RING_MIN_R})
	SimBosses.boss_act(sim, e, "ring_wind", RING_WIND)
	e.sig_cd = SimBosses.boss_cooldown(sim, 5.5)
	return true

static func start_phantom_skill(sim: GameSim, e, p) -> bool:
	if e.get("next_phantom_skill", "cloak") == "cloak":
		e.burrow = p.id
		e.next_phantom_skill = "mirage"
		spawn_phantom_cloak(sim, Vector2(e.pos))
		SimBosses.boss_act(sim, e, "cloak", 3.5)
		e.sig_cd = SimBosses.boss_cooldown(sim, 6.0)
		return false
	var focus: Vector2 = Vector2(p.pos)
	var boss_pos: Vector2 = Vector2(e.pos)
	var base_dir: Vector2 = (focus - boss_pos).normalized()
	if base_dir.length_squared() < 0.001:
		base_dir = Vector2.from_angle(float(e.face))
	e.face = base_dir.angle()
	e.next_phantom_skill = "cloak"
	var boss_end: Vector2 = IslandMap.pull_inland(focus + base_dir * (3.0 * T), e.r)
	var left_dir: Vector2 = base_dir.rotated(deg_to_rad(110.0))
	var right_dir: Vector2 = base_dir.rotated(deg_to_rad(-110.0))
	var c1_start: Vector2 = IslandMap.pull_inland(focus + left_dir * MIRAGE_FLANK_DIST, e.r)
	var c1_end: Vector2 = IslandMap.pull_inland(focus - left_dir * (3.5 * T), e.r)
	var c2_start: Vector2 = IslandMap.pull_inland(focus + right_dir * MIRAGE_FLANK_DIST, e.r)
	var c2_end: Vector2 = IslandMap.pull_inland(focus - right_dir * (3.5 * T), e.r)
	e.mirage_boss_start = boss_pos
	e.mirage_boss_end = boss_end
	e.mirage_clones = [[c1_start, c1_end], [c2_start, c2_end]]
	e.mirage_hit = []
	var fx_id: int = int(sim.next_id)
	sim.next_id += 1
	e.mirage_fx_id = fx_id
	sim.boss_fx.append({
		"id": fx_id,
		"kind": "mirage_cross",
		"boss_id": int(e.id),
		"phase": "wind",
		"t": 0.0,
		"dur": MIRAGE_WIND,
		"lines": [[boss_pos, boss_end], [c1_start, c1_end], [c2_start, c2_end]],
		"hit": []
	})
	SimAudio.emit(sim, "boss_warn", focus, -int(e.id) - 1)
	SimBosses.boss_act(sim, e, "mirage_wind", MIRAGE_WIND)
	e.sig_cd = SimBosses.boss_cooldown(sim, 6.0)
	return true

static func start_voltspire_skill(sim: GameSim, e, p) -> bool:
	if e.get("next_volt_skill", "lightning") == "lightning":
		e.face = (Vector2(p.pos) - Vector2(e.pos)).angle()
		e.next_volt_skill = "beam"
		e.volt_left = VOLT_CALL_COUNT
		e.volt_gap = 0.0
		SimAudio.emit(sim, "boss_volt_charge", e.pos, -int(e.id) - 1)
		SimBosses.boss_act(sim, e, "volt_call", VOLT_CALL_COUNT * VOLT_CALL_GAP)
		e.sig_cd = SimBosses.boss_cooldown(sim, 5.5)
		return true
	var aim: float = (Vector2(p.pos) - Vector2(e.pos)).angle()
	var sweep_sign: float = 1.0 if int(e.get("beam_dir", 1)) >= 0 else -1.0
	e.beam_dir = -int(sweep_sign)
	var start_ang: float = aim - sweep_sign * BEAM_ARC * 0.5
	e.face = start_ang
	e.beam_start_ang = start_ang
	e.beam_end_ang = aim + sweep_sign * BEAM_ARC * 0.5
	e.beam_hit = []
	e.next_volt_skill = "lightning"
	var fx_id: int = int(sim.next_id)
	sim.next_id += 1
	e.beam_fx_id = fx_id
	sim.boss_fx.append({
		"id": fx_id,
		"kind": "arc_beam",
		"boss_id": int(e.id),
		"phase": "wind",
		"t": 0.0,
		"dur": BEAM_WIND,
		"pos": Vector2(e.pos),
		"ang": start_ang,
		"end_ang": e.beam_end_ang,
		"range": BEAM_RANGE,
		"hit": []
	})
	SimAudio.emit(sim, "boss_warn", e.pos, -int(e.id) - 1)
	SimAudio.emit(sim, "boss_volt_charge", e.pos, -int(e.id) - 1)
	SimBosses.boss_act(sim, e, "beam_wind", BEAM_WIND)
	e.sig_cd = SimBosses.boss_cooldown(sim, 5.5)
	return true

static func tick_active_act(sim: GameSim, e, dt: float) -> bool:
	var act: String = Cs.s(e.act)
	if act == "volt_call":
		e.volt_gap = float(e.get("volt_gap", 0.0)) - dt
		while int(e.get("volt_left", 0)) > 0 and float(e.volt_gap) <= 0.0:
			var p = SimBosses.boss_target(sim, e)
			var spot: Vector2 = IslandMap.pull_inland(Vector2(p.pos), 8.0) if p != null else IslandMap.pull_inland(Vector2(e.pos) + Vector2.from_angle(float(e.face)) * 4.0 * T, 8.0)
			e.face = (spot - Vector2(e.pos)).angle()
			spawn_lightning_bolt(sim, e, spot)
			e.volt_left = int(e.volt_left) - 1
			e.volt_gap = float(e.volt_gap) + VOLT_CALL_GAP
		if e.act_t <= 0.0:
			SimBosses.boss_act(sim, e, "", 0.0)
			return false
		return true
	if act == "mirage_dash":
		var fx = find_fx(sim, int(e.get("mirage_fx_id", -1)))
		var progress: float = clampf(1.0 - float(e.act_t) / MIRAGE_DASH, 0.0, 1.0)
		var b_start: Vector2 = Vector2(e.get("mirage_boss_start", e.pos))
		var b_end: Vector2 = Vector2(e.get("mirage_boss_end", e.pos))
		var target_pos: Vector2 = b_start.lerp(b_end, progress)
		var prev_pos: Vector2 = Vector2(e.pos)
		e.pos = SimWorld.move_actor(sim, prev_pos, target_pos, float(e.r))
		e.face = (b_end - b_start).angle()
		if fx != null:
			fx.phase = "dash"
			fx.t = progress * MIRAGE_DASH
			fx.dur = MIRAGE_DASH
			var dmg: float = SimBosses.boss_damage(sim, MIRAGE_DAMAGE)
			var hit_list: Array = fx.hit
			for line_idx in range(fx.lines.size()):
				var pair: Array = fx.lines[line_idx]
				var ls: Vector2 = Vector2(pair[0])
				var le: Vector2 = Vector2(pair[1])
				var seg_a: Vector2 = ls.lerp(le, maxf(0.0, progress - 0.25))
				var seg_b: Vector2 = Vector2(e.pos) if line_idx == 0 else ls.lerp(le, progress)
				for q in sim.players.values():
					if int(q.state) != 0 or q.id in hit_list or (q.inside and not SimPhases.any_breach(sim)):
						continue
					if point_seg_dist(Vector2(q.pos), seg_a, seg_b) <= 0.95 * T and SimWorld.line_clear(sim, seg_b, q.pos):
						hit_list.append(q.id)
						var hp0: float = float(q.hp)
						SimPlayers.hurt(sim, q, dmg)
						if int(q.state) == 0 and float(q.hp) < hp0:
							SimPlayers.apply_slow(sim, q, FROST_SLOW_TIME)
		if e.act_t <= 0.0:
			SimBosses.boss_act(sim, e, "", 0.0)
			if fx != null:
				fx.phase = "fade"
				fx.t = 0.0
				fx.dur = 0.25
			return false
		return true
	if act == "beam_sweep":
		var fx = find_fx(sim, int(e.get("beam_fx_id", -1)))
		var progress: float = clampf(1.0 - float(e.act_t) / BEAM_SWEEP, 0.0, 1.0)
		var ang: float = lerpf(float(e.get("beam_start_ang", e.face)), float(e.get("beam_end_ang", e.face)), progress)
		e.face = ang
		var origin: Vector2 = Vector2(e.pos)
		var dir: Vector2 = Vector2.from_angle(ang)
		var tip_want: Vector2 = origin + dir * BEAM_RANGE
		var frac: float = SimWorld.obstacle_hit(sim, origin, tip_want, 4.0)
		var tip: Vector2 = origin.lerp(tip_want, frac) if frac < INF else tip_want
		var reach: float = origin.distance_to(tip)
		if fx != null:
			fx.phase = "sweep"
			fx.t = progress * BEAM_SWEEP
			fx.dur = BEAM_SWEEP
			fx.pos = origin
			fx.ang = ang
			fx.range = reach
		var hit_list: Array = e.get("beam_hit", [])
		var dmg: float = SimBosses.boss_damage(sim, BEAM_DAMAGE)
		for q in sim.players.values():
			if int(q.state) != 0 or q.id in hit_list or (q.inside and not SimPhases.any_breach(sim)):
				continue
			if point_seg_dist(Vector2(q.pos), origin, tip) <= 0.75 * T and SimWorld.line_clear(sim, origin, q.pos):
				hit_list.append(q.id)
				var hp0: float = float(q.hp)
				SimPlayers.hurt(sim, q, dmg)
				if int(q.state) == 0 and float(q.hp) < hp0:
					SimPlayers.start_hit_reaction(sim, q, "shock", Vector2.ZERO)
		e.beam_hit = hit_list
		if e.act_t <= 0.0:
			SimBosses.boss_act(sim, e, "", 0.0)
			if fx != null:
				fx.phase = "fade"
				fx.t = 0.0
				fx.dur = 0.2
			return false
		return true
	return false

static func finish_skill_act(sim: GameSim, e, act: String) -> bool:
	if act == "spine_wind":
		var origin: Vector2 = Vector2(e.get("spine_origin", e.pos))
		var ang: float = float(e.get("spine_ang", e.face))
		SimAudio.emit(sim, "boss_spine_erupt", origin, -int(e.id) - 1)
		sim.boss_fx.append({
			"kind": "spine_wave",
			"pos": origin,
			"ang": ang,
			"t": 0.0,
			"dur": SPINE_TOTAL_TIME,
			"dmg": SimBosses.boss_damage(sim, SPINE_DAMAGE),
			"hit": []
		})
		return true
	if act == "quake_wind":
		var origin: Vector2 = Vector2(e.get("quake_origin", e.pos))
		var ang: float = float(e.get("quake_ang", e.face))
		sim.boss_fx.append({
			"kind": "quake_fissure",
			"pos": origin,
			"ang": ang,
			"t": 0.0,
			"dur": QUAKE_BLASTS * QUAKE_BLAST_GAP + 0.55,
			"fired": 0,
			"dmg": SimBosses.boss_damage(sim, QUAKE_DAMAGE),
			"hit": []
		})
		return true
	if act == "ring_wind":
		var origin: Vector2 = Vector2(e.get("quake_origin", e.pos))
		SimAudio.emit(sim, "boss_tremor_ring", origin, -int(e.id) - 1)
		sim.boss_fx.append({
			"kind": "tremor_ring",
			"pos": origin,
			"t": 0.0,
			"dur": RING_DURATION,
			"dmg": SimBosses.boss_damage(sim, RING_DAMAGE),
			"hit": []
		})
		return true
	if act == "mirage_wind":
		SimAudio.emit(sim, "boss_mirage_dash", e.pos, -int(e.id) - 1)
		SimBosses.boss_act(sim, e, "mirage_dash", MIRAGE_DASH)
		return true
	if act == "beam_wind":
		SimAudio.emit(sim, "boss_arc_beam", e.pos, -int(e.id) - 1)
		SimBosses.boss_act(sim, e, "beam_sweep", BEAM_SWEEP)
		return true
	return false

static func spawn_lightning_bolt(sim: GameSim, e, spot: Vector2) -> void:
	SimAudio.emit(sim, "boss_warn", spot, -int(e.id) - 1)
	sim.boss_fx.append({
		"kind": "lightning_bolt",
		"pos": spot,
		"r": VOLT_BOLT_RADIUS,
		"t": 0.0,
		"warn": VOLT_BOLT_WARN,
		"dur": VOLT_BOLT_WARN + VOLT_BOLT_FLASH,
		"struck": false,
		"dmg": SimBosses.boss_damage(sim, VOLT_BOLT_DAMAGE)
	})

static func spawn_burrow_pop(sim: GameSim, spot: Vector2) -> void:
	sim.boss_fx.append({"kind": "burrow_pop", "pos": spot, "t": 0.0, "dur": 0.55})

static func spawn_phantom_slash(sim: GameSim, spot: Vector2, ang: float) -> void:
	sim.boss_fx.append({"kind": "phantom_slash", "pos": spot, "ang": ang, "t": 0.0, "dur": 0.35})

static func spawn_phantom_cloak(sim: GameSim, spot: Vector2) -> void:
	sim.boss_fx.append({"kind": "phantom_cloak", "pos": spot, "t": 0.0, "dur": 0.45})

static func spawn_jugg_slam(sim: GameSim, spot: Vector2) -> void:
	sim.boss_fx.append({"kind": "jugg_slam", "pos": spot, "t": 0.0, "dur": SimBosses.SLAM_IMPACT})

static func spawn_bio_barrage(sim: GameSim, spot: Vector2) -> void:
	sim.boss_fx.append({"kind": "bio_barrage", "pos": spot, "t": 0.0, "dur": 0.42})

static func tick_boss_fx(sim: GameSim, dt: float) -> void:
	if sim.boss_fx.is_empty():
		return
	for i in range(sim.boss_fx.size() - 1, -1, -1):
		var fx = sim.boss_fx[i]
		var kind: String = Cs.s(fx.kind)
		fx.t = float(fx.t) + dt
		if kind == "spine_wave":
			var reach: float = clampf(float(fx.t) / SPINE_WAVE_TIME, 0.0, 1.0) * SPINE_RANGE
			var origin: Vector2 = Vector2(fx.pos)
			var base_ang: float = float(fx.ang)
			if float(fx.t) <= SPINE_WAVE_TIME + 0.05:
				for off in [-SPINE_SPREAD, 0.0, SPINE_SPREAD]:
					var tip: Vector2 = origin + Vector2.from_angle(base_ang + off) * reach
					for q in sim.players.values():
						if int(q.state) != 0 or q.id in fx.hit or (q.inside and not SimPhases.any_breach(sim)):
							continue
						if point_seg_dist(Vector2(q.pos), origin, tip) <= SPINE_HALF_WIDTH and SimWorld.line_clear(sim, origin, q.pos):
							fx.hit.append(q.id)
							var hp0: float = float(q.hp)
							SimPlayers.hurt(sim, q, float(fx.dmg))
							if int(q.state) == 0 and float(q.hp) < hp0:
								SimPlayers.start_hit_reaction(sim, q, "root", Vector2.ZERO)
		elif kind == "quake_fissure":
			var origin: Vector2 = Vector2(fx.pos)
			var dir: Vector2 = Vector2.from_angle(float(fx.ang))
			while int(fx.fired) < QUAKE_BLASTS and float(fx.t) >= int(fx.fired) * QUAKE_BLAST_GAP:
				var idx: int = int(fx.fired)
				fx.fired = idx + 1
				var spot: Vector2 = origin + dir * ((idx + 1) * QUAKE_STEP_DIST)
				SimAudio.emit(sim, "boss_quake_fissure", spot)
				for q in sim.players.values():
					if int(q.state) != 0 or q.id in fx.hit or (q.inside and not SimPhases.any_breach(sim)):
						continue
					if Vector2(q.pos).distance_to(spot) <= QUAKE_BLAST_RADIUS and SimWorld.line_clear(sim, spot, q.pos):
						fx.hit.append(q.id)
						var hp0: float = float(q.hp)
						SimPlayers.hurt(sim, q, float(fx.dmg))
						if int(q.state) == 0 and float(q.hp) < hp0:
							SimPlayers.start_hit_reaction(sim, q, "charge", (Vector2(q.pos) - origin).normalized())
							q.hit_distance = 1.0 * T
		elif kind == "tremor_ring":
			var progress: float = clampf(float(fx.t) / float(fx.dur), 0.0, 1.0)
			var cur_r: float = lerpf(RING_MIN_R, RING_MAX_R, progress)
			var origin: Vector2 = Vector2(fx.pos)
			for q in sim.players.values():
				if int(q.state) != 0 or q.id in fx.hit or (q.inside and not SimPhases.any_breach(sim)):
					continue
				var dist: float = Vector2(q.pos).distance_to(origin)
				if absf(dist - cur_r) <= RING_BAND_HALF and dist >= RING_MIN_R - 0.25 * T and dist <= RING_MAX_R + 0.25 * T and SimWorld.line_clear(sim, origin, q.pos):
					fx.hit.append(q.id)
					SimPlayers.hurt(sim, q, float(fx.dmg))
		elif kind == "lightning_bolt":
			if not bool(fx.struck) and float(fx.t) >= float(fx.warn):
				fx.struck = true
				var spot: Vector2 = Vector2(fx.pos)
				SimAudio.emit(sim, "boss_lightning_strike", spot)
				for q in sim.players.values():
					if int(q.state) != 0 or (q.inside and not SimPhases.any_breach(sim)):
						continue
					if Vector2(q.pos).distance_to(spot) <= float(fx.r) and SimWorld.line_clear(sim, spot, q.pos):
						var hp0: float = float(q.hp)
						SimPlayers.hurt(sim, q, float(fx.dmg))
						if int(q.state) == 0 and float(q.hp) < hp0:
							SimPlayers.start_hit_reaction(sim, q, "shock", Vector2.ZERO)
		elif kind in ["mirage_cross", "arc_beam"]:
			var phase: String = Cs.s(fx.get("phase", ""))
			var boss_alive: bool = sim.enemies.any(func(x): return int(x.id) == int(fx.get("boss_id", -1)) and x.hp > 0)
			if not boss_alive and phase != "fade":
				sim.boss_fx.remove_at(i)
				continue
			if phase == "fade" and float(fx.t) >= float(fx.dur):
				sim.boss_fx.remove_at(i)
			continue
		if float(fx.t) >= float(fx.dur):
			sim.boss_fx.remove_at(i)

static func find_fx(sim: GameSim, id: int):
	if id < 0:
		return null
	for fx in sim.boss_fx:
		if int(fx.get("id", -1)) == id:
			return fx
	return null

static func point_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var u: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * u)

static func snapshot(sim: GameSim) -> Array:
	var out: Array = []
	for fx in sim.boss_fx:
		var kind: String = Cs.s(fx.kind)
		if kind == "spine_wave":
			out.append(["spine_wave", Vector2(fx.pos), float(fx.ang), float(fx.t), float(fx.dur)])
		elif kind == "quake_fissure":
			out.append(["quake_fissure", Vector2(fx.pos), float(fx.ang), float(fx.t), float(fx.dur), int(fx.fired)])
		elif kind == "tremor_ring":
			out.append(["tremor_ring", Vector2(fx.pos), float(fx.t), float(fx.dur), RING_MIN_R, RING_MAX_R])
		elif kind == "mirage_cross":
			out.append(["mirage_cross", Cs.s(fx.phase), float(fx.t), float(fx.dur), fx.lines])
		elif kind == "lightning_bolt":
			out.append(["lightning_bolt", Vector2(fx.pos), float(fx.r), float(fx.t), float(fx.warn), float(fx.dur)])
		elif kind == "arc_beam":
			out.append(["arc_beam", Cs.s(fx.phase), Vector2(fx.pos), float(fx.ang), float(fx.end_ang), float(fx.range), float(fx.t), float(fx.dur)])
		elif kind == "burrow_pop":
			out.append(["burrow_pop", Vector2(fx.pos), float(fx.t), float(fx.dur)])
		elif kind == "phantom_slash":
			out.append(["phantom_slash", Vector2(fx.pos), float(fx.ang), float(fx.t), float(fx.dur)])
		elif kind == "phantom_cloak":
			out.append(["phantom_cloak", Vector2(fx.pos), float(fx.t), float(fx.dur)])
		elif kind == "jugg_slam":
			out.append(["jugg_slam", Vector2(fx.pos), float(fx.t), float(fx.dur)])
		elif kind == "bio_barrage":
			out.append(["bio_barrage", Vector2(fx.pos), float(fx.t), float(fx.dur)])
	return out
