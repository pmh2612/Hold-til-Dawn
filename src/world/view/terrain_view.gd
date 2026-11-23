class_name TerrainView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.TerrainView.cs.
# Owner: Vu Duc Viet Anh. Draws the island of src/world/IslandMap.cs and the terrain of src/world/world_terrain.gd on
# the ground layer (under everything with height): the sea stepping up through the shallows, the beach with its
# wet edge and a line of surf, the grass (lighter in the safe zone), darker woodland floor, hills with contour
# contours, the Rainwater Pond and the Mangrove Swamp. Route surfaces are hidden. Same pixel-art palette
# as art/nature (tools/PixelNature.cs); light from the upper left.
const SEA: Color = Color("1F4257")
static var SHALLOW = [Color("27546A"), Color("2E6679"), Color("3B7E8A")]
const SAND: Color = Color("CDB688")
const WET_SAND: Color = Color("A99872")
const FOAM: Color = Color(0.92, 0.97, 1.0, 0.55)
const OUTER_GRASS: Color = Color("5B7434") * 1.1
const SAFE_GRASS: Color = Color("728C40") * 1.1
const WOOD_FLOOR: Color = Color("4C6530") * 1.1
const HILL_FOOT: Color = Color("6E8048")
const HILL_TOP: Color = Color("A49C7E")
const CONTOUR: Color = Color(0.93, 0.92, 0.8, 0.45)
const BANK: Color = Color("4A5638")
const WATER: Color = Color("3B6A86")
const DEEP: Color = Color("2F5A75")
const RIPPLE: Color = Color(0.62, 0.8, 0.88, 0.75)
const MUD: Color = Color("4F5233")
const MUD_DARK: Color = Color("3E4129")
# the coast pushed out a little, for the surf
var surf
var fills = {}
var ground_rid = RID()

# constants shared with Main
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

func fill_static(pts, col: Color, textured: bool = true) -> void:
	var f = fills.get(pts, null)
	if not fills.has(pts):
		f = Cs.init(Fill.new(), {"idx": Geometry2D.triangulate_polygon(pts), "uv": PackedVector2Array(Array(pts).map(func(p): return p / 256.0))})
		fills[pts] = f
	if f.idx.size() == 0:
		# not a simple polygon: leave it to Godot as before
		if textured:
			main.ground(pts, col)
		else:
			main.draw_colored_polygon(pts, col)
		return
	if textured and not ground_rid.is_valid():
		ground_rid = main.ground_tex.get_rid()
	RenderingServer.canvas_item_add_triangle_array(main.get_canvas_item(), f.idx, pts, [col], f.uv if textured else PackedVector2Array(), PackedInt32Array(), PackedFloat32Array(), ground_rid if textured else RID())

var safe_ring
var hill_ring = {}
var pond_look = {}

func bounds(pts, grow: float) -> Rect2:
	var r = Rect2(Vector2.INF, Vector2.ZERO)
	var first: bool = true
	for p in pts:
		if first:
			r = Rect2(p, Vector2.ZERO)
			first = false
		else:
			r = r.expand(p)
	return r.grow(grow)

static func closed(poly) -> Variant:
	var out = Cs.arr(poly.size() + 1, Vector2.ZERO)
	Cs.copy_to(poly, out, 0)
	out[-1] = poly[0]
	return out

# sea, beach and grass; called first on the ground layer
func draw_island(view: Rect2) -> void:
	var tl: float = float(T)
	var clk: float = float(main.clock)
	main.draw_rect(view.grow(4 * tl), SEA)
	for i in range(IslandMap.shallows.size() - 1, -1, -1):
		fill_static(IslandMap.shallows[i], SHALLOW[mini(SHALLOW.size() - 1, IslandMap.shallows.size() - 1 - i)], false)
	# surf rolling in and out over the wet sand
	if surf == null:
		var c = IslandMap.coast
		surf = Cs.arr(c.size(), Vector2.ZERO)
		for i in range(c.size()):
			var along: Vector2 = (c[(i + 1) % c.size()] - c[(i + c.size() - 1) % c.size()]).normalized()
			var n: Vector2 = Vector2(-along.y, along.x)
			if IslandMap.depth(c[i] + n * 8) > IslandMap.depth(c[i]):
				n = -n
			surf[i] = c[i] + n * 0.35 * tl
	fill_static(IslandMap.coast, SAND)
	main.draw_polyline(closed(IslandMap.coast), WET_SAND, 10)
	var wave: float = 0.5 + 0.5 * sin(clk * 0.9)
	var foam = FOAM
	foam.a *= 0.5 + 0.5 * wave
	var rolled = Cs.arr(surf.size() + 1, Vector2.ZERO)
	for i in range(surf.size()):
		rolled[i] = IslandMap.coast[i].lerp(surf[i], 0.3 + 0.7 * wave)
	rolled[-1] = rolled[0]
	main.draw_polyline(rolled, foam, 2)
	# grass, darker past the safe zone and under the woods
	fill_static(IslandMap.grass, OUTER_GRASS)
	for wd in IslandMap.shade:
		if bounds(wd, tl).intersects(view):
			fill_static(wd, WOOD_FLOOR)
	if safe_ring == null:
		var ring = []
		for p in main.round_rect(GameSim.HALF, GameSim.SAFE_D):
			ring.append(Vector2(p))
		safe_ring = Array(ring).duplicate()
	fill_static(safe_ring, SAFE_GRASS)
	main.draw_polyline(closed(safe_ring), Color(1, 1, 0.8, 0.12), 2)
	for h in IslandMap.hills:
		if h.rings.size() > 0 and bounds(h.rings[0], tl).intersects(view):
			draw_hill(h)

# stepped rings from the foot to the top, each lighter, a pale contour line round each and a shade line on
# the side away from the light
func draw_hill(h) -> void:
	var n: int = h.rings.size()
	for i in range(n):
		var k: float = 1 if n <= 1 else float(i) / (n - 1)
		fill_static(h.rings[i], HILL_FOOT.lerp(HILL_TOP, k) * 1.08)
		var look = hill_ring.get(h.rings[i], null)
		if not hill_ring.has(h.rings[i]):
			var ring = closed(h.rings[i])
			var low = Cs.arr(ring.size(), Vector2.ZERO)
			for j in range(ring.size()):
				low[j] = ring[j] + Vector2(1.5, 2.5)
			look = [ring, low]
			hill_ring[h.rings[i]] = look
		main.draw_polyline(look[1], Color(0.1, 0.12, 0.08, 0.22), 2)
		main.draw_polyline(look[0], CONTOUR, 1)

func draw_terrain(view: Rect2) -> void:
	var w = main.geometry
	var tl: float = float(T)
	# the Mangrove Swamp's mud, under the paths through it
	if Rect2(w.swamp_centre - Vector2.ONE * w.swamp_r, Vector2.ONE * 2 * w.swamp_r).intersects(view):
		draw_swamp(w)
	# Route data still reserves clear walking corridors; their yellow surface is no longer rendered.
	main.landmark_details.draw_landmark_soils(w, view)
	# Rivers and their functional crossing bridges remain visible.
	main.rivers.draw_rivers(view)
	# the landmarks' floors, the pier, the platform and coral (src/world/view/landmark_view.gd)
	main.landmark_view.draw_landmark_ground(w, view)
	for i in range(w.ponds.size()):
		if bounds(w.ponds[i].edge, tl * 2).intersects(view):
			draw_pond(w.ponds[i], i == 0)
	main.landmark_details.draw_landmark_life(w, view, float(main.clock))

var swamp_edge
var swamp_wet

# mud inside the grass (the swamp runs down to the beach of the Mangrove Inlet), darker wet patches in it
func draw_swamp(w) -> void:
	var tl: float = float(T)
	if swamp_edge == null:
		var n: int = 48
		swamp_edge = Cs.arr(n, Vector2.ZERO)
		for i in range(n):
			var a_: float = i * TAU / n
			var wob: float = 0.82 + 0.1 * sin(3 * a_ + 1.3) + 0.06 * sin(7 * a_ + 0.4)
			var p: Vector2 = w.swamp_centre + Vector2.from_angle(a_) * w.swamp_r * wob
			while not IslandMap.on_grass(p, 0.6 * tl) and p.distance_to(w.swamp_centre) > tl:
				p = p.move_toward(w.swamp_centre, 0.25 * tl)
			swamp_edge[i] = p
		swamp_wet = []
		for k in range(14):
			var c: Vector2 = w.swamp_centre + Vector2.from_angle(k * 2.4) * w.swamp_r * (0.12 + 0.055 * k)
			var size: float = 0.7 + 0.25 * (k % 3)
			if not IslandMap.on_grass(c, (size + 1.0) * tl):
				continue
			var blob_ = Cs.arr(12, Vector2.ZERO)
			for i in range(12):
				blob_[i] = c + Vector2.from_angle(i * TAU / 12) * tl * size * (1.0 + 0.3 * sin(i * 1.7 + k)) * Vector2(1.4, 0.8)
			swamp_wet.append(blob_)
	fill_static(swamp_edge, MUD * 1.2)
	for blob_ in swamp_wet:
		fill_static(blob_, MUD_DARK * 1.1)
		# a glint of standing water
		var c: Vector2 = (blob_[0] + blob_[6]) / 2
		main.draw_line((c + Vector2(-4, -2)).round(), (c + Vector2(3, -2)).round(), Color(0.6, 0.75, 0.7, 0.35), 1)

static func offset(path, by: float) -> Variant:
	var out = Cs.arr(path.size(), Vector2.ZERO)
	for i in range(path.size()):
		var along: Vector2 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		out[i] = path[i] + Vector2(-along.y, along.x) * by
	return out

func draw_pond(pd, lilies: bool = false) -> void:
	var clk: float = float(main.clock)
	var edge = pd.edge
	var look = pond_look.get(edge, null)
	if not pond_look.has(edge):
		look = [edge.map(func(p): return pd.centre + (p - pd.centre) * 1.0 + (p - pd.centre).normalized() * 4), edge.map(func(p): return pd.centre + (p - pd.centre) * 0.55), closed(edge)]
		pond_look[edge] = look
	fill_static(look[0], BANK, false)
	fill_static(edge, WATER, false)
	fill_static(look[1], DEEP, false)
	main.draw_polyline(look[2], Color(0.04, 0.08, 0.1, 0.35), 1)
	# ripples
	for k in range(5):
		var a_: float = k * 1.3 + clk * 0.25
		var p: Vector2 = pd.centre + Vector2.from_angle(a_) * pd.radius * (0.35 + 0.12 * k)
		var col = RIPPLE
		col.a *= 0.5 + 0.5 * sin(clk * 1.5 + k)
		main.draw_line(p.round(), (p + Vector2(4, 0)).round(), col, 1)
	# lily pads on the Rainwater Pond
	if lilies:
		main.landmark_view.draw_lilies(pd)

class Fill:
	var idx
	var uv
