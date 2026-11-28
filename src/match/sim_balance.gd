class_name SimBalance
extends RefCounted

# Centralized combat & difficulty balance formulas derived from GDD Chapter 3
# (FML-01..08, BAL-06..45, H1..H16). Single source of truth for Easy / Medium / Hard.
const ENEMY_SPEED_CAP: float = 3.0
const NIGHT_STAT_GROWTH: float = 1.10
const NIGHT_SPEED_GROWTH: float = 1.08
const BOSS_NIGHT4_HP_MUL: float = 1.5625
const BOSS_NIGHT4_DMG_MUL: float = 1.21
const BOSS_NIGHT4_CD_MUL: float = 0.90
const BOSS_REF_TEAM_WEIGHT: float = 3.4  # 1 + 0.8 * (4 - 1) for n = 4 reference squad
const BOSS_TEAM_STEP: float = 0.8

# Difficulty profiles [Easy, Medium, Hard] aligned with BAL-45 & H14 target win rates:
# Easy >= 75%, Medium 50-70%, Hard 25-40%.
# Fields: wave_mul, hp_mul, dmg_mul, boss_cd_mul, speed_mul, roam_mul
const MODE_PROFILES: Array = [
	{"name": "Easy", "wave": 0.75, "hp": 0.80, "dmg": 0.75, "boss_cd": 1.15, "speed": 0.95, "roam": 0.75},
	{"name": "Medium", "wave": 1.00, "hp": 1.00, "dmg": 1.00, "boss_cd": 1.00, "speed": 1.00, "roam": 1.00},
	{"name": "Hard", "wave": 1.25, "hp": 1.20, "dmg": 1.25, "boss_cd": 0.88, "speed": 1.05, "roam": 1.25},
]

static func profile(mode: int) -> Dictionary:
	return MODE_PROFILES[clampi(mode, 0, MODE_PROFILES.size() - 1)]

static func wave_multiplier(mode: int) -> float:
	return float(profile(mode).wave)

static func hp_multiplier(mode: int) -> float:
	return float(profile(mode).hp)

static func dmg_multiplier(mode: int) -> float:
	return float(profile(mode).dmg)

static func boss_cd_multiplier(mode: int) -> float:
	return float(profile(mode).boss_cd)

static func speed_multiplier(mode: int) -> float:
	return float(profile(mode).speed)

static func roam_multiplier(mode: int) -> float:
	return float(profile(mode).roam)

# FML-01: Enemy HP and damage grow x1.10 per night; speed grows x1.08 per night, capped at 3.0 tiles/s
# so players (5.0 tiles/s) can always disengage on every night and difficulty mode.
static func night_stat_growth(night: int) -> float:
	return pow(NIGHT_STAT_GROWTH, maxi(0, night - 1))

static func enemy_hp(base_hp: float, night: int, mode: int) -> float:
	return base_hp * night_stat_growth(night) * hp_multiplier(mode)

static func enemy_damage(base_dmg: float, night: int, mode: int) -> float:
	return base_dmg * night_stat_growth(night) * dmg_multiplier(mode)

static func night_speed_tiles(base_tiles_s: float, night: int, mode: int) -> float:
	return minf(ENEMY_SPEED_CAP, base_tiles_s * pow(NIGHT_SPEED_GROWTH, maxi(0, night - 1)) * speed_multiplier(mode))

# FML-02: Boss HP scales by team size (+80% per extra player, normalized at n = 4),
# x1.5625 on Night 4, and mode HP multiplier.
static func boss_hp(base_hp_n2_4p: float, night: int, team_size: int, mode: int) -> float:
	var n: int = maxi(1, team_size)
	var team_scale: float = (1.0 + BOSS_TEAM_STEP * float(n - 1)) / BOSS_REF_TEAM_WEIGHT
	var night_scale: float = BOSS_NIGHT4_HP_MUL if night >= 4 else 1.0
	return base_hp_n2_4p * team_scale * night_scale * hp_multiplier(mode)

# BAL-37/38 + BAL-45: Boss damage scales x1.21 on Night 4 and by mode damage multiplier.
static func boss_damage(sim: GameSim, base_dmg_n2: float) -> float:
	return boss_damage_for(base_dmg_n2, int(sim.k), int(sim.mode))

static func boss_damage_for(base_dmg_n2: float, night: int, mode: int) -> float:
	return base_dmg_n2 * (BOSS_NIGHT4_DMG_MUL if night >= 4 else 1.0) * dmg_multiplier(mode)

# BAL-38 + mode pacing: Boss cooldowns tighten on Night 4 (x0.90) and Hard (x0.88), relax on Easy (x1.15).
# Telegraph wind-ups remain unchanged so dodge fairness is identical across modes.
static func boss_cooldown(sim: GameSim, base_cd: float) -> float:
	return boss_cooldown_for(base_cd, int(sim.k), int(sim.mode))

static func boss_cooldown_for(base_cd: float, night: int, mode: int) -> float:
	return base_cd * (BOSS_NIGHT4_CD_MUL if night >= 4 else 1.0) * boss_cd_multiplier(mode)

# FML-03 helpers for automated balance verification.
static func weapon_dps(weapon_id: String, role: int = 1) -> float:
	var st = GameSim.WEAPON_STATS[weapon_id]
	return float(st[0]) * float(st[1]) * GameSim.WEAPON_ATTACK_SPEED * (1.25 if role == 0 else 1.0)

static func predicted_boss_ttk(kind: int, night: int, team_size: int, mode: int, weapon_id: String) -> float:
	var b = SimBosses.BOSS_KINDS[kind]
	var hp: float = boss_hp(float(b[2]), night, team_size, mode)
	var u_b: float = float(b[4])
	var d: float = weapon_dps(weapon_id, 1)
	return hp / maxf(1.0, float(maxi(1, team_size)) * d * u_b)
