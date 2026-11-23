class_name RiversView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.Rivers.cs.
# Owner: Vu Duc Viet Anh. Draws the two rivers of src/world/IslandRivers.cs on the ground layer, over the paths
# (a path the water cuts ends at the bank): a muddy bank, the water, a deeper channel down the middle and
# ripples drifting downstream, running out over the beach into the sea. Then the bridges: stone abutments on
# both banks, a plank deck on two beams, piles in the water under it, a rail on each side and a lantern on
# each corner post. Light from the upper left, like the rest of the island.
const RIVER_MUD: Color = Color("4E5636")
const RIVER_MUD_EDGE: Color = Color("5F6A3E")
const RIVER_WATER: Color = Color("3A6E85")
const RIVER_DEEP: Color = Color("2E5C74")
const RIVER_RIM: Color = Color(0.05, 0.09, 0.1, 0.4)
const RIVER_GLINT: Color = Color(0.7, 0.86, 0.92, 0.7)
var river_looks

# constants shared with Main
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

static func ribbon(path, half: float) -> Variant:
	var l = TerrainView.offset(path, -half)
	var r = TerrainView.offset(path, half)
	var out = Cs.arr(l.size() + r.size(), Vector2.ZERO)
	Cs.copy_to(l, out, 0)
	for i in range(r.size()):
		out[l.size() + i] = r[r.size() - 1 - i]
	return out

# the stretch of a river from where it leaves the sea to where it reaches it again, Out tiles past the coast
static func landward(path, out: float) -> Variant:
	var a_: int = 0
	var b: int = path.size() - 1
	while a_ < b and IslandMap.depth(path[a_]) < -out:
		a_ += 1
	while b > a_ and IslandMap.depth(path[b]) < -out:
		b -= 1
	return path.slice(a_, b + 1)

func build_river_looks() -> void:
	var tl: float = float(T)
	river_looks = []
	for path in IslandMap.rivers:
		# Continue well into the sea; offshore vertices become transparent before either end cap.
		var wet = landward(path, 8 * tl)
		var look = RiverLook.new()
		look.path = wet
		look.bank_mesh = build_surface(wet, true)
		look.water_mesh = build_surface(wet, false)
		look.box = main.terrain_view.bounds(wet, IslandMap.RIVER_HALF * 2 + IslandMap.RIVER_BANK + tl)
		for at in wet:
			look.glint_alpha.append(1 - smoothstep(0, 3 * tl, -IslandMap.depth(at)))
		river_looks.append(look)

# Fixed geometry and vertex colours are baked once. No coast queries or triangulation during drawing.
static func build_surface(path, bank: bool) -> RiverSurface:
	var mesh = RiverSurface.new()
	var cross_section = [-1.0, -0.65, 0.0, 0.65, 1.0]
	for i in range(path.size()):
		var centre: Vector2 = path[i]
		var along: Vector2 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var across = Vector2(-along.y, along.x)
		var offshore: float = smoothstep(0, 3 * T, -IslandMap.depth(centre))
		var half: float = IslandMap.RIVER_HALF + IslandMap.RIVER_BANK if bank else IslandMap.RIVER_HALF * (1 + 0.9 * offshore)
		for side in cross_section:
			var at: Vector2 = centre + across * half * side
			var depth: float = IslandMap.depth(at)
			var col: Color
			if bank:
				col = RIVER_MUD.lerp(RIVER_MUD_EDGE, pow(absf(side), 5))
				col.a = smoothstep(0, 2 * T, depth)
			else:
				col = RIVER_DEEP.lerp(RIVER_WATER, smoothstep(0.15, 0.9, absf(side)))
				col.a = 1 - smoothstep(0, 3 * T, -depth)
				# Mouths widen over sea only; the playable river footprint stays unchanged on land.
				if depth > 0 and offshore > 0:
					col.a *= 1 - smoothstep(IslandMap.RIVER_HALF - 4, IslandMap.RIVER_HALF + 4, IslandMap.river_dist(at))
			mesh.points.append(at)
			mesh.colors.append(col)
		if i > 0:
			for j in range(4):
				var a: int = (i - 1) * 5 + j
				var b: int = i * 5 + j
				mesh.indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	return mesh

func draw_surface(mesh: RiverSurface) -> void:
	RenderingServer.canvas_item_add_triangle_array(main.get_canvas_item(), mesh.indices, mesh.points, mesh.colors)

func draw_rivers(view: Rect2) -> void:
	if river_looks == null:
		build_river_looks()
	var clk: float = float(main.clock)
	for r in river_looks:
		if not r.box.intersects(view):
			continue
		draw_surface(r.bank_mesh)
		draw_surface(r.water_mesh)
		# ripples drifting downstream (south), only those in view
		var p = r.path
		var shift: int = int(clk * 3.0)
		for i in range(shift % 5, p.size() - 1, 5):
			var at: Vector2 = p[i]
			if not view.has_point(at):
				continue
			var along: Vector2 = (p[i + 1] - at).normalized()
			var across: Vector2 = Vector2(-along.y, along.x)
			var k: int = i / 5 + shift / 5
			var side: float = (k * 7 % 5 - 2) * 0.32 * IslandMap.RIVER_HALF
			var col = RIVER_GLINT
			col.a *= r.glint_alpha[i] * (0.35 + 0.35 * sin(clk * 2.0 + k))
			var q: Vector2 = (at + across * side).round()
			main.draw_line(q, (q + along * 5).round(), col, 1)
	for i in range(IslandMap.bridges.size()):
		var deck: Rect2 = IslandMap.bridge_deck(i)
		if deck.grow(2 * float(T)).intersects(view):
			draw_bridge(deck.get_center(), clk)

# a bridge east-west across its river, centred on C
func draw_bridge(c: Vector2, clk: float) -> void:
	var l: float = Cs.round_even(IslandMap.BRIDGE_HALF_LEN)
	var w: float = Cs.round_even(IslandMap.BRIDGE_HALF_W)
	var rh: float = IslandMap.RIVER_HALF
	main.draw_set_transform(c.round())
	# shadow on the water and the piles under the deck, with a ring of ripples round each
	main.draw_rect(Rect2(-rh + 4, w + 2, 2 * rh - 4, 14), Color(0, 0, 0, 0.28))
	for x in [-Cs.round_even(rh * 0.45), Cs.round_even(rh * 0.45)]:
		main.draw_rect(Rect2(x - 5, w - 4, 10, 18), Color("3F3122"))
		main.draw_rect(Rect2(x - 5, w - 4, 3, 18), Color("5E4A33"))
		var wob: float = sin(clk * 2.2 + x) * 1.5
		main.draw_arc(Vector2(x, w + 15), 8 + wob, 0, PI, 8, Color(0.75, 0.88, 0.92, 0.45), 1)
	# stone abutments on both banks: blocks, a pale top edge and a dark front face
	for end in [-1, 1]:
		var x0: float = -l if end < 0 else rh - 8
		var x1: float = -rh + 8 if end < 0 else l
		var block = Rect2(x0, -w - 6, x1 - x0, 2 * w + 12)
		main.draw_rect(block, Color("858069"))
		main.draw_rect(Rect2(x0, w + 6, x1 - x0, 7), Color("5A5646"))
		var y: float = -w - 6
		var row: float = 0
		while y < w + 6:
			main.draw_line(Vector2(x0, y), Vector2(x1, y), Color("6A6655"), 1)
			var x: float = x0 + (6 if fmod(row, 2) == 0 else 14)
			while x < x1:
				main.draw_line(Vector2(x, y), Vector2(x, minf(y + 10, w + 6)), Color("6A6655"), 1)
				x += 16
			y += 10
			row += 1
		main.draw_line(Vector2(x0, -w - 6), Vector2(x1, -w - 6), Color("B4AE93"), 2)
		main.draw_rect(Rect2(x0, w + 13, x1 - x0, 2), Color(0, 0, 0, 0.25))
	# the deck: planks across it on a dark frame, worn lighter down the middle where everyone walks
	var d0: float = -l + 8
	var d1: float = l - 8
	main.draw_rect(Rect2(d0, -w + 2, d1 - d0, 2 * w - 4), Color("3A2D21"))
	var wood = ["A47F4F", "967349", "8B6A43", "AB8A59", "9C7A4C"]
	var n: int = 0
	var x: float = d0 + 1
	while x < d1 - 1:
		var h: int = (n * 37 + 11) % 23
		var plank = Color(wood[h % wood.size()])
		if h == 0:
			plank = plank.darkened(0.2)
		var wd: float = minf(8, d1 - 1 - x)
		main.draw_rect(Rect2(x, -w + 4, wd, 2 * w - 8), plank)
		main.draw_line(Vector2(x, -w + 4), Vector2(x, w - 4), plank.lightened(0.18), 1)
		main.draw_rect(Rect2(x + 3, -w + 8, 2, 2), Color("3A3430"))
		main.draw_rect(Rect2(x + 3, w - 10, 2, 2), Color("3A3430"))
		if h % 7 == 3:
			main.draw_line(Vector2(x + 2, -6 + h), Vector2(x + 2, 4 + h), plank.darkened(0.25), 1)
		x += 9
		n += 1
	main.draw_rect(Rect2(d0, -16, d1 - d0, 32), Color(1, 1, 0.9, 0.06))
	# the two beams along its sides; the near one shows its face
	main.draw_rect(Rect2(d0 - 2, -w, d1 - d0 + 4, 6), Color("5C4630"))
	main.draw_line(Vector2(d0 - 2, -w), Vector2(d1 + 2, -w), Color("8C6C46"), 1)
	main.draw_rect(Rect2(d0 - 2, w - 6, d1 - d0 + 4, 6), Color("5C4630"))
	main.draw_rect(Rect2(d0 - 2, w, d1 - d0 + 4, 5), Color("3A2C1E"))
	# rails: posts with a top rail and a lower rail, the far side first
	for side in [-1, 1]:
		var base: float = -w + 2 if side < 0 else w - 2
		var top: float = base - 15
		var posts: int = 7
		for k in range(posts):
			x = Cs.round_even(lerpf(d0 + 6, d1 - 6, float(k) / (posts - 1)))
			var corner: bool = k == 0 or k == posts - 1
			var pw: float = 7 if corner else 5
			main.draw_rect(Rect2(x - pw / 2, top - (3 if corner else 0), pw, base - top + (3 if corner else 0)), Color("54412C"))
			main.draw_rect(Rect2(x - pw / 2, top - (3 if corner else 0), 1, base - top + (3 if corner else 0)), Color("8A6C47"))
			if corner:
				# a lantern on each corner post, glowing after dark
				main.draw_rect(Rect2(x - 3, top - 9, 6, 6), Color("2C2620"))
				main.draw_rect(Rect2(x - 2, top - 8, 4, 4), Color("F2C94C"))
				var glow: float = 0.12 + 0.04 * sin(clk * 3.0 + x)
				main.draw_circle(Vector2(x, top - 6), 9, Color(1.0, 0.82, 0.4, glow))
		main.draw_rect(Rect2(d0 + 4, top, d1 - d0 - 8, 4), Color("B08E5C"))
		main.draw_line(Vector2(d0 + 4, top), Vector2(d1 - 4, top), Color("D4B47C"), 1)
		main.draw_line(Vector2(d0 + 4, top + 4), Vector2(d1 - 4, top + 4), Color(0, 0, 0, 0.3), 1)
		main.draw_rect(Rect2(d0 + 4, top + 8, d1 - d0 - 8, 2), Color("8E7048"))
	main.draw_set_transform(Vector2.ZERO)

class RiverLook:
	var bank_mesh: RiverSurface
	var water_mesh: RiverSurface
	var glint_alpha: PackedFloat32Array = PackedFloat32Array()
	var path
	var box: Rect2 = Rect2()

class RiverSurface:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
