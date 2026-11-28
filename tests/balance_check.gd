class_name BalanceCheck
extends Node

var checks: int = 0
var failed: bool = false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("FAIL: " + label)
	else:
		print("ok   " + label)

func _ready() -> void:
	check_weapon_hierarchy()
	check_enemy_scaling_and_modes()
	check_boss_ttk_and_fairness()
	check_poison_and_roamer_mode_scaling()
	print(("BALANCE CHECK FAILED" if failed else "BALANCE CHECK ALL OK") + ": %d checks" % checks)
	get_tree().quit(1 if failed else 0)

func check_weapon_hierarchy() -> void:
	var d_starter: float = SimBalance.weapon_dps("starter_bow", 1)
	var d_starter_scout: float = SimBalance.weapon_dps("starter_bow", 0)
	var d_hammer: float = SimBalance.weapon_dps("hammer", 1)
	var d_fists: float = SimBalance.weapon_dps("fists", 1)
	var d_bow: float = SimBalance.weapon_dps("bow", 1)
	var d_bow_scout: float = SimBalance.weapon_dps("bow", 0)
	var d_stone: float = SimBalance.weapon_dps("stone_spear", 1)
	var d_long: float = SimBalance.weapon_dps("long_spear", 1)
	var d_maul: float = SimBalance.weapon_dps("stun_maul", 1)
	var d_blade: float = SimBalance.weapon_dps("titanium_blade", 1)
	var d_exp: float = SimTacticalItems.EXPLOSIVE_ARROW_DAMAGE * 1.0 * GameSim.WEAPON_ATTACK_SPEED
	print("WEAPON DPS (std): starter_bow=%.1f (scout=%.1f) hammer=%.1f fists=%.1f bow=%.1f (scout=%.1f) stone_spear=%.1f long_spear=%.1f stun_maul=%.1f titanium_blade=%.1f explosive=%.1f" % [
		d_starter, d_starter_scout, d_hammer, d_fists, d_bow, d_bow_scout, d_stone, d_long, d_maul, d_blade, d_exp
	])
	check(d_bow > d_starter * 1.5 and d_bow_scout > d_starter_scout * 1.5, "crafted Bow deals at least 50% more DPS than Scout free Starter Bow")
	check(d_bow > d_fists, "crafted Bow exceeds bare-hands DPS")
	check(d_stone > d_fists * 1.3 and d_long >= d_stone, "Day-1 crafted spears strictly beat bare hands")
	check(d_maul > d_stone and d_blade > d_maul, "Tier-2 Titanium weapons strictly outperform Day-1 spears (Stun Maul < Titanium Blade)")
	check(d_blade >= d_fists * 1.9 and d_blade <= d_fists * 2.1, "Titanium Blade hits ~2.0x bare-hands endgame ratio")
	check(d_exp > d_blade, "Explosive Arrow AoE burst exceeds single-target melee DPS")

func check_enemy_scaling_and_modes() -> void:
	for mode in range(3):
		var prof = SimBalance.profile(mode)
		check(is_equal_approx(float(GameSim.MODE_MUL[mode][0]), float(prof.wave)) and is_equal_approx(float(GameSim.MODE_MUL[mode][1]), float(prof.hp)) and is_equal_approx(float(GameSim.MODE_MUL[mode][2]), float(prof.dmg)), "GameSim.MODE_MUL[%d] matches SimBalance profile (%s)" % [mode, prof.name])
	for night in range(1, 6):
		for type in range(3):
			var base = GameSim.ENEMY[type]
			var h0: float = SimBalance.enemy_hp(float(base[0]), night, 0)
			var h1: float = SimBalance.enemy_hp(float(base[0]), night, 1)
			var h2: float = SimBalance.enemy_hp(float(base[0]), night, 2)
			var d0: float = SimBalance.enemy_damage(float(base[1]), night, 0)
			var d1: float = SimBalance.enemy_damage(float(base[1]), night, 1)
			var d2: float = SimBalance.enemy_damage(float(base[1]), night, 2)
			check(h0 < h1 and h1 < h2 and d0 < d1 and d1 < d2, "night %d enemy %d HP/DMG strictly rise Easy < Medium < Hard" % [night, type])
			for mode in range(3):
				var spd: float = SimBalance.night_speed_tiles(float(base[2]), night, mode)
				check(spd <= SimBalance.ENEMY_SPEED_CAP + 0.001 and spd < 5.0, "night %d enemy %d mode %d speed %.2f stays <= 3.0 cap (< player 5.0)" % [night, type, mode, spd])
	# Verify live spawn matches SimBalance across modes.
	var s := GameSim.new()
	s.add_player(1, "Eng", 2)
	s.add_player(2, "Scout", 0)
	s.add_player(3, "Healer", 1)
	s.start_match()
	var quotas: Array = []
	var grunt_hps: Array = []
	var grunt_dmgs: Array = []
	for mode in range(3):
		s.mode = mode
		s.k = 3
		s.night()
		quotas.append(s.regular_quota)
		var g = s.spawn(GameSim.GRUNT, 0, 25.0, false)
		grunt_hps.append(float(g.maxhp))
		grunt_dmgs.append(float(g.dmg))
		s.enemies.clear()
	print("NIGHT 3 (n=3) Easy/Med/Hard: quota=%s grunt_hp=%s grunt_dmg=%s" % [quotas, grunt_hps, grunt_dmgs])
	check(quotas[0] < quotas[1] and quotas[1] < quotas[2], "regular night quota increases monotonically Easy < Medium < Hard")
	check(grunt_hps[0] < grunt_hps[1] and grunt_hps[1] < grunt_hps[2], "live spawned Grunt HP increases Easy < Medium < Hard")
	check(grunt_dmgs[0] < grunt_dmgs[1] and grunt_dmgs[1] < grunt_dmgs[2], "live spawned Grunt damage increases Easy < Medium < Hard")

func check_boss_ttk_and_fairness() -> void:
	# H3: All 7 archetypes should have identical/tight TTK spread (<= 5%, GDD limit <= 15%).
	for night in [2, 4]:
		var weapon: String = "stone_spear" if night == 2 else "titanium_blade"
		var ttks: Array = []
		for kind in range(7):
			ttks.append(SimBalance.predicted_boss_ttk(kind, night, 4, 1, weapon))
		var lo: float = ttks.min()
		var hi: float = ttks.max()
		var spread: float = (hi - lo) / maxf(1.0, lo)
		print("BOSS TTK Night %d (n=4, Medium, %s): min=%.1fs max=%.1fs spread=%.1f%%" % [night, weapon, lo, hi, spread * 100.0])
		check(spread <= 0.05, "H3: Night %d all 7 boss archetypes TTK spread %.1f%% <= 5%%" % [night, spread * 100.0])
		if night == 2:
			check(lo >= 55.0 and hi <= 70.0, "BAL-36: Night-2 Medium Boss TTK (%.1fs) sits in 55-70s target band" % lo)
		else:
			check(lo >= 65.0 and hi <= 82.0, "BAL-36: Night-4 Medium Boss TTK (%.1fs) sits in 65-82s target band" % lo)
	# H2: Preparation matters — un-upgraded bare hands takes significantly longer than Stone tier.
	var ttk_upg: float = SimBalance.predicted_boss_ttk(0, 2, 4, 1, "stone_spear")
	var ttk_bare: float = SimBalance.predicted_boss_ttk(0, 2, 4, 1, "fists")
	check(ttk_bare >= ttk_upg * 1.35, "H2: un-upgraded Night-2 TTK (%.1fs) is >= 35%% slower than Stone-tier (%.1fs)" % [ttk_bare, ttk_upg])
	# T-FML03: Team size fairness for n in {3, 4, 5}: TTK differs by <= 5%.
	var n3: float = SimBalance.predicted_boss_ttk(0, 2, 3, 1, "stone_spear")
	var n4: float = SimBalance.predicted_boss_ttk(0, 2, 4, 1, "stone_spear")
	var n5: float = SimBalance.predicted_boss_ttk(0, 2, 5, 1, "stone_spear")
	var n_spread: float = (maxf(n3, maxf(n4, n5)) - minf(n3, minf(n4, n5))) / minf(n3, minf(n4, n5))
	check(n_spread <= 0.05, "T-FML03: n=3/4/5 Boss TTK (%.1f/%.1f/%.1fs) differs by %.1f%% <= 5%%" % [n3, n4, n5, n_spread * 100.0])
	# H14: Boss TTK and cooldown pressure separate Easy / Medium / Hard clearly.
	var e_ttk: float = SimBalance.predicted_boss_ttk(0, 2, 4, 0, "stone_spear")
	var m_ttk: float = SimBalance.predicted_boss_ttk(0, 2, 4, 1, "stone_spear")
	var h_ttk: float = SimBalance.predicted_boss_ttk(0, 2, 4, 2, "stone_spear")
	var e_cd: float = SimBalance.boss_cooldown_for(5.0, 2, 0)
	var m_cd: float = SimBalance.boss_cooldown_for(5.0, 2, 1)
	var h_cd: float = SimBalance.boss_cooldown_for(5.0, 2, 2)
	print("BOSS MODE SPREAD (Juggernaut N2 n=4): TTK=%.1f/%.1f/%.1fs | CD(5s)=%.2f/%.2f/%.2fs" % [e_ttk, m_ttk, h_ttk, e_cd, m_cd, h_cd])
	check(e_ttk < m_ttk and m_ttk < h_ttk, "Boss TTK scales strictly Easy < Medium < Hard")
	check(e_cd > m_cd and m_cd > h_cd, "Boss cooldowns tighten Easy > Medium > Hard")

func check_poison_and_roamer_mode_scaling() -> void:
	var s := GameSim.new()
	s.add_player(1, "Eng", 2)
	s.start_match()
	var p = s.players[1]
	var ticks: Array = []
	for mode in range(3):
		s.mode = mode
		s.k = 2
		SimPlayers.clear_poison(p)
		SimPlayers.apply_poison(s, p)
		ticks.append(float(p.poison_dmg))
	check(ticks[0] < ticks[1] and ticks[1] < ticks[2], "Bio-Cannon poison DoT scales Easy (%.0f) < Medium (%.0f) < Hard (%.0f)" % [ticks[0], ticks[1], ticks[2]])
	check(SimBalance.roam_multiplier(0) < SimBalance.roam_multiplier(1) and SimBalance.roam_multiplier(1) < SimBalance.roam_multiplier(2), "Daytime roamer pressure scales Easy < Medium < Hard")
