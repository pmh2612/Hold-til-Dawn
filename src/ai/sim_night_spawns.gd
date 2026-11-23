class_name SimNightSpawns
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/ai/GameSim.NightSpawns.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
static var SPAWN_MUL: float = AiSettings.get_current().spawn_multiplier
static var WAVE_INTERVAL: float = AiSettings.get_current().wave_interval
static var FINAL_WAVE_INTERVAL: float = AiSettings.get_current().final_wave_interval
const WAVE_MIN_DISTANCE = 8.0
static var NIGHT_BUDGET = [18, 30, 45, 60, 80]
static var SPAWN_GAP = [6, 4, 3, 2, 1.5]
static var NIGHT_ALIVE_CAP = [12, 16, 20, 24, 28]

# seconds after the field is cleared until the next wave comes
const CLEARED_WAVE_DELAY: float = 5.0

# constants shared with GameSim
const BOSS = GameSim.BOSS
const HALF = GameSim.HALF
const ISLAND = GameSim.ISLAND
const SPAWN_ALL_SIDES = GameSim.SPAWN_ALL_SIDES
const T = GameSim.T

static func plan_night_quota(sim: GameSim) -> void:
	var crew: float = 1.0 + 0.35 * maxi(0, sim.players.size() - 1)
	var mode_stats = GameSim.MODE_MUL[int(sim.mode)]
	var mode_scale: float = float(mode_stats[0])
	var len_: float = float(GameSim.NIGHT_LEN[sim.night_index])
	var budget: float = 0
	var w: int = 1
	# the waves that come in the first part of the night; the last minute is slack for the supplies
	var at: float = sim.night_first_wave_delay
	while at < len_ - 60.0:
		var growth: float = 1 if sim.night_index == 0 else 1 + 0.08 * clampi(w - 1, 0, 3)
		# a boss night counts its waves at full strength: while the boss lives the waves are thinner, but
		# killing the boss ends the night anyway (CheckEnd)
		budget += clampf(NIGHT_BUDGET[sim.night_index] * crew * growth * mode_scale * SPAWN_MUL, 0, sim.night_enemy_limit * 20.0)
		at += sim.night_wave_interval
		w += 1
	# the average cost of the kinds that come this night
	var cost: float = 0
	var kinds: int = 0
	for type in range(3):
		var stats = GameSim.ENEMY[type]
		if int(stats[4]) <= int(sim.k):
			cost += float(stats[3])
			kinds += 1
	sim.regular_quota = maxi(1, int(budget / maxf(1.0, cost / maxi(1, kinds))))
	sim.night_quota = sim.regular_quota + (1 if sim.boss_night else 0)
	sim.night_spawned = 0

# Quota enemies (the night's own, not daytime roamers or a boss's brood) still alive.
static func night_alive(sim: GameSim) -> int:
	var n: int = 0
	for enemy in sim.enemies:
		if enemy.get("quota", false) and float(enemy.get("hp")) > 0:
			n += 1
	return n

static func night_killed(sim: GameSim) -> int:
	return maxi(0, sim.night_spawned - night_alive(sim))

static func night_all_down(sim: GameSim) -> bool:
	return sim.night_quota > 0 and sim.night_spawned >= sim.night_quota and night_alive(sim) == 0

# Called from TickWaves: an empty field brings the next wave (or the boss) forward.
static func pull_night_forward(sim: GameSim) -> void:
	if sim.night_spawned == 0 or sim.pending_wave_budget >= 10 or night_alive(sim) > 0:
		return
	var now: float = float(sim.elapsed)
	if sim.night_spawned < sim.regular_quota:
		if float(sim.next_wave) > now + CLEARED_WAVE_DELAY:
			sim.next_wave = now + CLEARED_WAVE_DELAY
	elif sim.boss_night and not sim.boss_spawned:
		if sim.boss_at > now + CLEARED_WAVE_DELAY:
			sim.boss_at = now + CLEARED_WAVE_DELAY

static func reset_night_spawns(sim: GameSim) -> void:
	sim.pending_wave_budget = 0
	sim.next_enemy_spawn_at = 0
	sim.wave_spawn_ends_at = 0
	sim.wave_spawn_ordinal = 0
	sim.carry = 0.0

static func plan_night_wave(sim: GameSim) -> void:
	# Old unfinished waves are discarded. Neither a full field nor a hitch accumulates future bursts.
	var crew: float = 1.0 + 0.35 * maxi(0, sim.players.size() - 1)
	var growth: float = 1 if sim.night_index == 0 else 1 + 0.08 * clampi(int(sim.wave) - 1, 0, 3)
	var boss_scale: float = 1
	for enemy in sim.enemies:
		if int(enemy.get("type")) == BOSS:
			boss_scale = 1.0 / 3.0
			break
	var mode_stats = GameSim.MODE_MUL[int(sim.mode)]
	var mode_scale: float = float(mode_stats[0])
	sim.pending_wave_budget = clampf(NIGHT_BUDGET[sim.night_index] * crew * growth * boss_scale * mode_scale * SPAWN_MUL + float(sim.carry), 0, sim.night_enemy_limit * 20.0)
	sim.carry = 0.0
	sim.next_enemy_spawn_at = float(sim.elapsed)
	sim.wave_spawn_ends_at = sim.next_enemy_spawn_at + sim.night_wave_interval * 0.7
	sim.wave_spawn_ordinal = 0

static func tick_pending_night_spawn(sim: GameSim) -> void:
	var now: float = float(sim.elapsed)
	if sim.pending_wave_budget < 10:
		return
	if sim.night_spawned >= sim.regular_quota:
		sim.pending_wave_budget = 0
		return
	# an unfinished wave hands what is left to the next one, so the night's quota still comes
	if now >= sim.wave_spawn_ends_at:
		sim.carry = float(sim.carry) + sim.pending_wave_budget
		sim.pending_wave_budget = 0
		return
	if now < sim.next_enemy_spawn_at:
		return
	# Delay instead of a catch-up loop, including when the alive cap has been reached.
	sim.next_enemy_spawn_at = now + sim.night_spawn_spacing
	if sim.enemies.size() >= sim.night_enemy_limit or sim.active.size() == 0:
		return
	var eligible = Cs.arr(3, 0)
	var count_: int = 0
	for type in range(3):
		var stats = GameSim.ENEMY[type]
		if int(stats[4]) <= int(sim.k) and float(stats[3]) <= sim.pending_wave_budget:
			var _old1 = count_
			count_ += 1
			eligible[_old1] = type
	if count_ == 0:
		sim.pending_wave_budget = 0
		return
	var random = sim.rng
	var kind: int = eligible[int(random.randi() % count_)]
	var _old2 = sim.wave_spawn_ordinal
	sim.wave_spawn_ordinal += 1
	var door: int = int(sim.active[_old2 % sim.active.size()])
	var distance: float = random.randf_range(float(WAVE_MIN_DISTANCE), (float(ISLAND) - Vector2(HALF).length()) / T - 2) if SPAWN_ALL_SIDES else random.randf_range(25.0, 35.0)
	var enemy = SimEnemies.spawn_enemy(sim, kind, door, distance, SPAWN_ALL_SIDES)
	if SPAWN_ALL_SIDES:
		enemy["door"] = SimEnemies.nearest_active_door(sim, enemy.get("pos"))
	enemy["quota"] = true
	sim.night_spawned += 1
	var chosen_stats = GameSim.ENEMY[kind]
	sim.pending_wave_budget -= float(chosen_stats[3])
	if sim.pending_wave_budget < 10:
		sim.carry = sim.pending_wave_budget
		sim.pending_wave_budget = 0
