class_name TacticalCraftCheck
extends Node
var checks: int = 0

func check(pass_: bool, label) -> void:
	if not pass_:
		Cs.fail(label)
		return
	checks += 1
	print("ok   " + label)
var sim
var p
var ally
var field: Vector2 = Vector2(0, 640)

# Hold the attack input through the real player tick, rather than calling attacks through cooldowns.
func check_weapon_cadence() -> void:
	var old_rates = {"fists": 1.5, "stone_spear": 1.5, "titanium_blade": 1.5, "hammer": 1.2, "long_spear": 1.0, "stun_maul": 0.65, "starter_bow": 1.0, "bow": 1.0}
	var dt: float = 1.0 / 60.0
	for role in range(3):
		for weapon in old_rates:
			reset()
			p.role = role
			p.sel = 0
			if weapon != "fists":
				give(weapon, 1)
			give("arrow", 30)
			p.atk = true
			p.aim = 0.0
			sim.audio_events.clear()
			var strikes: Array = []
			var expected_gap: float = 1.0 / (float(old_rates[weapon]) * 1.5 * (1.25 if role == 0 else 1.0))
			for frame in range(180):
				var before: int = sim.audio_sequence
				sim.clock += dt
				sim.tick_players(dt)
				if sim.audio_sequence > before:
					strikes.append(frame * dt)
			var gaps_ok: bool = strikes.size() >= 3
			for i in range(1, strikes.size()):
				var gap: float = float(strikes[i]) - float(strikes[i - 1])
				gaps_ok = gaps_ok and gap >= expected_gap - 0.001 and gap <= expected_gap + dt + 0.001
			check(gaps_ok, "%s / %s repeats attacks 50%% faster without bypassing cooldown" % [GameSim.ROLES[role], weapon])
			if weapon in ["bow", "starter_bow"]:
				check(sim.arrows.size() == strikes.size() and sim.count(p, "arrow") == 30 - (strikes.size() if weapon == "bow" else 0), "%s / %s fires once per attack with correct ammunition use" % [GameSim.ROLES[role], weapon])
			p.atk = false
			var stopped: int = sim.audio_sequence
			sim.tick_players(2.0)
			check(sim.audio_sequence == stopped, "%s / %s stops attacking when released" % [GameSim.ROLES[role], weapon])
	reset()
	give("bow", 1)
	give("explosive_arrow", 3)
	check(sim.use_tactical_item(p, "explosive_arrow", field + Vector2(200, 0)), "first explosive arrow fires")
	p.atk_cd -= 0.61
	advance(0.61)
	check(not sim.use_tactical_item(p, "explosive_arrow", field + Vector2(200, 0)) and sim.count(p, "explosive_arrow") == 2, "explosive arrow cannot bypass its faster cooldown")
	p.atk_cd -= 0.07
	advance(0.07)
	check(sim.use_tactical_item(p, "explosive_arrow", field + Vector2(200, 0)) and sim.count(p, "explosive_arrow") == 1, "explosive arrow can fire again after two thirds of a second")

func reset() -> void:
	sim.phase = "day"
	sim.clock = 10.0
	sim.reset_tactical_items()
	sim.enemies = []
	sim.arrows = []
	sim.proj = []
	sim.drops = []
	sim.built_walls = []
	sim.towers = [null, null, null]
	sim.doors = [500.0, 500.0, 500.0]
	sim.broken = [false, false, false]
	sim.door_pause = [0.0, 0.0, 0.0]
	sim.world.rebuild([], sim.towers, sim.built_walls)
	sim.reset_player(p)
	sim.reset_player(ally)
	p.pos = field
	ally.pos = field + Vector2(0, 24)
	p.inv = SimInventory.empty_slots(12)
	p.role = 2

func give(item, count: int = 5) -> void:
	sim.set_count(p, item, count)

func advance(seconds: float) -> void:
	sim.clock += seconds
	sim.tick_tactical_items()

func enemy(pos: Vector2, type: int = 0) -> Variant:
	var e = sim.spawn(type, 0, 0.0)
	e.pos = pos
	e.hp = 200.0
	e.maxhp = 200.0
	e.spd = 0.0
	return e

func boss_at(pos: Vector2) -> Variant:
	sim.k = 2
	sim.spawn_boss()
	var e = sim.enemies[sim.enemies.size() - 1]
	e.pos = pos
	e.hp = 2000.0
	return e

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	run()
	print("TACTICAL CRAFT ALL OK ", checks)
	get_tree().quit()
	# catch (Exception E) dropped

func run() -> void:
	print("TACTICAL CRAFT CHECK starting")
	sim = GameSim.new()
	print("TACTICAL CRAFT CHECK simulation created")
	sim.add_player(1, "Engineer", 2)
	sim.add_player(2, "Ally", 1)
	sim.action(1, "start", 0)
	p = sim.players[1]
	ally = sim.players[2]
	check_weapon_cadence()
	check(GameSim.RECIPES.size() == 18 and not GameSim.ITEMS.has("wood_shield"), "18 approved recipes including hammer and cargo frame, no shield")
	for i in range(GameSim.RECIPES.size()):
		reset()
		p.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
		var r = GameSim.RECIPES[i]
		var id = Cs.s(r[3])
		var tier: int = int(r[2])
		sim.unlock = tier
		sim.base_hp = 500
		for res in r[1]:
			sim.set_count(p, res, r[1][res])
		if id == "healing_flask":
			for role in [0, 2]:
				p.role = role
				check(not sim.can_craft(p, i, false), GameSim.ROLES[role] + " cannot craft healing flasks")
				sim.action(1, "craft", i)
				check(p.craft_idx < 0 and sim.count(p, "herb") == 6 and sim.count(p, "titanium") == 2, "direct non-Healer craft request cannot spend flask materials")
			p.role = 1
		if id == "hammer":
			for role in range(3):
				p.role = role
				check(sim.can_craft(p, i, false), GameSim.ROLES[role] + " can craft the day-one hammer")
			p.role = 2
		check(sim.can_craft(p, i, false), id + " affordable at correct tier")
		if tier > 0:
			sim.unlock = tier - 1
			check(not sim.can_craft(p, i, false), id + " locked before tier")
			sim.unlock = tier
		sim.base_hp = 500
		var duration: float = sim.player_craft_duration(p, i)
		sim.craft(p, i)
		sim.tick_craft(p, duration - 0.1)
		check(p.craft_idx == i, id + " requires full craft time")
		sim.tick_craft(p, 0.11)
		var crafted: bool = sim.base_hp == 600 if id == "base" else p.armour == GameSim.ARMOUR_ITEMS.find(id) if SimInventory.kind_of(id) == "armour" else p.bag_tier == GameSim.BAG_ITEMS.find(id) and p.inv.size() >= GameSim.INV_SLOTS + GameSim.BAG_BONUS[p.bag_tier] if SimInventory.kind_of(id) == "bag" else sim.count(p, id) == int(r[4])
		check(crafted, id + " craft output")
		for res in r[1]:
			check(sim.count(p, res) == 0, id + " spends " + Cs.s(res))
		check(not (id == "haste_tonic" or id == "poison_flask" or id == "vine_trap"), id + " is allowed crafting")
		check(id == "chest_key" or ResourceLoader.exists("res://art/items/" + ("base_repair" if id == "base" else "revival_kit" if id == "revive" else id) + ".png"), id + " has native or imported icon")
	reset()
	p.role = 1
	p.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	sim.unlock = 1
	give("herb", 6)
	give("titanium", 2)
	sim.craft(p, 13)
	p.role = 2
	sim.tick_craft(p, 3)
	check(sim.count(p, "healing_flask") == 0 and sim.count(p, "herb") == 6 and sim.count(p, "titanium") == 2, "losing the Healer role before completion prevents flask output without charging materials")
	reset()
	give("haste_tonic", 2)
	var normal_speed: float = sim.player_speed(p)
	check(sim.use_tactical_item(p, "haste_tonic", field), "drink tonic")
	check(absf(sim.player_speed(p) / normal_speed - 1.2) < 0.001, "tonic increases authoritative speed 20%")
	advance(1.0)
	check(not sim.use_tactical_item(p, "haste_tonic", field) and sim.count(p, "haste_tonic") == 1, "tonic cannot stack or waste a dose")
	advance(7.0)
	check(sim.player_speed(p) == normal_speed, "tonic expires after 8 seconds")
	reset()
	give("vine_trap")
	check(not sim.use_tactical_item(p, "vine_trap", Vector2(NAN, 0)), "reject non-finite aim without spending")
	for i in range(3):
		check(sim.use_tactical_item(p, "vine_trap", field), "place trap " + str(i))
		advance(0.6)
	check(not sim.use_tactical_item(p, "vine_trap", field) and sim.vine_traps.size() == 3, "per-player trap cap")
	var grunt = enemy(field)
	advance(0.3)
	check(grunt.get("stun_until", 0.0) > float(sim.clock), "trap roots normal enemy")
	sim.tick_enemies(0.1)
	check(Vector2(grunt.pos) == field, "rooted enemy cannot move")
	advance(121.0)
	check(sim.vine_traps.size() == 0, "traps expire")
	reset()
	give("vine_trap")
	sim.use_tactical_item(p, "vine_trap", field)
	var boss = boss_at(field)
	advance(0.3)
	check(sim.vine_traps.size() == 1 and boss.get("stun_until", 0.0) == 0, "boss ignores vine trap")
	reset()
	give("poison_flask", 3)
	grunt = enemy(field + Vector2(24, 0))
	check(sim.use_tactical_item(p, "poison_flask", field), "throw poison")
	advance(0.5)
	check(float(grunt.hp) == 196.0, "poison pulse deals 4 damage")
	advance(0.2)
	check(sim.use_tactical_item(p, "poison_flask", field), "throw overlapping staggered poison")
	advance(0.3)
	advance(0.2)
	check(float(grunt.hp) == 192.0, "staggered poison zones do not stack")
	var before: float = float(grunt.hp)
	advance(20.0)
	check(float(grunt.hp) == before and sim.tactical_areas.size() == 0, "expired areas do not catch up damage")
	reset()
	give("poison_flask")
	grunt = enemy(field + Vector2(24, 0))
	grunt.hp = 4.0
	sim.use_tactical_item(p, "poison_flask", field)
	advance(0.5)
	check(sim.enemies.size() == 0 and p.kills == 1 and p.dmg == 4.0, "poison kills use normal damage / kill accounting")
	sim.hit(grunt, 4.0, p)
	check(p.kills == 1, "dead targets cannot award duplicate kills")
	reset()
	give("healing_flask")
	p.hp = 40.0
	ally.hp = 30.0
	sim.use_tactical_item(p, "healing_flask", field)
	advance(0.5)
	check(p.hp == 44.0 and ally.hp == 34.0, "healing zone heals caster and ally")
	ally.state = 1
	advance(0.5)
	check(ally.state == 1 and ally.hp == 34.0, "healing does not revive downed players")
	p.hp = p.maxhp - 1.0
	advance(0.5)
	check(p.hp == p.maxhp, "healing clamps max HP")
	reset()
	give("poison_flask", 20)
	for i in range(GameSim.MAX_TACTICAL_AREAS):
		sim.tactical_areas.append({"pos": field, "owner": 1, "kind": "heal", "until": 100.0, "next": 100.0})
	check(not sim.use_tactical_item(p, "poison_flask", field) and sim.count(p, "poison_flask") == 20, "area cap preserves unused consumable")
	reset()
	p.weapon = "long_spear"
	p.aim = 0.0
	var a = enemy(field + Vector2(36, 0))
	var b = enemy(field + Vector2(56, 0))
	var c = enemy(field + Vector2(78, 0))
	var side = enemy(field + Vector2(50, 42))
	sim.attack(p)
	check(a.hp == 176.0 and b.hp == 176.0 and c.hp == 200.0 and side.hp == 200.0, "long spear hits nearest two in a narrow line")
	reset()
	p.weapon = "stun_maul"
	p.aim = 0.0
	grunt = enemy(field + Vector2(24, 0))
	sim.attack(p)
	check(grunt.hp == 158.0 and grunt.get("stun_until", 0.0) > sim.clock and is_equal_approx(float(p.atk_cd), 1.0 / (0.65 * 1.5)), "maul damages / stuns with its faster heavy-weapon cadence")
	boss = boss_at(field + Vector2(25, 0))
	sim.attack(p)
	check(boss.get("slow_until", 0.0) > sim.clock and boss.get("stun_until", 0.0) == 0.0, "maul slows boss instead of stunning")
	reset()
	give("explosive_arrow", 3)
	check(not sim.use_tactical_item(p, "explosive_arrow", field + Vector2.RIGHT * 200) and sim.count(p, "explosive_arrow") == 3, "explosive arrows require a bow")
	give("starter_bow", 1)
	grunt = enemy(field + Vector2(70, 0))
	b = enemy(field + Vector2(76, 20))
	check(sim.use_tactical_item(p, "explosive_arrow", field + Vector2.RIGHT * 200) and sim.count(p, "explosive_arrow") == 2, "Scout starter bow consumes explosive ammo")
	sim.tick_arrows(0.2)
	check(grunt.hp == 160.0 and b.hp == 160.0 and p.hp == p.maxhp, "explosive arrow damages nearby foes once, no friendly fire")
	check(sim.arrows.size() == 0, "explosive projectile consumed on impact")
	reset()
	give("explosive_arrow", 1)
	give("bow", 1)
	sim.use_tactical_item(p, "explosive_arrow", field + Vector2.RIGHT * 500)
	sim.tick_arrows(1.0)
	check(sim.arrows.size() == 0 and sim.tactical_areas.size() == 1, "explosive arrow detonates at maximum range")
	reset()
	give("repair_kit", 2)
	var door: Vector2 = Vector2(GameSim.DOOR_POS[0])
	var direction: Vector2 = Vector2(GameSim.DOOR_DIR[0])
	p.pos = door + direction * 50
	sim.doors[0] = 300.0
	check(sim.use_tactical_item(p, "repair_kit", door), "begin field door repair")
	sim.tick_field_repair(p, 2.0)
	check(sim.doors[0] == 300.0 and sim.count(p, "repair_kit") == 2, "repair reserves kit until completion")
	sim.tick_field_repair(p, 1.1)
	check(sim.doors[0] == 400.0 and sim.count(p, "repair_kit") == 1, "repair adds 100 HP / consumes one kit")
	sim.use_tactical_item(p, "repair_kit", door)
	p.pos += Vector2(0, 6)
	sim.tick_field_repair(p, 1.0)
	check(sim.count(p, "repair_kit") == 1 and p.repair_kit_t == 0.0, "moving cancels field repair without spending")
	p.pos = door + direction * 50
	sim.use_tactical_item(p, "repair_kit", door)
	sim.hurt(p, 5.0)
	check(p.repair_kit_t == 0.0 and sim.count(p, "repair_kit") == 1, "damage cancels field repair")
	p.role = 0
	check(not sim.use_tactical_item(p, "repair_kit", door), "non-Engineer cannot use repair kit")
	p.role = 2
	sim.phase = "night"
	sim.use_tactical_item(p, "repair_kit", door)
	sim.tick_field_repair(p, 3.1)
	check(sim.doors[0] == 500.0, "field repair works on closed doors at night")
	reset()
	give("repair_kit", 3)
	var wall = {"pos": field + Vector2(60, 0), "hp": 30.0, "maxhp": 200.0, "kind": "wood", "vert": false}
	sim.built_walls.append(wall)
	check(sim.use_tactical_item(p, "repair_kit", Vector2(wall.pos)), "begin wall field repair")
	sim.tick_field_repair(p, 3.1)
	check(wall.hp == 130.0 and sim.count(p, "repair_kit") == 2, "field kit repairs built walls")
	sim.use_tactical_item(p, "repair_kit", Vector2(wall.pos))
	sim.built_walls.clear()
	sim.tick_field_repair(p, 3.1)
	check(sim.count(p, "repair_kit") == 2, "destroyed wall does not consume reserved kit")
	sim.place_tower(0, field + Vector2(60, 0))
	var tower = sim.towers[0]
	tower.hp = 100.0
	check(sim.use_tactical_item(p, "repair_kit", Vector2(tower.pos)), "begin tower field repair")
	sim.tick_field_repair(p, 3.1)
	check(tower.hp == 200.0 and sim.count(p, "repair_kit") == 1, "field kit repairs towers")
	tower.wrecked = true
	tower.hp = 85.0
	sim.use_tactical_item(p, "repair_kit", Vector2(tower.pos))
	sim.tick_field_repair(p, 3.1)
	check(tower.hp == 90.0, "wrecked tower repair stays within 30 percent cap")
	reset()
	give("haste_tonic", 1)
	p.inv[0] = ["haste_tonic", 1]
	p.sel = 0
	sim.action(1, "use_item", field)
	check(sim.count(p, "haste_tonic") == 0 and sim.player_speed(p) > float(GameSim.SPEED), "hotbar use action consumes selected item")
	reset()
	var node = sim.nodes[0]
	node.amount = 5
	p.pos = node.pos
	sim.interact(p, 1.0)
	check(absf(float(p.gather_acc) - 0.35) < 0.001, "gathering uses its normal rate without speed kits")
	reset()
	give("haste_tonic")
	sim.use_tactical_item(p, "haste_tonic", field)
	sim.vine_traps.append({})
	sim.dawn()
	check(sim.vine_traps.size() == 0 and sim.tactical_areas.size() == 0 and sim.player_speed(p) == float(GameSim.SPEED), "dawn clears temporary tactical effects")
	var snapshot = sim.snapshot()
	check(snapshot.has("tactical") and snapshot.ps[1].size() == 36, "snapshot includes tactical state and storage / unlocking HUD fields")
