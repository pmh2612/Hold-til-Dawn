class_name WorldLandmarks
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldLandmarks.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.
const S_: float = IslandMap.SCALE

# constants shared with WorldGeometry
const LANDMARK_SCALE = WorldGeometry.LANDMARK_SCALE
const SAFE_D = WorldGeometry.SAFE_D
const TL = WorldGeometry.TL
const TRAIL_W = WorldGeometry.TRAIL_W

static func build_landmarks(world: WorldGeometry) -> void:
	world.lm_props.clear()
	world.compounds.clear()
	world.compound_entrances.clear()
	world.compound_boundaries.clear()
	world.compound_gates.clear()
	world.lm_ground.clear()
	world.floors.clear()
	world.steps.clear()
	world.coral.clear()
	world.lm_solids.clear()
	world.lm_clear.clear()
	IslandMap.docks.clear()
	world.lm_at.clear()
	world.expedition_sites.clear()
	world.expedition_vehicles.clear()
	world.expedition_cliffs.clear()
	world.lookouts.clear()
	world.lookout_objects.clear()
	world.lookout_rails.clear()
	world.lookout_placements.clear()
	world.reef_beds.clear()
	world.cape_gulls.clear()
	world.lm_at[1] = Vector2.ZERO
	var r = CsRandom.new(31)
	WorldHomeFarms.build_home_farm_landmarks(world)
	WorldExpeditionSites.build_bayside_scene(world)
	ruined_base(world, r)
	WorldExpeditionSites.build_convoy_scene(world)
	mangroves(world, r)
	WorldWeatherStation.build_weather_station(world)
	WorldLandmarkScale.build_expanded_site(world, 10, func(): pier(world))
	WorldExpeditionSites.build_northwind_scene(world)
	WorldLookouts.build_coral_lookout(world)
	container_yard(world)
	WorldLandmarkScale.build_expanded_site(world, 14, func(): shipwreck(world, r))
	pond_banks(world, r)
	cave(world)
	WorldLookouts.build_south_cape_lookout(world)
	herb_garden(world, r)
	WorldLandmarkDetails.dress_landmarks(world)
	WorldExploration.build_ramps(world)
	WorldExploration.dress_exploration(world)
	# Compound entrances join the existing trail network after their larger footprints have been placed.
	WorldLandmarkScale.connect_compounds(world)

static func tl(x: float, y: float) -> Vector2:
	return Vector2(x, y) * TL

static func prop(world: WorldGeometry, p: Vector2, sprite) -> void:
	world.lm_props.append([p, sprite])

static func solid(world: WorldGeometry, c: Vector2, radius: float) -> void:
	world.lm_solids.append([c, radius])

static func clear(world: WorldGeometry, c: Vector2, radius: float) -> void:
	world.lm_clear.append([c, radius])

static func in_clear(world: WorldGeometry, p: Vector2, margin: float) -> bool:
	for _it1 in world.lm_clear:
		var c = _it1[0]
		var rr = _it1[1]
		if p.distance_to(c) < rr + margin:
			return true
	return false

# room for a structure of this radius: on the grass, off the paths, the door lanes and the pads, clear of the
# other landmarks' structures
static func room(world: WorldGeometry, p: Vector2, radius: float, grass: float = 0.5) -> bool:
	return IslandMap.on_grass(p, radius * grass) and not WorldTerrain.near_path(world, p, radius) and not in_clear(world, p, radius) and not WorldGeometry.lane(p) and not WorldGeometry.near_pad(p) and float(WorldGeometry.wall_dist(p)) > float(SAFE_D) * 0.5

# the nearest spot to Want with room, searching out in rings of half a tile
static func spot(world: WorldGeometry, want: Vector2, radius: float, grass: float = 0.5, reach: float = 14) -> Vector2:
	if room(world, want, radius, grass):
		return want
	var ring: float = 0.5
	while ring <= reach:
		var n: int = maxi(8, int(ring * 8))
		for i in range(n):
			var p: Vector2 = want + Vector2.from_angle(i * TAU / n) * ring * TL
			if room(world, p, radius, grass):
				return p
		ring += 0.5
	return want

# the nearest point on any route or trail, and which way it runs there
static func on_path(world: WorldGeometry, p: Vector2) -> Variant:
	var best: float = INF
	var at_: Vector2 = p
	var along: Vector2 = Vector2.RIGHT
	for k in range(3, world.trails.size()):
		var path = world.trails[k][0]
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var ab: Vector2 = b - a
			var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
			var q: Vector2 = a + ab * t
			var d: float = p.distance_to(q)
			if d < best:
				best = d
				at_ = q
				along = ab.normalized()
	return [at_, along]

# a short footpath from a landmark's marker out to its structure
static func footpath(world: WorldGeometry, from: Vector2, to: Vector2) -> void:
	# not where a path already runs close by
	if from.distance_to(to) < 2 * TL or WorldTerrain.near_path(world, to, 1.5 * TL):
		return
	var pts = []
	var n: int = int(from.distance_to(to) / (0.5 * TL))
	var side = (to - from).normalized().orthogonal()
	for i in range(n + 1):
		var t: float = float(i) / n
		pts.append(from.lerp(to, t) + side * sin(t * PI) * 0.8 * TL)
	world.trails.append([Array(pts).duplicate(), TRAIL_W])

static func at(world: WorldGeometry, id: int) -> Vector2:
	var _v1 = (IslandMap.by_id(id).pos if IslandMap.by_id(id) != null else null)
	return _v1 if _v1 != null else Vector2.ZERO

# --- 02 Coconut Grove: palms round the grove, a fallen trunk and dry branches by the trail
static func in_grove(world: WorldGeometry, p: Vector2) -> bool:
	return p.distance_to(at(world, 2)) < 13 * TL

static func grove(world: WorldGeometry, r) -> void:
	var g: Vector2 = at(world, 2)
	var log_: Vector2 = spot(world, g + tl(1.5, 2), 1.4 * TL)
	prop(world, log_, "lm_log_0")
	world.lm_at[2] = log_
	clear(world, log_, 1.6 * TL)
	for i in range(3):
		var p: Vector2 = spot(world, log_ + Vector2.from_angle(i * 2.1 + 0.4) * 2.2 * TL, 0.5 * TL)
		prop(world, p, "lm_sticks_0")
		clear(world, p, 0.5 * TL)
	for i in range(12):
		var p: Vector2 = g + Vector2.from_angle(float(r.next_double()) * TAU) * (2.5 + float(r.next_double()) * 8.5) * TL
		if not room(world, p, 0.8 * TL):
			continue
		prop(world, p, "lm_palm_" + str(i % 4))
		clear(world, p, 0.7 * TL)

# --- 03 Limestone Flats: low pale shelves breaking through the grass
static func limestone_flats(world: WorldGeometry, r) -> void:
	var l: Vector2 = at(world, 3)
	for i in range(5):
		var p: Vector2 = spot(world, l + Vector2.from_angle(i * 1.26 + 0.3) * (3.0 + i % 2 * 3.0) * TL, 2.2 * TL, 0.5, 7)
		prop(world, p, "lm_shelf_" + str(i % 3))
		if i == 0:
			world.lm_at[3] = p
		clear(world, p, 2.4 * TL)

# --- 04 Herb Meadow: broad-leaf herbs along the trail
static func herb_meadow(world: WorldGeometry, r) -> void:
	var h: Vector2 = at(world, 4)
	var placed: int = 0
	var tries: int = 0
	while tries < 300 and placed < 12:
		var p: Vector2 = h + Vector2.from_angle(float(r.next_double()) * TAU) * float(r.next_double()) * 8 * TL
		var _d1 = on_path(world, p)
		var on = _d1[0]
		var d: float = p.distance_to(on)
		if d < 1.7 * TL or d > 3.2 * TL or not IslandMap.on_grass(p, TL) or in_clear(world, p, 0.6 * TL) or WorldGeometry.near_pad(p):
			tries += 1
			continue
		prop(world, p, "lm_broadleaf_" + str(placed % 2))
		if placed == 0:
			world.lm_at[4] = p
		clear(world, p, 0.6 * TL)
		placed += 1
		tries += 1

# --- 06 Ruined Base: a concrete floor, broken walls behind and to the left, shelves and crates, the mast
static func ruined_base(world: WorldGeometry, r) -> void:
	WorldCompounds.build_ruined_compound(world)

# --- 08 Mangrove Swamp: mangroves on their stilt roots round the pools
static func mangroves(world: WorldGeometry, r) -> void:
	var placed: int = 0
	var tries: int = 0
	while tries < 400 and placed < 12:
		var p: Vector2 = world.swamp_centre + Vector2.from_angle(float(r.next_double()) * TAU) * sqrt(float(r.next_double())) * world.swamp_r
		if not IslandMap.on_grass(p, 0.6 * TL) or (WorldTerrain.terrain_at(world, p, 0.8 * TL) == 1 or WorldTerrain.terrain_at(world, p, 0.8 * TL) == 5) or in_clear(world, p, 1.4 * TL):
			tries += 1
			continue
		prop(world, p, "lm_mangrove_" + str(placed % 3))
		if placed == 0:
			world.lm_at[8] = p
		clear(world, p, 1.0 * TL)
		placed += 1
		tries += 1

# --- 10 Old Fishing Pier: out to sea from the west shore, fish traps on the beach
static func pier(world: WorldGeometry) -> void:
	var m: Vector2 = at(world, 10)
	# walk west to the waterline
	var shore: Vector2 = m
	while IslandMap.on_land(shore) and shore.x > m.x - 40 * TL:
		shore.x -= 0.25 * TL
	var land: Vector2 = (shore + tl(2.2, 0)).round()
	world.lm_ground.append([land, "lm_pier_0"])
	world.lm_at[10] = land
	# the deck: 224 px out from the land end, 48 px across (tools/PixelLandmarks.cs)
	IslandMap.docks.append(Rect2(land + Vector2(-224, -24) * LANDMARK_SCALE, Vector2(226, 48) * LANDMARK_SCALE))
	prop(world, land + tl(1.0, 1.6), "lm_trap_0")
	prop(world, land + tl(1.9, -1.5), "lm_trap_1")
	prop(world, land + tl(2.6, 1.2), "lm_trap_0")
	clear(world, land + tl(1.5, 0), 2.5 * TL)
	footpath(world, m, land + tl(0.6, 0))
	WorldFishingPier.build_fishing_details(world, land)

# --- 13 Container Yard: a concrete yard, containers along the back, one open, drums and pallets
static func container_yard(world: WorldGeometry) -> void:
	WorldCompounds.build_container_compound(world)

# --- 14 Beached Shipwreck: on the sand, the bow in the shallows, machinery washed up round it
static func shipwreck(world: WorldGeometry, r) -> void:
	var m: Vector2 = at(world, 14)
	var best: Vector2 = m
	var best_score: float = -INF
	for y in range(-18, 19):
		for x in range(-18, 19):
			var p: Vector2 = m + tl(x, y)
			if p.distance_to(m) > 18 * TL:
				continue
			# the keel along the sand: on the beach or just in the water, not up on the grass
			var good: int = 0
			for k in range(-6, 7):
				var q: Vector2 = p + tl(k * 1.1, 0)
				var d: float = IslandMap.depth(q)
				if d > -3.5 * TL and IslandMap.grass_in(q) < 0.5 * TL:
					good += 1
				if d > 0.5 * TL and IslandMap.grass_in(q) < 0:
					good += 1
			var score: float = good - p.distance_to(m) / (6 * TL)
			if score > best_score:
				best_score = score
				best = p
	best = best.round()
	prop(world, best, "lm_ship_0")
	world.lm_at[14] = best
	var x: float = -6.4
	while x <= 6.6:
		var q: Vector2 = best + tl(x, -0.6)
		if IslandMap.on_land(q, -TL):
			solid(world, q, 1.1 * TL)
		x += 1.2
	clear(world, best + tl(0, -1.5), 7.5 * TL)
	for _it1 in [[-4.5, 1.8, "lm_gear_0"], [1.5, 2.0, "lm_drum_1"], [2.4, 2.6, "lm_drum_1"], [5.2, 1.6, "lm_gear_0"], [-1.8, 2.4, "lm_crate_0"]]:
		var dx = _it1[0]
		var dy = _it1[1]
		var name = _it1[2]
		var p: Vector2 = best + tl(dx, dy)
		if IslandMap.on_land(p, 0.5 * TL):
			prop(world, p, name)

# --- 15 Rainwater Pond: red ginger and broad leaves on the damp banks
static func pond_banks(world: WorldGeometry, r) -> void:
	if world.ponds.size() == 0:
		return
	var pd = world.ponds[0]
	world.lm_at[15] = pd.centre + Vector2(0, pd.radius * 1.4)
	for i in range(9):
		var p: Vector2 = pd.centre + Vector2.from_angle(i * TAU / 9 + 0.3) * pd.radius * Vector2(1.75, 1.45)
		if not IslandMap.on_grass(p, 0.5 * TL) or WorldTerrain.near_path(world, p, 0.3 * TL) or in_clear(world, p, 0.4 * TL):
			continue
		prop(world, p, "lm_broadleaf_1" if i % 3 == 0 else "lm_ginger_0")
		clear(world, p, 0.5 * TL)

# --- 16 Southwest Cave: the bluff over the mouth (the spires of WorldTerrain flank it)
static func cave(world: WorldGeometry) -> void:
	WorldCompounds.build_cave_compound(world)

# --- 18 Abandoned Herb Garden: raised beds in a broken fence, a watering can left behind
static func herb_garden(world: WorldGeometry, r) -> void:
	WorldHerbGarden.build_abandoned_garden(world)
