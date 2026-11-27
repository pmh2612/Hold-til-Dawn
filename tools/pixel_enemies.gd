extends Node
## Offline boss pixel-art authoring from editable poses: hard edges and limited colour ramps.
## Regular enemies retain their original shipped artwork and are never written by this tool.
## godot --headless --path . tools/PixelEnemies.tscn
const GUTTER := 2 # Logical transparent pixels on every side of every pose.
const NAMES := ["boss_juggernaut", "boss_broodmother", "boss_bio_cannon", "boss_burrower", "boss_gatebreaker", "boss_phantom", "boss_ironhide"]
const ANGLES := [0.0, PI / 2, PI, -PI / 2, PI / 4, 3 * PI / 4, -3 * PI / 4, -PI / 4]
const INK := "#1c2226"
var parts: PackedStringArray
var kind: String
var back: bool
var side: float
var facing: float
var pose: int
var dark_eyes: bool
var palette: Array[Color] = []
var colour_cache: Dictionary = {}

func _ready() -> void:
	var out := "res://art/chars"
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).trim_prefix("boss_")
	DirAccess.make_dir_recursive_absolute(out)
	var bosses := {"chars": {}}
	if only != "" and FileAccess.file_exists(out.path_join("bosses.json")):
		bosses = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("bosses.json")))
	var generated: int = 0
	var poses: int = 0
	for name_ in NAMES:
		kind = name_.trim_prefix("boss_")
		if only != "" and kind != only:
			continue
		var is_boss: bool = name_.begins_with("boss_")
		var resolution := 3 if is_boss else 1
		var cell := 56 if kind == "wrecker" else 48
		var padded_cell: int = cell + GUTTER * 2
		var body := 48 if is_boss else 40 if kind == "wrecker" else 32
		var ground := 46.0 if is_boss or kind == "wrecker" else 37.0
		var columns: int = 32 if kind == "juggernaut" else 14
		var sheet := Image.create_empty(padded_cell * columns * resolution, padded_cell * 8 * resolution, false, Image.FORMAT_RGBA8)
		var header := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 %d %d'>" % [cell * resolution, cell * resolution, cell, cell]
		var materials := definitions()
		for row in range(8):
			for col in range(columns):
				# Rasterise each pose separately. Even SVG rasterisers with limited nested
				# viewport clipping cannot leak an attack/death pose into an adjacent cell.
				var source := header + materials + frame(ANGLES[row], col, body / 48.0, cell / 2.0, ground) + "</svg>"
				var image := Image.new()
				var err := image.load_svg_from_string(source)
				if err != OK or image.is_empty():
					push_error("Cannot rasterise " + name_)
					get_tree().quit(1)
					return
				pixel_palette(image)
				sheet.blit_rect(image, Rect2i(0, 0, cell * resolution, cell * resolution), Vector2i((col * padded_cell + GUTTER) * resolution, (row * padded_cell + GUTTER) * resolution))
		if sheet.save_png(out.path_join(name_ + ".png")) != OK:
			get_tree().quit(1)
			return
		var metadata := {"size": padded_cell * resolution, "body": body * resolution, "anchor": [(cell / 2.0 + GUTTER) * resolution, (ground + GUTTER) * resolution], "resolution": resolution, "gutter": GUTTER * resolution, "smooth": false, "pixel_art": true, "anims": {"attack": [6, 4, 10.0], "down": [10, 4, 8.0]}}
		if kind == "juggernaut":
			metadata.anims.merge({"slam_wind": [14, 6, 6.0], "slam_hit": [20, 4, 16.0], "charge_wind": [24, 4, 4.0], "charge_run": [28, 4, 16.0]})
		bosses.chars[name_] = metadata
		generated += 1
		poses += columns * 8
		print("PIXEL ENEMY: ", name_, " / ", sheet.get_size(), " / ", palette.size(), " colours")
	for entry in [["bosses.json", bosses]]:
		var file := FileAccess.open(out.path_join(entry[0]), FileAccess.WRITE)
		file.store_string(JSON.stringify(entry[1], "\t"))
		file.close()
	print("PIXEL ENEMY GENERATION OK: %d boss atlases, %d poses, regular enemy artwork preserved" % [generated, poses])
	get_tree().quit()

func definitions() -> String:
	# Three-tone materials, hard alpha and a small palette match the player sprites.
	palette.clear()
	colour_cache.clear()
	for hex in ["#1c2226", "#25312f", "#2b2627", "#c9e77c", "#eee2c7", "#e5d9c0", "#d6f5ec", "#ddceb1", "#c7b799", "#b88f79", "#ffffe0", "#ffd579", "#df8a46"]:
		palette.append(Color(hex))
	var colours: Array
	match kind:
		"grunt", "juggernaut": colours = ["#f0a06b", "#a64732", "#502e2b"]
		"spitter", "bio_cannon": colours = ["#a4bd76", "#527047", "#263c32"]
		"wrecker", "ironhide": colours = ["#a4b8c4", "#526e84", "#2b3c4f"]
		"broodmother": colours = ["#d99da9", "#924a69", "#412d45"]
		"burrower": colours = ["#dfbc78", "#987044", "#4d3b30"]
		"gatebreaker": colours = ["#c6a17a", "#806044", "#41372f"]
		_: colours = ["#c2eff1", "#70a9bf", "#354d73"]
	var result := "<defs>"
	result += gradient("skin", colours[0], colours[1], colours[2])
	result += gradient("bone", "#fff0cf", "#c1ae8a", "#776b5c")
	result += gradient("steel", "#dce6e9", "#8da7b6", "#40556b")
	result += gradient("acid", "#f2ffc0", "#bad55b", "#607c38")
	result += gradient("egg", "#ffedc0", "#d3b47c", "#8f6a58")
	result += gradient("under", "#77747d", "#4b4553", "#292936")
	result += gradient("hood", "#293947", "#182632", "#0e1824")
	result += "<radialGradient id='eye'><stop stop-color='#ffffe0'/><stop offset='.55' stop-color='#ffd579'/><stop offset='1' stop-color='#df8a46'/></radialGradient>"
	result += "<radialGradient id='shadow'><stop stop-color='#08121b' stop-opacity='.38'/><stop offset='1' stop-color='#08121b' stop-opacity='0'/></radialGradient></defs>"
	result = result.replace("</defs>", "<clipPath id='cell'><rect width='48' height='48'/></clipPath></defs>")
	return result

func gradient(id: String, lit: String, mid: String, shade: String) -> String:
	for hex in [lit, mid, shade]:
		var colour := Color(hex)
		if not palette.has(colour):
			palette.append(colour)
	return "<linearGradient id='%s' x1='0' y1='0' x2='1' y2='1'><stop stop-color='%s'/><stop offset='.34' stop-color='%s'/><stop offset='.34' stop-color='%s'/><stop offset='.7' stop-color='%s'/><stop offset='.7' stop-color='%s'/><stop offset='1' stop-color='%s'/></linearGradient>" % [id, lit, lit, mid, mid, shade, shade]

func pixel_palette(image: Image) -> void:
	var bytes := image.get_data()
	for offset in range(0, bytes.size(), 4):
		if bytes[offset + 3] < 128:
			for channel in range(4):
				bytes[offset + channel] = 0
			continue
		var key: int = (int(bytes[offset]) << 16) | (int(bytes[offset + 1]) << 8) | int(bytes[offset + 2])
		if not colour_cache.has(key):
			var original := Color8(bytes[offset], bytes[offset + 1], bytes[offset + 2])
			var nearest := palette[0]
			var distance: float = INF
			for colour in palette:
				var difference := Vector3(colour.r - original.r, colour.g - original.g, colour.b - original.b).length_squared()
				if difference < distance:
					distance = difference
					nearest = colour
			colour_cache[key] = nearest
		var result: Color = colour_cache[key]
		bytes[offset] = result.r8
		bytes[offset + 1] = result.g8
		bytes[offset + 2] = result.b8
		bytes[offset + 3] = 255
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes)

func frame(angle: float, col: int, scale_: float, cx: float, ground: float) -> String:
	if kind == "juggernaut" and col >= 14:
		return juggernaut_skill_frame(angle, col)
	parts = PackedStringArray()
	facing = angle
	side = absf(cos(angle))
	back = sin(angle) < -0.25
	pose = col - 5 if col in range(6, 10) else 0
	dark_eyes = col == 13
	# Every cell has its own clip: linear sampling can never pick up a neighbour's limb.
	parts.append("<svg x='0' y='0' width='%s' height='%s' viewBox='0 0 48 48' overflow='hidden'>" % [48 if kind != "wrecker" else 56, 48 if kind != "wrecker" else 56])
	parts.append("<g clip-path='url(#cell)'>")
	# Wrecker uses a 56px cell, all other sheets use 48px. Work in the same anatomical space.
	if kind == "wrecker":
		cx = cx * 48 / 56.0
		ground = ground * 48 / 56.0
		scale_ *= 48 / 56.0
	parts.append("<g transform='translate(%.3f %.3f) scale(%.4f) translate(-24 -46)'>" % [cx, ground, scale_])
	ell(Vector2(24, 46), Vector2(18, 2.3), "shadow", 0)
	var bob := 0.0
	var stride := 0.0
	if col == 1:
		bob = 0.35
	elif col in [2, 4]:
		bob = 0.45
		stride = 1.0 if col == 2 else -1.0
	if pose > 0:
		bob = [-0.8, 0.4, 1.0, 0.3][pose - 1]
	if col >= 10:
		var transforms := ["translate(0 0) rotate(-9 24 44)", "translate(3 9) scale(.88 .8)", "translate(14 43) rotate(48) scale(.64 .72) translate(-24 -46)", "translate(11 44) rotate(80) scale(.38 .72) translate(-24 -46)"]
		parts.append("<g transform='%s'>" % transforms[col - 10])
	parts.append("<g transform='translate(0 %.3f)'>" % bob)
	var width := lerpf(1.0, 0.74, side)
	var insect := kind == "broodmother"
	var ghost := kind == "phantom"
	var heavy := kind in ["juggernaut", "gatebreaker", "ironhide", "wrecker"]
	var wide := 12.0 if insect else 10.6 if heavy else 8.3
	var height := 9.0 if insect else 11.0
	if ghost:
		ghost_tails(stride)
	else:
		legs(width, stride, heavy)
	if insect:
		insect_legs(width, stride)
	# Rear arm before the torso; the closer arm overlaps it.
	var far_sign := -1.0 if cos(angle) >= 0 else 1.0
	arm(far_sign, width, stride, heavy, true)
	if ghost:
		path("M 16 17 Q 24 13 32 18 L 36 40 Q 32 38 31 44 Q 26 40 24 45 Q 21 41 17 43 Q 19 38 12 39 Z", "skin")
		line([Vector2(24, 19), Vector2(22, 29), Vector2(23, 40)], "#d6f5ec", .65, .6)
	else:
		ell(Vector2(24, 28), Vector2(wide * width, height), "skin", .65)
		# Belly and deltoid folds break up the old flat diagonal colour bands.
		path("M 18 23 Q 22 20 27 24 M 18 29 Q 22 31 26 30", "none", "#25312f", .5, .4)
		if heavy:
			ell(Vector2(24 - 9 * width, 21), Vector2(5.2 * width, 4.5), "skin", .55)
			ell(Vector2(24 + 9 * width, 21), Vector2(5.2 * width, 4.5), "skin", .55)
	back_parts(width)
	chest(width)
	arm(-far_sign, width, stride, heavy, false)
	head(width)
	if pose in [2, 3] and kind not in ["spitter", "bio_cannon", "phantom"]:
		# Fine dust motes and a curved impact ripple, not a pixelated baked square.
		path("M 10 45 Q 24 40 39 45", "none", "#c7b799", .55, .65 if pose == 3 else .25)
		for i in range(5):
			ell(Vector2(10 + i * 6, 43 - i % 2 * 1.5), Vector2(.45, .45), "#ddceb1", 0, .7)
	parts.append("</g>")
	if col >= 10:
		parts.append("</g>")
	parts.append("</g></g></svg>")
	return "".join(parts)

func juggernaut_skill_frame(angle: float, col: int) -> String:
	parts = PackedStringArray()
	facing = angle
	side = absf(cos(angle))
	back = sin(angle) < -0.25
	pose = 0
	dark_eyes = false
	var w: float = lerpf(1.0, 0.74, side)
	var phase: int = col - 14 if col < 20 else col - 20 if col < 24 else col - 24 if col < 28 else col - 28
	var wind: bool = col < 20
	var impact: bool = col >= 20 and col < 24
	var charge: bool = col >= 28
	var crouch: float = [2.0, 1.0, 0.0, -0.5, -0.5, 0.0][phase] if wind else [5.0, 5.0, 3.0, 1.0][phase] if impact else 3.0
	var stride: float = [1.6, 0.0, -1.6, 0.0][phase] if charge else 0.0
	var lean: float = cos(angle) * (10.0 if charge else 6.0 if col >= 24 else 0.0)
	parts.append("<g clip-path='url(#cell)'>")
	ell(Vector2(24, 46), Vector2(18, 2), "shadow", 0)
	legs(w, stride, true)
	parts.append("<g transform='translate(%.3f %.3f) rotate(%.3f 24 36)'>" % [cos(angle) * (2.0 if charge else 0.0), crouch, -lean])
	var far_sign: float = -1.0 if cos(angle) >= 0 else 1.0
	juggernaut_skill_arm(far_sign, w, col, phase, true)
	ell(Vector2(24, 28), Vector2(10.6 * w, 11), "skin", .65)
	for sign_ in [-1, 1]:
		ell(Vector2(24 + sign_ * 9 * w, 21), Vector2(5.2 * w, 4.5), "skin", .55)
	back_parts(w)
	chest(w)
	head(w)
	juggernaut_skill_arm(-far_sign, w, col, phase, false)
	parts.append("</g>")
	if impact and phase < 3:
		# Pebbles and short floor cracks belong to the impact sprite; the danger circle stays runtime geometry.
		for i in range(5):
			var x: float = 8 + i * 8
			var y: float = 45 - (2 - phase) * (1 + i % 2)
			ell(Vector2(x, y), Vector2(1.0, .7), "#c7b799", .3)
		line([Vector2(9, 46), Vector2(15, 44), Vector2(20, 46)], INK, .8)
		line([Vector2(28, 46), Vector2(33, 44), Vector2(40, 46)], INK, .8)
	parts.append("</g>")
	return "".join(parts)

func juggernaut_skill_arm(sign_: float, w: float, col: int, phase: int, far: bool) -> void:
	var root: Vector2 = Vector2(24 + sign_ * 10 * w, 22 + (1 if far else 0))
	var elbow: Vector2
	var hand: Vector2
	if col < 20:
		var t: float = phase / 5.0
		# Two fists rise above the shoulders, with bent elbows and a clear held peak.
		elbow = Vector2(root.x + sign_ * lerpf(2, 4, t), lerpf(27, 14, t))
		hand = Vector2(24 + sign_ * lerpf(12 * w, 7 * w, t), lerpf(28, 6, t))
	elif col < 24:
		var lift: float = [0.0, 0.0, 4.0, 8.0][phase]
		hand = Vector2(24 + sign_ * 9 * w + cos(facing) * 3, 39 - lift)
		elbow = root.lerp(hand, .5) + Vector2(sign_ * 4, 1)
	else:
		var pump: float = ([0.0, 2.0, 0.0, -2.0][phase] if col >= 28 else -phase * .6) * sign_
		# Leading arm shields the head, trailing arm is tucked back while the legs drive the dash.
		hand = root + Vector2(cos(facing) * (5.0 if not far else -3.0), -4 + sin(facing) * 2 + pump)
		elbow = root + Vector2(sign_ * 4 - cos(facing) * 2, 5 + pump)
	limb(root, elbow, hand, 3.0, "skin")
	ell(hand, Vector2(4, 3.3), "skin", .6)
	line([hand + Vector2(-2, -1), hand + Vector2(2, -1)], "#f0a06b", .8)

func legs(w: float, stride: float, heavy: bool) -> void:
	for sign_ in [-1.0, 1.0]:
		var x: float = 24 + sign_ * 4.3 * w
		var lift := maxf(0, stride * sign_) * 1.9
		var knee := Vector2(x + sign_ * .5, 39 - lift * .4)
		var foot := Vector2(x + cos(facing) * stride * sign_ * 2, 45 - lift)
		limb(Vector2(x, 34), knee, foot, 3.2 if heavy else 2.3, "skin")
		ell(foot + Vector2(cos(facing), .1), Vector2(3.5 if heavy else 2.6, 1.35), "under", .45)
		if heavy:
			path("M %.2f 38 L %.2f 42 L %.2f 42 Z" % [x - 1.5, x - 1.8, x + 1.5], "steel" if kind in ["wrecker", "ironhide"] else "skin", INK, .35)

func limb(a: Vector2, b: Vector2, c: Vector2, r: float, mat: String) -> void:
	# Round caps and a secondary lit stroke provide smooth articulated limbs.
	line([a, b, c], INK, r * 2 + .7)
	line([a, b, c], "url(#%s)" % mat, r * 2)
	line([a + Vector2(-r * .45, -.25), b + Vector2(-r * .45, -.25), c + Vector2(-r * .45, -.25)], "#d8e0c9", .35, .24)
	ell(b, Vector2(r, r * .9), mat, .3)

func arm(sign_: float, w: float, stride: float, heavy: bool, far: bool) -> void:
	var root := Vector2(24 + sign_ * 10 * w, 22 + (1 if far else 0))
	var elbow := root + Vector2(sign_ * 1.8, 7)
	var hand := root + Vector2(sign_ * 1.3 - stride * cos(facing), 14 - absf(stride))
	if pose > 0:
		match pose:
			1:
				hand = root + Vector2(sign_ * 3 - cos(facing) * 3, -10)
				elbow = root + Vector2(sign_ * 5, -3)
			2, 3:
				hand = root + Vector2(cos(facing) * (10 if pose == 2 else 12), 10 + sin(facing) * 4)
				elbow = root.lerp(hand, .5) + Vector2(sign_ * 2, -2)
			4:
				hand += Vector2(cos(facing) * 3, -1)
	if kind == "spitter":
		hand.y -= 3
		elbow.x += sign_ * 1.5
	limb(root, elbow, hand, 2.9 if heavy else 1.6 if kind == "phantom" else 2.0, "skin")
	ell(hand, Vector2(3.3 if heavy else 2.3, 2.7 if heavy else 2.0), "skin", .5)
	if kind == "gatebreaker" and not far:
		path("M %.2f %.2f l 9 -1 l 1 8 l -10 1 Z" % [hand.x - 4, hand.y - 3], "steel")
		line([hand + Vector2(-3, -1), hand + Vector2(4, -1.8)], "#dce8df", .7)
		ell(hand + Vector2(2, -1.7), Vector2(.8, .5), "#d5644e", .2)
	elif kind in ["burrower", "grunt", "wrecker"]:
		for i in range(3):
			var x := hand.x - 1.8 + i * 1.8
			path("M %.2f %.2f q -.5 3 1 4 q 1 -2 .7 -4 Z" % [x, hand.y + 1], "bone", INK, .3)
	elif kind == "phantom":
		for i in range(3):
			path("M %.2f %.2f q 0 3 -1 5" % [hand.x - 1 + i, hand.y], "none", "#bedfe7", .65)

func back_parts(w: float) -> void:
	match kind:
		"spitter":
			for sign_ in [-1, 1]:
				var at := Vector2(24 + sign_ * 8.5 * w, 24)
				ell(at, Vector2(3.5, 5), "acid", .65)
				path("M %.2f 21 q 3 1 0 6" % at.x, "none", "#71954a", .45)
				ell(at + Vector2(-1, -1.5), Vector2(.8, 1.2), "#f1ffc7", 0, .65)
		"bio_cannon":
			for sign_ in [-1, 1]:
				var x: float = 24 + sign_ * 10 * w
				path("M %.2f 22 Q %.2f 14 %.2f 8 L %.2f 8 Q %.2f 16 %.2f 23 Z" % [x - 2, x - 2.8, x - 3, x + 2.5, x + 1, x + 3], "skin")
				ell(Vector2(x, 8.5), Vector2(3.6, 1.8), "acid", .65)
				ell(Vector2(x, 8.5), Vector2(2.3, .8), "hood", .2)
				line([Vector2(x - 1.5, 12), Vector2(x - 1, 19)], "#c7df83", .55, .7)
		"broodmother":
			for at in [Vector2(18, 31), Vector2(24, 33), Vector2(30, 31)]:
				ell(at, Vector2(3, 3.8), "egg", .55)
				path("M %.2f %.2f q 2 -1 2 2" % [at.x - 1, at.y], "none", "#996c69", .45)
		"burrower":
			for i in range(4):
				var x := 14 + i * 6
				path("M %.2f 23 Q %.2f 17 %.2f 13 Q %.2f 14 %.2f 23 Z" % [x - 2, x - 1, x - 3, x + 3, x + 2], "bone", INK, .5)
		"juggernaut":
			for sign_ in [-1, 1]:
				var at := Vector2(24 + sign_ * 11 * w, 19)
				ell(at, Vector2(5.8, 3.7), "bone", .65)
				path("M %.2f %.2f l %.2f -3 l -1 4 Z" % [at.x, at.y - 2, sign_ * 3], "bone", INK, .45)
		"gatebreaker", "wrecker", "ironhide":
			for sign_ in [-1, 1]:
				var x: float = 24 + sign_ * 11 * w
				path("M %.2f 17 Q %.2f 15 %.2f 18 L %.2f 23 Q %.2f 24 %.2f 21 Z" % [x - 4, x, x + 4.5, x + 4, x, x - 4.5], "steel")
				line([Vector2(x - 2.5, 18), Vector2(x + 2.7, 18.7)], "#eff3e9", .5)
				for dotx in [-2, 2]:
					ell(Vector2(x + dotx, 20), Vector2(.55, .55), "#d7cba8", .25)
				if kind == "ironhide":
					path("M %.2f 17 L %.2f 8 L %.2f 17 Z" % [x - 1.8, x - sign_ * 1.3, x + 1.8], "steel", INK, .55)
				elif kind == "wrecker":
					line([Vector2(x - 2, 21), Vector2(x, 22), Vector2(x + 1, 20.5)], "#334455", .55)

func chest(w: float) -> void:
	if back:
		for i in range(4):
			ell(Vector2(24, 22 + i * 3), Vector2(1.3, .8), "bone" if kind in ["grunt", "juggernaut", "burrower"] else "skin", .25)
		return
	match kind:
		"ironhide", "wrecker":
			path("M %.2f 23 Q 24 20 %.2f 23 L %.2f 33 Q 24 39 %.2f 33 Z" % [24 - 7.5 * w, 24 + 7.5 * w, 24 + 6 * w, 24 - 6 * w], "steel", INK, .65)
			path("M 20 24 L 27 25 L 26 29 L 28 30", "none", "#48586a", .65)
			for x in [20, 28]:
				ell(Vector2(x, 32), Vector2(.65, .65), "#dfc797", .25)
		"bio_cannon":
			ell(Vector2(24 + cos(facing) * 3, 28), Vector2(4 * w, 4.8), "hood", .8)
			ell(Vector2(24 + cos(facing) * 3, 28), Vector2(2.3 * w, 3), "acid", .35)
			ell(Vector2(24 + cos(facing) * 3, 28), Vector2(.9, 1.5), "#293b2a", .2)
		"grunt", "juggernaut":
			for i in range(3):
				path("M 18 %.2f Q 21 %.2f 23 %.2f M 25 %.2f Q 28 %.2f 30 %.2f" % [25 + i * 2.4, 24 + i * 2.4, 26 + i * 2.4, 26 + i * 2.4, 24 + i * 2.4, 25 + i * 2.4], "none", "#dca77d", .55, .85)
		"gatebreaker":
			path("M 19 23 L 29 32 M 28 23 L 19 32", "none", "#293d46", 2.0)
			ell(Vector2(24, 27.5), Vector2(1.4, 1.5), "steel", .45)
		"spitter":
			path("M 24 19 Q 22 25 25 30", "none", "#c7e68f", 1.2, .8)
			ell(Vector2(24, 31), Vector2(3.5, 3.2), "skin", .4)

func head(w: float) -> void:
	var h := Vector2(24 + cos(facing) * 2.5, 13.5)
	if kind == "spitter":
		h += Vector2(cos(facing), 1)
	if kind == "phantom":
		path("M 16 17 Q 14 10 22 3 Q 27 7 32 13 L 31 19 Q 24 22 16 17 Z", "skin", INK, .6)
		ell(h + Vector2(0, 1.7), Vector2(4.8 * w, 5), "hood", .45)
	else:
		ell(h, Vector2(5.4 * w, 5.3), "skin", .65)
		ell(h + Vector2(cos(facing) * 1.7, 3), Vector2(3.5 * w, 2.8), "skin", .4)
	if kind == "juggernaut":
		for sign_ in [-1, 1]:
			var x: float = h.x + sign_ * 4 * w
			path("M %.2f %.2f Q %.2f 6 %.2f 2 Q %.2f 6 %.2f 11 Z" % [x - 1.5, h.y - 2, x - sign_ * 1.5, x + sign_ * 1.5, x + sign_ * 3, x + 1.8], "bone", INK, .5)
	elif kind == "grunt":
		for i in range(3):
			var x := h.x - 3 + i * 3
			path("M %.2f 10 L %.2f %.2f L %.2f 11 Z" % [x - .8, x - cos(facing) * 1.4, 5.5 + i % 2, x + 1.4], "bone", INK, .45)
	elif kind in ["wrecker", "gatebreaker", "ironhide"]:
		path("M %.2f %.2f Q %.2f %.2f %.2f %.2f L %.2f %.2f Q %.2f %.2f %.2f %.2f Z" % [h.x - 5.5 * w, h.y, h.x - 5 * w, h.y - 7, h.x + 1, h.y - 6, h.x + 5.4 * w, h.y - 2, h.x + 3, h.y - 1, h.x - 5.5 * w, h.y], "steel", INK, .55)
		if kind == "gatebreaker":
			path("M %.2f %.2f q -1 -4 1 -5 l 1 5 Z" % [h.x, h.y - 5], "#b9634d", INK, .3)
	if back:
		line([h + Vector2(-2, -1), h + Vector2(1, -2)], "#c4d3bb", .45, .35)
		return
	var look := cos(facing) * 1.8
	var near_eye := h + Vector2(2.2 * w + look, .5)
	var far_eye := h + Vector2(-2.2 * w + look, .5)
	for at in [near_eye, far_eye] if side < .9 else [h + Vector2(cos(facing) * 2.7, .5)]:
		ell(at, Vector2(1.5 if side < .9 else 1.4, .95), "#29312e", 0)
		if dark_eyes:
			line([at + Vector2(-.8, 0), at + Vector2(.8, 0)], "#44515a", .55)
		else:
			ell(at, Vector2(.85, .48), "eye", 0)
	if kind == "phantom":
		return
	if kind == "spitter":
		path("M %.2f %.2f q %.2f -2 %.2f 1 l -1 2 q -2 1 -4 -1 Z" % [h.x - 2, h.y + 2.5, cos(facing) * 5, cos(facing) * 6 + 5], "skin", INK, .45)
		path("M %.2f %.2f q 1 2 .5 4" % [h.x + cos(facing) * 4, h.y + 5], "none", "#c9e77c", .65)
	else:
		var mouth := h + Vector2(look, 3.4)
		path("M %.2f %.2f q 3 1 5 0" % [mouth.x - 2.5, mouth.y], "none", "#2b2627", .8)
		for dx in [-1.3, .5, 1.6]:
			path("M %.2f %.2f l .35 1.2 l .5 -1.1 Z" % [mouth.x + dx, mouth.y], "#eee2c7", "none", 0)
		if kind == "burrower":
			ell(h + Vector2(look, 2.3), Vector2(2.5, 1.4), "#b88f79", .35)

func insect_legs(w: float, stride: float) -> void:
	for sign_ in [-1.0, 1.0]:
		for i in range(3):
			var start := Vector2(24 + sign_ * 9 * w, 25 + i * 3)
			var knee := Vector2(24 + sign_ * (18 - i), 23 + i * 5)
			var tip := Vector2(24 + sign_ * 20, 34 + i * 5 - absf(stride) * (i % 2))
			limb(start, knee, tip, 1.0, "skin")
			line([tip, tip + Vector2(sign_, 1)], "#e5d9c0", .5)

func ghost_tails(stride: float) -> void:
	for sign_ in [-1.0, 1.0]:
		path("M %.2f 24 Q %.2f 30 %.2f 36 Q %.2f 39 %.2f 43 Q %.2f 39 %.2f 35 Q %.2f 29 %.2f 24 Z" % [24 + sign_ * 7, 24 + sign_ * 15, 24 + sign_ * 16, 24 + sign_ * 17, 24 + sign_ * (9 + stride), 24 + sign_ * 13, 24 + sign_ * 13, 24 + sign_ * 10, 24 + sign_ * 7], "skin", INK, .35, .8)

func paint(mat: String) -> String:
	return mat if mat.begins_with("#") or mat == "none" else "url(#%s)" % mat

func ell(at: Vector2, radius: Vector2, mat: String, border: float = .6, alpha: float = 1.0) -> void:
	parts.append("<ellipse cx='%.3f' cy='%.3f' rx='%.3f' ry='%.3f' fill='%s' stroke='%s' stroke-width='%.3f' opacity='%.3f'/>" % [at.x, at.y, radius.x, radius.y, paint(mat), INK if border > 0 else "none", border, alpha])

func path(d: String, mat: String, stroke: String = INK, width: float = .6, alpha: float = 1.0) -> void:
	parts.append("<path d='%s' fill='%s' stroke='%s' stroke-width='%.3f' stroke-linejoin='round' stroke-linecap='round' opacity='%.3f'/>" % [d, paint(mat), stroke, width, alpha])

func line(points: Array, colour: String, width: float, alpha: float = 1.0) -> void:
	var d := "M %.3f %.3f" % [points[0].x, points[0].y]
	for i in range(1, points.size()):
		d += " L %.3f %.3f" % [points[i].x, points[i].y]
	path(d, "none", colour, width, alpha)
