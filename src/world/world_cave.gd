class_name WorldCave
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldCave.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

# constants shared with WorldGeometry
const TL = WorldGeometry.TL

static func cave_ground_contains(offset: Vector2, margin: float = 0) -> bool:
	var r: Vector2 = WorldGeometry.cave_radii + Vector2.ONE * margin
	if absf(offset.x) > r.x or absf(offset.y) > r.y:
		return false
	var d: float = Vector2(offset.x / r.x, offset.y / r.y).length()
	var a: float = atan2(offset.y, offset.x)
	return d <= 0.94 + 0.035 * sin(a * 5 + 16) + 0.025 * sin(a * 9 - 16)

static func in_cave_region(world: WorldGeometry, p: Vector2, margin: float = 0) -> bool:
	return cave_ground_contains(p - world.cave_centre, margin)

static func in_cave_floor(world: WorldGeometry, p: Vector2) -> bool:
	return IslandMap.in_polygon(world.cave_floor, p)

static func is_cave_interior(world: WorldGeometry, p: Vector2) -> bool:
	return p.x < world.cave_entrance.x - 32 and in_cave_floor(world, p)

static func cave_ground_colour(world: WorldGeometry, p: Vector2) -> Color:
	if not in_cave_floor(world, p):
		return Color("65645D")
	var depth: float = clampf((world.cave_entrance.x - p.x) / (24 * TL), 0, 1)
	return Color("50544A").lerp(Color("303D38"), depth)

static func build_walkable_cave(world: WorldGeometry) -> void:
	world.cave_centre = (WorldLandmarks.at(world, 16) - WorldLandmarks.tl(12, 0)).round()
	world.lm_at[16] = world.cave_entrance
	world.cave_walls.clear()
	var shape = [WorldLandmarks.tl(12, -2.4), WorldLandmarks.tl(8, -2.6), WorldLandmarks.tl(6, -5.1), WorldLandmarks.tl(1, -6), WorldLandmarks.tl(-4, -5.8), WorldLandmarks.tl(-10, -3.8), WorldLandmarks.tl(-11, -0.8), WorldLandmarks.tl(-10.2, 3.5), WorldLandmarks.tl(-6, 5.6), WorldLandmarks.tl(0, 6.2), WorldLandmarks.tl(6, 5.2), WorldLandmarks.tl(8.6, 2.7), WorldLandmarks.tl(12, 2.4)]
	world.cave_floor = shape.map(func(p): return (world.cave_centre + p).round())
	build_cave_roof(world)
	# No closing wall on the east: an opening almost five tiles wide, with an unobstructed central aisle.
	var i: int = 0
	while i < world.cave_floor.size() - 1:
		var a: Vector2 = world.cave_floor[i]
		var b: Vector2 = world.cave_floor[i + 1]
		WorldLandmarkScale.compound_line(world, a, b, 21)
		var n: int = maxi(1, int(ceilf(a.distance_to(b) / (2.1 * TL))))
		for j in range(n):
			var along: Vector2 = (b - a).normalized()
			var p: Vector2 = a.lerp(b, j / float(n)) - along * 6
			var q: Vector2 = a.lerp(b, (j + 1.0) / n) + along * 6
			var across: Vector2 = (b - a).normalized().orthogonal() * 23
			var lift: Vector2 = Vector2(0, -39 - (i * 13 + j * 7) % 22)
			var cap = [(p + across + lift + Vector2(3, -7)).round(), (p.lerp(q, 0.47) + across + lift * 1.1).round(), (q + across + lift * 0.9 + Vector2(-3, -4)).round(), (q - across + lift * 0.75).round(), (p.lerp(q, 0.38) - across + lift * 0.93).round(), (p - across + lift * 0.85).round()]
			var face = [cap[5], cap[4], cap[3], (q - across + Vector2(0, 8)).round(), (p.lerp(q, 0.6) - across + Vector2(2, 11)).round(), (p - across + Vector2(0, 5)).round()]
			var facet = [cap[0], cap[1], cap[4], cap[5]]
			var strata = [face[0].lerp(face[5], 0.57).round(), face[1].lerp(face[4], 0.58).round(), face[2].lerp(face[3], 0.55).round()]
			var crack = [cap[1], cap[4].lerp(cap[3], 0.24).round(), face[4].lerp(face[3], 0.34).round()]
			world.cave_walls.append([face, cap, facet, strata, crack])
		i += 1
	# Geological dressing stays outside the mining lanes; only loose resource rocks can be harvested.
	for _it1 in [[-9.0, -4.7], [-6.0, -6.4], [2.0, -6.9], [5.0, 6.4], [-7.0, 6.5]]:
		var x = _it1[0]
		var y = _it1[1]
		WorldLandmarks.prop(world, world.cave_centre + WorldLandmarks.tl(x, y), "lm_rubble_0")
	WorldLandmarks.prop(world, world.cave_centre + WorldLandmarks.tl(13, -4.7), "lm_warning_0")
	WorldLandmarks.prop(world, world.cave_centre + WorldLandmarks.tl(12, 5.1), "lm_expedition_0")
	world.compound_entrances[16] = world.cave_entrance + WorldLandmarks.tl(1.5, 0)
	WorldLandmarks.clear(world, world.cave_centre, WorldGeometry.cave_radii.x + TL)
	build_cave_exterior_masks(world)

static func build_cave_exterior_masks(world: WorldGeometry) -> void:
	var points = Array(world.cave_floor).duplicate()
	for _it1 in world.cave_walls:
		var face = _it1[0]
		var cap = _it1[1]
		points.append_array(face)
		points.append_array(cap)
	var hull = Array(Geometry2D.convex_hull(Array(points).duplicate())).duplicate()
	if hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size() - 1)
	world.cave_visibility_boundary = Array(hull).duplicate()
	var left: int = 0
	var right: int = 0
	for i in range(1, hull.size()):
		if hull[i].x < hull[left].x:
			left = i
		if hull[i].x > hull[right].x:
			right = i
	var a = _build_cave_exterior_masks_chain(world, 1, hull, left, right)
	var b = _build_cave_exterior_masks_chain(world, -1, hull, left, right)
	if _build_cave_exterior_masks_average_y(world, a) > _build_cave_exterior_masks_average_y(world, b):
		var _t2 = b
		var _t3 = a
		a = _t2
		b = _t3
	var far: float = 32768
	a.append(Vector2(hull[right].x, -far))
	a.append(Vector2(hull[left].x, -far))
	b.append(Vector2(hull[right].x, far))
	b.append(Vector2(hull[left].x, far))
	world.cave_exterior_masks.clear()
	world.cave_exterior_masks.append(Array(a).duplicate())
	world.cave_exterior_masks.append(Array(b).duplicate())
	world.cave_exterior_masks.append([Vector2(-far, -far), Vector2(hull[left].x, -far), Vector2(hull[left].x, far), Vector2(-far, far)])
	world.cave_exterior_masks.append([Vector2(hull[right].x, -far), Vector2(far, -far), Vector2(far, far), Vector2(hull[right].x, far)])

# local function Chain of the method above
static func _build_cave_exterior_masks_chain(world: WorldGeometry, step: int, hull, left, right) -> Variant:
	var result = []
	var i: int = left
	while true:
		result.append(hull[i])
		if i == right:
			break
		i = (i + step + hull.size()) % hull.size()
	return result

# local function AverageY of the method above
static func _build_cave_exterior_masks_average_y(world: WorldGeometry, c) -> float:
	var y: float = 0
	for p in c:
		y += p.y
	return y / c.size()

static func build_cave_roof(world: WorldGeometry) -> void:
	# The rock canopy stops short of the eastern lip, exposing a dark, east-facing opening.
	var outline = [WorldLandmarks.tl(10.5, -3), WorldLandmarks.tl(5.8, -6), WorldLandmarks.tl(0, -7.5), WorldLandmarks.tl(-6.7, -6.4), WorldLandmarks.tl(-11.3, -3.3), WorldLandmarks.tl(-12, 0), WorldLandmarks.tl(-10.8, 3.8), WorldLandmarks.tl(-6, 5.6), WorldLandmarks.tl(0, 6.1), WorldLandmarks.tl(6, 5.2), WorldLandmarks.tl(10.5, 2.7), WorldLandmarks.tl(9.6, 0.8), WorldLandmarks.tl(9.6, -1)]
	world.cave_roof = outline.map(func(p): return (world.cave_centre + p).round())
	world.cave_roof_facets.clear()
	world.cave_roof_seams.clear()
	var samples = Array(world.cave_roof).duplicate()
	for y in range(-5, 5, 2):
		for x in range(-10, 9, 3):
			var p: Vector2 = (world.cave_centre + WorldLandmarks.tl(x + 0.6 * sin(x * 7 + y), y + 0.4 * cos(x + y * 3))).round()
			if IslandMap.in_polygon(world.cave_roof, p):
				samples.append(p)
	var points = Array(samples).duplicate()
	var triangles = Geometry2D.triangulate_delaunay(points)
	var i: int = 0
	while i < triangles.size():
		var triangle = [points[triangles[i]], points[triangles[i + 1]], points[triangles[i + 2]]]
		for patch in Geometry2D.intersect_polygons(triangle, world.cave_roof):
			world.cave_roof_facets.append(patch)
		i += 3
	# Irregular sediment bands and fissures, generated once rather than rebuilt while drawing.
	for i_2 in range(37):
		var x: float = -11 + fmod(i_2 * 7.31, 20)
		var y: float = -6 + fmod(i_2 * 3.17, 11)
		var a: Vector2 = world.cave_centre + WorldLandmarks.tl(x, y)
		var b: Vector2 = a + WorldLandmarks.tl(2.1 + i_2 % 3 * 0.6, -0.12 + i_2 % 4 * 0.1)
		var mid: Vector2 = a.lerp(b, 0.45) + Vector2(0, 5 if i_2 % 2 == 0 else -4)
		if IslandMap.in_polygon(world.cave_roof, a) and IslandMap.in_polygon(world.cave_roof, b):
			world.cave_roof_seams.append([a.round(), mid.round(), b.round()])

static func add_cave_resources(world: WorldGeometry) -> void:
	var ore: int = 0
	var stone: int = 0
	for y in [-3.5, -1.8, 1.8, 3.5]:
		for x in [-8.0, -5.0, -2.0, 1.0, 4.0, 7.0]:
			var p: Vector2 = (world.cave_centre + WorldLandmarks.tl(x + 0.45 * sin(x * 1.7 + y * 0.4), y + 0.27 * cos(x * 1.23))).round()
			if not in_cave_floor(world, p) or not _add_cave_resources_free(world, p, 19.2):
				continue
			var _old1 = ore
			ore += 1
			world.harvest_sites.append(Harvestables.Site.new(p, "node_titanium_" + Cs.s(_old1 % 2), 3, 19.2))
	# Scree fields wrap the chamber; leave the east-west entrance and its approach entirely clear.
	var i: int = 0
	while i < 204 and stone < 32:
		var a: float = i * 2.399963
		var ring: float = 0.74 if i % 3 == 0 else 0.86 if i % 3 == 1 else 0.94
		var p: Vector2 = (world.cave_centre + Vector2(cos(a) * WorldGeometry.cave_radii.x, sin(a) * WorldGeometry.cave_radii.y) * ring).round()
		if not in_cave_region(world, p) or in_cave_floor(world, p) or p.x > world.cave_centre.x + 7 * TL and absf(p.y - world.cave_centre.y) < 1.7 * TL or not _add_cave_resources_free(world, p, 19.84):
			i += 1
			continue
		var _old2 = stone
		stone += 1
		world.harvest_sites.append(Harvestables.Site.new(p, "rock_" + Cs.s(_old2 % 5), 1, 19.84))
		i += 1

# local function Free of the method above
static func _add_cave_resources_free(world: WorldGeometry, p: Vector2, radius: float) -> bool:
	if not IslandMap.on_land(p, radius + 12) or IslandMap.in_river(p, IslandMap.RIVER_BANK + radius):
		return false
	for _it1 in world.lm_solids:
		var c = _it1[0]
		var r = _it1[1]
		if p.distance_to(c) < r + radius + 13:
			return false
	for site in world.harvest_sites:
		if p.distance_to(site.pos) < radius + site.radius + 12:
			return false
	return true
