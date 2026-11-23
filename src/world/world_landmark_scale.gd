class_name WorldLandmarkScale
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldLandmarkScale.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.
const LANDMARK_AREA_SCALE: float = 1.5

# constants shared with WorldGeometry
const LANDMARK_SCALE = WorldGeometry.LANDMARK_SCALE
const TL = WorldGeometry.TL

static func build_expanded_site(world: WorldGeometry, id: int, build) -> void:
	var props: int = world.lm_props.size()
	var solids_: int = world.lm_solids.size()
	var clears: int = world.lm_clear.size()
	var step_start: int = world.steps.size()
	var reef_start: int = world.coral.size()
	build.call()
	var centre = world.lm_at.get(id, Vector2.ZERO)
	if not world.lm_at.has(id):
		return
	var old = world.lm_props.slice(props, props + (world.lm_props.size() - props))
	var shifts = Cs.arr(old.size(), Vector2.ZERO)
	for i in range(old.size()):
		var _d1 = old[i]
		var p = _d1[0]
		var sprite = _d1[1]
		var new: Vector2 = centre + (p - centre) * LANDMARK_SCALE
		# Coastal and river-bank sites grow inland; never push a prop into water or onto a trail.
		if not IslandMap.on_land(new, 12) or IslandMap.in_river(new, 12) or WorldTerrain.near_path(world, new, 16):
			new = p
		shifts[i] = new - p
		world.lm_props[props + i] = [new.round(), sprite]
	for i in range(solids_, world.lm_solids.size()):
		var _d2 = world.lm_solids[i]
		var p = _d2[0]
		var radius = _d2[1]
		world.lm_solids[i] = [p + _build_expanded_site_shift_for(world, p, old, shifts), radius]
	for i in range(clears, world.lm_clear.size()):
		var _d3 = world.lm_clear[i]
		var p = _d3[0]
		var radius = _d3[1]
		world.lm_clear[i] = [p + _build_expanded_site_shift_for(world, p, old, shifts), radius * LANDMARK_SCALE if radius > 2.8 * TL else radius]
	for i in range(step_start, world.steps.size()):
		var _d4 = world.steps[i]
		var p = _d4[0]
		var across = _d4[1]
		world.steps[i] = [centre + (p - centre) * LANDMARK_SCALE, across]
	for i in range(reef_start, world.coral.size()):
		var p: Vector2 = centre + (world.coral[i] - centre) * LANDMARK_SCALE
		if not IslandMap.on_land(p):
			world.coral[i] = p

# local function ShiftFor of the method above
static func _build_expanded_site_shift_for(world: WorldGeometry, p: Vector2, old, shifts) -> Vector2:
	var nearest: int = -1
	var best: float = 3.4028235e38
	for i in range(old.size()):
		var d: float = p.distance_squared_to(old[i][0])
		if d < best:
			nearest = i
			best = d
	return Vector2.ZERO if nearest < 0 else shifts[nearest]

# Find room for the entire compound, not just its centre. Keep all corners and walls on dry ground.
static func compound_spot(world: WorldGeometry, id: int, half: Vector2) -> Vector2:
	var want: Vector2 = WorldLandmarks.at(world, id)
	var best: Vector2 = want
	var score: float = INF
	for y in range(-18, 19):
		for x in range(-18, 19):
			var p: Vector2 = want + WorldLandmarks.tl(x * 0.5, y * 0.5)
			var cost: float = p.distance_squared_to(want)
			if cost >= score or IslandMap.in_river(p, 6 * TL):
				continue
			var fits: bool = true
			var dy: int = -1
			while dy <= 1 and fits:
				for dx in range(-1, 2):
					var q: Vector2 = p + Vector2(half.x * dx, half.y * dy)
					if not IslandMap.on_land(q, 20) or IslandMap.in_river(q, IslandMap.RIVER_BANK + 20) or WorldGeometry.near_pad(q) or WorldLandmarks.in_clear(world, q, 16):
						fits = false
						break
				dy += 1
			# The rear wall and the west return must not occupy an existing route.
			if fits and (WorldTerrain.near_path(world, p + Vector2(0, -half.y + 14), half.x * 0.45) or WorldTerrain.near_path(world, p + Vector2(-half.x + 12, 0), half.y * 0.45)):
				cost += 200 * TL * TL
			if fits and cost < score:
				score = cost
				best = p
	if is_inf(score):
		Cs.fail("No dry footprint for landmark %s" % [id])
		return Vector2.ZERO
	return best.round()

static func compound_line(world: WorldGeometry, a: Vector2, b: Vector2, radius: float) -> void:
	var n: int = maxi(1, int(ceilf(a.distance_to(b) / (radius * 1.45))))
	for i in range(n + 1):
		WorldLandmarks.solid(world, a.lerp(b, float(i) / n), radius)

static func connect_compounds(world: WorldGeometry) -> void:
	for _unused in world.compound_entrances:
		var entry = world.compound_entrances[_unused]
		var _d1 = WorldLandmarks.on_path(world, entry)
		var road = _d1[0]
		WorldLandmarks.footpath(world, road, entry)
	WorldRivers.cut_paths_at_rivers(world)
