class_name IslandMap
extends RefCounted

# ---- src/world/IslandMap.cs
# Owner: Vu Duc Viet Anh. The island from the level-design map (maps/island_map.json, made from the PDF by
# tools/island_from_pdf.py): its coast with 4-6 tile beaches, the shallows, hills, woods, the three main gathering
# routes and the exploration trails, and the 18 landmarks. Positions in the file are tiles from the outpost
# centre; here they are pixels, scaled up by SCALE. Shared by every peer (no rendering): the sea and the two rivers
# (src/world/IslandRivers.cs) stop everyone, and scenery,
# nodes and spawns are placed from it.
const TL: float = 32.0
# The island is drawn 1.5 times the size of the design map, round the outpost (which keeps its size, as do the
# safe zone, the door pads, the night spawn bands and the boss distance in GameSim).
const SCALE: float = 1.5
# how far the depth grid reaches each way, in tiles, and its step
const REACH: int = 126
const STEP: float = 1.0
static var coast = null
static var grass = null
static var shallows = []
static var shade = []
static var routes = []
static var trails = []
static var hills = []
static var trees = []
static var landmarks = []
static var bays = []
# walkable decks out over the water (the Old Fishing Pier, src/world/world_landmarks.gd)
static var docks = []
# the island's box, in pixels
static var box: Rect2 = Rect2()
static var coast_depth = null
static var grass_depth = null
static var N: int = 0

static func _static_init():
	var root = JSON.parse_string(FileAccess.get_file_as_string("res://maps/island_map.json"))
	coast = poly(root["coast"])
	grass = poly(root["grass"])
	for p in root["shallows"]:
		shallows.append(poly(p))
	for p in root["shade"]:
		shade.append(poly(p))
	for p in root["routes"]:
		routes.append(smooth(poly(p)))
	for p in root["trails"]:
		trails.append(smooth(poly(p)))
	for h in root["hills"]:
		var d = h
		var hl = Cs.init(Hill.new(), {"top": pt(d["top"])})
		for r in d["rings"]:
			hl.rings.append(poly(r))
		hills.append(hl)
	for p in root["trees"]:
		trees.append(pt(p))
	for l in root["landmarks"]:
		var d = l
		landmarks.append(Cs.init(Landmark.new(), {"id": int(d["id"]), "name": str(d["name"]), "what": str(d["what"]), "kind": str(d["kind"]), "pos": pt(d["pos"])}))
	for b in root["bays"]:
		var d = b
		bays.append([str(d["name"]), pt(d["pos"])])
	box = Rect2(coast[0], Vector2.ZERO)
	for p in coast:
		box = box.expand(p)
	# signed distance to the coast and to the edge of the grass, one sample per tile
	N = int(2 * REACH / STEP) + 1
	coast_depth = depth_grid(coast)
	grass_depth = depth_grid(grass)
	# the two rivers and their bridges (src/world/IslandRivers.cs)
	build_rivers()

static func pt(v) -> Vector2:
	var a = v
	return Vector2(float(a[0]), float(a[1])) * TL * SCALE

static func poly(v) -> Variant:
	var a = v
	var out = Cs.arr(a.size(), Vector2.ZERO)
	for i in range(a.size()):
		out[i] = pt(a[i])
	return out

# Catmull-Rom through the points, one every half tile
static func smooth(ctrl) -> Variant:
	if ctrl.size() < 3:
		return ctrl
	var pts = []
	var i: int = 0
	while i < ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(0, i - 1)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(ctrl.size() - 1, i + 2)]
		var steps: int = maxi(1, int(p1.distance_to(p2) / (0.5 * TL)))
		for s in range(steps):
			var t: float = float(s) / steps
			pts.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
		i += 1
	pts.append(ctrl[-1])
	return Array(pts).duplicate()

static func in_polygon(poly_, p: Vector2) -> bool:
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

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
	return p.distance_to(a + ab * t)

static func path_dist(p: Vector2, path, closed: bool = false) -> float:
	var best: float = INF
	for i in range(path.size() - 1):
		best = minf(best, seg_dist(p, path[i], path[i + 1]))
	if closed:
		best = minf(best, seg_dist(p, path[-1], path[0]))
	return best

static func depth_grid(poly_) -> Variant:
	var g = Cs.arr(N * N, 0.0)
	for y in range(N):
		for x in range(N):
			var p = Vector2((x * STEP - REACH) * TL, (y * STEP - REACH) * TL)
			var d: float = path_dist(p, poly_, true)
			g[y * N + x] = d if in_polygon(poly_, p) else -d
	return g

static func sample(g, p: Vector2) -> float:
	var fx: float = (p.x / TL + REACH) / STEP
	var fy: float = (p.y / TL + REACH) / STEP
	if fx < 0 or fy < 0 or fx >= N - 1 or fy >= N - 1:
		return -REACH * TL
	var x: int = int(fx)
	var y: int = int(fy)
	var tx: float = fx - x
	var ty: float = fy - y
	var a: float = lerpf(g[y * N + x], g[y * N + x + 1], tx)
	var b: float = lerpf(g[(y + 1) * N + x], g[(y + 1) * N + x + 1], tx)
	return lerpf(a, b, ty)

# pixels inland from the waterline (negative out at sea)
static func depth(p: Vector2) -> float:
	return sample(coast_depth, p)

# the rivers are water like the sea: only their bridges cross them (src/world/IslandRivers.cs)
static func on_land(p: Vector2, margin: float = 0) -> bool:
	return depth(p) >= margin and not in_river(p, margin) or on_dock(p, margin) or on_bridge(p, margin)

static func on_dock(p: Vector2, margin: float) -> bool:
	for d in docks:
		if Cs.has_point(d.grow(-maxf(margin, 0)), p):
			return true
	return false

# grass stops at the rivers' banks too
static func on_grass(p: Vector2, margin: float = 0) -> bool:
	return sample(grass_depth, p) >= margin and not in_river(p, RIVER_BANK + margin)

# pixels in from the edge of the grass (negative on the beach and at sea)
static func grass_in(p: Vector2) -> float:
	return sample(grass_depth, p)

# the nearest point at least Margin inland, walking in toward the outpost
static func pull_inland(p: Vector2, margin: float) -> Vector2:
	if on_land(p, margin):
		return p
	var dir: Vector2 = (-p).normalized()
	var i: int = 0
	while i < 400 and not on_land(p, margin):
		if p.length() < TL:
			break
		p += dir * (0.25 * TL)
		i += 1
	return p

# A body of this radius moving From -> To stays out of the sea: it slides along the coast.
static func keep(from: Vector2, to: Vector2, radius: float) -> Vector2:
	if on_land(to, radius):
		return to
	var sx = Vector2(to.x, from.y)
	var sy = Vector2(from.x, to.y)
	var ox: bool = on_land(sx, radius)
	var oy: bool = on_land(sy, radius)
	if ox and oy:
		return sx if depth(sx) >= depth(sy) else sy
	if ox:
		return sx
	if oy:
		return sy
	return from if on_land(from, radius) else pull_inland(from, radius)

# the landmark whose area this is (within Reach of its marker), or null
static func near(p: Vector2, reach: float) -> Variant:
	var best = null
	var bd: float = reach
	for l in landmarks:
		var d: float = l.pos.distance_to(p)
		if d < bd:
			bd = d
			best = l
	return best

static func by_id(id: int) -> Variant:
	return Cs.first_or_default(landmarks, func(l): return l.id == id)

# ---- src/world/IslandRivers.cs
# Owner: Vu Duc Viet Anh. The island's two rivers, one in the west and one in the east, each running from the
# north coast to the south coast, with bridges joining the exploration routes. The water stops everyone like the sea does
# (IslandMap.OnLand): players, enemies, bosses and bots cross only on a bridge, and the bots' and enemies' route
# grids mark the water solid the same way they mark the sea. Grass, trees, rocks and landmarks keep off the
# water and its muddy banks (IslandMap.OnGrass). Each river runs straight north-south under its bridges, so the
# decks are plain east-west boxes. Drawn by src/world/view/rivers.gd.
# half the width of the water, and the muddy bank on each side
const RIVER_HALF: float = 2.2 * TL
const RIVER_BANK: float = 0.9 * TL
# a bridge's deck: across the water and onto both banks, a little over three tiles wide
const BRIDGE_HALF_LEN: float = RIVER_HALF + RIVER_BANK + 1.2 * TL
const BRIDGE_HALF_W: float = 1.6 * TL
const BRIDGE_RAIL_RADIUS: float = 8
const BRIDGE_RAIL_OFFSET: float = BRIDGE_HALF_W - 2
# the course of each river in tiles from the outpost, north to south, from the sea to the sea
static var RIVER_COURSE = [[Vector2(-36, -118), Vector2(-34, -95), Vector2(-34, -75), Vector2(-36, -55), Vector2(-35, -35), Vector2(-38, -15), Vector2(-47, 15), Vector2(-51, 35), Vector2(-50, 75), Vector2(-43, 95), Vector2(-46, 118)], [Vector2(26, -118), Vector2(25.5, -95), Vector2(25.5, -75), Vector2(27, -55), Vector2(48.5, -15), Vector2(52.5, 15), Vector2(41, 35), Vector2(34.5, 55), Vector2(36.5, 75), Vector2(39.5, 95), Vector2(36, 118)]]
# the bridges in tiles: [river, centre]; the river runs straight north-south through each
static var BRIDGE_SPOTS = [[0, Vector2(-43, 0)], [0, Vector2(-55, 55)], [0, Vector2(-36, -52)], [1, Vector2(51, 0)], [1, Vector2(38, -36)]]
# centre lines (pixels, a point every half tile) and bridge centres (pixels)
static var rivers = []
static var bridges = []
# distance to the nearest river's centre line, sampled every half tile
const RSTEP: float = 0.5
static var RN: int = 0
static var river_grid = null

static func build_rivers() -> void:
	rivers.clear()
	bridges.clear()
	var k: int = 0
	while k < RIVER_COURSE.size():
		var ctrl = Array(RIVER_COURSE[k]).duplicate()
		for _it1 in BRIDGE_SPOTS:
			var river = _it1[0]
			var at = _it1[1]
			if river != k:
				continue
			# straight north-south for a stretch either side of the deck
			Cs.remove_all(ctrl, func(c): return absf(c.y - at.y) < 9)
			ctrl.append(at + Vector2(0, -5))
			ctrl.append(at)
			ctrl.append(at + Vector2(0, 5))
			bridges.append([k, at * TL])
		Cs.sort_cmp(ctrl, func(a, b): return Cs.compare(a.y, b.y))
		rivers.append(smooth(Array(ctrl.map(func(c): return c * TL)).duplicate()))
		k += 1
	RN = int(2 * REACH / RSTEP) + 1
	river_grid = Cs.arr(RN * RN, 0.0)
	river_grid.fill(1e6)
	var reach: float = RIVER_HALF + RIVER_BANK + 8 * TL
	for path in rivers:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var x0: int = maxi(0, int((minf(a.x, b.x) - reach) / TL / RSTEP + REACH / RSTEP))
			var x1: int = mini(RN - 1, int((maxf(a.x, b.x) + reach) / TL / RSTEP + REACH / RSTEP) + 1)
			var y0: int = maxi(0, int((minf(a.y, b.y) - reach) / TL / RSTEP + REACH / RSTEP))
			var y1: int = mini(RN - 1, int((maxf(a.y, b.y) + reach) / TL / RSTEP + REACH / RSTEP) + 1)
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var p = Vector2((x * RSTEP - REACH) * TL, (y * RSTEP - REACH) * TL)
					var d: float = seg_dist(p, a, b)
					if d < river_grid[y * RN + x]:
						river_grid[y * RN + x] = d

# pixels from P to the middle of the nearest river
static func river_dist(p: Vector2) -> float:
	if river_grid == null:
		return 1e6
	var fx: float = (p.x / TL + REACH) / RSTEP
	var fy: float = (p.y / TL + REACH) / RSTEP
	if fx < 0 or fy < 0 or fx >= RN - 1 or fy >= RN - 1:
		return 1e6
	var x: int = int(fx)
	var y: int = int(fy)
	var tx: float = fx - x
	var ty: float = fy - y
	var a: float = lerpf(river_grid[y * RN + x], river_grid[y * RN + x + 1], tx)
	var b: float = lerpf(river_grid[(y + 1) * RN + x], river_grid[(y + 1) * RN + x + 1], tx)
	return lerpf(a, b, ty)

# in the water, or within Margin of it
static func in_river(p: Vector2, margin: float = 0) -> bool:
	return river_dist(p) < RIVER_HALF + margin

# a bridge's deck, east-west across its river
static func bridge_deck(i: int) -> Rect2:
	return Rect2(bridges[i][1] - Vector2(BRIDGE_HALF_LEN, BRIDGE_HALF_W), Vector2(2 * BRIDGE_HALF_LEN, 2 * BRIDGE_HALF_W))

# on a deck with Margin to spare on its sides (its ends run onto the banks)
static func on_bridge(p: Vector2, margin: float = 0) -> bool:
	for _it1 in bridges:
		var at = _it1[1]
		if absf(p.x - at.x) <= BRIDGE_HALF_LEN and absf(p.y - at.y) <= BRIDGE_RAIL_OFFSET - BRIDGE_RAIL_RADIUS - maxf(margin, 0):
			return true
	return false

# within Reach of any bridge's deck
static func near_bridge(p: Vector2, reach: float = 0) -> bool:
	for i in range(bridges.size()):
		if Cs.has_point(bridge_deck(i).grow(reach), p):
			return true
	return false

# Reserve the full-width landing lane on both banks, including space for the largest enemy body.
static func in_bridge_approach(p: Vector2, margin: float = 0) -> bool:
	for _it1 in bridges:
		var at = _it1[1]
		if absf(p.x - at.x) <= BRIDGE_HALF_LEN + 3 * TL + margin and absf(p.y - at.y) <= BRIDGE_HALF_W + margin:
			return true
	return false

class Landmark:
	var id: int = 0
	var name
	var what
	var kind
	var pos: Vector2 = Vector2.ZERO

class Hill:
	var top: Vector2 = Vector2.ZERO
	var rings = []  # foot first, top last
