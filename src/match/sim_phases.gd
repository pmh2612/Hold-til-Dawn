class_name SimPhases
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/match/GameSim.Phases.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.

# constants shared with GameSim
const BOSS_AT = GameSim.BOSS_AT
const DAY_MAX = GameSim.DAY_MAX
const PAD_R = GameSim.PAD_R
const T = GameSim.T

# Owner: Pham Minh Hieu. Day / dusk / night cycle, win and loss, extraction (MEC-14..22, FML-13).

# --- phases -------------------------------------------------------------
static func dawn(sim: GameSim) -> void:
	SimSupplies.cancel_radio_build(sim)
	SimNightSpawns.reset_night_spawns(sim)
	SimTacticalItems.reset_tactical_items(sim)
	SimConstruction.cancel_all_construction(sim)
	sim.acid_pools.clear()
	sim.boss_fx.clear()
	sim.phase = "day"
	sim.t = DAY_MAX
	sim.votes.clear()
	sim.broken = [false, false, false]
	for tw in sim.towers:
		if tw != null:
			tw.wrecked = false
	for nd in sim.nodes:
		nd.amount = 5
	for p in sim.players.values():
		p.inside = false
		p.entry = 0.0
	var idx = [0, 1, 2]
	idx.shuffle()
	sim.active = idx.slice(0, mini(3, sim.k))
	sim.active.sort()
	sim.shown_unlock = sim.unlock
	# Phase, doors and recipe unlocks already have persistent HUD indicators.
	sim.msg = ""
	sim.msg_t = 0

static func dusk(sim: GameSim) -> void:
	SimSupplies.cancel_radio_build(sim)
	sim.phase = "dusk"
	sim.t = GameSim.DUSK
	for e in sim.enemies:
		if e.has("home"):
			e.erase("home")
			e.state = 0
			e.hits.clear()
			e.door = SimEnemies.nearest_active_door(sim, e.pos)
	sim.msg = ""
	sim.msg_t = 0

static func night(sim: GameSim) -> void:
	SimSupplies.cancel_radio_build(sim)
	if int(sim.k) == 5 and not sim.radio_built:
		end(sim, false, "Locator radio incomplete")
		return
	sim.phase = "night"
	sim.t = GameSim.NIGHT_LEN[sim.k - 1]
	sim.elapsed = 0.0
	sim.wave = 0
	SimNightSpawns.reset_night_spawns(sim)
	sim.next_wave = sim.night_first_wave_delay
	sim.boss_spawned = false
	sim.boss_down_tonight = false
	sim.boss_at = BOSS_AT
	SimNightSpawns.plan_night_quota(sim)
	SimConstruction.cancel_all_construction(sim)
	sim.ext = -1.0
	sim.pad_clear = [0.0, 0.0, 0.0]
	for p in sim.players.values():
		p.inside = false
		if SimWorld.inside_base(p.pos, 0.5 * T):
			var d = nearest_door(sim, p.pos)
			teleport(sim, p, GameSim.DOOR_POS[d] + GameSim.DOOR_DIR[d] * T)
	sim.msg = ""
	sim.msg_t = 0

static func night_cleared(sim: GameSim) -> void:
	if sim.k == 1:
		sim.unlock = maxi(sim.unlock, 1)
	sim.enemies.clear()
	sim.proj.clear()
	sim.tele.clear()
	sim.acid_pools.clear()
	sim.boss_fx.clear()
	sim.k += 1
	dawn(sim)

static func end(sim: GameSim, win, why) -> void:
	SimConstruction.cancel_all_construction(sim)
	SimTacticalItems.reset_tactical_items(sim)
	SimNightSpawns.reset_night_spawns(sim)
	SimSupplies.clear_supplies(sim)
	# section 2.5: the result screen stays until the players go back to the lobby
	sim.phase = "result"
	sim.t = 0.0
	sim.result = [win, why, sim.k]
	sim.msg = ("MISSION COMPLETE - " if win else "BEACON LOST - ") + Cs.s(why) + " (night %d)" % [sim.k]
	sim.enemies.clear()
	sim.proj.clear()
	sim.tele.clear()
	sim.acid_pools.clear()
	sim.boss_fx.clear()

static func to_lobby(sim: GameSim) -> void:
	SimConstruction.cancel_all_construction(sim)
	SimTacticalItems.reset_tactical_items(sim)
	SimNightSpawns.reset_night_spawns(sim)
	SimSupplies.clear_supplies(sim)
	sim.phase = "lobby"
	sim.msg = ""
	sim.result = null
	sim.drops.clear()
	sim.enemies.clear()
	sim.proj.clear()
	sim.tele.clear()
	sim.acid_pools.clear()
	sim.boss_fx.clear()
	for p in sim.players.values():
		SimPlayers.reset_player(sim, p)

static func check_end(sim: GameSim, dt) -> void:
	if sim.base_hp <= 0:
		end(sim, false, "Generator destroyed at door %s" % [GameSim.DOOR_NAMES[sim.last_door]] if sim.last_door >= 0 else "Generator destroyed")
		return
	if team_wiped(sim):
		end(sim, false, "Team wiped")
		return
	# the boss counts toward the night's quota like any other enemy
	if sim.boss_dead:
		sim.boss_dead = false
		sim.boss_down_tonight = true
		sim.bosses_killed += 1
		sim.unlock = maxi(sim.unlock, 2)
	# Clearing the quota advances dawn. Final-night extraction also requires the crafted rescue equipment.
	if sim.t > 0 and SimNightSpawns.night_all_down(sim):
		if sim.k < 5:
			night_cleared(sim)
			return
		sim.t = 0.0
		SimPlayers.say(sim, "Rescue incoming")
	if sim.t > 0:
		return
	if (sim.k == 2 or sim.k == 4) and not sim.boss_down_tonight:
		end(sim, false, "Boss survived the night")
		return
	if sim.k < 5:
		night_cleared(sim)
		return
	if not SimSupplies.supplies_all_in(sim):
		end(sim, false, "Locator radio incomplete")
		return
	# night 5 extraction (FML-13)
	var clear = []
	for i in 3:
		clear.append(pad_is_clear(sim, i))
	if sim.ext < 0:
		if true in clear:
			end(sim, true, "Helicopter landed at pad %s" % [GameSim.DOOR_NAMES[clear.find(true)]])
		elif sim.base_hp > 500:
			sim.ext = 60.0
			SimPlayers.say(sim, "Clear a landing pad")
		else:
			end(sim, false, "Landing pads blocked")
		return
	sim.ext -= dt
	for i in 3:
		sim.pad_clear[i] = sim.pad_clear[i] + dt if clear[i] else 0.0
		if sim.pad_clear[i] >= 10.0:
			end(sim, true, "Helicopter landed at pad %s" % [GameSim.DOOR_NAMES[i]])
			return
	if sim.ext <= 0:
		end(sim, false, "Landing pads blocked")

static func team_wiped(sim: GameSim) -> Variant:
	return not sim.players.is_empty() and sim.players.values().filter(func(p): return p.state == 0).is_empty()

static func near_pad(sim: GameSim, p) -> Variant:
	for i in 3:
		if p.distance_to(SimWorld.pad_pos(i)) < PAD_R + T:
			return true
	return false

static func pad_is_clear(sim: GameSim, i) -> Variant:
	var pad = SimWorld.pad_pos(i)
	for e in sim.enemies:
		if e.pos.distance_to(pad) < PAD_R:
			return false
	return true

static func tick_breach_end(sim: GameSim, dt) -> void:
	var caught = sim.players.values().filter(func(p): return p.state != 2 and not p.inside and SimWorld.inside_base(p.pos))
	if any_breach(sim) or caught.is_empty():
		sim.breach_end_t = -1.0
		return
	if sim.breach_end_t < 0:
		sim.breach_end_t = 5.0
		SimPlayers.say(sim, "Everyone out in 5 s")
	sim.breach_end_t -= dt
	if sim.breach_end_t > 0:
		return
	sim.breach_end_t = -1.0
	for p in caught:
		var d = nearest_door(sim, p.pos)
		teleport(sim, p, GameSim.DOOR_POS[d] + GameSim.DOOR_DIR[d] * T)

static func any_breach(sim: GameSim) -> Variant:
	return sim.doors.any(func(d): return d <= 0)

static func enemy_inside(sim: GameSim) -> Variant:
	for e in sim.enemies:
		if e.state == 3 and SimWorld.inside_base(e.pos):
			return true
	return false

static func nearest_door(sim: GameSim, pos) -> Variant:
	var best = 0
	for i in 3:
		if pos.dot(GameSim.DOOR_DIR[i]) > pos.dot(GameSim.DOOR_DIR[best]):
			best = i
	return best

static func teleport(sim: GameSim, p, pos) -> void:
	p.pos = sim.world.resolve(pos, 0.3 * T)
	p.nav_t = 0.0
	p.tp += 1
