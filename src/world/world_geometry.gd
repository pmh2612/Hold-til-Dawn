class_name WorldGeometry
extends RefCounted

# Owner: Vu Duc Viet Anh. Shared world data. No rendering or SceneTree is needed on the dedicated server.
# This file keeps the data, collision, movement and navigation; each place of the island is built by its own
# static part (src/world/world_*.gd: cave, landmarks, lookouts, rivers...), which takes the world as `world`.
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
# a built wall is three solid circles one tile apart (src/gameplay/sim_walls.gd)
const WALL_PIECE: float = 0.55

var harvest_sites = []

# A cutaway cavern: the eastern opening leads west into a walkable chamber.
# The ground footprint is three times the previous cave clearing's area.
const CAVE_AREA_SCALE: float = 3.0
static var cave_radii: Vector2 = Vector2(7.5, 5.2) * LANDMARK_SCALE * sqrt(CAVE_AREA_SCALE) * TL

var cave_centre: Vector2 = Vector2.ZERO

var cave_entrance: Vector2:
	get:
		return cave_centre + WorldLandmarks.tl(12, 0)

var cave_floor = []

var cave_roof = []
var cave_roof_facets = []
var cave_roof_seams = []
var cave_exterior_masks = []

var cave_visibility_boundary = []
var cave_walls = []

# Another 50% of the current yard area, in addition to the earlier island-wide enlargement.
const YARD_AREA_SCALE: float = 1.5
var compound_boundaries = []
var compound_gates = {}

var expedition_sites = {}
var expedition_vehicles = []
var expedition_cliffs = []

var ramps = []

var fishing_rods = []
var fishing_fish = []
var fishing_litter = []
var fishing_litter_faces = []

var next_dynamic_colliders = []
var previous_dynamic_colliders = []
var previous_static_colliders
var previous_built_colliders
var previous_static_count: int = -1

# Owner: Vu Duc Viet Anh. Typed copies of the colliders (Solids and Buckets) for the moves made every tick: each
# enemy, bot and player body is slid along the scenery and the base walls up to twice a tick, so at night with
# dozens of enemies the dynamic versions (WorldGeometry.Resolve / MoveBody) kept a laptop's CPU flat out. Same
# sums in the same order, so every body ends up exactly where the dynamic versions put it.
var solid_t = []
var bucket_t = {}
var near_t = []
var seen_t = []
var stamp_t: int = 0

# Typed navigation shares the collision snapshot used by FastMove. No dictionary/Variant conversions
# inside the grid raster or segment checks; a coastline mask survives resource/tower changes.
const NAV_REACH: int = 128
const NAV_WIDTH: int = 257
var fast_grids = {}
var sea_cells = {}

var navigation_grid_builds: int = 0

var navigation_path_searches: int = 0

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

static var home_farm_radii: Vector2 = Vector2(6 * TL, 5 * TL)
var home_farm_slots = [[], [], []]
# Per material and region: exactly three quarters remain (rounding at most one node per group).
var outside_before = Cs.arr(3, 0)
# Per material and region: exactly three quarters remain (rounding at most one node per group).
var outside_after = Cs.arr(3, 0)
# Sites placed by hand in maps/island.tscn: the thinning never removes them, so what a designer puts in the
# editor stays in the game.
var hand_placed = {}

# Owner: Vu Duc Viet Anh. Atlas landmarks get a silhouette, supporting props and a distinct ground treatment.
# These are fixed world decorations, not loot or usable machines. Added solid props stay off the paths.
static var landmark_soils = [LandmarkSoil.new(1, 12.0, 8.0, "83734F", true), LandmarkSoil.new(2, 6.8 / LANDMARK_SCALE, 5.7 / LANDMARK_SCALE, "A39761", true), LandmarkSoil.new(3, 6.8 / LANDMARK_SCALE, 5.7 / LANDMARK_SCALE, "B7B098", true), LandmarkSoil.new(4, 6.8 / LANDMARK_SCALE, 5.7 / LANDMARK_SCALE, "77965B", false), LandmarkSoil.new(5, 8.3 / LANDMARK_SCALE, 5.9 / LANDMARK_SCALE, "91836C", true), LandmarkSoil.new(6, 6.8, 4.8, "92917D", true), LandmarkSoil.new(7, 11.0 / LANDMARK_SCALE, 6.9 / LANDMARK_SCALE, "847254", true), LandmarkSoil.new(9, 6.7, 5.0, "8E8A7A", true), LandmarkSoil.new(10, 4.0, 3.8, "BBA77E", true), LandmarkSoil.new(11, 7.5 / LANDMARK_SCALE, 8.2 / LANDMARK_SCALE, "9A9881", true), LandmarkSoil.new(12, 7.1 / LANDMARK_SCALE, 5.5 / LANDMARK_SCALE, "CABCA3", true), LandmarkSoil.new(13, 9.1 * sqrt(YARD_AREA_SCALE), 5.8 * sqrt(YARD_AREA_SCALE), "828172", true), LandmarkSoil.new(14, 9.0, 4.5, "BBA77E", true), LandmarkSoil.new(15, 6.5, 4.8, "596047", true), LandmarkSoil.new(16, 7.5 * sqrt(CAVE_AREA_SCALE), 5.2 * sqrt(CAVE_AREA_SCALE), "65645D", true), LandmarkSoil.new(17, 7.0 / LANDMARK_SCALE, 6.4 / LANDMARK_SCALE, "829B98", true), LandmarkSoil.new(18, 8.0, 6.3, "796347", true)]

# Area grows by 50%, so lengths grow by sqrt(1.5). Props retain their human scale.
const LANDMARK_SCALE: float = 1.2247449
var compounds = {}
var compound_entrances = {}

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
# (src/world/view/landmark_view.gd). The pier is walkable: IslandMap.Docks.
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
var lookouts = {}
var lookout_objects = []
var lookout_rails = []
var lookout_placements = []
var reef_beds = []
var cape_gulls = []
var cape_scarp_face = []
var cape_scarp_cap = []

# Owner: Vu Duc Viet Anh. Terrain of the island from the level-design map (src/world/IslandMap.cs): beaches and the
# sea around them, walkable hills, the three main gathering routes and the exploration trails, dirt roads out
# along the three door axes (the boss approaches), the Rainwater Pond and the pools of the Mangrove Swamp, and
# the rock spires round the Southwest Cave.
# Everything is fixed (same on every run and every peer). The roads keep the door corridors clear, so the three
# doors stay equally hard to defend (H10). Collision uses the same solid circles as trees and rocks; the sea is
# kept out by IslandMap.Keep. Water stops movement but not arrows or spit.
const TL: float = 32.0
const TRAIL_W: float = 1.3 * TL  # exploration trails
var ponds = []
# [path, width]: the main routes and the door roads first, then the exploration trails
var trails = []
var crags = []
# the swamp's muddy ground
var swamp_centre: Vector2 = Vector2.INF
var swamp_r: float = 6.0 * TL

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

func _init() -> void:
	self.generate()

static func wall_dist(p) -> Variant:
	return Vector2(maxf(absf(p.x) - HALF.x, 0), maxf(absf(p.y) - HALF.y, 0)).length()

static func near_pad(p: Vector2) -> bool:
	for i in 3:
		if p.distance_to(Vector2(SimWorld.pad_pos(i))) < float(GameSim.PAD_R) + T:
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
	# paths, ponds, the swamp and the cave spires first, so the scenery grows around them (src/world/world_terrain.gd)
	WorldTerrain.build_terrain(self)
	# the landmarks' structures, so the scenery keeps clear of them (src/world/world_landmarks.gd)
	WorldLandmarks.build_landmarks(self)
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
	var free = func(p): return IslandMap.on_grass(p, 0.6 * T) and wall_dist(p) > 4 * T and not lane(p) and not WorldTerrain.terrain_blocked(self, p, 0.6 * T) and not near_pad(p)
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
				if WorldLandmarks.in_grove(self, p):
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
				deco.append([p, variant.call("lm_palm" if WorldLandmarks.in_grove(self, p) else pines[random.randi() % pines.size()], random.randi()), 1.0, COLD])
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
		var kind: int = WorldTerrain.terrain_at(self, p, 4.0)
		if WorldLandmarkDetails.bare_landmark_ground(self, p):
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
			if random.randf() < 0.6 and IslandMap.on_grass(bank) and not WorldTerrain.near_path(self, bank, 0.3 * T):
				deco.append([bank, variant.call("reed", random.randi()), 1.0, COLD])
			i += 2
	WorldExploration.fill_resource_gaps(self, variants)
	extract_harvestables(variants)
	WorldCave.add_cave_resources(self)
	WorldHerbGarden.add_garden_herbs(self)
	WorldHomeFarms.ensure_home_farm_resources(self)
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
	WorldTerrain.add_terrain_solids(self, static_solids)
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
	WorldHomeFarms.thin_outside_resources(self)
	static_solids.append([Vector2(0, 0.3 * T - 6), 22.0, true])
	# the workbench and the storage chest (src/world/sim_world.gd)
	for s in SimWorld.furniture_solids():
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

# --- the parts' functions that other scripts call on WorldGeometry ---
func in_cave_region(p: Vector2, margin: float = 0) -> bool:
	return WorldCave.in_cave_region(self, p, margin)

func in_cave_floor(p: Vector2) -> bool:
	return WorldCave.in_cave_floor(self, p)

func is_cave_interior(p: Vector2) -> bool:
	return WorldCave.is_cave_interior(self, p)

func cave_ground_colour(p: Vector2) -> Color:
	return WorldCave.cave_ground_colour(self, p)

func in_compound_passage(p: Vector2) -> bool:
	return WorldCompounds.in_compound_passage(self, p)

func in_expedition_aisle(p: Vector2) -> bool:
	return WorldExpeditionSites.in_expedition_aisle(self, p)

func ensure_home_farm_resources(primary_count: int = 0) -> void:
	WorldHomeFarms.ensure_home_farm_resources(self, primary_count)

func soil_centre(soil) -> Vector2:
	return WorldLandmarkDetails.soil_centre(self, soil)

# UI locations follow the built scene, rather than the original placement hint or an entrance prop.
# Keep lm_at as the entrance / interaction anchor used by gameplay and development teleport commands.
func landmark_centre(id: int) -> Vector2:
	if id == 16:
		return cave_centre
	if id == 8:
		return swamp_centre
	if id == 15 and not ponds.is_empty():
		return ponds[0].centre
	return lm_at.get(id, Vector2.INF)

func near_landmark(p: Vector2, reach: float) -> Variant:
	# The enlarged cave owns its complete rock footprint, including the eastern entrance.
	if in_cave_region(p):
		return IslandMap.by_id(16)
	var best = null
	var distance: float = reach * reach
	for location in IslandMap.landmarks:
		if not lm_at.has(location.id):
			continue
		var d: float = p.distance_squared_to(landmark_centre(location.id))
		if d < distance:
			distance = d
			best = location
	return null if best != null and best.id == 1 else best

func bare_landmark_ground(p: Vector2) -> bool:
	return WorldLandmarkDetails.bare_landmark_ground(self, p)

func prop(p: Vector2, sprite) -> void:
	WorldLandmarks.prop(self, p, sprite)

func solid(c: Vector2, radius: float) -> void:
	WorldLandmarks.solid(self, c, radius)

func clear(c: Vector2, radius: float) -> void:
	WorldLandmarks.clear(self, c, radius)

func room(p: Vector2, radius: float, grass: float = 0.5) -> bool:
	return WorldLandmarks.room(self, p, radius, grass)

func at(id: int) -> Vector2:
	return WorldLandmarks.at(self, id)

func herb_garden(r) -> void:
	WorldLandmarks.herb_garden(self, r)

func in_lookout_passage(p: Vector2) -> bool:
	return WorldLookouts.in_lookout_passage(self, p)

func terrain_at(p: Vector2, margin: float = 0) -> int:
	return WorldTerrain.terrain_at(self, p, margin)

func is_weather_interior(p: Vector2) -> bool:
	return WorldWeatherStation.is_weather_interior(self, p)

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
