class_name WorldGeometry
extends RefCounted

# ---- src/world/WorldGeometry.cs
# Shared world data. No rendering or SceneTree is needed on the dedicated server.
const T = 32.0
# how far the island reaches from the outpost, the sea beyond it is not walkable (src/world/IslandMap.cs)
const ISLAND = 126.0 * T
const HALF = Vector2(5.5, 3.5) * T
const SAFE_D = 20.0 * T
const CELL = 128.0
const COLD = Color(0.8, 0.88, 0.92)
static var LAYOUT = load("res://maps/island.tscn")
var deco = []
var scatter = []
var solids = []
var static_solids = []
var buckets = {}
var grids = {}
var paths = {}
var revision = 0
# a built wall is three solid circles one tile apart (GameSim.Walls.cs)
const WALL_PIECE: float = 0.55

func _init() -> void:
	self.generate()

static func wall_dist(p) -> Variant:
	return Vector2(maxf(absf(p.x) - HALF.x, 0), maxf(absf(p.y) - HALF.y, 0)).length()

static func near_pad(p: Vector2) -> bool:
	for i in 3:
		if p.distance_to(Vector2(GameSim.pad_pos(i))) < float(GameSim.PAD_R) + T:
			return true
	return false

static func lane(p) -> Variant:
	return absf(p.y) < 2.5 * T and absf(p.x) > HALF.x or absf(p.x) < 2.5 * T and p.y < -HALF.y

func generate() -> void:
	deco.clear()
	scatter.clear()
	harvest_sites.clear()
	var random = RandomNumberGenerator.new()
	random.seed = 7
	# paths, ponds, the swamp and the cave spires first, so the scenery grows around them (WorldTerrain.cs)
	self.build_terrain()
	# the landmarks' structures, so the scenery keeps clear of them (WorldLandmarks.cs)
	self.build_landmarks()
	# sprite names without the variant number (art/nature/<name>_<k>.png, tools/PixelNature.cs)
	var pines = ["pine"]
	var rocks = ["rock"]
	var variants = JSON.parse_string(FileAccess.get_file_as_string("res://art/nature/index.json"))
	# and the landmarks' sprites (art/landmarks, tools/PixelLandmarks.cs)
	var lm_variants = JSON.parse_string(FileAccess.get_file_as_string("res://art/landmarks/index.json"))
	for n in lm_variants:
		variants[n] = lm_variants[n]
	var names = {}
	for n in variants:
		var base = n.rsplit("_", true, 1)
		names[base[0]] = maxi(names.get(base[0], 0), base[1].to_int() + 1)
	var variant = func(n, k): return "%s_%d" % [n, absi(k) % maxi(1, names.get(n, 1))]
	# scenery stays on the grass, off the door roads and paths, out of the outpost's surroundings
	var free = func(p): return IslandMap.on_grass(p, 0.6 * T) and wall_dist(p) > 4 * T and not lane(p) and not self.terrain_blocked(p, 0.6 * T) and not near_pad(p)
	var outer = func(p): return free.call(p) and wall_dist(p) > SAFE_D + 2 * T
	var box: Rect2 = IslandMap.box
	var anywhere = func(): return Vector2(lerpf(box.position.x, box.end.x, random.randf()), lerpf(box.position.y, box.end.y, random.randf()))
	# a tree for every tree on the design map, most with one to three more beside it (the island is larger than the map)
	for dot in IslandMap.trees:
		var count: int = 1  # harvestable forest: spaced trees, without overlapping decorative copies
		for k in count:
			var p: Vector2 = dot if k == 0 else dot + Vector2.from_angle(random.randf() * TAU) * random.randf_range(0.8 * T, 2.6 * T)
			if free.call(p):
				var pool = pines
				# coconut palms in the Coconut Grove
				if self.in_grove(p):
					pool = ["lm_palm"]
				deco.append([p, variant.call(pool[random.randi() % pool.size()], random.randi()), 1.0, COLD])
	# and the woods filled in more thinly
	for wood in IslandMap.shade:
		var wb = Rect2(wood[0], Vector2.ZERO)
		for q in wood:
			wb = wb.expand(q)
		var many: int = int(wb.get_area() / (T * T) / 110.0)
		for k in many:
			var p = Vector2(lerpf(wb.position.x, wb.end.x, random.randf()), lerpf(wb.position.y, wb.end.y, random.randf()))
			if IslandMap.in_polygon(wood, p) and free.call(p):
				deco.append([p, variant.call("lm_palm" if self.in_grove(p) else pines[random.randi() % pines.size()], random.randi()), 1.0, COLD])
	# rock outcrops and lone dead trees out past the safe zone
	for c in 54:
		var centre: Vector2 = anywhere.call()
		if not outer.call(centre):
			continue
		for k in random.randi_range(3, 6):
			var p: Vector2 = centre + Vector2.from_angle(random.randf() * TAU) * random.randf_range(0, 2.2 * T)
			if outer.call(p):
				deco.append([p, variant.call(rocks[random.randi() % rocks.size()], random.randi()), 1.0, COLD])
	# low shrubs in the safe zone
	for i in 1350:
		var p: Vector2 = anywhere.call()
		var wd = wall_dist(p)
		if wd > 3 * T and wd < SAFE_D and random.randf() < 0.12 and free.call(p):
			deco.append([p, variant.call("shrub", random.randi()), 1.0, COLD])
	# grass tufts and pebbles on the grass, pebbles on the beach
	var flat = ["grass", "grass", "grass", "grass_dry", "grass", "grass_dry", "pebble", "grass", "pebble", "grass"]
	for tries in 45000:
		if scatter.size() >= 3800:
			break
		var p: Vector2 = anywhere.call()
		if absf(p.x) <= HALF.x + 2.6 * T and absf(p.y) <= HALF.y + 2.6 * T:
			continue
		var kind: int = self.terrain_at(p, 4.0)
		if bare_landmark_ground(p):
			continue
		if kind == 0 or kind == 4 or kind == 9:
			scatter.append([p, variant.call(flat[random.randi() % flat.size()], random.randi()), 1.0])
		elif kind == 7 and IslandMap.on_land(p, T) and random.randf() < 0.25:
			scatter.append([p, variant.call("pebble", random.randi()), 1.0])
	# rock spires round the Southwest Cave, and reeds round the pond and the swamp pools
	for cp in self.crags:
		deco.append([cp, variant.call("crag", random.randi()), 1.0, COLD])
	for pd in self.ponds:
		var i: int = 0
		while i < pd.edge.size():
			var bank: Vector2 = pd.edge[i] + (pd.edge[i] - pd.centre).normalized() * 6.0
			if random.randf() < 0.6 and IslandMap.on_grass(bank) and not self.near_path(bank, 0.3 * T):
				deco.append([bank, variant.call("reed", random.randi()), 1.0, COLD])
			i += 2
	fill_resource_gaps(variants)
	extract_harvestables(variants)
	add_cave_resources()
	add_garden_herbs()
	ensure_home_farm_resources()
	# a landmark's own props are added after the resources are picked out: they stay as scenery and cannot be
	# gathered, so each place keeps its look when everything round it has been cut down
	for _it1 in self.lm_props:
		var lp = _it1[0]
		var ls = _it1[1]
		deco.append([lp, ls, 1.0, COLD])
	# Hand-placed objects are editable with Godot's 2D editor.
	var layout = LAYOUT.instantiate()
	static_solids.clear()
	# index.json gives each sprite's solid radius in pixels: a trunk, a boulder's footprint, 0 for shrubs
	for d in deco:
		var radius: float = float(variants.get(d[1], [0, 0, 0])[2])
		if radius > 0:
			static_solids.append([d[0], radius, true])
	self.add_terrain_solids(static_solids)
	for child in layout.get_children():
		if child is Sprite2D and child.texture != null:
			var sprite = child.texture.resource_path.get_file().get_basename()
			if sprite.begins_with("dead_"):
				continue
			var resource_type: int = Harvestables.type_of(sprite)
			if resource_type >= 0:
				var site = Harvestables.Site.new(Vector2(child.position), sprite, resource_type, float(child.solid_radius * absf(child.scale.x)))
				harvest_sites.append(site)
				Cs.set_add(hand_placed, site)
				continue
			deco.append([child.position, child.texture.resource_path.get_file().get_basename(), child.scale.x, child.modulate])
			if child.solid_radius > 0:
				static_solids.append([child.position, child.solid_radius * absf(child.scale.x), child.blocks_attacks])
	layout.free()
	thin_outside_resources()
	static_solids.append([Vector2(0, 0.3 * T - 6), 22.0, true])
	# the workbench and the storage chest (GameSim.World.cs)
	for s in GameSim.furniture_solids():
		static_solids.append([s[0], s[1], true])
	scatter.sort_custom(func(a, b): return a[0].y < b[0].y)
	self.rebuild([], [])

static func wall_pieces(pos, vert) -> Variant:
	var along: Vector2 = Vector2.DOWN if vert else Vector2.RIGHT
	return [pos - along * T, pos, pos + along * T]

func rebuild(nodes, towers, walls = null) -> void:
	var next = updated_colliders(nodes, towers, walls)
	if next == null:
		return
	solids = next
	buckets.clear()
	grids.clear()
	paths.clear()
	invalidate_fast_navigation()
	revision += 1
	for i in solids.size():
		var s = solids[i]
		var lo = Vector2i((s[0] - Vector2.ONE * s[1]) / CELL)
		var hi = Vector2i((s[0] + Vector2.ONE * s[1]) / CELL)
		# floor is essential for negative world coordinates.
		lo = Vector2i(((s[0] - Vector2.ONE * s[1]) / CELL).floor())
		hi = Vector2i(((s[0] + Vector2.ONE * s[1]) / CELL).floor())
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var key = Vector2i(x, y)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(i)
	# the typed copy the moves use every tick (WorldGeometry.FastMove.cs)
	self.mirror_solids()

func candidates(a, b, radius) -> Variant:
	var lo = Vector2i(((a.min(b) - Vector2.ONE * radius) / CELL).floor())
	var hi = Vector2i(((a.max(b) + Vector2.ONE * radius) / CELL).floor())
	var found = {}
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for i in buckets.get(Vector2i(x, y), []):
				found[i] = true
	return found.keys()

func resolve(pos, radius) -> Variant:
	var nearby = self.candidates(pos, pos, radius + 32.0)
	for pass_index in 3:
		for i in nearby:
			var s = solids[i]
			var d: Vector2 = Vector2(pos - s[0])
			var need: float = float(radius + s[1])
			if d.length_squared() < need * need:
				pos = s[0] + (d.normalized() if d.length_squared() > 0.0001 else Vector2.DOWN) * need
	return pos

func move_body(from, to, radius, walls) -> Variant:
	var count = maxi(1, ceili(from.distance_to(to) / 4.0))
	var step = (to - from) / count
	var pos = from
	for i in count:
		var next = self.resolve(pos + step, radius)
		for w in walls:
			var q = next.clamp(w.position, w.end)
			var d = next - q
			if d.length_squared() < radius * radius and d.length_squared() > 1e-06:
				next = q + d.normalized() * radius
		pos = next
	return pos

static func circle_hit(a, b, centre, radius) -> Variant:
	# Fraction of a finite segment at first contact; INF means no contact.
	var start = a - centre
	if start.length_squared() <= radius * radius:
		return 0.0
	var step = b - a
	var length2 = step.length_squared()
	if length2 < 1e-06:
		return INF
	var dot = start.dot(step)
	var disc = dot * dot - length2 * (start.length_squared() - radius * radius)
	if disc < 0:
		return INF
	var hit = (-dot - sqrt(disc)) / length2
	return hit if hit >= 0.0 and hit <= 1.0 else INF

func first_hit(a, b, radius = null, attacks = null, ignore = null) -> Variant:
	if radius == null: radius = 0.0
	if attacks == null: attacks = false
	if ignore == null: ignore = Vector2.INF
	var best = INF
	for i in self.candidates(a, b, radius):
		var s = solids[i]
		if s[1] <= 0 or s[0].is_equal_approx(ignore) or attacks and not s[2]:
			continue
		best = minf(best, circle_hit(a, b, s[0], s[1] + radius))
	return best

func waypoint(from, to, radius, walls) -> Variant:
	# A resource/tower is a valid destination: walk up to its surface, not its centre.
	if self.first_hit(from, to, radius, false, to) == INF and not walls.any(func(w): return segment_box(from, to, w.grow(radius)) < INF):
		return to
	var key = "%d:%s" % [roundi(radius * 10), Cs.s(walls)]
	var grid = grids.get(key)
	if grid == null:
		grid = AStarGrid2D.new()
		grid.region = Rect2i(-128, -128, 257, 257)
		grid.cell_size = Vector2.ONE * T
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for s in solids:
			var reach: float = float(s[1] + radius + 1.0)
			var lo = Vector2i(((s[0] - Vector2.ONE * reach) / T).floor())
			var hi = Vector2i(((s[0] + Vector2.ONE * reach) / T).ceil())
			for y in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var cell = Vector2i(x, y)
					if grid.is_in_boundsv(cell) and (Vector2(cell) * T).distance_to(s[0]) < reach:
						grid.set_point_solid(cell)
		# the sea
		for cy in range(-128, 129):
			for cx in range(-128, 129):
				if not IslandMap.on_land(Vector2(cx, cy) * T, float(radius)):
					grid.set_point_solid(Vector2i(cx, cy))
		for w in walls:
			var box = w.grow(radius + 1)
			var lo = Vector2i((box.position / T).floor())
			var hi = Vector2i((box.end / T).ceil())
			for y in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var cell = Vector2i(x, y)
					if grid.is_in_boundsv(cell) and box.has_point(Vector2(cell) * T):
						grid.set_point_solid(cell)
		grids[key] = grid
	var start = self.open_cell(grid, from)
	var end = self.open_cell(grid, to)
	var path_key = [key, start, end]
	var path = paths.get(path_key, [])
	if path.is_empty():
		path = grid.get_id_path(start, end, true)
		if paths.size() > 1024:
			paths.clear()
		paths[path_key] = path
	for j in range(mini(path.size() - 1, 5), -1, -1):
		var p = Vector2(path[j]) * T
		if from.distance_to(p) < 2:
			continue
		if self.first_hit(from, p, radius) == INF and not walls.any(func(w): return segment_box(from, p, w.grow(radius)) < INF):
			return p
	# Nothing ahead is in plain sight, e.g. the body is pressed into a tree or squeezed between two solids:
	# head for the next cell anyway and let the movement slide along the solid. Returning From here left a
	# bot (or an enemy) standing still for good.
	for j in range(mini(1, path.size() - 1), -1, -1):
		var p = Vector2(path[j]) * T
		if from.distance_to(p) >= 2:
			return p
	return from

func open_cell(grid, pos) -> Variant:
	var cell = Vector2i((pos / T).round())
	for ring in 7:
		var best = cell
		var distance = INF
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				var c = cell + Vector2i(x, y)
				if grid.is_in_boundsv(c) and not grid.is_point_solid(c):
					var d = (Vector2(c) * T).distance_squared_to(pos)
					if d < distance:
						distance = d
						best = c
		if distance < INF:
			return best
	return cell

static func segment_box(a, b, box) -> Variant:
	var enter = 0.0
	var leave = 1.0
	var step = b - a
	for axis in 2:
		if absf(step[axis]) < 1e-05:
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]:
				return INF
		else:
			var t0: float = float((box.position[axis] - a[axis]) / step[axis])
			var t1: float = float((box.end[axis] - a[axis]) / step[axis])
			enter = maxf(enter, minf(t0, t1))
			leave = minf(leave, maxf(t0, t1))
			if enter > leave:
				return INF
	return enter

# ---- src/world/Harvestables.cs
var harvest_sites = []

func extract_harvestables(variants) -> void:
	var kept = []
	for d in deco:
		var sprite = Cs.s(d[1])
		if sprite.begins_with("dead_"):
			continue
		var type: int = Harvestables.type_of(sprite)
		if type < 0:
			kept.append(d)
			continue
		var radius: float = float(variants.get(sprite, [0, 0, 0])[2])
		harvest_sites.append(Harvestables.Site.new(Vector2(d[0]), sprite, type, radius))
	deco = kept

# ---- src/world/WorldCave.cs
# A cutaway cavern: the eastern opening leads west into a walkable chamber.
# The ground footprint is three times the previous cave clearing's area.
const CAVE_AREA_SCALE: float = 3.0
static var cave_radii: Vector2 = Vector2(7.5, 5.2) * LANDMARK_SCALE * sqrt(CAVE_AREA_SCALE) * TL

var cave_centre: Vector2 = Vector2.ZERO

var cave_entrance: Vector2:
	get:
		return cave_centre + tl(12, 0)

var cave_floor = []

var cave_roof = []
var cave_roof_facets = []
var cave_roof_seams = []
var cave_exterior_masks = []

var cave_visibility_boundary = []
var cave_walls = []

static func cave_ground_contains(offset: Vector2, margin: float = 0) -> bool:
	var r: Vector2 = cave_radii + Vector2.ONE * margin
	if absf(offset.x) > r.x or absf(offset.y) > r.y:
		return false
	var d: float = Vector2(offset.x / r.x, offset.y / r.y).length()
	var a: float = atan2(offset.y, offset.x)
	return d <= 0.94 + 0.035 * sin(a * 5 + 16) + 0.025 * sin(a * 9 - 16)

func in_cave_region(p: Vector2, margin: float = 0) -> bool:
	return cave_ground_contains(p - cave_centre, margin)

func in_cave_floor(p: Vector2) -> bool:
	return IslandMap.in_polygon(cave_floor, p)

func is_cave_interior(p: Vector2) -> bool:
	return p.x < cave_entrance.x - 32 and in_cave_floor(p)

func cave_ground_colour(p: Vector2) -> Color:
	if not in_cave_floor(p):
		return Color("65645D")
	var depth: float = clampf((cave_entrance.x - p.x) / (24 * TL), 0, 1)
	return Color("50544A").lerp(Color("303D38"), depth)

func build_walkable_cave() -> void:
	cave_centre = (at(16) - tl(12, 0)).round()
	lm_at[16] = cave_entrance
	cave_walls.clear()
	var shape = [tl(12, -2.4), tl(8, -2.6), tl(6, -5.1), tl(1, -6), tl(-4, -5.8), tl(-10, -3.8), tl(-11, -0.8), tl(-10.2, 3.5), tl(-6, 5.6), tl(0, 6.2), tl(6, 5.2), tl(8.6, 2.7), tl(12, 2.4)]
	cave_floor = shape.map(func(p): return (cave_centre + p).round())
	build_cave_roof()
	# No closing wall on the east: an opening almost five tiles wide, with an unobstructed central aisle.
	var i: int = 0
	while i < cave_floor.size() - 1:
		var a: Vector2 = cave_floor[i]
		var b: Vector2 = cave_floor[i + 1]
		compound_line(a, b, 21)
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
			cave_walls.append([face, cap, facet, strata, crack])
		i += 1
	# Geological dressing stays outside the mining lanes; only loose resource rocks can be harvested.
	for _it1 in [[-9.0, -4.7], [-6.0, -6.4], [2.0, -6.9], [5.0, 6.4], [-7.0, 6.5]]:
		var x = _it1[0]
		var y = _it1[1]
		prop(cave_centre + tl(x, y), "lm_rubble_0")
	prop(cave_centre + tl(13, -4.7), "lm_warning_0")
	prop(cave_centre + tl(12, 5.1), "lm_expedition_0")
	compound_entrances[16] = cave_entrance + tl(1.5, 0)
	clear(cave_centre, cave_radii.x + TL)
	build_cave_exterior_masks()

func build_cave_exterior_masks() -> void:
	var points = Array(cave_floor).duplicate()
	for _it1 in cave_walls:
		var face = _it1[0]
		var cap = _it1[1]
		points.append_array(face)
		points.append_array(cap)
	var hull = Array(Geometry2D.convex_hull(Array(points).duplicate())).duplicate()
	if hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size() - 1)
	cave_visibility_boundary = Array(hull).duplicate()
	var left: int = 0
	var right: int = 0
	for i in range(1, hull.size()):
		if hull[i].x < hull[left].x:
			left = i
		if hull[i].x > hull[right].x:
			right = i
	var a = _build_cave_exterior_masks_chain(1, hull, left, right)
	var b = _build_cave_exterior_masks_chain(-1, hull, left, right)
	if _build_cave_exterior_masks_average_y(a) > _build_cave_exterior_masks_average_y(b):
		var _t2 = b
		var _t3 = a
		a = _t2
		b = _t3
	var far: float = 32768
	a.append(Vector2(hull[right].x, -far))
	a.append(Vector2(hull[left].x, -far))
	b.append(Vector2(hull[right].x, far))
	b.append(Vector2(hull[left].x, far))
	cave_exterior_masks.clear()
	cave_exterior_masks.append(Array(a).duplicate())
	cave_exterior_masks.append(Array(b).duplicate())
	cave_exterior_masks.append([Vector2(-far, -far), Vector2(hull[left].x, -far), Vector2(hull[left].x, far), Vector2(-far, far)])
	cave_exterior_masks.append([Vector2(hull[right].x, -far), Vector2(far, -far), Vector2(far, far), Vector2(hull[right].x, far)])

# local function Chain of the method above
func _build_cave_exterior_masks_chain(step: int, hull, left, right) -> Variant:
	var result = []
	var i: int = left
	while true:
		result.append(hull[i])
		if i == right:
			break
		i = (i + step + hull.size()) % hull.size()
	return result

# local function AverageY of the method above
func _build_cave_exterior_masks_average_y(c) -> float:
	var y: float = 0
	for p in c:
		y += p.y
	return y / c.size()

func build_cave_roof() -> void:
	# The rock canopy stops short of the eastern lip, exposing a dark, east-facing opening.
	var outline = [tl(10.5, -3), tl(5.8, -6), tl(0, -7.5), tl(-6.7, -6.4), tl(-11.3, -3.3), tl(-12, 0), tl(-10.8, 3.8), tl(-6, 5.6), tl(0, 6.1), tl(6, 5.2), tl(10.5, 2.7), tl(9.6, 0.8), tl(9.6, -1)]
	cave_roof = outline.map(func(p): return (cave_centre + p).round())
	cave_roof_facets.clear()
	cave_roof_seams.clear()
	var samples = Array(cave_roof).duplicate()
	for y in range(-5, 5, 2):
		for x in range(-10, 9, 3):
			var p: Vector2 = (cave_centre + tl(x + 0.6 * sin(x * 7 + y), y + 0.4 * cos(x + y * 3))).round()
			if IslandMap.in_polygon(cave_roof, p):
				samples.append(p)
	var points = Array(samples).duplicate()
	var triangles = Geometry2D.triangulate_delaunay(points)
	var i: int = 0
	while i < triangles.size():
		var triangle = [points[triangles[i]], points[triangles[i + 1]], points[triangles[i + 2]]]
		for patch in Geometry2D.intersect_polygons(triangle, cave_roof):
			cave_roof_facets.append(patch)
		i += 3
	# Irregular sediment bands and fissures, generated once rather than rebuilt while drawing.
	for i_2 in range(37):
		var x: float = -11 + fmod(i_2 * 7.31, 20)
		var y: float = -6 + fmod(i_2 * 3.17, 11)
		var a: Vector2 = cave_centre + tl(x, y)
		var b: Vector2 = a + tl(2.1 + i_2 % 3 * 0.6, -0.12 + i_2 % 4 * 0.1)
		var mid: Vector2 = a.lerp(b, 0.45) + Vector2(0, 5 if i_2 % 2 == 0 else -4)
		if IslandMap.in_polygon(cave_roof, a) and IslandMap.in_polygon(cave_roof, b):
			cave_roof_seams.append([a.round(), mid.round(), b.round()])

func add_cave_resources() -> void:
	var ore: int = 0
	var stone: int = 0
	for y in [-3.5, -1.8, 1.8, 3.5]:
		for x in [-8.0, -5.0, -2.0, 1.0, 4.0, 7.0]:
			var p: Vector2 = (cave_centre + tl(x + 0.45 * sin(x * 1.7 + y * 0.4), y + 0.27 * cos(x * 1.23))).round()
			if not in_cave_floor(p) or not _add_cave_resources_free(p, 19.2):
				continue
			var _old1 = ore
			ore += 1
			harvest_sites.append(Harvestables.Site.new(p, "node_titanium_" + Cs.s(_old1 % 2), 3, 19.2))
	# Scree fields wrap the chamber; leave the east-west entrance and its approach entirely clear.
	var i: int = 0
	while i < 204 and stone < 32:
		var a: float = i * 2.399963
		var ring: float = 0.74 if i % 3 == 0 else 0.86 if i % 3 == 1 else 0.94
		var p: Vector2 = (cave_centre + Vector2(cos(a) * cave_radii.x, sin(a) * cave_radii.y) * ring).round()
		if not in_cave_region(p) or in_cave_floor(p) or p.x > cave_centre.x + 7 * TL and absf(p.y - cave_centre.y) < 1.7 * TL or not _add_cave_resources_free(p, 19.84):
			i += 1
			continue
		var _old2 = stone
		stone += 1
		harvest_sites.append(Harvestables.Site.new(p, "rock_" + Cs.s(_old2 % 5), 1, 19.84))
		i += 1

# local function Free of the method above
func _add_cave_resources_free(p: Vector2, radius: float) -> bool:
	if not IslandMap.on_land(p, radius + 12) or IslandMap.in_river(p, IslandMap.RIVER_BANK + radius):
		return false
	for _it1 in lm_solids:
		var c = _it1[0]
		var r = _it1[1]
		if p.distance_to(c) < r + radius + 13:
			return false
	for site in harvest_sites:
		if p.distance_to(site.pos) < radius + site.radius + 12:
			return false
	return true

# ---- src/world/WorldCompounds.cs
# Another 50% of the current yard area, in addition to the earlier island-wide enlargement.
const YARD_AREA_SCALE: float = 1.5
static var ruin_half: Vector2 = Vector2(4.5, 3.2) * TL * LANDMARK_SCALE
static var yard_half: Vector2 = Vector2(6.2, 3.8) * TL * LANDMARK_SCALE * sqrt(YARD_AREA_SCALE)
var compound_boundaries = []
var compound_gates = {}

func build_compound_perimeter(id: int, floor_: Rect2, gate_width: float) -> void:
	var edge: Rect2 = floor_.grow(-8)
	var nw: Vector2 = edge.position
	var se: Vector2 = edge.end
	var gate: Vector2 = Vector2(floor_.get_center().x, se.y)
	compound_gates[id] = gate
	compound_entrances[id] = gate + Vector2(0, 28)
	_build_compound_perimeter_side(nw, Vector2(se.x, nw.y), 0, id)
	_build_compound_perimeter_side(nw, Vector2(nw.x, se.y), 1, id)
	_build_compound_perimeter_side(Vector2(se.x, nw.y), se, 2, id)
	_build_compound_perimeter_side(Vector2(nw.x, se.y), gate - Vector2(gate_width / 2, 0), 3, id)
	_build_compound_perimeter_side(gate + Vector2(gate_width / 2, 0), se, 3, id)

# local function Side of the method above
func _build_compound_perimeter_side(a: Vector2, b: Vector2, side_id: int, id) -> void:
	compound_line(a, b, 8)
	var count: int = maxi(1, int(ceilf(a.distance_to(b) / 54)))
	var i: int = 0
	while i < count:
		var p: Vector2 = a.lerp(b, i / float(count))
		var q: Vector2 = a.lerp(b, (i + 1.0) / count)
		var height: float = 48 if id == 13 else 63 + i % 3 * 4 if side_id == 0 else 40 + i % 3 * 5 if side_id == 3 else 52 + i % 2 * 7
		var lift: Vector2 = Vector2(0, -height)
		var across: Vector2 = (q - p).normalized().orthogonal() * 5
		var face
		if side_id == 1 or side_id == 2:
			face = [p + Vector2(2, 0), q + Vector2(2, 0), q + lift + Vector2(9, 0), p + lift + Vector2(9, 0)]
		else:
			face = [p, q, q + lift, p.lerp(q, 0.71) + lift + Vector2(0, 5), p.lerp(q, 0.47) + lift - Vector2(0, 3), p.lerp(q, 0.22) + lift + Vector2(0, 3), p + lift]
		var cap = [p + lift - across, q + lift - across, q + lift + across, p + lift + across]
		if id == 6 and (side_id == 0 or side_id == 3):
			cap = Cs.arr(10, Vector2.ZERO)
			for k in range(5):
				cap[k] = face[6 - k]
				cap[9 - k] = face[6 - k] - Vector2(0, 6)
		var wire = []
		if id == 13:
			var along: Vector2 = (q - p).normalized()
			var length: float = p.distance_to(q)
			# Cache clipped diamond mesh once rather than rebuilding wire geometry while drawing.
			var start: float = -height
			while start <= length:
				var lo: float = maxf(0, -start)
				var hi: float = minf(height, length - start)
				if hi > lo:
					wire.append(p + along * (start + lo) + Vector2.UP * lo)
					wire.append(p + along * (start + hi) + Vector2.UP * hi)
				start += 12
			start = 0
			while start <= length + height:
				var lo: float = maxf(0, start - length)
				var hi: float = minf(height, start)
				if hi > lo:
					wire.append(p + along * (start - lo) + Vector2.UP * lo)
					wire.append(p + along * (start - hi) + Vector2.UP * hi)
				start += 12
		compound_boundaries.append(CompoundBoundary.new(id, side_id, p, q, height, face, cap, Array(wire).duplicate()))
		i += 1

func build_ruined_compound() -> void:
	var c: Vector2 = compound_spot(6, ruin_half)
	var floor_ = Rect2(c - ruin_half, ruin_half * 2)
	floors.append([floor_, true])
	compounds[6] = floor_
	lm_at[6] = c
	build_compound_perimeter(6, floor_, 100)
	# The whole roof has fallen in; four standing, damaged walls describe the original base.
	prop(c + Vector2(-94, 14), "lm_roof_fallen_0")
	compound_line(c + Vector2(-130, 7), c + Vector2(-67, 18), 15)
	prop(c + Vector2(103, 48), "lm_roof_fallen_0")
	compound_line(c + Vector2(75, 40), c + Vector2(135, 51), 14)
	prop(c + Vector2(-107, -70), "lm_rack_0")
	solid(c + Vector2(-107, -75), 15)
	prop(c + Vector2(81, -69), "lm_console_0")
	prop(c + Vector2(135, -60), "lm_mast_0")
	prop(c + Vector2(77, -13), "lm_radio_0")
	prop(c + Vector2(-133, 80), "lm_generator_0")
	solid(c + Vector2(-133, 75), 15)
	prop(c + Vector2(-77, 88), "lm_cable_0")
	prop(c + Vector2(136, 87), "lm_crate_0")
	prop(c + Vector2(104, -88), "lm_crate_0")
	prop(c + Vector2(-49, -81), "lm_expedition_0")
	prop(c + Vector2(132, -4), "lm_drum_1")
	prop(c + Vector2(-129, -31), "lm_rubble_0")
	prop(c + Vector2(100, 22), "lm_rubble_1")
	prop(c + Vector2(-62, 54), "lm_rubble_1")
	prop(c + Vector2(65, 88), "lm_rubble_0")
	prop(c + Vector2(-81, -99), "lm_scrap_0")
	prop(c + Vector2(-133, 113), "lm_warning_0")
	clear(c, ruin_half.length() + TL)

func build_container_compound() -> void:
	var c: Vector2 = compound_spot(13, yard_half)
	var floor_ = Rect2(c - yard_half, yard_half * 2)
	floors.append([floor_, true])
	compounds[13] = floor_
	lm_at[13] = c
	build_compound_perimeter(13, floor_, 144)
	# Rear bays, another long container at the front and a genuinely open end-on container.
	for _it1 in [[c + Vector2(-142, -105), "lm_container_1"], [c + Vector2(142, -105), "lm_container_0"], [c + Vector2(-157, 108), "lm_container_0"]]:
		var p = _it1[0]
		var sprite = _it1[1]
		prop(p, sprite)
		compound_line(p + Vector2(-75, -8), p + Vector2(75, -8), 18)
	var open: Vector2 = c + Vector2(224, 73)
	prop(open, "lm_container_end_0")
	compound_line(open + tl(-1, -2.6), open + tl(-1, -0.25), 10)
	compound_line(open + tl(1, -2.6), open + tl(1, -0.25), 10)
	compound_line(open + tl(-1, -2.6), open + tl(1, -2.6), 10)
	prop(c + Vector2(-110, 12), "lm_forklift_0")
	compound_line(c + Vector2(-133, 5), c + Vector2(-91, 5), 15)
	prop(c + Vector2(-258, 25), "lm_crane_0")
	solid(c + Vector2(-258, 25), 18)
	prop(c + Vector2(-89, -42), "lm_pallet_0")
	prop(c + Vector2(-81, -37), "lm_cargo_stack_0")
	prop(c + Vector2(91, 48), "lm_cargo_stack_0")
	prop(c + Vector2(146, 134), "lm_pallet_0")
	prop(c + Vector2(-256, 143), "lm_cable_0")
	prop(c + Vector2(-52, 139), "lm_expedition_0")
	prop(c + Vector2(261, 143), "lm_console_0")
	prop(c + Vector2(93, 163), "lm_warning_0")
	prop(c + Vector2(-95, 161), "lm_warning_0")
	for i in range(6):
		prop(c + Vector2(84 + i % 3 * 26, 106 + i / 3 * 28), "lm_drum_" + str(i % 2))
	prop(c + Vector2(-254, -37), "lm_cart_0")
	prop(c + Vector2(254, -151), "lm_crate_0")
	prop(c + Vector2(-250, -153), "lm_crate_0")
	clear(c, yard_half.length() + TL)

func in_compound_passage(p: Vector2) -> bool:
	for id in compounds:
		var floor_ = compounds[id]
		if (id == 6 or id == 13) and Cs.has_point(floor_.grow(48), p) and absf(p.x - floor_.get_center().x) < 35:
			return true
	return false

func build_cave_compound() -> void:
	build_walkable_cave()

# ---- src/world/WorldExpeditionSites.cs
var expedition_sites = {}
var expedition_vehicles = []
var expedition_cliffs = []

static func expedition_half(id: int) -> Vector2:
	return Vector2(220, 144) if id == 5 else Vector2(306, 183) if id == 7 else Vector2(204, 222) if id == 11 else Vector2.ZERO

func expedition_centre(id: int, half: Vector2) -> Vector2:
	var c: Vector2 = compound_spot(id, half)
	expedition_sites[id] = ExpeditionSite.new(id, c, half)
	lm_at[id] = c
	# Keep random vegetation out of the designed ground and the walking corridors.
	clear(c, half.length() + 12)
	compound_entrances[id] = c + Vector2(0, half.y - 12)
	return c

func expedition_prop(p: Vector2, sprite) -> void:
	prop(p.round(), sprite)

func expedition_car(id: int, p: Vector2, model: int, tilt: float = 0) -> void:
	expedition_vehicles.append(ExpeditionVehicle.new(id, p, model, tilt))
	var half: float = 70 if model == 0 else 82
	# Preserve a path around the trucks. The body, rather than an oversized circular sprite, is solid.
	compound_line(p + Vector2(-half + 15, -15), p + Vector2(half - 15, -15), 22)

func build_bayside_scene() -> void:
	var c: Vector2 = expedition_centre(5, expedition_half(5))
	expedition_car(5, c, 0, -0.12)
	# A snapped roadside barrier, a winch and recovered cargo describe a failed rescue attempt.
	expedition_prop(c + Vector2(-150, -74), "lm_barricade_0")
	expedition_prop(c + Vector2(-79, -110), "lm_barricade_0")
	expedition_prop(c + Vector2(157, 10), "lm_cable_0")
	solid(c + Vector2(157, 3), 14)
	expedition_prop(c + Vector2(128, -73), "lm_crate_0")
	expedition_prop(c + Vector2(178, -57), "lm_drum_1")
	expedition_prop(c + Vector2(-134, 80), "lm_scrap_0")
	expedition_prop(c + Vector2(-63, 111), "lm_rope_0")
	expedition_prop(c + Vector2(141, 103), "lm_warning_0")

func build_convoy_scene() -> void:
	var c: Vector2 = expedition_centre(7, expedition_half(7))
	# Symmetric foot anchors centre the whole convoy, rather than using the truck in one side lane.
	expedition_car(7, c + Vector2(-178, -38), 1, -0.04)
	expedition_car(7, c + Vector2(0, 76), 2, 0.035)
	expedition_car(7, c + Vector2(178, -38), 3, -0.07)
	expedition_prop(c + Vector2(-241, 117), "lm_barricade_0")
	expedition_prop(c + Vector2(230, 123), "lm_barricade_0")
	expedition_prop(c + Vector2(-135, -133), "lm_cargo_stack_0")
	expedition_prop(c + Vector2(-49, -118), "lm_pallet_0")
	expedition_prop(c + Vector2(42, -130), "lm_crate_0")
	expedition_prop(c + Vector2(111, -117), "lm_drum_0")
	expedition_prop(c + Vector2(5, -154), "lm_radio_0")
	expedition_prop(c + Vector2(183, 88), "lm_scrap_0")
	expedition_prop(c + Vector2(-133, 122), "lm_expedition_0")
	expedition_prop(c + Vector2(249, -127), "lm_warning_0")

func build_northwind_scene() -> void:
	var c: Vector2 = expedition_centre(11, expedition_half(11))
	# Three exposed rock benches flank a generous central ascent; cached polygons are reused every frame.
	for i in range(3):
		for side in [-1, 1]:
			var y: float = -132 + i * 108
			var a: Vector2 = c + Vector2(side * 73, y + 13)
			var b: Vector2 = c + Vector2(side * (177 - i * 10), y - 3)
			var lift: Vector2 = Vector2(0, -28 - i * 4)
			var f1: Vector2 = a.lerp(b, 0.23) + Vector2(0, 4)
			var f2: Vector2 = a.lerp(b, 0.61) - Vector2(0, 2)
			var t0: Vector2 = a + lift
			var t1: Vector2 = f1 + lift - Vector2(0, 4)
			var t2: Vector2 = f2 + lift + Vector2(0, 2)
			var t3: Vector2 = b + lift
			var face = [a, f1, f2, b, t3, t2, t1, t0]
			var cap = [t0, t1, t2, t3, t3 + Vector2(-side * 12, -24), t2 + Vector2(side * 2, -35), t1 + Vector2(side * 6, -29), t0 + Vector2(side * 15, -25)]
			expedition_cliffs.append(ExpeditionCliff.new(a, b, face, cap))
			compound_line(a, b, 12)
	expedition_prop(c + Vector2(-143, -187), "lm_windsock_0")
	expedition_prop(c + Vector2(133, -183), "lm_cairn_0")
	solid(c + Vector2(133, -183), 12)
	expedition_prop(c + Vector2(-135, 194), "lm_signpost_0")
	expedition_prop(c + Vector2(134, 190), "lm_cairn_0")
	solid(c + Vector2(134, 190), 12)
	expedition_prop(c + Vector2(168, -43), "lm_expedition_0")

func in_expedition_aisle(p: Vector2) -> bool:
	for site in expedition_sites.values():
		var d: Vector2 = p - site.centre
		if site.id == 11 and absf(d.x) < 63 and absf(d.y) < site.half.y + 32:
			return true
		if (site.id == 5 or site.id == 7) and absf(d.y - (60 if site.id == 5 else 4)) < 28 and absf(d.x) < site.half.x + 20:
			return true
	return false

# ---- src/world/WorldExploration.cs
var ramps = []

# Stone steps where a path climbs a hill. (The rivers and their bridges are src/world/IslandRivers.cs.)
func build_ramps() -> void:
	ramps.clear()
	for h in IslandMap.hills:
		var _d1 = on_path(h.top)
		var at_ = _d1[0]
		var along = _d1[1]
		if at_.distance_to(h.top) > 18 * TL:
			continue
		ramps.append([at_, along])
		for i in range(-4, 5):
			steps.append([at_ + along * i * 0.7 * TL, along.orthogonal()])

func dress_exploration() -> void:
	var r = CsRandom.new(802)
	# Every named site gets a distinct supporting scene; these props never become resource nodes.
	for id in range(2, 19):
		if id == 2 or id == 3 or id == 4 or id == 5 or id == 6 or id == 7 or id == 9 or id == 11 or id == 12 or id == 13 or id == 16 or id == 17 or id == 18:
			continue  # dedicated site dressing
		var props = ["lm_cart_0", "lm_warning_0", "lm_cargo_stack_0"] if id == 5 or id == 7 else ["lm_console_0", "lm_cargo_stack_0", "lm_warning_0"] if id == 6 or id == 9 or id == 13 else ["lm_waterpump_0", "lm_rainbarrel_0", "lm_signpost_0"] if id == 8 or id == 15 or id == 18 else ["lm_cargo_stack_0", "lm_rope_0", "lm_buoys_0"] if id == 10 or id == 12 or id == 14 else ["lm_tent_0", "lm_warning_0", "lm_expedition_0"]
		for i in range(props.size()):
			for try in range(12):
				var a: float = i * 2.1 + try * 0.52
				var p: Vector2 = lm_at.get(id, at(id)) + Vector2.from_angle(a) * (4.8 + try * 0.3) * TL * LANDMARK_SCALE
				if dress_at(p, props[i], 12 if i == 0 else 0):
					break
	# Survey camps, broken carts and signs in unnamed spaces, along trails rather than isolated clutter.
	for _it1 in trails:
		var path = _it1[0]
		var width = _it1[1]
		if path.size() < 18:
			continue
		for i in range(12, path.size() - 2, 32):
			var along: Vector2 = (path[i + 1] - path[i]).normalized()
			var p: Vector2 = path[i] + along.orthogonal() * (width / 2 + 2 * TL) * (-1 if r.next(2) == 0 else 1)
			if IslandMap.near(p, 10 * TL) != null or p.length() < 26 * TL or in_clear(p, 2 * TL):
				continue
			var _sw2 = r.next(4)
			var prop_ = "lm_tent_0" if _sw2 == 0 else "lm_cart_0" if _sw2 == 1 else "lm_warning_0" if _sw2 == 2 else "lm_cargo_stack_0"
			if dress_at(p, prop_, 12):
				dress_at(p + along * 1.6 * TL, "lm_expedition_0")

func fill_resource_gaps(variants) -> void:
	var r = CsRandom.new(317)
	var occupied = []
	var natural: int = 0
	for d in deco:
		occupied.append(Vector2(d[0]))
		if Harvestables.type_of(Cs.s(d[1])) >= 0:
			natural += 1
	# One small cluster per grid cell, with clear corridors between them. Fixed seed keeps world parity.
	var b: Rect2 = IslandMap.box
	# A second bounded pass replaces resources displaced by the larger landmark clearings.
	for pass_ in range(2):
		var y: float = b.position.y + 3 * TL
		while y < b.end.y and (pass_ == 0 or natural < 860):
			var x: float = b.position.x + 3 * TL
			while x < b.end.x and (pass_ == 0 or natural < 860):
				var k: int = 0
				while k < 2 and (pass_ == 0 or natural < 860):
					var p: Vector2 = Vector2(x, y) + Vector2(float(r.next_double()) * 4 - 2, float(r.next_double()) * 4 - 2) * TL
					if wall_dist(p) < 10 * TL or not IslandMap.on_grass(p, TL) or terrain_blocked(p, TL) or lane(p) or near_pad(p):
						k += 1
						continue
					var free: bool = true
					for q in occupied:
						if p.distance_squared_to(q) < 2.3 * TL * 2.3 * TL:
							free = false
							break
					if not free:
						k += 1
						continue
					var type: int = r.next(10)
					var name = "pine_" + Cs.s(r.next(6)) if type < 5 else "rock_" + Cs.s(r.next(5)) if type < 8 else "shrub_" + Cs.s(r.next(4))
					if not variants.has(name):
						k += 1
						continue
					deco.append([p.round(), name, 1.0, COLD])
					occupied.append(p)
					natural += 1
					k += 1
				x += 6 * TL
			y += 6 * TL

# ---- src/world/WorldFishingPier.cs
var fishing_rods = []
var fishing_fish = []
var fishing_litter = []
var fishing_litter_faces = []

func build_fishing_details(land: Vector2) -> void:
	fishing_rods.clear()
	fishing_fish.clear()
	fishing_litter.clear()
	fishing_litter_faces.clear()
	var deck: Rect2 = IslandMap.docks[0]
	# Feet sit on the deck edge, with lines hanging out over the sea.
	for _it1 in [[0.18, -1], [0.47, 1], [0.76, -1]]:
		var fraction = _it1[0]
		var side = _it1[1]
		fishing_rods.append([Vector2(lerpf(deck.position.x, deck.end.x, fraction), land.y + side * 20 * LANDMARK_SCALE).round(), side])
	for i in range(8):
		var side: int = -1 if i % 2 == 0 else 1
		var p: Vector2 = Vector2(lerpf(deck.position.x - 34, deck.end.x - 48, (i + 0.5) / 8), land.y + side * (66 + i % 3 * 24))
		if not IslandMap.on_land(p, -16) and not IslandMap.on_land(p + Vector2(28, 0), -12) and not IslandMap.on_land(p - Vector2(28, 0), -12) and not Cs.has_point(deck.grow(24), p):
			fishing_fish.append(p.round())
	for i in range(12):
		var p: Vector2 = Vector2(lerpf(deck.position.x + 30, deck.end.x - 26, i / 5.0), land.y + (-1 if i % 2 == 0 else 1) * 17) if i < 5 else land + tl(0.8 + i % 3 * 0.7, (-1 if i % 2 == 0 else 1) * (1.0 + i % 3 * 0.6))
		if i < 5 or IslandMap.on_land(p, 6):
			p = p.round()
			fishing_litter.append([p, i % 4])
			fishing_litter_faces.append([p + Vector2(-6, -3), p + Vector2(3, -5), p + Vector2(8, 1), p + Vector2(-2, 4)])

# ---- src/world/WorldGeometry.DynamicColliders.cs
var next_dynamic_colliders = []
var previous_dynamic_colliders = []
var previous_static_colliders
var previous_built_colliders
var previous_static_count: int = -1

func updated_colliders(nodes, towers, walls) -> Variant:
	next_dynamic_colliders.clear()
	if walls != null:
		for wall in walls:
			var p: Vector2 = Vector2(wall.get("pos"))
			var along: Vector2 = Vector2.DOWN if wall.get("vert") else Vector2.RIGHT
			for i in range(-1, 2):
				next_dynamic_colliders.append([p + along * i * 32, WALL_PIECE * 32])
	for node in nodes:
		var radius: float = Harvestables.radius(node)
		if int(node.get("amount")) > 0 and radius > 0:
			next_dynamic_colliders.append([Vector2(node.get("pos")), radius])
	for entry in towers:
		var tower = entry
		if entry is Dictionary:
			next_dynamic_colliders.append([Vector2(tower.get("pos")), 0.7 * 32])
	var same: bool = is_same(previous_static_colliders, static_solids) and previous_static_count == static_solids.size() and is_same(previous_built_colliders, solids) and next_dynamic_colliders.size() == previous_dynamic_colliders.size()
	if same:
		for i in range(next_dynamic_colliders.size()):
			if next_dynamic_colliders[i] != previous_dynamic_colliders[i]:
				same = false
				break
	if same:
		return null
	var next = []
	for static_ in static_solids:
		next.append(static_)
	for _it1 in next_dynamic_colliders:
		var pos = _it1[0]
		var radius = _it1[1]
		next.append([pos, radius, true])
	previous_dynamic_colliders.clear()
	previous_dynamic_colliders.append_array(next_dynamic_colliders)
	previous_static_colliders = static_solids
	previous_static_count = static_solids.size()
	previous_built_colliders = next
	return next

# ---- src/world/WorldGeometry.FastMove.cs
# Owner: Vu Duc Viet Anh. Typed copies of the colliders (Solids and Buckets) for the moves made every tick: each
# enemy, bot and player body is slid along the scenery and the base walls up to twice a tick, so at night with
# dozens of enemies the dynamic versions (WorldGeometry.Resolve / MoveBody) kept a laptop's CPU flat out. Same
# sums in the same order, so every body ends up exactly where the dynamic versions put it.
var solid_t = []
var bucket_t = {}
var near_t = []
var seen_t = []
var stamp_t: int = 0

# after Rebuild has filled Solids and Buckets
func mirror_solids() -> void:
	var n: int = solids.size()
	solid_t = Cs.arr(n, null)
	for i in range(n):
		var s = solids[i]
		solid_t[i] = [Vector2(s[0]), float(s[1])]
	seen_t = Cs.arr(n, 0)
	stamp_t = 0
	bucket_t.clear()
	for key in buckets.keys():
		var list = buckets[key]
		var ids = Cs.arr(list.size(), 0)
		for i in range(ids.size()):
			ids[i] = int(list[i])
		bucket_t[Vector2i(key)] = ids

# Candidates(): the solids in the cells round the segment, each once, in the order they are first met
func candidates_fast(a: Vector2, b: Vector2, radius: float) -> Variant:
	near_t.clear()
	stamp_t += 1
	if stamp_t == 2147483647:
		Cs.array_clear(seen_t)
		stamp_t = 1
	var cell: float = float(CELL)
	var lo = Vector2i(((a.min(b) - Vector2.ONE * radius) / cell).floor())
	var hi = Vector2i(((a.max(b) + Vector2.ONE * radius) / cell).floor())
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var ids = bucket_t.get(Vector2i(x, y), null)
			if not bucket_t.has(Vector2i(x, y)):
				continue
			for i in ids:
				if seen_t[i] == stamp_t:
					continue
				seen_t[i] = stamp_t
				near_t.append(i)
	return near_t

# Resolve(), typed
func resolve_fast(pos: Vector2, radius: float) -> Vector2:
	var nearby = candidates_fast(pos, pos, radius + 32.0)
	for pass_ in range(3):
		for i in nearby:
			var _d1 = solid_t[i]
			var c = _d1[0]
			var r = _d1[1]
			var d: Vector2 = pos - c
			var need: float = radius + r
			if d.length_squared() < need * need:
				pos = c + (d.normalized() if d.length_squared() > 0.0001 else Vector2.DOWN) * need
	return pos

# MoveBody(), typed: 4-pixel steps, each pushed out of the scenery and then of the wall pieces
func move_body_fast(from: Vector2, to: Vector2, radius: float, walls) -> Vector2:
	var count: int = maxi(1, ceili(from.distance_to(to) / 4.0))
	var step: Vector2 = (to - from) / count
	var pos: Vector2 = from
	for i in range(count):
		var next: Vector2 = resolve_fast(pos + step, radius)
		for w in walls:
			var q: Vector2 = next.clamp(w.position, w.end)
			var d: Vector2 = next - q
			if d.length_squared() < radius * radius and d.length_squared() > 1e-06:
				next = q + d.normalized() * radius
		pos = next
	return pos

# ---- src/world/WorldGeometry.FastNavigation.cs
# Typed navigation shares the collision snapshot used by FastMove. No dictionary/Variant conversions
# inside the grid raster or segment checks; a coastline mask survives resource/tower changes.
const NAV_REACH: int = 128
const NAV_WIDTH: int = 257
var fast_grids = {}
var sea_cells = {}

var navigation_grid_builds: int = 0

var navigation_path_searches: int = 0

func invalidate_fast_navigation() -> void:
	for entry in fast_grids.values():
		pass
	fast_grids.clear()

func get_navigation_grid(radius: float, walls) -> Variant:
	var cached = fast_grids.get([radius, walls], null)
	if fast_grids.has([radius, walls]):
		return cached
	var grid = Cs.init(AStarGrid2D.new(), {"region": Rect2i(-NAV_REACH, -NAV_REACH, NAV_WIDTH, NAV_WIDTH), "cell_size": Vector2.ONE * 32, "diagonal_mode": AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES})
	grid.update()
	var sea = sea_cells.get(radius, null)
	if not sea_cells.has(radius):
		var cells = []
		for y in range(-NAV_REACH, NAV_REACH + 1):
			var start: int = -2147483648
			for x in range(-NAV_REACH, NAV_REACH + 2):
				var solid_: bool = x <= NAV_REACH and not IslandMap.on_land(Vector2(x, y) * 32, radius)
				if solid_ and start == -2147483648:
					start = x
				if not solid_ and start != -2147483648:
					cells.append(Rect2i(start, y, x - start, 1))
					start = -2147483648
		sea = Array(cells).duplicate()
		sea_cells[radius] = sea
	# Fill contiguous sea spans; no interop call for every ocean cell.
	for span in sea:
		grid.fill_solid_region(span)
	for _it1 in solid_t:
		var centre = _it1[0]
		var solid_radius = _it1[1]
		var reach: float = solid_radius + radius + 1
		var lo = Vector2i(((centre - Vector2.ONE * reach) / 32).floor())
		var hi = Vector2i(((centre + Vector2.ONE * reach) / 32).ceil())
		for y in range(maxi(-NAV_REACH, lo.y), mini(NAV_REACH, hi.y) + 1):
			for x in range(maxi(-NAV_REACH, lo.x), mini(NAV_REACH, hi.x) + 1):
				if (Vector2(x, y) * 32).distance_squared_to(centre) < reach * reach:
					grid.set_point_solid(Vector2i(x, y))
	for wall in walls:
		var box: Rect2 = wall.grow(radius + 1)
		var lo = Vector2i((box.position / 32).floor())
		var hi = Vector2i((box.end / 32).ceil())
		for y in range(maxi(-NAV_REACH, lo.y), mini(NAV_REACH, hi.y) + 1):
			for x in range(maxi(-NAV_REACH, lo.x), mini(NAV_REACH, hi.x) + 1):
				if box.has_point(Vector2(x, y) * 32):
					grid.set_point_solid(Vector2i(x, y))
	var result = Cs.init(NavigationGrid.new(), {"grid": grid})
	fast_grids[[radius, walls]] = result
	navigation_grid_builds += 1
	return result

func waypoint_fast(from: Vector2, to: Vector2, radius: float, walls) -> Vector2:
	# The destination may be a resource/tower centre, as in the original Waypoint.
	if navigation_segment_clear(from, to, radius, walls, to):
		return to
	var cache = get_navigation_grid(radius, walls)
	var start: Vector2i = open_cell_fast(cache.grid, from)
	var end: Vector2i = open_cell_fast(cache.grid, to)
	var path = cache.paths.get([start, end], null)
	if not cache.paths.has([start, end]):
		var found = cache.grid.get_id_path(start, end, true)
		path = Array(found).duplicate()
		navigation_path_searches += 1
		if cache.paths.size() >= 512:
			cache.paths.clear()
		cache.paths[[start, end]] = path
	for i in range(mini(path.size() - 1, 5), -1, -1):
		var p: Vector2 = Vector2(path[i]) * 32
		if from.distance_squared_to(p) >= 4 and navigation_segment_clear(from, p, radius, walls, Vector2.INF):
			return p
	# Keep the original slide-out fallback when a body is pressed against scenery.
	for i in range(mini(path.size() - 1, 1), -1, -1):
		var p: Vector2 = Vector2(path[i]) * 32
		if from.distance_squared_to(p) >= 4:
			return p
	return from

func navigation_segment_clear(from: Vector2, to: Vector2, radius: float, walls, ignore: Vector2) -> bool:
	var step: Vector2 = to - from
	var length2: float = step.length_squared()
	for i in candidates_fast(from, to, radius):
		var _d1 = solid_t[i]
		var centre = _d1[0]
		var r = _d1[1]
		if r <= 0 or centre.is_equal_approx(ignore):
			continue
		var start: Vector2 = from - centre
		var reach: float = radius + r
		if start.length_squared() <= reach * reach:
			return false
		if length2 < 0.000001:
			continue
		var dot: float = start.dot(step)
		var disc: float = dot * dot - length2 * (start.length_squared() - reach * reach)
		if disc < 0:
			continue
		var hit: float = (-dot - sqrt(disc)) / length2
		if hit >= 0 and hit <= 1:
			return false
	for wall in walls:
		if segment_box_fast(from, to, wall.grow(radius)):
			return false
	# no short cut over the water: the sea, and the rivers beside their bridges (IslandMap.OnLand)
	var samples: int = int(sqrt(length2) / 12.0) + 1
	for k in range(1, samples + 1):
		if not IslandMap.on_land(from + step * (float(k) / samples), radius * 0.9):
			return false
	return true

static func segment_box_fast(a: Vector2, b: Vector2, box: Rect2) -> bool:
	var enter: float = 0
	var leave: float = 1
	var step: Vector2 = b - a
	for axis in range(2):
		if absf(step[axis]) < 0.00001:
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]:
				return false
		else:
			var t0: float = (box.position[axis] - a[axis]) / step[axis]
			var t1: float = (box.end[axis] - a[axis]) / step[axis]
			enter = maxf(enter, minf(t0, t1))
			leave = minf(leave, maxf(t0, t1))
			if enter > leave:
				return false
	return true

static func open_cell_fast(grid, pos: Vector2) -> Vector2i:
	var cell = Vector2i((pos / 32).round())
	for ring in range(7):
		var best: Vector2i = cell
		var distance: float = INF
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				var c = cell + Vector2i(x, y)
				if not grid.is_in_boundsv(c) or grid.is_point_solid(c):
					continue
				var d: float = (Vector2(c) * 32).distance_squared_to(pos)
				if d < distance:
					distance = d
					best = c
		if is_finite(distance):
			return best
	return cell

# ---- src/world/WorldHerbGarden.cs
static var garden_half: Vector2 = Vector2(8 * TL, 6 * TL)

var garden_centre: Vector2 = Vector2.ZERO

var garden_bounds: Rect2:
	get:
		return Rect2(garden_centre - garden_half, garden_half * 2)

var garden_entrance: Vector2:
	get:
		return garden_centre + Vector2(0, garden_half.y)
var garden_beds = []
var garden_fence = []

func build_abandoned_garden() -> void:
	garden_centre = at(18).round()
	lm_at[18] = garden_centre
	garden_beds.clear()
	garden_fence.clear()
	for y in [-3.8, -0.3, 3.2]:
		for side in [-1, 1]:
			garden_beds.append(Rect2(garden_centre + tl(side * 4.3 - 2.5, y - 1.1), tl(5, 2.2)))
	var nw: Vector2 = garden_bounds.position
	var se: Vector2 = garden_bounds.end
	_build_abandoned_garden_fence(nw, Vector2(se.x, nw.y))
	_build_abandoned_garden_fence(nw, Vector2(nw.x, se.y))
	_build_abandoned_garden_fence(Vector2(se.x, nw.y), se)
	_build_abandoned_garden_fence(Vector2(nw.x, se.y), garden_entrance - tl(1.5, 0))
	_build_abandoned_garden_fence(garden_entrance + tl(1.5, 0), se)
	prop(garden_entrance, "lm_arch_0")
	solid(garden_entrance + Vector2(-46, 0), 8)
	solid(garden_entrance + Vector2(46, 0), 8)
	prop(garden_centre + tl(-6.7, -5.0), "lm_waterpump_0")
	prop(garden_centre + tl(6.7, -5.0), "lm_rainbarrel_0")
	prop(garden_centre + tl(6.5, 5.0), "lm_pots_0")
	prop(garden_centre + tl(-6.5, 5.0), "lm_can_0")
	clear(garden_centre, garden_half.length() + TL)
	compound_entrances[18] = garden_entrance + tl(0, 1.2)

# local function Fence of the method above
func _build_abandoned_garden_fence(a: Vector2, b: Vector2) -> void:
	compound_line(a, b, 8)
	var n: int = maxi(1, int(ceilf(a.distance_to(b) / (1.6 * TL))))
	for i in range(n):
		garden_fence.append([a.lerp(b, i / float(n)).round(), a.lerp(b, (i + 1.0) / n).round()])

func add_garden_herbs() -> void:
	var i: int = 0
	for bed in garden_beds:
		for y in [-0.43, 0.43]:
			for x in [-1.7, -0.57, 0.57, 1.7]:
				var p: Vector2 = (bed.get_center() + tl(x, y)).round()
				var _old1 = i
				i += 1
				harvest_sites.append(Harvestables.Site.new(p, "node_herb_" + Cs.s(_old1 % 2), 2, 0))

# ---- src/world/WorldHomeFarms.cs
static var home_farm_radii: Vector2 = Vector2(6 * TL, 5 * TL)
var home_farm_slots = [[], [], []]
static var home_farm_minimum = [36, 32, 36]
static var home_farm_centres = [find_home_farm_centre(0), find_home_farm_centre(1), find_home_farm_centre(2)]

static func home_farm_centre(type: int) -> Vector2:
	return home_farm_centres[type]

static func find_home_farm_centre(type: int) -> Vector2:
	var p: Vector2 = IslandMap.by_id(type + 2).pos
	while (p.abs() - Vector2(5.5, 3.5) * TL).max(Vector2.ZERO).length() > 14.5 * TL:
		p *= 0.96
	return p.round()

static func in_home_farm(p: Vector2, margin: float = 0) -> bool:
	for type in range(3):
		if in_home_farm_2(p, type, margin):
			return true
	return false

static func in_home_farm_2(p: Vector2, type: int, margin: float = 0) -> bool:
	return ((p - home_farm_centre(type)) / (home_farm_radii + Vector2.ONE * margin)).length_squared() <= 1

func build_home_farm_landmarks() -> void:
	var r = CsRandom.new(211)
	for type in range(3):
		var c: Vector2 = home_farm_centre(type)
		lm_at[type + 2] = c
		clear(c, home_farm_radii.x + 24)
		var slots = home_farm_slots[type]
		slots.clear()
		for side in range(-1, 2, 2):
			var y: float = 26
			while y < home_farm_radii.y - 12:
				var x: float = -162
				while x <= 162:
					var p: Vector2 = (c + Vector2(x + float(r.next_double()) * 2 - 1, side * y + float(r.next_double()) * 2 - 1)).round()
					if not in_home_farm_2(p, type, -22 if type == 1 else -14) or not IslandMap.on_grass(p, 18) or near_pad(p) or lane(p) or wall_dist(p) < 3 * TL:
						x += 36
						continue
					slots.append(p)
					x += 36
				y += 36
		# A fixed shuffle avoids rows of identical resources, while retaining a clear east-west aisle.
		for i in range(slots.size() - 1, 0, -1):
			var j: int = r.next(i + 1)
			var _t1 = slots[j]
			var _t2 = slots[i]
			slots[i] = _t1
			slots[j] = _t2
		prop(c + Vector2(home_farm_radii.x + 14, 52), "lm_signpost_0")
		if type == 0:
			prop(c + Vector2(-home_farm_radii.x - 4, 26), "lm_coconuts_0")

func ensure_home_farm_resources(primary_count: int = 0) -> void:
	for type in range(3):
		var have: int = harvest_sites.filter(func(s): return s.type == type and in_home_farm_2(s.pos, type)).size()
		var want: int = maxi(home_farm_minimum[type], primary_count)
		var slots = home_farm_slots[type]
		if want > slots.size():
			Cs.fail("Home farm %s supports %s nodes; requested %s. Reduce NodeMultiplier." % [type, slots.size(), want])
			return
		for i in range(have, want):
			var rock: int = (0 if i % 2 == 0 else 3) if absf(slots[i].y - home_farm_centre(type).y) < 40 else i % 5
			var radius: float = 6 if type == 0 else (13 if rock == 0 else 18 if rock == 1 else 17 if rock == 2 else 10 if rock == 3 else 19) if type == 1 else 0
			var sprite = "lm_palm_" + str(i % 4) if type == 0 else "rock_" + str(rock) if type == 1 else "node_herb_" + str(i % 2)
			harvest_sites.append(Harvestables.Site.new(slots[i], sprite, type, radius))
# Per material and region: exactly three quarters remain (rounding at most one node per group).
var outside_before = Cs.arr(3, 0)
# Per material and region: exactly three quarters remain (rounding at most one node per group).
var outside_after = Cs.arr(3, 0)
# Sites placed by hand in maps/island.tscn: the thinning never removes them, so what a designer puts in the
# editor stays in the game.
var hand_placed = {}

func thin_outside_resources() -> void:
	Cs.array_clear(outside_before)
	Cs.array_clear(outside_after)
	var groups = {}
	for s in harvest_sites:
		if s.type > 2 or in_home_farm(s.pos):
			continue
		var region: int = 180 + Cs.find_index(garden_beds, func(b): return b.has_point(s.pos)) if garden_bounds.has_point(s.pos) else 16 if in_cave_region(s.pos) else 0
		var key = [s.type, region]
		var group = groups.get(key, null)
		if not groups.has(key):
			group = []
			groups[key] = group
		group.append(s)
		outside_before[s.type] += 1
	var remove = {}
	for key in groups:
		var group = groups[key]
		var drop: int = int(Cs.round_even(group.size() * 0.25))
		# Spatial hashing distributes removals across the world instead of deleting one contiguous patch.
		Cs.sort_cmp(group, func(a, b): return Cs.compare(resource_order(a.pos), resource_order(b.pos)))
		var dropped: int = 0
		for i in range(drop):
			if not hand_placed.has(group[i]):
				Cs.set_add(remove, group[i])
				dropped += 1
		outside_after[key[0]] += group.size() - dropped
	Cs.remove_all(harvest_sites, func(s): return remove.has(s))
	var flat = []
	var outside: int = 0
	for d in scatter:
		var _c1 = in_home_farm(Vector2(d[0]))
		if not _c1:
			outside += 1
			_c1 = outside % 4 != 0
		if _c1:
			flat.append(d)
	scatter = flat

static func resource_order(p: Vector2) -> int:
	# C# uint arithmetic: wraps at 32 bits
	var h: int = Cs.u32(int(p.x) * 73856093 ^ int(p.y) * 19349663)
	h ^= h >> 16
	h = Cs.u32(h * 0x7feb352d)
	h ^= h >> 15
	return h

# ---- src/world/WorldLandmarkDetails.cs
# Owner: Vu Duc Viet Anh. Atlas landmarks get a silhouette, supporting props and a distinct ground treatment.
# These are fixed world decorations, not loot or usable machines. Added solid props stay off the paths.
static var landmark_soils = [LandmarkSoil.new(1, 12.0, 8.0, "83734F", true), LandmarkSoil.new(2, 6.8 / LANDMARK_SCALE, 5.7 / LANDMARK_SCALE, "A39761", true), LandmarkSoil.new(3, 6.8 / LANDMARK_SCALE, 5.7 / LANDMARK_SCALE, "B7B098", true), LandmarkSoil.new(4, 6.8 / LANDMARK_SCALE, 5.7 / LANDMARK_SCALE, "77965B", false), LandmarkSoil.new(5, 8.3 / LANDMARK_SCALE, 5.9 / LANDMARK_SCALE, "91836C", true), LandmarkSoil.new(6, 6.8, 4.8, "92917D", true), LandmarkSoil.new(7, 11.0 / LANDMARK_SCALE, 6.9 / LANDMARK_SCALE, "847254", true), LandmarkSoil.new(9, 6.7, 5.0, "8E8A7A", true), LandmarkSoil.new(10, 4.0, 3.8, "BBA77E", true), LandmarkSoil.new(11, 7.5 / LANDMARK_SCALE, 8.2 / LANDMARK_SCALE, "9A9881", true), LandmarkSoil.new(12, 7.1 / LANDMARK_SCALE, 5.5 / LANDMARK_SCALE, "CABCA3", true), LandmarkSoil.new(13, 9.1 * sqrt(YARD_AREA_SCALE), 5.8 * sqrt(YARD_AREA_SCALE), "828172", true), LandmarkSoil.new(14, 9.0, 4.5, "BBA77E", true), LandmarkSoil.new(15, 6.5, 4.8, "596047", true), LandmarkSoil.new(16, 7.5 * sqrt(CAVE_AREA_SCALE), 5.2 * sqrt(CAVE_AREA_SCALE), "65645D", true), LandmarkSoil.new(17, 7.0 / LANDMARK_SCALE, 6.4 / LANDMARK_SCALE, "829B98", true), LandmarkSoil.new(18, 8.0, 6.3, "796347", true)]

func soil_centre(soil) -> Vector2:
	return cave_centre if soil.id == 16 else lm_at[soil.id]

# Continuous core with a broken, feathered outer edge; never a faint green-tinted wash.
static func soil_coverage(soil, offset: Vector2) -> float:
	# Every point of the cave region is opaque rock, including its rim and eastern approach.
	if soil.id == 16:
		return 1 if cave_ground_contains(offset) else 0
	if soil.id == 12 or soil.id == 17:
		var distance: float = (offset / lookout_radii(soil.id)).length()
		return clampf((1.18 - distance) / 0.18, 0, 1)
	if soil.id == 5 or soil.id == 7 or soil.id == 11:
		# The complete designed footprint shares its centre with the map marker and the scene.
		# A rounded rectangle covers the outer vehicles and ledges, unlike the former small ellipse.
		var outside: Vector2 = (offset.abs() - expedition_half(soil.id)).max(Vector2.ZERO)
		return clampf(1 - outside.length() / TL, 0, 1)
	if soil.id == 2 or soil.id == 3 or soil.id == 4:
		var farm_distance: float = (offset / home_farm_radii).length()
		# The complete gathering footprint is opaque, with the feathering entirely outside it.
		return clampf((1.12 - farm_distance) / 0.12, 0, 1)
	if soil.id == 18:
		var garden_edge: Vector2 = offset.abs() / TL - garden_half / TL
		return clampf(1 - (maxf(garden_edge.x, garden_edge.y) - 0.25) / 1.25, 0, 1)
	if absf(offset.x) >= soil.rx * TL or absf(offset.y) >= soil.ry * TL:
		return 0
	var d: float = Vector2(offset.x / (soil.rx * TL), offset.y / (soil.ry * TL)).length()
	var angle: float = atan2(offset.y, offset.x)
	var edge: float = 0.94 + 0.035 * sin(angle * 5 + soil.id) + 0.025 * sin(angle * 9 - soil.id)
	return clampf((edge - d) / 0.18, 0, 1) * (1 if soil.bare else 0.38)

func bare_landmark_ground(p: Vector2) -> bool:
	for soil in landmark_soils:
		if soil.bare and lm_at.has(soil.id) and soil_coverage(soil, p - soil_centre(soil)) > 0.5:
			return true
	return false

func dress_landmarks() -> void:
	# 01: the outpost's exterior service corner; leave all three defence approaches open.
	dress_at(tl(-7.6, 5.8), "lm_generator_0", 12)
	dress_at(tl(-9.1, 5.5), "lm_cable_0", 9)
	dress_at(tl(7.9, 5.5), "lm_barricade_0")
	# 02..04: the compact home farms own their scenery and all their trees, stones and herbs are harvestable.
	# 05 and 07 supply their own centred recovery / convoy scenes.
	# 06: the expanded ruined compound supplies its own equipment and collapse debris.
	# 08: dense fern fans grow on the raised banks, never in the water or across a path.
	for i in range(15):
		var p: Vector2 = swamp_centre + Vector2.from_angle(i * 2.39996) * (0.35 + i * 0.035) * swamp_r
		if not near_path(p, 0.8 * TL):
			dress_at(p, "lm_fern_0")
	# 09: the walkable weather hut owns its equipment and a clear southern doorway.
	# 10: fishing gear on shore; the pier deck remains fully walkable.
	dress(10, 2.7, 3.1, "lm_boat_0")
	dress(10, 1.0, -2.7, "lm_buoys_0", 7)
	dress(10, 1.2, 2.6, "lm_rope_0")
	dress(10, 2.2, -2.2, "lm_lifering_0")
	# 11 owns the rocky terraces, stairs and wind markers.
	# 12 supplies its marine lookout, reef board and diving equipment.
	# 13: the expanded yard supplies its own crane, forklift and loading bays.
	# 14: an anchor, tender and ring identify the wreck's salvage beach.
	dress(14, -5.6, 3.1, "lm_anchor_0")
	dress(14, 2.7, 4.0, "lm_boat_0")
	dress(14, -1.1, 3.5, "lm_lifering_0")
	dress(14, 4.5, 3.0, "lm_rope_0")
	dress(14, -3.6, 2.8, "lm_scrap_0")
	# 15: a wet garden of ferns and pale flowers around the actual pond, with animated dragonflies.
	if ponds.size() > 0:
		for i in range(14):
			var p: Vector2 = ponds[0].centre + Vector2.from_angle(i * TAU / 14) * ponds[0].radius * Vector2(1.95, 1.55)
			if not near_path(p, 0.6 * TL):
				dress_at(p, "lm_flowers_1" if i % 3 == 0 else "lm_fern_0")
	# 16: the cave has a dedicated scree apron and survey cache.
	# The eastern cave entrance and resource fields are dressed by WorldCave.cs.
	# 17 supplies its compass terrace, beacon and signal equipment.
	# 18 supplies its own enclosed garden, gate, equipment and harvestable herb beds.

func dress(id: int, x: float, y: float, sprite, radius: float = 0) -> void:
	var c = lm_at.get(id, Vector2.ZERO)
	if lm_at.has(id):
		dress_at(c + tl(x, y) * LANDMARK_SCALE, sprite, radius)

func dress_at(p: Vector2, sprite, radius: float = 0) -> bool:
	# Reject rather than relocate: do not move set dressing into a doorway, a pool or a resource route.
	if not IslandMap.on_land(p, maxf(8, radius)) or near_pad(p) or lane(p):
		return false
	if not (terrain_at(p, maxf(6, radius)) == 0 or terrain_at(p, maxf(6, radius)) == 4 or terrain_at(p, maxf(6, radius)) == 6 or terrain_at(p, maxf(6, radius)) == 7 or terrain_at(p, maxf(6, radius)) == 9):
		return false
	if radius > 0:
		if near_path(p, radius + 12):
			return false
		for _it1 in lm_solids:
			var c = _it1[0]
			var r = _it1[1]
			if p.distance_to(c) < radius + r + 12:
				return false
		# Avoid overlapping the centres of the Atlas's existing props.
		for _it2 in lm_props:
			var c = _it2[0]
			if p.distance_to(c) < radius + 20:
				return false
	prop(p.round(), sprite)
	clear(p, maxf(14, radius + 14))
	return true

func flower_border(id: int, radius: float) -> void:
	var c = lm_at.get(id, Vector2.ZERO)
	if not lm_at.has(id):
		return
	radius *= LANDMARK_SCALE
	for i in range(24):
		var a: float = i * 2.39996
		var p: Vector2 = c + Vector2.from_angle(a) * (radius * (0.55 + i % 5 * 0.1)) * TL
		if not near_path(p, 0.8 * TL) and IslandMap.on_grass(p, 20):
			dress_at(p, "lm_flowers_" + str(i % 3))

# ---- src/world/WorldLandmarkScale.cs
const LANDMARK_AREA_SCALE: float = 1.5
# Area grows by 50%, so lengths grow by sqrt(1.5). Props retain their human scale.
const LANDMARK_SCALE: float = 1.2247449
var compounds = {}
var compound_entrances = {}

func build_expanded_site(id: int, build) -> void:
	var props: int = lm_props.size()
	var solids_: int = lm_solids.size()
	var clears: int = lm_clear.size()
	var step_start: int = steps.size()
	var reef_start: int = coral.size()
	build.call()
	var centre = lm_at.get(id, Vector2.ZERO)
	if not lm_at.has(id):
		return
	var old = lm_props.slice(props, props + (lm_props.size() - props))
	var shifts = Cs.arr(old.size(), Vector2.ZERO)
	for i in range(old.size()):
		var _d1 = old[i]
		var p = _d1[0]
		var sprite = _d1[1]
		var new: Vector2 = centre + (p - centre) * LANDMARK_SCALE
		# Coastal and river-bank sites grow inland; never push a prop into water or onto a trail.
		if not IslandMap.on_land(new, 12) or IslandMap.in_river(new, 12) or near_path(new, 16):
			new = p
		shifts[i] = new - p
		lm_props[props + i] = [new.round(), sprite]
	for i in range(solids_, lm_solids.size()):
		var _d2 = lm_solids[i]
		var p = _d2[0]
		var radius = _d2[1]
		lm_solids[i] = [p + _build_expanded_site_shift_for(p, old, shifts), radius]
	for i in range(clears, lm_clear.size()):
		var _d3 = lm_clear[i]
		var p = _d3[0]
		var radius = _d3[1]
		lm_clear[i] = [p + _build_expanded_site_shift_for(p, old, shifts), radius * LANDMARK_SCALE if radius > 2.8 * TL else radius]
	for i in range(step_start, steps.size()):
		var _d4 = steps[i]
		var p = _d4[0]
		var across = _d4[1]
		steps[i] = [centre + (p - centre) * LANDMARK_SCALE, across]
	for i in range(reef_start, coral.size()):
		var p: Vector2 = centre + (coral[i] - centre) * LANDMARK_SCALE
		if not IslandMap.on_land(p):
			coral[i] = p

# local function ShiftFor of the method above
func _build_expanded_site_shift_for(p: Vector2, old, shifts) -> Vector2:
	var nearest: int = -1
	var best: float = 3.4028235e38
	for i in range(old.size()):
		var d: float = p.distance_squared_to(old[i][0])
		if d < best:
			nearest = i
			best = d
	return Vector2.ZERO if nearest < 0 else shifts[nearest]

# Find room for the entire compound, not just its centre. Keep all corners and walls on dry ground.
func compound_spot(id: int, half: Vector2) -> Vector2:
	var want: Vector2 = at(id)
	var best: Vector2 = want
	var score: float = INF
	for y in range(-18, 19):
		for x in range(-18, 19):
			var p: Vector2 = want + tl(x * 0.5, y * 0.5)
			var cost: float = p.distance_squared_to(want)
			if cost >= score or IslandMap.in_river(p, 6 * TL):
				continue
			var fits: bool = true
			var dy: int = -1
			while dy <= 1 and fits:
				for dx in range(-1, 2):
					var q: Vector2 = p + Vector2(half.x * dx, half.y * dy)
					if not IslandMap.on_land(q, 20) or IslandMap.in_river(q, IslandMap.RIVER_BANK + 20) or near_pad(q) or in_clear(q, 16):
						fits = false
						break
				dy += 1
			# The rear wall and the west return must not occupy an existing route.
			if fits and (near_path(p + Vector2(0, -half.y + 14), half.x * 0.45) or near_path(p + Vector2(-half.x + 12, 0), half.y * 0.45)):
				cost += 200 * TL * TL
			if fits and cost < score:
				score = cost
				best = p
	if is_inf(score):
		Cs.fail("No dry footprint for landmark %s" % [id])
		return Vector2.ZERO
	return best.round()

func compound_line(a: Vector2, b: Vector2, radius: float) -> void:
	var n: int = maxi(1, int(ceilf(a.distance_to(b) / (radius * 1.45))))
	for i in range(n + 1):
		solid(a.lerp(b, float(i) / n), radius)

func connect_compounds() -> void:
	for _unused in compound_entrances:
		var entry = compound_entrances[_unused]
		var _d1 = on_path(entry)
		var road = _d1[0]
		footpath(road, entry)
	cut_paths_at_rivers()

# ---- src/world/WorldLandmarks.cs
# Owner: Vu Duc Viet Anh. The landmarks built on the island, after the Landmark Atlas (art/landmarks/ref/, sprites
# from tools/PixelLandmarks.cs): palms and fallen trunks in the Coconut Grove (02), limestone shelves (03),
# broad-leaf herbs along the meadow trail (04), the utility vehicle slid off the road (05), the ruined depot (06),
# the stranded convoy beside its track (07), mangroves in the swamp (08), the weather station (09), the old pier
# out over the sea with fish traps on the beach (10), stone steps between rocky shoulders (11), the lookout shelter
# over a coral reef (12), the container yard (13), the cargo ship on the beach (14), red ginger round the pond (15),
# the limestone bluff with the cave mouth (16), the concrete platform at the end of the south cape (17) and the
# old herb garden (18). The outpost (01) is the base.
# Everything is placed from the island's shape, the same on every run and every peer. Props stand in Deco with
# the other scenery (depth sorted, solid where index.json gives a radius, plus the circles here for the big ones);
# floors, the pier, the platform, the steps and the coral lie flat on the ground layer
# (src/world/view/Main.LandmarkView.cs). The pier is walkable: IslandMap.Docks.
# props: [world position, sprite name]
var lm_props = []
# flat sprites on the ground layer
var lm_ground = []
# built ground where nothing grows: the depot's and the yard's concrete (drawn), the platform (its sprite)
var floors = []
# stone steps across the Northwind Slope trail: [middle, across]
var steps = []
var coral = []
var lm_solids = []
# where each landmark's main structure stands (for --goto=lm:N)
var lm_at = {}
# no trees, rocks or grass inside these
var lm_clear = []
const S_: float = IslandMap.SCALE

func build_landmarks() -> void:
	lm_props.clear()
	compounds.clear()
	compound_entrances.clear()
	compound_boundaries.clear()
	compound_gates.clear()
	lm_ground.clear()
	floors.clear()
	steps.clear()
	coral.clear()
	lm_solids.clear()
	lm_clear.clear()
	IslandMap.docks.clear()
	lm_at.clear()
	expedition_sites.clear()
	expedition_vehicles.clear()
	expedition_cliffs.clear()
	lookouts.clear()
	lookout_objects.clear()
	lookout_rails.clear()
	lookout_placements.clear()
	reef_beds.clear()
	cape_gulls.clear()
	lm_at[1] = Vector2.ZERO
	var r = CsRandom.new(31)
	build_home_farm_landmarks()
	build_bayside_scene()
	ruined_base(r)
	build_convoy_scene()
	mangroves(r)
	build_weather_station()
	build_expanded_site(10, pier)
	build_northwind_scene()
	build_coral_lookout()
	container_yard()
	build_expanded_site(14, func(): shipwreck(r))
	pond_banks(r)
	cave()
	build_south_cape_lookout()
	herb_garden(r)
	dress_landmarks()
	build_ramps()
	dress_exploration()
	# Compound entrances join the existing trail network after their larger footprints have been placed.
	connect_compounds()

static func tl(x: float, y: float) -> Vector2:
	return Vector2(x, y) * TL

func prop(p: Vector2, sprite) -> void:
	lm_props.append([p, sprite])

func solid(c: Vector2, radius: float) -> void:
	lm_solids.append([c, radius])

func clear(c: Vector2, radius: float) -> void:
	lm_clear.append([c, radius])

func in_clear(p: Vector2, margin: float) -> bool:
	for _it1 in lm_clear:
		var c = _it1[0]
		var rr = _it1[1]
		if p.distance_to(c) < rr + margin:
			return true
	return false

# room for a structure of this radius: on the grass, off the paths, the door lanes and the pads, clear of the
# other landmarks' structures
func room(p: Vector2, radius: float, grass: float = 0.5) -> bool:
	return IslandMap.on_grass(p, radius * grass) and not near_path(p, radius) and not in_clear(p, radius) and not lane(p) and not near_pad(p) and float(wall_dist(p)) > float(SAFE_D) * 0.5

# the nearest spot to Want with room, searching out in rings of half a tile
func spot(want: Vector2, radius: float, grass: float = 0.5, reach: float = 14) -> Vector2:
	if room(want, radius, grass):
		return want
	var ring: float = 0.5
	while ring <= reach:
		var n: int = maxi(8, int(ring * 8))
		for i in range(n):
			var p: Vector2 = want + Vector2.from_angle(i * TAU / n) * ring * TL
			if room(p, radius, grass):
				return p
		ring += 0.5
	return want

# the nearest point on any route or trail, and which way it runs there
func on_path(p: Vector2) -> Variant:
	var best: float = INF
	var at_: Vector2 = p
	var along: Vector2 = Vector2.RIGHT
	for k in range(3, trails.size()):
		var path = trails[k][0]
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
func footpath(from: Vector2, to: Vector2) -> void:
	# not where a path already runs close by
	if from.distance_to(to) < 2 * TL or near_path(to, 1.5 * TL):
		return
	var pts = []
	var n: int = int(from.distance_to(to) / (0.5 * TL))
	var side = (to - from).normalized().orthogonal()
	for i in range(n + 1):
		var t: float = float(i) / n
		pts.append(from.lerp(to, t) + side * sin(t * PI) * 0.8 * TL)
	trails.append([Array(pts).duplicate(), TRAIL_W])

func at(id: int) -> Vector2:
	var _v1 = (IslandMap.by_id(id).pos if IslandMap.by_id(id) != null else null)
	return _v1 if _v1 != null else Vector2.ZERO

# --- 02 Coconut Grove: palms round the grove, a fallen trunk and dry branches by the trail
func in_grove(p: Vector2) -> bool:
	return p.distance_to(at(2)) < 13 * TL

func grove(r) -> void:
	var g: Vector2 = at(2)
	var log_: Vector2 = spot(g + tl(1.5, 2), 1.4 * TL)
	prop(log_, "lm_log_0")
	lm_at[2] = log_
	clear(log_, 1.6 * TL)
	for i in range(3):
		var p: Vector2 = spot(log_ + Vector2.from_angle(i * 2.1 + 0.4) * 2.2 * TL, 0.5 * TL)
		prop(p, "lm_sticks_0")
		clear(p, 0.5 * TL)
	for i in range(12):
		var p: Vector2 = g + Vector2.from_angle(float(r.next_double()) * TAU) * (2.5 + float(r.next_double()) * 8.5) * TL
		if not room(p, 0.8 * TL):
			continue
		prop(p, "lm_palm_" + str(i % 4))
		clear(p, 0.7 * TL)

# --- 03 Limestone Flats: low pale shelves breaking through the grass
func limestone_flats(r) -> void:
	var l: Vector2 = at(3)
	for i in range(5):
		var p: Vector2 = spot(l + Vector2.from_angle(i * 1.26 + 0.3) * (3.0 + i % 2 * 3.0) * TL, 2.2 * TL, 0.5, 7)
		prop(p, "lm_shelf_" + str(i % 3))
		if i == 0:
			lm_at[3] = p
		clear(p, 2.4 * TL)

# --- 04 Herb Meadow: broad-leaf herbs along the trail
func herb_meadow(r) -> void:
	var h: Vector2 = at(4)
	var placed: int = 0
	var tries: int = 0
	while tries < 300 and placed < 12:
		var p: Vector2 = h + Vector2.from_angle(float(r.next_double()) * TAU) * float(r.next_double()) * 8 * TL
		var _d1 = on_path(p)
		var on = _d1[0]
		var d: float = p.distance_to(on)
		if d < 1.7 * TL or d > 3.2 * TL or not IslandMap.on_grass(p, TL) or in_clear(p, 0.6 * TL) or near_pad(p):
			tries += 1
			continue
		prop(p, "lm_broadleaf_" + str(placed % 2))
		if placed == 0:
			lm_at[4] = p
		clear(p, 0.6 * TL)
		placed += 1
		tries += 1

# --- 06 Ruined Base: a concrete floor, broken walls behind and to the left, shelves and crates, the mast
func ruined_base(r) -> void:
	build_ruined_compound()

# --- 08 Mangrove Swamp: mangroves on their stilt roots round the pools
func mangroves(r) -> void:
	var placed: int = 0
	var tries: int = 0
	while tries < 400 and placed < 12:
		var p: Vector2 = swamp_centre + Vector2.from_angle(float(r.next_double()) * TAU) * sqrt(float(r.next_double())) * swamp_r
		if not IslandMap.on_grass(p, 0.6 * TL) or (terrain_at(p, 0.8 * TL) == 1 or terrain_at(p, 0.8 * TL) == 5) or in_clear(p, 1.4 * TL):
			tries += 1
			continue
		prop(p, "lm_mangrove_" + str(placed % 3))
		if placed == 0:
			lm_at[8] = p
		clear(p, 1.0 * TL)
		placed += 1
		tries += 1

# --- 10 Old Fishing Pier: out to sea from the west shore, fish traps on the beach
func pier() -> void:
	var m: Vector2 = at(10)
	# walk west to the waterline
	var shore: Vector2 = m
	while IslandMap.on_land(shore) and shore.x > m.x - 40 * TL:
		shore.x -= 0.25 * TL
	var land: Vector2 = (shore + tl(2.2, 0)).round()
	lm_ground.append([land, "lm_pier_0"])
	lm_at[10] = land
	# the deck: 224 px out from the land end, 48 px across (tools/PixelLandmarks.cs)
	IslandMap.docks.append(Rect2(land + Vector2(-224, -24) * LANDMARK_SCALE, Vector2(226, 48) * LANDMARK_SCALE))
	prop(land + tl(1.0, 1.6), "lm_trap_0")
	prop(land + tl(1.9, -1.5), "lm_trap_1")
	prop(land + tl(2.6, 1.2), "lm_trap_0")
	clear(land + tl(1.5, 0), 2.5 * TL)
	footpath(m, land + tl(0.6, 0))
	build_fishing_details(land)

# --- 13 Container Yard: a concrete yard, containers along the back, one open, drums and pallets
func container_yard() -> void:
	build_container_compound()

# --- 14 Beached Shipwreck: on the sand, the bow in the shallows, machinery washed up round it
func shipwreck(r) -> void:
	var m: Vector2 = at(14)
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
	prop(best, "lm_ship_0")
	lm_at[14] = best
	var x: float = -6.4
	while x <= 6.6:
		var q: Vector2 = best + tl(x, -0.6)
		if IslandMap.on_land(q, -TL):
			solid(q, 1.1 * TL)
		x += 1.2
	clear(best + tl(0, -1.5), 7.5 * TL)
	for _it1 in [[-4.5, 1.8, "lm_gear_0"], [1.5, 2.0, "lm_drum_1"], [2.4, 2.6, "lm_drum_1"], [5.2, 1.6, "lm_gear_0"], [-1.8, 2.4, "lm_crate_0"]]:
		var dx = _it1[0]
		var dy = _it1[1]
		var name = _it1[2]
		var p: Vector2 = best + tl(dx, dy)
		if IslandMap.on_land(p, 0.5 * TL):
			prop(p, name)

# --- 15 Rainwater Pond: red ginger and broad leaves on the damp banks
func pond_banks(r) -> void:
	if ponds.size() == 0:
		return
	var pd = ponds[0]
	lm_at[15] = pd.centre + Vector2(0, pd.radius * 1.4)
	for i in range(9):
		var p: Vector2 = pd.centre + Vector2.from_angle(i * TAU / 9 + 0.3) * pd.radius * Vector2(1.75, 1.45)
		if not IslandMap.on_grass(p, 0.5 * TL) or near_path(p, 0.3 * TL) or in_clear(p, 0.4 * TL):
			continue
		prop(p, "lm_broadleaf_1" if i % 3 == 0 else "lm_ginger_0")
		clear(p, 0.5 * TL)

# --- 16 Southwest Cave: the bluff over the mouth (the spires of WorldTerrain flank it)
func cave() -> void:
	build_cave_compound()

# --- 18 Abandoned Herb Garden: raised beds in a broken fence, a watering can left behind
func herb_garden(r) -> void:
	build_abandoned_garden()

# ---- src/world/WorldLookouts.cs
var lookouts = {}
var lookout_objects = []
var lookout_rails = []
var lookout_placements = []
var reef_beds = []
var cape_gulls = []
var cape_scarp_face = []
var cape_scarp_cap = []

static func lookout_radii(id: int) -> Vector2:
	return Vector2(188, 144) if id == 12 else Vector2(184, 168)

func lookout_spot(id: int) -> Vector2:
	var want: Vector2 = at(id) + (tl(-4, 12) if id == 17 else tl(3, -10))
	var half: Vector2 = lookout_radii(id)
	var best: Vector2 = want
	var score: float = INF
	# Fit the complete scene before placing anything; coastal props no longer get scattered independently.
	for y in range(-24, 25):
		for x in range(-24, 25):
			var c: Vector2 = (want + tl(x * 0.5, y * 0.5)).round()
			var cost: float = c.distance_squared_to(want)
			if cost >= score:
				continue
			var fits: bool = true
			var dy: int = -2
			while dy <= 2 and fits:
				for dx in range(-2, 3):
					var p: Vector2 = c + half * Vector2(dx * 0.5, dy * 0.5)
					if not IslandMap.on_land(p, 22) or IslandMap.in_river(p, 48) or in_clear(p, 12) or near_pad(p):
						fits = false
						break
				dy += 1
			if fits:
				score = cost
				best = c
	if is_inf(score):
		Cs.fail("No dry footprint for lookout %s" % [id])
		return Vector2.ZERO
	return best

func new_lookout(id: int, deck_half: Vector2) -> Variant:
	var c: Vector2 = lookout_spot(id)
	var half: Vector2 = lookout_radii(id)
	var outline = [c + Vector2(-112, -70), c + Vector2(112, -70), c + Vector2(112, 70), c + Vector2(-112, 70)] if id == 12 else [c + Vector2(-88, -98), c + Vector2(88, -98), c + Vector2(126, -60), c + Vector2(126, 60), c + Vector2(88, 98), c + Vector2(-88, 98), c + Vector2(-126, 60), c + Vector2(-126, -60)]
	var site = LookoutSite.new(id, c, half, Rect2(c - deck_half, deck_half * 2), outline)
	lookouts[id] = site
	lm_at[id] = c
	floors.append([site.deck, false])
	clear(c, half.length() + 32)
	compound_entrances[id] = c + Vector2(0, (1 if id == 12 else -1) * (half.y - 12))
	return site

func lookout_prop(site, offset: Vector2, sprite, foot_radius: float = 12) -> void:
	var p: Vector2 = site.centre + offset
	prop(p, sprite)
	lookout_placements.append([site.id, p, foot_radius])

func lookout_fixture(site, offset: Vector2, model: int, radius: float) -> void:
	var p: Vector2 = site.centre + offset
	lookout_objects.append(LookoutObject.new(site.id, model, p))
	lookout_placements.append([site.id, p, radius])
	if radius > 0:
		solid(p, radius)

func lookout_railing(id: int, a: Vector2, b: Vector2) -> void:
	compound_line(a, b, 7)
	var count: int = maxi(1, int(ceilf(a.distance_to(b) / 48)))
	var i: int = 0
	while i < count:
		lookout_rails.append(LookoutRail.new(id, a.lerp(b, i / float(count)), a.lerp(b, (i + 1.0) / count)))
		i += 1

func build_coral_lookout() -> void:
	var site = new_lookout(12, Vector2(112, 70))
	var c: Vector2 = site.centre
	# A bleached timber marine lookout, reef identification board and abandoned diving equipment.
	lookout_objects.append(LookoutObject.new(12, 0, c + Vector2(0, -48)))
	lookout_placements.append([12, c + Vector2(-48, -48), 9])
	lookout_placements.append([12, c + Vector2(48, -48), 9])
	solid(c + Vector2(-48, -48), 9)
	solid(c + Vector2(48, -48), 9)
	lookout_fixture(site, Vector2(-146, 24), 1, 15)
	lookout_fixture(site, Vector2(144, 45), 2, 18)
	lookout_fixture(site, Vector2(-69, 33), 6, 16)
	lookout_prop(site, Vector2(72, 17), "lm_scope_0", 9)
	lookout_prop(site, Vector2(-142, -67), "lm_buoys_0", 10)
	lookout_prop(site, Vector2(133, 81), "lm_lifering_0", 10)
	lookout_prop(site, Vector2(-106, 100), "lm_rope_0", 8)
	var e = site.outline
	lookout_railing(12, e[0], e[1])
	lookout_railing(12, e[0], e[3])
	lookout_railing(12, e[1], e[2])
	lookout_railing(12, e[3], c + Vector2(-48, 70))
	lookout_railing(12, c + Vector2(48, 70), e[2])
	var r = CsRandom.new(1212)
	var beds = []
	for y in range(-340, 341, 36):
		for x in range(-340, 441, 36):
			var p: Vector2 = c + Vector2(x + r.next(-14, 15), y + r.next(-14, 15))
			var d: float = IslandMap.depth(p)
			if d > -30 or d < -150 or IslandMap.in_river(p, 32):
				continue
			var bed = Cs.arr(12, Vector2.ZERO)
			var wet_: bool = true
			var size: float = 0.8 + float(r.next_double()) * 0.45
			for i in range(bed.size()):
				var a: float = i * TAU / bed.size()
				var edge: float = 0.88 + 0.15 * sin(i * 2.1 + x * 0.13 + y * 0.07)
				bed[i] = (p + Vector2(cos(a) * 23, sin(a) * 15) * size * edge).round()
				if IslandMap.on_land(bed[i], -8):
					wet_ = false
			if not wet_:
				continue
			beds.append([p.round(), bed])
	Cs.sort_cmp(beds, func(a, b): return Cs.compare(a[0].distance_squared_to(c), b[0].distance_squared_to(c)))
	var i: int = 0
	while i < mini(42, beds.size()):
		coral.append(beds[i][0])
		reef_beds.append(beds[i][1])
		i += 1

func build_south_cape_lookout() -> void:
	var site = new_lookout(17, Vector2(126, 98))
	var c: Vector2 = site.centre
	# Cold slate, a compass terrace, a navigation beacon and storm-worn signal equipment.
	lookout_fixture(site, Vector2(110, 28), 3, 21)
	lookout_fixture(site, Vector2(-128, -86), 4, 8)
	lookout_fixture(site, Vector2(116, -88), 5, 14)
	lookout_fixture(site, Vector2(-94, 96), 6, 16)
	lookout_prop(site, Vector2(-82, 17), "lm_scope_0", 9)
	lookout_prop(site, Vector2(125, 107), "lm_lifering_0", 8)
	lookout_prop(site, Vector2(-139, 48), "lm_rope_0", 8)
	var e = site.outline
	for i in range(1, e.size()):
		lookout_railing(17, e[i], e[(i + 1) % e.size()])
	# North is the landward approach; preserve a wide gap in the parapet.
	lookout_railing(17, e[0], c + Vector2(-48, -98))
	lookout_railing(17, c + Vector2(48, -98), e[1])
	var rim = [Vector2(-138, 77), Vector2(-104, 124), Vector2(-54, 147), Vector2(45, 144), Vector2(124, 110), Vector2(151, 59)]
	cape_scarp_face = Cs.arr(rim.size() * 2, Vector2.ZERO)
	cape_scarp_cap = Cs.arr(rim.size() * 2, Vector2.ZERO)
	for i in range(rim.size()):
		var p: Vector2 = c + rim[i]
		cape_scarp_face[i] = p
		cape_scarp_face[-(i + 1)] = p + Vector2(0, 12)
		cape_scarp_cap[i] = p
		cape_scarp_cap[-(i + 1)] = p - Vector2(0, 14)
	for i in range(5):
		for y in range(180, 601, 12):
			var p: Vector2 = c + Vector2(-240 + i * 120, y)
			if IslandMap.on_land(p, -48):
				continue
			cape_gulls.append(p)
			break

func in_lookout_passage(p: Vector2) -> bool:
	for site in lookouts.values():
		if absf(p.x - site.centre.x) < 32 and Cs.has_point(site.deck.grow(90), p):
			return true
	return false

# ---- src/world/WorldRivers.cs
# Owner: Vu Duc Viet Anh. Where the paths meet the rivers (src/world/IslandRivers.cs). A path that crosses on a
# bridge runs on over it. A path the water cuts anywhere else stops at the bank and turns along it to the nearest
# bridge on that side, so no path just ends at the water; one too far from any bridge ends at the bank.
# the longest walk along a bank to a bridge, in tiles
const BANK_WALK: float = 45.0

func cut_paths_at_rivers() -> void:
	if IslandMap.rivers.size() == 0:
		return
	var out = []
	var extra = []
	var k: int = 0
	while k < trails.size():
		var _d1 = trails[k]
		var path = _d1[0]
		var width = _d1[1]
		var pieces = cut_path(path, width)
		# the first piece keeps the path's place in the list (the door roads are the first three)
		out.append([pieces[0], width] if pieces.size() > 0 else [path, width])
		var i: int = 1
		while i < pieces.size():
			extra.append([pieces[i], width])
			i += 1
		k += 1
	trails.clear()
	trails.append_array(out)
	trails.append_array(extra)

func wet(p: Vector2, width: float) -> bool:
	return IslandMap.in_river(p, IslandMap.RIVER_BANK + width / 2) and not IslandMap.near_bridge(p)

func cut_path(path, width: float) -> Variant:
	var pieces = []
	var i: int = 0
	while i < path.size():
		while i < path.size() and wet(path[i], width):
			i += 1
		var start: int = i
		while i < path.size() and not wet(path[i], width):
			i += 1
		if i - start < 2:
			continue
		var piece = Array(path.slice(start, i)).duplicate()
		# cut by water at either end: turn along the bank to a bridge
		if i < path.size():
			piece.append_array(bank_walk(path[i - 1], width))
		if start > 0:
			var before = bank_walk(path[start], width)
			before.reverse()
			Cs.insert_range(piece, 0, before)
		pieces.append(Array(piece).duplicate())
	if pieces.size() == 0:
		pieces.append(path)
	return pieces

# From a path's last dry point by a river, along that bank to the nearest bridge on the river (empty when
# there is none near enough, or the bank runs into the sea first).
func bank_walk(from: Vector2, width: float) -> Variant:
	var walk = []
	var best: int = -1
	var at_: int = 0
	var bd: float = 3.4028235e38
	for r in range(IslandMap.rivers.size()):
		var p = IslandMap.rivers[r]
		for j in range(p.size()):
			var d: float = p[j].distance_squared_to(from)
			if d < bd:
				bd = d
				best = r
				at_ = j
	if best < 0:
		return walk
	var river = IslandMap.rivers[best]
	var target: int = -1
	var steps_: float = 3.4028235e38
	for _it1 in IslandMap.bridges:
		var r = _it1[0]
		var bridge = _it1[1]
		if r != best:
			continue
		var bi: int = 0
		var bbd: float = 3.4028235e38
		for j in range(river.size()):
			var d: float = river[j].distance_squared_to(bridge)
			if d < bbd:
				bbd = d
				bi = j
		if absi(bi - at_) < steps_:
			steps_ = absi(bi - at_)
			target = bi
	# the river's points are half a tile apart
	if target < 0 or steps_ * 0.5 > BANK_WALK:
		return walk
	var side: float = signf((from - river[at_]).dot(_bank_walk_normal(at_, river)))
	if side == 0:
		side = 1
	var off: float = IslandMap.RIVER_HALF + IslandMap.RIVER_BANK + width / 2 + 0.3 * TL
	var dir: int = signi(target - at_)
	# every other point (a tile apart), stopping where the bridge's deck begins
	var j: int = at_
	while j != target:
		if (j - at_) % 2 != 0:
			j += dir
			continue
		var p: Vector2 = river[j] + _bank_walk_normal(j, river) * side * off
		if IslandMap.depth(p) < TL:
			return []
		if IslandMap.near_bridge(p, 0.5 * TL):
			break
		walk.append(p)
		j += dir
	# onto the end of the deck
	var deck: Vector2 = river[target] + _bank_walk_normal(target, river) * side * (IslandMap.BRIDGE_HALF_LEN - 0.5 * TL)
	walk.append(deck)
	return walk

# local function Normal of the method above
func _bank_walk_normal(j: int, river) -> Vector2:
	var along: Vector2 = (river[mini(j + 1, river.size() - 1)] - river[maxi(j - 1, 0)]).normalized()
	return Vector2(-along.y, along.x)

# ---- src/world/WorldTerrain.cs
# Owner: Vu Duc Viet Anh. Terrain of the island from the level-design map (src/world/IslandMap.cs): beaches and the
# sea around them, walkable hills, the three main gathering routes and the exploration trails, dirt roads out
# along the three door axes (the boss approaches), the Rainwater Pond and the pools of the Mangrove Swamp, and
# the rock spires round the Southwest Cave.
# Everything is fixed (same on every run and every peer). The roads keep the door corridors clear, so the three
# doors stay equally hard to defend (H10). Collision uses the same solid circles as trees and rocks; the sea is
# kept out by IslandMap.Keep. Water stops movement but not arrows or spit.
const TL: float = 32.0
const ROUTE_W: float = 2.2 * TL  # main gathering routes and the door roads
const TRAIL_W: float = 1.3 * TL  # exploration trails
var ponds = []
# [path, width]: the main routes and the door roads first, then the exploration trails
var trails = []
var crags = []
# the swamp's muddy ground
var swamp_centre: Vector2 = Vector2.INF
var swamp_r: float = 6.0 * TL

static func tiles(x: float, y: float) -> Vector2:
	return Vector2(x, y) * TL
# sizes round the landmarks grow with the island
const S: float = IslandMap.SCALE

func build_terrain() -> void:
	ponds.clear()
	trails.clear()
	crags.clear()
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
		trails.append([Array(pts).duplicate(), ROUTE_W])
	for rt in IslandMap.routes:
		trails.append([rt, ROUTE_W])
	for tr in IslandMap.trails:
		trails.append([tr, TRAIL_W])
	# paths cut by a river turn along its bank to a bridge (WorldRivers.cs)
	cut_paths_at_rivers()
	# the Rainwater Pond, just off the trail at landmark 15
	var rain = IslandMap.by_id(15)
	if rain != null:
		ponds.append(make_pond(r, rain.pos + tiles(4.2, 0.8) * S, 2.8 * 1.25 * LANDMARK_SCALE))
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
					swamp_centre = p
		swamp_r = clampf(IslandMap.grass_in(swamp_centre) - TL, 3 * TL, 7 * S * TL * LANDMARK_SCALE)
	if swamp != null:
		var i: int = 0
		var tries: int = 0
		while i < 9 and tries < 300:
			var c: Vector2 = swamp_centre + Vector2.from_angle(float(r.next_double()) * TAU) * float(r.next_double()) * (swamp_r - 2 * TL)
			var rad: float = 1.1 + float(r.next_double()) * 1.0
			if not IslandMap.on_grass(c, (rad + 1.5) * TL) or near_path(c, (rad + 1.6) * TL):
				tries += 1
				continue
			var clear_: bool = true
			for pd in ponds:
				if pd.centre.distance_to(c) < pd.radius + (rad + 1.5) * TL:
					clear_ = false
			if not clear_:
				tries += 1
				continue
			ponds.append(make_pond(r, c, rad))
			i += 1
			tries += 1
	# Southwest Cave now owns its walkable chamber and rock perimeter (WorldCave.cs).

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

func near_path(p: Vector2, reach: float) -> bool:
	for _it1 in trails:
		var path = _it1[0]
		var width = _it1[1]
		if IslandMap.path_dist(p, path) < reach + width / 2:
			return true
	return false

# --- queries ----------------------------------------------------------------
# What lies at P: 0 grass, 1 water (pond or pool), 4 hill, 5 path, 6 built floor, 7 beach, 8 sea, 9 swamp mud.
# Used for the minimap and to keep trees, grass and reeds where they belong.
func terrain_at(p: Vector2, margin: float = 0) -> int:
	if not IslandMap.on_land(p):
		return 8
	for _it1 in floors:
		var f = _it1[0]
		if Cs.has_point(f.grow(margin), p):
			return 6
	# a bridge's deck is a path; the rivers' muddy banks count as beach
	if IslandMap.near_bridge(p, margin) and IslandMap.in_river(p, IslandMap.RIVER_BANK + margin):
		return 5
	if not IslandMap.on_grass(p, margin):
		return 7
	for pd in ponds:
		if p.distance_to(pd.centre) < pd.radius * 1.6 + margin and IslandMap.in_polygon(pd.edge, p):
			return 1
	for _it2 in trails:
		var path = _it2[0]
		var width = _it2[1]
		if IslandMap.path_dist(p, path) < width / 2 + margin:
			return 5
	if p.distance_to(swamp_centre) < swamp_r:
		return 9
	for h in IslandMap.hills:
		if h.rings.size() > 0 and p.distance_to(h.top) < 14 * S * TL and IslandMap.in_polygon(h.rings[0], p):
			return 4
	return 0

# True where scenery (trees, rocks, grass tufts) must not be placed.
func terrain_blocked(p: Vector2, margin: float) -> bool:
	if in_cave_region(p, margin):
		return true
	if IslandMap.in_bridge_approach(p, margin):
		return true
	var k: int = terrain_at(p, margin)
	if k != 0 and k != 4 and k != 9:
		return true
	for c in crags:
		if p.distance_to(c) < TL + margin:
			return true
	return in_clear(p, margin)

# Solid circles: ponds and pools. Crags are added with the other scenery from their sprites' radius.
func add_terrain_solids(into) -> void:
	# three circles across each (they are wider than tall)
	for pd in ponds:
		for k in [-0.45, 0.0, 0.45]:
			into.append([pd.centre + Vector2(k * pd.radius, 0), pd.radius * 0.85, false])
	# the landmarks' big structures (WorldLandmarks.cs)
	for _it1 in lm_solids:
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

# ---- src/world/WorldWeatherStation.cs
static var weather_half: Vector2 = Vector2(144, 112)

var weather_centre: Vector2 = Vector2.ZERO

var weather_room: Rect2:
	get:
		return Rect2(weather_centre - weather_half, weather_half * 2)

var weather_entrance: Vector2:
	get:
		return weather_centre + Vector2(0, weather_half.y)

var weather_visibility: Rect2:
	get:
		return Rect2(weather_room.position - Vector2(12, 66), weather_room.size + Vector2(24, 80))
var weather_walls = []
var weather_wall_faces = []

func is_weather_interior(p: Vector2) -> bool:
	return Cs.has_point(weather_room.grow(-10), p)

func build_weather_station() -> void:
	weather_centre = compound_spot(9, weather_half + Vector2(56, 80))
	lm_at[9] = weather_centre
	compounds[9] = weather_room
	weather_walls.clear()
	weather_wall_faces.clear()
	var nw: Vector2 = weather_room.position
	var se: Vector2 = weather_room.end
	_build_weather_station_wall(nw, Vector2(se.x, nw.y))
	_build_weather_station_wall(nw, Vector2(nw.x, se.y))
	_build_weather_station_wall(Vector2(se.x, nw.y), se)
	_build_weather_station_wall(Vector2(nw.x, se.y), weather_entrance - Vector2(42, 0))
	_build_weather_station_wall(weather_entrance + Vector2(42, 0), se)
	floors.append([weather_room, false])
	clear(weather_centre, 8 * TL)
	compound_entrances[9] = weather_entrance + Vector2(0, 40)
	# Scenery only: these names have no harvest, use, loot or crafting behaviour.
	prop(weather_centre + Vector2(-76, -55), "lm_console_0")
	prop(weather_centre + Vector2(78, -61), "lm_rack_0")
	solid(weather_centre + Vector2(-76, -55), 24)
	solid(weather_centre + Vector2(78, -61), 22)
	prop(weather_centre + Vector2(104, 35), "lm_crate_0")
	solid(weather_centre + Vector2(104, 35), 16)
	prop(weather_centre + Vector2(-224, -16), "lm_radar_0")
	solid(weather_centre + Vector2(-224, -16), 14)
	prop(weather_centre + Vector2(220, 20), "lm_solar_0")
	solid(weather_centre + Vector2(220, 20), 15)
	prop(weather_centre + Vector2(205, -112), "lm_windsock_0")
	solid(weather_centre + Vector2(205, -112), 5)

# local function Wall of the method above
func _build_weather_station_wall(a: Vector2, b: Vector2) -> void:
	weather_walls.append([a, b])
	compound_line(a, b, 9)
	weather_wall_faces.append([a, b, b - Vector2(0, 56), a - Vector2(0, 56)])

class CompoundBoundary:
	var id: int
	var side: int
	var a: Vector2
	var b: Vector2
	var height: float
	var face
	var cap
	var wire

	func _init(p_id = 0, p_side = 0, p_a = Vector2.ZERO, p_b = Vector2.ZERO, p_height = 0.0, p_face = null, p_cap = null, p_wire = null) -> void:
		id = p_id
		side = p_side
		a = p_a
		b = p_b
		height = p_height
		face = p_face
		cap = p_cap
		wire = p_wire

class ExpeditionSite:
	var id: int
	var centre: Vector2
	var half: Vector2

	func _init(p_id = 0, p_centre = Vector2.ZERO, p_half = Vector2.ZERO) -> void:
		id = p_id
		centre = p_centre
		half = p_half

class ExpeditionVehicle:
	var id: int
	var pos: Vector2
	var model: int
	var tilt: float

	func _init(p_id = 0, p_pos = Vector2.ZERO, p_model = 0, p_tilt = 0.0) -> void:
		id = p_id
		pos = p_pos
		model = p_model
		tilt = p_tilt

class ExpeditionCliff:
	var a: Vector2
	var b: Vector2
	var face
	var cap

	func _init(p_a = Vector2.ZERO, p_b = Vector2.ZERO, p_face = null, p_cap = null) -> void:
		a = p_a
		b = p_b
		face = p_face
		cap = p_cap

class NavigationGrid:
	var grid
	var paths = {}

class LandmarkSoil:

	var id: int = 0

	var rx: float = 0.0

	var ry: float = 0.0

	var hex

	var bare: bool = false

	func _init(id_: int = 0, rx_: float = 0.0, ry_: float = 0.0, hex_ = null, bare_: bool = false) -> void:
		self.id = id_
		self.rx = rx_ * WorldGeometry.LANDMARK_SCALE
		self.ry = ry_ * WorldGeometry.LANDMARK_SCALE
		self.hex = hex_
		self.bare = bare_

	func deconstruct(id_: int, rx_: float, ry_: float, hex_, bare_: bool) -> void:
		id_ = self.id
		rx_ = self.rx
		ry_ = self.ry
		hex_ = self.hex
		bare_ = self.bare

class LookoutSite:
	var id: int
	var centre: Vector2
	var radii: Vector2
	var deck: Rect2
	var outline

	func _init(p_id = 0, p_centre = Vector2.ZERO, p_radii = Vector2.ZERO, p_deck = Rect2(), p_outline = null) -> void:
		id = p_id
		centre = p_centre
		radii = p_radii
		deck = p_deck
		outline = p_outline

class LookoutObject:
	var id: int
	var model: int
	var pos: Vector2

	func _init(p_id = 0, p_model = 0, p_pos = Vector2.ZERO) -> void:
		id = p_id
		model = p_model
		pos = p_pos

class LookoutRail:
	var id: int
	var a: Vector2
	var b: Vector2

	func _init(p_id = 0, p_a = Vector2.ZERO, p_b = Vector2.ZERO) -> void:
		id = p_id
		a = p_a
		b = p_b

class Pond:
	var centre: Vector2 = Vector2.ZERO
	var edge  # closed outline
	var radius: float = 0.0  # a little inside the outline, for collision
