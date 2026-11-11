class_name GameSim
extends RefCounted
## Server-only match rules (GDD chapters 2-3). Clients never run this; they get snapshot().
## ponytail: balance values are consts here instead of a .tres resource; move them when designers tune without code.

const T := 32.0  # px per tile
const HALF := Vector2(5.5, 3.5) * T  # base: 11 x 7 tile rectangle (team change; GDD BAL-21 says 15 x 10)
const SAFE_D := 20.0 * T  # safe zone: within 20 tiles of the nearest base wall
const ISLAND := 72.0 * T
const DOOR_DIR := [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)]  # A west, B north, C east (outward); no south door
const DOOR_POS := [Vector2(-HALF.x, 0), Vector2(0, -HALF.y), Vector2(HALF.x, 0)]
const DOOR_NAMES := ["A", "B", "C"]
const PAD_DIST := 5.5 * T  # pad centre in front of each door (island map, fig. 4.1)
const PAD_R := 4.0 * T
const TOWER_HP := 300.0  # BAL-28 / AGT-12
const TOWER_DPS := 8.0
const TOWER_RANGE := 6.0 * T
const TOWER_LIGHT := 6.0 * T  # night light radius, seen by every player
const TOWER_BAND := Vector2(3.0, 8.0) * T  # placed 3-8 tiles in front of a door ...
const TOWER_SIDE := 3.0 * T  # ... and at most 3 tiles to either side of its lane
const TOWER_COST := {"wood": 10, "metal": 5}  # recipe table; unlocked by the first boss kill (MEC-25)

const DAY_MIN := 0.0  # Temporary playtest: allow the day-skip vote immediately (BAL-02 default: 180 s).
const DAY_MAX := 360.0
const DUSK := 5.0  # Temporary playtest countdown (BAL-05 default: 15 s).
const NIGHT_LEN := [600.0, 720.0, 600.0, 720.0, 600.0]  # BAL-03
const BASE_HP := 1000.0  # BAL-20
const DOOR_HP := 500.0  # BAL-21
const MAX_ENEMIES := 60  # BAL-33
const SPAWN_MUL := 3.0  # playtest-only x3 on the FML-04 budget (not in the GDD); GDD value is 1.0
const SPAWN_ALL_SIDES := true  # Night waves can arrive from anywhere around the island, including the south.
const ENEMY_SPEED_MUL := 0.5  # Half movement speed for every enemy, including roamers and bosses.
const FIRST_WAVE_DELAY := 5.0
const WAVE_INTERVAL := 30.0
const FINAL_WAVE_INTERVAL := 15.0
const WAVE_MIN_DISTANCE := 8.0  # tiles from the base; close enough for the first attackers to arrive quickly
const ROAM_MUL := 2.0  # playtest-only x2 on the FML-16 roamer chance (not in the GDD); GDD value is 1.0
const DROP_MUL := 3.0  # playtest-only x3 on BAL-41 drop chances (not in the GDD); GDD value is 1.0
const NODE_MUL := 2  # playtest-only x2 on the BAL-17 node count per type (not in the GDD); GDD value is 1

const ROLES := ["Scout", "Healer", "Engineer"]
const ROLE_HP := [90.0, 100.0, 110.0]  # BAL-06
const SPEED := 5.0 * T  # BAL-07
const WEAPON_DMG := [15.0, 20.0, 26.0]  # 1.5 hits/s => DPS 22.5 / 30 / 39 (BAL-09)
const WEAPONS := ["Basic weapon", "Stone spear", "Metal blade"]
const ARMOUR := [0.0, 0.15, 0.30, 0.45]  # BAL-11
const MODES := ["Easy", "Medium", "Hard"]
const MODE_MUL := [[0.75, 0.85, 0.8], [1.0, 1.0, 1.0], [1.25, 1.15, 1.2]]  # budget, hp, dmg (BAL-45)

enum { GRUNT, SPITTER, WRECKER, BOSS }
const ENEMY := [  # hp, dmg, speed tiles/s, cost, first night (BAL-29..31)
	[60.0, 10.0, 3.0, 10, 1],
	[40.0, 8.0, 3.0, 15, 3],
	[100.0, 10.0, 2.5, 20, 4],
]
const RES := ["wood", "stone", "herb", "metal"]
const ROAM_CHECK := 15.0  # BAL-44 / FML-16: one check per player every 15 s
const ROAM_D0 := 20.0  # tiles from the base wall: no roamers inside
const ROAM_D1 := 60.0
const ROAM_PMAX := 0.3
const ROAM_MAX := 8
const ROAM_SIGHT := 4.0 * T  # day sight
const VIEW_HALF := Vector2(15.0, 8.5) * T  # half of the 30 x 17 tile camera view
const DROP_TTL := 30.0  # BAL-41
const DROPS := [  # BAL-41 per enemy type: chance, possible items, min, max
	[0.10, ["wood", "stone", "herb"], 1, 2],
	[0.15, ["bandage"], 1, 1],
	[0.20, ["metal"], 2, 2],
]
const RECIPES := [  # name, cost, unlock tier, effect, value, engineer only
	["Light armour", {"wood": 6}, 0, "armour", 1, false],
	["Bandage", {"herb": 2}, 0, "bandage", 1, false],
	["Revival kit", {"herb": 4, "metal": 4}, 0, "revive", 0, false],
	["Base repair +100", {"stone": 5}, 0, "base", 100, true],
	["Stone spear", {"wood": 8, "stone": 12}, 1, "weapon", 1, false],
	["Stone armour", {"wood": 8, "stone": 16}, 1, "armour", 2, false],
	["Metal blade", {"wood": 10, "metal": 20}, 2, "weapon", 2, false],
	["Metal armour", {"metal": 24}, 2, "armour", 3, false],
]

var phase := "lobby"  # lobby, day, dusk, night, result
var t := 0.0  # time left in phase
var elapsed := 0.0  # time into the night
var k := 1
var mode := 1
var base_hp := BASE_HP
var doors := [DOOR_HP, DOOR_HP, DOOR_HP]
var broken := [false, false, false]
var door_pause := [0.0, 0.0, 0.0]
var active: Array = []
var players := {}
var order: Array = []
var enemies: Array = []
var proj: Array = []
var tele: Array = []
var nodes: Array = []
var drops: Array = []
var votes := {}
var unlock := 0
var shown_unlock := 0
var bosses_killed := 0
var boss_dead := false
var wave := 0
var next_wave := 0.0
var carry := 0.0
var boss_spawned := false
var towers := [null, null, null]  # one per door: {door, pos, hp, wrecked, pause, target}
var free_tower := true  # MEC-28: the match starts with one free tower to place
var ext := -1.0
var pad_clear := [0.0, 0.0, 0.0]
var msg := ""
var msg_t := 0.0
var next_id := 0
var n0 := 1
var rng := RandomNumberGenerator.new()
const Bots := preload("res://bots.gd")  # bot teammates for demos and solo tests (not in the GDD)


func leader() -> int:
	return order[0] if order.size() > 0 else 0


func add_player(id: int, pname: String, role: int) -> void:
	# ponytail: no joining mid-match (GDD: rejoin is out of scope).
	if phase != "lobby" or players.size() >= 5 or players.has(id):
		return
	players[id] = {"id": id, "name": pname.substr(0, 16), "role": clampi(role, 0, 2), "pos": Vector2.ZERO, "tp": 0, "bot": false}
	order.append(id)
	_reset_player(players[id])


func remove_player(id: int) -> void:
	players.erase(id)
	order.erase(id)
	votes.erase(id)
	if humans() == 0:  # the last person left: bots do not play on alone
		for b in players.keys():
			players.erase(b)
			order.erase(b)
		if phase != "lobby":
			_to_lobby()


func humans() -> int:
	return players.values().filter(func(p): return not p.bot).size()


func input(id: int, pos: Vector2, aim: float, atk: bool, inter: bool, ent: bool, tp: int) -> void:
	var p = players.get(id)
	if p == null:
		return
	p.aim = aim
	p.atk = atk
	p.inter = inter
	p.ent = ent
	if tp == p.tp and p.state == 0:  # ignore stale positions sent before a server teleport
		p.pos = pos.limit_length(ISLAND)


func action(id: int, kind: String, arg) -> void:
	var p = players.get(id)
	if p == null:
		return
	match kind:
		"role":
			if phase == "lobby":
				p.role = clampi(int(arg), 0, 2)
				_reset_player(p)
		"mode":
			if phase == "lobby" and id == leader():
				mode = clampi(int(arg), 0, 2)
		"start":
			if phase == "lobby" and id == leader():
				var err := start_match()
				if err != "":
					_say(err)
		"add_bot":
			if id == leader():
				Bots.add(self)
		"remove_bot":
			if id == leader():
				Bots.remove(self)
		"craft":
			craft(p, int(arg))
		"tower":
			_build_tower(p)
		"bandage":
			if p.state == 0 and p.inv.bandage > 0 and p.hp < p.maxhp and p.channel <= 0:
				p.channel = 2.0
		"flask":
			if arg is Vector2:
				_flask(p, arg)
		"vote":
			if phase == "day":
				if votes.has(id):
					votes.erase(id)
				else:
					votes[id] = true
		"skip":  # debug only: host ends the current phase
			if id == 1 and OS.is_debug_build() and phase in ["day", "dusk", "night"]:
				enemies.clear()
				t = 0.0


func start_match() -> String:
	var eng := false
	for p in players.values():
		if p.role == 2:
			eng = true
	if not eng:
		return "Need at least one Engineer"
	# ponytail: GDD wants 3-5 players; 1+ allowed so one person can test.
	rng.randomize()
	n0 = players.size()
	k = 1
	base_hp = BASE_HP
	doors = [DOOR_HP, DOOR_HP, DOOR_HP]
	unlock = 0
	towers = [null, null, null]
	free_tower = true
	shown_unlock = 0
	bosses_killed = 0
	enemies.clear()
	proj.clear()
	tele.clear()
	drops.clear()
	_gen_nodes()
	for p in players.values():
		_reset_player(p)
	_dawn()
	return ""


func tick(dt: float) -> void:
	if phase == "lobby":
		return
	t -= dt
	msg_t -= dt
	if phase == "result":
		if t <= 0:
			_to_lobby()
		return
	for i in 3:
		door_pause[i] -= dt
	Bots.tick(self, dt)
	_tick_players(dt)
	if phase == "night":
		elapsed += dt
		_tick_waves()
	elif phase == "day":
		_tick_roamers(dt)
	_tick_enemies(dt)
	_tick_towers(dt)
	_tick_proj(dt)
	_tick_tele(dt)
	_tick_drops(dt)
	if phase == "night":
		_check_end(dt)
		return
	if _team_wiped():  # lose condition 2 holds by day too (downed by roamers)
		_end(false, "Team wiped")
	elif phase == "day":
		if t <= 0 or (DAY_MAX - t >= DAY_MIN and votes.size() >= ceili(0.6 * humans())):
			_dusk()
	elif phase == "dusk" and t <= 0:
		_night()


func craft(p, idx: int) -> void:
	if idx < 0 or idx >= RECIPES.size():
		return
	var r: Array = RECIPES[idx]
	# ponytail: crafting is instant and day-only; GDD's 3 s craft time and Engineer night entry come later.
	var bench_ok: bool = (phase in ["day", "dusk"] and inside_base(p.pos)) or (phase == "night" and p.inside)
	if p.state != 0 or not bench_ok:
		_note(p, "Craft at the workbench inside the base (by day; Engineer at night)")
		return
	if r[2] > unlock:
		_note(p, "%s is locked" % r[0])
		return
	if r[5] and p.role != 2:
		_note(p, "Only an Engineer can do that")
		return
	for res in r[1]:
		if p.inv[res] < r[1][res]:
			_note(p, "Not enough %s for %s" % [res, r[0]])
			return
	var dead := players.values().filter(func(q): return q.state == 2)
	if r[3] == "revive" and dead.is_empty():
		_note(p, "No dead teammate to revive")
		return
	for res in r[1]:
		p.inv[res] -= r[1][res]
	match r[3]:
		"armour":
			p.armour = maxi(p.armour, r[4])
		"weapon":
			p.weapon = maxi(p.weapon, r[4])
		"bandage":
			p.inv.bandage += 1
		"base":
			base_hp = minf(BASE_HP, base_hp + r[4])
		"revive":
			var q = dead[0]
			q.state = 0
			q.hp = q.maxhp * 0.5
			_teleport(q, DOOR_POS[0] + DOOR_DIR[0] * T)
			_say("%s is back (Revival kit)" % q.name)
	_note(p, "Crafted " + r[0])


func snapshot() -> Dictionary:
	var ps := {}
	for id in players:
		var p = players[id]
		ps[id] = [p.name, p.role, p.pos, p.hp, p.maxhp, p.state, p.bleed, p.inv, p.weapon, p.armour,
			p.flasks, p.swing > 0, p.aim, p.channel, p.revive_p, p.tp, p.note if p.note_t > 0 else "", p.kills, p.dmg, p.inside, p.entry, p.gather_acc]
	return {
		"ph": phase, "t": t, "k": k, "base": base_hp, "doors": doors, "active": active, "ps": ps,
		"en": enemies.map(func(e): return [e.id, e.type, e.pos, e.hp, e.maxhp, e.r]),
		"proj": proj.map(func(b): return b.pos),
		"tele": tele.map(func(tl): return [tl.pos, tl.r, tl.t]),
		# ponytail: static node positions resent every snapshot; send once if bandwidth matters.
		"nodes": nodes.map(func(nd): return [nd.type, nd.pos, nd.amount]),
		"drops": drops.map(func(d): return [d.pos, d.item, d.n, d.ttl]),
		"msg": msg if msg_t > 0 or phase == "result" else "",
		"unlock": unlock, "votes": votes.size(), "need": ceili(0.6 * humans()),
		"leader": leader(), "mode": mode, "ext": ext, "pads": pad_clear,
		"broken": broken, "dpause": door_pause.map(func(v): return v > 0), "inside_en": _enemy_inside(),
		"tw": towers.filter(func(tw): return tw != null).map(func(tw): return [tw.door, tw.pos, tw.hp, tw.wrecked, tw.target != null, tw.target if tw.target != null else Vector2.ZERO]),
		"free_tower": free_tower,
	}


# --- phases -------------------------------------------------------------

func _dawn() -> void:
	phase = "day"
	t = DAY_MAX
	votes.clear()
	broken = [false, false, false]
	for tw in towers:  # like a door, a wrecked tower can be repaired in full again by day
		if tw != null:
			tw.wrecked = false
	for nd in nodes:
		nd.amount = 5
	for p in players.values():
		p.inside = false
		p.entry = 0.0
		if p.role == 1:
			p.flasks = 3
	var idx := [0, 1, 2]
	idx.shuffle()
	active = idx.slice(0, mini(3, k))
	active.sort()
	var names := PackedStringArray(active.map(func(i): return DOOR_NAMES[i]))
	var s := "Radio: night %d/5 - %s %s will be attacked" % [k, "door" if names.size() == 1 else "doors", ", ".join(names)]
	if k == 2 or k == 4:
		s += ", and a NOX specimen is coming"
	if k == 5:
		s = "Radio: We can see your light. Keep one landing pad clear."
	if unlock > shown_unlock:
		shown_unlock = unlock
		s += "  |  New recipes unlocked (C)"
	_say(s)


func _dusk() -> void:
	phase = "dusk"
	t = DUSK
	for e in enemies:  # MEC-26: surviving roamers head for the nearest attacked door
		if e.has("home"):
			e.erase("home")
			e.state = 0
			e.threat.clear()
			e.door = _nearest_active_door(e.pos)
	if free_tower and k == 1:  # MEC-28: an unplaced free tower appears in front of the door drawn for night 1
		free_tower = false
		var d: int = active[0]
		_place_tower(d, DOOR_POS[d] + DOOR_DIR[d] * 5.0 * T)
	_say("Dusk: night falls in %d s - everyone out of the base" % DUSK)


func _night() -> void:
	phase = "night"
	t = NIGHT_LEN[k - 1]
	elapsed = 0.0
	wave = 0
	next_wave = FIRST_WAVE_DELAY
	carry = 0.0
	boss_spawned = false
	ext = -1.0
	pad_clear = [0.0, 0.0, 0.0]
	for p in players.values():
		p.inside = false
		if inside_base(p.pos, 0.5 * T):
			var d := _nearest_door(p.pos)
			_teleport(p, DOOR_POS[d] + DOOR_DIR[d] * T)
	_say("Night %d - hold the doors!" % k)


func _night_cleared() -> void:
	if k == 1:
		unlock = maxi(unlock, 1)
	enemies.clear()
	proj.clear()
	tele.clear()
	k += 1
	_dawn()


func _end(win: bool, why: String) -> void:
	phase = "result"
	t = 10.0
	msg = ("MISSION COMPLETE - " if win else "BEACON LOST - ") + why + " (night %d)" % k
	enemies.clear()
	proj.clear()
	tele.clear()


func _to_lobby() -> void:
	phase = "lobby"
	msg = ""
	drops.clear()
	enemies.clear()
	proj.clear()
	tele.clear()
	for p in players.values():
		_reset_player(p)


func _check_end(dt: float) -> void:
	if base_hp <= 0:
		_end(false, "Generator destroyed")
		return
	if _team_wiped():
		_end(false, "Team wiped")
		return
	if boss_dead:
		boss_dead = false
		bosses_killed += 1
		unlock = maxi(unlock, 2)
		_night_cleared()
		return
	if t > 0:
		return
	if k == 2 or k == 4:
		_end(false, "Specimen still alive at dawn")
		return
	if k < 5:
		_night_cleared()
		return
	# night 5 extraction (FML-13)
	var clear := []
	for i in 3:
		clear.append(_pad_is_clear(i))
	if ext < 0:
		if true in clear:
			_end(true, "Helicopter landed at pad %s" % DOOR_NAMES[clear.find(true)])
		elif base_hp > 500:
			ext = 60.0
			_say("Extension: keep one landing pad clear for 10 s!")
		else:
			_end(false, "No landing pad was clear")
		return
	ext -= dt
	for i in 3:
		pad_clear[i] = pad_clear[i] + dt if clear[i] else 0.0
		if pad_clear[i] >= 10.0:
			_end(true, "Helicopter landed at pad %s" % DOOR_NAMES[i])
			return
	if ext <= 0:
		_end(false, "Extension ended without a clear pad")


# --- players ------------------------------------------------------------

func _reset_player(p) -> void:
	p.hp = ROLE_HP[p.role]
	p.maxhp = p.hp
	p.state = 0  # 0 standing, 1 downed, 2 dead
	p.bleed = 0.0
	p.inv = {"wood": 0, "stone": 0, "herb": 0, "metal": 0, "bandage": 0}
	p.weapon = 0
	p.armour = 0
	p.flasks = 3 if p.role == 1 else 0
	p.invuln = 0.0
	p.atk_cd = 0.0
	p.swing = 0.0
	p.channel = 0.0
	p.revive_p = 0.0
	p.gather_acc = 0.0
	p.repair_acc = 0.0
	p.aim = 0.0
	p.atk = false
	p.inter = false
	p.kills = 0
	p.dmg = 0.0
	p.inside = false  # Engineer inside the base at night (MEC-15)
	p.entry = 0.0
	p.entry_pos = Vector2.ZERO
	p.ent = false
	p.gather_pos = Vector2.ZERO
	p.roam_t = ROAM_CHECK
	p.note = ""
	p.note_t = 0.0
	p.bot_cd = 0.0
	p.bot_node = -1  # index of the resource node a bot is gathering
	_teleport(p, Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)) * T)


func _tick_players(dt: float) -> void:
	for p in players.values():
		p.invuln -= dt
		p.atk_cd -= dt
		p.swing -= dt
		p.note_t -= dt
		if p.state == 1:
			p.bleed -= dt
			if p.bleed <= 0:
				p.state = 2
				_say("%s died - craft a Revival kit at the workbench" % p.name)
		if p.state != 0:
			continue
		if p.channel > 0:
			if p.atk:
				p.channel = 0.0  # attacking cancels the bandage and keeps it
			else:
				p.channel -= dt
				if p.channel <= 0 and p.inv.bandage > 0:
					p.inv.bandage -= 1
					p.hp = minf(p.maxhp, p.hp + 30.0 * (1.5 if p.role == 1 else 1.0))
		_tick_entry(p, dt)
		if p.inside:  # inside at night: no attack, repair or revive
			p.revive_p = 0.0
			continue
		if p.atk and p.atk_cd <= 0:
			_attack(p)
		if p.inter:
			_interact(p, dt)
		else:
			p.revive_p = 0.0
			p.gather_acc = 0.0


func _tick_entry(p, dt: float) -> void:  # MEC-15 / BAL-26: hold F 2 s at a closed door, standing still
	var door := -1
	if p.ent and p.role == 2 and phase == "night":
		for i in 3:
			if doors[i] > 0 and p.pos.distance_to(DOOR_POS[i]) <= 2.0 * T:
				door = i
	if door < 0 or (p.entry > 0 and p.pos.distance_to(p.entry_pos) > 4.0):
		p.entry = 0.0
		return
	if p.entry == 0.0:
		p.entry_pos = p.pos
	p.entry += dt
	if p.entry < 2.0:
		return
	p.entry = 0.0
	p.inside = not p.inside
	if p.inside:
		_teleport(p, DOOR_POS[door] - DOOR_DIR[door] * 1.2 * T)
		_note(p, "Inside: C to craft, hold F at a door to leave")
	else:
		_teleport(p, DOOR_POS[door] + DOOR_DIR[door] * T)
		p.invuln = 0.5


func _attack(p) -> void:
	p.atk_cd = 1.0 / (1.5 * (1.25 if p.role == 0 else 1.0))
	p.swing = 0.15
	var dir := Vector2.from_angle(p.aim)
	for e in enemies:
		var d: Vector2 = e.pos - p.pos
		if d.length() <= 1.5 * T + e.r and (d.length() < 0.5 * T or absf(dir.angle_to(d)) <= PI / 4):
			_hit(e, WEAPON_DMG[p.weapon], p)
	enemies = enemies.filter(func(e): return e.hp > 0)


func _hit(e, dmg: float, p) -> void:
	e.hp -= dmg
	e.nodmg = 0.0
	p.dmg += dmg
	if (e.type == GRUNT or e.type == BOSS) and (e.state <= 1 or e.state == 4):
		# ponytail: threat is cumulative until the leash breaks, not a sliding 5 s window (FML-09).
		e.threat[p.id] = e.threat.get(p.id, 0.0) + dmg
		if e.state == 0 or e.state == 4:
			e.state = 1
			e.anchor = e.pos
			e.target = p.id
		elif e.threat[p.id] > 1.2 * e.threat.get(e.target, 0.0):
			e.target = p.id
	if e.hp <= 0:
		_drop(e)
		p.kills += 1
		if e.type == BOSS:
			boss_dead = true


func _interact(p, dt: float) -> void:
	for q in players.values():  # 1) revive
		if q.state == 1 and q.id != p.id and q.pos.distance_to(p.pos) <= 1.5 * T:
			p.revive_p += dt / (10.0 if p.role == 1 else 20.0)
			if p.revive_p >= 1.0:
				p.revive_p = 0.0
				q.state = 0
				q.hp = 0.3 * q.maxhp
				q.invuln = 1.0
				_say("%s revived %s" % [p.name, q.name])
			return
	p.revive_p = 0.0
	if p.role == 2 and not inside_base(p.pos):  # 2) Engineer repairs a door from outside (MEC-12), day or night
		for i in 3:
			var dp: Vector2 = DOOR_POS[i]
			if p.pos.distance_to(dp) <= 1.5 * T:  # BAL-23
				var cap: float = DOOR_HP * 0.3 if broken[i] else DOOR_HP
				if (broken[i] and _enemy_inside()) or door_pause[i] > 0 or doors[i] >= cap or p.inv.wood <= 0:
					return
				var amt := 15.0 * dt
				doors[i] = minf(cap, doors[i] + amt)
				p.repair_acc += amt
				if p.repair_acc >= 10.0:
					p.repair_acc -= 10.0
					p.inv.wood -= 1
				return
		for tw in towers:  # ... and a tower the same way (BAL-23 / BAL-28)
			if tw != null and p.pos.distance_to(tw.pos) <= 1.5 * T:
				var tcap: float = TOWER_HP * 0.3 if tw.wrecked else TOWER_HP
				if (tw.wrecked and _enemy_near(tw.pos, TOWER_LIGHT)) or tw.pause > 0 or tw.hp >= tcap or p.inv.wood <= 0:
					return
				var tamt := 15.0 * dt
				tw.hp = minf(tcap, tw.hp + tamt)
				p.repair_acc += tamt
				if p.repair_acc >= 10.0:
					p.repair_acc -= 10.0
					p.inv.wood -= 1
				return
	for nd in nodes:  # 3) gather (MEC-08): hold E standing still; moving or a hit resets the unit in progress
		if nd.amount > 0 and nd.pos.distance_to(p.pos) <= 1.5 * T:
			if p.gather_acc > 0 and p.pos.distance_to(p.gather_pos) > 4.0:
				p.gather_acc = 0.0
			if p.gather_acc == 0.0:
				p.gather_pos = p.pos
			p.gather_acc += 0.35 * dt
			if p.gather_acc >= 1.0:
				p.gather_acc = 0.0
				nd.amount -= 1
				p.inv[RES[nd.type]] += 1
			return
	p.gather_acc = 0.0  # nothing in reach


func _hurt(p, dmg: float) -> void:
	# ponytail: an Engineer inside is untouchable; let breached enemies hit them if playtests ask.
	if p.state != 0 or p.invuln > 0 or p.inside:
		return
	p.entry = 0.0
	p.hp -= maxf(1.0, roundf(dmg * (1.0 - ARMOUR[p.armour])))
	p.invuln = 1.0
	p.channel = 0.0
	p.revive_p = 0.0
	p.gather_acc = 0.0
	if p.hp <= 0:
		p.hp = 0.0
		p.state = 1
		p.bleed = 30.0
		_say("%s is DOWN - hold E next to them to revive" % p.name)


func _flask(p, aim_point: Vector2) -> void:
	if p.role != 1 or p.flasks <= 0 or p.state != 0:
		return
	var target = p
	for q in players.values():
		if q.state == 0 and q.id != p.id and q.pos.distance_to(p.pos) <= 3 * T and q.pos.distance_to(aim_point) < T:
			target = q
	target.hp = minf(target.maxhp, target.hp + 40.0)
	p.flasks -= 1


# --- enemies ------------------------------------------------------------

func _tick_waves() -> void:
	if elapsed >= next_wave:
		wave += 1
		next_wave += FINAL_WAVE_INTERVAL if k == 5 else WAVE_INTERVAL
		_spawn_wave()
	if (k == 2 or k == 4) and not boss_spawned and elapsed >= 300.0:
		boss_spawned = true
		_spawn_boss()


func _spawn_wave() -> void:  # FML-04
	var n := players.size()
	var wf := 1.0 if k == 5 else 1.0 + 0.15 * mini(wave - 1, 5)
	var budget: float = 40.0 * (1 + 0.5 * (n - 1)) * pow(1.2, k - 1) * wf * (1.5 if k == 5 else 1.0) \
		* (1.0 / 3.0 if _boss() != null else 1.0) * MODE_MUL[mode][0] * SPAWN_MUL + carry
	var types := [0, 1, 2].filter(func(ty): return ENEMY[ty][4] <= k)
	var i := 0
	while enemies.size() < MAX_ENEMIES:
		var can := types.filter(func(ty): return ENEMY[ty][3] <= budget)
		if can.is_empty():
			break
		var ty: int = can[rng.randi() % can.size()]
		budget -= ENEMY[ty][3]
		var dist := rng.randf_range(WAVE_MIN_DISTANCE, (ISLAND - HALF.length()) / T - 2.0) if SPAWN_ALL_SIDES else rng.randf_range(25.0, 35.0)
		var e := _spawn(ty, active[i % active.size()], dist)
		if SPAWN_ALL_SIDES:
			e.door = _nearest_active_door(e.pos)
		i += 1
	carry = budget if budget < 10 else 0.0


func _spawn(ty: int, door: int, dist_tiles: float, any_side := SPAWN_ALL_SIDES) -> Dictionary:  # FML-01
	var s: Array = ENEMY[ty]
	var g := pow(1.1, k - 1)
	var e := {
		"id": next_id, "type": ty, "pos": _spawn_pos(door, dist_tiles, any_side),
		"hp": s[0] * g * MODE_MUL[mode][1], "dmg": s[1] * g * MODE_MUL[mode][2],
		"spd": minf(4.25, s[2] * pow(1.08, k - 1)) * T * ENEMY_SPEED_MUL, "door": door, "state": 0, "cd": 0.0,
		"threat": {}, "target": 0, "anchor": Vector2.ZERO, "nodmg": 0.0,
		"r": (0.625 if ty == WRECKER else 0.5) * T,
	}
	e.maxhp = e.hp
	next_id += 1
	enemies.append(e)
	return e


func _spawn_boss() -> void:  # FML-02; ponytail: one archetype (slam only) instead of seven, add the rest on this hook
	var door: int = active[rng.randi() % active.size()]
	var e := _spawn(GRUNT, door, 60.0, false)
	e.pos = (DOOR_POS[door] + DOOR_DIR[door] * 60.0 * T).limit_length(ISLAND - 2 * T)  # BAL-34
	var m4 := 1.21 if k == 4 else 1.0
	e.type = BOSS
	e.hp = 3900.0 * (1 + 0.8 * (players.size() - 1)) / 3.4 * (1.5625 if k == 4 else 1.0) * MODE_MUL[mode][1]
	e.maxhp = e.hp
	e.dmg = 60.0 * m4 * MODE_MUL[mode][2]  # door damage per 4 s (BAL-37)
	e.slam = 40.0 * m4 * MODE_MUL[mode][2]  # BAL-38
	e.slam_cd = 3.0
	e.r = 0.9 * T
	_say("NOX-01 JUGGERNAUT is heading for door %s!" % DOOR_NAMES[door])


func _boss():
	for e in enemies:
		if e.type == BOSS:
			return e
	return null


func _tick_enemies(dt: float) -> void:  # FML-09 state machine: 0 approach, 1 retaliate, 2 lock door, 3 lock base
	for e in enemies:
		e.cd -= dt
		e.nodmg += dt
		if e.type == SPITTER:
			_tick_spitter(e, dt)
			continue
		if e.state == 4:  # daytime roamer: wander until someone comes within day sight
			var seen = _nearest_player(e.pos, ROAM_SIGHT)
			if seen == null:
				_wander(e, dt)
				continue
			e.state = 1
			e.target = seen.id
			e.anchor = e.pos
			e.nodmg = 0.0
			e.threat[seen.id] = 1.0
		var target_p = null
		if e.state == 1:
			target_p = players.get(e.target)
			if target_p == null or target_p.state != 0 or target_p.inside or e.nodmg > 5.0 or e.pos.distance_to(e.anchor) > 12 * T:
				e.state = 4 if e.has("home") else 0  # roamers go back to wandering by day
				e.threat.clear()
				target_p = null
				if e.state == 4:
					continue
		if e.state == 0 and phase == "night":  # MEC-28: walking into a standing tower's light, it attacks the tower first
			var lit = _tower_in_light(e.pos)
			if lit != null:
				e.state = 5
				e.tw = lit.door
		if e.state == 5:  # locked on a tower: ignores players until the tower falls, then walks on to its door
			var tw = towers[e.tw]
			if tw == null or tw.hp <= 0:
				e.state = 0
			else:
				if e.pos.distance_to(tw.pos) > e.r + 0.4 * T:
					e.pos += (_route(e.pos, tw.pos, e.r) - e.pos).normalized() * minf(e.spd * dt, e.pos.distance_to(tw.pos))
				elif e.cd <= 0:
					_tower_attack(e, tw)
				if e.type == BOSS:
					_boss_slam(e, dt)
				e.pos = push_out(e.pos, e.r)
				continue
		if (e.state == 0 or e.state == 2) and doors[e.door] <= 0:
			e.state = 3
		var door_pos: Vector2 = DOOR_POS[e.door]
		var near_door: bool = e.pos.distance_to(door_pos) <= e.r + T  # anywhere along the door gap
		var goal: Vector2 = door_pos + DOOR_DIR[e.door] * (e.r + 0.2 * T)
		var arrived := near_door
		var outside := true
		if e.state == 1:
			goal = target_p.pos
			arrived = e.pos.distance_to(goal) <= e.r + 0.4 * T
		elif e.state == 3 and (inside_base(e.pos, e.r + 2) or near_door):
			goal = Vector2.ZERO  # through the broken door to the generator
			arrived = e.pos.length() <= 2.5 * T
			outside = false
		if not arrived:
			var way := _route(e.pos, goal, e.r) if outside else goal
			e.pos += (way - e.pos).normalized() * minf(e.spd * dt, e.pos.distance_to(goal))
		elif e.cd <= 0:
			_enemy_attack(e, target_p)
		if e.type == BOSS:
			_boss_slam(e, dt)
		if outside:
			e.pos = push_out(e.pos, e.r)
	_separate()


func _enemy_attack(e, p) -> void:
	var boss: bool = e.type == BOSS
	if e.state == 1:
		if not boss:  # bosses hurt players only through the telegraphed slam
			_hurt(p, e.dmg)
		e.cd = 2.0
		return
	var d: float = e.dmg * (2.0 if e.type == WRECKER else 1.0)
	if e.state == 3:
		base_hp -= d  # breach: beta = 1
	else:  # FML-07
		var x: float = 1.0 - doors[e.door] / DOOR_HP
		doors[e.door] = maxf(0.0, doors[e.door] - d)
		base_hp -= 0.3 * d * (1.0 + x)
		door_pause[e.door] = 2.0
		e.state = 2
		if doors[e.door] <= 0 and not broken[e.door]:
			broken[e.door] = true
			_say("Door %s broken - BREACH!" % DOOR_NAMES[e.door])
	base_hp = maxf(0.0, base_hp)
	e.cd = 4.0 if boss else 2.0


func _tower_attack(e, tw) -> void:  # towers take door damage: Wreckers x2, bosses their door blow (BAL-28, BAL-37)
	tw.hp = maxf(0.0, tw.hp - e.dmg * (2.0 if e.type == WRECKER else 1.0))
	tw.pause = 2.0  # FML-08: a hit blocks repair for 2 s
	e.cd = 4.0 if e.type == BOSS else 2.0
	if tw.hp <= 0 and not tw.wrecked:
		tw.wrecked = true
		_say("Tower at door %s destroyed - its light is out" % DOOR_NAMES[tw.door])


# --- towers (AGT-12, MEC-11, MEC-28) -------------------------------------

static func tower_slot(pos: Vector2) -> int:
	## The door whose tower band (3-8 tiles in front of it, 3 to either side) holds pos, else -1.
	for i in 3:
		var rel: Vector2 = pos - DOOR_POS[i]
		var dd: Vector2 = DOOR_DIR[i]
		var along := rel.dot(dd)
		if along >= TOWER_BAND.x and along <= TOWER_BAND.y and absf(rel.dot(Vector2(-dd.y, dd.x))) <= TOWER_SIDE:
			return i
	return -1


func _build_tower(p) -> void:
	if p.role != 2 or p.state != 0 or p.inside:
		_note(p, "Only an Engineer can build towers")
		return
	var i := tower_slot(p.pos)
	if i < 0:
		_note(p, "Stand 3-8 tiles in front of a door to build a tower")
		return
	if towers[i] != null:
		_note(p, "Door %s already has a tower" % DOOR_NAMES[i])
		return
	if free_tower:
		free_tower = false
	else:
		if unlock < 2:
			_note(p, "More towers unlock after the first boss")
			return
		for res in TOWER_COST:
			if p.inv[res] < TOWER_COST[res]:
				_note(p, "A tower costs 10 wood + 5 metal")
				return
		for res in TOWER_COST:
			p.inv[res] -= TOWER_COST[res]
	_place_tower(i, p.pos)
	_note(p, "Tower built at door %s" % DOOR_NAMES[i])


func _place_tower(door: int, pos: Vector2) -> void:
	towers[door] = {"door": door, "pos": pos, "hp": TOWER_HP, "wrecked": false, "pause": 0.0, "target": null}


func _tick_towers(dt: float) -> void:
	## A standing tower shoots the nearest enemy within 6 tiles at 8 DPS, day or night.
	for tw in towers:
		if tw == null:
			continue
		tw.pause -= dt
		tw.target = null
		if tw.hp <= 0:
			continue
		var best = null
		var bd := TOWER_RANGE
		for e in enemies:
			var d: float = e.pos.distance_to(tw.pos)
			if e.hp > 0 and d <= bd:
				bd = d
				best = e
		if best != null:
			tw.target = best.pos
			best.hp -= TOWER_DPS * dt
			best.nodmg = 0.0
			if best.hp <= 0:
				_drop(best)
				if best.type == BOSS:
					boss_dead = true
	enemies = enemies.filter(func(e): return e.hp > 0)


func _tower_in_light(pos: Vector2):
	for tw in towers:
		if tw != null and tw.hp > 0 and pos.distance_to(tw.pos) <= TOWER_LIGHT:
			return tw
	return null


func _enemy_near(pos: Vector2, radius: float) -> bool:
	for e in enemies:
		if e.pos.distance_to(pos) <= radius:
			return true
	return false


func _boss_slam(e, dt: float) -> void:
	e.slam_cd -= dt
	if e.slam_cd > 0:
		return
	for p in players.values():
		if p.state == 0 and p.pos.distance_to(e.pos) < 3 * T:
			tele.append({"pos": e.pos, "r": 3 * T, "t": 1.0, "dmg": e.slam})
			e.slam_cd = 6.0 * (0.9 if k == 4 else 1.0)
			return


func _tick_spitter(e, dt: float) -> void:
	var best = _nearest_player(e.pos, ROAM_SIGHT if e.state == 4 else 8.0 * T)
	var bd: float = best.pos.distance_to(e.pos) if best != null else INF
	if best == null and e.state == 4:
		_wander(e, dt)
	elif best == null:
		var front: Vector2 = DOOR_POS[e.door] + DOOR_DIR[e.door] * 4 * T
		if e.pos.distance_to(front) > 0.5 * T:
			e.pos += (_route(e.pos, front, e.r) - e.pos).normalized() * e.spd * dt
			e.pos = push_out(e.pos, e.r)
	elif bd > 5.5 * T:
		e.pos += (_route(e.pos, best.pos, e.r) - e.pos).normalized() * e.spd * dt
		e.pos = push_out(e.pos, e.r)
	elif e.cd <= 0:
		e.cd = 2.0
		proj.append({"pos": e.pos, "vel": (best.pos - e.pos).normalized() * 8 * T, "dmg": e.dmg, "ttl": 1.0})


func _tick_roamers(dt: float) -> void:  # FML-16, by day only
	for p in players.values():
		p.roam_t -= dt
		if p.roam_t > 0:
			continue
		p.roam_t = ROAM_CHECK
		if p.state != 0 or inside_base(p.pos) or _roamer_count() >= ROAM_MAX or enemies.size() > MAX_ENEMIES - 2:
			continue
		if rng.randf() < roam_chance(p.pos) * ROAM_MUL:
			_spawn_roamers(p)


static func roam_chance(pos: Vector2) -> float:
	var d := wall_dist(pos) / T  # tiles from the nearest base wall (FML-16)
	return ROAM_PMAX * clampf((d - ROAM_D0) / (ROAM_D1 - ROAM_D0), 0.0, 1.0)


func _spawn_roamers(p) -> void:
	# Just outside this player's camera view, on the side away from the base.
	var away: Vector2 = p.pos.normalized()
	var side := Vector2(-away.y, away.x)
	var at: Vector2 = p.pos + away * (VIEW_HALF.x + 2 * T) + side * rng.randf_range(-4.0, 4.0) * T
	if at.length() > ISLAND - 2 * T:  # the coast is behind the player: come from one side instead
		at = p.pos + side * (VIEW_HALF.x + 2 * T) * (1.0 if rng.randf() < 0.5 else -1.0)
	at = at.limit_length(ISLAND - 2 * T)
	for q in players.values():  # never pop in inside anyone's view
		if absf(q.pos.x - at.x) < VIEW_HALF.x + T and absf(q.pos.y - at.y) < VIEW_HALF.y + T:
			return
	for i in 2:
		var ty: int = SPITTER if k >= 4 and i == 1 and rng.randf() < 0.5 else GRUNT
		var e := _spawn(ty, _nearest_active_door(at), 0.0)  # stats of night k on day k
		e.pos = at + Vector2(i * 1.3 * T, 0)
		e.home = at
		e.wander = e.pos
		e.state = 4
	_note(p, "Something is moving out there...")


func _roamer_count() -> int:
	return enemies.filter(func(e): return e.has("home")).size()


func _wander(e, dt: float) -> void:
	if e.pos.distance_to(e.wander) < 4.0:
		e.wander = e.home + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 3.0) * T
	e.pos += (e.wander - e.pos).normalized() * minf(e.spd * 0.4 * dt, e.pos.distance_to(e.wander))
	e.pos = push_out(e.pos, e.r)


func _nearest_player(pos: Vector2, radius: float):
	var best = null
	var bd := radius
	for p in players.values():
		if p.state == 0 and not p.inside:
			var d: float = p.pos.distance_to(pos)
			if d <= bd:
				bd = d
				best = p
	return best


func _nearest_active_door(pos: Vector2) -> int:
	var best: int = active[0]
	for i in active:
		if pos.distance_to(DOOR_POS[i]) < pos.distance_to(DOOR_POS[best]):
			best = i
	return best


func _team_wiped() -> bool:
	return not players.is_empty() and players.values().filter(func(p): return p.state == 0).is_empty()


func _drop(e) -> void:  # BAL-41 / FML-15: independent roll per kill, boss always drops
	if e.type == BOSS:
		_add_drop(e.pos, "metal", 10)
		_add_drop(e.pos + Vector2(0.6 * T, 0), "bandage", 3)
		return
	var d: Array = DROPS[e.type]
	if rng.randf() < minf(1.0, d[0] * DROP_MUL):
		_add_drop(e.pos, d[1][rng.randi() % d[1].size()], rng.randi_range(d[2], d[3]))


func _add_drop(pos: Vector2, item: String, n: int) -> void:
	drops.append({"pos": pos, "item": item, "n": n, "ttl": DROP_TTL})


func _tick_drops(dt: float) -> void:  # MEC-23: walk over to collect, not from inside the base
	for d in drops:
		d.ttl -= dt
		for p in players.values():
			if d.ttl > 0 and p.state == 0 and not inside_base(p.pos) and p.pos.distance_to(d.pos) <= 0.8 * T:
				p.inv[d.item] += d.n
				_note(p, "+%d %s" % [d.n, d.item])
				d.ttl = 0.0
	drops = drops.filter(func(d): return d.ttl > 0)


func _tick_proj(dt: float) -> void:
	for b in proj:
		b.pos += b.vel * dt
		b.ttl -= dt
		for p in players.values():
			if p.state == 0 and p.pos.distance_to(b.pos) < 0.5 * T:
				_hurt(p, b.dmg)
				b.ttl = 0.0
				break
	proj = proj.filter(func(b): return b.ttl > 0)


func _tick_tele(dt: float) -> void:
	for tl in tele:
		tl.t -= dt
		if tl.t <= 0:
			for p in players.values():
				if p.pos.distance_to(tl.pos) <= tl.r:
					_hurt(p, tl.dmg)
	tele = tele.filter(func(tl): return tl.t > 0)


func _separate() -> void:
	# ponytail: O(n^2) push-apart, fine at the 60-enemy cap; spatial hash if the cap grows.
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			var a = enemies[i]
			var b = enemies[j]
			var d: Vector2 = b.pos - a.pos
			var min_d: float = a.r + b.r
			var l := d.length()
			if l < min_d and l > 0.01:
				var push := d / l * (min_d - l) * 0.5
				a.pos -= push
				b.pos += push


# --- helpers ------------------------------------------------------------

static func wall_dist(pos: Vector2) -> float:
	## Distance to the nearest base wall (0 inside); every zone distance in the GDD uses this.
	return Vector2(maxf(absf(pos.x) - HALF.x, 0.0), maxf(absf(pos.y) - HALF.y, 0.0)).length()


static func in_door_lane(pos: Vector2, half_width := 1.5 * T) -> bool:
	## The 3-tile corridor in front of each door that stays clear (section 4.3).
	for i in 3:
		var rel: Vector2 = pos - DOOR_POS[i]
		var dd: Vector2 = DOOR_DIR[i]
		if rel.dot(dd) > 0 and absf(rel.dot(Vector2(-dd.y, dd.x))) < half_width:
			return true
	return false


func _spawn_pos(door: int, dist_tiles: float, any_side: bool) -> Vector2:
	if not any_side:  # band 25-35 tiles in front of the door, up to 22 tiles to either side (fig. 4.1)
		var dd: Vector2 = DOOR_DIR[door]
		return DOOR_POS[door] + dd * dist_tiles * T + Vector2(-dd.y, dd.x) * rng.randf_range(-22.0, 22.0) * T
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var pos := dir * (dist_tiles * T + HALF.length())
	while wall_dist(pos) < dist_tiles * T:
		pos += dir * T
	return pos


func _rand_zone_point(lo: float, hi: float) -> Vector2:
	## Random point lo..hi from the nearest base wall, on the island, off the door lanes and pads.
	for i in 400:
		var p := Vector2(rng.randf_range(-ISLAND, ISLAND), rng.randf_range(-ISLAND, ISLAND))
		var d := wall_dist(p)
		if d >= lo and d <= hi and p.length() < ISLAND - 6 * T and not in_door_lane(p) and not _near_pad(p):
			return p
	return Vector2(0, HALF.y + lo)


func _near_pad(p: Vector2) -> bool:
	for i in 3:
		if p.distance_to(pad_pos(i)) < PAD_R + T:
			return true
	return false


static func inside_base(pos: Vector2, margin := 0.0) -> bool:
	return absf(pos.x) < HALF.x + margin and absf(pos.y) < HALF.y + margin


const WALL_IN := 12.0  # wall band: 12 px inside the base edge, 6 px outside
const WALL_OUT := 6.0
const DOOR_GAP := 1.2 * T  # half width of a door opening


static func walls(open: Array) -> Array:
	## Solid wall pieces; an open door (day, or broken) leaves a gap.
	var h := HALF
	var th := WALL_IN + WALL_OUT
	var top := Rect2(-h.x - WALL_OUT, -h.y - WALL_OUT, 2 * h.x + th, th)
	var bottom := Rect2(-h.x - WALL_OUT, h.y - WALL_IN, 2 * h.x + th, th)
	var left := Rect2(-h.x - WALL_OUT, -h.y - WALL_OUT, th, 2 * h.y + th)
	var right := Rect2(h.x - WALL_IN, -h.y - WALL_OUT, th, 2 * h.y + th)
	return [bottom] + _split(top, open[1], false) + _split(left, open[0], true) + _split(right, open[2], true)


static func _split(r: Rect2, open: bool, vertical: bool) -> Array:
	if not open:
		return [r]
	if vertical:
		return [Rect2(r.position.x, r.position.y, r.size.x, -DOOR_GAP - r.position.y),
			Rect2(r.position.x, DOOR_GAP, r.size.x, r.end.y - DOOR_GAP)]
	return [Rect2(r.position.x, r.position.y, -DOOR_GAP - r.position.x, r.size.y),
		Rect2(DOOR_GAP, r.position.y, r.end.x - DOOR_GAP, r.size.y)]


static func collide(pos: Vector2, radius: float, open: Array) -> Vector2:
	## Pushes a circle out of every wall piece (players only enter through doors).
	for w: Rect2 in walls(open):
		var q := pos.clamp(w.position, w.end)
		var d := pos - q
		var l := d.length()
		if l >= radius:
			continue
		if l > 0.001:
			pos = q + d / l * radius
		else:  # centre inside the wall: leave by the shortest axis
			var c := w.get_center()
			var e := w.size / 2 + Vector2(radius, radius)
			var o := pos - c
			if e.x - absf(o.x) < e.y - absf(o.y):
				pos.x = c.x + (1.0 if o.x >= 0 else -1.0) * e.x
			else:
				pos.y = c.y + (1.0 if o.y >= 0 else -1.0) * e.y
	return pos


static func _route(from: Vector2, to: Vector2, r: float) -> Vector2:
	## Next waypoint around the base: the goal if the way is clear, else the best visible corner.
	# ponytail: corner hopping around one rectangle; NavigationAgent2D once the map has obstacles.
	if not _blocked(from, to, r):
		return to
	var c := HALF + Vector2(r + T, r + T)
	var corners := [Vector2(c.x, c.y), Vector2(-c.x, c.y), Vector2(c.x, -c.y), Vector2(-c.x, -c.y)]
	var best := to
	var best_d := INF
	for corner: Vector2 in corners:
		if from.distance_to(corner) < 4.0 or _blocked(from, corner, r):
			continue
		var d := from.distance_to(corner) + _rest(corner, to, r, corners)
		if d < best_d:
			best_d = d
			best = corner
	return best


static func _rest(corner: Vector2, to: Vector2, r: float, corners: Array) -> float:
	## Distance left from a corner to the goal, with at most one more corner (enough for a rectangle).
	if not _blocked(corner, to, r):
		return corner.distance_to(to)
	var d := INF
	for c2: Vector2 in corners:
		if c2 != corner and not _blocked(corner, c2, r) and not _blocked(c2, to, r):
			d = minf(d, corner.distance_to(c2) + c2.distance_to(to))
	return d


static func _blocked(a: Vector2, b: Vector2, r: float) -> bool:
	var h := HALF + Vector2(r, r)
	var pts := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, pts[i], pts[(i + 1) % 4]) != null:
			return true
	return false


static func push_out(pos: Vector2, margin: float) -> Vector2:
	## Moves a point inside the (grown) base rectangle to its nearest edge.
	if not inside_base(pos, margin):
		return pos
	var dx := HALF.x + margin - absf(pos.x)
	var dy := HALF.y + margin - absf(pos.y)
	if dx < dy:
		pos.x = (HALF.x + margin) * (1.0 if pos.x >= 0 else -1.0)
	else:
		pos.y = (HALF.y + margin) * (1.0 if pos.y >= 0 else -1.0)
	return pos


static func pad_pos(i: int) -> Vector2:
	return DOOR_POS[i] + DOOR_DIR[i] * PAD_DIST


func _gen_nodes() -> void:
	nodes.clear()
	for type in 4:  # wood, stone, herb in the safe zone; metal only beyond 20 tiles (ITM-14, ITM-15)
		for i in (4 + 3 * n0) * NODE_MUL:
			var lo := 3 * T if type < 3 else SAFE_D + 3 * T
			var hi := SAFE_D - T if type < 3 else ISLAND
			nodes.append({"type": type, "pos": _rand_zone_point(lo, hi), "amount": 5})


func _pad_is_clear(i: int) -> bool:
	var pad := pad_pos(i)
	for e in enemies:
		if e.pos.distance_to(pad) < PAD_R:
			return false
	return true


func _enemy_inside() -> bool:
	for e in enemies:
		if e.state == 3 and inside_base(e.pos):
			return true
	return false


func _nearest_door(pos: Vector2) -> int:
	var best := 0
	for i in 3:
		if pos.dot(DOOR_DIR[i]) > pos.dot(DOOR_DIR[best]):
			best = i
	return best


func _teleport(p, pos: Vector2) -> void:
	p.pos = pos
	p.tp += 1


func _say(s: String) -> void:
	msg = s
	msg_t = 6.0


func _note(p, s: String) -> void:
	p.note = s
	p.note_t = 3.0
