class_name SimTowers
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/gameplay/GameSim.Towers.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
const TOWER_DPS = 8.0

# constants shared with GameSim
const BOSS = GameSim.BOSS
const BUILD_REACH = GameSim.BUILD_REACH
const MAX_TOWERS = GameSim.MAX_TOWERS
const PAD_DIST = GameSim.PAD_DIST
const PAD_R = GameSim.PAD_R
const T = GameSim.T
const TOWER_HP = GameSim.TOWER_HP
const TOWER_LIGHT = GameSim.TOWER_LIGHT
const TOWER_R = GameSim.TOWER_R
const TOWER_RANGE = GameSim.TOWER_RANGE
const WALL_DOOR_GAP = GameSim.WALL_DOOR_GAP

# --- towers (AGT-12, MEC-11, MEC-28) -------------------------------------
# A tower goes anywhere outside the base on open land, except on a helicopter landing pad (FML-13) and
# right in front of a door. Returns "" when the spot is fine, else what is wrong.
static func tower_spot_problem(pos: Vector2, world_) -> Variant:
	if SimWorld.inside_base(pos, TOWER_R * T):
		return "Towers go outside the base"
	for i in 3:
		if pos.distance_to(Vector2(SimWorld.pad_pos(i))) < float(PAD_R) + TOWER_R * T:
			return "Keep the landing pads clear"
		if pos.distance_to(Vector2(GameSim.DOOR_POS[i])) < WALL_DOOR_GAP * T:
			return "Too close to a door (3 tiles)"
	if not IslandMap.on_land(pos, TOWER_R * T):
		return "Too close to the water"
	var ground = world_
	if world_ is WorldGeometry and ground.terrain_at(pos, TOWER_R * T) == 1:
		return "Needs dry land for the dirt foundation"
	if world_ != null and Vector2(world_.resolve(pos, TOWER_R * T)) != pos:
		return "Something is in the way"
	return ""

# The first free tower slot, or -1 when all MAX_TOWERS are taken.
static func free_tower_slot(sim: GameSim) -> int:
	for i in range(MAX_TOWERS):
		if sim.towers[i] == null and not SimConstruction.construction_slot_taken(sim, i):
			return i
	return -1

# Where the unplaced free tower appears at dusk: in front of the door, beside its landing pad.
static func free_tower_spot(sim: GameSim, door: int) -> Vector2:
	var dp: Vector2 = Vector2(GameSim.DOOR_POS[door])
	var dd: Vector2 = Vector2(GameSim.DOOR_DIR[door])
	var side: Vector2 = Vector2(-dd.y, dd.x)
	var out: float = float(PAD_DIST)
	var off: float = float(PAD_R) + (TOWER_R + 1.0) * T
	for grow in [0.0, 1.0, 2.0, 3.0, 4.0]:
		for sgn in [1.0, -1.0]:
			for along in [0.0, -1.5, 1.5]:
				var p: Vector2 = dp + dd * (out + along * T) + side * (sgn * (off + grow * T))
				if tower_spot_problem(p, sim.world) == "":
					return p
	# nothing free beside the pad: just past its far edge
	return dp + dd * (out + float(PAD_R) + (TOWER_R + 1.0) * T)

static func build_tower(sim: GameSim, p, at = null) -> void:
	var spot: Vector2 = Vector2(at if at != null else p.pos)
	if not spot.is_finite() or not sim.phase in ["day", "dusk", "night"]:
		return
	if p.craft_idx >= 0 or p.channel > 0 or p.get("repair_kit_t", 0.0) > 0:
		SimPlayers.note(sim, p, "Finish your current action first")
		return
	if p.role != 2 or p.state != 0 or p.inside:
		SimPlayers.note(sim, p, "Engineer only")
		return
	if SimInventory.count(sim, p, "hammer") <= 0:
		SimPlayers.note(sim, p, "Needs the hammer")
		return
	if spot.distance_to(p.pos) > BUILD_REACH * T:
		SimPlayers.note(sim, p, "Too far away to build there")
		return
	# T places it at the Engineer's feet (they stand there already); from the build menu the spot must be free of people too
	var why = tower_spot_problem(spot, sim.world if at != null else null)
	if why == "" and at != null and sim.players.values().any(func(q): return q.pos.distance_to(spot) < 1.1 * T):
		why = "Someone is standing there"
	if why == "" and sim.towers.any(func(tw): return tw != null and Vector2(tw.pos).distance_to(spot) < 2.0 * TOWER_R * T):
		why = "Something is in the way"
	if why != "":
		SimPlayers.note(sim, p, why)
		return
	var i: int = free_tower_slot(sim)
	if i < 0:
		SimPlayers.note(sim, p, "The team already has %d towers" % [MAX_TOWERS])
		return
	if not sim.free_tower:
		if sim.unlock < 2:
			SimPlayers.note(sim, p, "Unlocks after the first boss")
			return
		for res in GameSim.TOWER_COST:
			if SimInventory.count(sim, p, res) < GameSim.TOWER_COST[res]:
				SimPlayers.note(sim, p, "A tower costs 10 wood + 5 titanium")
				return
	if not SimConstruction.reserve_tower(sim, p, i, spot):
		SimPlayers.note(sim, p, "Tower foundation is already reserved")

static func place_tower(sim: GameSim, slot, pos) -> void:
	sim.towers[slot] = {"slot": slot, "pos": pos, "hp": TOWER_HP, "wrecked": false, "pause": 0.0, "target": null}

static func tick_towers(sim: GameSim, dt) -> void:
	# A standing tower shoots the nearest enemy within 6 tiles at 8 DPS, day or night.
	for tw in sim.towers:
		if tw == null:
			continue
		tw.pause -= dt
		tw.target = null
		if tw.hp <= 0:
			continue
		var best = null
		var bd = TOWER_RANGE
		for e in sim.enemies:
			var d: float = float(e.pos.distance_to(tw.pos))
			if e.hp > 0 and d <= bd and SimWorld.line_clear(sim, tw.pos, e.pos, tw.pos):
				bd = d
				best = e
		if best != null:
			tw.target = best.pos
			best.hp -= TOWER_DPS * dt
			best.nodmg = 0.0
			if best.hp <= 0:
				SimDrops.drop(sim, best)
				if best.type == BOSS:
					sim.boss_dead = true
	sim.enemies = sim.enemies.filter(func(e): return e.hp > 0)

static func tower_in_light(sim: GameSim, pos) -> Variant:
	for tw in sim.towers:
		if tw != null and tw.hp > 0 and pos.distance_to(tw.pos) <= TOWER_LIGHT:
			return tw
	return null
