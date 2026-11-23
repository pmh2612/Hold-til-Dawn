class_name WorldLandmarkDetails
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldLandmarkDetails.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

# constants shared with WorldGeometry
const LANDMARK_SCALE = WorldGeometry.LANDMARK_SCALE
const TL = WorldGeometry.TL

static func soil_centre(world: WorldGeometry, soil) -> Vector2:
	return world.cave_centre if soil.id == 16 else world.lm_at[soil.id]

# Continuous core with a broken, feathered outer edge; never a faint green-tinted wash.
static func soil_coverage(soil, offset: Vector2) -> float:
	# Every point of the cave region is opaque rock, including its rim and eastern approach.
	if soil.id == 16:
		return 1 if WorldCave.cave_ground_contains(offset) else 0
	if soil.id == 12 or soil.id == 17:
		var distance: float = (offset / WorldLookouts.lookout_radii(soil.id)).length()
		return clampf((1.18 - distance) / 0.18, 0, 1)
	if soil.id == 5 or soil.id == 7 or soil.id == 11:
		# The complete designed footprint shares its centre with the map marker and the scene.
		# A rounded rectangle covers the outer vehicles and ledges, unlike the former small ellipse.
		var outside: Vector2 = (offset.abs() - WorldExpeditionSites.expedition_half(soil.id)).max(Vector2.ZERO)
		return clampf(1 - outside.length() / TL, 0, 1)
	if soil.id == 2 or soil.id == 3 or soil.id == 4:
		var farm_distance: float = (offset / WorldGeometry.home_farm_radii).length()
		# The complete gathering footprint is opaque, with the feathering entirely outside it.
		return clampf((1.12 - farm_distance) / 0.12, 0, 1)
	if soil.id == 18:
		var garden_edge: Vector2 = offset.abs() / TL - WorldGeometry.garden_half / TL
		return clampf(1 - (maxf(garden_edge.x, garden_edge.y) - 0.25) / 1.25, 0, 1)
	if absf(offset.x) >= soil.rx * TL or absf(offset.y) >= soil.ry * TL:
		return 0
	var d: float = Vector2(offset.x / (soil.rx * TL), offset.y / (soil.ry * TL)).length()
	var angle: float = atan2(offset.y, offset.x)
	var edge: float = 0.94 + 0.035 * sin(angle * 5 + soil.id) + 0.025 * sin(angle * 9 - soil.id)
	return clampf((edge - d) / 0.18, 0, 1) * (1 if soil.bare else 0.38)

static func bare_landmark_ground(world: WorldGeometry, p: Vector2) -> bool:
	for soil in WorldGeometry.landmark_soils:
		if soil.bare and world.lm_at.has(soil.id) and soil_coverage(soil, p - soil_centre(world, soil)) > 0.5:
			return true
	return false

static func dress_landmarks(world: WorldGeometry) -> void:
	# 01: the outpost's exterior service corner; leave all three defence approaches open.
	dress_at(world, WorldLandmarks.tl(-7.6, 5.8), "lm_generator_0", 12)
	dress_at(world, WorldLandmarks.tl(-9.1, 5.5), "lm_cable_0", 9)
	dress_at(world, WorldLandmarks.tl(7.9, 5.5), "lm_barricade_0")
	# 02..04: the compact home farms own their scenery and all their trees, stones and herbs are harvestable.
	# 05 and 07 supply their own centred recovery / convoy scenes.
	# 06: the expanded ruined compound supplies its own equipment and collapse debris.
	# 08: dense fern fans grow on the raised banks, never in the water or across a path.
	for i in range(15):
		var p: Vector2 = world.swamp_centre + Vector2.from_angle(i * 2.39996) * (0.35 + i * 0.035) * world.swamp_r
		if not WorldTerrain.near_path(world, p, 0.8 * TL):
			dress_at(world, p, "lm_fern_0")
	# 09: the walkable weather hut owns its equipment and a clear southern doorway.
	# 10: fishing gear on shore; the pier deck remains fully walkable.
	dress(world, 10, 2.7, 3.1, "lm_boat_0")
	dress(world, 10, 1.0, -2.7, "lm_buoys_0", 7)
	dress(world, 10, 1.2, 2.6, "lm_rope_0")
	dress(world, 10, 2.2, -2.2, "lm_lifering_0")
	# 11 owns the rocky terraces, stairs and wind markers.
	# 12 supplies its marine lookout, reef board and diving equipment.
	# 13: the expanded yard supplies its own crane, forklift and loading bays.
	# 14: an anchor, tender and ring identify the wreck's salvage beach.
	dress(world, 14, -5.6, 3.1, "lm_anchor_0")
	dress(world, 14, 2.7, 4.0, "lm_boat_0")
	dress(world, 14, -1.1, 3.5, "lm_lifering_0")
	dress(world, 14, 4.5, 3.0, "lm_rope_0")
	dress(world, 14, -3.6, 2.8, "lm_scrap_0")
	# 15: a wet garden of ferns and pale flowers around the actual pond, with animated dragonflies.
	if world.ponds.size() > 0:
		for i in range(14):
			var p: Vector2 = world.ponds[0].centre + Vector2.from_angle(i * TAU / 14) * world.ponds[0].radius * Vector2(1.95, 1.55)
			if not WorldTerrain.near_path(world, p, 0.6 * TL):
				dress_at(world, p, "lm_flowers_1" if i % 3 == 0 else "lm_fern_0")
	# 16: the cave has a dedicated scree apron and survey cache.
	# The eastern cave entrance and resource fields are dressed by src/world/world_cave.gd.
	# 17 supplies its compass terrace, beacon and signal equipment.
	# 18 supplies its own enclosed garden, gate, equipment and harvestable herb beds.

static func dress(world: WorldGeometry, id: int, x: float, y: float, sprite, radius: float = 0) -> void:
	var c = world.lm_at.get(id, Vector2.ZERO)
	if world.lm_at.has(id):
		dress_at(world, c + WorldLandmarks.tl(x, y) * LANDMARK_SCALE, sprite, radius)

static func dress_at(world: WorldGeometry, p: Vector2, sprite, radius: float = 0) -> bool:
	# Reject rather than relocate: do not move set dressing into a doorway, a pool or a resource route.
	if not IslandMap.on_land(p, maxf(8, radius)) or WorldGeometry.near_pad(p) or WorldGeometry.lane(p):
		return false
	if not (WorldTerrain.terrain_at(world, p, maxf(6, radius)) == 0 or WorldTerrain.terrain_at(world, p, maxf(6, radius)) == 4 or WorldTerrain.terrain_at(world, p, maxf(6, radius)) == 6 or WorldTerrain.terrain_at(world, p, maxf(6, radius)) == 7 or WorldTerrain.terrain_at(world, p, maxf(6, radius)) == 9):
		return false
	if radius > 0:
		if WorldTerrain.near_path(world, p, radius + 12):
			return false
		for _it1 in world.lm_solids:
			var c = _it1[0]
			var r = _it1[1]
			if p.distance_to(c) < radius + r + 12:
				return false
		# Avoid overlapping the centres of the Atlas's existing props.
		for _it2 in world.lm_props:
			var c = _it2[0]
			if p.distance_to(c) < radius + 20:
				return false
	WorldLandmarks.prop(world, p.round(), sprite)
	WorldLandmarks.clear(world, p, maxf(14, radius + 14))
	return true

static func flower_border(world: WorldGeometry, id: int, radius: float) -> void:
	var c = world.lm_at.get(id, Vector2.ZERO)
	if not world.lm_at.has(id):
		return
	radius *= LANDMARK_SCALE
	for i in range(24):
		var a: float = i * 2.39996
		var p: Vector2 = c + Vector2.from_angle(a) * (radius * (0.55 + i % 5 * 0.1)) * TL
		if not WorldTerrain.near_path(world, p, 0.8 * TL) and IslandMap.on_grass(p, 20):
			dress_at(world, p, "lm_flowers_" + str(i % 3))
