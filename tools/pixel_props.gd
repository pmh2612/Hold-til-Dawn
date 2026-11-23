class_name PixelProps
extends Node
# Pixel-art props for the base (GDD 4.3 / 5.1 / 6): the old lighthouse that carries the beacon, the workbench,
# the defence tower (AGT-12) standing and wrecked, and the helicopter landing pad (FML-13).
# Same rules as the characters: 1 px = 1 game px, GDD palette, light from the upper left, 1 px dark outline.
# Not part of the game. Run: godot --headless --path . tools/PixelProps.tscn
# Writes art/props/<name>.png and art/props/props.json ({name: [anchor_x, anchor_y]}, the pixel on the ground point).
# The PNGs are plain pixel art and can be repainted by hand.
const INK = Color("141019")
const SHADOW = Color(0.04, 0.06, 0.1, 0.38)
static var CONCRETE = [Color("A3A8B0"), Color("8A8F98"), Color("6A6F7C")]
static var STEEL = [Color("B4C4D4"), Color("8FA3B8"), Color("5B6B7C")]
static var RED = [Color("D9534A"), Color("B8322E"), Color("7E2320")]
static var WHITE = [Color("FFFFFF"), Color("E8E3D8"), Color("B9B4AA")]
static var WOOD = [Color("C08A50"), Color("A0703C"), Color("7A5634"), Color("5A3E26")]
const AMBER = Color("F2B544")
const GLOW = Color("FFF1B8")
const DARK = Color("2B2F36")
var props = {}

func _ready() -> void:
	var out = "res://art/props"
	for output_argument in OS.get_cmdline_user_args():
		if output_argument.begins_with("--out="):
			out = output_argument.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	self.save(out, "lighthouse", self.lighthouse(), Vector2(14, 73 + LH_EXTRA))
	self.save(out, "workbench", self.workbench(), Vector2(31, 45))
	# the shared storage chest: 4 frames side by side, shut to wide open (src/world/view/base_props.gd)
	self.save(out, "chest", self.chest_sheet(), Vector2(18, 35))
	self.save(out, "tower", self.tower(false), Vector2(13, 57 + TOWER_EXTRA))
	self.save(out, "tower_wreck", self.tower(true), Vector2(13, 57 + TOWER_EXTRA))
	self.save(out, "pad", self.pad(), Vector2(128, 128))
	# built walls (ITM-07, ITM-11): 3 x 1 tiles, anchor = centre of the footprint
	for stone in [false, true]:
		var kind = "stone" if stone else "wood"
		self.save(out, "wall_" + kind + "_h", self.wall(stone, false), Vector2(49, 31))
		self.save(out, "wall_" + kind + "_v", self.wall(stone, true), Vector2(17, 63))
	var fa = FileAccess.open(out.path_join("props.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(props, "\t"))
	fa.close()
	get_tree().quit()

func save(out, n, im, anchor) -> void:
	im.save_png(out.path_join(Cs.s(n) + ".png"))
	props[n] = [anchor.x, anchor.y]
	print("drew ", n, " ", im.get_size())
# --- the props ---------------------------------------------------------------
# extra pixels of tower body: tall enough to stand well above the base's roof, so it is seen from outside
const LH_EXTRA: int = 36

func lighthouse() -> Variant:
	# The old lighthouse at the heart of Lighthouse Outpost; its lamp is the beacon (GDD 5.1).
	var d: int = LH_EXTRA
	var im = Image.create_empty(28, 76 + d, false, Image.FORMAT_RGBA8)
	self.shadow(im, Vector2(19, 72 + d), 12, 3)
	# plinth
	self.block(im, Rect2i(2, 66 + d, 24, 8), CONCRETE)
	for y in range(22, 66 + d):
		var half = 6 + int(3.0 * (y - 22) / (43.0 + d))
		var band = RED if (65 + d - y) / 9 % 2 == 0 else WHITE
		for x in range(14 - half, 14 + half):
			var c: Color = band[1]
			if x < 14 - half + 2:
				c = band[0]
			elif x >= 14 + half - 3:
				c = band[2]
			im.set_pixel(x, y, c)
	# door
	im.fill_rect(Rect2i(12, 58 + d, 4, 8), Color("2B2024"))
	# windows up the stair
	for wy in [34, 34 + d / 2 + 6, 40 + d]:
		im.fill_rect(Rect2i(13, wy, 2, 3), Color("2B2024"))
	# gallery rail
	im.fill_rect(Rect2i(4, 18, 20, 1), Color("5B5F6B"))
	im.fill_rect(Rect2i(4, 21, 20, 1), Color("3A3F48"))
	for x in range(4, 24, 3):
		im.fill_rect(Rect2i(x, 19, 1, 2), Color("3A3F48"))
	# lamp room
	im.fill_rect(Rect2i(9, 9, 10, 9), AMBER)
	im.fill_rect(Rect2i(12, 11, 4, 4), GLOW)
	for x in [9, 18]:
		im.fill_rect(Rect2i(x, 9, 1, 9), Color("3A3F48"))
	for r in 5:
		im.fill_rect(Rect2i(8 + r, 8 - r, 12 - 2 * r, 1), RED[1] if r > 0 else RED[2])
	im.fill_rect(Rect2i(9, 7, 2, 1), RED[0])
	im.fill_rect(Rect2i(13, 2, 2, 2), Color("3A3F48"))
	self.outline(im)
	return im

# small typed helper for the furniture below
static func fill(im, x: int, y: int, w: int, h: int, c: Color) -> void:
	im.fill_rect(Rect2i(x, y, w, h), c)

func workbench() -> Variant:
	# The team's workbench (crafting, MEC-10), about 2 tiles wide: a pegboard of hanging tools at the back, a deep
	# plank top with a vise, a blueprint, a hammer and a red tool box, a front apron with two drawers, and logs
	# and metal bars on the low shelf. Stands against the base's north wall.
	var im = Image.create_empty(62, 48, false, Image.FORMAT_RGBA8)
	var w0: Color = WOOD[0]
	var w1: Color = WOOD[1]
	var w2: Color = WOOD[2]
	var w3: Color = WOOD[3]
	var s0: Color = STEEL[0]
	var s1: Color = STEEL[1]
	var s2: Color = STEEL[2]
	self.shadow(im, Vector2(34, 45), 29, 3)
	# pegboard with its posts
	fill(im, 4, 2, 54, 19, w2)
	fill(im, 4, 2, 54, 1, w1)
	for y in range(5, 20, 4):
		for x in range(8 + y / 4 % 2 * 2, 56, 4):
			im.set_pixel(x, y, w3)
	fill(im, 3, 1, 3, 24, w3)
	fill(im, 56, 1, 3, 24, w3)
	fill(im, 3, 1, 1, 24, w2)
	# hanging tools: wrench, saw, pliers, a coil of rope
	fill(im, 10, 5, 2, 11, s1)
	fill(im, 9, 4, 4, 2, s1)
	fill(im, 10, 4, 2, 1, w2)
	fill(im, 9, 15, 4, 2, s1)
	fill(im, 11, 15, 1, 1, w2)
	fill(im, 17, 6, 12, 5, s0)
	fill(im, 17, 10, 12, 1, s2)
	for x in range(17, 29, 2):
		im.set_pixel(x, 11, s2)
	fill(im, 29, 6, 4, 5, RED[1])
	fill(im, 30, 7, 2, 3, RED[2])
	fill(im, 37, 5, 1, 9, s1)
	fill(im, 40, 5, 1, 9, s1)
	fill(im, 37, 13, 1, 4, RED[1])
	fill(im, 40, 13, 1, 4, RED[1])
	fill(im, 38, 8, 2, 2, s2)
	var rope: Color = Color("D8C08A")
	var rope_d: Color = Color("A88F5A")
	fill(im, 45, 6, 8, 8, rope)
	fill(im, 47, 8, 4, 4, w2)
	fill(im, 45, 12, 8, 2, rope_d)
	fill(im, 48, 4, 2, 2, w3)
	# the top: planks running along the bench
	fill(im, 1, 21, 60, 10, w1)
	fill(im, 1, 21, 60, 1, w0)
	fill(im, 1, 24, 60, 1, w2)
	fill(im, 1, 28, 60, 1, w2)
	fill(im, 1, 21, 1, 10, w0)
	fill(im, 60, 21, 1, 10, w2)
	# apron with two drawers
	fill(im, 1, 31, 60, 6, w2)
	fill(im, 1, 31, 60, 1, w3)
	for x in [8, 37]:
		fill(im, x, 32, 17, 4, w1)
		fill(im, x, 35, 17, 1, w3)
		fill(im, x + 7, 33, 3, 1, s0)
	# legs, a low shelf and what is on it
	fill(im, 3, 37, 4, 9, w3)
	fill(im, 55, 37, 4, 9, w3)
	fill(im, 3, 37, 1, 9, w2)
	fill(im, 7, 42, 48, 2, w3)
	for x in [11, 16, 13]:
		var y: int = 37 if x == 13 else 39
		fill(im, x, y, 6, 3, w1)
		fill(im, x, y, 2, 3, Color("E0B880"))
		im.set_pixel(x, y + 1, w2)
	fill(im, 38, 39, 7, 3, s1)
	fill(im, 38, 39, 7, 1, s0)
	fill(im, 40, 37, 7, 2, s0)
	fill(im, 40, 38, 7, 1, s1)
	# vise at the left end, sticking up
	fill(im, 4, 16, 9, 6, s2)
	fill(im, 4, 16, 9, 1, s1)
	fill(im, 5, 15, 3, 1, s0)
	fill(im, 13, 18, 4, 1, s1)
	fill(im, 8, 22, 3, 3, s2)
	# blueprint
	var paper: Color = Color("E8E3D8")
	var ink: Color = Color("4F7FC0")
	fill(im, 17, 22, 15, 6, paper)
	fill(im, 17, 27, 15, 1, Color("B9B4AA"))
	fill(im, 19, 23, 6, 1, ink)
	fill(im, 19, 23, 1, 3, ink)
	fill(im, 22, 25, 8, 1, ink)
	fill(im, 27, 23, 1, 3, ink)
	# hammer lying on the top
	fill(im, 34, 26, 8, 1, w3)
	fill(im, 42, 24, 2, 4, s1)
	fill(im, 42, 24, 2, 1, s0)
	# tool box at the right end
	fill(im, 46, 15, 11, 7, RED[1])
	fill(im, 46, 15, 11, 1, RED[0])
	fill(im, 46, 19, 11, 1, RED[2])
	fill(im, 50, 13, 3, 1, DARK)
	fill(im, 49, 14, 1, 1, DARK)
	fill(im, 53, 14, 1, 1, DARK)
	fill(im, 51, 17, 1, 1, AMBER)
	self.outline(im)
	return im

func chest_sheet() -> Variant:
	# The shared storage chest (BAL-18): a banded wooden chest with a brass lock. Frame 0 shut, 1 the lid lifting,
	# 2 half open (the underside of the lid shows), 3 wide open with the team's materials inside.
	var fw: int = 36
	var fh: int = 37
	var sheet = Image.create_empty(fw * 4, fh, false, Image.FORMAT_RGBA8)
	for f in range(4):
		var im = self.chest(f, fw, fh)
		sheet.blit_rect(im, Rect2i(0, 0, fw, fh), Vector2i(f * fw, 0))
	return sheet

func chest(f: int, fw: int, fh: int) -> Variant:
	var im = Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
	var w0: Color = WOOD[0]
	var w1: Color = WOOD[1]
	var w2: Color = WOOD[2]
	var w3: Color = WOOD[3]
	var s0: Color = STEEL[0]
	var s1: Color = STEEL[1]
	var s2: Color = STEEL[2]
	var brass: Color = AMBER
	var brass_d: Color = Color("B8862E")
	var hollow: Color = Color("2B2024")
	self.shadow(im, Vector2(20, 34), 16, 3)
	var l: int = 3
	var r: int = 33
	var wd: int = r - l
	# body: front face 22..34 with planks, steel bands and corner brackets
	fill(im, l, 22, wd, 12, w2)
	fill(im, l, 22, wd, 1, w1)
	fill(im, l, 27, wd, 1, w3)
	fill(im, l, 31, wd, 1, w3)
	fill(im, l, 22, 1, 12, w1)
	for x in [7, 28]:
		fill(im, x, 22, 2, 12, s1)
		fill(im, x, 22, 1, 12, s0)
	fill(im, l, 32, 3, 2, s2)
	fill(im, r - 3, 32, 3, 2, s2)
	# feet
	fill(im, 4, 34, 4, 1, w3)
	fill(im, 28, 34, 4, 1, w3)
	# brass catch on the body
	fill(im, 16, 22, 4, 3, brass_d)
	fill(im, 17, 23, 2, 1, brass)
	if f == 0:
		# shut: the lid's top face and its front face with the lock plate
		fill(im, l, 11, wd, 6, w1)
		fill(im, l, 11, wd, 1, w0)
		fill(im, l, 14, wd, 1, w2)
		fill(im, l, 17, wd, 5, w2)
		fill(im, l, 17, wd, 1, w0)
		fill(im, l, 21, wd, 1, w3)
		for x in [7, 28]:
			fill(im, x, 11, 2, 11, s1)
			fill(im, x, 11, 1, 11, s0)
		fill(im, 15, 18, 6, 6, brass)
		fill(im, 15, 23, 6, 1, brass_d)
		fill(im, 17, 20, 2, 2, hollow)
	else:
		# open: the hollow inside, back wall and side walls of the body around it
		fill(im, l, 15, wd, 7, hollow)
		fill(im, l, 15, wd, 1, w3)
		fill(im, l, 15, 2, 7, w2)
		fill(im, r - 2, 15, 2, 7, w3)
		fill(im, l, 21, wd, 1, w1)
		if f >= 2:
			# the team's materials: a log, stones, herbs, metal bars; lit warm when wide open
			var lit: bool = f == 3
			fill(im, 7, 18, 7, 3, w0 if lit else w1)
			fill(im, 7, 18, 2, 3, Color("E0B880"))
			fill(im, 15, 17, 4, 4, CONCRETE[0] if lit else CONCRETE[1])
			fill(im, 15, 17, 4, 1, CONCRETE[0])
			fill(im, 18, 19, 2, 2, CONCRETE[2])
			fill(im, 21, 16, 1, 4, Color("3E8E4A"))
			fill(im, 22, 17, 2, 1, Color("6CC070"))
			fill(im, 20, 17, 1, 1, Color("6CC070"))
			fill(im, 24, 19, 6, 2, s0 if lit else s1)
			fill(im, 25, 18, 5, 1, s0)
			if lit:
				fill(im, 6, 20, 24, 1, Color(1.0, 0.82, 0.45, 1.0).lerp(hollow, 0.55))
		else:
			# just lifting: a glint of what is inside
			fill(im, 12, 19, 10, 1, brass_d)
		# the lid, hinged at the back edge (row 15)
		if f == 1:
			# tilted up a little: its front face, raised, over a sliver of the inside
			fill(im, l, 9, wd, 5, w1)
			fill(im, l, 9, wd, 1, w0)
			fill(im, l, 14, wd, 4, w2)
			fill(im, l, 14, wd, 1, w0)
			fill(im, l, 17, wd, 1, w3)
			for x in [7, 28]:
				fill(im, x, 9, 2, 9, s1)
				fill(im, x, 9, 1, 9, s0)
			fill(im, 15, 15, 6, 4, brass)
			fill(im, 15, 18, 6, 1, brass_d)
		else:
			# standing up (2) or leaning back (3): its underside faces you
			var top: int = 6 if f == 2 else 2
			var edge: int = 3 if f == 2 else 2
			fill(im, l, top, wd, edge, w1)
			fill(im, l, top, wd, 1, w0)
			fill(im, l, top + edge, wd, 15 - top - edge, w3)
			fill(im, l + 2, top + edge + 1, wd - 4, 15 - top - edge - 2, w2)
			for y in range(top + edge + 3, 14, 3):
				fill(im, l + 2, y, wd - 4, 1, w3)
			for x in [7, 28]:
				fill(im, x, top, 2, 15 - top, s2)
			fill(im, 16, top, 4, 2, brass_d)
	self.outline(im)
	return im
# extra pixels of tower mast (team change: taller towers); Main.TOWER_EXTRA must match
const TOWER_EXTRA: int = 18

func tower(wreck) -> Variant:
	# Defence tower (AGT-12): concrete footing, steel lattice mast, platform, floodlight (amber) and a small gun.
	var d: int = TOWER_EXTRA
	var im = Image.create_empty(26, 60 + d, false, Image.FORMAT_RGBA8)
	self.shadow(im, Vector2(17, 56 + d), 11, 3)
	self.block(im, Rect2i(3, 50 + d, 20, 8), CONCRETE)
	var top = 32 + d if wreck else 20
	for y in range(top, 50 + d):
		var time_left = float(y - 20) / (30.0 + d)
		var l = int(lerpf(9, 6, time_left))
		var r = int(lerpf(16, 19, time_left))
		im.fill_rect(Rect2i(l, y, 2, 1), STEEL[1])
		im.fill_rect(Rect2i(r, y, 2, 1), STEEL[2])
		var k = (y - 20) % 10
		im.set_pixel(l + 2 + int((r - l - 2) * k / 10.0), y, STEEL[2])
		im.set_pixel(r - 1 - int((r - l - 2) * k / 10.0), y, STEEL[2])
	if wreck:
		im.fill_rect(Rect2i(9, 29 + d, 2, 3), STEEL[2])
		im.fill_rect(Rect2i(15, 30 + d, 3, 2), STEEL[2])
		self.block(im, Rect2i(16, 51 + d, 9, 6), [Color("6E7682"), Color("5B6B7C"), Color("3A4250")])
		im.fill_rect(Rect2i(17, 53 + d, 4, 2), Color("3A3530"))
		for p in [Vector2i(1, 55 + d), Vector2i(4, 57 + d), Vector2i(22, 49 + d)]:
			im.fill_rect(Rect2i(p.x, p.y, 2, 2), CONCRETE[2])
	else:
		# platform
		im.fill_rect(Rect2i(4, 15, 18, 5), Color("3A4250"))
		im.fill_rect(Rect2i(4, 15, 18, 1), STEEL[1])
		# head
		im.fill_rect(Rect2i(8, 6, 10, 9), STEEL[2])
		im.fill_rect(Rect2i(8, 6, 10, 1), STEEL[0])
		# floodlight
		im.fill_rect(Rect2i(10, 8, 6, 4), AMBER)
		im.fill_rect(Rect2i(11, 9, 3, 2), GLOW)
		# gun
		im.fill_rect(Rect2i(18, 10, 6, 2), DARK)
		# antenna
		im.fill_rect(Rect2i(12, 2, 1, 4), Color("3A3F48"))
		im.set_pixel(12, 1, RED[0])
	self.outline(im)
	return im

# A built wall seen from above at the game's 2.5D angle: a top face over a 14 px front face.
# Wood = a palisade of sharpened logs; stone = mortared blocks with a capstone row.
func wall(stone: bool, vert: bool) -> Variant:
	var h: int = 14
	var fw: int = 32 if vert else 96
	var fd: int = 96 if vert else 32
	var im = Image.create_empty(fw + 2, fd + h + 2, false, Image.FORMAT_RGBA8)
	var top = Rect2i(1, 1, fw, fd)
	var front = Rect2i(1, fd + 1, fw, h)
	var light: Color = Color("A3A8B0") if stone else Color("C08A50")
	var mid: Color = Color("8A8F98") if stone else Color("A0703C")
	var dark: Color = Color("6A6F7C") if stone else Color("7A5634")
	var deep: Color = Color("4A4E58") if stone else Color("5A3E26")
	im.fill_rect(top, mid)
	im.fill_rect(front, dark)
	if stone:
		# blocks on the top face and the front, offset every other row
		for y in range(top.position.y, top.end.y, 8):
			im.fill_rect(Rect2i(top.position.x, y, fw, 1), deep)
			var shift: int = (y - top.position.y) / 8 % 2 * 6
			for x in range(top.position.x + shift, top.end.x, 12):
				im.fill_rect(Rect2i(x, y, 1, mini(8, top.end.y - y)), deep)
				im.fill_rect(Rect2i(x + 1, y + 1, mini(10, top.end.x - x - 1), 1), light)
		for y in range(front.position.y, front.end.y, 7):
			im.fill_rect(Rect2i(front.position.x, y, fw, 1), deep)
			var shift: int = (y - front.position.y) / 7 % 2 * 6
			for x in range(front.position.x + shift, front.end.x, 12):
				im.fill_rect(Rect2i(x, y, 1, mini(7, front.end.y - y)), deep)
	else:
		# log tops along the wall, logs on the front face
		var across: bool = not vert
		var len_: int = fw if across else fd
		for i in range(0, len_, 8):
			if across:
				im.fill_rect(Rect2i(top.position.x + i, top.position.y, 1, fd), deep)
				im.fill_rect(Rect2i(top.position.x + i + 1, top.position.y, 2, fd), light)
				im.fill_rect(Rect2i(front.position.x + i, front.position.y, 1, h), deep)
				im.fill_rect(Rect2i(front.position.x + i + 1, front.position.y, 2, h), mid)
			else:
				im.fill_rect(Rect2i(top.position.x, top.position.y + i, fw, 1), deep)
				im.fill_rect(Rect2i(top.position.x, top.position.y + i + 1, fw, 2), light)
		# rope bands
		for k in range(1, 3):
			if across:
				im.fill_rect(Rect2i(top.position.x, top.position.y + fd * k / 3, fw, 2), Color("D8C08A"))
			else:
				im.fill_rect(Rect2i(top.position.x + fw * k / 3, top.position.y, 2, fd), Color("D8C08A"))
		if not across:
			for x in range(front.position.x, front.end.x, 8):
				im.fill_rect(Rect2i(x, front.position.y, 1, h), deep)
	# light upper-left edges, dark lower-right edges
	im.fill_rect(Rect2i(top.position.x, top.position.y, fw, 1), light.lightened(0.15))
	im.fill_rect(Rect2i(top.position.x, top.position.y, 1, fd), light.lightened(0.15))
	im.fill_rect(Rect2i(top.end.x - 1, top.position.y, 1, fd), deep)
	im.fill_rect(Rect2i(front.position.x, front.position.y, fw, 1), deep)
	self.outline(im)
	return im

func pad() -> Variant:
	# Landing pad (FML-13): 8 tiles across, dark asphalt, amber ring, white H, blue edge lamps.
	var n = 256
	var im = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c = Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d = Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= 126:
				var col = Color("3A3F48")
				if d > 122:
					col = Color("2B2F36")
				elif d > 104 and d <= 112:
					# dashed ring
					col = AMBER if int(atan2(y - c.y, x - c.x) / TAU * 32.0 + 32) % 2 == 0 else Color("2B2F36")
				elif (x * 7 + y * 13) % 23 == 0:
					# grit
					col = Color("444955")
				im.set_pixel(x, y, col)
	var w = WHITE[1]
	# H
	im.fill_rect(Rect2i(96, 72, 18, 112), w)
	im.fill_rect(Rect2i(142, 72, 18, 112), w)
	im.fill_rect(Rect2i(114, 119, 28, 18), w)
	for i in 8:
		var p = c + Vector2.from_angle(i * TAU / 8.0) * 117.0
		im.fill_rect(Rect2i(int(p.x) - 2, int(p.y) - 2, 4, 4), Color("4FA3FF"))
	self.outline(im)
	return im

# --- helpers ---------------------------------------------------------------
func block(im, r, shades) -> void:
	# A lit box: light left edge and top, dark right edge.
	im.fill_rect(r, shades[1])
	im.fill_rect(Rect2i(r.position.x, r.position.y, 2, r.size.y), shades[0])
	im.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 1), shades[0])
	im.fill_rect(Rect2i(r.end.x - 2, r.position.y + 1, 2, r.size.y - 1), shades[2])

func shadow(im, c, rx, ry) -> void:
	# Ground shadow to the lower right, like the baked trees (sun from the upper left).
	for y in im.get_height():
		for x in im.get_width():
			var d = Vector2((x + 0.5 - c.x) / rx, (y + 0.5 - c.y) / ry)
			if d.length_squared() <= 1.0:
				im.set_pixel(x, y, SHADOW)

func outline(im) -> void:
	var src = im.duplicate()
	for y in im.get_height():
		for x in im.get_width():
			if self.solid(src, x, y):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if self.solid(src, x + d.x, y + d.y):
					im.set_pixel(x, y, INK)
					break

func solid(im, x, y) -> Variant:
	return x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height() and im.get_pixel(x, y).a > 0.6
