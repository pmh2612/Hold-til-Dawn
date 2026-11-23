class_name PixelNature
extends Node

# ---- tools/PixelNature.cs
# Nature pixel art for the island (GDD 4.3 / 6.1): harvestable living pines for the outer forest, rock outcrops,
# shrubs, grass tufts and pebbles, the four resource nodes and what is left of them once gathered, and the
# tileable ground texture. Same rules as tools/PixelChars.cs and tools/PixelProps.cs: 1 px = 1 game px
# (32 px tile), muted GDD palette, light from the upper left, a dark outline, a soft shadow to the lower right.
# Shapes are built from a fixed seed, so every run writes the same PNGs.
# Not part of the game. Run: godot --headless --path . tools/PixelNature.tscn   (then --import once)
# Writes art/nature/<name>_<variant>.png, art/nature/ground.png and art/nature/index.json, and the landmarks
# (tools/PixelLandmarks.cs) to art/landmarks/
# ({name: [anchor_x, anchor_y, solid_radius_px]}: the anchor is the pixel on the ground point; radius 0 = walk through).
# The PNGs are plain pixel art and can be repainted by hand; keep the size or update the anchor in index.json.
# dark to light
static var PINE = hex("16302B", "21453A", "2F5C47", "437554", "5E9062", "7FAA72")
static var FIR = hex("1B3A2C", "285239", "3A6B45", "52864F", "6FA25C", "93BE6E")
static var BARK = hex("3E2B1E", "5A3E26", "7A5634")
static var DEAD = hex("3A3431", "4F4843", "675E56", "857B70", "A39A8E")
static var ROCK = hex("3F474F", "566068", "707A81", "8C959B", "A9B1B5")
static var STONE = hex("565B66", "7D838C", "A3A8B0", "BEC3CA", "D5DAE1")
static var MOSS = hex("4B5E3A", "5F7446", "778C52")
static var SHRUB = hex("2A3F2D", "3A5538", "4E6C44", "668650", "819E5E")
static var HERB = hex("2E7D3E", "4FB862", "7ACC6C", "9BE37A")
static var GRASS = hex("4F6438", "667E45", "819A55", "9CB267")
static var DRY = hex("7A6E45", "978B56", "B5A96E", "CFC48A")
static var ORE_ROCK = hex("1E2030", "2C2F45", "3D415C", "525876", "6C7394")
static var TI = hex("1E2A78", "2F47B8", "4A72E6", "7FB0FF", "D2E6FF")
static var VIOLET = hex("3A2378", "5838B0", "7C5CE0", "A98CFF", "E2D6FF")
static var WOOD_CHIPS = hex("5A3E26", "A0703C", "C08A50", "E0B070")
static var CUT = hex("A0703C", "C08A50", "E0B070")
const PETAL: Color = Color("F2F2F2")
const PETAL_SHADE: Color = Color("C8D2CC")
const INK: Color = Color("141019")
const SHADOW: Color = Color(0.04, 0.06, 0.1, 0.38)
# light comes from the upper left and a little towards the viewer
static var LIGHT: Vector3 = Vector3(-0.55, -0.62, 0.56).normalized()
static var LIGHT2: Vector2 = Vector2(-0.7, -0.7).normalized()
static var BAYER = [0.0, 0.5, 0.75, 0.25]
var index = {}
var out = "res://art/nature"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	# the landmarks (tools/PixelLandmarks.cs); --landmarks-only skips the rest
	draw_landmarks()
	if OS.get_cmdline_user_args().find("--landmarks-only") >= 0:
		get_tree().quit()
		return
	# Living, harvestable forest. Dead trees are no longer placed or indexed.
	var pines = [[36, 56], [40, 62], [44, 68], [38, 60], [42, 66], [34, 52]]
	for i in range(pines.size()):
		save("pine", i, pine(101 + i, pines[i][0], pines[i][1], PINE, false), 7)
	for i in range(5):
		var _d1 = outcrop(301 + i, i)
		var rock = _d1[0]
		var r = _d1[1]
		save("rock", i, rock, r)
	for i in range(3):
		save("shrub", i, shrub(401 + i), 0)
	# rock spires that line the ridges (impassable) and reeds along the streams (walk-through)
	for i in range(3):
		save("crag", i, crag(451 + i, i), 12)
	for i in range(3):
		save("reed", i, reed(481 + i), 0)
	# ground scatter, drawn flat under everything
	for i in range(4):
		save("grass", i, tuft(501 + i, GRASS, 4 + i % 3), 0)
	for i in range(2):
		save("grass_dry", i, tuft(551 + i, DRY, 5 + i), 0)
	for i in range(4):
		save("pebble", i, pebble(601 + i, 3 + i % 3, 2 + i % 2), 0)
	# resource nodes (MEC-08): each kind has a look of its own so it is never mistaken for scenery
	# and as it is gathered (5 units), broken stages 1..4: <name>_dmg<k>_<variant>
	for i in range(3):
		var tree = pine(701 + i, 32 + 2 * i, 50 + 3 * i, FIR, true)
		save("node_wood", i, tree, 8)
		# needles knocked off the crown, never the trunk
		save_stages("node_wood", i, tree, 8)
	for i in range(2):
		var stone = stone_node(801 + i)
		save("node_stone", i, stone, 20)
		save_stages("node_stone", i, stone, 20)
	for i in range(2):
		var herb = herb_node(901 + i)
		save("node_herb", i, herb, 0)
		save_stages("node_herb", i, herb, 0)
	for i in range(2):
		var _d2 = titanium_ore(1001 + i)
		var ore = _d2[0]
		var glow = _d2[1]
		save("node_titanium", i, ore, 19)
		save("node_titanium_glow", i, glow, 0)
		save_stages("node_titanium", i, ore, 19, glow)
	# what is left of a gathered node until dawn
	save("stump", 0, stump(1101), 0)
	save("rubble", 0, rubble(1201), 0)
	save("herb_cut", 0, herb_cut(1301), 0)
	save("ore_left", 0, ore_left(1401), 0)
	ground(1501).save_png(out.path_join("ground.png"))
	print("drew ground (256, 256)")
	var fa = FileAccess.open(out.path_join("index.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(index, "\t"))
	get_tree().quit()

# Material-specific stages keep the source silhouette coherent: a deeper axe cut, fractured stone or cut
# stems. Each is drawn from the full source rather than progressively deleting disconnected pixel islands.
func save_stages(name, variant: int, full, radius: int, glow = null) -> void:
	for stage in range(1, 5):
		var out_ = harvest_stage(name, variant, full, stage)
		save(name + "_dmg" + str(stage), variant, out_, radius)
		if glow != null:
			var g = glow.clone()
			g.keep_where(out_)
			save(name + "_glow_dmg" + str(stage), variant, g, 0)

func save(name, variant: int, c, radius: int) -> void:
	var n = name + "_" + str(variant)
	c.to_image().save_png(out.path_join(n + ".png"))
	index[n] = [c.anchor.x, c.anchor.y, radius]
	if Harvestables.type_of(n) >= 0 and not name.contains("_dmg") and not name.contains("_empty"):
		save_harvest_variants(name, variant, c, radius, out, index)
	print("drew ", n, " (", c.w, ", ", c.h, ")")

# --- trees ------------------------------------------------------------------
# A conifer seen from the 3/4 camera: a trunk and 4-5 drooping tiers of needles, lit from the left.
# A wood node (Node = true) uses the fresher FIR greens, shows an axe notch and has chips at its foot.
func pine(seed_: int, w: int, h: int, pal, node: bool) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(w + 10, h + 5)
	var cx: int = w / 2 + 2
	var gy: int = c.h - 3
	c.anchor = Vector2i(cx, gy)
	c.shadow(cx + 4, gy, w * 0.44, 3.4)
	var tw: int = 5 if w >= 40 else 4
	var left: int = cx - tw / 2
	for y in range(gy - 12, gy + 1):
		var flare: int = 1 if y >= gy - 1 else 0
		for x in range(left - flare, left + tw + flare):
			var b: int = 2 if x <= left else 0 if x >= left + tw - 1 else 1
			c.put(x, y, BARK[b])
	if node:
		# axe notch: pale cut wood on the lit side, and chips on the ground
		c.put(left + tw - 2, gy - 3, CUT[2])
		c.put(left + tw - 1, gy - 3, CUT[1])
		c.put(left + tw - 1, gy - 4, CUT[0])
		c.put(left + tw - 2, gy - 2, BARK[0])
		c.put(cx + 5, gy, CUT[2], 3)
		c.put(cx + 6, gy + 1, CUT[0], 3)
		c.put(cx - 6, gy + 1, CUT[1], 3)
	var n: int = 5 if h >= 60 else 4
	var top: float = gy - h + 1
	var bottom: float = gy - 7
	var band = Cs.arr(c.w * c.h, 0)
	for i in range(n - 1, -1, -1):
		var yb: float = top + (bottom - top) * (i + 1) / n
		var yt: float = top if i == 0 else top + (bottom - top) * (i - 0.85) / n
		var hw: float = w * 0.5 * (0.34 + 0.66 * (i + 1.0) / n)
		var phase: int = r.next(4)
		for y in range(int(yt), int(yb) + 4):
			var v: float = clampf((y - yt) / (yb - yt), 0, 1)
			var half: float = 1.0 + hw * pow(v, 0.8)
			for x in range(int(cx - hw - 2), int(cx + hw + 2) + 1):
				var dx: float = x - cx
				if absf(dx) > half:
					continue
				# drooping bough tips along the bottom edge, lower towards the outside
				var tip: bool = (int(absf(dx)) + phase) % 4 < 2
				var edge: float = yb + 2.0 * absf(dx) / hw - (0 if tip else 1.6)
				if y > edge:
					continue
				var t: float = dx / hw
				var l: float = 0.62 - 0.4 * t + 0.16 * (1 - v) + noise(r) * 0.2
				if y > edge - 1.5:
					l -= 0.22
				var b: int = quant(l, pal.size() - 1, x, y)
				c.put(x, y, pal[b], 2, i + 1)
				band[y * c.w + x] = b
	# a tier hangs over the one below it: darken the boughs just under the upper tier's edge
	for y in range(c.h - 1, 0, -1):
		for x in range(c.w):
			var t: int = c.tag_at(x, y)
			if t <= 1:
				continue
			var above: int = c.tag_at(x, y - 1)
			var above2: int = c.tag_at(x, y - 2)
			if above > 0 and above < t or above2 > 0 and above2 < t:
				var b: int = maxi(0, band[y * c.w + x] - 2)
				c.put(x, y, pal[b], 2, t)
	# the very top catches the most light
	c.put(cx, int(top), pal[-1], 2, 1)
	c.outline(pal[0].darkened(0.55))
	return c

# A bare grey tree: a leaning trunk that splits into thinning limbs, shaded along each limb.
func dead_tree(seed_: int, w: int, h: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(w + 10, h + 5)
	var cx: int = w / 2 + 2
	var gy: int = c.h - 3
	c.anchor = Vector2i(cx, gy)
	c.shadow(cx + 4, gy, w * 0.3, 3.0)
	var segs = []
	var lean: float = float(r.next_double() - 0.5) * 6
	var foot = Vector2(cx + 0.5, gy + 0.5)
	var crown = Vector2(cx + 0.5 + lean, gy - h * 0.45)
	segs.append([foot, crown, 2.9, 2.0])
	# roots
	segs.append([foot + Vector2(0, -1), foot + Vector2(-4, 1), 1.4, 0.6])
	segs.append([foot + Vector2(0, -1), foot + Vector2(4, 1), 1.4, 0.6])
	# a side limb from the trunk
	var mid = foot.lerp(crown, 0.55)
	var side: float = -1 if r.next(2) == 0 else 1
	grow(segs, r, mid, -PI / 2 + side * 1.0, h * 0.2, 1.3, 1, w * 0.5)
	# the crown splits in two or three
	var limbs: int = 2 + r.next(2)
	for k in range(limbs):
		var a: float = -PI / 2 + (k - (limbs - 1) / 2.0) * 0.8 + float(r.next_double() - 0.5) * 0.25
		grow(segs, r, crown, a, h * 0.24, 1.9, 2, w * 0.5)
	# shrink the crown about the foot until every twig fits inside the sprite
	var min_x: float = foot.x
	var max_x: float = foot.x
	var min_y: float = foot.y
	for s in segs:
		for p in [s[0], s[1]]:
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			min_y = minf(min_y, p.y)
	var fit: float = minf(1, minf((foot.y - 3) / maxf(1, foot.y - min_y), minf((foot.x - 3) / maxf(1, foot.x - min_x), (c.w - 4 - foot.x) / maxf(1, max_x - foot.x))))
	for i in range(segs.size()):
		var s = segs[i]
		segs[i] = [foot + (s[0] - foot) * fit, foot + (s[1] - foot) * fit, s[2], s[3]]
	raster(c, segs, DEAD)
	# a dark knot hole on the trunk
	var knot = foot.lerp(crown, 0.35)
	c.put(int(knot.x), int(knot.y), DEAD[0])
	c.outline(DEAD[0].darkened(0.6))
	return c

func grow(segs, r, p: Vector2, ang: float, len_: float, rad: float, depth: int, max_half: float) -> void:
	ang = clampf(ang, -PI + 0.35, -0.35)
	var q = p + Vector2(cos(ang), sin(ang)) * len_
	var rq: float = maxf(0.55, rad * 0.66)
	segs.append([p, q, rad, rq])
	if depth == 0:
		return
	var kids: int = 1 if r.next(3) == 0 else 2
	for k in range(kids):
		var spread: float = (k - (kids - 1) / 2.0) * (0.55 + float(r.next_double()) * 0.3)
		grow(segs, r, q, ang + spread, len_ * (0.62 + float(r.next_double()) * 0.16), rq, depth - 1, max_half)

# Thick tapered segments, each pixel shaded by which side of its limb it lies on.
static func raster(c, segs, pal) -> void:
	for y in range(c.h):
		for x in range(c.w):
			var p = Vector2(x + 0.5, y + 0.5)
			var best: float = 2
			var side: float = 0
			var rad: float = 1
			for s in segs:
				var ab = s[1] - s[0]
				var t: float = clampf((p - s[0]).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
				var q = s[0] + ab * t
				var rr: float = lerpf(s[2], s[3], t)
				var d: float = p.distance_to(q) / rr
				if d < best:
					best = d
					rad = rr
					side = (p - q).dot(LIGHT2) / rr
			if best > 1:
				continue
			var b: int = 0
			if rad < 1.0:
				b = 2 if side > 0.2 else 1
			else:
				b = 4 if side > 0.55 else 3 if side > 0.15 else 2 if side > -0.35 else 1
			c.put(x, y, pal[b])

# --- rocks ------------------------------------------------------------------
# One faceted boulder: a lumpy dome whose sides are flat facets lit from the upper left, with a flatter top
# face. Where it overlaps a boulder drawn before it, its rim is drawn as a dark seam.
# Taper narrows the upper half toward a point (0 = a dome, 0.8 = a spire).
static func boulder(c, r, cx: float, by: float, rx: float, ry: float, pal, moss: bool, tag: int, taper: float = 0) -> void:
	var k: int = 7
	var rad = Cs.arr(k, 0.0)
	var facet = Cs.arr(k, 0.0)
	for i in range(k):
		rad[i] = 0.84 + float(r.next_double()) * 0.16
		facet[i] = (i + 0.5) / k * TAU - PI + float(r.next_double() - 0.5) * 0.3
	var cy: float = by - ry * 0.8
	var top_r: float = 0.5 + float(r.next_double()) * 0.12
	var moss_seed: int = r.next()
	for y in range(int(cy - ry - 1), int(by) + 1):
		for x in range(int(cx - rx - 1), int(cx + rx + 1) + 1):
			var dy: float = (y + 0.5 - cy) / ry
			var dx: float = (x + 0.5 - cx) / (rx * (1 - taper * clampf(-dy, 0, 1)))
			var th: float = atan2(dy, dx)
			var u: float = (th + PI) / TAU * k
			var j: int = int(floorf(u)) % k
			var rr: float = lerpf(rad[j], rad[(j + 1) % k], u - floorf(u))
			var d: float = sqrt(dx * dx + dy * dy)
			if d > rr:
				continue
			var seam: bool = d / rr > 0.9 and c.body(x, y) and c.tag_at(x, y) != tag
			if seam:
				c.put(x, y, pal[0], 2, tag)
				continue
			# the top face sits a little higher than the dome's centre (3/4 view)
			var tdx: float = dx
			var tdy: float = dy + 0.3
			var top_face: bool = sqrt(tdx * tdx + tdy * tdy) < top_r * rr
			var n: Vector3 = Vector3.ZERO
			if top_face:
				n = Vector3(-0.08, -0.3, 1).normalized()
			else:
				var f: float = facet[j]
				n = Vector3(cos(f) * 0.9, sin(f) * 0.9 - 0.1, 0.42).normalized()
			var l: float = clampf((n.dot(LIGHT) + 0.3) / 1.2, 0, 1)
			# the foot of the rock sits in its own shade
			if y >= by - 1:
				l -= 0.25
			var b: int = quant(l, pal.size() - 1, x, y, 0.0)
			var col: Color = pal[b]
			if moss and top_face and value(x, y, 4, moss_seed) > 0.52:
				col = MOSS[clampi(b - 2, 0, MOSS.size() - 1)]
			c.put(x, y, col, 2, tag)
	# a crack or two running down from the top face, lit on its left edge
	var cracks: int = 1 + r.next(2)
	for i in range(cracks):
		var x: int = int(cx + (r.next_double() - 0.5) * rx * 0.8)
		var y: int = int(cy - ry * 0.1)
		var len_: int = 3 + r.next(int(maxf(2, ry * 0.6)))
		for s in range(len_):
			if not c.body(x, y) or c.tag_at(x, y) != tag:
				break
			c.put(x, y, pal[0], 2, tag)
			if c.body(x - 1, y) and c.tag_at(x - 1, y) == tag:
				c.put(x - 1, y, pal[-1], 2, tag)
			y += 1
			x += r.next(3) - 1

# Scenery outcrops: a single boulder, a big one with a small one in front, a pair, a tall standing stone,
# a low wide slab. Returns the sprite and its solid radius.
func outcrop(seed_: int, shape: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c
	var cx: float = 0.0
	var by: float = 0.0
	var radius: int = 0
	if shape == 0:
		c = Canvas.new(40, 30)
		cx = 18
		by = 26
		boulder(c, r, cx, by, 15, 11, ROCK, true, 1)
		radius = 13
	elif shape == 1:
		c = Canvas.new(52, 38)
		cx = 25
		by = 33
		boulder(c, r, cx + 2, by - 2, 19, 14, ROCK, true, 1)
		boulder(c, r, cx - 11, by + 1, 8, 6, ROCK, false, 2)
		radius = 18
	elif shape == 2:
		c = Canvas.new(50, 32)
		cx = 24
		by = 28
		boulder(c, r, cx - 8, by - 1, 13, 10, ROCK, true, 1)
		boulder(c, r, cx + 9, by + 1, 11, 8, ROCK, true, 2)
		radius = 17
	elif shape == 3:
		c = Canvas.new(32, 42)
		cx = 15
		by = 38
		boulder(c, r, cx, by, 11, 17, ROCK, true, 1)
		radius = 10
	else:
		c = Canvas.new(56, 30)
		cx = 27
		by = 26
		boulder(c, r, cx, by, 23, 10, ROCK, true, 1)
		boulder(c, r, cx + 14, by + 2, 6, 5, ROCK, false, 2)
		radius = 19
	c.shadow_under(cx + 4, by, c.w * 0.4, 4)
	c.anchor = Vector2i(int(cx), int(by - 4))
	c.outline(ROCK[0].darkened(0.6))
	return [c, radius]

# A crag: two or three tall jagged spires with rubble at the foot, the pieces of a rock ridge.
func crag(seed_: int, shape: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(38, 54)
	var cx: float = 18
	var by: float = 49
	c.shadow(cx + 5, by, 15, 4)
	var spires = [[-5.0, 0.0, 7.0, 20.0], [5.0, 2.0, 6.0, 15.0], [0.0, 4.0, 5.0, 9.0]] if shape == 0 else [[3.0, 0.0, 8.0, 22.0], [-7.0, 2.0, 6.0, 13.0]] if shape == 1 else [[-6.0, 0.0, 6.0, 16.0], [4.0, 0.0, 7.0, 21.0], [-1.0, 4.0, 6.0, 10.0]]
	var tag: int = 1
	for sp in spires:
		var _old1 = tag
		tag += 1
		boulder(c, r, cx + sp[0], by - sp[1], sp[2], sp[3], ROCK, false, _old1, 0.85)
	# loose rocks at the foot
	for _it2 in [[6, 48], [29, 49], [10, 50]]:
		var x = _it2[0]
		var y = _it2[1]
		c.put(x, y, ROCK[3])
		c.put(x + 1, y, ROCK[2])
		c.put(x, y + 1, ROCK[1])
		c.put(x + 1, y + 1, ROCK[0])
	c.anchor = Vector2i(int(cx), int(by) - 3)
	c.outline(ROCK[0].darkened(0.6))
	return c

# Reeds by the water: thin stems, a few with brown seed heads.
func reed(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(16, 22)
	var gy: int = 20
	var stem = hex("3F5A33", "56733F", "6F8C4A", "8CA65C")
	var head: Color = Color("6B4A2B")
	var head_lit: Color = Color("8C6239")
	var n: int = 5 + r.next(3)
	for i in range(n):
		var x0: float = 8 + (i - (n - 1) / 2.0) * 1.5
		var h: int = 8 + r.next(9)
		var lean: float = (x0 - 8) * 0.25 + float(r.next_double() - 0.5)
		var tx: int = 0
		var ty: int = 0
		for s in range(h + 1):
			tx = int(Cs.round_even(x0 + lean * s / h))
			ty = gy - s
			c.put(tx, ty, stem[mini(stem.size() - 1, s * stem.size() / (h + 1))], 3)
		if r.next(2) == 0:
			c.put(tx, ty + 1, head, 3)
			c.put(tx, ty + 2, head, 3)
			c.put(tx, ty + 3, head, 3)
			c.put(tx, ty + 1, head_lit, 3)
	c.anchor = Vector2i(8, gy)
	return c

# The stone node: a pale quarry boulder with fresh pick marks and loose chips, unlike the dark mossy outcrops.
func stone_node(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(48, 36)
	var cx: float = 22
	var by: float = 31
	boulder(c, r, cx, by - 1, 19, 13, STONE, false, 1)
	if seed_ % 2 == 1:
		boulder(c, r, cx + 12, by + 1, 7, 5, STONE, false, 2)
	# pick marks: a bright chipped face with a dark notch under it
	for i in range(3):
		var x: int = int(cx - 10 + i * 8 + r.next(3))
		var y: int = int(by - 14 + r.next(6))
		if not c.body(x, y):
			continue
		c.put(x, y, STONE[-1])
		c.put(x + 1, y, STONE[-1])
		c.put(x, y + 1, STONE[0])
		c.put(x + 1, y + 1, STONE[1])
	c.shadow_under(cx + 4, by, 18, 4)
	# loose chips around the foot
	for _it1 in [[5, 30], [9, 33], [37, 33], [41, 30]]:
		var x = _it1[0]
		var y = _it1[1]
		c.put(x, y, STONE[3])
		c.put(x + 1, y, STONE[1])
	c.anchor = Vector2i(int(cx), int(by - 5))
	c.outline(STONE[0].darkened(0.6))
	return c

func rubble(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(30, 16)
	c.shadow_under(16, 11, 11, 3)
	for _it1 in [[6, 9, 4], [12, 11, 3], [17, 8, 5], [22, 11, 3], [14, 6, 2]]:
		var x = _it1[0]
		var y = _it1[1]
		var w = _it1[2]
		for dx in range(w):
			c.put(x + dx, y - 1, STONE[4 if dx == 0 else 3])
			c.put(x + dx, y, STONE[1 if dx == w - 1 else 2])
		if r.next(2) == 0:
			c.put(x + 1, y - 2, STONE[3])
	c.anchor = Vector2i(15, 10)
	c.outline(STONE[0].darkened(0.6))
	return c

# --- plants -----------------------------------------------------------------
# A low round bush: a few leafy balls lit from the upper left, seams where they overlap.
func shrub(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(30, 22)
	var cx: float = 13
	var by: float = 18
	c.shadow(cx + 3, by, 12, 3)
	var balls: int = 4 + r.next(2)
	var list = []
	for i in range(balls):
		var t: float = i / (balls - 1.0) - 0.5
		var rad: float = 4.2 + float(r.next_double()) * 2.2 - absf(t) * 2
		list.append([cx + t * 16 + float(r.next_double() - 0.5) * 2, by - rad - (0.5 - absf(t)) * 5, rad])
	Cs.sort_cmp(list, func(a, b): return Cs.compare(a[1], b[1]))
	for i in range(list.size()):
		ball(c, r, list[i][0], list[i][1], list[i][2], SHRUB, i + 1)
	c.anchor = Vector2i(int(cx), int(by) - 2)
	c.outline(SHRUB[0].darkened(0.5))
	return c

static func ball(c, r, cx: float, cy: float, rad: float, pal, tag: int) -> void:
	for y in range(int(cy - rad - 1), int(cy + rad + 1) + 1):
		for x in range(int(cx - rad - 1), int(cx + rad + 1) + 1):
			var dx: float = (x + 0.5 - cx) / rad
			var dy: float = (y + 0.5 - cy) / rad
			var d2: float = dx * dx + dy * dy
			if d2 > 1:
				continue
			if d2 > 0.75 and c.body(x, y) and c.tag_at(x, y) != tag:
				c.put(x, y, pal[0], 2, tag)
				continue
			var n = Vector3(dx, dy, sqrt(maxf(0, 1 - d2)))
			var l: float = clampf((n.dot(LIGHT) + 0.3) / 1.3 + noise(r) * 0.22, 0, 1)
			c.put(x, y, pal[quant(l, pal.size() - 1, x, y)], 2, tag)

# The herb node: a bright medicinal plant with broad leaves and small white flowers (matches the herb icon).
func herb_node(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(30, 24)
	var cx: float = 14.5
	var gy: float = 20.5
	c.shadow(cx + 3, gy, 10, 2.6)
	var n: int = 8
	var leaves = []
	for i in range(n):
		leaves.append(-PI * 0.97 + i * (PI * 0.94 / (n - 1)) + float(r.next_double() - 0.5) * 0.2)
	# the upright leaves are behind, the flat ones in front
	Cs.sort_cmp(leaves, func(a, b): return Cs.compare(absf(sin(b)), absf(sin(a))))
	var base = Vector2(cx, gy - 2)
	var tips = []
	for a in leaves:
		var len_: float = 7 + absf(sin(a)) * 5 + float(r.next_double()) * 2
		var dir = Vector2(cos(a), sin(a) * 0.85)
		leaf(c, base, dir, len_, 2.4, HERB)
		tips.append(base + dir * len_)
	c.outline(Color("123A22"))
	# three small flower heads over the top leaves
	Cs.sort_cmp(tips, func(a, b): return Cs.compare(a.y, b.y))
	var i: int = 0
	while i < 3 and i < tips.size():
		var x: int = int(tips[i].x)
		var y: int = int(tips[i].y) + 1
		c.put(x, y - 1, PETAL)
		c.put(x - 1, y, PETAL)
		c.put(x + 1, y, PETAL_SHADE)
		c.put(x, y + 1, PETAL_SHADE)
		c.put(x, y, HERB[-1])
		i += 1
	c.anchor = Vector2i(int(cx), int(gy) - 1)
	return c

static func leaf(c, base: Vector2, dir: Vector2, len_: float, width: float, pal) -> void:
	dir = dir.normalized()
	var perp = Vector2(-dir.y, dir.x)
	for y in range(int(base.y - len_ - 2), int(base.y + len_ + 2) + 1):
		for x in range(int(base.x - len_ - 2), int(base.x + len_ + 2) + 1):
			var p = Vector2(x + 0.5, y + 0.5) - base
			var u: float = p.dot(dir)
			var v: float = p.dot(perp)
			if u < 0 or u > len_:
				continue
			var hw: float = width * sin(PI * pow(u / len_, 0.8))
			if absf(v) > hw:
				continue
			var lit: float = (perp * signf(v)).dot(LIGHT2)
			var b: int = 3 if absf(v) < 0.6 and u > 1.5 else 2 if lit > 0.1 else 1
			if u < 1.5:
				b = 0
			c.put(x, y, pal[b])

func herb_cut(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(18, 12)
	c.shadow(10, 9, 6, 2)
	for i in range(4):
		var x: int = 5 + i * 2 + r.next(2)
		var h: int = 2 + r.next(3)
		for y in range(h):
			c.put(x, 9 - y, HERB[1 if y == h - 1 else 0])
		c.put(x, 9 - h, HERB[2])
	c.put(13, 9, HERB[1])
	c.put(14, 8, HERB[2])
	c.anchor = Vector2i(9, 8)
	c.outline(Color("123A22"))
	return c

# A wood stump with a pale cut face and growth rings.
func stump(seed_: int) -> Variant:
	var c = Canvas.new(18, 14)
	var cx: float = 8.5
	c.shadow(cx + 3, 11, 7, 2.4)
	for y in range(6, 12):
		for x in range(4, 13):
			var flare: bool = y >= 10
			if not flare and (x == 4 or x == 12):
				continue
			c.put(x, y, BARK[2 if x <= 5 else 0 if x >= 11 else 1])
	for y in range(3, 9):
		for x in range(4, 14):
			var dx: float = (x + 0.5 - cx) / 4.2
			var dy: float = (y + 0.5 - 5.8) / 2.4
			var d: float = dx * dx + dy * dy
			if d > 1:
				continue
			c.put(x, y, BARK[1] if d > 0.62 else CUT[1] if d > 0.3 else CUT[0] if d > 0.12 else CUT[2])
	c.put(6, 5, CUT[2])
	c.anchor = Vector2i(8, 10)
	c.outline(BARK[0].darkened(0.5))
	return c

# Grass tuft: a handful of blades, dark at the root and light at the tip; no outline so it sits in the ground.
func tuft(seed_: int, pal, blades: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(13, 11)
	var gy: int = 9
	for i in range(blades):
		var x0: float = 6 + (i - (blades - 1) / 2.0) * 1.4 + float(r.next_double() - 0.5)
		var h: int = 3 + r.next(5)
		var lean: float = (x0 - 6) * 0.35 + float(r.next_double() - 0.5) * 1.5
		for s in range(h + 1):
			var x: int = int(Cs.round_even(x0 + lean * s / h))
			var y: int = gy - s
			var b: int = mini(pal.size() - 1, s * pal.size() / (h + 1))
			c.put(x, y, pal[b], 3)
	c.anchor = Vector2i(6, gy)
	return c

func pebble(seed_: int, w: int, h: int) -> Variant:
	var c = Canvas.new(w + 3, h + 3)
	for y in range(h):
		for x in range(w):
			if (x == 0 or x == w - 1) and (y == 0 or y == h - 1) and w > 2:
				continue
			var b: int = 1 if y == h - 1 else 4 if x == 0 or y == 0 else 3
			c.put(x + 1, y + 1, ROCK[b], 3)
	for x in range(1, w):
		c.put(x + 1, h + 1, SHADOW, 1)
	c.anchor = Vector2i(w / 2 + 1, h)
	return c

# --- titanium: ore outcrops in the outer zone (GDD 4.3) --------------------------
# A dark slate-blue rock with blue and violet crystal prisms growing out of it, so it never reads as the pale
# grey stone. Also writes node_titanium_glow_<k>: the crystals alone, which the game pulses over the node, with
# the crystal tips marked pure white (where it twinkles).
func titanium_ore(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(48, 44)
	var g = Canvas.new(48, 44)
	var cx: float = 22
	var by: float = 39
	boulder(c, r, cx, by - 1, 17, 11, ORE_ROCK, false, 1)
	if seed_ % 2 == 0:
		boulder(c, r, cx + 13, by + 1, 7, 5, ORE_ROCK, false, 2)
	else:
		boulder(c, r, cx - 13, by + 1, 6, 4, ORE_ROCK, false, 2)
	# crystals, back ones first
	var n: int = 5 + r.next(2)
	var list = []
	for i in range(n):
		var t: float = i / (n - 1.0) - 0.5
		var x: float = cx + t * 22 + float(r.next_double() - 0.5) * 3
		var y: float = by - 13 + absf(t) * 7 + float(r.next_double()) * 2
		var a: float = t * 1.1 + float(r.next_double() - 0.5) * 0.3
		var l: float = 17 - absf(t) * 14 + float(r.next_double()) * 4
		var w: float = 2.6 + float(r.next_double()) * 1.2 - absf(t) * 0.8
		list.append([x, y, a, l, w, r.next(3) == 0])
	Cs.sort_cmp(list, func(p, q): return Cs.compare(p[1], q[1]))
	for k in list:
		crystal(c, g, k[0], k[1], k[2], k[3], k[4], VIOLET if k[5] else TI)
	# a few chips of crystal lying at the foot
	for _it1 in [[6, 41], [11, 42], [35, 42], [40, 40]]:
		var x = _it1[0]
		var y = _it1[1]
		c.put(x, y, TI[3])
		c.put(x + 1, y, TI[1])
	c.shadow_under(cx + 4, by, 17, 4)
	c.anchor = Vector2i(int(cx), int(by - 5))
	g.anchor = c.anchor
	c.outline(ORE_ROCK[0].darkened(0.55))
	return [c, g]

# One hexagonal prism from its foot (X, Y), leaning by A radians from straight up: the face toward the light
# is bright, the far face dark, a pale ridge between them, a pointed tip.
static func crystal(c, g, x: float, y: float, a: float, l: float, w: float, pal) -> void:
	var dir = Vector2(sin(a), -cos(a))
	var side = Vector2(-dir.y, dir.x)
	var tip: float = w * 1.6
	var x0: int = int(x - l - w - 2)
	var x1: int = int(x + l + w + 2)
	var y0: int = int(y - l - w - 2)
	var y1: int = int(y + w + 2)
	var tip_px = Vector2i(-1, -1)
	var tip_u: float = -1
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var d = Vector2(px + 0.5 - x, py + 0.5 - y)
			var u: float = d.dot(dir)
			var v: float = d.dot(side)
			if u < 0 or u > l:
				continue
			var half: float = w if u < l - tip else w * (l - u) / tip
			if absf(v) > half:
				continue
			# Side points to the right of the axis; the light comes from the upper left
			var b: int = 0
			if absf(v) < 0.6:
				b = 4
			elif v < 0:
				b = 4 if u > l - tip else 3
			else:
				b = 2 if u > l - tip else 1
			if v > half - 0.8 and v > 0:
				b = 0
			c.put(px, py, pal[b], 2, 9)
			g.put(px, py, Color(pal[mini(4, b + 1)], 0.9), 3)
			if u > tip_u:
				tip_u = u
				tip_px = Vector2i(px, py)
	if tip_u >= 0:
		g.put(tip_px.x, tip_px.y, Color.WHITE, 3)

# what is left once mined: dark rubble and a few broken crystal stubs
func ore_left(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(30, 18)
	c.shadow_under(16, 13, 11, 3)
	for _it1 in [[6, 11, 4], [12, 13, 3], [17, 10, 5], [22, 13, 3]]:
		var x = _it1[0]
		var y = _it1[1]
		var w = _it1[2]
		for dx in range(w):
			c.put(x + dx, y - 1, ORE_ROCK[4 if dx == 0 else 3])
			c.put(x + dx, y, ORE_ROCK[1 if dx == w - 1 else 2])
	for _it2 in [[11, 10, 3], [19, 8, 2], [15, 12, 2]]:
		var x = _it2[0]
		var y = _it2[1]
		var h = _it2[2]
		for dy in range(h):
			c.put(x, y - dy, TI[4 if dy == h - 1 else 3])
			c.put(x + 1, y - dy, TI[1])
	if r.next(2) == 0:
		c.put(24, 11, VIOLET[3])
	c.anchor = Vector2i(15, 12)
	c.outline(ORE_ROCK[0].darkened(0.55))
	return c

static func disc(c, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(int(cy - ry - 1), int(cy + ry + 1) + 1):
		for x in range(int(cx - rx - 1), int(cx + rx + 1) + 1):
			var dx: float = (x + 0.5 - cx) / rx
			var dy: float = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1:
				c.put(x, y, col)

static func inside(poly_, p: Vector2) -> bool:
	var in_: bool = false
	var i: int = 0
	var j: int = poly_.size() - 1
	while i < poly_.size():
		if (poly_[i].y > p.y) != (poly_[j].y > p.y) and p.x < (poly_[j].x - poly_[i].x) * (p.y - poly_[i].y) / (poly_[j].y - poly_[i].y) + poly_[i].x:
			in_ = not in_
		var _old1 = i
		i += 1
		j = _old1
	return in_

# --- ground -----------------------------------------------------------------
# A 256 x 256 tile (8 x 8 game tiles) that repeats without seams. Near-white values: the game multiplies it
# by the day-grass and outer-zone colours, so it only adds light patches, dark patches and grass marks.
func ground(seed_: int) -> Variant:
	var s: int = 256
	var r = CsRandom.new(seed_)
	var im = Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var levels = [0.9, 0.94, 0.97, 1.0]
	for y in range(s):
		for x in range(s):
			# flat patches with hard edges, like the sprites (no dither: it reads as grain when scaled up)
			var v: float = tiled(x, y, s, 64, seed_) * 0.55 + tiled(x, y, s, 32, seed_ + 7) * 0.3 + tiled(x, y, s, 16, seed_ + 13) * 0.15
			var b: int = quant((v - 0.5) * 1.6 + 0.5, levels.size() - 1, x, y, 0.0)
			var l: float = levels[b]
			im.set_pixel(x, y, Color(l, l, l * 0.985))
	# grass marks: a dark root under a light blade, scattered over the tile
	for i in range(1040):
		var x: int = r.next(s)
		var y: int = r.next(s)
		var tall: bool = r.next(3) == 0
		mark(im, x, y, 0.82)
		mark(im, x, y - 1, 1.0)
		if tall:
			mark(im, x + (-1 if r.next(2) == 0 else 1), y - 2, 1.0)
	# a few dark specks of soil
	for i in range(280):
		mark(im, r.next(s), r.next(s), 0.84)
	return im

static func mark(im, x: int, y: int, l: float) -> void:
	var s: int = im.get_width()
	im.set_pixel((x % s + s) % s, (y % s + s) % s, Color(l, l, l * 0.985))

# --- helpers ----------------------------------------------------------------
static func hex(...codes: Array) -> Variant:
	return codes.map(func(h): return Color(h))

static func noise(r) -> float:
	return float(r.next_double()) - 0.5

# value 0..1 to a palette index 0..Top with a light 2 x 2 ordered dither on the band edges
static func quant(v: float, top: int, x: int, y: int, dither: float = 0.45) -> int:
	var d: float = (BAYER[(x & 1) + 2 * (y & 1)] - 0.375) * dither
	return clampi(int(floorf(v * (top + 1) + d)), 0, top)

static func hash_(x: int, y: int, seed_: int) -> float:
	# C# uint arithmetic: wraps at 32 bits
	var h: int = Cs.u32(x * 374761393 + y * 668265263 + seed_ * 1442695041)
	h = Cs.u32((h ^ (h >> 13)) * 1274126177)
	return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

# smooth value noise with a cell size in pixels
static func value(x: int, y: int, cell: int, seed_: int) -> float:
	var fx: float = float(x) / cell
	var fy: float = float(y) / cell
	var x0: int = int(floorf(fx))
	var y0: int = int(floorf(fy))
	var tx: float = smooth(fx - x0)
	var ty: float = smooth(fy - y0)
	var a: float = lerpf(hash_(x0, y0, seed_), hash_(x0 + 1, y0, seed_), tx)
	var b: float = lerpf(hash_(x0, y0 + 1, seed_), hash_(x0 + 1, y0 + 1, seed_), tx)
	return lerpf(a, b, ty)

# value noise that wraps every Size pixels (Size must be a multiple of Cell)
static func tiled(x: int, y: int, size: int, cell: int, seed_: int) -> float:
	var n: int = size / cell
	var fx: float = float(x) / cell
	var fy: float = float(y) / cell
	var x0: int = int(floorf(fx))
	var y0: int = int(floorf(fy))
	var tx: float = smooth(fx - x0)
	var ty: float = smooth(fy - y0)
	return lerpf(lerpf(_tiled_h(x0, y0, n, seed_), _tiled_h(x0 + 1, y0, n, seed_), tx), lerpf(_tiled_h(x0, y0 + 1, n, seed_), _tiled_h(x0 + 1, y0 + 1, n, seed_), tx), ty)

# local function H of the method above
static func _tiled_h(i: int, j: int, n, seed_) -> float:
	return hash_((i % n + n) % n, (j % n + n) % n, seed_)

static func smooth(t: float) -> float:
	return t * t * (3 - 2 * t)

# ---- tools/PixelExpeditionProps.cs
# Hand-authored pixel geometry using the existing Atlas palettes, anchors and outline pipeline.

func draw_expedition_props() -> void:
	lm("lm_tent", 0, survey_tent(), 12)
	lm("lm_console", 0, research_console(), 12)
	lm("lm_cart", 0, broken_cart(), 10)
	lm("lm_warning", 0, quarantine_sign(), 3)
	lm("lm_cargo_stack", 0, cargo_stack(), 12)
	lm("lm_waterpump", 0, water_pump(), 8)

func survey_tent() -> Variant:
	var c = detail_canvas(102, 75, 51, 66)
	# Side-lit orange survey canvas, dark entrance, guy lines and pegs.
	for y in range(10, 65):
		var half: int = (y - 10) * 43 / 55
		rect(c, 48 - half, y, half + 1, 1, TIN, 3)
		rect(c, 49, y, half + 1, 1, TIN, 2)
	for y in range(28, 65):
		var half: int = (y - 28) * 17 / 37
		rect(c, 49 - half, y, half * 2, 1, HULL, 0)
	line(c, Vector2(48, 10), Vector2(49, 65), TIMBER[4])
	line(c, Vector2(18, 30), Vector2(4, 68), TIMBER[4])
	line(c, Vector2(80, 30), Vector2(96, 68), TIMBER[4])
	rect(c, 3, 65, 3, 6, STEELS, 1)
	rect(c, 95, 65, 3, 6, STEELS, 1)
	rect(c, 25, 40, 9, 5, WHITEWASH, 3)
	rect(c, 28, 38, 3, 9, WHITEWASH, 3)
	return finish_detail(c)

func research_console() -> Variant:
	var c = detail_canvas(66, 64, 33, 57)
	box(c, 8, 35, 46, 14, 15, STEELS, 4801)
	box(c, 14, 9, 34, 6, 25, OLIVE, 4802)
	rect(c, 18, 16, 25, 13, GLASSY, 1)
	for x in range(20, 40, 4):
		rect(c, x, 21 + x % 5, 2, 3, GLASSY, 3)
	rect(c, 18, 40, 21, 5, TYRES, 1)
	for x in range(20, 38, 4):
		rect(c, x, 41, 2, 1, STEELS, 3)
	disc(c, 46, 41, 3, 2, HULL_RED[3])
	rect(c, 11, 52, 5, 8, STEELS, 0)
	rect(c, 48, 52, 5, 8, STEELS, 0)
	line(c, Vector2(52, 47), Vector2(62, 57), TYRES[0])
	return finish_detail(c)

func broken_cart() -> Variant:
	var c = detail_canvas(82, 53, 41, 46)
	box(c, 10, 20, 54, 16, 10, TIMBER, 4811)
	for x in range(13, 64, 10):
		rect(c, x, 24, 2, 13, TIMBER, 1)
	box(c, 23, 7, 22, 12, 13, OLIVE, 4812)
	line(c, Vector2(60, 32), Vector2(79, 43), STEELS[1])
	wheel(c, 23, 42, 8)
	wheel(c, 58, 45, 5)
	rect(c, 47, 37, 10, 2, TIMBER, 4)
	return finish_detail(c)

func quarantine_sign() -> Variant:
	var c = detail_canvas(48, 64, 24, 58)
	rect(c, 22, 15, 5, 44, TIMBER, 2)
	box(c, 4, 7, 39, 3, 26, TIN, 4813)
	rect(c, 7, 14, 33, 19, WHITEWASH, 2)
	for y in range(15, 25):
		rect(c, 23 - (y - 15), y, (y - 15) * 2 + 1, 1, RUSTY, 2)
	rect(c, 22, 19, 3, 4, TYRES, 0)
	rect(c, 23, 25, 1, 1, TYRES, 0)
	rect(c, 10, 29, 26, 2, TYRES, 1)
	return finish_detail(c)

func cargo_stack() -> Variant:
	var c = detail_canvas(85, 69, 42, 61)
	box(c, 7, 39, 70, 17, 8, TIMBER, 4821)
	box(c, 11, 21, 29, 15, 20, BOX_BLUE, 4822)
	box(c, 43, 24, 30, 12, 18, BOX_ORANGE, 4823)
	box(c, 27, 6, 30, 16, 17, OLIVE, 4824)
	for x in [17, 32, 50, 66]:
		rect(c, x, 32, 2, 14, TYRES, 1)
	rect(c, 35, 16, 9, 6, WHITEWASH, 3)
	return finish_detail(c)

func water_pump() -> Variant:
	var c = detail_canvas(58, 72, 29, 64)
	box(c, 7, 56, 44, 9, 5, CONC, 4831)
	box(c, 20, 23, 14, 10, 33, BOX_BLUE, 4832)
	box(c, 17, 13, 20, 10, 11, STEELS, 4833)
	rect(c, 28, 5, 4, 12, STEELS, 3)
	line(c, Vector2(29, 6), Vector2(49, 20), STEELS[3])
	rect(c, 34, 29, 14, 5, STEELS, 2)
	rect(c, 44, 31, 4, 8, STEELS, 2)
	disc(c, 13, 55, 9, 4, TIN[2])
	rect(c, 5, 50, 16, 5, TIN, 3)
	stain(c, 20, 25, 15, 30, RUSTY, 4834, 0.15, 3)
	return finish_detail(c)

# ---- tools/PixelHarvestDamage.cs
# Harvesting leaves a recognisable object: axe cuts in a rigid trunk, planar fractures in rock and cut stems.
# Never remove random circles or flood-fill away diagonally connected foliage.

func save_harvest_variants(name, variant: int, full, radius: int, folder, into) -> void:
	for stage in range(1, 6):
		var key = name + ("_empty_" if stage == 5 else "_dmg" + str(stage) + "_") + str(variant)
		var c = harvest_stage(name, variant, full, stage)
		c.to_image().save_png(folder.path_join(key + ".png"))
		into[key] = [c.anchor.x, c.anchor.y, 0 if stage == 5 else radius]

func harvest_stage(name, variant: int, full, stage: int) -> Variant:
	var type: int = 0 if name.begins_with("node_wood") else 1 if name.begins_with("node_stone") else 2 if name.begins_with("node_herb") else 3 if name.begins_with("node_titanium") else Harvestables.type_of(name + "_" + str(variant))
	if stage == 5 and type != 2:
		var empty = Cs.init(Canvas.new(full.w, full.h), {"anchor": full.anchor})
		var remains = stump(1101 + variant) if type == 0 else rubble(1201 + variant)
		empty.paste(remains, full.anchor - remains.anchor)
		if name == "lm_log" or name == "lm_sticks":
			empty = Cs.init(Canvas.new(full.w, full.h), {"anchor": full.anchor})
			harvest_chips(empty, stage, WOOD_CHIPS, variant)
		return empty
	var c = full.clone()
	c.unoutline()
	if type == 0:
		trim_branches(c, name, stage)
		axe_cut(c, name, stage, variant)
	elif type == 1 or type == 3:
		rock_fracture(c, stage, variant, ORE_ROCK if type == 3 else LIME if name.begins_with("lm_") else STONE if name.begins_with("node_") else ROCK)
	else:
		cut_plants(c, name, stage, variant)
	harvest_chips(c, stage, WOOD_CHIPS if type == 0 else STONE if type == 1 else TI if type == 3 else HERB, variant)
	if full.ink.a > 0:
		c.outline(full.ink)
	return c

static func axe_cut(c, name, stage: int, variant: int) -> void:
	if name == "lm_log" or name == "lm_sticks":
		var b = harvest_bounds(c)
		var edge: int = b.end.x - int(b.size.x * stage * 0.16)
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				if c.solid(x, y):
					if x > edge:
						c.clear(x, y)
					elif x >= edge - 2:
						c.set_(x, y, CUT[(x + y) % CUT.size()])
		return
	var cy: int = c.anchor.y - (19 if name == "lm_mangrove" else 7)
	var left: int = -1
	var right: int = -1
	# Choose the trunk nearest the anchor, not a branch at the silhouette's edge.
	var d: int = 0
	while d < 18 and left < 0:
		for sign_ in [-1, 1]:
			var x: int = c.anchor.x + d * sign_
			if not _axe_cut_bark_at(x, cy, c):
				continue
			right = x
			left = right
			while _axe_cut_bark_at(left - 1, cy, c):
				left -= 1
			while _axe_cut_bark_at(right + 1, cy, c):
				right += 1
			break
		d += 1
	if left < 0:
		return
	var depth: int = maxi(1, int(ceilf((right - left + 1) * (0.12 + stage * 0.16))))
	var half_height: int = 2 + stage
	for dy in range(-half_height, half_height + 1):
		for dx in range(maxi(1, depth - absi(dy))):
			var x: int = left + dx
			var y: int = cy + dy
			if not _axe_cut_bark_at(x, y, c):
				continue
			# A triangular pale cut face, with a shaded inner lip and one intact strip of bark.
			c.set_(x, y, CUT[2] if dy < 0 else BARK[0].darkened(0.3) if dy == 0 else CUT[1])

# local function BarkAt of the method above
static func _axe_cut_bark_at(x: int, y: int, c) -> bool:
	if not c.body(x, y):
		return false
	var col: Color = c.at(x, y)
	return col.r > col.g * 1.1 and col.g > col.b * 1.08

static func harvest_bounds(c, leaves: bool = false) -> Rect2i:
	var x0: int = c.w
	var x1: int = -1
	var y0: int = c.h
	var y1: int = -1
	for y in range(c.h):
		for x in range(c.w):
			if c.solid(x, y) and (not leaves or is_leaf(c.at(x, y))):
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	return Rect2i() if x1 < x0 else Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

static func is_leaf(col: Color) -> bool:
	return col.g > col.r * 1.08 and col.g > col.b * 0.9

static func trim_branches(c, name, stage: int) -> void:
	if name == "lm_log" or name == "lm_sticks":
		return
	var b = harvest_bounds(c, true)
	if b.size == Vector2i.ZERO:
		return
	var pine_: bool = name == "pine" or name == "node_wood"
	var tiers: int = 0
	if pine_:
		for y in range(c.h):
			for x in range(c.w):
				if c.body(x, y) and is_leaf(c.at(x, y)):
					tiers = maxi(tiers, c.tag_at(x, y))
	var centre: float = c.anchor.x if pine_ else b.position.x + b.size.x * 0.5
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if not c.solid(x, y) or not is_leaf(c.at(x, y)):
				continue
			var half: float = 0.0
			if pine_:
				var tier: int = c.tag_at(x, y)
				var removed: float = clampf(tier - (tiers - stage * 0.4), 0, 1)
				if removed >= 0.999:
					c.clear(x, y)
					continue
				half = b.size.x * 0.5 * (0.34 + 0.66 * tier / maxi(1, tiers)) * (1 - removed)
			else:
				# A whole frond or leafy cluster breaks away, keeping the curved tips of the others.
				var tag: int = c.tag_at(x, y)
				var remove: bool = tag >= 100 and tag < 100 + stage if name == "lm_palm" else y > b.end.y - b.size.y * stage * 0.12 + absf(x - centre) * 0.12
				if remove:
					c.clear(x, y)
				continue
			if absf(x - centre) > maxf(1, half):
				c.clear(x, y)
	if name == "lm_mangrove":
		# Leaves used to cover this part of the fork: expose its wood as the crown is pruned.
		var top: int = int(b.end.y - b.size.y * stage * 0.12) - 2
		for y in range(top, c.anchor.y - 36):
			for dx in range(-1, 2):
				var x: int = int(centre) + dx
				if not c.solid(x, y):
					c.put(x, y, MANG_BARK[3 if dx < 0 else 1])
	if pine_:
		# Expose the trunk where lower boughs have been taken, rather than leaving a floating crown.
		var top: int = b.position.y + int(b.size.y * 0.25)
		for y in range(top, c.anchor.y):
			for dx in range(-1, 2):
				var x: int = c.anchor.x + dx
				if not c.solid(x, y):
					c.put(x, y, BARK[2 if dx < 0 else 0 if dx > 0 else 1])

static func rock_fracture(c, stage: int, variant: int, palette) -> void:
	var bounds = harvest_bounds(c)
	var x0: int = bounds.position.x
	var x1: int = bounds.end.x - 1
	var y0: int = bounds.position.y
	var y1: int = bounds.end.y - 1
	var width: float = x1 - x0
	var height: float = y1 - y0
	if width <= 0 or height <= 0:
		return
	var edge: float = x1 - width * stage * 0.12
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not c.solid(x, y):
				continue
			# Each unit removes a substantial angular slab: the base stays on the same ground anchor.
			var top: float = y0 + height * stage * 0.15 + (x - x0 - width * 0.4) * 0.16 + (x / 7 + variant) % 2
			var cut: float = edge + maxf(0, y - top) * 0.25
			if x > cut or y < top:
				c.clear(x, y)
			elif y < top + 3:
				c.set_(x, y, palette[-1 if y < top + 1 else -2])
			elif x > cut - 3:
				c.set_(x, y, palette[1])
	var root: Vector2 = Vector2(x0 + width * (0.35 + variant * 0.07), y0 + height * stage * 0.15)
	var prev: Vector2 = root
	for i in range(1, stage + 2):
		var next: Vector2 = root + Vector2((1 if i % 2 == 0 else -1) * (2 + stage), height * i * 0.14)
		rock_seam(c, prev, next, palette[0], palette[-1])
		if stage >= 2 and i == 2:
			rock_seam(c, next, next + Vector2(width * 0.24, height * 0.07), palette[0], palette[-2])
		prev = next

static func rock_seam(c, a: Vector2, b: Vector2, dark: Color, light: Color) -> void:
	var n: int = maxi(1, int(a.distance_to(b)))
	for i in range(n + 1):
		var p: Vector2i = Vector2i(a.lerp(b, float(i) / n).round())
		if c.body(p.x, p.y):
			c.set_(p.x, p.y, dark)
		if c.body(p.x - 1, p.y):
			c.set_(p.x - 1, p.y, light)

static func cut_plants(c, name, stage: int, variant: int) -> void:
	var container_: bool = name == "lm_bed" or name == "lm_pots"
	var b = harvest_bounds(c, true)
	if b.size == Vector2i.ZERO:
		return
	var root_x: float = c.anchor.x
	var root_y: float = b.end.y - 1
	var half_angle: float = PI * 0.5 * [1.0, 0.72, 0.52, 0.33, 0.14, 0.0][stage]
	for y in range(c.h):
		for x in range(c.w):
			if not c.solid(x, y):
				continue
			var col: Color = c.at(x, y)
			var vegetation: bool = is_leaf(col) or col.b > col.r * 1.12 or col.r > col.g * 1.25 and col.b > col.g * 1.12
			if container_ and not vegetation:
				continue
			var cut: bool = stage == 5
			if container_:
				cut = cut or x < b.position.x + b.size.x * stage / 5.0
			else:
				# Remove outer leaves in complete fans, including flowers and their stems.
				var angle: float = absf(atan2(x - root_x, maxf(1, root_y - y)))
				cut = cut or (angle > half_angle or y < b.position.y + b.size.y * stage * 0.045)
			if cut:
				c.clear(x, y)
				if container_ and name == "lm_bed" and y >= 16 and y <= 29:
					c.put(x, y, SOIL[1])
	if not container_:
		for i in range(mini(4, stage + 1)):
			var x: int = c.anchor.x - 4 + i * 2
			var y: int = mini(c.h - 3, int(root_y))
			c.put(x, y, HERB[0])
			c.put(x, y - 1, HERB[2])

static func harvest_chips(c, stage: int, palette, variant: int) -> void:
	for i in range(stage + 1):
		var x: int = c.anchor.x + (-1 if i % 2 == 0 else 1) * (5 + i * 2 + variant % 2)
		var y: int = mini(c.h - 2, c.anchor.y + i % 3)
		if c.solid(x, y):
			continue
		c.put(x, y, palette[mini(palette.size() - 1, 1 + i % 2)], 3)
		if stage >= 2 and not c.solid(x, y - 1):
			c.put(x, y - 1, palette[-1], 3)
		if stage >= 3 and not c.solid(x + 1, y):
			c.put(x + 1, y, palette[-1], 3)

# ---- tools/PixelLandmarkDetails.cs
# Owner: Vu Duc Viet Anh. Additional Atlas set dressing, generated with the same canvas, palette, pixel scale
# and anchors as PixelLandmarks.cs. Decorative machinery is abandoned, never an interactive crafting station.

func draw_landmark_details() -> void:
	lm("lm_radio", 0, field_radio(), 0)
	lm("lm_generator", 0, old_generator(), 12)
	lm("lm_coconuts", 0, coconut_pile(), 0)
	lm("lm_fossil", 0, fossil_slab(), 0)
	for i in range(3):
		lm("lm_flowers", i, wildflowers(i), 0)
	lm("lm_signpost", 0, trail_sign(), 4)
	lm("lm_scrap", 0, salvage_pile(), 0)
	lm("lm_cable", 0, cable_reel(), 9)
	lm("lm_barricade", 0, sandbags(), 0)
	lm("lm_radar", 0, radar_dish(), 12)
	lm("lm_solar", 0, solar_panel(), 12)
	lm("lm_windsock", 0, windsock(), 4)
	lm("lm_boat", 0, fishing_boat(), 0)
	lm("lm_buoys", 0, buoy_rack(), 7)
	lm("lm_rope", 0, rope_coil(), 0)
	lm("lm_cairn", 0, trail_cairn(), 7)
	lm("lm_scope", 0, telescope(), 6)
	lm("lm_crane", 0, yard_crane(), 0)
	lm("lm_lifering", 0, life_ring(), 0)
	lm("lm_anchor", 0, ship_anchor(), 0)
	lm("lm_fern", 0, fern_fan(), 0)
	lm("lm_expedition", 0, expedition_cache(), 0)
	lm("lm_arch", 0, garden_arch(), 0)
	lm("lm_rainbarrel", 0, rain_barrel(), 10)
	lm("lm_pots", 0, garden_pots(), 0)

static func detail_canvas(w: int, h: int, ax: int, ay: int) -> Variant:
	var c = Cs.init(Canvas.new(w, h), {"anchor": Vector2i(ax, ay)})
	c.shadow(ax + 4, ay + 1, minf(w * 0.4, 38), 3)
	return c

static func finish_detail(c) -> Variant:
	c.outline(Color("211F24"))
	return c

func field_radio() -> Variant:
	var c = detail_canvas(54, 51, 27, 45)
	box(c, 6, 32, 40, 6, 7, TIMBER, 3701)
	for x in range(10, 45, 30):
		box(c, x, 40, 3, 1, 5, TIMBER, 3702)
	box(c, 12, 20, 23, 4, 9, OLIVE, 3703)
	rect(c, 15, 25, 10, 5, GLASSY, 1)
	for x in range(16, 24, 3):
		c.put(x, 26, Color("8AAC8A"))
	disc(c, 30, 28, 2, 2, STEELS[3])
	line(c, Vector2(31, 20), Vector2(37, 4), STEELS[3])
	rect(c, 38, 31, 6, 3, WHITEWASH, 3)
	return finish_detail(c)

func old_generator() -> Variant:
	var c = detail_canvas(69, 46, 34, 40)
	box(c, 9, 11, 49, 14, 14, OLIVE, 3711)
	box(c, 14, 8, 20, 9, 3, OLIVE, 3712)
	for x in range(36, 54, 3):
		rect(c, x, 28, 1, 8, TYRES, 0)
	box(c, 47, 3, 4, 3, 10, STEELS, 3713)
	wheel(c, 18, 38, 5)
	wheel(c, 51, 38, 5)
	rect(c, 16, 26, 14, 6, TIN, 3)
	for x in range(17, 29):
		if x % 5 < 2:
			line(c, Vector2(x, 26), Vector2(x - 3, 31), TYRES[0])
	stain(c, 9, 20, 49, 17, RUSTY, 3714, 0.25, 6)
	return finish_detail(c)

func coconut_pile() -> Variant:
	var c = detail_canvas(39, 24, 19, 19)
	var r = CsRandom.new(3721)
	for _it1 in [[8, 16], [16, 12], [24, 17], [30, 11]]:
		var x = _it1[0]
		var y = _it1[1]
		ball(c, r, x, y, 4.5, COCO, x)
	disc(c, 13, 16, 4, 3, WHITEWASH[3])
	disc(c, 13, 16, 2, 1.5, COCO[0])
	return finish_detail(c)

func fossil_slab() -> Variant:
	var c = detail_canvas(94, 48, 47, 41)
	box(c, 7, 10, 78, 24, 6, LIME, 3731, 3, 1, 0.15)
	var centre = Vector2(46, 22)
	var prev: Vector2 = centre
	for i in range(150):
		var a: float = i * 0.12
		var r: float = 1 + i * 0.11
		var p: Vector2 = centre + Vector2(cos(a) * r, sin(a) * r * 0.55)
		line(c, prev, p, LIME[0])
		line(c, prev + Vector2.UP, p + Vector2.UP, LIME[4])
		prev = p
	return finish_detail(c)

func wildflowers(variant: int) -> Variant:
	var c = Cs.init(Canvas.new(54, 34), {"anchor": Vector2i(27, 27)})
	var r = CsRandom.new(3741 + variant)
	var petals = [PURPLE[2], Color("F4D581"), Color("ECADBE")]
	for i in range(16):
		var x: int = 4 + r.next(44)
		var y: int = 15 + r.next(14)
		var h: int = 3 + r.next(10)
		line(c, Vector2(x, y), Vector2(x - 1, y - h), BROADLEAF[2])
		c.put(x + 1, y - 3, BROADLEAF[3])
		disc(c, x - 1, y - h, 2.2, 1.5, petals[variant])
		c.put(x - 1, y - h, WHITEWASH[4])
	return c

func trail_sign() -> Variant:
	var c = detail_canvas(48, 61, 24, 55)
	box(c, 23, 12, 4, 2, 42, TIMBER, 3751)
	poly(c, [Vector2(5, 13), Vector2(34, 13), Vector2(43, 19), Vector2(34, 25), Vector2(5, 25)], func(x, y): return TIMBER[4 if y < 15 else 2])
	line(c, Vector2(11, 19), Vector2(31, 19), WHITEWASH[2])
	line(c, Vector2(27, 16), Vector2(32, 19), WHITEWASH[2])
	line(c, Vector2(27, 22), Vector2(32, 19), WHITEWASH[2])
	box(c, 11, 30, 26, 3, 9, OLIVE, 3752)
	return finish_detail(c)

func salvage_pile() -> Variant:
	var c = detail_canvas(70, 32, 35, 26)
	for i in range(6):
		var x: int = 7 + i * 9
		var y: int = 13 + i % 3 * 3
		box(c, x, y, 15, 5, 3, ALLOY if i % 2 == 0 else RUSTY, 3761 + i)
		line(c, Vector2(x + 1, y + 1), Vector2(x + 11, y + 4), STEELS[0])
	wheel(c, 14, 22, 6)
	return finish_detail(c)

func cable_reel() -> Variant:
	var c = detail_canvas(44, 39, 22, 33)
	disc(c, 22, 12, 17, 8, TIMBER[3])
	rect(c, 12, 14, 20, 15, TYRES, 1)
	for y in range(15, 29, 3):
		line(c, Vector2(12, y), Vector2(32, y), STEELS[1])
	disc(c, 22, 27, 18, 8, TIMBER[2])
	disc(c, 22, 26, 15, 6, TIMBER[3])
	disc(c, 22, 26, 4, 2, TIMBER[0])
	return finish_detail(c)

func sandbags() -> Variant:
	var c = detail_canvas(90, 32, 45, 27)
	for row in range(2):
		for i in range(4 - row):
			var x: int = 6 + i * 20 + row * 9
			var y: int = 20 - row * 10
			disc(c, x + 9, y, 11, 6, CANVAS_C[1])
			disc(c, x + 8, y - 2, 9, 4, CANVAS_C[3])
			line(c, Vector2(x + 4, y), Vector2(x + 13, y + 1), CANVAS_C[2])
	return finish_detail(c)

func radar_dish() -> Variant:
	var c = detail_canvas(100, 130, 50, 120)
	box(c, 28, 110, 45, 8, 5, CONC, 3781)
	for d in range(-1, 2, 2):
		line(c, Vector2(50, 59), Vector2(50 + d * 18, 113), STEELS[1])
		line(c, Vector2(50, 60), Vector2(51 + d * 18, 113), STEELS[3])
	for y in range(73, 110, 12):
		var w: float = (y - 59) * 0.32
		line(c, Vector2(50 - w, y), Vector2(50 + w + 4, y + 12), STEELS[2])
		line(c, Vector2(50 + w, y), Vector2(46 - w, y + 12), STEELS[2])
	disc(c, 46, 36, 36, 27, STEELS[0])
	disc(c, 44, 34, 33, 25, WHITEWASH[2])
	disc(c, 40, 31, 27, 20, WHITEWASH[3])
	for i in range(8):
		var edge: Vector2 = Vector2(44, 34) + Vector2.from_angle(i * TAU / 8) * Vector2(31, 23)
		line(c, Vector2(43, 35), edge, STEELS[2])
	line(c, Vector2(44, 35), Vector2(76, 13), STEELS[0])
	line(c, Vector2(43, 34), Vector2(75, 12), STEELS[4])
	box(c, 73, 9, 8, 4, 4, RUSTY, 3782)
	stain(c, 10, 12, 67, 50, RUSTY, 3783, 0.09, 2)
	return finish_detail(c)

func solar_panel() -> Variant:
	var c = detail_canvas(74, 57, 37, 51)
	box(c, 12, 34, 3, 2, 14, STEELS, 3791)
	box(c, 58, 34, 3, 2, 14, STEELS, 3792)
	box(c, 5, 10, 62, 25, 5, STEELS, 3793)
	rect(c, 8, 12, 56, 21, BOX_BLUE, 1)
	for x in range(8, 64, 9):
		rect(c, x, 12, 1, 21, STEELS, 3)
	for y in range(12, 33, 7):
		rect(c, 8, y, 56, 1, STEELS, 3)
	line(c, Vector2(47, 14), Vector2(35, 23), STEELS[4])
	line(c, Vector2(35, 23), Vector2(42, 30), TYRES[0])
	return finish_detail(c)

func windsock() -> Variant:
	var c = detail_canvas(72, 106, 22, 99)
	box(c, 20, 12, 3, 1, 86, STEELS, 3801)
	disc(c, 22, 99, 10, 3, CONC[2])
	poly(c, [Vector2(24, 13), Vector2(40, 15), Vector2(61, 30), Vector2(62, 35), Vector2(38, 25), Vector2(24, 27)], func(x, y): return TIN[4] if x / 8 % 2 == 0 else WHITEWASH[3])
	line(c, Vector2(23, 12), Vector2(23, 28), STEELS[4])
	return finish_detail(c)

func fishing_boat() -> Variant:
	var c = detail_canvas(124, 49, 62, 35)
	poly(c, [Vector2(5, 20), Vector2(31, 7), Vector2(100, 12), Vector2(118, 27), Vector2(98, 41), Vector2(29, 37)], func(x, y): return BOX_BLUE[3 if y < 23 else 1])
	poly(c, [Vector2(17, 21), Vector2(33, 13), Vector2(95, 17), Vector2(106, 27), Vector2(95, 33), Vector2(32, 30)], func(x, y): return TIMBER[1 + (1 if y % 5 == 0 else 0)])
	for x in range(40, 95, 22):
		box(c, x, 15, 6, 17, 2, TIMBER, 3811 + x)
	line(c, Vector2(30, 37), Vector2(97, 40), WHITEWASH[3])
	return finish_detail(c)

func buoy_rack() -> Variant:
	var c = detail_canvas(69, 64, 34, 57)
	for x in [9, 56]:
		box(c, x, 9, 4, 2, 46, TIMBER, 3821 + x)
	box(c, 6, 11, 57, 3, 4, TIMBER, 3822)
	for i in range(4):
		var x: int = 19 + i * 10
		var y: int = 28 + i % 2 * 7
		line(c, Vector2(x, 14), Vector2(x, y), TIMBER[3])
		disc(c, x, y + 4, 4, 7, TIN[4] if i % 2 == 0 else WHITEWASH[3])
		rect(c, x - 3, y + 3, 7, 3, BOX_RED, 3)
	return finish_detail(c)

func rope_coil() -> Variant:
	var c = Cs.init(Canvas.new(44, 23), {"anchor": Vector2i(22, 16)})
	for i in range(5, -1, -1):
		disc(c, 21, 12, 5 + i * 2.5, 2 + i, TIMBER[1])
		disc(c, 21, 11, 4 + i * 2.5, 1 + i, TIMBER[4])
	disc(c, 21, 11, 4, 1, TIMBER[0])
	line(c, Vector2(35, 13), Vector2(41, 19), TIMBER[3], 3)
	return c

func trail_cairn() -> Variant:
	var c = detail_canvas(45, 61, 22, 55)
	var r = CsRandom.new(3841)
	for i in range(4):
		boulder(c, r, 22 + i % 2 * 2, 55 - i * 10, 17 - i * 3, 8 - i, LIME, i == 0, i + 1)
	line(c, Vector2(25, 22), Vector2(25, 3), TIMBER[2])
	poly(c, [Vector2(26, 4), Vector2(40, 8), Vector2(26, 12)], func(x, y): return TIN[4])
	return finish_detail(c)

func telescope() -> Variant:
	var c = detail_canvas(54, 61, 26, 55)
	for x in range(12, 41, 14):
		line(c, Vector2(27, 30), Vector2(x, 55), STEELS[2])
	box(c, 23, 29, 7, 3, 12, STEELS, 3851)
	poly(c, [Vector2(9, 15), Vector2(14, 8), Vector2(44, 23), Vector2(39, 31)], func(x, y): return STEELS[4 if (x + y) % 6 == 0 else 2])
	line(c, Vector2(9, 15), Vector2(14, 8), GLASSY[0])
	return finish_detail(c)

func yard_crane() -> Variant:
	var c = detail_canvas(218, 196, 48, 184)
	box(c, 23, 164, 54, 14, 6, CONC, 3861)
	for x in [32, 61]:
		box(c, x, 40, 6, 3, 133, TIN, 3862 + x)
	for y in range(49, 165, 23):
		line(c, Vector2(38, y), Vector2(61, y + 22), TIN[3])
		line(c, Vector2(61, y), Vector2(38, y + 22), TIN[2])
	box(c, 22, 24, 174, 8, 10, TIN, 3863)
	for x in range(26, 191, 18):
		line(c, Vector2(x, 33), Vector2(x + 8, 40), TYRES[0])
	line(c, Vector2(44, 28), Vector2(52, 5), STEELS[2])
	line(c, Vector2(52, 5), Vector2(190, 25), STEELS[2])
	line(c, Vector2(177, 40), Vector2(177, 110), TYRES[0])
	line(c, Vector2(179, 40), Vector2(179, 110), STEELS[2])
	disc(c, 178, 111, 5, 7, TIN[3])
	line(c, Vector2(178, 117), Vector2(173, 125), STEELS[2])
	line(c, Vector2(173, 125), Vector2(181, 125), STEELS[3])
	box(c, 18, 124, 24, 9, 22, TIN, 3864)
	rect(c, 20, 134, 16, 9, GLASSY, 1)
	stain(c, 22, 24, 174, 20, RUSTY, 3865, 0.25, 8)
	return finish_detail(c)

func life_ring() -> Variant:
	var c = detail_canvas(34, 28, 17, 22)
	disc(c, 16, 13, 12, 8, TIN[4])
	disc(c, 16, 13, 6, 4, TIMBER[0])
	rect(c, 14, 6, 4, 3, WHITEWASH, 4)
	rect(c, 14, 18, 4, 3, WHITEWASH, 4)
	rect(c, 5, 12, 4, 3, WHITEWASH, 4)
	rect(c, 23, 12, 4, 3, WHITEWASH, 4)
	return finish_detail(c)

func ship_anchor() -> Variant:
	var c = detail_canvas(60, 49, 30, 39)
	for d in range(-2, 3):
		line(c, Vector2(30 + d, 10), Vector2(30 + d, 38), STEELS[2])
		line(c, Vector2(12, 30 + d), Vector2(30, 39 + d), STEELS[1])
		line(c, Vector2(48, 30 + d), Vector2(30, 39 + d), STEELS[1])
	disc(c, 30, 8, 6, 5, STEELS[2])
	disc(c, 30, 8, 3, 2, TYRES[0])
	line(c, Vector2(17, 19), Vector2(43, 19), STEELS[3])
	poly(c, [Vector2(9, 24), Vector2(12, 35), Vector2(20, 31)], func(x, y): return RUSTY[2])
	poly(c, [Vector2(51, 24), Vector2(48, 35), Vector2(40, 31)], func(x, y): return RUSTY[2])
	return finish_detail(c)

func fern_fan() -> Variant:
	var c = detail_canvas(57, 43, 28, 36)
	for i in range(7):
		var a: float = -PI + 0.2 + i * 0.46
		var dir: Vector2 = Vector2.from_angle(a)
		for k in range(1, 8):
			var p: Vector2 = Vector2(28, 36) + dir * k * 3
			var length: float = (8 - k) * 1.4
			line(c, p, p + dir.orthogonal() * length - dir * 2, BROADLEAF[2])
			line(c, p, p - dir.orthogonal() * length - dir * 2, BROADLEAF[3])
		line(c, Vector2(28, 36), Vector2(28, 36) + dir * 23, BROADLEAF[4])
	return c

func expedition_cache() -> Variant:
	var c = detail_canvas(73, 43, 36, 36)
	box(c, 6, 19, 30, 9, 9, OLIVE, 3891)
	for x in range(12, 33, 15):
		rect(c, x, 20, 3, 15, STEELS, 3)
	box(c, 43, 8, 16, 8, 22, TIMBER, 3892)
	rect(c, 45, 12, 12, 19, WHITEWASH, 2)
	line(c, Vector2(47, 15), Vector2(54, 23), TIN[4])
	line(c, Vector2(54, 15), Vector2(47, 23), TIN[4])
	line(c, Vector2(61, 33), Vector2(65, 9), TIMBER[3])
	line(c, Vector2(59, 10), Vector2(69, 12), STEELS[3])
	return finish_detail(c)

func garden_arch() -> Variant:
	var c = detail_canvas(121, 114, 60, 105)
	for x in [11, 102]:
		box(c, x, 24, 6, 3, 78, TIMBER, 3901 + x)
	poly(c, [Vector2(8, 26), Vector2(28, 8), Vector2(88, 8), Vector2(111, 26), Vector2(108, 35), Vector2(84, 19), Vector2(33, 19), Vector2(11, 35)], func(x, y): return TIMBER[3 if y % 4 == 0 else 2])
	for x in [16, 102]:
		for y in range(24, 99, 6):
			var dx: int = -3 if y / 6 % 2 == 0 else 2
			disc(c, x + dx, y, 5, 3, BROADLEAF[2])
			c.put(x + dx - 2, y - 1, BROADLEAF[4])
			if y % 18 == 0:
				disc(c, x + dx + 2, y - 2, 2, 2, PURPLE[3])
	vines(c, CsRandom.new(3902), 20, 98, 18, 24)
	return finish_detail(c)

func rain_barrel() -> Variant:
	var c = detail_canvas(45, 48, 22, 40)
	box(c, 8, 12, 28, 8, 22, TIMBER, 3911)
	ribs(c, 8, 20, 28, 22, TIMBER, 2, 5)
	for y in range(24, 37, 12):
		rect(c, 8, y, 28, 3, STEELS, 1)
	disc(c, 22, 14, 14, 7, TIMBER[4])
	disc(c, 22, 14, 11, 5, GLASSY[1])
	line(c, Vector2(15, 12), Vector2(25, 12), GLASSY[3])
	box(c, 32, 32, 7, 2, 3, STEELS, 3912)
	return finish_detail(c)

func garden_pots() -> Variant:
	var c = detail_canvas(61, 39, 30, 32)
	for i in range(3):
		var x: int = 12 + i * 17
		var y: int = 22 + i % 2 * 6
		box(c, x - 6, y - 5, 13, 5, 10, TIN, 3921 + i)
		disc(c, x, y - 4, 7, 3, SOIL[0])
		for k in range(-1, 2):
			leaf(c, Vector2(x, y - 4), Vector2(k * 0.7, -1).normalized(), 10, 2, BROADLEAF)
	return finish_detail(c)

# ---- tools/PixelLandmarkRebuild.cs
# Native pixel assets for credible abandoned infrastructure and eroded limestone, at the game's 32px tile scale.

func draw_rebuilt_landmarks() -> void:
	lm("lm_roof_fallen", 0, collapsed_roof(), 0)
	lm("lm_rubble", 0, collapse_debris(0), 0)
	lm("lm_rubble", 1, collapse_debris(1), 0)
	lm("lm_forklift", 0, yard_forklift(), 0)
	lm("lm_chainfence", 0, chain_fence(), 0)

func eroded_cave() -> Variant:
	var c = Cs.init(Canvas.new(328, 192), {"anchor": Vector2i(164, 172)})
	var r = CsRandom.new(5601)
	var rock = hex("454944", "62685D", "818575", "9C9F8C", "B7B7A1", "CDCAB2")
	c.shadow(171, 175, 151, 12)
	var outline = [Vector2(10, 169), Vector2(16, 135), Vector2(36, 111), Vector2(46, 85), Vector2(74, 75), Vector2(89, 48), Vector2(123, 37), Vector2(141, 22), Vector2(173, 29), Vector2(195, 17), Vector2(226, 33), Vector2(240, 54), Vector2(265, 63), Vector2(278, 89), Vector2(298, 105), Vector2(305, 139), Vector2(319, 168), Vector2(275, 177), Vector2(233, 172), Vector2(188, 178), Vector2(128, 174), Vector2(83, 180), Vector2(46, 173)]
	poly(c, outline, func(x, y):
		var light: float = 0.48 - x / 600.0 + (172 - y) / 340.0
		var n: float = value(x, y, 19, 5602)
		return pick(rock, int(2 + light * 2 + (1 if n > 0.7 else -1 if n < 0.25 else 0)))
	)
	# Large sloping planes and bedding, rather than evenly spaced vertical columns.
	poly(c, [Vector2(25, 137), Vector2(91, 67), Vector2(172, 35), Vector2(137, 89), Vector2(73, 131), Vector2(46, 169)], func(x, y): return rock[3])
	poly(c, [Vector2(172, 35), Vector2(195, 17), Vector2(226, 33), Vector2(231, 89), Vector2(201, 129), Vector2(175, 82)], func(x, y): return rock[4])
	poly(c, [Vector2(241, 68), Vector2(278, 89), Vector2(302, 132), Vector2(309, 166), Vector2(270, 172), Vector2(252, 124)], func(x, y): return rock[1])
	for band in range(7):
		var y: int = 60 + band * 16
		for x in range(18, 311):
			var py: int = y + int(6 * sin(x * 0.019 + band) + x * 0.045)
			if not c.body(x, py) or not c.body(x, py - 4):
				continue
			if (x / 13 + band * 3) % 9 != 0:
				c.set_(x, py, rock[1])
			if c.body(x, py - 1):
				c.set_(x, py - 1, rock[4])
	for _it1 in [[91, 53, -19, 59], [219, 42, 13, 67], [58, 102, -21, 53], [271, 91, 21, 60]]:
		var x = _it1[0]
		var y = _it1[1]
		var dx = _it1[2]
		var dy = _it1[3]
		var a: Vector2 = Vector2(x, y)
		var b: Vector2 = a + Vector2(dx, dy * 0.5)
		var d: Vector2 = a + Vector2(dx * 0.6, dy)
		line(c, a, b, rock[0])
		line(c, b, d, rock[0])
		line(c, a + Vector2.LEFT, b + Vector2.LEFT, rock[4])
	# Uneven weathered lip, then two recessed planes; the roof mass hangs over the opening.
	var rim = [Vector2(99, 171), Vector2(106, 140), Vector2(121, 111), Vector2(141, 100), Vector2(160, 102), Vector2(181, 94), Vector2(202, 108), Vector2(216, 135), Vector2(225, 173)]
	poly(c, rim, func(x, y): return rock[0])
	var mouth = [Vector2(108, 171), Vector2(116, 142), Vector2(128, 121), Vector2(143, 111), Vector2(161, 114), Vector2(180, 105), Vector2(195, 117), Vector2(207, 143), Vector2(214, 172)]
	poly(c, mouth, func(x, y): return Color("242B29" if x < 128 or x > 199 else "101815" if y < 149 else "18221C"))
	poly(c, [Vector2(110, 170), Vector2(142, 156), Vector2(181, 155), Vector2(214, 172)], func(x, y): return Color("30362B" if y < 162 else "555344"))
	line(c, Vector2(121, 171), Vector2(146, 160), Color("6D6D59"))
	for i in range(20):
		var x: int = 14 + r.next(298)
		var y: int = 162 + r.next(12)
		if x > 101 and x < 228:
			continue
		var size: int = 3 + r.next(7)
		poly(c, [Vector2(x, y), Vector2(x + size, y - size), Vector2(x + size * 2, y - 2), Vector2(x + size, y + 3)], func(px, py): return rock[4] if py < y - 2 else rock[2])
	# Thin damp seams and lichen follow cracks, leaving the pale rock readable.
	for i in range(34):
		var x: int = 30 + r.next(268)
		var y: int = 40 + r.next(105)
		if not c.body(x, y) or not c.body(x, y + 6) or x > 101 and x < 221 and y > 95:
			continue
		for k in range(3 + r.next(5)):
			if c.body(x + k / 3, y + k):
				c.set_(x + k / 3, y + k, MOSS[0])
	c.outline(Color("30362E"))
	return c

func broken_depot_wall(variant: int) -> Variant:
	var seed_: int = 5701 + variant
	var c = Cs.init(Canvas.new(154, 106), {"anchor": Vector2i(77, 96)})
	c.shadow(83, 97, 72, 5)
	var tops = Cs.arr(144, 0)
	for x in range(144):
		var top: int = (53 - x if x < 21 else 26 + (x - 110) if x > 110 else 25) if variant == 0 else 64 - x if x < 28 else 24 + (x - 101) / 2 if x > 101 else 22
		top += int(value(x, 0, 7, seed_) * 6)
		tops[x] = top
		for y in range(top, 97):
			var col: Color = CONC[4] if y < top + 7 else Color("606D60") if y > 76 else Color("A3A49A")
			if y > top + 7 and y < 77 and value(x, y, 13, seed_) < 0.28:
				col = CONC[2]
			if y == top + 7 or y > 91:
				col = CONC[1]
			c.put(x + 5, y, col)
	# Exposed brick infill where plaster has peeled; broken edges reveal the concrete aggregate.
	for y in range(45, 90):
		for x in range(7, 35):
			if y > tops[x - 5] + 8 and x < 24 + 8 * sin(y * 0.15):
				c.set_(x, y, CONC[1] if y % 7 == 0 or (x + y / 7 % 2 * 6) % 12 == 0 else Color("8A7560"))
	var wx: int = 46 if variant == 0 else 68
	rect(c, wx - 3, 43, 43, 37, CONC, 1)
	rect(c, wx, 46, 37, 29, hex("202B2C", "35433F", "596661"), 0)
	rect(c, wx - 3, 79, 43, 3, CONC, 4)
	line(c, Vector2(wx + 16, 45), Vector2(wx + 16, 75), STEELS[1])
	line(c, Vector2(wx, 59), Vector2(wx + 35, 59), STEELS[1])
	poly(c, [Vector2(wx + 1, 47), Vector2(wx + 12, 47), Vector2(wx + 1, 60)], func(x, y): return GLASSY[2])
	for x in [17, 103, 124, 131]:
		var y: int = tops[x - 5]
		line(c, Vector2(x, y + 2), Vector2(x + 2, y - 12), RUSTY[1])
		line(c, Vector2(x + 2, y - 12), Vector2(x + 9, y - 16), RUSTY[2])
	line(c, Vector2(112, 42), Vector2(105, 60), CONC[0])
	line(c, Vector2(105, 60), Vector2(114, 88), CONC[0])
	# Old service stripe and a weathered junction box.
	rect(c, 38, 85, 58, 2, CONC, 1)
	box(c, 127, 67, 12, 4, 16, STEELS, seed_, 2, 1, 0.025)
	line(c, Vector2(130, 86), Vector2(130, 94), TYRES[1])
	c.outline(Color("303632"))
	return c

func depot_return_wall() -> Variant:
	var c = Cs.init(Canvas.new(57, 155), {"anchor": Vector2i(29, 146)})
	poly(c, [Vector2(9, 29), Vector2(26, 8), Vector2(42, 19), Vector2(45, 126), Vector2(28, 147), Vector2(10, 134)], func(x, y): return CONC[2])
	poly(c, [Vector2(9, 29), Vector2(26, 8), Vector2(34, 14), Vector2(18, 34), Vector2(20, 128), Vector2(10, 134)], func(x, y): return CONC[4])
	poly(c, [Vector2(28, 147), Vector2(28, 104), Vector2(45, 86), Vector2(45, 126)], func(x, y): return CONC[1])
	for y in range(43, 126, 20):
		line(c, Vector2(22, y), Vector2(42, y - 18), CONC[1])
	line(c, Vector2(29, 39), Vector2(23, 65), CONC[0])
	line(c, Vector2(23, 65), Vector2(29, 82), CONC[0])
	line(c, Vector2(26, 15), Vector2(27, 2), RUSTY[2])
	c.outline(Color("303632"))
	return c

func freight_container(variant: int, stacked: bool) -> Variant:
	var c = Cs.init(Canvas.new(178, 136 if stacked else 80), {"anchor": Vector2i(89, 126 if stacked else 70)})
	c.shadow(95, c.anchor.y + 1, 81, 6)
	_freight_container_one(c.anchor.y, BOX_BLUE if variant == 0 else BOX_ORANGE, 5801, c)
	if stacked:
		_freight_container_one(c.anchor.y - 57, BOX_RED, 5802, c)
	c.outline(Color("20282B"))
	return c

# local function One of the method above
func _freight_container_one(ground_: int, paint, seed_: int, c) -> void:
	var top: int = ground_ - 57
	# Long freight-container proportions, a visible roof and a shaded short end.
	box(c, 6, top, 149, 14, 43, paint, seed_, 3, 2, 0.02)
	poly(c, [Vector2(155, top + 14), Vector2(169, top + 5), Vector2(169, ground_ - 9), Vector2(155, ground_)], func(x, y): return paint[1])
	poly(c, [Vector2(6, top), Vector2(20, top - 9), Vector2(169, top - 9), Vector2(155, top + 14)], func(x, y): return paint[3])
	for x in range(15, 149, 6):
		rect(c, x, top + 17, 2, 37, paint, 1)
		rect(c, x + 2, top + 17, 1, 36, paint, 3)
		line(c, Vector2(x, top + 10), Vector2(x + 11, top - 4), paint[2])
	rect(c, 7, ground_ - 4, 148, 4, paint, 0)
	rect(c, 7, top + 13, 148, 3, paint, 4)
	for x in [7, 149]:
		for y in [top + 13, ground_ - 6]:
			rect(c, x, y, 5, 5, STEELS, 2)
			c.put(x + 2, y + 2, TYRES[0])
	# Door locking rods on the short end, hinges, streaked rust at welds and base.
	for k in range(2):
		line(c, Vector2(158 + k * 6, top + 16 - k * 3), Vector2(158 + k * 6, ground_ - 5 - k * 3), STEELS[3])
	for i in range(29):
		var x: int = 10 + (i * 37 + seed_) % 140
		var h: int = 2 + i % 8
		for y in range(ground_ - h, ground_ - 2):
			c.set_(x, y, RUSTY[i % 3])
	rect(c, 26, top + 25, 23, 9, paint, 2)
	for i in range(6):
		rect(c, 28 + i * 3, top + 27, 2, 4, WHITEWASH, 2)
	rect(c, 117, top + 28, 11, 7, WHITEWASH, 2)
	rect(c, 120, top + 30, 5, 3, TYRES, 1)

func open_freight_container() -> Variant:
	var c = Cs.init(Canvas.new(112, 147), {"anchor": Vector2i(52, 133)})
	c.shadow(59, 132, 47, 8)
	# Roof runs away from the open end; dark interior has depth and a ribbed wooden floor.
	poly(c, [Vector2(15, 72), Vector2(34, 14), Vector2(91, 14), Vector2(78, 72)], func(x, y): return BOX_RED[3])
	for i in range(7):
		line(c, Vector2(22 + i * 8, 67), Vector2(38 + i * 8, 18), BOX_RED[2])
	rect(c, 14, 73, 66, 58, BOX_RED, 1)
	rect(c, 20, 78, 54, 49, TYRES, 0)
	poly(c, [Vector2(21, 126), Vector2(35, 105), Vector2(65, 105), Vector2(73, 126)], func(x, y): return DECK[1])
	for y in range(111, 127, 4):
		line(c, Vector2(29, y), Vector2(70, y), DECK[2])
	box(c, 35, 93, 16, 5, 17, OLIVE, 5820, 2, 1, 0.02)
	box(c, 55, 102, 12, 5, 10, TIMBER, 5821, 3, 2, 0.02)
	# Both open doors swing away from the central walkable opening.
	poly(c, [Vector2(14, 75), Vector2(2, 83), Vector2(2, 141), Vector2(14, 131)], func(x, y): return BOX_RED[2])
	poly(c, [Vector2(80, 75), Vector2(106, 85), Vector2(106, 141), Vector2(80, 131)], func(x, y): return BOX_RED[2])
	for x in range(85, 106, 5):
		line(c, Vector2(x, 85), Vector2(x, 132), BOX_RED[1])
	line(c, Vector2(96, 89), Vector2(96, 132), STEELS[3])
	rect(c, 13, 72, 67, 4, BOX_RED, 4)
	rect(c, 13, 129, 67, 4, STEELS, 1)
	c.outline(Color("20282B"))
	return c

func collapsed_roof() -> Variant:
	var c = Cs.init(Canvas.new(116, 64), {"anchor": Vector2i(58, 54)})
	c.shadow(61, 55, 52, 7)
	poly(c, [Vector2(7, 36), Vector2(37, 9), Vector2(99, 15), Vector2(110, 47), Vector2(67, 58), Vector2(43, 45)], func(x, y): return STEELS[2])
	for x in range(18, 101, 6):
		line(c, Vector2(x, 34), Vector2(x + 13, 18), STEELS[0])
	line(c, Vector2(10, 45), Vector2(102, 20), RUSTY[1])
	line(c, Vector2(18, 48), Vector2(97, 25), STEELS[3])
	line(c, Vector2(30, 14), Vector2(59, 50), RUSTY[2])
	box(c, 18, 44, 23, 6, 5, CONC, 5851, 3, 1, 0.05)
	c.outline(Color("303632"))
	return c

func collapse_debris(variant: int) -> Variant:
	var c = Cs.init(Canvas.new(83, 42), {"anchor": Vector2i(41, 33)})
	var r = CsRandom.new(5861 + variant)
	c.shadow(44, 34, 36, 5)
	for i in range(12):
		var x: int = 5 + r.next(63)
		var y: int = 15 + r.next(18)
		var size: int = 4 + r.next(8)
		poly(c, [Vector2(x, y), Vector2(x + size, y - size), Vector2(x + size + 5, y - 2), Vector2(x + 3, y + 4)], func(px, py): return pick(LIME, 3 if py < y - 2 else 1) if variant == 0 else pick(CONC, 4 if py < y - 2 else 2))
	if variant == 1:
		line(c, Vector2(20, 30), Vector2(48, 11), RUSTY[1])
		line(c, Vector2(48, 11), Vector2(69, 15), RUSTY[2])
	c.outline(Color("303632"))
	return c

func yard_forklift() -> Variant:
	var c = Cs.init(Canvas.new(94, 84), {"anchor": Vector2i(47, 74)})
	c.shadow(50, 75, 41, 5)
	var paint = hex("69502C", "93713C", "BD9652", "D8B56E", "E3C58B")
	wheel(c, 21, 69, 9)
	wheel(c, 62, 69, 9)
	box(c, 14, 45, 49, 9, 15, paint, 5870, 3, 2, 0.03)
	box(c, 14, 37, 19, 8, 9, paint, 5871, 3, 2, 0.02)
	rect(c, 37, 37, 14, 13, TYRES, 1)
	rect(c, 34, 46, 19, 4, TYRES, 2)
	for x in [32, 59]:
		rect(c, x, 12, 3, 39, STEELS, 1)
	box(c, 28, 9, 38, 7, 3, STEELS, 5872, 2, 1, 0.02)
	for x in [69, 76]:
		rect(c, x, 19, 4, 53, STEELS, 1)
	rect(c, 67, 40, 16, 4, STEELS, 3)
	for i in range(2):
		line(c, Vector2(76, 66 + i * 7), Vector2(91, 64 + i * 7), STEELS[3])
	line(c, Vector2(56, 31), Vector2(49, 44), STEELS[2])
	rect(c, 16, 54, 8, 4, WHITEWASH, 2)
	c.outline(Color("242A29"))
	return c

func chain_fence() -> Variant:
	var c = Cs.init(Canvas.new(158, 62), {"anchor": Vector2i(79, 55)})
	var wire: Color = Color("6C7976", 0.72)
	for y in range(10, 52):
		for x in range(5, 153):
			if (x + y) % 10 == 0 or (x - y + 200) % 10 == 0:
				c.put(x, y, wire, 3)
	for x in [5, 78, 151]:
		rect(c, x, 5, 3, 51, STEELS, 2)
		c.put(x, 5, STEELS[4])
	line(c, Vector2(5, 10), Vector2(153, 10), STEELS[2])
	line(c, Vector2(5, 51), Vector2(153, 51), STEELS[1])
	return c

# ---- tools/PixelLandmarks.cs
# Owner: Vu Duc Viet Anh. Pixel art for the 18 landmarks of the island, after the concept art of the Landmark Atlas
# (art/landmarks/ref/, from .tmp/Hold_til_Dawn_Landmark_Atlas.pdf): coconut palms and fallen trunks (02),
# limestone shelves (03), broad-leaf herbs (04), the military utility vehicle wreck (05), the ruined depot's broken
# walls, shelves, crates and radio mast (06), the convoy trucks (07), mangroves on stilt roots (08), the weather
# station (09), the old pier and fish traps (10), the coral lookout shelter (12), shipping containers, drums and
# pallets (13), the beached cargo ship and machinery washed up (14), red ginger by the pond (15), the limestone
# bluff with the cave mouth (16), the concrete lookout platform (17) and the herb garden's raised beds, broken
# fence and watering can (18). Same rules as the rest of tools/PixelNature.cs (this is part of that tool):
# 1 px = 1 game px, light from the upper left, a dark outline, a soft shadow to the lower right.
# Writes art/landmarks/<name>_<variant>.png and art/landmarks/index.json ({name: [anchor_x, anchor_y, solid_radius_px]}).
# Placed on the island by src/world/world_landmarks.gd.
static var LIME = hex("5E5B4F", "817D6D", "A5A08C", "C6C1AA", "E2DDC8")
static var PALM_BARK = hex("4A3A28", "6A5338", "8C7150", "AD9268")
static var PALM_LEAF = hex("1E4526", "2C6230", "3F823A", "62A348", "8FC45A")
static var COCO = hex("3E2E16", "5E4822", "7E6630")
static var OLIVE = hex("272C1C", "3A4128", "4F5835", "687246", "848E5A")
static var RUSTY = hex("41200F", "673318", "8E4C22", "B06A30")
static var TYRES = hex("141519", "23252B", "363940")
static var GLASSY = hex("142027", "21363F", "355561", "6E98A2")
static var ALLOY = hex("5B6B7C", "8FA3B8", "B4C4D4", "DCE6F0")
static var CANVAS_C = hex("353B28", "4A5236", "626C46", "7C8758", "98A26C")
static var CONC = hex("4B4D4F", "67696B", "838684", "A0A29D", "BDBEB7")
static var TIN = hex("4E2E20", "77462A", "9A6038", "BB7E4E", "D29C6A")
static var TIMBER = hex("3B3026", "574735", "766148", "957C5C", "B09775")
static var PLASTER = hex("6F6A5E", "928C7C", "B2AC98", "CDC7B2", "E4DFCC")
static var STEELS = hex("3A424C", "56606C", "77828E", "9AA5AF", "C2CBD2")
static var BOX_BLUE = hex("172A40", "223D5C", "305478", "446F96", "5E8AB2")
static var BOX_ORANGE = hex("4E2412", "79381A", "A34E25", "C66A35", "DE8A50")
static var BOX_RED = hex("3E1814", "5E241C", "823427", "A04633", "B85E47")
static var HULL = hex("15191D", "23292F", "353E46", "4C5760", "66737D")
static var HULL_RED = hex("3A1512", "5A2119", "7C3022", "99412D")
static var DECK = hex("3A2C22", "54402E", "6E553C", "8A6D4C")
static var WHITEWASH = hex("7C7A72", "A09E95", "C2C0B6", "DDDBD1", "F0EEE5")
static var VINES = hex("1C3F22", "2A5A2C", "3C7838", "58974A")
static var MANG_BARK = hex("33291F", "4B3D2D", "66533D", "826B4F", "9C8566")
static var MANG_LEAF = hex("1A3A24", "27512E", "386B39", "4F8746", "6CA257")
static var BROADLEAF = hex("1D4A28", "2D6A34", "438A40", "64A94E", "8CC664")
static var PURPLE = hex("3E2668", "5E3E98", "8462C4", "AE90E6")
static var GINGER = hex("6A1420", "9A2230", "C83A40", "E8665C")
static var SOIL = hex("2A2018", "3C2E22", "52402E")
const CAVE_DARK: Color = Color("0E0C12")
var lm_index = {}
var lm_out = "res://art/landmarks"

func draw_landmarks() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--landmarks-out="):
			lm_out = arg.substr(16)
	DirAccess.make_dir_recursive_absolute(lm_out)
	# 02 Coconut Grove
	for i in range(4):
		lm("lm_palm", i, palm(2001 + i, 66 + i % 3 * 8, 1 if i % 2 == 0 else -1), 6)
	lm("lm_log", 0, fallen_trunk(2101), 0)
	lm("lm_sticks", 0, sticks(2111), 0)
	# 03 Limestone Flats
	for i in range(3):
		lm("lm_shelf", i, lime_shelf(2201 + i, i), 18 + 3 * i)
	# 04 Herb Meadow, 15, 18
	for i in range(2):
		lm("lm_broadleaf", i, broad_leaf(2301 + i, i == 0), 0)
	lm("lm_ginger", 0, ginger(2311), 0)
	# 05 Bayside Wreck
	lm("lm_jeep", 0, jeep(2401), 0)
	# 06 Ruined Base
	lm("lm_ruin_h", 0, broken_depot_wall(0), 0)
	lm("lm_ruin_h", 1, broken_depot_wall(1), 0)
	lm("lm_ruin_v", 0, depot_return_wall(), 0)
	lm("lm_rack", 0, rack(2521), 0)
	lm("lm_crate", 0, crate(2531), 8)
	lm("lm_mast", 0, mast(2541), 6)
	# 07 Stranded Convoy
	lm("lm_truck", 0, truck(2601, false), 0)
	lm("lm_truck", 1, truck(2602, true), 0)
	# 08 Mangrove Swamp
	for i in range(3):
		lm("lm_mangrove", i, mangrove(2701 + i, i), 7)
	# 09 Weather Station
	lm("lm_station", 0, station(2801), 0)
	# 10 Old Fishing Pier (flat, on the ground layer, walked on)
	lm("lm_pier", 0, pier(2901), 0)
	lm("lm_trap", 0, trap(2911, false), 0)
	lm("lm_trap", 1, trap(2912, true), 0)
	# 12 Coral Lookout
	lm("lm_lookout", 0, lookout(3001), 0)
	# 13 Container Yard
	lm("lm_container", 0, freight_container(0, false), 0)
	lm("lm_container", 1, freight_container(1, true), 0)
	lm("lm_container_end", 0, open_freight_container(), 0)
	lm("lm_drum", 0, drum(3121, BOX_BLUE), 6)
	lm("lm_drum", 1, drum(3122, RUSTY), 6)
	lm("lm_pallet", 0, pallet(3131), 0)
	# 14 Beached Shipwreck
	lm("lm_ship", 0, ship(3201), 0)
	lm("lm_gear", 0, gear(3211), 8)
	# 16 Southwest Cave
	lm("lm_bluff", 0, eroded_cave(), 0)
	# 17 South Cape Lookout (flat, on the ground layer)
	lm("lm_platform", 0, platform(3401), 0)
	# 18 Abandoned Herb Garden
	lm("lm_bed", 0, bed(3501, 0), 0)
	lm("lm_bed", 1, bed(3502, 1), 0)
	lm("lm_fence", 0, fence(3511), 0)
	lm("lm_can", 0, can(3521), 0)
	draw_landmark_details()
	draw_expedition_props()
	draw_rebuilt_landmarks()
	var fa = FileAccess.open(lm_out.path_join("index.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(lm_index, "\t"))

func lm(name, variant: int, c, radius: int) -> void:
	var n = name + "_" + str(variant)
	c.to_image().save_png(lm_out.path_join(n + ".png"))
	lm_index[n] = [c.anchor.x, c.anchor.y, radius]
	if Harvestables.type_of(n) >= 0:
		save_harvest_variants(name, variant, c, radius, lm_out, lm_index)
	print("drew ", n, " (", c.w, ", ", c.h, ")")

# --- building blocks ----------------------------------------------------------
static func pick(pal, b: int) -> Color:
	return pal[clampi(b, 0, pal.size() - 1)]

# a rectangle in one band, with grain: a pixel one band lighter or darker now and then
static func rect(c, x0: int, y0: int, w: int, h: int, pal, b: int, seed_: int = 0, grain: float = 0, k: int = 2) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var bb: int = b
			if grain > 0:
				var g: float = hash_(x, y, seed_)
				if g < grain * 0.5:
					bb -= 1
				elif g > 1 - grain * 0.5:
					bb += 1
			c.put(x, y, pick(pal, bb), k)

# A box seen from the 3/4 camera: a lit top face D rows deep over a front face H rows tall. The edge between
# them catches the light; the right end and the foot are in shade.
static func box(c, x: int, y: int, w: int, d: int, h: int, pal, seed_: int, top_b: int = 3, front_b: int = 2, grain: float = 0.14) -> void:
	rect(c, x, y, w, d, pal, top_b, seed_, grain)
	rect(c, x, y + d, w, h, pal, front_b, seed_ + 7, grain)
	for xx in range(x, x + w):
		c.put(xx, y, pick(pal, top_b + 1))
		if h > 0:
			c.put(xx, y + d, pick(pal, front_b + 1))
		if h > 1:
			c.put(xx, y + d + h - 1, pick(pal, front_b - 1))
	for yy in range(y, y + d + h):
		c.put(x + w - 1, yy, pick(pal, (top_b if yy < y + d else front_b) - 1))
	for yy in range(y, y + d):
		c.put(x, yy, pick(pal, top_b + 1))

# vertical ribs (corrugated steel, planks): a dark line and a lit line every Every px
static func ribs(c, x0: int, y0: int, w: int, h: int, pal, b: int, every: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if not c.body(x, y):
				continue
			var m: int = (x - x0) % every
			if m == 0:
				c.set_(x, y, pick(pal, b - 1))
			elif m == 1:
				c.set_(x, y, pick(pal, b + 1))

# rust and grime: patches of another palette where a smooth noise is high, and drips running down
static func stain(c, x0: int, y0: int, w: int, h: int, pal, seed_: int, amount: float, drips: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if c.body(x, y) and value(x, y, 6, seed_) + hash_(x, y, seed_) * 0.06 > 1 - amount * 0.55:
				c.set_(x, y, pick(pal, 1 + int(hash_(x, y, seed_ + 1) * 2)))
	var r = CsRandom.new(seed_)
	for i in range(drips / 2):
		var x: int = x0 + r.next(maxi(1, w))
		var y: int = y0 + r.next(maxi(1, h / 2))
		var len_: int = 3 + r.next(maxi(2, h / 2))
		for s in range(len_):
			if c.body(x, y + s):
				c.set_(x, y + s, pick(pal, 2 if s < 2 else 1))

# vines hanging from the top edge of what is drawn in X0..X1, with leaves
static func vines(c, r, x0: int, x1: int, count: int, max_len: int) -> void:
	for i in range(count):
		var x: int = x0 + r.next(maxi(1, x1 - x0))
		var y: int = 0
		while y < c.h and not c.body(x, y):
			y += 1
		if y >= c.h:
			continue
		var len_: int = 4 + r.next(maxi(2, max_len))
		for s in range(len_):
			if not c.solid(x, y):
				break
			c.put(x, y, pick(VINES, 1 + (1 if s % 3 == 0 else 0)), 3)
			if r.next(3) == 0:
				var lx: int = x + (-1 if r.next(2) == 0 else 1)
				if c.solid(lx, y):
					c.put(lx, y, pick(VINES, 2 + r.next(2)), 3)
			y += 1
			if r.next(4) == 0:
				x += r.next(3) - 1

static func wheel(c, cx: float, cy: float, rad: float) -> void:
	disc(c, cx, cy, rad, rad, TYRES[0])
	disc(c, cx - 0.5, cy - 0.5, rad - 1.2, rad - 1.2, TYRES[1])
	disc(c, cx, cy, rad * 0.45, rad * 0.45, OLIVE[2])
	c.put(int(cx - 1), int(cy - 1), OLIVE[3])
	for i in range(3):
		c.put(int(cx - rad + 1 + i), int(cy - rad * 0.5 + i), TYRES[2])

static func line(c, a: Vector2, b: Vector2, col: Color, k: int = 2) -> void:
	var n: int = int(maxf(1, ceilf(a.distance_to(b))))
	for i in range(n + 1):
		var p = a.lerp(b, float(i) / n)
		c.put(int(floorf(p.x)), int(floorf(p.y)), col, k)

static func poly(c, pts, paint, k: int = 2) -> void:
	var y0: float = 3.4028235e38
	var y1: float = -3.4028235e38
	var x0: float = 3.4028235e38
	var x1: float = -3.4028235e38
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
	for y in range(int(y0), int(y1) + 1):
		for x in range(int(x0), int(x1) + 1):
			if inside(pts, Vector2(x + 0.5, y + 0.5)):
				c.put(x, y, paint.call(x, y), k)

# the drawing turned by Deg round (Px, Py), nearest pixel (before outlining)
static func turned(src, deg: float, px: float, py: float) -> Variant:
	var c = Cs.init(Canvas.new(src.w, src.h), {"anchor": src.anchor})
	var a: float = deg_to_rad(-deg)
	var co: float = cos(a)
	var si: float = sin(a)
	for y in range(c.h):
		for x in range(c.w):
			var dx: float = x + 0.5 - px
			var dy: float = y + 0.5 - py
			var sx: int = int(floorf(px + dx * co - dy * si))
			var sy: int = int(floorf(py + dx * si + dy * co))
			if not src.in_(sx, sy) or not src.solid(sx, sy):
				continue
			c.put(x, y, src.at(sx, sy), 2 if src.body(sx, sy) else 3)
	return c

# --- 02 Coconut Grove ---------------------------------------------------------
# A coconut palm: a ringed trunk curving up, a crown of drooping feathered fronds and a bunch of coconuts.
func palm(seed_: int, h: int, lean: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(76, h + 22)
	var gx: int = 38
	var gy: int = c.h - 4
	c.anchor = Vector2i(gx, gy)
	c.shadow(gx + 10, gy, 22, 4)
	var top = Vector2(gx + lean * (7 + r.next(5)), gy - h + 12)
	var mid = Vector2(gx + lean * 1, gy - h * 0.5)
	# the trunk: a quadratic curve, 4 px wide at the foot, 3 at the crown, rings every 3 px
	var prev: Vector2 = Vector2(gx, gy)
	for s in range(81):
		var t: float = s / 80.0
		var p = Vector2(gx, gy).lerp(mid, t).lerp(mid.lerp(top, t), t)
		var hw: float = lerpf(2.6, 1.6, t)
		for dx in range(-3, 4):
			if absi(dx) > hw:
				continue
			var x: int = int(Cs.round_even(p.x + dx))
			var y: int = int(Cs.round_even(p.y))
			var ring: bool = (gy - y) % 3 == 0
			var b: int = 3 if dx < -0.5 else 1 if dx > 0.8 else 2
			if ring:
				b -= 1
			c.put(x, y, pick(PALM_BARK, b))
		prev = p
	# coconuts under the crown
	for i in range(4):
		ball(c, r, top.x - 3 + i * 2 + i % 2, top.y + 4 + i % 2 * 2, 2.2, COCO, 50 + i)
	# fronds: a midrib arcing out and down, leaflets either side shortening to the tip
	var n: int = 9
	var order = []
	for i in range(n):
		order.append(-PI + i * TAU / n + float(r.next_double() - 0.5) * 0.3)
	# the fronds at the back first
	Cs.sort_cmp(order, func(a, b): return Cs.compare(sin(a), sin(b)))
	var cut_order = Array(order).duplicate()
	Cs.sort_cmp(cut_order, func(a, b): return Cs.compare(absf(cos(b)), absf(cos(a))))
	for a in order:
		var frond_tag: int = 100 + cut_order.find(a)
		var dir = Vector2(cos(a), sin(a) * 0.45)
		var len_: float = 27 + float(r.next_double()) * 6
		var back: bool = sin(a) < -0.2
		var steps: int = int(len_)
		for s in range(1, steps + 1):
			var t: float = float(s) / steps
			var p = top + dir * len_ * t + Vector2(0, t * t * 20 - t * 5)
			var along = (dir * len_ + Vector2(0, 2 * t * 20 - 5)).normalized()
			var perp = Vector2(-along.y, along.x)
			var base: int = 1 if back else 2
			c.put(int(p.x), int(p.y), pick(PALM_LEAF, base - 1), 2, frond_tag)
			var lf: float = (1 - t * 0.8) * 7.0
			for side in range(-1, 2, 2):
				var dir2 = (perp * side + along * 0.9 + Vector2(0, 0.7)).normalized()
				for k in range(1, int(lf) + 1):
					var q = p + dir2 * k
					var lit: bool = (perp * side).dot(LIGHT2) > 0
					c.put(int(q.x), int(q.y), pick(PALM_LEAF, base + (1 if lit else 0) + (1 if k == 1 and not back else 0)), 2, frond_tag)
	# a few dry brown fronds hanging under the crown
	for i in range(2):
		var x: float = top.x + (-4 if i == 0 else 4)
		for s in range(10):
			c.put(int(x + (-s * 0.4 if i == 0 else s * 0.4)), int(top.y + 3 + s), pick(DRY, 1 + s % 2))
	c.outline(Color("10261A"))
	return c

# a fallen palm trunk with its sawn pale end and a dead frond, lying across the sand
func fallen_trunk(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(84, 28)
	c.anchor = Vector2i(42, 22)
	c.shadow(46, 22, 38, 4)
	var a = Vector2(10, 18)
	var b = Vector2(72, 12)
	for y in range(c.h):
		for x in range(c.w):
			var p = Vector2(x + 0.5, y + 0.5)
			var ab = b - a
			var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0, 1)
			var q = a + ab * t
			var rr: float = lerpf(5.2, 4.0, t)
			var d: float = (p - q).y / rr
			if p.distance_to(q) > rr:
				continue
			var bb: int = 3 if d < -0.45 else 2 if d < 0.3 else 1
			if int(t * 62) % 4 == 0:
				bb -= 1
			c.put(x, y, pick(PALM_BARK, bb))
	# the sawn end: a pale disc with rings
	disc(c, 10, 18, 3, 5, CUT[1])
	disc(c, 9.6, 17.6, 2, 3.4, CUT[2])
	c.put(9, 18, CUT[0])
	# a dead frond off the far end
	for s in range(16):
		var x: int = 72 + s / 2
		var y: int = 11 - s / 3
		c.put(x, y, pick(DRY, 1))
		if s % 2 == 0:
			c.put(x + 1, y + 2, pick(DRY, 2))
			c.put(x - 1, y - 2, pick(DRY, 0))
	c.outline(PALM_BARK[0].darkened(0.6))
	return c

func sticks(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(36, 18)
	c.anchor = Vector2i(18, 12)
	for i in range(4):
		var a = Vector2(4 + r.next(8), 6 + r.next(8))
		var b = Vector2(24 + r.next(9), 4 + r.next(10))
		line(c, a, b, pick(WOOD_CHIPS, 1))
		line(c, a + Vector2(0, -1), b + Vector2(0, -1), pick(WOOD_CHIPS, 2))
		line(c, a + Vector2(0, 1), b + Vector2(0, 1), pick(WOOD_CHIPS, 0))
	c.outline(Color("2A1C12"))
	return c

# --- 03 Limestone Flats -------------------------------------------------------
# Low limestone shelves breaking through the grass: two or three flat, pitted layers stepping up, each with a
# pale top and a banded front face, the edges broken.
func lime_shelf(seed_: int, shape: int) -> Variant:
	var r = CsRandom.new(seed_)
	var w: int = 92 + shape * 16
	var c = Canvas.new(w + 12, 50)
	c.anchor = Vector2i(c.w / 2, 44)
	c.shadow(c.w / 2 + 6, 44, w * 0.5, 6)
	var layers: int = 2 + (1 if shape == 2 else 0)
	for l in range(layers):
		var lw: int = int(w * (1 - l * 0.28)) - r.next(6)
		var x0: int = 4 + (w - lw) / 2 + r.next(9) - 4 - l * 3
		var base: int = 44 - l * 9
		var depth: int = 13 - l * 2
		var h: int = 8
		for x in range(x0, x0 + lw):
			var u: float = float(x - x0) / lw
			# broken, rounded ends and a ragged top edge
			var end: float = minf(u, 1 - u) * lw
			var cut: int = int(4 - end) if end < 4 else 0
			var rag: int = int(value(x, l, 3, seed_) * 3)
			var ytop: int = base - h - depth + cut + rag
			var yfront: int = base - h + (cut - 2 if cut > 2 else 0)
			for y in range(ytop, base):
				if y < yfront:
					# the top: pale with pits and a lit back rim
					var b: int = 4 if y == ytop else 3
					if hash_(x, y, seed_) > 0.9:
						b = 2
					c.put(x, y, pick(LIME, b), 2, l + 1)
				else:
					# the front: bands of the layers in the rock, darker to the foot
					var b: int = 1 if (y - yfront) % 3 == 2 else 2
					if y >= base - 1:
						b = 1
					if x >= x0 + lw - 2:
						b -= 1
					c.put(x, y, pick(LIME, b), 2, l + 1)
	# a crack or two, and lichen
	for i in range(3):
		var x: int = 10 + r.next(w - 10)
		var y: int = 20
		while y < 44 and not c.body(x, y):
			y += 1
		var s: int = 0
		while s < 6 and c.body(x, y):
			c.set_(x, y, LIME[1])
			y += 1
			x += r.next(3) - 1
			s += 1
	for i in range(14):
		var x: int = 6 + r.next(w)
		var y: int = 20 + r.next(22)
		if c.body(x, y):
			c.set_(x, y, pick(MOSS, 1 + r.next(2)))
	c.outline(LIME[0].darkened(0.55))
	return c

# --- 04 Herb Meadow -------------------------------------------------------------
# a broad-leaf plant, some with spikes of purple flowers
func broad_leaf(seed_: int, flowers: bool) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(38, 40)
	var cx: float = 19
	var gy: float = 36
	c.anchor = Vector2i(19, 35)
	c.shadow(cx + 3, gy, 13, 3)
	if flowers:
		for i in range(3):
			var x: int = 12 + i * 6 + r.next(2)
			var h: int = 13 + r.next(8)
			for s in range(h):
				var y: int = int(gy) - 6 - s
				c.put(x, y, BROADLEAF[1])
				if s > h / 3:
					c.put(x - 1, y, pick(PURPLE, 3 if s % 2 == 0 else 2))
					c.put(x + 1, y, pick(PURPLE, 1))
					c.put(x, y, pick(PURPLE, 3 if s % 3 == 0 else 2))
	var leaves = []
	for i in range(9):
		leaves.append(-PI * 0.98 + i * PI * 0.96 / 8 + float(r.next_double() - 0.5) * 0.2)
	Cs.sort_cmp(leaves, func(a, b): return Cs.compare(absf(sin(b)), absf(sin(a))))
	for a in leaves:
		var dir = Vector2(cos(a), sin(a) * 0.8)
		leaf(c, Vector2(cx, gy - 3), dir, 10 + absf(sin(a)) * 5 + float(r.next_double()) * 2, 3.6, BROADLEAF)
	c.outline(Color("0F2A16"))
	return c

# red ginger by the pond and the cave: tall leaves and red flower cones
func ginger(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(30, 40)
	c.anchor = Vector2i(15, 36)
	c.shadow(18, 36, 10, 2.5)
	for i in range(6):
		var a: float = -PI / 2 + (i - 2.5) * 0.32
		leaf(c, Vector2(15, 34), Vector2(cos(a), sin(a)), 16 + r.next(6), 2.6, BROADLEAF)
	for i in range(2):
		var x: int = 11 + i * 8
		var y: int = 10 + r.next(5)
		for s in range(7):
			for dx in range(-1, 2):
				if absi(dx) <= 1 - s / 7.0 + 0.5:
					c.put(x + dx, y + s, pick(GINGER, 3 if dx < 0 else 2 if s % 2 == 0 else 1))
	c.outline(Color("0F2A16"))
	return c

# --- 05 Bayside Wreck -----------------------------------------------------------
# A military utility vehicle slid off the road, nose down: olive paint gone to rust, the windows broken, the
# door panel stripped to bare alloy (where the titanium comes from), the spare wheel on the back.
func jeep(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var raw = Canvas.new(96, 66)
	# body: the low hull, the bonnet, the cab
	box(raw, 10, 28, 74, 6, 16, OLIVE, seed_, 3, 2)
	box(raw, 34, 12, 40, 5, 16, OLIVE, seed_ + 1, 3, 2)
	# windscreen and side windows, broken
	rect(raw, 37, 19, 15, 8, GLASSY, 1, seed_ + 2, 0.2)
	rect(raw, 55, 19, 15, 8, GLASSY, 1, seed_ + 3, 0.2)
	for i in range(6):
		raw.put(39 + i, 25 - i, GLASSY[3])
		raw.put(58 + i, 24 - i, GLASSY[2])
	raw.put(48, 20, CAVE_DARK)
	raw.put(49, 21, CAVE_DARK)
	raw.put(47, 22, CAVE_DARK)
	# the stripped door: bare alloy with rivets
	rect(raw, 54, 35, 14, 9, ALLOY, 2, seed_ + 4, 0.25)
	for x in range(55, 68, 3):
		raw.put(x, 36, ALLOY[0])
		raw.put(x, 42, ALLOY[0])
	for x in range(54, 68):
		raw.put(x, 35, ALLOY[3])
	# grille and headlight on the nose
	for y in range(35, 43):
		for x in range(11, 17, 2):
			raw.put(x, y, OLIVE[0])
	disc(raw, 20, 37, 2, 2, Color("D8D2A6"))
	raw.put(19, 36, Color("F4EFCB"))
	# the spare wheel on the tail
	wheel(raw, 86, 36, 6)
	stain(raw, 10, 12, 76, 34, RUSTY, seed_ + 5, 0.32, 10)
	wheel(raw, 24, 47, 8)
	wheel(raw, 70, 47, 8)
	# a broken tow hitch, a dent
	raw.put(8, 42, STEELS[1])
	raw.put(7, 42, STEELS[2])
	var c = turned(raw, -9, 48, 50)
	c.anchor = Vector2i(48, 57)
	c.shadow(54, 56, 40, 6)
	vines(c, r, 30, 80, 5, 6)
	c.outline(Color("12140C"))
	return c

# --- 06 Ruined Base -------------------------------------------------------------
# A broken concrete wall running across: jagged top, a window, rebar sticking out, vines and stains.
func ruin_wall_h(seed_: int, shape: int) -> Variant:
	var r = CsRandom.new(seed_)
	var w: int = 128 if shape == 0 else 96
	var c = Canvas.new(w + 12, 86)
	var gy: int = 78
	var thick: int = 10
	c.anchor = Vector2i(w / 2 + 4, gy)
	c.shadow(w / 2 + 12, gy + 1, w * 0.5, 5)
	var tops = Cs.arr(w, 0)
	for x in range(w):
		var u: float = float(x) / w
		# tall in the middle stretches, broken down toward the ends and at a gap
		var hgt: float = 56 - 30 * value(x, 0, 14, seed_) - (40 if shape == 1 and u > 0.55 and u < 0.72 else 0)
		if u < 0.06 or u > 0.94:
			hgt -= 18
		tops[x] = gy - maxi(6, int(hgt)) - int(hash_(x, 1, seed_) * 2)
	for x in range(w):
		var xx: int = 4 + x
		var top: int = tops[x]
		# the top of the wall (its thickness seen from above), then the face
		var y: int = top
		while y < top + thick and y < gy:
			c.put(xx, y, pick(CONC, 4 if y == top else 3 - int(hash_(xx, y, seed_) * 1.3)))
			y += 1
		for y_2 in range(top + thick, gy + 1):
			var b: int = 2
			if y_2 >= gy - 1:
				b = 1
			if (y_2 - gy) % 12 == 0:
				b = 1
			if hash_(xx, y_2, seed_ + 3) > 0.92:
				b -= 1
			if hash_(xx, y_2, seed_ + 4) > 0.95:
				b += 1
			c.put(xx, y_2, pick(CONC, b))
	# a window with the dark room behind
	var wx: int = 4 + w / 3
	var wy: int = gy - 40
	if tops[w / 3 + 6] < wy - 4:
		rect(c, wx, wy, 16, 14, [CAVE_DARK, Color("1D1A20"), Color("2B2730")], 1, seed_ + 6, 0.25)
		for x in range(wx - 1, wx + 17):
			c.put(x, wy + 14, CONC[4])
	# a door gap at the right on the long wall
	if shape == 0:
		for x in range(4 + w - 34, 4 + w - 18):
			for y in range(maxi(tops[x - 4] + thick, gy - 32), gy + 1):
				c.put(x, y, Color("1D1A20") if y > gy - 30 else CONC[2])
	# a patch of old green paint, stains, rebar
	rect(c, 4 + int(w * 0.68), gy - 34, 14, 18, hex("3E5536", "4F6A43", "62804F"), 1, seed_ + 7, 0.3)
	stain(c, 4, gy - 60, w, 60, hex("2E2C28", "3E3B35", "4E4A42"), seed_ + 8, 0.2, 14)
	for i in range(6):
		var x: int = 6 + r.next(w - 4)
		var top: int = tops[x - 4]
		for s in range(1, 6 + r.next(6)):
			c.put(x + (1 if s > 5 else 0), top - s, pick(RUSTY, 1 + s % 2))
	vines(c, r, 4, 4 + w, 9, 26)
	# rubble at the foot
	for i in range(7):
		var x: int = 4 + r.next(w)
		var y: int = gy - 1 + r.next(3)
		c.put(x, y, CONC[3])
		c.put(x + 1, y, CONC[2])
		c.put(x, y - 1, CONC[4])
	c.outline(Color("1A1B1E"))
	return c

# the same wall running down the screen: its long top, broken, and the end face
func ruin_wall_v(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(26, 128)
	var gy: int = 122
	var thick: int = 10
	c.anchor = Vector2i(12, gy)
	c.shadow(18, gy - 40, 7, 44)
	for y in range(8, gy - 30):
		# the wall's height drops away in broken steps toward the far end
		var lift: int = int(26 + 22 * value(0, y, 16, seed_))
		for x in range(7, 7 + thick):
			c.put(x, y - lift + 30, pick(CONC, 4 if x == 7 else 3 - int(hash_(x, y, seed_) * 1.4)))
		c.put(7 + thick, y - lift + 30, CONC[1])
	box(c, 7, gy - 44, thick, 4, 40, CONC, seed_ + 1, 3, 2)
	stain(c, 6, 0, 14, gy, hex("2E2C28", "3E3B35", "4E4A42"), seed_ + 2, 0.2, 6)
	vines(c, r, 7, 17, 4, 18)
	c.outline(Color("1A1B1E"))
	return c

# steel shelving with boxes on it
func rack(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(52, 60)
	c.anchor = Vector2i(26, 56)
	c.shadow(30, 56, 22, 3)
	for y in range(4, 57):
		c.put(4, y, STEELS[3])
		c.put(5, y, STEELS[1])
		c.put(46, y, STEELS[2])
		c.put(47, y, STEELS[0])
	for sy in [18, 34, 50]:
		box(c, 4, sy - 3, 44, 2, 2, STEELS, seed_ + sy, 3, 1)
		var x: int = 7
		while x < 42:
			var bw: int = 7 + r.next(6)
			var bh: int = 7 + r.next(5)
			if x + bw > 45:
				break
			var pal = OLIVE if r.next(3) == 0 else hex("5A4630", "7E6444", "A08458", "BFA16E") if r.next(2) == 0 else BOX_BLUE
			box(c, x, sy - 3 - bh - 2, bw, 2, bh, pal, seed_ + x, 3, 2)
			x += bw + 1 + r.next(2)
	stain(c, 0, 0, 52, 60, RUSTY, seed_ + 9, 0.12, 4)
	c.outline(Color("15171C"))
	return c

# a green military crate with a stencilled mark
func crate(seed_: int) -> Variant:
	var c = Canvas.new(30, 26)
	c.anchor = Vector2i(15, 22)
	c.shadow(18, 22, 13, 3)
	box(c, 3, 4, 24, 6, 13, OLIVE, seed_, 3, 2)
	for x in range(3, 27):
		c.put(x, 15, OLIVE[1])
	for y in range(10, 23):
		c.put(5, y, OLIVE[1])
		c.put(24, y, OLIVE[1])
	for _it1 in [[12, 12], [13, 12], [14, 12], [13, 13], [16, 12], [16, 13], [17, 13], [18, 12]]:
		var x = _it1[0]
		var y = _it1[1]
		c.put(x, y, Color("C9C08A"))
	c.put(5, 11, STEELS[3])
	c.put(24, 11, STEELS[3])
	c.outline(Color("12140C"))
	return c

# a lattice radio mast with a dish
func mast(seed_: int) -> Variant:
	var c = Canvas.new(40, 150)
	var gy: int = 146
	c.anchor = Vector2i(20, gy)
	c.shadow(28, gy, 12, 3)
	var lb = Vector2(10, gy)
	var rb = Vector2(30, gy)
	var lt = Vector2(17, 10)
	var rt = Vector2(23, 10)
	line(c, lb, lt, STEELS[3])
	line(c, lb + Vector2(1, 0), lt + Vector2(1, 0), STEELS[2])
	line(c, rb, rt, STEELS[1])
	line(c, rb + Vector2(-1, 0), rt + Vector2(-1, 0), STEELS[2])
	for i in range(9):
		var t0: float = i / 9.0
		var t1: float = (i + 1) / 9.0
		var a = lb.lerp(lt, t0)
		var b = rb.lerp(rt, t1)
		var a2 = rb.lerp(rt, t0)
		var b2 = lb.lerp(lt, t1)
		line(c, a, b, STEELS[1])
		line(c, a2, b2, STEELS[1])
		line(c, lb.lerp(lt, t1), rb.lerp(rt, t1), STEELS[2])
	line(c, Vector2(20, 10), Vector2(20, 0), STEELS[3])
	c.put(20, 0, Color("D9534A"))
	# the dish, turned toward the light
	disc(c, 31, 30, 6, 7, STEELS[3])
	disc(c, 31.5, 30.5, 4, 5, STEELS[2])
	c.put(29, 27, STEELS[4])
	line(c, Vector2(24, 30), Vector2(27, 30), STEELS[1])
	# a rusty cable box at the foot
	box(c, 14, gy - 12, 12, 3, 8, RUSTY, seed_, 3, 2)
	stain(c, 0, 0, 40, 150, RUSTY, seed_ + 1, 0.1, 0)
	c.outline(Color("15171C"))
	return c

# --- 07 Stranded Convoy ---------------------------------------------------------
# A military truck facing left: the cab with its bonnet, the cargo bed under a sagging canvas cover. The
# second one has the canvas torn open and the tailgate down, crates showing (the titanium cargo).
func truck(seed_: int, open: bool) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(142, 92)
	var gy: int = 84
	c.anchor = Vector2i(72, gy)
	c.shadow(80, gy, 64, 6)
	# chassis and bumper
	rect(c, 8, gy - 22, 126, 6, OLIVE, 1, seed_, 0.1)
	# bonnet and cab
	box(c, 6, gy - 44, 22, 6, 18, OLIVE, seed_ + 1, 3, 2)
	box(c, 26, gy - 62, 26, 6, 38, OLIVE, seed_ + 2, 3, 2)
	rect(c, 29, gy - 54, 20, 12, GLASSY, 1, seed_ + 3, 0.2)
	for i in range(7):
		c.put(31 + i, gy - 44 - i, GLASSY[3])
	for y in range(gy - 36, gy - 26):
		for x in range(7, 14, 2):
			c.put(x, y, OLIVE[0])
	disc(c, 17, gy - 33, 2, 2, Color("D8D2A6"))
	# the bed
	box(c, 54, gy - 40, 80, 4, 18, OLIVE, seed_ + 4, 3, 2)
	ribs(c, 54, gy - 36, 80, 18, OLIVE, 2, 8)
	if not open:
		# the canvas cover: a rounded top, sagging between the hoops
		for x in range(54, 134):
			var u: float = (x - 54) % 20 / 20.0
			var sag: int = int(sin(u * PI) * 3)
			var top: int = gy - 70 + sag
			for y in range(top, gy - 40):
				var b: int = 3 if y < top + 8 else 2
				if y == top:
					b = 4
				if (x - 54) % 20 == 0:
					b = 4 if y < top + 8 else 3
				if hash_(x, y, seed_) > 0.93:
					b -= 1
				c.put(x, y, pick(CANVAS_C, b))
		# a tear
		for i in range(8):
			c.put(100 + i, gy - 58 + i / 2, CAVE_DARK)
			c.put(100 + i, gy - 57 + i / 2, CANVAS_C[0])
	else:
		# hoops left bare, shreds of canvas, crates in the bed, the tailgate down
		for h in range(4):
			var x: int = 56 + h * 24
			for y in range(gy - 70, gy - 40):
				c.put(x, y, STEELS[2])
			var xx: int = x
			while xx < x + 24 and h < 3:
				c.put(xx, gy - 70, STEELS[3])
				xx += 1
		for x in range(56, 82):
			for y in range(gy - 70, gy - 62 + x % 5):
				c.put(x, y, pick(CANVAS_C, 2 + (1 if y == gy - 70 else 0)))
		box(c, 64, gy - 56, 18, 5, 11, OLIVE, seed_ + 5, 3, 2)
		box(c, 86, gy - 52, 14, 4, 8, ALLOY, seed_ + 6, 2, 1)
		box(c, 104, gy - 58, 20, 5, 13, OLIVE, seed_ + 7, 3, 2)
		box(c, 132, gy - 24, 6, 2, 18, OLIVE, seed_ + 8, 3, 1)
	stain(c, 6, gy - 70, 128, 50, RUSTY, seed_ + 9, 0.22, 12)
	stain(c, 6, gy - 30, 130, 14, hex("2E2418", "4A3A26", "5E4A30"), seed_ + 10, 0.4, 0)
	wheel(c, 22, gy - 9, 10)
	wheel(c, 86, gy - 9, 10)
	wheel(c, 112, gy - 9, 10)
	vines(c, r, 30, 130, 7, 10)
	c.outline(Color("12140C"))
	return c

# --- 08 Mangrove Swamp ----------------------------------------------------------
# a mangrove: a dark leafy crown on a short trunk standing on arched stilt roots
func mangrove(seed_: int, shape: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(72, 80)
	var cx: float = 36
	var gy: float = 76
	c.anchor = Vector2i(36, 75)
	c.shadow(cx + 6, gy - 1, 26, 4)
	var segs = []
	var fork = Vector2(cx, gy - 20 - shape * 3)
	# arched roots from the fork out to the mud
	var roots: int = 7 + shape
	for i in range(roots):
		var u: float = (i + 0.5) / roots
		var fx: float = lerpf(-27, 27, u) + float(r.next_double() - 0.5) * 4
		var foot = Vector2(cx + fx, gy - 1 - float(r.next_double()) * 3)
		var knee = Vector2(cx + fx * 0.6, fork.y - 4 - float(r.next_double()) * 4)
		segs.append([fork, knee, 1.6, 1.3])
		segs.append([knee, foot, 1.3, 1.1])
	segs.append([fork, Vector2(cx + 1, gy - 40), 2.8, 2.2])
	segs.append([Vector2(cx + 1, gy - 40), Vector2(cx - 8, gy - 50), 1.6, 1.0])
	segs.append([Vector2(cx + 1, gy - 40), Vector2(cx + 10, gy - 52), 1.6, 1.0])
	raster(c, segs, MANG_BARK)
	# the crown: overlapping leafy balls, the far ones first
	var balls = []
	for i in range(9):
		balls.append([cx + float(r.next_double() - 0.5) * 40, gy - 54 - float(r.next_double()) * 14, 7 + float(r.next_double()) * 4])
	Cs.sort_cmp(balls, func(a, b): return Cs.compare(a[1], b[1]))
	var tag: int = 10
	for b in balls:
		var _old1 = tag
		tag += 1
		ball(c, r, b[0], b[1], b[2], MANG_LEAF, _old1)
	c.outline(Color("101C12"))
	return c

# --- 09 Weather Station ---------------------------------------------------------
# A small plastered hut under a rusty tin roof, a steel door and a louvred vent, a wind vane and an aerial
# on the roof, vines up the corner and a planter by the door.
func station(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(96, 120)
	var gy: int = 114
	c.anchor = Vector2i(46, gy)
	c.shadow(54, gy, 40, 6)
	# walls
	box(c, 14, gy - 50, 64, 4, 46, PLASTER, seed_, 3, 2, 0.2)
	# door, vent, window
	rect(c, 24, gy - 38, 14, 34, STEELS, 2, seed_ + 1, 0.15)
	for y in range(gy - 38, gy - 4):
		c.put(37, y, STEELS[0])
	c.put(34, gy - 22, STEELS[4])
	c.put(34, gy - 21, STEELS[0])
	rect(c, 26, gy - 34, 10, 6, STEELS, 1, seed_ + 2)
	rect(c, 50, gy - 36, 18, 12, STEELS, 1, seed_ + 3)
	for y in range(gy - 35, gy - 24, 2):
		for x in range(51, 67):
			c.put(x, y, STEELS[3])
	stain(c, 14, gy - 50, 64, 46, hex("4E4A40", "6A6556", "857F6D"), seed_ + 4, 0.25, 12)
	# the tin roof: a sloping sheet, overhanging, ribbed and rusting
	for x in range(8, 86):
		var top: int = gy - 66 + (x - 8) / 12
		for y in range(top, gy - 48):
			var b: int = 1 if y > gy - 51 else 3
			if (x - 8) % 5 == 0:
				b -= 1
			if (x - 8) % 5 == 1:
				b += 1
			c.put(x, y, pick(TIN, b))
	stain(c, 8, gy - 68, 78, 20, RUSTY, seed_ + 5, 0.3, 4)
	# the wind vane: a mast, the arrow and the cross of N-S-E-W
	var mx: int = 30
	for y in range(gy - 106, gy - 64):
		c.put(mx, y, STEELS[3])
		c.put(mx + 1, y, STEELS[1])
	line(c, Vector2(mx - 10, gy - 100), Vector2(mx + 12, gy - 100), STEELS[2])
	for i in range(4):
		c.put(mx - 10 + i, gy - 101 - i / 2, STEELS[3])
		c.put(mx - 10 + i, gy - 99 + i / 2, STEELS[3])
	rect(c, mx + 10, gy - 104, 4, 8, STEELS, 3, seed_ + 6)
	line(c, Vector2(mx - 6, gy - 90), Vector2(mx + 7, gy - 90), STEELS[1])
	line(c, Vector2(mx - 3, gy - 93), Vector2(mx + 4, gy - 87), STEELS[1])
	# anemometer cups and the aerial
	var ax: int = 68
	for y in range(gy - 98, gy - 60):
		c.put(ax, y, STEELS[2])
	for i in range(4):
		line(c, Vector2(ax - 7 + i, gy - 94 + i * 6), Vector2(ax + 7 - i, gy - 94 + i * 6), STEELS[2])
	# vines up the right corner, a planter
	for i in range(30):
		var x: int = 72 + r.next(6)
		var y: int = gy - 4 - r.next(46)
		if c.body(x, y):
			c.put(x, y, pick(VINES, 1 + r.next(3)), 3)
	box(c, 40, gy - 10, 12, 3, 7, TIMBER, seed_ + 7, 3, 2)
	for i in range(6):
		c.put(41 + i * 2, gy - 11 - i % 2, pick(BROADLEAF, 2 + i % 2))
	c.outline(Color("1A1714"))
	return c

# --- 10 Old Fishing Pier ----------------------------------------------------------
# The pier seen from above, running out to sea to the left: boards across it, some missing (the sea shows
# through), posts down the sides, the far end gone to bare posts. Flat on the ground layer; the anchor is the
# land end, the middle of the deck.
func pier(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(300, 84)
	var y0: int = 16
	var y1: int = 64
	c.anchor = Vector2i(296, (y0 + y1) / 2)
	# the shade on the water under the deck
	for x in range(70, 300):
		for y in range(y1, y1 + 6):
			c.put(x, y, SHADOW, 1)
	for x in range(72, 298, 7):
		var plank: int = (x - 72) / 7
		# gaps: a few missing near the middle, many near the broken end
		var lose: float = 0.55 if x < 120 else 0.18 if x < 170 else 0.06
		if hash_(plank, 0, seed_) < lose:
			continue
		var sag: int = 1 if hash_(plank, 2, seed_) > 0.8 else 0
		for xx in range(x, x + 6):
			for y in range(y0 + sag, y1 + sag):
				var b: int = 2 + (1 if hash_(plank, 4, seed_) > 0.65 else 0) - (1 if hash_(plank, 3, seed_) > 0.8 else 0)
				if xx == x + 5:
					b = 0
				elif y == y0 + sag:
					b += 1
				if value(xx, y, 3, seed_) > 0.72:
					b -= 1
				c.put(xx, y, pick(TIMBER, b + 1))
		# the boards' front edge
		for xx in range(x, x + 6):
			c.put(xx, y1 + sag, TIMBER[1])
			c.put(xx, y1 + sag + 1, TIMBER[0])
	# stringers under the deck show through the gaps, and posts along both sides out to the end
	for x in range(72, 296):
		c.put(x, y0 + 8, TIMBER[1], 1)
		c.put(x, y1 - 8, TIMBER[1], 1)
	for x in range(10, 296, 30):
		for y in [y0 - 2, y1 + 2]:
			if x < 72 and hash_(x, y, seed_) < 0.3:
				continue
			var h: int = 10 + int(hash_(x, y + 1, seed_) * 10) if x < 72 else 6
			box(c, x, y - h + 4, 6, 3, h, TIMBER, seed_ + x + y, 3, 2)
	c.outline(Color("1C150F"))
	return c

# a fish trap (a slatted barrel basket), lying or standing
func trap(seed_: int, standing: bool) -> Variant:
	var c = Canvas.new(30, 24)
	c.anchor = Vector2i(15, 20)
	c.shadow(18, 20, 12, 3)
	if standing:
		box(c, 6, 4, 16, 4, 14, TIMBER, seed_, 3, 2)
		for x in range(7, 21, 3):
			for y in range(9, 18):
				c.put(x, y, CAVE_DARK)
		for x in range(6, 22):
			c.put(x, 12, TIMBER[3])
			c.put(x, 15, TIMBER[3])
	else:
		for x in range(4, 26):
			for y in range(8, 20):
				var dy: float = (y - 14) / 6.0
				var b: int = 3 if dy < -0.4 else 2 if dy < 0.4 else 1
				var gap: bool = x % 4 == 0 and y > 9 and y < 19
				c.put(x, y, CAVE_DARK if gap else pick(TIMBER, b))
		disc(c, 5, 14, 2.5, 6, TIMBER[2])
		disc(c, 5, 14, 1.2, 3, CAVE_DARK)
		for y in range(8, 20):
			c.put(12, y, TIMBER[4])
			c.put(20, y, TIMBER[4])
	c.outline(Color("1C150F"))
	return c

# --- 12 Coral Lookout -------------------------------------------------------------
# A wooden shelter on stilts with a rusty tin roof, a railing and steps down to the ground.
func lookout(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(104, 124)
	var gy: int = 118
	c.anchor = Vector2i(52, gy)
	c.shadow(62, gy, 42, 6)
	# stilts
	for x in [18, 82]:
		box(c, x, gy - 46, 5, 2, 44, TIMBER, seed_ + x, 3, 2)
	# the floor deck
	box(c, 12, gy - 58, 80, 14, 6, TIMBER, seed_ + 1, 3, 1)
	ribs(c, 12, gy - 58, 80, 14, TIMBER, 3, 6)
	# back posts and the roof posts
	for x in [14, 50, 86]:
		for y in range(gy - 100, gy - 56):
			c.put(x, y, TIMBER[3])
			c.put(x + 1, y, TIMBER[1])
	# bench inside
	box(c, 30, gy - 68, 30, 3, 6, TIMBER, seed_ + 2, 4, 2)
	# the railing along the front
	for x in range(12, 92):
		c.put(x, gy - 64, TIMBER[4])
		c.put(x, gy - 63, TIMBER[2])
		c.put(x, gy - 56, TIMBER[2])
	for x in range(14, 90, 6):
		for y in range(gy - 63, gy - 52):
			c.put(x, y, TIMBER[3])
	# the roof: rusty tin sloping down to the front, ribbed, overhanging
	for x in range(4, 100):
		for y in range(gy - 112, gy - 96):
			var b: int = 1 if y > gy - 99 else 3
			if (x - 4) % 6 == 0:
				b -= 1
			if (x - 4) % 6 == 1:
				b += 1
			c.put(x, y, pick(TIN, b))
	stain(c, 4, gy - 112, 96, 16, RUSTY, seed_ + 3, 0.35, 6)
	# steps down on the left
	for i in range(6):
		box(c, 2 + i * 2, gy - 46 + i * 7, 12, 3, 2, TIMBER, seed_ + 10 + i, 3, 1)
	line(c, Vector2(2, gy - 50), Vector2(12, gy - 2), TIMBER[1])
	vines(c, r, 14, 90, 4, 10)
	c.outline(Color("1C150F"))
	return c

# --- 13 Container Yard -----------------------------------------------------------
# a shipping container side on: ribbed steel, corner castings, rust; Stacked = two high
func container(seed_: int, pal, stacked: bool) -> Variant:
	var c = Canvas.new(142, 118 if stacked else 70)
	var gy: int = c.h - 6
	c.anchor = Vector2i(70, gy)
	c.shadow(78, gy, 66, 6)
	if stacked:
		_container_one(gy - 48, pal, seed_, c)
		_container_one(gy - 96, BOX_BLUE, seed_ + 3, c)
	else:
		_container_one(gy - 48, pal, seed_, c)
	c.outline(Color("101216"))
	return c

# local function One of the method above
func _container_one(y: int, p, s: int, c) -> void:
	box(c, 4, y, 132, 10, 38, p, s, 3, 2, 0.08)
	ribs(c, 4, y + 11, 132, 36, p, 2, 4)
	for x in [4, 130]:
		rect(c, x, y, 6, 10, STEELS, 2)
		rect(c, x, y + 42, 6, 6, STEELS, 1)
	stain(c, 4, y, 132, 48, RUSTY, s + 1, 0.22, 12)
	# a faded stencil
	for x in range(20, 44, 3):
		c.put(x, y + 18, p[4])

# a container end on, its doors open: one swung out, the dark inside with crates (titanium cargo)
func container_end(seed_: int, pal) -> Variant:
	var c = Canvas.new(92, 76)
	var gy: int = 70
	c.anchor = Vector2i(36, gy)
	c.shadow(44, gy, 40, 6)
	box(c, 6, gy - 64, 58, 16, 48, pal, seed_, 3, 2, 0.08)
	# the open end: dark inside, a crate and a sheet of alloy
	rect(c, 10, gy - 44, 50, 38, [CAVE_DARK, Color("1A1A20"), Color("26262E")], 1, seed_ + 1, 0.2)
	box(c, 14, gy - 22, 18, 4, 14, OLIVE, seed_ + 2, 3, 2)
	box(c, 36, gy - 28, 8, 2, 20, ALLOY, seed_ + 3, 3, 2)
	box(c, 46, gy - 18, 12, 3, 10, TIMBER, seed_ + 4, 3, 2)
	# the door swung open to the right, seen edge-on-ish
	for x in range(64, 86):
		for y in range(gy - 46 + (x - 64) / 4, gy - 4 + (x - 64) / 8):
			var b: int = 1 if (x - 64) % 4 == 0 else 2
			c.put(x, y, pick(pal, b))
	for y in range(gy - 46, gy - 4, 10):
		c.put(70, y, STEELS[3])
	stain(c, 6, gy - 64, 80, 64, RUSTY, seed_ + 5, 0.25, 10)
	c.outline(Color("101216"))
	return c

# an oil drum
func drum(seed_: int, pal) -> Variant:
	var c = Canvas.new(20, 28)
	c.anchor = Vector2i(10, 25)
	c.shadow(12, 25, 8, 2.5)
	for y in range(6, 25):
		for x in range(3, 17):
			var dx: float = (x - 9.5) / 7.0
			var b: int = 3 if dx < -0.4 else 2 if dx < 0.35 else 1
			if y == 11 or y == 19:
				b -= 1
			c.put(x, y, pick(pal, b))
	disc(c, 10, 6, 7, 3, pick(pal, 3))
	disc(c, 10, 6, 5, 2, pick(pal, 2))
	c.put(12, 5, STEELS[1])
	stain(c, 0, 0, 20, 28, RUSTY, seed_, 0.25, 3)
	c.outline(Color("101216"))
	return c

func pallet(seed_: int) -> Variant:
	var c = Canvas.new(40, 20)
	c.anchor = Vector2i(20, 15)
	c.shadow(22, 15, 18, 3)
	for i in range(5):
		box(c, 3 + i * 7, 4, 6, 7, 3, TIMBER, seed_ + i, 3, 2)
	for x in range(3, 37):
		c.put(x, 14, TIMBER[1])
		c.put(x, 15, TIMBER[0])
	c.outline(Color("1C150F"))
	return c

# --- 14 Beached Shipwreck --------------------------------------------------------
# A small cargo ship run aground, bow to the left: the black upper hull and the red below, rust running down,
# a few containers on the deck, the white bridge and funnel at the stern, a crane mast, and the hull split
# open toward the shore.
func ship(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var raw = Canvas.new(470, 230)
	var keel: int = 206
	var split: int = 250
	for x in range(12, 462):
		var dk: int = _ship_deck_at(x)
		var bt: int = _ship_bottom_at(x, keel)
		if bt <= dk + 6:
			continue
		if x >= split - 4 and x <= split + 5:
			continue
		# the deck seen from above
		for y in range(dk - 14, dk):
			var b: int = 3 if y == dk - 14 else 2
			if hash_(x, y, seed_) > 0.92:
				b -= 1
			raw.put(x, y, pick(DECK, b))
		# the side: black above the waterline, red below
		var water: int = dk + int((bt - dk) * 0.55)
		for y in range(dk, bt + 1):
			var p = HULL if y < water else HULL_RED
			var b: int = 4 if y == dk else 3 if y == dk + 1 else 2
			if y > bt - 3:
				b = 0
			if (x - 12) % 34 == 0:
				b -= 1
			if hash_(x, y, seed_ + 1) > 0.95:
				b -= 1
			raw.put(x, y, pick(p, b))
		raw.put(x, water, pick(WHITEWASH, 2))
	# the torn edges of the split: jagged plates and the dark hold behind
	for y in range(96, keel):
		var j: int = int(hash_(0, y, seed_) * 4)
		for x in range(split - 6 - j, split + 7 + j + 1):
			var edge: bool = x < split - 3 - j / 2 or x > split + 4 + j / 2
			if edge:
				raw.put(x, y, pick(RUSTY, 1 + (1 if y % 3 == 0 else 0)))
			else:
				raw.put(x, y, CAVE_DARK if y > 150 else Color("1C1A1E"))
	# containers on the deck, a hatch, the crane mast
	box(raw, 120, 72, 46, 8, 26, BOX_ORANGE, seed_ + 2, 3, 2, 0.06)
	ribs(raw, 120, 80, 46, 26, BOX_ORANGE, 2, 4)
	box(raw, 170, 76, 40, 8, 22, BOX_BLUE, seed_ + 3, 3, 2, 0.06)
	ribs(raw, 170, 84, 40, 22, BOX_BLUE, 2, 4)
	box(raw, 262, 84, 40, 6, 14, BOX_RED, seed_ + 4, 3, 2, 0.06)
	box(raw, 214, 92, 30, 6, 8, DECK, seed_ + 5, 3, 1)
	for y in range(20, 100):
		raw.put(92, y, STEELS[3])
		raw.put(93, y, STEELS[1])
	line(raw, Vector2(93, 26), Vector2(150, 70), STEELS[2])
	line(raw, Vector2(93, 30), Vector2(40, 92), STEELS[1])
	# the bridge, its windows, the funnel
	box(raw, 340, 34, 84, 8, 70, WHITEWASH, seed_ + 6, 3, 2, 0.1)
	box(raw, 352, 14, 60, 6, 22, WHITEWASH, seed_ + 7, 3, 2, 0.1)
	for x in range(356, 408, 8):
		rect(raw, x, 26, 6, 6, GLASSY, 1)
	for row in range(3):
		for x in range(348, 418, 10):
			rect(raw, x, 52 + row * 16, 5, 6, GLASSY, 1)
	box(raw, 426, 22, 18, 5, 40, HULL_RED, seed_ + 8, 3, 2)
	rect(raw, 426, 34, 18, 5, WHITEWASH, 3)
	for y in range(14):
		raw.put(372, y, STEELS[2])
	line(raw, Vector2(372, 2), Vector2(392, 2), STEELS[2])
	# rust running down the hull and the white superstructure, barnacles at the foot
	stain(raw, 12, 96, 450, 112, RUSTY, seed_ + 9, 0.2, 70)
	stain(raw, 340, 14, 104, 92, hex("4A3020", "6E4A30", "8E6440"), seed_ + 10, 0.18, 20)
	for i in range(160):
		var x: int = 20 + r.next(440)
		var y: int = keel - 14 + r.next(12)
		if raw.body(x, y):
			raw.set_(x, y, pick(LIME, 2 + r.next(2)))
	var c = turned(raw, 3.5, 235, keel)
	c.anchor = Vector2i(235, keel)
	c.shadow(250, keel + 2, 220, 12)
	c.outline(Color("0C0E10"))
	return c

# local function DeckAt of the method above
func _ship_deck_at(x: int) -> int:
	return 112 - ((80 - x) / 3 if x < 80 else 0)

# local function BottomAt of the method above
func _ship_bottom_at(x: int, keel) -> int:
	return keel - (int((110 - x) * (110 - x) / 140.0) if x < 110 else 0) - (x - 440 if x > 440 else 0)

# machinery washed onto the sand: an engine block with pipes
func gear(seed_: int) -> Variant:
	var c = Canvas.new(38, 30)
	c.anchor = Vector2i(19, 25)
	c.shadow(22, 25, 16, 3)
	box(c, 6, 6, 24, 6, 13, STEELS, seed_, 3, 2)
	for x in range(9, 28, 4):
		rect(c, x, 12, 2, 6, STEELS, 0)
	disc(c, 30, 14, 4, 4, ALLOY[1])
	disc(c, 30, 14, 2, 2, STEELS[0])
	line(c, Vector2(4, 8), Vector2(10, 2), RUSTY[2])
	line(c, Vector2(5, 9), Vector2(11, 3), RUSTY[1])
	stain(c, 0, 0, 38, 30, RUSTY, seed_ + 1, 0.3, 4)
	c.outline(Color("101216"))
	return c

# --- 16 Southwest Cave -----------------------------------------------------------
# A limestone bluff with a shallow cave at its foot: big pale blocks, ferns and vines hanging, the dark mouth
# with a fringe of dripstone and a dirt floor running out.
func bluff(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(240, 156)
	var gy: int = 150
	c.anchor = Vector2i(120, gy)
	c.shadow(132, gy, 112, 8)
	# the cliff face in blocks of limestone: each block its own height, a lit top ledge with moss, a lit left
	# edge and a shaded right one, bedding lines across
	var edges = [8]
	while edges[-1] < 232:
		edges.append(min(232, edges[-1] + 18 + r.next(18)))
	for b in range(edges.size() - 1):
		var x0: int = edges[b]
		var x1: int = edges[b + 1]
		var mid: float = (x0 + x1) / 2.0
		var taper: float = clampf(minf(mid - 8, 232 - mid) / 50.0, 0.35, 1)
		var hgt: int = int((70 + r.next(46)) * taper)
		var ledge: int = 7 + r.next(5)
		var bed_: int = r.next(6)
		for x in range(x0, x1):
			var top: int = gy - hgt + int(hash_(x, b, seed_) * 2) + (2 if x == x0 or x == x1 - 1 else 0)
			for y in range(top, gy + 1):
				var bb: int = 0
				if y < top + ledge:
					bb = 4 if y == top else 3
				else:
					bb = 2
					if x < x0 + 2:
						bb = 3
					if x >= x1 - 3:
						bb = 1
					if (y - top - ledge + bed_) % 15 == 0:
						bb = 1
					if y >= gy - 2:
						bb = 1
					if hash_(x, y, seed_) > 0.94:
						bb -= 1
				c.put(x, y, pick(LIME, bb), 2, b + 1)
				if y < top + ledge and y > top and value(x, y, 4, seed_ + b) > 0.6:
					c.set_(x, y, pick(MOSS, 1 + int(hash_(x, y, seed_) * 2)))
			# the seam between blocks
			if x == x0:
				for y in range(top + ledge, gy + 1):
					c.set_(x, y, LIME[0])
	# fallen blocks at the foot, either side of the mouth
	var tag: int = 50
	for _it1 in [[30, 16, 13], [66, 12, 10], [176, 14, 12], [214, 15, 12]]:
		var x = _it1[0]
		var rx = _it1[1]
		var ry = _it1[2]
		var _old2 = tag
		tag += 1
		boulder(c, r, x, gy + 2, rx, ry, LIME, false, _old2, 0.1)
	# the cave mouth: a dark arch, darkest at the back, teeth of dripstone along its lip
	var mx: float = 120
	var my: float = gy - 1
	var mw: float = 32
	var mh: float = 46
	for y in range(int(my - mh), floori(my) + 1):
		for x in range(int(mx - mw), floori(mx + mw) + 1):
			var dx: float = (x + 0.5 - mx) / mw
			var dy: float = (y + 0.5 - my) / mh
			if dx * dx + dy * dy > 1:
				continue
			var d: float = sqrt(dx * dx + dy * dy)
			var col: Color = LIME[0] if d > 0.88 else Color("221E22") if d > 0.68 else CAVE_DARK
			c.put(x, y, col, 2, 99)
	for x in range(int(mx - mw + 6), ceili(mx + mw - 6), 4):
		var dx: float = (x - mx) / mw
		var lip: int = int(my - mh * sqrt(maxf(0, 1 - dx * dx)))
		var l: int = 2 + r.next(5)
		for s in range(l):
			c.put(x, lip + s, LIME[2])
			if s < l - 2:
				c.put(x + 1, lip + s, LIME[1])
	# the dirt floor of the mouth
	for y in range(int(my) - 6, floori(my) + 1):
		for x in range(int(mx - 24), ceili(mx + 24)):
			if absf(x - mx) < 24 - (my - y) * 2:
				c.put(x, y, pick(hex("3A2E22", "54432F", "6E5A40"), (y - int(my) + 6) / 3), 3)
	vines(c, r, 12, 228, 30, 40)
	# ferns at the foot
	for i in range(7):
		var fx: float = 20 + i * 32 + r.next(10)
		if absf(fx - mx) < 34:
			continue
		for k in range(5):
			var a: float = -PI / 2 + (k - 2) * 0.5
			leaf(c, Vector2(fx, gy), Vector2(cos(a), sin(a) * 0.8), 9 + r.next(4), 2, BROADLEAF)
	c.outline(LIME[0].darkened(0.6))
	return c

# --- 17 South Cape Lookout ------------------------------------------------------
# A concrete observation platform from above: a six-sided slab with a low parapet, open at the back where the
# trail comes up. Flat on the ground layer; the anchor is its middle.
func platform(seed_: int) -> Variant:
	var c = Canvas.new(150, 112)
	var ctr = Vector2(75, 54)
	var hex6 = Cs.arr(6, Vector2.ZERO)
	for i in range(6):
		var a: float = i * TAU / 6
		hex6[i] = ctr + Vector2(cos(a) * 66, sin(a) * 44)
	c.anchor = Vector2i(int(ctr.x), int(ctr.y))
	# the slab's front face (the platform stands a little proud of the rock)
	var low = hex6.map(func(p): return p + Vector2(0, 8))
	poly(c, low, func(x, y): return pick(CONC, 1))
	poly(c, hex6, func(x, y):
		var b: int = 3
		if (x + 2 * y) % 22 == 0 or (x - 2 * y) % 22 == 0:
			b = 2
		if hash_(x, y, seed_) > 0.93:
			b = 2
		if value(x, y, 6, seed_) > 0.8:
			return pick(MOSS, 1)
		return pick(CONC, b)
	)
	# the parapet: a low wall round five sides, a gap on the side facing the trail (the top)
	for i in range(6):
		if i == 4:
			continue
		var a = hex6[i]
		var b = hex6[(i + 1) % 6]
		var n: int = int(a.distance_to(b))
		for s in range(n + 1):
			var p = a.lerp(b, float(s) / n)
			var in_ = (ctr - p).normalized()
			for k in range(5):
				var q = p + in_ * k
				var front: bool = p.y > ctr.y + 4
				c.put(int(q.x), int(q.y) - (0 if front else 6), pick(CONC, 4 if k == 0 else 3))
				if not front:
					for h in range(6):
						c.put(int(q.x), int(q.y) - h, pick(CONC, 4 if h == 5 else 2))
	stain(c, 0, 0, 150, 112, hex("3E3E38", "55554C", "6A6A60"), seed_ + 1, 0.15, 10)
	c.outline(Color("1A1B1E"))
	return c

# --- 18 Abandoned Herb Garden ----------------------------------------------------
# a raised timber bed of dark soil, overgrown with herbs (one with purple flowers)
func bed(seed_: int, shape: int) -> Variant:
	var r = CsRandom.new(seed_)
	var c = Canvas.new(84, 48)
	var gy: int = 42
	c.anchor = Vector2i(42, gy)
	c.shadow(46, gy, 40, 4)
	box(c, 4, gy - 30, 74, 24, 6, TIMBER, seed_, 3, 2)
	rect(c, 8, gy - 26, 66, 17, SOIL, 1, seed_ + 1, 0.3)
	# plants in rows
	for row in range(2):
		for i in range(6):
			var base = Vector2(13 + i * 11 + r.next(3), gy - 21 + row * 8)
			for k in range(5):
				var a: float = -PI / 2 + (k - 2) * 0.6
				leaf(c, base, Vector2(cos(a), sin(a) * 0.7), 5 + r.next(3), 1.8, BROADLEAF)
			if shape == 1 and r.next(2) == 0:
				for s in range(6):
					c.put(int(base.x), int(base.y) - 6 - s, pick(PURPLE, 2 + s % 2))
	# a broken board
	for x in range(50, 62):
		c.put(x, gy - 6, SOIL[0])
	c.outline(Color("1C150F"))
	return c

# a broken picket fence, leaning, with gaps
func fence(seed_: int) -> Variant:
	var r = CsRandom.new(seed_)
	var raw = Canvas.new(108, 44)
	var gy: int = 38
	for x in range(4, 104):
		raw.put(x, gy - 22, TIMBER[3])
		raw.put(x, gy - 21, TIMBER[1])
	for x in range(4, 70):
		raw.put(x, gy - 10, TIMBER[3])
		raw.put(x, gy - 9, TIMBER[1])
	for x in range(6, 102, 7):
		if hash_(x, 0, seed_) < 0.22:
			continue
		var h: int = 26 + r.next(5)
		box(raw, x, gy - h, 4, 2, h - 2, TIMBER, seed_ + x, 3, 2)
	var c = turned(raw, 4, 20, gy)
	c.anchor = Vector2i(54, gy)
	c.shadow(58, gy, 50, 3)
	vines(c, r, 50, 104, 6, 12)
	c.outline(Color("1C150F"))
	return c

func can(seed_: int) -> Variant:
	var c = Canvas.new(28, 22)
	c.anchor = Vector2i(12, 18)
	c.shadow(14, 18, 10, 2.5)
	for y in range(7, 18):
		for x in range(6, 17):
			var dx: float = (x - 11) / 5.5
			c.put(x, y, pick(STEELS, 4 if dx < -0.4 else 3 if dx < 0.4 else 2))
	disc(c, 11, 7, 5.5, 2, STEELS[4])
	line(c, Vector2(16, 14), Vector2(24, 6), STEELS[2])
	rect(c, 23, 4, 3, 3, STEELS, 3)
	line(c, Vector2(8, 6), Vector2(11, 2), STEELS[2])
	line(c, Vector2(11, 2), Vector2(15, 6), STEELS[2])
	stain(c, 0, 0, 28, 22, RUSTY, seed_, 0.2, 2)
	c.outline(Color("101216"))
	return c

class Canvas:
	var w: int = 0
	var h: int = 0
	var anchor: Vector2i = Vector2i.ZERO
	var px
	var kind
	var tags

	func _init(w_: int, h_: int) -> void:
		self.w = w_
		self.h = h_
		px = Cs.arr(w_ * h_, Color(0, 0, 0, 0))
		kind = Cs.arr(w_ * h_, 0)
		tags = Cs.arr(w_ * h_, 0)

	func in_(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h

	func body(x: int, y: int) -> bool:
		return in_(x, y) and kind[y * w + x] == 2

	func tag_at(x: int, y: int) -> int:
		return tags[y * w + x] if in_(x, y) else -1

	# kind: 1 shadow, 2 body (gets an outline), 3 flat detail (no outline)
	func put(x: int, y: int, c: Color, k: int = 2, tag: int = 0) -> void:
		if not in_(x, y):
			return
		px[y * w + x] = c
		kind[y * w + x] = k
		tags[y * w + x] = tag

	# a soft ground shadow on empty pixels; drawn first, the body covers it
	func shadow(cx: float, cy: float, rx: float, ry: float) -> void:
		for y in range(h):
			for x in range(w):
				var dx: float = (x + 0.5 - cx) / rx
				var dy: float = (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1 and kind[y * w + x] == 0:
					put(x, y, PixelNature.SHADOW, 1)

	# the same, for shapes drawn before their shadow
	func shadow_under(cx: float, cy: float, rx: float, ry: float) -> void:
		shadow(cx, cy, rx, ry)
	var ink: Color = Color(0, 0, 0, 0)
	# what the outline painted over, so a broken stage can take it off, knock pieces out and outline again
	var under = []

	func solid(x: int, y: int) -> bool:
		return in_(x, y) and (kind[y * w + x] == 2 or kind[y * w + x] == 3)

	func at(x: int, y: int) -> Color:
		return px[y * w + x]

	func set_(x: int, y: int, c: Color) -> void:
		if in_(x, y):
			px[y * w + x] = c

	func clear(x: int, y: int) -> void:
		if in_(x, y):
			kind[y * w + x] = 0
			px[y * w + x] = Color(0, 0, 0, 0)

	func clone() -> Variant:
		var c = Cs.init(PixelNature.Canvas.new(w, h), {"anchor": anchor, "ink": ink, "under": Array(under).duplicate()})
		Cs.array_copy(px, c.px, px.size())
		Cs.array_copy(kind, c.kind, kind.size())
		Cs.array_copy(tags, c.tags, tags.size())
		return c

	func paste(source, offset: Vector2i) -> void:
		for y in range(source.h):
			for x in range(source.w):
				if source.kind[y * source.w + x] != 0:
					put(x + offset.x, y + offset.y, source.px[y * source.w + x], source.kind[y * source.w + x])

	func unoutline() -> void:
		for _it1 in under:
			var i = _it1[0]
			var c = _it1[1]
			var k = _it1[2]
			px[i] = c
			kind[i] = k
		under.clear()

	# keep only the pixels that are still solid on the other canvas (a glow layer over a broken node)
	func keep_where(body_) -> void:
		for i in range(w * h):
			if kind[i] != 0 and not body_.solid(i % w, i / w):
				kind[i] = 0

	func outline(ink_: Color) -> void:
		self.ink = ink_
		var marks = []
		for y in range(h):
			for x in range(w):
				var k: int = kind[y * w + x]
				if k == 2 or k == 3 or k == 4:
					continue
				if body(x - 1, y) or body(x + 1, y) or body(x, y - 1) or body(x, y + 1):
					marks.append(y * w + x)
		for i in marks:
			under.append([i, px[i], kind[i]])
			px[i] = ink_
			kind[i] = 4

	func to_image() -> Variant:
		var im = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for i in range(w * h):
			if kind[i] != 0:
				im.set_pixel(i % w, i / w, px[i])
		return im
