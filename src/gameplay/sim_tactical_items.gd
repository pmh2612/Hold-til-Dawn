class_name SimTacticalItems
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/gameplay/GameSim.TacticalItems.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
const MAX_VINE_TRAPS: int = 12

# constants shared with GameSim
const ARROW_SPEED = GameSim.ARROW_SPEED
const BOSS = GameSim.BOSS
const DOOR_HP = GameSim.DOOR_HP
const MAX_TACTICAL_AREAS = GameSim.MAX_TACTICAL_AREAS
const SPEED = GameSim.SPEED
const T = GameSim.T
const TOWER_HP = GameSim.TOWER_HP
const TOWER_LIGHT = GameSim.TOWER_LIGHT

static func is_tactical_use(id) -> bool:
	return id == "vine_trap" or id == "poison_flask" or id == "healing_flask" or id == "haste_tonic" or id == "repair_kit" or id == "explosive_arrow"

static func tactical_description(id) -> Variant:
	if id == "explosive_arrow":
		return ["Blast DMG 32 | Radius 1.5", "Bow in bag | Select ammo + LMB"]
	return ["DMG 22 | Reach 2.6", "Hits 2 targets"] if id == "long_spear" else ["DMG 30 | Stun 0.8s"] if id == "stun_maul" else ["Root: 2.5s"] if id == "vine_trap" else ["8 DMG/s | 5s"] if id == "poison_flask" else ["+8 HP/s | 5s"] if id == "healing_flask" else ["Speed +20% | 8s"] if id == "haste_tonic" else ["Hold E 2s: unlock", "Single use"] if id == "chest_key" else ["Blast DMG 32"] if id == "explosive_arrow" else ["+100 HP: door / tower"] if id == "repair_kit" else []

static func player_speed(sim: GameSim, p) -> float:
	var speed: float = float(SPEED) * (1.2 if int(p.role) == 0 else 1.0) * (1.2 if p.get("haste_until", 0.0) > float(sim.clock) else 1.0)
	if SimPlayers.is_slowed(sim, p):
		speed *= 0.7
	return speed

static func reset_tactical_items(sim: GameSim) -> void:
	sim.tactical_areas.clear()
	sim.vine_traps.clear()
	sim.next_trap_check = 0
	for p in sim.players.values():
		p.repair_kit_t = 0.0
		p.haste_until = 0.0
		SimPlayers.clear_poison(p)

static func selected_item(sim: GameSim, p) -> Variant:
	var s = p.inv[int(p.sel)]
	return "" if s == null else Cs.s(s[0])

static func use_selected_item(sim: GameSim, p, aim_point: Vector2) -> void:
	use_tactical_item(sim, p, selected_item(sim, p), aim_point)

static func use_tactical_item(sim: GameSim, p, id, aim_point: Vector2) -> bool:
	if not is_tactical_use(id) or not aim_point.is_finite() or not sim.phase in ["day", "dusk", "night"] or int(p.state) != 0 or p.inside or int(p.craft_idx) >= 0 or float(p.channel) > 0 or SimInventory.count(sim, p, id) <= 0 or p.get("item_cd", 0.0) > float(sim.clock) or p.get("repair_kit_t", 0.0) > 0:
		return false
	var pos: Vector2 = Vector2(p.pos)
	var at: Vector2 = pos + (aim_point - pos).limit_length((2.0 if id == "vine_trap" else 5.0) * T)
	var now: float = float(sim.clock)
	if id == "haste_tonic":
		if p.get("haste_until", 0.0) > now:
			SimPlayers.note(sim, p, "Already active")
			return false
		p.haste_until = now + 8.0
	elif id == "repair_kit":
		return begin_field_repair(sim, p, aim_point)
	elif id == "explosive_arrow":
		if SimInventory.count(sim, p, "bow") + SimInventory.count(sim, p, "starter_bow") == 0:
			SimPlayers.note(sim, p, "Needs a bow")
			return false
		if float(p.atk_cd) > 0:
			return false
		var dir: Vector2 = (aim_point - pos).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.from_angle(float(p.aim))
		sim.arrows.append({"pos": pos + dir * 0.4 * T, "vel": dir * ARROW_SPEED * T, "dmg": 32.0, "left": 7.6 * T, "owner": p.id, "explosive": true})
		p.aim = dir.angle()
		SimPlayers.begin_attack_pose(p, "explosive_arrow", GameSim.WEAPON_SWING_TIME)
		# Special arrows keep their existing role-neutral cadence, now 50% faster too.
		p.atk_cd = SimPlayers.attack_interval("bow", -1)
	else:
		if not SimWorld.line_clear(sim, pos, at) or not IslandMap.on_land(at, 8.0) or id == "vine_trap" and Vector2(sim.world.resolve_fast(at, 8.0)).distance_to(at) > 1.0:
			SimPlayers.note(sim, p, "Blocked")
			return false
		if id == "vine_trap":
			var own: int = 0
			for trap in sim.vine_traps:
				if trap.owner == p.id:
					own += 1
			if own >= 3 or sim.vine_traps.size() >= MAX_VINE_TRAPS:
				SimPlayers.note(sim, p, "Trap limit")
				return false
			sim.vine_traps.append({"pos": at, "owner": p.id, "until": now + 120.0})
		else:
			if sim.tactical_areas.size() >= MAX_TACTICAL_AREAS:
				SimPlayers.note(sim, p, "Wait")
				return false
			sim.tactical_areas.append({"pos": at, "owner": p.id, "kind": "poison" if id == "poison_flask" else "heal", "until": now + 5.0, "next": now + 0.5})
	SimInventory.take(sim, p, id, 1)
	if id == "explosive_arrow":
		SimAudio.emit(sim, "bow", pos, p.id)
	elif id in ["poison_flask", "healing_flask"]:
		SimAudio.emit(sim, "flask", pos, p.id)
	p.item_cd = now + 0.6
	# the throw / drink plays as a short swing of the character
	if id != "explosive_arrow":
		SimPlayers.begin_attack_pose(p, Cs.s(id), 0.25)
	SimPlayers.note(sim, p, "Used " + SimInventory.item_name(id))
	return true

static func tick_tactical_items(sim: GameSim) -> void:
	var now: float = float(sim.clock)
	if now >= sim.next_trap_check:
		sim.next_trap_check = now + 0.25
		for i in range(sim.vine_traps.size() - 1, -1, -1):
			var trap = sim.vine_traps[i]
			if float(trap.until) <= now:
				sim.vine_traps.remove_at(i)
				continue
			for e in sim.enemies:
				if e.hp <= 0 or int(e.type) == BOSS or not SimBosses.hittable(sim, e) or Vector2(e.pos).distance_to(Vector2(trap.pos)) > float(e.r) + 16.0:
					continue
				e.stun_until = maxf(e.get("stun_until", 0.0), now + 2.5)
				sim.vine_traps.remove_at(i)
				break
	# Each actor receives a given area effect once per half-second, even where areas overlap.
	if sim.tactical_areas.size() == 0:
		return
	sim.poisoned.clear()
	sim.healed.clear()
	for i in range(sim.tactical_areas.size() - 1, -1, -1):
		var area = sim.tactical_areas[i]
		var until: float = float(area.until)
		var next: float = float(area.next)
		if now >= next and next <= until and now <= until + 0.01:
			area.next = now + 0.5
			var owner = sim.players.get(area.owner)
			if Cs.s(area.kind) == "poison" and owner != null:
				for e in sim.enemies:
					if e.hp > 0 and SimBosses.hittable(sim, e) and e.get("area_poison_at", 0.0) <= now and Vector2(e.pos).distance_to(Vector2(area.pos)) <= 1.8 * T + float(e.r) and SimWorld.line_clear(sim, area.pos, e.pos) and Cs.set_add(sim.poisoned, int(e.id)):
						e.area_poison_at = now + 0.5
						SimPlayers.hit(sim, e, 4.0, owner)
			elif Cs.s(area.kind) == "heal":
				for q in sim.players.values():
					if int(q.state) == 0 and not SimPlayers.is_poisoned(sim, q) and q.get("area_heal_at", 0.0) <= now and Vector2(q.pos).distance_to(Vector2(area.pos)) <= 1.8 * T and SimWorld.line_clear(sim, area.pos, q.pos) and Cs.set_add(sim.healed, int(q.id)):
						q.area_heal_at = now + 0.5
						q.hp = minf(float(q.maxhp), float(q.hp) + 4.0)
		if now >= until:
			sim.tactical_areas.remove_at(i)
	# Hit() owns drops, boss progression, threat and player statistics.
	sim.enemies = sim.enemies.filter(func(e): return e.hp > 0)

static func explode_arrow(sim: GameSim, arrow) -> void:
	var at: Vector2 = Vector2(arrow.pos)
	var owner = sim.players.get(arrow.owner)
	if owner != null:
		for e in sim.enemies:
			if e.hp > 0 and SimBosses.hittable(sim, e) and Vector2(e.pos).distance_to(at) <= 1.5 * T + float(e.r) and SimWorld.line_clear(sim, at, e.pos):
				SimPlayers.hit(sim, e, 32.0, owner)
	if sim.tactical_areas.size() < MAX_TACTICAL_AREAS:
		sim.tactical_areas.append({"pos": at, "owner": arrow.owner, "kind": "blast", "until": float(sim.clock) + 0.3, "next": INF})

static func tactical_snapshot(sim: GameSim) -> Variant:
	var out = []
	# [kind, pos, seconds left, owner]
	for a in sim.tactical_areas:
		out.append([a.kind, a.pos, maxf(0.0, float(a.until) - float(sim.clock)), a.owner])
	for a in sim.vine_traps:
		out.append(["trap", a.pos, maxf(0.0, float(a.until) - float(sim.clock)), a.owner])
	return out

static func attack_long_spear(sim: GameSim, p) -> void:
	var pos: Vector2 = Vector2(p.pos)
	var dir: Vector2 = Vector2.from_angle(float(p.aim))
	var hits = []
	for e in sim.enemies:
		var delta: Vector2 = Vector2(e.pos) - pos
		var along: float = delta.dot(dir)
		var side: float = absf(delta.cross(dir))
		if SimBosses.hittable(sim, e) and along >= 0 and along <= 2.6 * T + float(e.r) and side <= 10.0 + float(e.r) and SimWorld.line_clear(sim, pos, e.pos):
			hits.append([along, e])
	Cs.sort_cmp(hits, func(a, b): return Cs.compare(a[0], b[0]))
	for i in range(mini(2, hits.size())):
		SimPlayers.hit(sim, hits[i][1], 22.0, p)
	p.atk_cd = SimPlayers.attack_interval("long_spear", int(p.role))
	SimPlayers.begin_attack_pose(p, "long_spear", GameSim.WEAPON_SWING_TIME)
	SimAudio.emit(sim, "attack_long_spear", pos, p.id)
	sim.enemies = sim.enemies.filter(func(e): return e.hp > 0)

static func begin_field_repair(sim: GameSim, p, aim: Vector2) -> bool:
	if int(p.role) != 2 or SimWorld.inside_base(p.pos):
		SimPlayers.note(sim, p, "Use outside base")
		return false
	var target = null
	var kind = ""
	var door: int = -1
	var best: float = T
	for i in range(3):
		var at: Vector2 = Vector2(GameSim.DOOR_POS[i])
		var d: float = at.distance_to(aim)
		if d < best and field_door_cap(sim, i) > float(sim.doors[i]):
			best = d
			door = i
			kind = "door"
	for w in sim.built_walls:
		if Vector2(w.pos).distance_to(aim) < best and float(w.hp) < float(w.maxhp):
			target = w
			best = Vector2(w.pos).distance_to(aim)
			kind = "wall"
	for w in sim.towers:
		if w != null and Vector2(w.pos).distance_to(aim) < best and field_tower_cap(sim, w) > float(w.hp):
			target = w
			best = Vector2(w.pos).distance_to(aim)
			kind = "tower"
	var spot: Vector2 = Vector2(GameSim.DOOR_POS[door]) if kind == "door" else Vector2.INF if target == null else Vector2(target.pos)
	var approach: Vector2 = spot.move_toward(Vector2(p.pos), T) if spot.is_finite() else spot
	if kind == "" or spot.distance_to(Vector2(p.pos)) > 3.0 * T or not SimWorld.line_clear(sim, p.pos, approach):
		SimPlayers.note(sim, p, "Nothing to repair")
		return false
	p.repair_kit_kind = kind
	p.repair_kit_door = door
	p.repair_kit_target = target
	p.repair_kit_t = 3.0
	p.repair_kit_pos = p.pos
	p.repair_kit_spot = spot
	p.atk = false
	SimPlayers.note(sim, p, "Repairing...")
	return true

static func field_door_cap(sim: GameSim, i: int) -> float:
	return 0.0 if float(sim.door_pause[i]) > 0 or sim.broken[i] and SimPhases.enemy_inside(sim) else float(DOOR_HP) * (0.3 if sim.broken[i] else 1.0)

static func field_tower_cap(sim: GameSim, w) -> float:
	return 0.0 if float(w.pause) > 0 or w.wrecked and SimEnemies.enemy_near(sim, w.pos, TOWER_LIGHT) else float(TOWER_HP) * (0.3 if w.wrecked else 1.0)

static func tick_field_repair(sim: GameSim, p, dt: float) -> bool:
	var left: float = p.get("repair_kit_t", 0.0)
	if left <= 0:
		return false
	if int(p.state) != 0 or p.atk or p.inside or Vector2(p.pos).distance_to(Vector2(p.repair_kit_pos)) > 4.0 or SimInventory.count(sim, p, "repair_kit") == 0:
		p.repair_kit_t = 0.0
		SimPlayers.note(sim, p, "Repair cancelled")
		return false
	p.activity = "repair"
	p.activity_target = p.repair_kit_spot
	p.repair_kit_t = maxf(0.0, left - dt)
	if float(p.repair_kit_t) > 0:
		return true
	var kind = Cs.s(p.repair_kit_kind)
	var target = p.repair_kit_target
	var before: float = 0.0
	var after: float = 0.0
	if kind == "door":
		var i: int = int(p.repair_kit_door)
		before = float(sim.doors[i])
		after = minf(field_door_cap(sim, i), before + 100.0)
		if after > before:
			sim.doors[i] = after
	elif target != null and (kind == "wall" and target in sim.built_walls or kind == "tower" and target in sim.towers):
		before = float(target.hp)
		after = minf(float(target.maxhp) if kind == "wall" else field_tower_cap(sim, target), before + 100.0)
		if after > before:
			target.hp = after
	if after > before:
		SimInventory.take(sim, p, "repair_kit", 1)
		SimPlayers.note(sim, p, "+" + Cs.s(Cs.round_even(after - before)) + " HP")
	else:
		SimPlayers.note(sim, p, "Nothing to repair")
	return true
