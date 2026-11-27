extends Main

var review_frame: int = 0
var weapons := ["fists", "stone_spear", "titanium_blade", "hammer", "long_spear", "stun_maul", "starter_bow", "bow", "explosive_arrow"]
var held_review: bool = false

func _ready() -> void:
	Engine.max_fps = 60
	set_physics_process(false)
	my_id = -1
	held_review = "--held-items" in OS.get_cmdline_user_args()
	snap = {"ph": "day"}
	cinfo = JSON.parse_string(FileAccess.get_file_as_string("res://art/chars/chars.json"))
	for skin in ["scout", "healer", "engineer"]:
		csheet[skin] = load("res://art/chars/%s.png" % skin)
	player_view.load_combat_art()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	geometry.static_solids = []
	geometry.rebuild([], [], [])
	clock = 10.0
	var start: float = anim.swing_start("low-fps", true)
	for step in range(1, 4):
		clock = 10.0 + step * 0.1
		if anim.swing_start("low-fps", true) != start:
			Cs.fail("Attack animation restarts before reaching full extension at low frame rates")
			get_tree().quit(1)
			return
	anim.swing_start("low-fps", false)
	clock = 10.4
	if not is_equal_approx(anim.swing_start("low-fps", true), clock):
		Cs.fail("A new attack did not restart its animation")
		get_tree().quit(1)
		return
	anim.swings.clear()
	if not check_attack_selection():
		get_tree().quit(1)
		return
	anim.swings.clear()
	snap.erase("attack_pose")
	clock = 0
	DirAccess.make_dir_recursive_absolute("res://.tmp/combat-readability")
	DirAccess.make_dir_recursive_absolute("res://.tmp/held-items")
	print("ATTACK ANIMATION TIMING OK: low-frame-rate swings finish and new swings restart")

func check_attack_selection() -> bool:
	var bag: Array = SimInventory.empty_slots(8)
	var p := ["Preview", 0, Vector2.ZERO, 90, 90, 0, 0, bag, "bow", 0, 0, true, 0.0, 0, 0, 0, "", 0, 0, false, 0, 0, "attack", Vector2.ZERO, 0, 0, -1, 0, 0, 0, false, 0, -1, -1, 0, 0]
	snap.attack_pose = {90: [1, "explosive_arrow", 0.0]}
	clock = 20
	var attack = anim.player_attack(90, p, "scout")
	if attack == null or attack[0] != "combat_explosive_arrow":
		Cs.fail("Consumed explosive ammo did not select its integrated attack sprite")
		return false
	clock += 0.05
	p[8] = "hammer"
	p[12] = PI
	attack = anim.player_attack(90, p, "scout")
	if attack == null or attack[0] != "combat_explosive_arrow" or not is_zero_approx(float(attack[2])):
		Cs.fail("Changing selection or aim replaced an unfinished attack sprite")
		return false
	p[11] = false
	clock += 0.4
	if anim.player_attack(90, p, "scout") != null:
		Cs.fail("Finished combat sprite did not return to idle")
		return false
	snap.attack_pose[90] = [2, "long_spear", PI]
	attack = anim.player_attack(90, p, "scout")
	if attack == null or attack[0] != "combat_long_spear":
		Cs.fail("A new attack missed between rendered frames did not animate")
		return false
	clock += 0.03
	attack = anim.player_attack(90, p, "scout")
	if attack == null or float(attack[1]) <= 0:
		Cs.fail("Attack identity restarted on an unchanged snapshot")
		return false
	print("INTEGRATED ATTACK SELECTION OK: consumed ammo, fixed pose/aim, return to idle and missed-frame sequencing")
	return true

func _process(_delta: float) -> void:
	clock = review_frame / 60.0
	queue_redraw()

func _draw() -> void:
	if held_review:
		draw_held_review()
		return
	draw_rect(get_viewport_rect(), Color("496C20") if "--grass" in OS.get_cmdline_user_args() else Color("252D35"))
	var role: int = (review_frame / 240) % 3
	var facing: float = ((review_frame % 240) / 30) * PI / 4
	draw_string(ThemeDB.fallback_font, Vector2(24, 28), "INTEGRATED ATTACK SPRITES / " + GameSim.ROLES[role] + " / direction %d" % ((review_frame % 240) / 30), 20)
	for i in range(weapons.size()):
		var weapon: String = weapons[i]
		var foot := Vector2(100 + (i % 3) * 310, 125 + (i / 3) * 155)
		var bag: Array = SimInventory.empty_slots(8)
		if weapon != "fists":
			bag[0] = [weapon, 3]
		var p := ["Preview", role, foot, 90, 90, 0, 0, bag, "bow" if weapon == "explosive_arrow" else weapon, 0, 0, review_frame % 30 < 10, facing, 0, 0, 0, "", 0, 0, false, 0, 0, "attack", Vector2.ZERO, 0, 0, -1, 0, 0, 0, false, 0, -1, -1, 0, 0]
		var reach: float = TacticalItemsView.weapon_reach(weapon)
		if weapon not in ["starter_bow", "bow", "explosive_arrow"]:
			var end_: Vector2 = foot + Vector2.from_angle(facing) * reach
			var side: Vector2 = Vector2.from_angle(facing).orthogonal() * 5
			draw_line(end_ - side, end_ + side, Color("6C7B85"), 1) # Review ruler only; never drawn in game.
		player_view.draw_player(100 + i, p, foot)
		draw_string(ThemeDB.fallback_font, foot + Vector2(-10, 38), weapon.replace("_", " "), 14)
	var captured: int = review_frame
	review_frame += 1
	if captured % 30 in [2, 5, 8, 12]:
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.linear_to_srgb()
		shot.save_png("res://.tmp/combat-readability/weapons-%03d.png" % captured)
	if review_frame >= 720:
		print("COMBAT READABILITY RENDER OK: 9 attacks, all 3 roles, all 8 directions, compact body + weapon sprites and shared melee reach strokes")
		get_tree().quit()

func draw_held_review() -> void:
	draw_rect(get_viewport_rect(), Color("252D35"))
	var view: Vector2 = get_viewport_rect().size
	var role: int = (review_frame / 240) % 3
	var octant: int = (review_frame % 240) / 30
	var facing: float = octant * PI / 4
	var walking: bool = review_frame % 30 >= 15
	var mode: String = "run" if walking else "idle"
	draw_string(ThemeDB.fallback_font, Vector2(24, 28), "HELD ITEMS / %s / %s / direction %d" % [GameSim.ROLES[role], mode, octant], 20)
	var items: Array = cinfo.held.items
	for index in range(items.size()):
		var item: String = items[index]
		var key_: int = 1000 + index
		if review_frame % 30 == 0:
			cmove.erase(key_)
		var base := Vector2((index % 7 + 0.5) * view.x / 7, 75 + (index / 7) * (view.y - 130) / ceili(items.size() / 7.0))
		var foot: Vector2 = base + (Vector2.from_angle(facing) * (review_frame % 15 + 1) if walking else Vector2.ZERO)
		var bag: Array = SimInventory.empty_slots(8)
		if item != "":
			bag[0] = [item, 3]
		# The weapon field is deliberately fists, even when holding a sword or a bow.
		# The renderer must follow the selected stack for all item types.
		var p := ["Preview", role, foot, 90, 90, 0, 0, bag, "fists", 0, 0, false, facing, 0, 0, 0, "", 0, 0, false, 0, 0, "idle", Vector2.ZERO, 0, 0, -1, 0, 0, 0, false, 0, -1, -1, 0, 0]
		player_view.draw_player(key_, p, foot)
		var expected: String = "hold_%s_%s" % ["empty" if item == "" else item, mode]
		if anim_state[key_][0] != expected:
			Cs.fail("Wrong selected-item sprite: %s instead of %s" % [anim_state[key_][0], expected])
			get_tree().quit(1)
			return
		draw_string(ThemeDB.fallback_font, base + Vector2(-45, 35), "empty hands" if item == "" else item.replace("_", " "), 11)
	# One actor changes selected slots over time, including non-weapons and an empty slot.
	var stacks: Array = [["stone_spear", 1], ["titanium_blade", 1], ["hammer", 1], ["bow", 1, 30], ["wood", 3], ["herb", 2], ["chest_key", 1], ["healing_flask", 1]]
	var slot: int = (review_frame / 10) % 9
	var focus := Vector2(view.x * 0.25, view.y - 34)
	var changing := ["Preview", role, focus, 90, 90, 0, 0, stacks, "fists", 0, 0, false, 0.0, 0, 0, 0, "", 0, 0, false, 0, 0, "idle", Vector2.ZERO, 0, mini(slot, 7), -1, 0, 0, 0, false, 0, -1, -1, 0, 0]
	if slot == 8:
		stacks[7] = null
	player_view.draw_player(9000, changing, focus)
	var selected_name: String = "hold_%s_idle" % ["empty" if slot == 8 else stacks[slot][0]]
	if anim_state[9000][0] != selected_name:
		Cs.fail("Changing slots on the same actor left a stale held sprite")
		get_tree().quit(1)
		return
	draw_string(ThemeDB.fallback_font, Vector2(24, view.y - 6), "Slot switching: " + selected_name, 13)
	player_view.char_(9001, Main.ROLE_SKIN[role], Vector2(view.x * 0.65, focus.y), 0.0, 1.0, Color.WHITE, true, "gather", "gather_wood", clock, true, "bow")
	if anim_state[9001][0] != "gather_wood":
		Cs.fail("Holding an item overrode a harvesting pose")
		get_tree().quit(1)
		return
	draw_string(ThemeDB.fallback_font, Vector2(view.x * 0.53, view.y - 6), "Gathering keeps its tool", 13)
	var captured: int = review_frame
	review_frame += 1
	if captured % 30 in [2, 20]:
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.linear_to_srgb()
		shot.save_png("res://.tmp/held-items/held-%03d.png" % captured)
	if review_frame >= 720:
		print("HELD ITEM RENDER ALL OK: %d selections x 3 roles x 8 directions, idle and walking, actual selected-stack sprites" % items.size())
		get_tree().quit()
