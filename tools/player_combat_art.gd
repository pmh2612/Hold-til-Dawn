extends Node

# Offline sprite authoring into the same player PNGs used for walking and farming.
const WEAPONS := ["fists", "stone_spear", "titanium_blade", "hammer", "long_spear", "stun_maul", "starter_bow", "bow", "explosive_arrow"]
const POSES: int = 6
const CANVAS: int = 256
const FOOT := Vector2(128, 144)
const ATLAS_WIDTH: int = 2304
const HELD_WEAPON_SCALE: float = 0.5
# Kept explicit so this offline art tool need not initialize the entire island simulation.
# CombatReadabilityCheck verifies exact coverage against GameSim.ITEMS and COMPONENT_IDS.
const HELD_ITEMS := ["", "wood", "stone", "herb", "titanium", "bandage", "arrow", "revive", "long_spear", "stun_maul", "vine_trap", "poison_flask", "healing_flask", "haste_tonic", "chest_key", "explosive_arrow", "repair_kit", "stone_spear", "titanium_blade", "starter_bow", "bow", "hammer", "light_armour", "stone_armour", "titanium_armour", "battery_cells", "antenna_assembly", "locator_circuit", "backpack"]
const RADIO_PARTS := ["battery_cells", "antenna_assembly", "locator_circuit"]
# Pull back beside the torso, drive outward along the aim, then return along that same line.
# Grip and head translate together: the weapon stays rigid throughout the six poses.
const OUTWARD_PULL := [8.0, 6.0, 2.0, 0.0, 2.0, 7.0]
var painter: PixelChars
var packed: Array = []
var cursor := Vector2i.ZERO
var shelf: int = 0
var packed_images: Dictionary = {}
var item_images: Dictionary = {}

func _ready() -> void:
	painter = PixelChars.new()
	painter.configure_enemy_designs()
	painter.add_three_quarter_views()
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/chars/chars.json"))
	info.combat = {"version": 4, "frames": POSES, "weapons": WEAPONS}
	var held_items: Array = HELD_ITEMS
	info.held = {"version": 1, "items": held_items}
	for skin in ["scout", "healer", "engineer"]:
		# Keep the original cells byte-for-byte, including their existing coordinates.
		# A fixed height makes repeated authoring idempotent instead of appending forever.
		var original := Image.load_from_file("res://art/chars/%s.png" % skin)
		var original_height: int = int(info.chars[skin].size) * 8
		var original_band: Image = original.get_region(Rect2i(0, 0, ATLAS_WIDTH, original_height))
		var clips: Dictionary = {}
		packed = []
		packed_images = {}
		cursor = Vector2i(2, original_height + 2)
		shelf = 0
		for weapon in WEAPONS:
			var rows: Array = []
			for row in range(8):
				var frames: Array = []
				for pose in range(POSES):
					var image: Image = make_pose(skin, weapon, row, pose)
					frames.append(pack_frame(image))
				rows.append(frames)
			var fps: float = 18.0 if weapon in ["hammer", "stun_maul", "starter_bow", "bow", "explosive_arrow"] else 27.0 if weapon == "fists" else 24.0
			clips["combat_" + weapon] = {"weapon": weapon, "fps": fps, "rows": rows}
		var held_clips: Dictionary = {}
		for item in held_items:
			for mode in ["idle", "run"]:
				var rows: Array = []
				for row in range(8):
					var frames: Array = []
					for pose in range(2 if mode == "idle" else 4):
						frames.append(pack_frame(make_held_pose(skin, item, row, mode, pose)))
					rows.append(frames)
				held_clips["hold_%s_%s" % ["empty" if item == "" else item, mode]] = {"item": item, "fps": 2.0 if mode == "idle" else 10.0, "count": 2 if mode == "idle" else 4, "rows": rows}
		var reactions: Dictionary = {}
		for reaction in ["hit_launch", "hit_knockback"]:
			var rows: Array = []
			for row in range(8):
				var frames: Array = []
				for pose in range(POSES):
					frames.append(pack_frame(make_reaction_pose(skin, reaction, row, pose)))
				rows.append(frames)
			reactions[reaction] = {"count": POSES, "fps": POSES / (0.7 if reaction == "hit_launch" else 0.55), "rows": rows}
		var height: int = ceili((cursor.y + shelf + 2) / 64.0) * 64
		var atlas := Image.create_empty(ATLAS_WIDTH, height, false, Image.FORMAT_RGBA8)
		atlas.blit_rect(original_band, Rect2i(Vector2i.ZERO, original_band.get_size()), Vector2i.ZERO)
		for frame_ in packed:
			atlas.blit_rect(frame_[0], Rect2i(Vector2i.ZERO, frame_[0].get_size()), frame_[1])
		if atlas.save_png("res://art/chars/%s.png" % skin) != OK:
			push_error("Cannot save integrated combat atlas: " + skin)
			get_tree().quit(1)
			return
		info.chars[skin].combat = clips
		info.chars[skin].held = held_clips
		info.chars[skin].reactions = reactions
		info.chars[skin].atlas = [ATLAS_WIDTH, height]
		print("INTEGRATED COMBAT ART OK: %s / 9 attacks x 8 directions x 6 poses / %dx%d" % [skin, ATLAS_WIDTH, height])
		print("HELD ITEM ART OK: %s / %d selections x 8 directions x (2 idle + 4 walk) / %dx%d" % [skin, held_items.size(), ATLAS_WIDTH, height])
		print("HIT REACTION ART OK: %s / 2 reactions x 8 directions x 6 poses" % skin)
	var file := FileAccess.open("res://art/chars/chars.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "\t"))
	file.close()
	painter.free()
	get_tree().quit()

func pack_frame(image: Image) -> Array:
	var used: Rect2i = image.get_used_rect().grow(2)
	assert(Rect2i(2, 2, CANVAS - 4, CANVAS - 4).encloses(used), "Player sprite exceeds authoring canvas")
	var crop: Image = image.get_region(used)
	# Identical planted-foot poses share PNG pixels; no runtime copying or synthesis.
	var key: String = "%s/%s/%s" % [used, crop.get_size(), crop.get_data().hex_encode().sha256_text()]
	if packed_images.has(key):
		return packed_images[key]
	if cursor.x + used.size.x + 2 > ATLAS_WIDTH:
		cursor = Vector2i(2, cursor.y + shelf + 2)
		shelf = 0
	packed.append([crop, cursor])
	var region: Array = [cursor.x, cursor.y, used.size.x, used.size.y, FOOT.x - used.position.x, FOOT.y - used.position.y]
	packed_images[key] = region
	cursor.x += used.size.x + 2
	shelf = maxi(shelf, used.size.y)
	return region

func make_held_pose(skin: String, item: String, row: int, mode: String, pose: int) -> Image:
	var view: String = PixelChars.VIEWS[row]
	var dir := Vector2.from_angle(PixelPoses.facing(view))
	var side := dir.orthogonal()
	var body: Image = painter.compose(skin, view, false, true)
	var rig = PixelChars.rig("human", view, painter.palette(skin))
	body.fill_rect(rig.erase_main, Color.TRANSPARENT)
	body.fill_rect(rig.erase_off, Color.TRANSPARENT)
	if rig.patch.size != Vector2i.ZERO:
		body.fill_rect(rig.patch, rig.patch_col)
	var bounce: int = 1 if mode == "idle" and pose == 1 or mode == "run" and pose % 2 == 0 else 0
	if mode == "run" and pose % 2 == 0:
		body = painter.step(body, PixelChars.HUMAN, view, 1 if pose == 0 else -1)
	if bounce:
		body = painter.bob(body, PixelChars.HUMAN)
	var torso: Image = PixelPoses.finish(PixelPoses.embed(body, 48), 37, 7)
	var origin: Vector2 = FOOT - Vector2(16, 29) + Vector2(0, bounce)
	var shoulder: Vector2 = origin + rig.main
	var off: Vector2 = origin + rig.off
	var layer := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var grip: Vector2 = shoulder + Vector2(0, 7) + dir * 2 + side * 3
	var other: Vector2 = off + Vector2(0, 5)
	if item in ["stone_spear", "long_spear", "titanium_blade", "hammer", "stun_maul"]:
		var axis := Vector2(0.4 + dir.x * 0.2, 0.9).normalized()
		draw_weapon(layer, item, grip, grip + axis * weapon_length(item))
		layer = compact_held_weapon(layer, grip)
		if item in ["stone_spear", "long_spear", "stun_maul"]:
			other = grip + axis * 7 * HELD_WEAPON_SCALE
	elif item in ["starter_bow", "bow"]:
		draw_bow(layer, item, grip, dir, side, grip - dir * 5, 5)
		layer = compact_held_weapon(layer, grip)
	elif item != "":
		var icon: Image = held_item_image(item)
		var bulky: bool = item in ["wood", "stone", "titanium", "revive", "repair_kit", "vine_trap", "light_armour", "stone_armour", "titanium_armour", "backpack"]
		var centre: Vector2 = FOOT + Vector2(0, -9 + bounce) + dir * 6 + side * (9 if view.begins_with("up") else 3)
		layer.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i((centre - Vector2(icon.get_size()) / 2).round()))
		grip = centre - side * 4 + Vector2(0, 3)
		if bulky:
			other = centre + side * 4 + Vector2(0, 3)
	else:
		# Empty selection has empty hands, without the role's decorative resting tool.
		grip = shoulder + Vector2(0, 6)
	if mode == "run" and item == "":
		grip += dir * (2 if pose == 0 else -2 if pose == 2 else 0)
	arm(layer, shoulder, grip, rig)
	arm(layer, off, other, rig)
	var result := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	if view.begins_with("up"):
		outline_over(result, layer)
		result.blend_rect(torso, Rect2i(0, 0, 48, 48), Vector2i(FOOT - Vector2(24, 37)))
	else:
		result.blend_rect(torso, Rect2i(0, 0, 48, 48), Vector2i(FOOT - Vector2(24, 37)))
		outline_over(result, layer)
	if row in PixelChars.MIRRORED:
		var flipped := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
		result.flip_x()
		flipped.blit_rect(result, Rect2i(0, 0, CANVAS - 1, CANVAS), Vector2i(1, 0))
		return flipped
	return result

# Offline only: identical equipment scale for held and attacking poses, full-size body.
func weapon_length(weapon: String) -> float:
	return 45.0 if weapon == "long_spear" else 34.0 if weapon == "stone_spear" else 26.0 if weapon == "titanium_blade" else 23.0

func compact_held_weapon(layer: Image, grip: Vector2) -> Image:
	var bounds: Rect2i = layer.get_used_rect().grow(1)
	var weapon: Image = layer.get_region(bounds)
	weapon.resize(maxi(1, roundi(bounds.size.x * HELD_WEAPON_SCALE)), maxi(1, roundi(bounds.size.y * HELD_WEAPON_SCALE)), Image.INTERPOLATE_NEAREST)
	var result := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var at: Vector2 = grip + (Vector2(bounds.position) - grip) * HELD_WEAPON_SCALE
	result.blit_rect(weapon, Rect2i(Vector2i.ZERO, weapon.get_size()), Vector2i(at.round()))
	return result

func held_item_image(item: String) -> Image:
	if item_images.has(item):
		return item_images[item]
	var image: Image
	if item == "chest_key":
		image = Image.create_empty(18, 12, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(1, 1, 7, 7), Color("E7BD5C"))
		image.fill_rect(Rect2i(3, 3, 3, 3), Color("70552A"))
		image.fill_rect(Rect2i(7, 5, 10, 3), Color("E7BD5C"))
		image.fill_rect(Rect2i(12, 7, 2, 4), Color("E7BD5C"))
		image.fill_rect(Rect2i(15, 7, 2, 3), Color("E7BD5C"))
	elif item in RADIO_PARTS:
		image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		if item == "battery_cells":
			for x in [3, 9]:
				image.fill_rect(Rect2i(x, 4, 4, 10), Color("99B8AD"))
				image.fill_rect(Rect2i(x, 11, 4, 3), Color("527E62"))
				image.fill_rect(Rect2i(x + 1, 2, 2, 2), Color("D7E2D9"))
		elif item == "antenna_assembly":
			image.fill_rect(Rect2i(7, 1, 2, 13), Color("9AB1AA"))
			image.fill_rect(Rect2i(2, 3, 12, 2), Color("D4DDD1"))
			image.fill_rect(Rect2i(3, 7, 10, 2), Color("A9C0B7"))
			image.fill_rect(Rect2i(4, 13, 8, 2), Color("D4DDD1"))
		else:
			image.fill_rect(Rect2i(1, 3, 14, 10), Color("3E7950"))
			image.fill_rect(Rect2i(5, 5, 6, 6), Color("253E38"))
			for x in range(3, 14, 3):
				image.fill_rect(Rect2i(x, 12, 1, 3), Color("D3B874"))
	else:
		image = Image.load_from_file("res://art/items/%s.png" % ("revival_kit" if item == "revive" else item))
		image = image.get_region(image.get_used_rect())
		var limit: int = 18 if item in ["arrow", "explosive_arrow"] else 15
		var scale_: float = minf(1.0, float(limit) / maxi(image.get_width(), image.get_height()))
		image.resize(maxi(1, roundi(image.get_width() * scale_)), maxi(1, roundi(image.get_height() * scale_)), Image.INTERPOLATE_NEAREST)
	item_images[item] = image
	return image

func make_pose(skin: String, weapon: String, row: int, pose: int) -> Image:
	var view: String = PixelChars.VIEWS[row]
	var angle: float = PixelPoses.facing(view)
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var body: Image = painter.compose(skin, view, false, true)
	var rig = PixelChars.rig("human", view, painter.palette(skin))
	body.fill_rect(rig.erase_main, Color.TRANSPARENT)
	body.fill_rect(rig.erase_off, Color.TRANSPARENT)
	if rig.patch.size != Vector2i.ZERO:
		body.fill_rect(rig.patch, rig.patch_col)
	var lean: int = [-1, -1, 1, 2, 1, 0][pose]
	var step := Vector2i(roundi(dir.x * lean), roundi(dir.y * lean * 0.6))
	body = PixelPoses.lean(body, int(PixelChars.HUMAN.legs), step)
	var torso: Image = PixelPoses.finish(PixelPoses.embed(body, 48), 37, 7)
	var origin: Vector2 = FOOT - Vector2(16, 29)
	var shoulder: Vector2 = origin + rig.main + Vector2(step.x, maxi(0, step.y))
	var off: Vector2 = origin + rig.off + Vector2(step.x, maxi(0, step.y))
	var layer := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var grip: Vector2 = shoulder + dir * 6
	var other: Vector2 = off + dir * 4
	if weapon in ["stone_spear", "long_spear", "titanium_blade", "hammer", "stun_maul"]:
		# A short arm extension drives the same compact weapon outward.
		# Gameplay reach is shown by the shared ground effect, never a stretched sprite.
		grip = origin + rig.main + Vector2(0, 4) + dir * 10
		var pull: float = OUTWARD_PULL[pose]
		grip -= dir * pull
		var axis: Vector2 = dir
		draw_weapon(layer, weapon, grip, grip + axis * weapon_length(weapon))
		layer = compact_held_weapon(layer, grip)
		if weapon in ["stone_spear", "long_spear"]:
			other = grip + axis * 7 * HELD_WEAPON_SCALE
		elif weapon == "titanium_blade":
			other = off + dir * 2 - side * 3
		else:
			other = grip - axis * 4
	elif weapon in ["starter_bow", "bow", "explosive_arrow"]:
		grip = off + dir * 7
		other = grip - dir * (5 + [0, 4, 8, 1, 0, 0][pose])
		draw_bow(layer, weapon, grip, dir, side, other, pose)
		layer = compact_held_weapon(layer, grip)
		other = grip + (other - grip) * HELD_WEAPON_SCALE
	else:
		grip = shoulder + dir * [3, 6, 16, 18, 9, 3][pose] - side * 2
		other = off + dir * 4 + side * 2
	# Sleeve and hands cover the handle, using each role's own palette.
	arm(layer, shoulder, other if weapon in ["starter_bow", "bow", "explosive_arrow"] else grip, rig)
	arm(layer, off, grip if weapon in ["starter_bow", "bow", "explosive_arrow"] else other, rig)
	var result := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	if view.begins_with("up"):
		outline_over(result, layer)
		result.blend_rect(torso, Rect2i(0, 0, 48, 48), Vector2i(FOOT - Vector2(24, 37)))
	else:
		result.blend_rect(torso, Rect2i(0, 0, 48, 48), Vector2i(FOOT - Vector2(24, 37)))
		outline_over(result, layer)
	if row in PixelChars.MIRRORED:
		# Mirror around the foot, not the half-pixel canvas centre.
		var flipped := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
		result.flip_x()
		flipped.blit_rect(result, Rect2i(0, 0, CANVAS - 1, CANVAS), Vector2i(1, 0))
		return flipped
	return result

func make_reaction_pose(skin: String, reaction: String, row: int, pose: int) -> Image:
	var view: String = PixelChars.VIEWS[row]
	var dir := Vector2.from_angle(PixelPoses.facing(view))
	var body: Image = painter.compose(skin, view, false, true)
	var rig = PixelChars.rig("human", view, painter.palette(skin))
	body.fill_rect(rig.erase_main, Color.TRANSPARENT)
	body.fill_rect(rig.erase_off, Color.TRANSPARENT)
	if rig.patch.size != Vector2i.ZERO:
		body.fill_rect(rig.patch, rig.patch_col)
	var fold: int = [0, 1, 3, 3, 2, 0][pose]
	body = PixelPoses.kneel(body, int(PixelChars.HUMAN.legs), fold)
	var image := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var torso: Image = PixelPoses.embed(body, 48)
	var origin: Vector2 = FOOT - Vector2(16, 29)
	var layer := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var spread: float = [2.0, 5.0, 8.0, 7.0, 4.0, 1.0][pose]
	var lift: float = [0.0, -4.0, -8.0, -6.0, -2.0, 1.0][pose] if reaction == "hit_launch" else [0.0, -3.0, -5.0, -4.0, -1.0, 1.0][pose]
	var shoulder: Vector2 = origin + rig.main + Vector2(0, fold)
	var off: Vector2 = origin + rig.off + Vector2(0, fold)
	arm(layer, shoulder, shoulder + Vector2(spread, lift), rig)
	arm(layer, off, off + Vector2(-spread, lift + 1), rig)
	if view.begins_with("up"):
		outline_over(image, layer)
		outline_over(image, image_at(torso, FOOT - Vector2(24, 37)))
	else:
		outline_over(image, image_at(torso, FOOT - Vector2(24, 37)))
		outline_over(image, layer)
	# Bake the backward tilt into each complete sprite using nearest-pixel sampling, never a runtime filter.
	var degrees: float = -dir.x * ([0.0, 12.0, 22.0, 17.0, 8.0, 0.0][pose] if reaction == "hit_knockback" else [0.0, 5.0, -4.0, 3.0, 1.0, 0.0][pose])
	var centre: Vector2 = FOOT - Vector2(0, 15)
	var rotated := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var bounds: Rect2i = image.get_used_rect().grow(14)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var source: Vector2 = (Vector2(x, y) - centre).rotated(-deg_to_rad(degrees)) + centre
			rotated.set_pixel(x, y, image.get_pixel(roundi(source.x), roundi(source.y)))
	if row in PixelChars.MIRRORED:
		var flipped := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
		rotated.flip_x()
		flipped.blit_rect(rotated, Rect2i(0, 0, CANVAS - 1, CANVAS), Vector2i(1, 0))
		return flipped
	return rotated

func image_at(source: Image, at: Vector2) -> Image:
	var result := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	result.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(at))
	return result

func arm(image: Image, shoulder: Vector2, hand: Vector2, rig) -> void:
	PixelPoses.seg(image, shoulder, hand, 2, rig.arm)
	PixelPoses.dot(image, hand, 3, rig.hand)

func outline_over(image: Image, layer: Image) -> void:
	var used: Rect2i = layer.get_used_rect().grow(1)
	var crop: Image = layer.get_region(used)
	var outlined := Image.create_empty(used.size.x, used.size.y, false, Image.FORMAT_RGBA8)
	PixelPoses.over(outlined, crop, true)
	image.blend_rect(outlined, Rect2i(Vector2i.ZERO, used.size), used.position)

# Scan-line pixel polygons: hard palette edges at one texel per world pixel.
func polygon(image: Image, points: PackedVector2Array, colour: Color) -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	for y in range(floori(bounds.position.y), ceili(bounds.end.y) + 1):
		var crossings: Array[float] = []
		var scan: float = y + 0.5
		for index in range(points.size()):
			var a: Vector2 = points[index]
			var b: Vector2 = points[(index + 1) % points.size()]
			if (a.y <= scan and b.y > scan) or (b.y <= scan and a.y > scan):
				crossings.append(a.x + (scan - a.y) * (b.x - a.x) / (b.y - a.y))
		crossings.sort()
		for index in range(0, crossings.size() - 1, 2):
			for x in range(ceili(crossings[index] - 0.5), ceili(crossings[index + 1] - 0.5)):
				PixelPoses.set_(image, Vector2(x, y), colour)

func local_polygon(image: Image, grip: Vector2, axis: Vector2, points: Array, colour: String) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(grip + axis * point.x + axis.orthogonal() * point.y)
	polygon(image, transformed, Color(colour))

func draw_weapon(image: Image, weapon: String, grip: Vector2, tip: Vector2) -> void:
	var axis: Vector2 = (tip - grip).normalized()
	var length: float = grip.distance_to(tip)
	if weapon in ["stone_spear", "long_spear"]:
		var head: float = 12 if weapon == "stone_spear" else 17
		PixelPoses.seg(image, grip - axis * 12, tip - axis * (head - 3), 3, Color("996B40"))
		PixelPoses.seg(image, grip - axis * 11 - axis.orthogonal(), tip - axis * head - axis.orthogonal(), 1, Color("D2A773"))
		local_polygon(image, grip, axis, [Vector2(length - head, -3), Vector2(length - 7, -4), Vector2(length, 0), Vector2(length - 7, 4), Vector2(length - head, 3)], "A0ADB6" if weapon == "long_spear" else "929A9B")
		local_polygon(image, grip, axis, [Vector2(length - head, -3), Vector2(length - 7, -4), Vector2(length, 0), Vector2(length - head, 0)], "DDE9ED" if weapon == "long_spear" else "C7CEC7")
		for wrap in range(4):
			var at: Vector2 = tip - axis * (head + wrap * 2)
			PixelPoses.seg(image, at - axis.orthogonal() * 2, at + axis.orthogonal() * 2, 1, Color("D5C396"))
	elif weapon == "titanium_blade":
		PixelPoses.seg(image, grip - axis * 8, grip + axis * 4, 3, Color("6B4533"))
		local_polygon(image, grip, axis, [Vector2(5, -4), Vector2(length - 10, -4), Vector2(length, 0), Vector2(length - 10, 4), Vector2(5, 4)], "8DAEBE")
		local_polygon(image, grip, axis, [Vector2(5, -4), Vector2(length - 10, -4), Vector2(length, 0), Vector2(5, 0)], "E9F4F6")
		PixelPoses.seg(image, grip + axis * 3 - axis.orthogonal() * 7, grip + axis * 3 + axis.orthogonal() * 7, 3, Color("D4A858"))
		PixelPoses.dot(image, grip - axis * 9, 4, Color("D4A858"))
	else:
		var width: float = 8 if weapon == "hammer" else 11
		var depth: float = 11 if weapon == "hammer" else 16
		PixelPoses.seg(image, grip - axis * 8, tip - axis * 4, 3, Color("A47647"))
		local_polygon(image, grip, axis, [Vector2(length - depth, -width), Vector2(length - 2, -width), Vector2(length, -width + 2), Vector2(length, width - 2), Vector2(length - 2, width), Vector2(length - depth, width)], "8498A4")
		local_polygon(image, grip, axis, [Vector2(length - depth, -width), Vector2(length - 2, -width), Vector2(length - 2, -width + 3), Vector2(length - depth, -width + 3)], "E0EAEB")
		local_polygon(image, grip, axis, [Vector2(length - depth, width - 3), Vector2(length - 1, width - 3), Vector2(length - 2, width), Vector2(length - depth, width)], "526570")
		if weapon == "stun_maul":
			local_polygon(image, grip, axis, [Vector2(length - 11, -4), Vector2(length - 7, -4), Vector2(length - 7, 4), Vector2(length - 11, 4)], "65C8BA")

func draw_bow(image: Image, weapon: String, grip: Vector2, dir: Vector2, side: Vector2, hand: Vector2, pose: int) -> void:
	var limbs: Array[Vector2] = []
	var pull: float = [0.0, 1.0, 2.0, 0.0, 0.0, 0.0][pose]
	for index in range(-8, 9):
		var t: float = index / 8.0
		limbs.append(grip + side * t * 15 + dir * (4 - t * t * (9 + pull)))
	for index in range(limbs.size() - 1):
		PixelPoses.seg(image, limbs[index], limbs[index + 1], 2, Color("BD8E53" if weapon == "starter_bow" else "8F663E"))
	var string_hand: Vector2 = hand if pose < 3 else grip - dir * 5
	PixelPoses.seg(image, limbs[0], string_hand, 1, Color("DDD8BD"))
	PixelPoses.seg(image, string_hand, limbs[-1], 1, Color("DDD8BD"))
	PixelPoses.seg(image, grip - side * 3, grip + side * 3, 3, Color("6C4930" if weapon == "starter_bow" else "A34737"))
	if weapon != "starter_bow":
		PixelPoses.dot(image, limbs[0], 3, Color("B5C9D4"))
		PixelPoses.dot(image, limbs[-1], 3, Color("B5C9D4"))
	if pose < 3:
		var tip: Vector2 = grip + dir * 17
		PixelPoses.seg(image, hand - dir * 3, tip - dir * 3, 1, Color("D0A371"))
		polygon(image, PackedVector2Array([tip, tip - dir * 5 - side * 3, tip - dir * 5 + side * 3]), Color("E99750" if weapon == "explosive_arrow" else "D5E1E4"))
		PixelPoses.seg(image, hand - dir * 3 - side * 2, hand - dir * 2 + side * 2, 1, Color("C4654F"))
