class_name WorldTerrain
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldTerrain.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.
const ROUTE_W: float = 2.2 * TL  # main gathering routes and the door roads
# sizes round the landmarks grow with the island
const S: float = IslandMap.SCALE

# constants shared with WorldGeometry
const LANDMARK_SCALE = WorldGeometry.LANDMARK_SCALE
const TL = WorldGeometry.TL
const TRAIL_W = WorldGeometry.TRAIL_W

static func tiles(x: float, y: float) -> Vector2:
	return Vector2(x, y) * TL

static func build_terrain(world: WorldGeometry) -> void:
	world.ponds.clear()
	world.trails.clear()
	world.crags.clear()
	var r = CsRandom.new(23)
	# dirt roads out along the door axes to where the bosses land (the cross on the design map)
	for i in range(3):
		var door: Vector2 = Vector2(GameSim.DOOR_POS[i])
		var dir: Vector2 = Vector2(GameSim.DOOR_DIR[i])
		var side = Vector2(-dir.y, dir.x)
		var pts = []
		var d: float = 1.5
		while d <= 60:
			var p: Vector2 = door + dir * d * TL + side * sin(d * 0.23 + i) * 0.45 * TL
			# the road crosses a river on its bridge
			if not IslandMap.on_grass(p, TL) and not IslandMap.near_bridge(p, TL):
				break
			pts.append(p)
			d += 0.5
		world.trails.append([Array(pts).duplicate(), ROUTE_W])
	for rt in IslandMap.routes:
		world.trails.append([rt, ROUTE_W])
	for tr in IslandMap.trails:
		world.trails.append([tr, TRAIL_W])
	# paths cut by a river turn along its bank to a bridge (src/world/world_rivers.gd)
	WorldRivers.cut_paths_at_rivers(world)
	# the Rainwater Pond, just off the trail at landmark 15
	var rain = IslandMap.by_id(15)
	if rain != null:
		world.ponds.append(make_pond(r, rain.pos + tiles(4.2, 0.8) * S, 2.8 * 1.25 * LANDMARK_SCALE))
	# the Mangrove Swamp: muddy ground with small pools, kept off the paths
	var swamp = IslandMap.by_id(8)
	if swamp != null:
		# the swamp lies round its marker, on the grass back from the inlet's beach
		var best: float = -INF
		var look: int = int(8 * S)
		for dy in range(-look, look + 1):
			for dx in range(-look, look + 1):
				var p: Vector2 = swamp.pos + tiles(dx, dy)
				var score: float = minf(IslandMap.grass_in(p), 7 * S * TL) - 0.35 * p.distance_to(swamp.pos)
				if score > best:
					best = score
					world.swamp_centre = p
		world.swamp_r = clampf(IslandMap.grass_in(world.swamp_centre) - TL, 3 * TL, 7 * S * TL * LANDMARK_SCALE)
	if swamp != null:
		var i: int = 0
		var tries: int = 0
		while i < 9 and tries < 300:
			var c: Vector2 = world.swamp_centre + Vector2.from_angle(float(r.next_double()) * TAU) * float(r.next_double()) * (world.swamp_r - 2 * TL)
			var rad: float = 1.1 + float(r.next_double()) * 1.0
			if not IslandMap.on_grass(c, (rad + 1.5) * TL) or near_path(world, c, (rad + 1.6) * TL):
				tries += 1
				continue
			var clear_: bool = true
			for pd in world.ponds:
				if pd.centre.distance_to(c) < pd.radius + (rad + 1.5) * TL:
					clear_ = false
			if not clear_:
				tries += 1
				continue
			world.ponds.append(make_pond(r, c, rad))
			i += 1
			tries += 1
	# Southwest Cave now owns its walkable chamber and rock perimeter (src/world/world_cave.gd).

static func make_pond(r, centre: Vector2, radius_tiles: float) -> Variant:
	var n: int = 22
	var b = Cs.arr(3, 0.0)
	for i in range(b.size()):
		b[i] = float(r.next_double()) * TAU
	var edge = Cs.arr(n, Vector2.ZERO)
	for i in range(n):
		var a: float = i * TAU / n
		var wob: float = 1.0 + 0.12 * sin(2 * a + b[0]) + 0.07 * sin(3 * a + b[1]) + 0.04 * sin(5 * a + b[2])
		# a little wider than tall, like the rest of the 3/4 view
		edge[i] = centre + Vector2(cos(a) * 1.15, sin(a) * 0.85) * radius_tiles * TL * wob
	return Cs.init(Pond.new(), {"centre": centre, "edge": edge, "radius": radius_tiles * TL * 0.8})

static func near_path(world: WorldGeometry, p: Vector2, reach: float) -> bool:
	for _it1 in world.trails:
		var path = _it1[0]
		var width = _it1[1]
		if IslandMap.path_dist(p, path) < reach + width / 2:
			return true
	return false

# --- queries ----------------------------------------------------------------
# What lies at P: 0 grass, 1 water (pond or pool), 4 hill, 5 path, 6 built floor, 7 beach, 8 sea, 9 swamp mud.
# Used for the minimap and to keep trees, grass and reeds where they belong.
static func terrain_at(world: WorldGeometry, p: Vector2, margin: float = 0) -> int:
	if not IslandMap.on_land(p):
		return 8
	for _it1 in world.floors:
		var f = _it1[0]
		if Cs.has_point(f.grow(margin), p):
			return 6
	# a bridge's deck is a path; the rivers' muddy banks count as beach
	if IslandMap.near_bridge(p, margin) and IslandMap.in_river(p, IslandMap.RIVER_BANK + margin):
		return 5
	if not IslandMap.on_grass(p, margin):
		return 7
	for pd in world.ponds:
		if p.distance_to(pd.centre) < pd.radius * 1.6 + margin and IslandMap.in_polygon(pd.edge, p):
			return 1
	for _it2 in world.trails:
		var path = _it2[0]
		var width = _it2[1]
		if IslandMap.path_dist(p, path) < width / 2 + margin:
			return 5
	if p.distance_to(world.swamp_centre) < world.swamp_r:
		return 9
	for h in IslandMap.hills:
		if h.rings.size() > 0 and p.distance_to(h.top) < 14 * S * TL and IslandMap.in_polygon(h.rings[0], p):
			return 4
	return 0

# True where scenery (trees, rocks, grass tufts) must not be placed.
static func terrain_blocked(world: WorldGeometry, p: Vector2, margin: float) -> bool:
	if WorldCave.in_cave_region(world, p, margin):
		return true
	if IslandMap.in_bridge_approach(p, margin):
		return true
	var k: int = terrain_at(world, p, margin)
	if k != 0 and k != 4 and k != 9:
		return true
	for c in world.crags:
		if p.distance_to(c) < TL + margin:
			return true
	return WorldLandmarks.in_clear(world, p, margin)

# Solid circles: ponds and pools. Crags are added with the other scenery from their sprites' radius.
static func add_terrain_solids(world: WorldGeometry, into) -> void:
	# three circles across each (they are wider than tall)
	for pd in world.ponds:
		for k in [-0.45, 0.0, 0.45]:
			into.append([pd.centre + Vector2(k * pd.radius, 0), pd.radius * 0.85, false])
	# the landmarks' big structures (src/world/world_landmarks.gd)
	for _it1 in world.lm_solids:
		var c = _it1[0]
		var rr = _it1[1]
		into.append([c, rr, true])
	# Continuous rail colliders include the dry abutments: land checks alone cannot stop side entry there.
	for _it2 in IslandMap.bridges:
		var at_ = _it2[1]
		for side in [-1, 1]:
			var reach: float = IslandMap.BRIDGE_HALF_LEN - 10
			var steps_: int = int(ceilf(reach * 2 / (IslandMap.BRIDGE_RAIL_RADIUS * 1.4)))
			for i in range(steps_ + 1):
				into.append([at_ + Vector2(lerpf(-reach, reach, i / float(steps_)), side * IslandMap.BRIDGE_RAIL_OFFSET), IslandMap.BRIDGE_RAIL_RADIUS, false])

class Pond:
	var centre: Vector2 = Vector2.ZERO
	var edge  # closed outline
	var radius: float = 0.0  # a little inside the outline, for collision
