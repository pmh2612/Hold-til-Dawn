class_name Bots
extends RefCounted

# ---- src/ai/Bots.cs
# Bot teammates for demos and solo playtests (not in the GDD). They run on the server inside GameSim and
# follow the same rules as people: a bot only sets what a player's input sets (where it stands, aim,
# attack, hold E) or calls the same actions (bandage, flask, craft). No planning, just priorities:
#   dodge a boss slam > revive a downed teammate > heal (Healer) > fight > repair a door (Engineer)
#   > by day gather, then craft at the workbench near dusk; at dusk and night hold the attacked door.
# Bots share obstacle collision and navigation with the authoritative simulation.
const T = GameSim.T
static var GATHER = [0, 2, 1]
const HOME_AT = 40.0
const SIGHT_DAY = 6.0 * T
const LEASH = 8.0 * T
const FLASK_AT = 0.55
const BANDAGE_AT = 0.4
const BODY = 0.4 * T
# where bots stand to craft: in front of the workbench (GameSim.WORKBENCH_POS, -3.2, -2.0), within its reach
static var BENCH_SPOTS = [Vector2(-3.2, -0.8), Vector2(-2.1, -0.9), Vector2(-4.3, -0.9), Vector2(-2.4, -0.3)]

static func add(sim) -> void:
	# A bot takes the role the team lacks most: an Engineer first if there is none, then Healer, Scout.
	if sim.phase != "lobby" or sim.players.size() >= 5:
		return
	var count = [0, 0, 0]
	for p in sim.players.values():
		count[p.role] += 1
	var role = 2
	if count[2] > 0:
		role = 1 if count[1] <= count[0] else 0
	var id = -1
	while sim.players.has(id):
		id -= 1
	var pname = "Bot " + Cs.s(GameSim.ROLES[role])
	for p in sim.players.values():
		if p.name == pname:
			pname += " %d" % [-id]
			break
	sim.add_player(id, pname, role)
	if sim.players.has(id):
		sim.players[id].bot = true

static func remove(sim) -> void:
	if sim.phase != "lobby":
		return
	for i in range(sim.order.size() - 1, -1, -1):
		var id: int = int(sim.order[i])
		if sim.players[id].bot:
			sim.remove_player(id)
			return

static func tick(sim, dt) -> void:
	var playing: bool = sim.phase in ["day", "dusk", "night"]
	var slot = 0
	for p in sim.players.values():
		if not p.bot:
			continue
		p.atk = false
		p.inter = false
		p.ent = false
		p.nav_t = p.get("nav_t", 0.0) - dt
		p.bot_cd -= dt
		if playing and p.state == 0:
			think(sim, p, slot, dt)
		slot += 1

static func think(sim, p, slot, dt) -> void:
	equip(sim, p)
	var post_ = post(sim, p, slot)
	for tl in sim.tele:
		if p.pos.distance_to(tl.pos) < tl.r + 0.5 * T:
			move(sim, p, tl.pos + (p.pos - tl.pos).normalized() * (tl.r + T), dt)
			return
	var foe_ = foe(sim, p, post_)
	var foe_d: float = INF if foe_ == null else p.pos.distance_to(foe_.pos)
	if use_tactical_items(sim, p, foe_, foe_d):
		return
	# downed teammates, and dead ones once the bot carries a Revival kit
	var kit: bool = sim.count(p, "revive") > 0
	var down = nearest(sim, p, func(q): return q.state == 1 or kit and q.state == 2, (200.0 if kit else 25.0) * T)
	if down != null and foe_d > 2.5 * T:
		if p.pos.distance_to(down.pos) > 1.0 * T:
			move(sim, p, down.pos, dt)
		else:
			p.inter = true
		return
	if p.role == 1 and p.flasks > 0 and p.bot_cd <= 0:
		var hurt = nearest(sim, p, func(q): return q.state == 0 and q.hp < FLASK_AT * q.maxhp, 3.0 * T)
		if hurt != null or p.hp < FLASK_AT * p.maxhp:
			sim.flask(p, hurt.pos if hurt != null else p.pos)
			p.bot_cd = 1.0
	if p.hp < BANDAGE_AT * p.maxhp and sim.count(p, "bandage") > 0 and p.channel <= 0 and foe_d > 3.0 * T:
		sim.action(p.id, "bandage", 0)
	if p.channel > 0 and foe_d > 1.5 * T:
		return
	if p.get("tower_build_t", 0.0) > 0:
		return
	if foe_ != null:
		var weapon_reach: float = float(GameSim.WEAPON_STATS[sim.weapon_of(p)][2])
		var reach: float = float((weapon_reach - 0.25) * T + foe_.r)
		if foe_d > reach:
			move(sim, p, foe_.pos, dt)
		p.aim = (foe_.pos - p.pos).angle()
		p.atk = p.pos.distance_to(foe_.pos) <= weapon_reach * T + foe_.r
		return
	if p.role == 1 and sim.phase != "day":
		var far = nearest(sim, p, func(q): return q.state == 0 and q.hp < FLASK_AT * q.maxhp, 10.0 * T)
		if far != null and p.flasks > 0:
			move(sim, p, far.pos, dt)
			return
	if p.role == 2 and sim.count(p, "wood") > 0 and repair(sim, p, dt):
		return
	if sim.phase == "day" and fetch_rescue_by_day(sim, p, dt):
		return
	if sim.phase == "day" and sim.t > HOME_AT:
		gather(sim, p, dt)
	elif sim.phase == "day":
		var spot: Vector2 = Vector2(BENCH_SPOTS[slot % BENCH_SPOTS.size()] * T)
		move(sim, p, spot, dt)
		if SimWorld.inside_base(p.pos):
			craft(sim, p)
	else:
		if p.pos.distance_to(post_) > 0.3 * T:
			move(sim, p, post_, dt)
		else:
			p.aim = (post_ - Vector2.ZERO).angle()

# walks to the nearest supply still out there; false when none is left
static func fetch_supply(sim, p, dt) -> bool:
	var best: Vector2 = Vector2.INF
	for c in sim.exploration_chests:
		if c.opened:
			continue
		var at: Vector2 = c.pos
		if not best.is_finite() or Vector2(p.pos).distance_squared_to(at) < Vector2(p.pos).distance_squared_to(best):
			best = at
	if not best.is_finite():
		return false
	if Vector2(p.pos).distance_to(best) <= 38:
		p.inter = true
	else:
		move(sim, p, best, dt)
	return true

static func post(sim, p, slot) -> Variant:
	# Bots share out the attacked doors and stand side by side in front of them; the Engineer stays closer.
	var act = sim.active if not sim.active.is_empty() else [0]
	var d: int = int(act[slot % act.size()])
	var dir: Vector2 = Vector2(GameSim.DOOR_DIR[d])
	var out = (2.0 if p.role == 2 else 3.0) * T
	if sim.k == 5:
		# night 5: between the door and its landing pad
		out = 4.0 * T
	var side = float(slot / act.size() % 3 - 1) * 1.5 * T
	return GameSim.DOOR_POS[d] + dir * out + dir.orthogonal() * side

static func foe(sim, p, post_) -> Variant:
	var best = null
	var best_d = INF
	var day: bool = sim.phase == "day"
	for e in sim.enemies:
		var d: float = float(p.pos.distance_to(e.pos))
		var ok: bool = false
		if day:
			ok = d <= SIGHT_DAY or e.get("target", 0) == p.id
		else:
			ok = d <= 2.5 * T or e.pos.distance_to(post_) <= LEASH or SimWorld.inside_base(e.pos)
		if ok and d < best_d and sim.line_clear(p.pos, e.pos):
			best_d = d
			best = e
	return best

static func nearest(sim, p, pred, radius) -> Variant:
	var best = null
	var best_d = radius
	for q in sim.players.values():
		if q.id != p.id and pred.call(q):
			var d: float = float(p.pos.distance_to(q.pos))
			if d <= best_d:
				best_d = d
				best = q
	return best

static func repair(sim, p, dt) -> Variant:
	# The nearest door below full (30% cap once broken) that can be repaired now; stands just outside it.
	var best = -1
	for i in 3:
		var cap: float = float(GameSim.DOOR_HP * (0.3 if sim.broken[i] else 1.0))
		if sim.doors[i] >= cap - 1.0 or sim.door_pause[i] > 0 or sim.broken[i] and sim.enemy_inside():
			continue
		if best < 0 or p.pos.distance_to(GameSim.DOOR_POS[i]) < p.pos.distance_to(GameSim.DOOR_POS[best]):
			best = i
	if best < 0:
		return false
	var spot: Vector2 = Vector2(GameSim.DOOR_POS[best] + GameSim.DOOR_DIR[best] * 1.0 * T)
	if p.pos.distance_to(spot) > 0.3 * T:
		move(sim, p, spot, dt)
	else:
		p.inter = true
	return true

static func gather(sim, p, dt) -> void:
	var i: int = int(p.bot_node)
	if i < 0 or i >= sim.nodes.size() or sim.nodes[i].amount <= 0:
		i = pick_node(sim, p)
		p.bot_node = i
	if i < 0:
		return
	var nd = sim.nodes[i]
	if p.pos.distance_to(nd.pos) > 1.0 * T:
		move(sim, p, nd.pos, dt)
	else:
		p.aim = (nd.pos - p.pos).angle()
		# hold E standing still (MEC-08)
		p.inter = true

static func pick_node(sim, p) -> Variant:
	# Nearest safe-zone node (no titanium), its favourite resource counted as 12 tiles closer; one bot per node.
	var taken = []
	for q in sim.players.values():
		if q.bot and q.id != p.id:
			taken.append(q.bot_node)
	var best = -1
	var best_s = INF
	for i in sim.nodes.size():
		var nd = sim.nodes[i]
		if nd.type == 3 or nd.amount <= 0 or i in taken:
			continue
		if p.role == 0 and not sim.radio_built and sim.count(p, "chest_key") == 0:
			var missing: int = 0 if sim.count(p, "wood") < 2 else 1 if sim.count(p, "stone") < 2 else -1
			if missing >= 0 and nd.type != missing:
				continue
		var s: float = float(p.pos.distance_to(nd.pos) - (12.0 * T if nd.type == GATHER[p.role] else 0.0))
		if s < best_s:
			best_s = s
			best = i
	return best

static func craft(sim, p) -> void:
	# One useful recipe it can afford: best weapon and armour first, then support items. Crafting takes 3 s.
	if p.bot_cd > 0 or p.craft_idx >= 0:
		return
	p.bot_cd = 0.5
	var dead: bool = sim.players.values().any(func(q): return q.state == 2)
	var has_weapon: int = 2 if sim.count(p, "titanium_blade") > 0 else 1 if sim.count(p, "stone_spear") > 0 else 0
	for idx in [9, 12, 4, 5, 11, 3, 1, 7, 8, 13, 14, 15, 2, 0]:
		var r = GameSim.RECIPES[idx]
		var makes = r[3]
		var useful: bool = has_weapon < 2 and sim.count(p, "long_spear") == 0 and sim.count(p, "stun_maul") == 0 if makes == "long_spear" else p.role == 2 and sim.count(p, "stun_maul") == 0 if makes == "stun_maul" else p.role == 0 and not sim.radio_built and sim.count(p, "chest_key") < 2 if makes == "chest_key" else p.role == 1 and sim.count(p, "healing_flask") < 2 if makes == "healing_flask" else p.role == 0 and sim.count(p, "poison_flask") < 2 if makes == "poison_flask" else p.role == 2 and sim.count(p, "vine_trap") < 2 if makes == "vine_trap" else sim.count(p, "haste_tonic") < 1 if makes == "haste_tonic" else p.role == 2 and sim.count(p, "repair_kit") < 1 if makes == "repair_kit" else has_weapon < 1 and sim.count(p, "long_spear") == 0 if makes == "stone_spear" else has_weapon < 2 if makes == "titanium_blade" else p.role == 0 and sim.count(p, "bow") == 0 and sim.count(p, "starter_bow") == 0 if makes == "bow" else sim.count(p, "bow") > 0 and sim.count(p, "arrow") < 10 if makes == "arrow" else sim.armour_tier(p) < 1 if makes == "light_armour" else sim.armour_tier(p) < 2 if makes == "stone_armour" else sim.armour_tier(p) < 3 if makes == "titanium_armour" else sim.count(p, "bandage") < 2 if makes == "bandage" else dead and sim.count(p, "revive") == 0 if makes == "revive" else sim.base_hp <= GameSim.BASE_HP - 100 if makes == "base" else false
		if useful and sim.can_craft(p, int(idx), false):
			sim.craft(p, idx)
			return
	equip(sim, p)

# Holds the strongest melee weapon it carries (blade, then spear), else an empty hand: bare hands hit
# harder than the hammer or the starter bow up close.
static func equip(sim, p) -> void:
	for w in ["stun_maul", "titanium_blade", "long_spear", "stone_spear"] if p.role == 2 else ["titanium_blade", "long_spear", "stun_maul", "stone_spear"]:
		for i in range(p.inv.size()):
			var s = p.inv[i]
			if s != null and s[0] == w:
				var hand: int = i
				if i >= GameSim.HOTBAR:
					hand = GameSim.HOTBAR - 1
					sim.move_slot(p, ["inv", i, "inv", hand])
				p.sel = hand
				return
	for i in GameSim.HOTBAR:
		var s = p.inv[i]
		if s == null or SimInventory.kind_of(s[0]) != "weapon":
			p.sel = i
			return

static func move(sim, p, goal, dt) -> void:
	# Walks like a player: same speed, same walls, and out of the base at night unless a door is broken.
	var base_way = waypoint(sim, p.pos, goal)
	if p.get("nav_t", 0.0) <= 0 or not p.has("nav_way") or p.pos.distance_to(p.nav_way) < 4 or p.get("nav_goal", Vector2.INF).distance_to(base_way) > T or p.get("nav_revision", -1) != sim.world.revision:
		p.nav_way = sim.navigate(p.pos, base_way, 0.3 * T, false)
		p.nav_goal = base_way
		p.nav_revision = sim.world.revision
		p.nav_t = 0.4
	var way: Vector2 = Vector2(p.nav_way)
	var step: Vector2 = way - p.pos
	if step.length() < 1.0:
		return
	var spd: float = sim.player_speed(p)
	p.pos = sim.move_actor(p.pos, p.pos + step.normalized() * minf(spd * dt, step.length()), 0.3 * T)
	p.aim = step.angle()
	var night: bool = sim.phase == "night"
	p.pos = SimWorld.collide(p.pos, BODY, sim.doors.map(func(d): return not night or d <= 0))
	if night and not p.inside and not sim.doors.any(func(d): return d <= 0):
		p.pos = SimWorld.push_out(p.pos, BODY)

static func waypoint(sim, from, to) -> Variant:
	# Around the base outside, through a door to get in or out.
	var ain = SimWorld.inside_base(from)
	var bin = SimWorld.inside_base(to)
	if ain and bin:
		return to
	var night: bool = sim.phase == "night"
	var best = -1
	var best_d = INF
	for i in 3:
		if night and sim.doors[i] > 0:
			continue
		var d: float = float(from.distance_to(GameSim.DOOR_POS[i]) + GameSim.DOOR_POS[i].distance_to(to))
		if d < best_d:
			best_d = d
			best = i
	var gap = best >= 0 and from.distance_to(GameSim.DOOR_POS[best]) < 1.0 * T
	if not ain:
		if bin and best >= 0:
			var outer: Vector2 = Vector2(GameSim.DOOR_POS[best] + GameSim.DOOR_DIR[best] * T)
			if gap or from.distance_to(outer) < 0.3 * T:
				return GameSim.DOOR_POS[best] - GameSim.DOOR_DIR[best] * T
			if not SimWorld.inside_base(from, BODY + 2):
				return SimWorld.route(from, outer, BODY)
		if SimWorld.inside_base(from, BODY + 2):
			return SimWorld.push_out(from, BODY + 4)
		return SimWorld.route(from, to, BODY)
	if best < 0:
		return from
	var inner: Vector2 = Vector2(GameSim.DOOR_POS[best] - GameSim.DOOR_DIR[best] * T)
	if gap or from.distance_to(inner) < 0.3 * T:
		return GameSim.DOOR_POS[best] + GameSim.DOOR_DIR[best] * T
	return inner

# ---- src/ai/Bots.Rescue.cs

static func fetch_rescue_by_day(sim, p, dt) -> bool:
	if p.craft_idx >= 0:
		return true
	if not sim.radio_built and sim.supplies_got() == 3:
		var match_ = sim
		if match_.radio_builder != null and match_.radio_builder != int(p.id):
			return false
		if not SimSupplies.at_radio(sim, p):
			move(sim, p, GameSim.RADIO_POS + Vector2(0, 24), dt)
		else:
			sim.action(p.id, "radio_open", null)
			sim.action(p.id, "radio_repair", null)
		return true
	if sim.radio_built or p.role != 0:
		return false
	var s = sim
	var open = s.chest_by_id(int(p.open_chest))
	if s.can_access_chest(p, open):
		for i in range(open.slots.size()):
			var item = open.slots[i]
			if item == null or GameSim.COMPONENT_IDS.find(Cs.s(item[0])) < 0:
				continue
			s.move_slot(p, ["chest:" + str(open.id), i, "inv", 0])
			return true
	if s.count(p, "chest_key") == 0:
		if s.count(p, "wood") >= 2 and s.count(p, "stone") >= 2:
			if not s.at_bench(p):
				move(s, p, GameSim.WORKBENCH_POS + Vector2(0, 24), dt)
			else:
				s.craft(p, 15)
			return true
		return false
	return fetch_supply(sim, p, dt)

# ---- src/ai/Bots.TacticalItems.cs

# Called on the bot's existing decision tick; item cooldowns and limits are enforced by GameSim.
static func use_tactical_items(sim, p, foe_, foe_distance: float) -> bool:
	if p.get("repair_kit_t", 0.0) > 0:
		return true
	if p.get("tactical_think_at", 0.0) > float(sim.clock):
		return false
	p.tactical_think_at = float(sim.clock) + 0.5
	var hurt = nearest(sim, p, func(q): return q.state == 0 and q.hp < q.maxhp * 0.65, 4.0 * T)
	if hurt == null and p.hp < p.maxhp * 0.65:
		hurt = p
	if hurt != null and sim.use_tactical_item(p, "healing_flask", Vector2(hurt.pos)):
		return false
	if foe_ != null:
		if foe_distance < 5.0 * T and sim.use_tactical_item(p, "poison_flask", Vector2(foe_.pos)):
			return false
		if foe_distance < 2.5 * T and foe_.type != GameSim.BOSS and p.get("next_trap_at", 0.0) <= float(sim.clock) and sim.use_tactical_item(p, "vine_trap", Vector2(p.pos)):
			p.next_trap_at = float(sim.clock) + 8.0
		if p.hp < p.maxhp * 0.4:
			sim.use_tactical_item(p, "haste_tonic", Vector2(p.pos))
	elif p.role == 2 and sim.count(p, "repair_kit") > 0:
		for i in range(3):
			if sim.doors[i] < GameSim.DOOR_HP - 80 and Vector2(p.pos).distance_to(Vector2(GameSim.DOOR_POS[i])) <= 3.0 * T and sim.use_tactical_item(p, "repair_kit", Vector2(GameSim.DOOR_POS[i])):
				return true
	return false
