class_name GameSim
extends RefCounted

# Owner: Pham Minh Hieu. Server-only match rules (GDD chapters 2-3): the public API used by the network
# (AddPlayer, RemovePlayer, Input, Action, Tick, Snapshot), core constants, match state and crafting.
# The rules themselves are static parts, one file per owner (src/gameplay/sim_*.gd, src/ai/sim_*.gd,
# src/world/sim_*.gd, src/match/sim_phases.gd); each takes the match as `sim` and starts with an Owner comment.
# Clients never run this; they get Snapshot().
static var DAY_MIN: float = GameplaySettings.get_current().day_min
const DAY_MAX = 360.0
static var DUSK: float = GameplaySettings.get_current().dusk_seconds
static var NIGHT_LEN = [420.0, 480.0, 420.0, 480.0, 480.0]
const BASE_HP = 1000.0
const DOOR_HP = 500.0
static var ROLES = ["Scout", "Healer", "Engineer"]
const SPEED = 5.0 * T
const SCOUT_NIGHT_SIGHT: float = 6.5 * T
static var ARMOUR = [0.0, 0.15, 0.3, 0.45]
static var MODES = ["Easy", "Medium", "Hard"]
static var MODE_MUL = [[0.75, 0.80, 0.75], [1.0, 1.0, 1.0], [1.25, 1.20, 1.25]]
static var RES = ["wood", "stone", "herb", "titanium"]
# Permanent equipment, healing and maintenance are craftable. Tactical buffs/traps are chest loot only.
static var RECIPES = [["Arrows", {"wood": 1}, 0, "arrow", 5, false], ["Stone spear", {"wood": 8, "stone": 12}, 0, "stone_spear", 1, false], ["Bow", {"wood": 8, "stone": 4}, 0, "bow", 1, false], ["Long spear", {"wood": 10, "stone": 8}, 0, "long_spear", 1, false], ["Titanium blade", {"wood": 10, "titanium": 20}, 2, "titanium_blade", 1, false], ["Stun maul", {"wood": 8, "titanium": 6}, 2, "stun_maul", 1, false], ["Explosive arrows", {"wood": 3, "stone": 4, "titanium": 2}, 2, "explosive_arrow", 3, false], ["Light armour", {"wood": 6}, 0, "light_armour", 1, false], ["Bandage", {"herb": 2}, 0, "bandage", 1, false], ["Revival kit", {"herb": 4, "titanium": 4}, 0, "revive", 1, false], ["Base repair", {"stone": 5}, 0, "base", 100, true], ["Stone armour", {"wood": 8, "stone": 16}, 0, "stone_armour", 1, false], ["Titanium armour", {"titanium": 24}, 2, "titanium_armour", 1, false], ["Healing flask", {"herb": 6, "titanium": 2}, 0, "healing_flask", 1, false], ["Field repair kit", {"wood": 4, "stone": 3, "titanium": 1}, 0, "repair_kit", 1, true], ["Chest key", {"wood": 2, "stone": 2}, 0, "chest_key", 1, false], ["Hammer", {"wood": 6, "stone": 4}, 0, "hammer", 1, false], ["Cargo frame", {"wood": 12, "stone": 6, "titanium": 2}, 0, "cargo_frame", 1, false]]
var world = WorldGeometry.new()
var phase = "lobby"
var t = 0.0
var elapsed = 0.0
var k = 1
var mode = 1
var base_hp = BASE_HP
var doors = [DOOR_HP, DOOR_HP, DOOR_HP]
var broken = [false, false, false]
var door_pause = [0.0, 0.0, 0.0]
var active = []
var players = {}
var order = []
var enemies = []
var proj = []
# players' arrows in flight (MEC-03)
var arrows = []
# seconds since the match started; FML-09 threat windows are measured with it
var clock = 0.0
var tele = []
var acid_pools = []
var boss_fx = []
var nodes = []
var drops = []
var votes = {}
var unlock = 0
var shown_unlock = 0
var bosses_killed = 0
var boss_dead = false
var wave = 0
var next_wave = 0.0
var carry = 0.0
var boss_spawned = false
var towers = [null, null, null]
var free_tower = true
var ext = -1.0
var pad_clear = [0.0, 0.0, 0.0]
var msg = ""
# door where the generator was last hit, for the loss cause on the result screen
var last_door = -1
# [win, cause, night reached] while the result screen shows
var result
var msg_t = 0.0
var next_id = 0
var n0 = 1
var rng = RandomNumberGenerator.new()

var collider_check_left: float = 0.0

const WALL_IN = 12.0
const WALL_OUT = 6.0
const DOOR_GAP = 1.2 * T

var bot_step_accumulator: float = 0.0

# Owner: Vu Duc Viet Anh. The seven NOX boss archetypes (AGT-05..11, table 4.2, BAL-36..39, BAL-43, FML-05).
# Bosses hunt the nearest living player within twice Scout night sight, then the nearest structure.
# Special wind-ups, dashes and burrowing commit briefly; there is no post-special recovery lock.
const JUGGERNAUT: int = 0
const CHAINWARDEN: int = 1
const BROODMOTHER: int = CHAINWARDEN # legacy ID for saved tools/atlas names
const BIO_CANNON: int = 2
const BURROWER: int = 3
const EARTHSHAKER: int = 4
const GATEBREAKER: int = EARTHSHAKER # legacy ID for saved tests / sprites
const PHANTOM: int = 5
const VOLTSPIRE: int = 6
const IRONHIDE: int = VOLTSPIRE # legacy ID for saved tests / sprites
# The bosses of nights 2 and 4, drawn when the match starts and announced at dawn of that day (FML-05).
var boss_plan = [0, 1]

# Owner: Vu Duc Viet Anh. Enemy drops (MEC-23, BAL-41, FML-15).
static var DROP_MUL: float = AiSettings.get_current().drop_multiplier
# Owner: Vu Duc Viet Anh. Wave director, enemy state machine, boss, projectiles (MEC-19/20, FML-01..05, BAL-29..39).
# AI decides targets and movement; damage to players goes through Hurt() in src/gameplay.
const MAX_ENEMIES = 70
const SPAWN_ALL_SIDES = false  # GDD 4.3 / BAL-34: waves spawn 25-35 tiles out in a band in front of each active door
static var FIRST_WAVE_DELAY: float = AiSettings.get_current().first_wave
const GRUNT: int = 0
const SPITTER: int = 1
const WRECKER: int = 2
const BOSS: int = 3
static var ENEMY = [[55.0, 6.0, 2.0, 8, 1], [38.0, 6.0, 2.0, 12, 2], [95.0, 8.0, 1.6, 16, 3]]  # hp, damage per hit, speed tiles/s, cost, first night

var enemy_batch = []
var audio_sequence: int = 0
var audio_events: Array = []

# reused every tick by Separate()
var sep_cells = {}
var sep_pairs = []
var sep_seen = {}
var sep_pos = Cs.arr(0, Vector2.ZERO)
var sep_r = Cs.arr(0, 0.0)

var limit_enemy_navigation: bool = false
var enemy_think_cursor: int = 0
var enemy_step_accumulator: float = 0.0
var enemy_body_interval: float = 0.05

var enemy_body_steps: int = 0

var enemy_navigation_updates_this_tick: int = 0

# A wave is a bounded budget, not a queue of allocated enemies. Only one body is made when due.
var pending_wave_budget: float = 0.0
# A wave is a bounded budget, not a queue of allocated enemies. Only one body is made when due.
var next_enemy_spawn_at: float = 0.0
# A wave is a bounded budget, not a queue of allocated enemies. Only one body is made when due.
var wave_spawn_ends_at: float = 0.0
var wave_spawn_ordinal: int = 0
var night_index: int:
	get:
		return clampi(int(k) - 1, 0, 4)

var night_first_wave_delay: float:
	get:
		return maxf(0, AiSettings.get_current().early_night_first_wave if night_index == 0 else (AiSettings.get_current().early_night_first_wave + FIRST_WAVE_DELAY) * 0.5 if night_index == 1 else FIRST_WAVE_DELAY)

var night_wave_interval: float:
	get:
		return maxf(10, AiSettings.get_current().early_night_wave_interval if night_index == 0 else (AiSettings.get_current().early_night_wave_interval + SimNightSpawns.WAVE_INTERVAL) * 0.5 if night_index == 1 else SimNightSpawns.WAVE_INTERVAL if night_index == 2 else SimNightSpawns.WAVE_INTERVAL * (5.0 / 6.0) if night_index == 3 else SimNightSpawns.FINAL_WAVE_INTERVAL)

var night_spawn_spacing: float:
	get:
		return maxf(0.25, SimNightSpawns.SPAWN_GAP[night_index] * AiSettings.get_current().spawn_spacing / 6.0)

var night_enemy_limit: int:
	get:
		return clampi(mini(SimNightSpawns.NIGHT_ALIVE_CAP[night_index], AiSettings.get_current().max_night_enemies), 1, int(MAX_ENEMIES))
# Each night has a fixed number of enemies (its quota), worked out at nightfall from the budgets of the waves the
# night has time for, plus the boss on nights 2 and 4. The HUD bar fills as they die; once all of them are dead
# the night is over and dawn comes early (CheckEnd). While the field is empty the next wave does not keep the
# players waiting, so a strong team clears the night sooner. The night's clock stays the upper limit.
var night_quota: int = 0
# Each night has a fixed number of enemies (its quota), worked out at nightfall from the budgets of the waves the
# night has time for, plus the boss on nights 2 and 4. The HUD bar fills as they die; once all of them are dead
# the night is over and dawn comes early (CheckEnd). While the field is empty the next wave does not keep the
# players waiting, so a strong team clears the night sooner. The night's clock stays the upper limit.
var night_spawned: int = 0
var regular_quota: int = 0
# when the boss of nights 2 and 4 comes (seconds into the night), unless the field is cleared before
const BOSS_AT: float = 150.0
var boss_at: float = BOSS_AT
# the boss of nights 2 and 4 has been killed tonight (the night still ends only with its quota and supplies)
var boss_down_tonight: bool = false

var boss_night: bool:
	get:
		return int(k) == 2 or int(k) == 4

const ROAM_CHECK = 8.0
const ROAM_MAX = 14
var chest_roam_scan_left: float = 0.0
var chest_roam_spawn_left: float = 0.0
var construction = []

# Owner: Pham Minh Hieu. Items, the 8-slot inventory with its 4-slot hotbar, shared base storage,
# giving, dropping and picking up (MEC-09, BAL-18, ITM-01..13).
const INV_SLOTS: int = 8
const HOTBAR: int = 4
static var BAG_ITEMS = ["", "cargo_frame"]
static var BAG_BONUS = [0, 4]
const STORAGE_SLOTS: int = 40
# id -> [name, stack size, kind]; kind is res, use, ammo, weapon, tool, armour, bag or quest.
static var ITEMS = {"wood": ["Wood", SimInventory.STACK, "res"], "stone": ["Stone", SimInventory.STACK, "res"], "herb": ["Herb", SimInventory.STACK, "res"], "titanium": ["Titanium", SimInventory.STACK, "res"], "bandage": ["Bandage", SimInventory.STACK, "use"], "arrow": ["Arrow", SimInventory.STACK, "ammo"], "revive": ["Revival kit", 3, "use"], "long_spear": ["Long spear", 1, "weapon"], "stun_maul": ["Stun maul", 1, "weapon"], "vine_trap": ["Vine trap", 5, "use"], "poison_flask": ["Poison flask", 5, "use"], "healing_flask": ["Healing flask", 5, "use"], "haste_tonic": ["Haste tonic", 5, "use"], "chest_key": ["Chest key", 10, "tool"], "explosive_arrow": ["Explosive arrow", 12, "ammo"], "repair_kit": ["Field repair kit", 3, "use"], "stone_spear": ["Stone spear", 1, "weapon"], "titanium_blade": ["Titanium blade", 1, "weapon"], "starter_bow": ["Starter bow", 1, "weapon"], "bow": ["Bow", 1, "weapon"], "hammer": ["Hammer", 1, "weapon"], "light_armour": ["Light armour", 1, "armour"], "stone_armour": ["Stone armour", 1, "armour"], "titanium_armour": ["Titanium armour", 1, "armour"], "cargo_frame": ["Cargo frame", 1, "bag"], "battery_cells": ["Radio battery", 1, "quest"], "antenna_assembly": ["Antenna assembly", 1, "quest"], "locator_circuit": ["Locator circuit", 1, "quest"]}
# id -> [damage, attacks per second, reach or range in tiles, ranged, uses arrows] (BAL-08..10, BAL-42)
const WEAPON_ATTACK_SPEED: float = 1.5
const WEAPON_SWING_TIME: float = 0.25 / WEAPON_ATTACK_SPEED
static var WEAPON_STATS = {"long_spear": [24.0, 1.0, 2.6, false, false], "stun_maul": [42.0, 0.65, 1.5, false, false], "fists": [11.0, 1.5, 1.5, false, false], "stone_spear": [16.0, 1.5, 1.5, false, false], "titanium_blade": [22.0, 1.5, 1.5, false, false], "hammer": [13.0, 1.2, 1.5, false, false], "starter_bow": [10.0, 1.0, 8.0, true, false], "bow": [18.0, 1.0, 8.0, true, true]}
# armour items by tier; ARMOUR holds the matching values (BAL-11)
static var ARMOUR_ITEMS = ["", "light_armour", "stone_armour", "titanium_armour"]
# Team storage inside the base (BAL-18).
var storage = SimInventory.empty_slots(STORAGE_SLOTS)

# Owner: Pham Minh Hieu. Player actions: movement credit, combat, gather/repair/revive, healing (MEC-01..13).
# Crafting takes CRAFT_TIME at the workbench (BAL-19); base repair runs at 20 HP/s (BAL-20).
const CRAFT_TIME: float = 3.0
const ARROW_SPEED: float = 16.0  # tiles/s

# Small bounded lists, checked at 4 Hz (traps) / 2 Hz (areas), without physics nodes or navigation changes.
var tactical_areas = []
var vine_traps = []
var next_trap_check: float = 0.0
var poisoned = {}
var healed = {}
const MAX_TACTICAL_AREAS: int = 16
# Owner: Pham Minh Hieu. Defence towers: placing, shooting, light (AGT-12, MEC-11, MEC-28, BAL-28).
# Team change: a tower goes anywhere outside the base except on a landing pad (was 3-8 tiles in front of a door).
const TOWER_HP = 300.0
const TOWER_RANGE = 6.0 * T
const TOWER_LIGHT = 6.0 * T
static var TOWER_COST = {"wood": 10, "titanium": 5}
# the team has this many tower slots (a wrecked tower keeps its slot and can be repaired)
const MAX_TOWERS: int = 3
# the tower's footprint (its collider, WorldGeometry.DynamicColliders)
const TOWER_R: float = 0.7

# Owner: Pham Minh Hieu. Engineer construction from the build menu (B): wood and stone walls (ITM-07, ITM-11,
# MEC-11, BAL-27). A wall is 3 tiles long and 1 tile thick; enemies whose way it blocks attack it.
# kind -> [name, cost, unlock tier, HP]
static var WALL_KINDS = {"wood": ["Wood wall", {"wood": 5}, 0, 200.0], "stone": ["Stone wall", {"stone": 5}, 1, 400.0]}
const BUILD_REACH: float = 5.0  # tiles from the Engineer
const WALL_DOOR_GAP: float = 3.0  # BAL-27: no wall within 3 tiles of a door
var built_walls = []

# MEC-17 / BAL-25: once no door is broken, players inside (other than the Engineer who entered) get a
# 5 s warning and are then moved to the nearest door.
var breach_end_t = -1.0

static var SUPPLY_NAMES = ["Radio battery", "Antenna assembly", "Locator circuit"]
static var COMPONENT_IDS = ["battery_cells", "antenna_assembly", "locator_circuit"]
const EXPLORATION_CHEST_SLOTS: int = 8
const CHEST_UNLOCK_TIME: float = 2.0
const CHEST_REACH: float = 44.0
static var CHEST_SUPPORT = ["vine_trap", "poison_flask", "haste_tonic"]
var exploration_chests = []
var rescue_components = Cs.arr(3, 0)
var radio_parts_placed = Cs.arr(3, 0)
var radio_built: bool = false
var radio_builder
var radio_build_t: float = 0.0
var radio_build_pos: Vector2 = Vector2.ZERO
var radio_build_damage: float = 0.0
var chest_scenery = []
var chest_resources = []
# Owner: Vu Duc Viet Anh. Island and base geometry, collision, navigation and resource nodes (shared by every peer).
const T: float = 32.0  # pixels per tile; const so every partial file can use it in its static fields
const HALF = Vector2(5.5, 3.5) * T
const SAFE_D = 20.0 * T
# how far the island reaches from the outpost; its real outline (and the sea) is src/world/IslandMap.cs
const ISLAND = 126.0 * T
static var DOOR_DIR = [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)]
static var DOOR_POS = [Vector2(-HALF.x, 0), Vector2(0, -HALF.y), Vector2(HALF.x, 0)]
static var DOOR_NAMES = ["A", "B", "C"]
const PAD_DIST = 5.5 * T
const PAD_R = 4.0 * T
static var NODE_MUL: int = WorldSettings.get_current().node_multiplier
# Workbench and shared storage flank the north door. The dedicated radio table stands southeast,
# clear of the lighthouse and door lanes. Each point is the middle of the furniture's front edge.
const WORKBENCH_POS: Vector2 = Vector2(-3.2, -2.0) * T
const STORAGE_POS: Vector2 = Vector2(3.3, -2.0) * T
const RADIO_POS: Vector2 = Vector2(3.0, 1.25) * T
const RADIO_REACH: float = 1.5 * T
# how close you have to stand to use them
const BENCH_REACH: float = 2.2 * T
var harvest_snapshot_source
var harvest_snapshot = []
var harvest_snapshot_state = []

func leader() -> Variant:
	return order[0] if order.size() > 0 else 0

func add_player(id, pname, role) -> void:
	# ponytail: no joining mid-match (GDD: rejoin is out of scope).
	if phase != "lobby" or players.size() >= 5 or players.has(id):
		return
	players[id] = {"id": id, "name": pname.substr(0, 16), "role": clampi(role, 0, 2), "pos": Vector2.ZERO, "tp": 0, "bot": false}
	order.append(id)
	SimPlayers.reset_player(self, players[id])

func remove_player(id) -> void:
	var leaving = players.get(id, null)
	if leaving != null:
		SimSupplies.cancel_chest_unlock(self, leaving)
		for part_id in COMPONENT_IDS:
			if SimInventory.take(self, leaving, part_id, 1):
				SimInventory.player_drop(self, leaving.pos, part_id, 1)
	players.erase(id)
	order.erase(id)
	votes.erase(id)
	if self.humans() == 0:
		for b in players.keys():
			players.erase(b)
			order.erase(b)
		if phase != "lobby":
			SimPhases.to_lobby(self)

func humans() -> Variant:
	return players.values().filter(func(p): return not p.bot).size()

func input(id, pos, aim, atk, inter, ent, tp, sequence = null) -> void:
	if sequence == null: sequence = 0
	var p = players.get(id)
	if p == null or not pos.is_finite() or not is_finite(aim):
		return
	if sequence > 0 and sequence <= p.input_sequence:
		return
	p.input_sequence = sequence
	if SimPlayers.is_reacting(p):
		p.atk = false
		p.inter = false
		p.ent = false
		return
	p.aim = aim
	p.atk = atk
	p.inter = inter
	p.ent = ent
	if tp == p.tp and p.state == 0:
		var travel: Vector2 = Vector2((pos - p.pos).limit_length(p.move_credit))
		p.move_credit = maxf(0.0, p.move_credit - travel.length())
		p.pos = SimWorld.move_actor(self, p.pos, p.pos + travel, 0.3 * T)
		for e in enemies:
			var delta: Vector2 = Vector2(p.pos - e.pos)
			var need: float = float(0.3 * T + e.r * 0.6)
			if delta.length_squared() < need * need:
				p.pos = e.pos + (delta.normalized() if delta.length_squared() > 0.001 else Vector2.DOWN) * need
		p.pos = SimWorld.move_actor(self, p.pos, p.pos, 0.3 * T)
		# at night only the Engineer (MEC-15) or a breach (MEC-16) lets anyone in; players caught inside
		# when a breach ends are moved out by TickBreachEnd after a warning (MEC-17)
		if phase == "night" and not p.inside and not SimPhases.any_breach(self) and not SimWorld.inside_base(p.pos):
			p.pos = SimWorld.push_out(p.pos, 0.4 * T)

func action(id, kind, arg) -> void:
	var p = players.get(id)
	if p == null:
		return
	if SimPlayers.is_reacting(p) and not kind in ["select", "lobby", "cancel_craft"]:
		return
	if kind == "role":
		if phase == "lobby":
			p.role = clampi(int(arg), 0, 2)
			SimPlayers.reset_player(self, p)
	elif kind == "mode":
		if phase == "lobby" and id == self.leader():
			mode = clampi(int(arg), 0, 2)
	elif kind == "start":
		if phase == "lobby" and id == self.leader():
			var err = self.start_match()
			if err != "":
				SimPlayers.say(self, err)
	elif kind == "add_bot":
		if id == self.leader():
			Bots.add(self)
	elif kind == "remove_bot":
		if id == self.leader():
			Bots.remove(self)
	elif kind == "craft":
		SimPlayers.craft(self, p, int(arg))
	elif kind == "radio_open":
		pass  # Opening the radio station panel no longer auto-installs parts; players deposit carried parts explicitly.
	elif kind == "radio_insert":
		var part_idx: int = -1 if arg == null else int(arg)
		SimSupplies.insert_radio_part(self, p, part_idx)
	elif kind == "radio_repair":
		SimSupplies.try_build_radio(self, p, 0)
	elif kind == "tower":
		SimTowers.build_tower(self, p)
	elif kind == "build":
		SimWalls.build(self, p, arg)
	elif kind == "lobby":
		# result screen: Back to lobby (section 2.5)
		if phase == "result":
			SimPhases.to_lobby(self)
	elif kind == "bandage":
		if p.state == 0 and SimPlayers.is_poisoned(self, p):
			SimPlayers.note(self, p, "Poisoned: cannot heal")
		elif p.state == 0 and SimInventory.count(self, p, "bandage") > 0 and p.hp < p.maxhp and p.channel <= 0:
			p.channel = 2.0
	elif kind == "select":
		p.sel = clampi(int(arg), 0, HOTBAR - 1)
	elif kind == "move_item":
		SimInventory.move_slot(self, p, arg)
	elif kind == "open_chest":
		SimSupplies.open_chest_panel(self, p, int(arg))
	elif kind == "give":
		SimInventory.give_or_drop(self, p)
	elif kind == "cancel_craft":
		p.craft_idx = -1
	elif kind == "use_item":
		if arg is Vector2:
			SimTacticalItems.use_selected_item(self, p, Vector2(arg))
	elif kind == "use_healing_flask":
		if arg is Vector2:
			SimTacticalItems.use_tactical_item(self, p, "healing_flask", arg)
	elif kind == "vote":
		if phase == "day":
			if votes.has(id):
				votes.erase(id)
			else:
				votes[id] = true
	elif kind == "skip":
		if id == 1 and OS.is_debug_build() and phase in ["day", "dusk", "night"]:
			enemies.clear()
			t = 0.0

func start_match() -> Variant:
	var eng = false
	for p in players.values():
		if p.role == 2:
			eng = true
	if not eng:
		return "Need at least one Engineer"
	# ponytail: GDD wants 3-5 players, all Ready (BAL-01, card H08); 1+ allowed until the Ready lobby exists.
	rng.randomize()
	n0 = players.size()
	k = 1
	base_hp = BASE_HP
	doors = [DOOR_HP, DOOR_HP, DOOR_HP]
	unlock = 0
	towers = [null, null, null]
	free_tower = true
	SimConstruction.cancel_all_construction(self)
	shown_unlock = 0
	bosses_killed = 0
	enemies.clear()
	proj.clear()
	chest_roam_scan_left = 0.0
	chest_roam_spawn_left = 0.0
	arrows.clear()
	SimTacticalItems.reset_tactical_items(self)
	tele.clear()
	acid_pools.clear()
	boss_fx.clear()
	drops.clear()
	storage = SimInventory.empty_slots(STORAGE_SLOTS)
	built_walls = []
	clock = 0.0
	last_door = -1
	SimBosses.draw_bosses(self)
	SimWorld.gen_nodes(self)
	for p in players.values():
		SimPlayers.reset_player(self, p)
	SimPhases.dawn(self)
	world.rebuild(nodes, towers, built_walls)
	SimSupplies.place_supplies(self)
	return ""

func tick(dt) -> void:
	if phase == "lobby":
		return
	t -= dt
	msg_t -= dt
	clock += dt
	if phase == "result":
		return
	for i in 3:
		door_pause[i] -= dt
	collider_check_left -= float(dt)
	if collider_check_left <= 0:
		world.rebuild(nodes, towers, built_walls)
		collider_check_left = 0.1
	tick_bots(float(dt))
	SimPlayers.tick_players(self, dt)
	if phase == "night":
		elapsed += dt
		SimEnemies.tick_waves(self)
	elif phase == "day":
		SimRoamers.tick_roamers(self, dt)
	SimTacticalItems.tick_tactical_items(self)
	SimEnemies.tick_enemy_simulation(self, float(dt))
	SimTowers.tick_towers(self, dt)
	SimEnemies.tick_proj(self, dt)
	SimPlayers.tick_arrows(self, dt)
	SimEnemies.tick_tele(self, dt)
	SimBosses.tick_acid_pools(self)
	SimBossSkills.tick_boss_fx(self, float(dt))
	SimDrops.tick_drops(self, dt)
	if phase == "night":
		SimPhases.tick_breach_end(self, dt)
		SimPhases.check_end(self, dt)
		return
	if SimPhases.team_wiped(self):
		SimPhases.end(self, false, "Team wiped")
	elif phase == "day":
		if t <= 0 or DAY_MAX - t >= DAY_MIN and votes.size() >= ceili(0.6 * self.humans()):
			SimPhases.dusk(self)
	elif phase == "dusk" and t <= 0:
		SimPhases.night(self)

# Player array layout: 0 name, 1 role, 2 pos, 3 hp, 4 maxhp, 5 state, 6 bleed, 7 inventory slots, 8 weapon id,
# 9 armour tier, 10 reserved (0), 11 swinging, 12 aim, 13 bandage channel, 14 revive progress, 15 teleport count,
# 16 note, 17 kills, 18 damage dealt, 19 inside, 20 entry, 21 gather, 22 activity, 23 activity target,
# 24 input ack, 25 selected hotbar slot, 26 craft recipe (-1 none), 27 craft progress 0..1, 28 revives, 29 damage taken,
# 30 haste active, 31 field repair seconds remaining. Enemy fields 10/11: rooted or stunned / slowed.
# Enemy fields 12/13: special seconds remaining / seconds since the last ground-slam impact.
# Visual attack identity is separate from the stable 36-field player snapshot.
func snapshot_attack_poses() -> Dictionary:
	var poses: Dictionary = {}
	for id in players:
		var p = players[id]
		poses[id] = [int(p.get("attack_sequence", 0)), Cs.s(p.get("attack_item", "")), float(p.get("attack_aim", 0.0))]
	return poses

func snapshot_hit_reactions() -> Dictionary:
	var reactions: Dictionary = {}
	for id in players:
		var p = players[id]
		if SimPlayers.is_reacting(p):
			reactions[id] = [int(p.hit_sequence), Cs.s(p.hit_kind), maxf(0, clock - float(p.hit_started)), float(p.hit_duration), Vector2(p.hit_direction)]
	return reactions

func snapshot_poisoned() -> Dictionary:
	var out: Dictionary = {}
	for id in players:
		var p = players[id]
		if SimPlayers.is_poisoned(self, p):
			out[id] = maxf(0.0, float(p.poison_until) - float(clock))
	return out

func snapshot_slowed() -> Dictionary:
	var out: Dictionary = {}
	for id in players:
		var p = players[id]
		if SimPlayers.is_slowed(self, p):
			out[id] = maxf(0.0, float(p.slow_until) - float(clock))
	return out

func snapshot_rooted() -> Dictionary:
	var out: Dictionary = {}
	for e in enemies:
		if float(e.get("root_until", 0.0)) > float(clock):
			out[e.id] = maxf(0.0, float(e.root_until) - float(clock))
	return out

func snapshot() -> Variant:
	var ps = {}
	for id in players:
		var p = players[id]
		ps[id] = [p.name, p.role, p.pos, p.hp, p.maxhp, p.state, p.bleed, p.inv, p.weapon, p.armour, 0, p.swing > 0, p.aim, p.channel, p.revive_p, p.tp, p.note if p.note_t > 0 else "", p.kills, p.dmg, p.inside, p.entry, p.gather_acc, p.activity, p.activity_target, p.input_sequence, p.sel, p.craft_idx, p.craft_t / SimPlayers.player_craft_duration(self, p, int(p.craft_idx)) if p.craft_idx >= 0 else 0.0, p.revives, p.taken, p.get("haste_until", 0.0) > clock, p.get("repair_kit_t", 0.0), p.open_chest, p.unlock_chest, float(p.unlock_t) / CHEST_UNLOCK_TIME, p.chest_use_seq]
	return {"audio": audio_events.duplicate(), "ph": phase, "t": t, "k": k, "base": base_hp, "doors": doors, "active": active, "ps": ps, "attack_pose": snapshot_attack_poses(), "hit_reactions": snapshot_hit_reactions(), "poisoned": snapshot_poisoned(), "slowed": snapshot_slowed(), "rooted": snapshot_rooted(), "en": enemies.map(func(e): return [e.id, e.type, e.pos, e.hp, e.maxhp, e.r, e.get("kind", -1), SimBosses.boss_look(self, e), e.get("face", 0.0), e.get("swing", 0.0) > 0, e.get("stun_until", 0.0) > clock, e.get("slow_until", 0.0) > clock, float(e.get("act_t", 0.0)), clock - float(e.get("slam_at", -99.0))]), "chains": SimChainwarden.snapshot(self), "proj": proj.map(func(b): return [b.pos, b.get("kind", "spit"), Vector2(b.vel).angle()]), "tele": tele.filter(func(tl): return not tl.get("hidden", false)).map(func(tl): return [tl.pos, tl.r, tl.t / tl.dur, tl.kind, tl.end, tl.ang, tl.spread, tl.get("acid_from", null), tl.get("fx_style", ""), tl.get("ring_inner", 0.0)]), "acid_pools": SimBosses.acid_pools_snapshot(self), "boss_fx": SimBossSkills.snapshot(self), "nodes": snapshot_nodes(), "drops": drops.map(func(d): return [d.pos, d.item, d.n, d.ttl]), "msg": msg if msg_t > 0 or phase == "result" else "", "unlock": unlock, "votes": votes.size(), "need": ceili(0.6 * self.humans()), "leader": self.leader(), "mode": mode, "ext": ext, "pads": pad_clear, "broken": broken, "dpause": door_pause.map(func(v): return v > 0), "inside_en": SimPhases.enemy_inside(self), "tw": towers.filter(func(tw): return tw != null).map(func(tw): return [tw.slot, tw.pos, tw.hp, tw.wrecked, tw.target != null, tw.target if tw.target != null else Vector2.ZERO]), "free_tower": free_tower, "nq": [SimNightSpawns.night_killed(self), night_quota], "sup": SimSupplies.supply_snapshot(self), "chests": SimSupplies.chest_contents_snapshot(self), "rescue": SimSupplies.rescue_snapshot(self), "construction": SimConstruction.construction_snapshot(self), "boss_next": SimBosses.boss_kind_for(self, k) if k == 2 or k == 4 else -1, "sto": storage, "walls": built_walls.map(func(w): return [w.pos, w.vert, w.hp, w.maxhp, w.kind]), "result": result, "tactical": SimTacticalItems.tactical_snapshot(self), "arrows": arrows.map(func(a): return [a.pos, a.vel.angle(), a.get("explosive", false)])}

func tick_bots(dt: float) -> void:
	bot_step_accumulator += dt
	if bot_step_accumulator < 0.05 - 0.000001:
		return
	Bots.tick(self, bot_step_accumulator)
	bot_step_accumulator = 0

# Most resources are unchanged between snapshots; reuse their immutable records instead of allocating
# hundreds of dictionaries/arrays every 50 ms now that the whole forest can be gathered.
func snapshot_nodes() -> Variant:
	var current = nodes
	if not is_same(current, harvest_snapshot_source) or current.size() != harvest_snapshot_state.size():
		harvest_snapshot_source = current
		harvest_snapshot = []
		harvest_snapshot_state.clear()
	var i: int = 0
	while i < current.size():
		var n = current[i]
		var state = [int(n.get("type")), Vector2(n.get("pos")), int(n.get("amount")), Cs.s(n.get("sprite", "")), Harvestables.radius(n)]
		if i < harvest_snapshot_state.size() and harvest_snapshot_state[i] == state:
			i += 1
			continue
		var record = [state[0], state[1], state[2], state[3], state[4]]
		if i < harvest_snapshot_state.size():
			harvest_snapshot_state[i] = state
			harvest_snapshot[i] = record
		else:
			harvest_snapshot_state.append(state)
			harvest_snapshot.append(record)
		i += 1
	return harvest_snapshot

# --- the parts' functions that other scripts call on GameSim ---
func draw_bosses() -> void:
	SimBosses.draw_bosses(self)

func boss_act(e, act, time: float) -> void:
	SimBosses.boss_act(self, e, act, time)

func boss_look(e) -> Variant:
	return SimBosses.boss_look(self, e)

func drop(e) -> void:
	SimDrops.drop(self, e)

func add_drop(pos, item, n) -> void:
	SimDrops.add_drop(self, pos, item, n)

func tick_waves() -> void:
	SimEnemies.tick_waves(self)

func spawn_wave() -> void:
	SimEnemies.spawn_wave(self)

func spawn(ty, door, dist_tiles, any_side = null) -> Variant:
	return SimEnemies.spawn(self, ty, door, dist_tiles, any_side)

func spawn_boss() -> void:
	SimEnemies.spawn_boss(self)

func boss() -> Variant:
	return SimEnemies.boss(self)

func tick_enemy_simulation(dt: float) -> void:
	SimEnemies.tick_enemy_simulation(self, dt)

func tick_enemies(dt) -> void:
	SimEnemies.tick_enemies(self, dt)

func nearest_active_door(pos) -> Variant:
	return SimEnemies.nearest_active_door(self, pos)

func tick_proj(dt) -> void:
	SimEnemies.tick_proj(self, dt)

func night_killed() -> int:
	return SimNightSpawns.night_killed(self)

func night_all_down() -> bool:
	return SimNightSpawns.night_all_down(self)

func spawn_roamers(p) -> void:
	SimRoamers.spawn_roamers(self, p)

func wander(e, dt) -> void:
	SimRoamers.wander(self, e, dt)

func tick_tower_construction(p, dt: float) -> bool:
	return SimConstruction.tick_tower_construction(self, p, dt)

func count(p, id) -> int:
	return SimInventory.count(self, p, id)

func room(p, id) -> int:
	return SimInventory.room(self, p, id)

func add_item(p, id, n) -> void:
	SimInventory.add_item(self, p, id, n)

func set_count(p, id, n) -> void:
	SimInventory.set_count(self, p, id, n)

func weapon_of(p) -> Variant:
	return SimInventory.weapon_of(self, p)

func armour_tier(p) -> int:
	return SimInventory.armour_tier(self, p)

func move_slot(p, arg) -> void:
	SimInventory.move_slot(self, p, arg)

func pick_up(p) -> bool:
	return SimInventory.pick_up(self, p)

func at_bench(p) -> bool:
	return SimPlayers.at_bench(self, p)

func can_craft(p, idx: int, tell: bool = true) -> bool:
	return SimPlayers.can_craft(self, p, idx, tell)

func player_craft_duration(p, idx: int) -> float:
	return SimPlayers.player_craft_duration(self, p, idx)

func craft(p, idx) -> void:
	SimPlayers.craft(self, p, idx)

func tick_craft(p, dt) -> void:
	SimPlayers.tick_craft(self, p, dt)

func finish_craft(p, idx: int) -> void:
	SimPlayers.finish_craft(self, p, idx)

func reset_player(p) -> void:
	SimPlayers.reset_player(self, p)

func tick_players(dt) -> void:
	SimPlayers.tick_players(self, dt)

func attack(p) -> void:
	SimPlayers.attack(self, p)

func tick_arrows(dt) -> void:
	SimPlayers.tick_arrows(self, dt)

func threat(e, pid) -> float:
	return SimPlayers.threat(self, e, pid)

func retarget(e) -> void:
	SimPlayers.retarget(self, e)

func hit(e, dmg, p) -> void:
	SimPlayers.hit(self, e, dmg, p)

func interact(p, dt) -> void:
	SimPlayers.interact(self, p, dt)

func hurt(p, dmg) -> void:
	SimPlayers.hurt(self, p, dmg)

func note(p, s) -> void:
	SimPlayers.note(self, p, s)

func player_speed(p) -> float:
	return SimTacticalItems.player_speed(self, p)

func reset_tactical_items() -> void:
	SimTacticalItems.reset_tactical_items(self)

func use_tactical_item(p, id, aim_point: Vector2) -> bool:
	return SimTacticalItems.use_tactical_item(self, p, id, aim_point)

func tick_tactical_items() -> void:
	SimTacticalItems.tick_tactical_items(self)

func tick_field_repair(p, dt: float) -> bool:
	return SimTacticalItems.tick_field_repair(self, p, dt)

func free_tower_spot(door: int) -> Vector2:
	return SimTowers.free_tower_spot(self, door)

func build_tower(p, at = null) -> void:
	SimTowers.build_tower(self, p, at)

func place_tower(slot, pos) -> void:
	SimTowers.place_tower(self, slot, pos)

func tick_towers(dt) -> void:
	SimTowers.tick_towers(self, dt)

func dawn() -> void:
	SimPhases.dawn(self)

func night() -> void:
	SimPhases.night(self)

func end(win, why) -> void:
	SimPhases.end(self, win, why)

func to_lobby() -> void:
	SimPhases.to_lobby(self)

func check_end(dt) -> void:
	SimPhases.check_end(self, dt)

func enemy_inside() -> Variant:
	return SimPhases.enemy_inside(self)

func teleport(p, pos) -> void:
	SimPhases.teleport(self, p, pos)

func supplies_got() -> int:
	return SimSupplies.supplies_got(self)

func supplies_all_in() -> bool:
	return SimSupplies.supplies_all_in(self)

func place_supplies() -> void:
	SimSupplies.place_supplies(self)

func chest_by_id(id: int) -> Variant:
	return SimSupplies.chest_by_id(self, id)

func can_access_chest(p, c) -> bool:
	return SimSupplies.can_access_chest(self, p, c)

func try_loot_chest(p, dt: float = 0.05) -> bool:
	return SimSupplies.try_loot_chest(self, p, dt)

func chest_contents_snapshot() -> Variant:
	return SimSupplies.chest_contents_snapshot(self)

func try_build_radio(p, dt: float) -> bool:
	return SimSupplies.try_build_radio(self, p, dt)

func supply_snapshot() -> Variant:
	return SimSupplies.supply_snapshot(self)

func line_clear(a, b, ignore = null) -> Variant:
	return SimWorld.line_clear(self, a, b, ignore)

func move_actor(from, to, radius) -> Variant:
	return SimWorld.move_actor(self, from, to, radius)

func navigate(from, to, radius, outside = null) -> Variant:
	return SimWorld.navigate(self, from, to, radius, outside)
