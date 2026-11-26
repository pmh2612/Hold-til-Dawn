class_name SimPlayers
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/gameplay/GameSim.Players.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
static var ROLE_HP = [90.0, 100.0, 110.0]
# seconds of holding E over a dead teammate to use a Revival kit on them
const REVIVE_KIT_TIME: float = 3.0

# constants shared with GameSim
const ARROW_SPEED = GameSim.ARROW_SPEED
const BASE_HP = GameSim.BASE_HP
const BOSS = GameSim.BOSS
const CRAFT_TIME = GameSim.CRAFT_TIME
const DOOR_HP = GameSim.DOOR_HP
const GRUNT = GameSim.GRUNT
const ROAM_CHECK = GameSim.ROAM_CHECK
const SPEED = GameSim.SPEED
const T = GameSim.T
const TOWER_HP = GameSim.TOWER_HP
const TOWER_LIGHT = GameSim.TOWER_LIGHT

# In the base (by day, or as the Engineer who went in at night) and standing at the furniture.
static func in_base_to_work(sim: GameSim, p) -> bool:
	return sim.phase in ["day", "dusk"] and SimWorld.inside_base(p.pos) or sim.phase == "night" and p.inside

static func at_bench(sim: GameSim, p) -> bool:
	return in_base_to_work(sim, p) and SimWorld.near_bench(Vector2(p.pos))

# Shared by the simulation and workbench UI; -1 means every role may craft it.
static func craft_role(recipe) -> int:
	return 1 if recipe[3] == "healing_flask" else 2 if recipe[5] else -1

# Checks every rule of MEC-10; Note() tells the player why not.
static func can_craft(sim: GameSim, p, idx: int, tell: bool = true) -> bool:
	if idx < 0 or idx >= GameSim.RECIPES.size():
		return false
	var r = GameSim.RECIPES[idx]
	var role: int = craft_role(r)
	var why = ""
	if p.state != 0 or not at_bench(sim, p):
		why = "Move to workbench"
	elif sim.radio_builder == int(p.id):
		why = "Radio repair in progress"
	elif r[2] > sim.unlock:
		why = "%s is locked" % [r[0]]
	elif role >= 0 and int(p.role) != role:
		why = "%s only" % GameSim.ROLES[role]
	elif r[3] == "base" and sim.phase == "night":
		why = "Day only"
	elif r[3] == "base" and sim.base_hp >= BASE_HP:
		why = "Generator full"
	elif SimInventory.kind_of(r[3]) == "armour" and GameSim.ARMOUR_ITEMS.find(r[3]) <= int(p.armour):
		why = "Already worn"
	else:
		for res in r[1]:
			if SimSupplies.craft_have(sim, p, Cs.s(res)) < r[1][res]:
				why = "Need %s" % [SimInventory.item_name(res)]
				break
	if why != "" and tell:
		note(sim, p, why)
	return why == ""

static func craft_duration(sim: GameSim, idx: int) -> Variant:
	var r = GameSim.RECIPES[idx]
	return r[4] / 20.0 if r[3] == "base" else CRAFT_TIME

static func player_craft_duration(sim: GameSim, _p, idx: int) -> float:
	return float(craft_duration(sim, idx))

# Starts the craft channel; the cost is paid when it completes (TickCraft).
static func craft(sim: GameSim, p, idx) -> void:
	if p.craft_idx >= 0 or not can_craft(sim, p, int(idx), false):
		return
	p.craft_idx = int(idx)
	p.craft_t = 0.0

static func tick_craft(sim: GameSim, p, dt) -> void:
	if p.craft_idx < 0:
		return
	if p.state != 0 or not at_bench(sim, p):
		p.craft_idx = -1
		return
	p.activity = "craft"
	p.craft_t += dt
	if p.craft_t < player_craft_duration(sim, p, int(p.craft_idx)):
		return
	var idx: int = int(p.craft_idx)
	p.craft_idx = -1
	p.craft_t = 0.0
	if can_craft(sim, p, idx, false):
		finish_craft(sim, p, idx)

static func finish_craft(sim: GameSim, p, idx: int) -> void:
	var r = GameSim.RECIPES[idx]
	for res in r[1]:
		SimInventory.take(sim, p, res, r[1][res])
	if r[3] == "base":
		sim.base_hp = minf(float(BASE_HP), float(sim.base_hp) + int(r[4]))
	else:
		SimInventory.add_item(sim, p, r[3], r[4])
	note(sim, p, "Crafted " + Cs.s(r[0]))
	SimAudio.emit(sim, "craft_done", p.pos, p.id)

# --- players ------------------------------------------------------------
static func reset_player(sim: GameSim, p) -> void:
	SimSupplies.cancel_chest_unlock(sim, p)
	p.open_chest = -1
	p.chest_use_seq = 0
	p.hp = ROLE_HP[p.role]
	p.maxhp = p.hp
	p.haste_until = 0.0
	p.item_cd = 0.0
	p.repair_kit_t = 0.0
	p.area_heal_at = 0.0
	p.tactical_think_at = 0.0
	p.next_trap_at = 0.0
	# 0 standing, 1 downed, 2 dead
	p.state = 0
	p.bleed = 0.0
	SimInventory.give_starting_kit(sim, p)
	p.weapon = SimInventory.weapon_of(sim, p)
	p.armour = 0
	p.craft_idx = -1
	p.craft_t = 0.0
	p.flasks = 3 if p.role == 1 else 0
	p.invuln = 0.0
	p.atk_cd = 0.0
	p.swing = 0.0
	p.channel = 0.0
	p.repair_kit_t = 0.0
	p.tower_build_t = 0.0
	p.revive_p = 0.0
	p.revive_target = null
	p.gather_acc = 0.0
	p.repair_acc = 0.0
	p.aim = 0.0
	p.atk = false
	p.inter = false
	# result screen stats (section 2.5): kills, damage dealt, revives, damage taken
	p.kills = 0
	p.dmg = 0.0
	p.revives = 0
	p.taken = 0.0
	# Engineer inside the base at night (MEC-15)
	p.inside = false
	p.entry = 0.0
	p.entry_pos = Vector2.ZERO
	p.ent = false
	p.gather_pos = Vector2.ZERO
	p.roam_t = ROAM_CHECK
	p.note = ""
	p.note_t = 0.0
	p.bot_cd = 0.0
	p.activity = "idle"
	p.activity_target = Vector2.ZERO
	p.move_credit = SPEED * 0.1
	p.input_sequence = 0
	# index of the resource node a bot is gathering
	p.bot_node = -1
	# spawn beside the lighthouse, left or right (behind it the sprite hides you), in front of the workbench
	# and the storage chest by the north wall
	var side: float = -1.0 if sim.rng.randf() < 0.5 else 1.0
	SimPhases.teleport(sim, p, sim.world.resolve(Vector2(side * sim.rng.randf_range(2.5, 4.0), sim.rng.randf_range(-0.6, 1.5)) * T, 0.3 * T))

# Resolve before any bleed timer ticks, independent of player iteration order.
static func revive_target_for(sim: GameSim, p) -> Variant:
	if p.state != 0 or not p.inter or p.inside or p.atk or sim.radio_builder == int(p.id) or p.craft_idx >= 0 or p.channel > 0 or p.get("tower_build_t", 0.0) > 0 or p.get("repair_kit_t", 0.0) > 0 or p.get("unlock_chest", -1) >= 0:
		return null
	for state in [1, 2]:
		if state == 2 and SimInventory.count(sim, p, "revive") == 0:
			continue
		for q in sim.players.values():
			if q.id != p.id and q.state == state and q.pos.distance_to(p.pos) <= 1.5 * T and SimWorld.line_clear(sim, p.pos, q.pos):
				return q
	return null

static func tick_players(sim: GameSim, dt) -> void:
	SimSupplies.tick_chest_access(sim)
	var being_revived = {}
	for helper in sim.players.values():
		var target = revive_target_for(sim, helper)
		var target_id = null if target == null else target.id
		if helper.get("revive_target") != target_id:
			helper.revive_p = 0.0
		helper.revive_target = target_id
		if target != null and target.state == 1:
			being_revived[target.id] = true
	if sim.radio_builder != null:
		var builder = sim.players.get(sim.radio_builder, null)
		if builder == null or builder.state != 0 or builder.atk or builder.channel > 0 or builder.craft_idx >= 0 or builder.get("tower_build_t", 0.0) > 0 or builder.get("repair_kit_t", 0.0) > 0 or not SimSupplies.at_radio(sim, builder) or sim.phase != "day" or Vector2(builder.pos).distance_squared_to(sim.radio_build_pos) > 16 or float(builder.taken) != sim.radio_build_damage:
			SimSupplies.cancel_radio_build(sim)
			if builder != null:
				builder.inter = false
	for p in sim.players.values():
		p.activity = "idle"
		p.move_credit = minf(SimTacticalItems.player_speed(sim, p) * 0.2, p.move_credit + SimTacticalItems.player_speed(sim, p) * dt)
		p.invuln -= dt
		p.atk_cd -= dt
		p.swing -= dt
		p.note_t -= dt
		p.weapon = SimInventory.weapon_of(sim, p)
		SimInventory.wear_armour(sim, p)
		if p.state == 1:
			if not being_revived.has(p.id):
				p.bleed -= dt
			if p.bleed <= 0:
				p.state = 2
				say(sim, "%s died" % [p.name])
		if p.state != 0:
			SimConstruction.tick_tower_construction(sim, p, 0)
			continue
		if sim.radio_builder == int(p.id):
			SimSupplies.try_build_radio(sim, p, float(dt))
			continue
		if p.channel > 0:
			p.activity = "heal"
			if p.atk:
				# attacking cancels the bandage and keeps it
				p.channel = 0.0
			else:
				p.channel -= dt
				if p.channel <= 0 and SimInventory.take(sim, p, "bandage", 1):
					p.hp = minf(p.maxhp, p.hp + 30.0 * (1.5 if p.role == 1 else 1.0))
		if SimConstruction.tick_tower_construction(sim, p, float(dt)):
			continue
		if SimTacticalItems.tick_field_repair(sim, p, float(dt)):
			continue
		tick_entry(sim, p, dt)
		tick_craft(sim, p, dt)
		if p.inside:
			p.revive_p = 0.0
			continue
		if p.atk and p.atk_cd <= 0:
			attack(sim, p)
		if p.inter:
			interact(sim, p, dt)
		else:
			p.revive_p = 0.0
			p.gather_acc = 0.0

static func tick_entry(sim: GameSim, p, dt) -> void:
	var door = -1
	if p.ent and p.role == 2 and sim.phase == "night":
		for i in 3:
			if sim.doors[i] > 0 and p.pos.distance_to(GameSim.DOOR_POS[i]) <= 2.0 * T:
				door = i
	if door < 0 or p.entry > 0 and p.pos.distance_to(p.entry_pos) > 4.0:
		p.entry = 0.0
		return
	if p.entry == 0.0:
		p.entry_pos = p.pos
	p.entry += dt
	if p.entry < 2.0:
		return
	p.entry = 0.0
	p.inside = not p.inside
	SimAudio.emit(sim, "entry", GameSim.DOOR_POS[door], p.id)
	if p.inside:
		SimPhases.teleport(sim, p, GameSim.DOOR_POS[door] - GameSim.DOOR_DIR[door] * 1.2 * T)
		note(sim, p, "Inside the base")
	else:
		SimPhases.teleport(sim, p, GameSim.DOOR_POS[door] + GameSim.DOOR_DIR[door] * T)
		p.invuln = 0.5

# MEC-02 / MEC-03: a melee swing hits every enemy in the 90-degree arc once; a bow fires one arrow.
static func attack(sim: GameSim, p) -> void:
	var selected = SimTacticalItems.selected_item(sim, p)
	if SimTacticalItems.is_tactical_use(selected):
		return
	var w = p.weapon
	if w == "long_spear":
		SimTacticalItems.attack_long_spear(sim, p)
		return
	var st = GameSim.WEAPON_STATS[w]
	if st[4] and not SimInventory.take(sim, p, "arrow", 1):
		note(sim, p, "No arrows")
		SimAudio.emit(sim, "empty_bow", p.pos, p.id)
		p.atk_cd = 0.5
		return
	# BAL-07: the Scout attacks 1.25x faster
	p.atk_cd = 1.0 / (st[1] * (1.25 if p.role == 0 else 1.0))
	p.swing = 0.25
	SimAudio.emit(sim, "bow" if st[3] else "attack_" + str(w), p.pos, p.id)
	var dir = Vector2.from_angle(p.aim)
	if st[3]:
		sim.arrows.append({"pos": p.pos + dir * (0.4 * T), "vel": dir * ARROW_SPEED * T, "dmg": st[0], "left": st[2] * T - 0.4 * T, "owner": p.id})
		return
	var reach: float = float(st[2] * T)
	for e in sim.enemies:
		var d: Vector2 = Vector2(e.pos - p.pos)
		if d.length() <= reach + e.r and (d.length() < 0.5 * T or dir.dot(d.normalized()) >= cos(PI / 4)) and SimWorld.line_clear(sim, p.pos, e.pos):
			hit(sim, e, st[0], p)
			if w == "stun_maul":
				if e.type == BOSS:
					e.slow_until = float(sim.clock) + 1.0
				else:
					e.stun_until = float(sim.clock) + 0.8
	sim.enemies = sim.enemies.filter(func(e): return e.hp > 0)

# Arrows fly toward the cursor, hit the first enemy on their way and stop at walls or at their range.
static func tick_arrows(sim: GameSim, dt) -> void:
	for a in sim.arrows:
		var start: Vector2 = Vector2(a.pos)
		var step: float = minf(a.vel.length() * dt, a.left)
		var end_: Vector2 = start + a.vel.normalized() * step
		var first = SimWorld.obstacle_hit(sim, start, end_, 2.0)
		var victim = null
		for e in sim.enemies:
			if not SimBosses.hittable(sim, e):
				continue
			var h = WorldGeometry.circle_hit(start, end_, e.pos, e.r + 2.0)
			if h < first:
				first = h
				victim = e
		a.left -= step
		a.pos = start.lerp(end_, first) if first < INF else end_
		if first == INF and a.left <= 0 and a.get("explosive", false):
			SimTacticalItems.explode_arrow(sim, a)
		if first < INF:
			a.left = 0.0
			SimAudio.emit(sim, "arrow_hit", a.pos, a.owner)
			var owner = sim.players.get(a.owner)
			if a.get("explosive", false):
				SimTacticalItems.explode_arrow(sim, a)
			elif victim != null and owner != null:
				hit(sim, victim, a.dmg, owner)
	sim.arrows = sim.arrows.filter(func(a): return a.left > 0)
	sim.enemies = sim.enemies.filter(func(e): return e.hp > 0)

# FML-09: threat is the damage a player dealt to this enemy in the last 5 s.
static func threat(sim: GameSim, e, pid) -> float:
	var sum: float = 0.0
	for h in e.hits:
		if h[1] == pid and sim.clock - h[0] <= 5.0:
			sum += float(h[2])
	return sum

# Chase the top threat; switch only when a newcomer's threat beats the current target's by 20%.
static func retarget(sim: GameSim, e) -> void:
	e.hits = e.hits.filter(func(h): return sim.clock - h[0] <= 5.0)
	var cur: float = threat(sim, e, e.target)
	for h in e.hits:
		var pid = h[1]
		var q = sim.players.get(pid)
		if q != null and q.state == 0 and threat(sim, e, pid) > 1.2 * cur:
			e.target = pid
			cur = threat(sim, e, pid)

static func hit(sim: GameSim, e, dmg, p) -> void:
	if e.hp <= 0 or not SimBosses.hittable(sim, e):
		return
	dmg = SimBosses.boss_damage_taken(sim, e, dmg, p.pos)
	e.hp -= dmg
	e.nodmg = 0.0
	p.dmg += dmg
	SimBosses.boss_on_hit(sim, e)
	# Grunts and bosses retaliate unless locked on a door or tower; Wreckers never do (AGT-01..03).
	if (e.type == GRUNT or e.type == BOSS) and (e.state <= 1 or e.state == 4):
		e.hits.append([sim.clock, p.id, dmg])
		if e.state == 0 or e.state == 4:
			# BAL-35: a boss ignores new threat for 10 s after its leash broke
			if e.get("calm", 0.0) <= 0:
				e.state = 1
				e.anchor = e.pos
				e.target = p.id
		else:
			retarget(sim, e)
	if e.hp <= 0:
		SimDrops.drop(sim, e)
		p.kills += 1
		if e.type == BOSS:
			sim.boss_dead = true

static func interact(sim: GameSim, p, dt) -> void:
	var revive_target = revive_target_for(sim, p)
	for q in sim.players.values():
		if q == revive_target and q.state == 1:
			p.activity = "revive"
			p.activity_target = q.pos
			p.revive_p += dt / (10.0 if p.role == 1 else 20.0)
			if p.revive_p >= 1.0:
				p.revive_p = 0.0
				q.state = 0
				q.hp = 0.3 * q.maxhp
				q.invuln = 1.0
				p.revives += 1
				say(sim, "%s revived %s" % [p.name, q.name])
			return
	# a Revival kit is carried to a dead teammate's body and used there: hold E for REVIVE_KIT_TIME
	if SimInventory.count(sim, p, "revive") > 0:
		for q in sim.players.values():
			if q == revive_target and q.state == 2:
				p.activity = "revive"
				p.activity_target = q.pos
				p.revive_p += dt / REVIVE_KIT_TIME
				if p.revive_p >= 1.0 and SimInventory.take(sim, p, "revive", 1):
					# MEC-07: back where they fell, with 50% HP
					p.revive_p = 0.0
					q.state = 0
					q.hp = q.maxhp * 0.5
					q.invuln = 1.0
					p.revives += 1
					say(sim, "%s is back" % [q.name])
				return
	p.revive_p = 0.0
	if SimInventory.pick_up(sim, p):
		p.inter = false
		return
	if SimSupplies.try_loot_chest(sim, p, float(dt)):
		return
	# repairs need the Engineer's hammer (ITM-04) and wood (BAL-23)
	if p.role == 2 and not SimWorld.inside_base(p.pos) and SimInventory.count(sim, p, "hammer") > 0:
		for i in 3:
			var dp: Vector2 = Vector2(GameSim.DOOR_POS[i])
			if p.pos.distance_to(dp) <= 1.5 * T:
				var cap: float = float(DOOR_HP * 0.3 if sim.broken[i] else DOOR_HP)
				if sim.broken[i] and SimPhases.enemy_inside(sim) or sim.door_pause[i] > 0 or sim.doors[i] >= cap or SimInventory.count(sim, p, "wood") <= 0:
					return
				p.activity = "repair"
				p.activity_target = dp
				var amt = 15.0 * dt
				sim.doors[i] = minf(cap, sim.doors[i] + amt)
				p.repair_acc += amt
				if p.repair_acc >= 10.0:
					p.repair_acc -= 10.0
					SimInventory.take(sim, p, "wood", 1)
				return
		for tw in sim.towers:
			if tw != null and p.pos.distance_to(tw.pos) <= 1.5 * T:
				var tcap: float = float(TOWER_HP * 0.3 if tw.wrecked else TOWER_HP)
				if tw.wrecked and SimEnemies.enemy_near(sim, tw.pos, TOWER_LIGHT) or tw.pause > 0 or tw.hp >= tcap or SimInventory.count(sim, p, "wood") <= 0:
					return
				p.activity = "repair"
				p.activity_target = tw.pos
				var tamt = 15.0 * dt
				tw.hp = minf(tcap, tw.hp + tamt)
				p.repair_acc += tamt
				if p.repair_acc >= 10.0:
					p.repair_acc -= 10.0
					SimInventory.take(sim, p, "wood", 1)
				return
	for nd in sim.nodes:
		if nd.amount > 0 and nd.pos.distance_to(p.pos) <= 1.5 * T and SimWorld.line_clear(sim, p.pos, nd.pos, nd.pos):
			if SimInventory.room(sim, p, GameSim.RES[nd.type]) <= 0:
				note(sim, p, "Bag full")
				p.gather_acc = 0.0
				return
			p.activity = "gather"
			p.activity_target = nd.pos
			if p.gather_acc > 0 and p.pos.distance_to(p.gather_pos) > 4.0:
				p.gather_acc = 0.0
			if p.gather_acc == 0.0:
				p.gather_pos = p.pos
			p.gather_acc += 0.35 * dt
			if p.gather_acc >= 1.0:
				p.gather_acc = 0.0
				nd.amount -= 1
				SimInventory.add_to(p.inv, GameSim.RES[nd.type], 1)
			return
	# nothing in reach
	p.gather_acc = 0.0

static func hurt(sim: GameSim, p, dmg) -> void:
	# An Engineer inside the base can be hit too, but only enemies that broke in can reach them.
	if p.state != 0 or p.invuln > 0:
		return
	p.entry = 0.0
	# FML-06: armour reduces the hit, never below 1 damage; BAL-13: 1 s invulnerability
	var taken: float = maxf(1.0, roundf(dmg * (1.0 - minf(0.6, GameSim.ARMOUR[p.armour]))))
	p.hp -= taken
	p.taken += taken
	p.invuln = 1.0
	p.channel = 0.0
	p.repair_kit_t = 0.0
	p.tower_build_t = 0.0
	p.revive_p = 0.0
	p.revive_target = null
	p.gather_acc = 0.0
	p.craft_idx = -1
	if sim.radio_builder == int(p.id):
		SimSupplies.cancel_radio_build(sim)
	SimSupplies.cancel_chest_unlock(sim, p)
	if p.hp <= 0:
		p.hp = 0.0
		p.state = 1
		p.bleed = 30.0
		say(sim, "%s is down" % [p.name])

static func flask(sim: GameSim, p, aim_point) -> void:
	if p.role != 1 or p.flasks <= 0 or p.state != 0:
		return
	var target = p
	for q in sim.players.values():
		if q.state == 0 and q.id != p.id and q.pos.distance_to(p.pos) <= 3 * T and q.pos.distance_to(aim_point) < T:
			target = q
	target.hp = minf(target.maxhp, target.hp + 40.0)
	p.flasks -= 1

static func say(sim: GameSim, s) -> void:
	sim.msg = s
	sim.msg_t = 6.0

static func note(sim: GameSim, p, s) -> void:
	p.note = s
	p.note_t = 3.0
