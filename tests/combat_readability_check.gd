extends Node

var checks: int = 0
var failed: bool = false
var sim: GameSim

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("FAIL (exception): " + label)
	else:
		print("ok   ", label)

func _ready() -> void:
	if "--combat-art-only" in OS.get_cmdline_user_args():
		check_combat_assets()
		print(("COMBAT ART FAILED" if failed else "COMBAT ART ALL OK") + ": %d checks" % checks)
		get_tree().quit(1 if failed else 0)
		return
	sim = GameSim.new()
	sim.add_player(1, "Healer", 1)
	sim.add_player(2, "Engineer", 2)
	sim.start_match()
	sim.world.rebuild([], sim.towers, [])
	check_healing()
	check_cave()
	check_weapon_reach()
	check_combat_assets()
	check_attack_identity()
	print(("COMBAT READABILITY FAILED" if failed else "COMBAT READABILITY ALL OK") + ": %d checks" % checks)
	get_tree().quit(1 if failed else 0)

func check_combat_assets() -> void:
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/chars/chars.json"))
	var info: Dictionary = chars.combat
	check(int(info.version) == 4 and int(info.frames) == 6 and info.weapons.size() == 9, "character sprite catalog covers all nine attacks with six poses")
	var total_pixels: int = 0
	var angles := [0.0, PI / 2, PI, -PI / 2, PI / 4, 3 * PI / 4, -3 * PI / 4, -PI / 4]
	for skin in ["scout", "healer", "engineer"]:
		var image := Image.load_from_file("res://art/chars/%s.png" % skin)
		total_pixels += image.get_width() * image.get_height()
		check(image.get_width() == int(chars.chars[skin].atlas[0]) and image.get_height() == int(chars.chars[skin].atlas[1]), skin + " uses one character PNG for walking, farming and all attacks")
		for name_ in ["hit_launch", "hit_knockback"]:
			var reaction: Dictionary = chars.chars[skin].reactions[name_]
			var complete: bool = reaction.rows.size() == 8 and int(reaction.count) == 6
			for direction in reaction.rows:
				var hashes: Dictionary = {}
				complete = complete and direction.size() == 6
				for region in direction:
					var rect := Rect2i(region[0], region[1], region[2], region[3])
					complete = complete and Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect)
					var pose: Image = image.get_region(rect)
					var used: Rect2i = pose.get_used_rect()
					complete = complete and used.has_area() and used.position.x >= 2 and used.position.y >= 2 and used.end.x <= rect.size.x - 2 and used.end.y <= rect.size.y - 2
					hashes[hash(pose.get_data())] = true
				complete = complete and hashes.size() >= 4
			check(complete, skin + " / " + name_ + " has six distinct anchored full-body reaction frames in eight directions")
		for weapon in info.weapons:
			var clip: Dictionary = chars.chars[skin].combat["combat_" + Cs.s(weapon)]
			var complete: bool = clip.rows.size() == 8
			var anchored: bool = true
			var animated: bool = true
			var compact: bool = true
			var lowered: bool = true
			var outward: bool = true
			var held_diameter: float = 0.0
			if weapon not in ["fists", "starter_bow", "bow", "explosive_arrow"]:
				# A rear-facing hand/body can occlude the blade: compare against the
				# largest visible held diameter across directions, not an occluded slice.
				for row in chars.chars[skin].held["hold_" + Cs.s(weapon) + "_idle"].rows:
					held_diameter = maxf(held_diameter, metal_diameter(image, row[0], weapon))
			for direction in range(8):
				complete = complete and clip.rows[direction].size() == 6
				var poses: Dictionary = {}
				for region in clip.rows[direction]:
					var rect := Rect2i(region[0], region[1], region[2], region[3])
					anchored = anchored and rect.position.y >= 8 * int(chars.chars[skin].size) and Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect)
					var frame_: Image = image.get_region(rect)
					poses[hash(frame_.get_data())] = true
					var used: Rect2i = frame_.get_used_rect()
					anchored = anchored and not used.size == Vector2i.ZERO and used.position.x >= 2 and used.position.y >= 2 and used.end.x <= rect.size.x - 2 and used.end.y <= rect.size.y - 2
					anchored = anchored and float(region[4]) >= 0 and float(region[4]) < rect.size.x and float(region[5]) >= 0 and float(region[5]) < rect.size.y
				animated = animated and poses.size() >= 4
				if weapon not in ["fists", "starter_bow", "bow", "explosive_arrow"]:
					# Inspect actual metal pixels in the PNGs, rather than the authoring formula.
					# A straight outward strike advances along aim without an overhead sideways arc.
					var direction_: Vector2 = Vector2.from_angle(angles[direction])
					var centres: Array[Vector2] = []
					for pose in range(4):
						centres.append(metal_centre(image, clip.rows[direction][pose], weapon))
					var finite: bool = centres.all(func(point: Vector2): return point.is_finite())
					outward = outward and finite
					if finite:
						outward = outward and (centres[3] - centres[0]).dot(direction_) >= 5
						for pose in range(1, 4):
							var advance: Vector2 = centres[pose] - centres[pose - 1]
							outward = outward and advance.dot(direction_) >= -0.75 and absf(advance.cross(direction_)) <= 2.5
					var held: Array = chars.chars[skin].held["hold_" + Cs.s(weapon) + "_idle"].rows[direction][0]
					lowered = lowered and metal_centre(image, held, weapon).y > -12
					# Rotation changes the bounding box but must not grow the weapon itself.
					# Compare actual metal-pixel diameters, independent of body/arm movement.
					for region in clip.rows[direction]:
						compact = compact and metal_diameter(image, region, weapon) <= held_diameter + 3.0
			check(complete and anchored, skin + "/" + weapon + " has 48 complete, anchored frames without clipping or atlas bleed")
			check(animated, skin + "/" + weapon + " animates the integrated body and weapon in every direction")
			if weapon not in ["fists", "starter_bow", "bow", "explosive_arrow"]:
				check(compact, skin + "/" + weapon + " attack weapon stays as small as its held art in all eight directions")
				check(lowered, skin + "/" + weapon + " resting weapon points down beside the body rather than above the head")
				check(outward, skin + "/" + weapon + " metal pixels move from the body outward along aim in all eight directions")
	check(total_pixels * 4 <= 48 * 1024 * 1024, "three unified player atlases stay below 48 MiB including every held item, all attacks, walking and farming")
	check_held_assets(chars)
	check_held_selection()

func check_held_assets(chars: Dictionary) -> void:
	var items: Array = [""]
	items.append_array(GameSim.ITEMS.keys())
	for comp in GameSim.COMPONENT_IDS:
		if not items.has(comp):
			items.append(comp)
	check(int(chars.held.version) == 1 and chars.held.items.size() == items.size() and items.all(func(item): return chars.held.items.has(item)), "held sprites cover every inventory item, all three radio components and empty hands")
	for skin in ["scout", "healer", "engineer"]:
		var image := Image.load_from_file("res://art/chars/%s.png" % skin)
		for item in items:
			var complete: bool = true
			var animated: bool = true
			var visible: bool = true
			for mode in ["idle", "run"]:
				var name_: String = "hold_%s_%s" % ["empty" if item == "" else item, mode]
				var clip: Dictionary = chars.chars[skin].held[name_]
				var count_: int = 2 if mode == "idle" else 4
				complete = complete and int(clip.count) == count_ and clip.rows.size() == 8 and clip.item == item
				for direction in range(8):
					var hashes: Dictionary = {}
					complete = complete and clip.rows[direction].size() == count_
					for region in clip.rows[direction]:
						var rect := Rect2i(region[0], region[1], region[2], region[3])
						complete = complete and Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect) and rect.position.y >= 384
						var frame_: Image = image.get_region(rect)
						var used: Rect2i = frame_.get_used_rect()
						complete = complete and used.has_area() and used.position.x >= 2 and used.position.y >= 2 and used.end.x <= rect.size.x - 2 and used.end.y <= rect.size.y - 2
						complete = complete and float(region[4]) >= 0 and float(region[4]) < rect.size.x and float(region[5]) >= 0 and float(region[5]) < rect.size.y
						hashes[hash(frame_.get_data())] = true
					animated = animated and hashes.size() >= (2 if mode == "idle" else 3)
					if item != "":
						var empty: Array = chars.chars[skin].held["hold_empty_" + mode].rows[direction][0]
						var first: Array = clip.rows[direction][0]
						visible = visible and aligned_pose(image, first).get_data() != aligned_pose(image, empty).get_data()
			check(complete and animated, "%s / %s has anchored, animated idle and walking poses in all eight directions" % [skin, "empty hands" if item == "" else item])
			if item != "":
				check(visible, "%s / %s remains visibly different from empty hands in every direction" % [skin, item])

func aligned_pose(image: Image, region: Array) -> Image:
	var result := Image.create_empty(192, 192, false, Image.FORMAT_RGBA8)
	result.blit_rect(image, Rect2i(region[0], region[1], region[2], region[3]), Vector2i(96 - int(region[4]), 120 - int(region[5])))
	return result

func check_held_selection() -> void:
	var p := ["Test", 2, Vector2.ZERO, 90, 90, 0, 0, [["stone_spear", 1], ["wood", 3], ["chest_key", 1], ["healing_flask", 1]], "fists", 0, 0, false, 0.0, 0, 0, 0, "", 0, 0, false, 0, 0, "idle", Vector2.ZERO, 0, 0]
	for slot in range(4):
		p[25] = slot
		check(PlayerView.held_item(p) == p[7][slot][0], "hotbar slot %d shows its actual item even when weapon field says fists" % (slot + 1))
	p[7][3] = null
	check(PlayerView.held_item(p) == "", "dropping or using the selected stack clears held art")
	p[7][3] = ["bandage", 0]
	check(PlayerView.held_item(p) == "", "an exhausted stack cannot leave a stale held item")
	p[7][3] = ["hammer", 1]
	p[5] = 1
	check(PlayerView.held_item(p) == "", "downed players do not carry their selected item")

func metal_centre(image: Image, region: Array, weapon: String) -> Vector2:
	var colours: Array = [Color("A0ADB6"), Color("DDE9ED")] if weapon == "long_spear" else [Color("929A9B"), Color("C7CEC7")] if weapon == "stone_spear" else [Color("8DAEBE"), Color("E9F4F6")] if weapon == "titanium_blade" else [Color("8498A4"), Color("E0EAEB"), Color("526570"), Color("65C8BA")]
	var sum_ := Vector2.ZERO
	var count_: int = 0
	for y in range(int(region[3])):
		for x in range(int(region[2])):
			var pixel: Color = image.get_pixel(int(region[0]) + x, int(region[1]) + y)
			if pixel.a > 0.9 and colours.has(pixel):
				sum_ += Vector2(x - float(region[4]), y - float(region[5]))
				count_ += 1
	return sum_ / count_ if count_ > 0 else Vector2(INF, INF)

func metal_diameter(image: Image, region: Array, weapon: String) -> float:
	var colours: Array = [Color("A0ADB6"), Color("DDE9ED")] if weapon == "long_spear" else [Color("929A9B"), Color("C7CEC7")] if weapon == "stone_spear" else [Color("8DAEBE"), Color("E9F4F6")] if weapon == "titanium_blade" else [Color("8498A4"), Color("E0EAEB"), Color("526570"), Color("65C8BA")]
	var points: Array[Vector2] = []
	for y in range(int(region[3])):
		for x in range(int(region[2])):
			var pixel: Color = image.get_pixel(int(region[0]) + x, int(region[1]) + y)
			if pixel.a > 0.9 and colours.has(pixel):
				points.append(Vector2(x, y))
	var diameter: float = 0.0
	for a in points:
		for b in points:
			diameter = maxf(diameter, a.distance_to(b))
	return diameter if not points.is_empty() else INF

func check_attack_identity() -> void:
	var p = sim.players[1]
	sim.phase = "day"
	p.state = 0
	p.inside = false
	p.craft_idx = -1
	p.channel = 0
	p.atk_cd = 0
	p.item_cd = 0
	p.inv = SimInventory.empty_slots(8)
	p.inv[0] = ["explosive_arrow", 1]
	p.inv[1] = ["bow", 1]
	p.sel = 0
	p.pos = Vector2(0, 640)
	var before: int = int(p.attack_sequence)
	check(SimTacticalItems.use_tactical_item(sim, p, "explosive_arrow", p.pos + Vector2.RIGHT * 100), "last explosive arrow fires successfully")
	var pose: Array = sim.snapshot().attack_pose[1]
	check(sim.count(p, "explosive_arrow") == 0 and int(pose[0]) == before + 1 and pose[1] == "explosive_arrow", "animation keeps the explosive-arrow identity after consuming its final ammo")
	p.sel = 1
	p.aim = PI
	check(sim.snapshot().attack_pose[1] == pose, "changing slot or aim mid-swing does not change the authored attack pose")
	check(sim.snapshot().ps[1].size() == 36, "animation identity preserves the stable 36-field player snapshot")

func check_healing() -> void:
	var p = sim.players[1]
	var ally = sim.players[2]
	p.hp = 40
	ally.hp = 40
	p.pos = Vector2(0, 640)
	ally.pos = p.pos + Vector2(30, 0)
	check(not p.has("flasks") and sim.snapshot().ps[1][10] == 0, "Healer has no free charges or +3 HUD counter")
	for i in range(5):
		sim.action(1, "flask", ally.pos)
		sim.action(1, "use_healing_flask", ally.pos)
	check(p.hp == 40 and ally.hp == 40 and sim.tactical_areas.is_empty(), "old free-heal actions and empty-inventory right clicks cannot heal")
	sim.set_count(p, "healing_flask", 1)
	sim.action(1, "use_healing_flask", ally.pos)
	check(sim.count(p, "healing_flask") == 0 and sim.tactical_areas.size() == 1 and ally.hp == 40, "right click consumes one crafted flask and creates its normal healing area")
	sim.clock += 0.51
	sim.tick_tactical_items()
	check(ally.hp == 44 and p.hp == 44, "crafted flask heals over time rather than granting an instant free 40 HP")
	sim.dawn()
	check(not p.has("flasks") and sim.count(p, "healing_flask") == 0 and sim.snapshot().ps[1][10] == 0, "dawn does not refill free charges or inventory flasks")

func on_wall(world: WorldGeometry, p: Vector2) -> bool:
	for wall in world.cave_walls:
		for polygon in [wall[0], wall[1]]:
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array(polygon)):
				return true
	return false

func check_cave() -> void:
	var w: WorldGeometry = sim.world
	w.rebuild([], [null, null, null], [])
	var samples: int = 0
	var covered: bool = true
	for wall in w.cave_walls:
		for polygon in [wall[0], wall[1]]:
			var outline := PackedVector2Array(polygon)
			var bounds := Rect2(outline[0], Vector2.ZERO)
			for point in outline:
				bounds = bounds.expand(point)
			for y in range(int(bounds.position.y), int(bounds.end.y) + 1, 10):
				for x in range(int(bounds.position.x), int(bounds.end.x) + 1, 10):
					var p := Vector2(x, y)
					if Geometry2D.is_point_in_polygon(p, outline):
						samples += 1
						covered = covered and w.first_hit(p, p, 0.0, true) == 0.0
	check(samples > 300 and covered, "every sampled visible cave wall face and cap is covered by solid collision (%d points)" % samples)
	for octant in range(1, 16):
		var p: Vector2 = w.cave_centre
		var direction := Vector2.from_angle(octant * TAU / 16)
		for step in range(260):
			p = sim.move_actor(p, p + direction * 4, 9.6)
		check(not on_wall(w, p), "swept player movement cannot climb visible cave walls in direction %d" % octant)
	var p: Vector2 = w.cave_entrance + Vector2(3 * 32, 0)
	var goal: Vector2 = w.cave_centre
	for step in range(300):
		p = sim.move_actor(p, p.move_toward(goal, 4), 9.6)
	check(p.distance_to(goal) < 4, "the east-facing cave entrance and central mining aisle remain walkable")
	check(w.harvest_sites.filter(func(site): return site.type == 3 and w.in_cave_floor(site.pos)).size() == 19, "wall collision preserves all 19 titanium veins")
	w.rebuild(sim.nodes, sim.towers, [])

func check_weapon_reach() -> void:
	var p = sim.players[1]
	p.pos = Vector2(0, 640)
	p.inv = SimInventory.empty_slots(8)
	sim.world.static_solids = []
	sim.world.rebuild([], [null, null, null], [])
	for weapon in GameSim.WEAPON_STATS:
		var reach: float = float(GameSim.WEAPON_STATS[weapon][2]) * GameSim.T
		check(is_equal_approx(TacticalItemsView.weapon_reach(weapon), reach), weapon + " effect reads the simulation reach")
		for direction in range(8):
			var angle: float = direction * PI / 4
			var dir := Vector2.from_angle(angle)
			var outline := TacticalItemsView.attack_outline(weapon, p.pos, angle)
			if weapon == "long_spear":
				check(is_equal_approx((outline[1] - p.pos).dot(dir), reach) and is_equal_approx(absf((outline[1] - p.pos).cross(dir)), 10), "long spear effect ends at full 2.6-tile reach with the actual narrow hit width / %d" % direction)
			elif GameSim.WEAPON_STATS[weapon][3]:
				check(outline[-1].is_equal_approx(p.pos + dir * reach), weapon + " trajectory ends at full eight-tile range / %d" % direction)
			else:
				check(outline.size() == 17 and outline[8].is_equal_approx(p.pos + dir * reach) and is_equal_approx(outline[0].distance_to(p.pos), reach), weapon + " effect reaches its actual 90-degree damage arc / %d" % direction)
			if GameSim.WEAPON_STATS[weapon][3]:
				continue
			sim.enemies.clear()
			var near = sim.spawn(GameSim.GRUNT, 0, 0.0)
			var far = sim.spawn(GameSim.GRUNT, 0, 0.0)
			near.pos = p.pos + dir * (reach + near.r - 1)
			far.pos = p.pos + dir * (reach + far.r + 3)
			near.hp = 500
			far.hp = 500
			p.weapon = weapon
			p.aim = angle
			p.atk_cd = 0
			sim.attack(p)
			check(near.hp < 500 and far.hp == 500, weapon + " maximum effect range matches actual enemy-body contact / %d" % direction)
	check(is_equal_approx(TacticalItemsView.weapon_reach("explosive_arrow"), 8 * GameSim.T), "explosive-arrow guide uses the actual eight-tile flight range")
