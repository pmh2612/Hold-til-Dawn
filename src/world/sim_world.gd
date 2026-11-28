class_name SimWorld
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/world/GameSim.World.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
const STORAGE_REACH: float = 1.8 * T

# The wall pieces for each of the 8 ways the three doors can be open or shut, built once: bodies are pushed
# out of them several times a tick. Callers only read the arrays.
static var wall_sets = Cs.arr(8, null)
static var wall_rect_sets = Cs.arr(8, null)

# Primary wood, stone and herbs share the actual compact home-farm sites and their soil footprints.
# Titanium remains spread over five salvage landmarks, with additional fixed veins in Southwest Cave.
static var TITANIUM_SITES = [5, 6, 7, 13, 14]

static var outside_navigation_walls = [Rect2(-Vector2(HALF), Vector2(HALF) * 2)]

# constants shared with GameSim
const BENCH_REACH = GameSim.BENCH_REACH
const DOOR_GAP = GameSim.DOOR_GAP
const HALF = GameSim.HALF
const ISLAND = GameSim.ISLAND
const PAD_DIST = GameSim.PAD_DIST
const SAFE_D = GameSim.SAFE_D
const STORAGE_POS = GameSim.STORAGE_POS
const T = GameSim.T
const WALL_IN = GameSim.WALL_IN
const WALL_OUT = GameSim.WALL_OUT
const WORKBENCH_POS = GameSim.WORKBENCH_POS

static func near_bench(pos: Vector2) -> bool:
	return pos.distance_to(WORKBENCH_POS) <= BENCH_REACH

static func near_storage(pos: Vector2) -> bool:
	return pos.distance_to(STORAGE_POS) <= STORAGE_REACH

static func near_radio(pos: Vector2) -> bool:
	return pos.distance_squared_to(GameSim.RADIO_POS) <= GameSim.RADIO_REACH * GameSim.RADIO_REACH

# Colliders of the base furniture as [centre, radius]: a row of circles along the bench, two under the chest.
# They reach back to the wall so nobody slips behind.
static func furniture_solids() -> Variant:
	var out = []
	for x in [-19.0, -6.0, 6.0, 19.0]:
		out.append([WORKBENCH_POS + Vector2(x, -10.0), 12.0])
	for x in [-7.0, 7.0]:
		out.append([STORAGE_POS + Vector2(x, -7.0), 10.0])
	for x in [-20.0, -7.0, 7.0, 20.0]:
		out.append([GameSim.RADIO_POS + Vector2(x, -10.0), 12.0])
	return out

# --- helpers ------------------------------------------------------------
static func wall_dist(pos) -> Variant:
	# Distance to the nearest base wall (0 inside); every zone distance in the GDD uses this.
	return Vector2(maxf(absf(pos.x) - HALF.x, 0.0), maxf(absf(pos.y) - HALF.y, 0.0)).length()

static func in_door_lane(pos, half_width = null) -> Variant:
	if half_width == null: half_width = 1.5 * T
	# The 3-tile corridor in front of each door that stays clear (section 4.3).
	for i in 3:
		var rel: Vector2 = Vector2(pos - GameSim.DOOR_POS[i])
		var dd: Vector2 = Vector2(GameSim.DOOR_DIR[i])
		if rel.dot(dd) > 0 and absf(rel.dot(Vector2(-dd.y, dd.x))) < half_width:
			return true
	return false

static func rand_zone_point(sim: GameSim, lo, hi) -> Variant:
	# Random point lo..hi from the nearest base wall, on the island, off the door lanes and pads.
	for i in 400:
		var p = Vector2(sim.rng.randf_range(-ISLAND, ISLAND), sim.rng.randf_range(-ISLAND, ISLAND))
		var d = wall_dist(p)
		if d >= lo and d <= hi and IslandMap.on_grass(Vector2(p), 2 * T) and not in_door_lane(p) and not SimPhases.near_pad(sim, p):
			return p
	return Vector2(0, HALF.y + lo)

static func inside_base(pos, margin = null) -> Variant:
	if margin == null: margin = 0.0
	return absf(pos.x) < HALF.x + margin and absf(pos.y) < HALF.y + margin

# bit I set: door I is open
static func open_mask(open) -> int:
	var m: int = 0
	for i in range(3):
		if open[i]:
			m |= 1 << i
	return m

# doors open to bodies moving now: all by day, the broken ones at night
static func door_mask(sim: GameSim) -> int:
	var day: bool = sim.phase != "night"
	var m: int = 0
	for i in range(3):
		if day or float(sim.doors[i]) <= 0:
			m |= 1 << i
	return m

static func wall_rects(mask: int) -> Variant:
	if wall_rect_sets[mask] == null:
		var set = walls([mask & 1 != 0, mask & 2 != 0, mask & 4 != 0])
		var rects = Cs.arr(set.size(), Rect2())
		for i in range(rects.size()):
			rects[i] = Rect2(set[i])
		wall_rect_sets[mask] = rects
	return wall_rect_sets[mask]

static func walls(open) -> Variant:
	var mask: int = open_mask(open)
	if wall_sets[mask] == null: wall_sets[mask] = build_walls(open)
	return wall_sets[mask]

static func build_walls(open) -> Variant:
	# Solid wall pieces; an open door (day, or broken) leaves a gap.
	var h = HALF
	var th = WALL_IN + WALL_OUT
	var top = Rect2(-h.x - WALL_OUT, -h.y - WALL_OUT, 2 * h.x + th, th)
	var bottom = Rect2(-h.x - WALL_OUT, h.y - WALL_IN, 2 * h.x + th, th)
	var left = Rect2(-h.x - WALL_OUT, -h.y - WALL_OUT, th, 2 * h.y + th)
	var right = Rect2(h.x - WALL_IN, -h.y - WALL_OUT, th, 2 * h.y + th)
	return [bottom] + split(top, open[1], false) + split(left, open[0], true) + split(right, open[2], true)

static func split(r, open, vertical) -> Variant:
	if not open:
		return [r]
	if vertical:
		return [Rect2(r.position.x, r.position.y, r.size.x, -DOOR_GAP - r.position.y), Rect2(r.position.x, DOOR_GAP, r.size.x, r.end.y - DOOR_GAP)]
	return [Rect2(r.position.x, r.position.y, -DOOR_GAP - r.position.x, r.size.y), Rect2(DOOR_GAP, r.position.y, r.end.x - DOOR_GAP, r.size.y)]

static func collide(pos, radius, open) -> Variant:
	var at = pos
	if pos is Vector2:
		return collide_fast(at, float(radius), open_mask(open))
	# Pushes a circle out of every wall piece (players only enter through doors).
	for w in walls(open):
		var q = pos.clamp(w.position, w.end)
		var d = pos - q
		var l = d.length()
		if l >= radius:
			continue
		if l > 0.001:
			pos = q + d / l * radius
		else:
			var c = w.get_center()
			var e = w.size / 2 + Vector2(radius, radius)
			var o = pos - c
			if e.x - absf(o.x) < e.y - absf(o.y):
				pos.x = c.x + (1.0 if o.x >= 0 else -1.0) * e.x
			else:
				pos.y = c.y + (1.0 if o.y >= 0 else -1.0) * e.y
	return pos

# Collide(), typed
static func collide_fast(pos: Vector2, radius: float, mask: int) -> Vector2:
	for w in wall_rects(mask):
		var q: Vector2 = pos.clamp(w.position, w.end)
		var d: Vector2 = pos - q
		var l: float = d.length()
		if l >= radius:
			continue
		if l > 0.001:
			pos = q + d / l * radius
		else:
			var c: Vector2 = w.get_center()
			var e: Vector2 = w.size / 2 + Vector2(radius, radius)
			var o: Vector2 = pos - c
			if e.x - absf(o.x) < e.y - absf(o.y):
				pos.x = c.x + (1.0 if o.x >= 0 else -1.0) * e.x
			else:
				pos.y = c.y + (1.0 if o.y >= 0 else -1.0) * e.y
	return pos

static func route(from, to, r) -> Variant:
	# Next waypoint around the base: the goal if the way is clear, else the best visible corner.
	# ponytail: corner hopping around one rectangle; NavigationAgent2D once the map has obstacles.
	if not blocked(from, to, r):
		return to
	var c = HALF + Vector2(r + T, r + T)
	var corners = [Vector2(c.x, c.y), Vector2(-c.x, c.y), Vector2(c.x, -c.y), Vector2(-c.x, -c.y)]
	var best = to
	var best_d = INF
	for corner in corners:
		if from.distance_to(corner) < 4.0 or blocked(from, corner, r):
			continue
		var d = from.distance_to(corner) + rest(corner, to, r, corners)
		if d < best_d:
			best_d = d
			best = corner
	return best

static func rest(corner, to, r, corners) -> Variant:
	# Distance left from a corner to the goal, with at most one more corner (enough for a rectangle).
	if not blocked(corner, to, r):
		return corner.distance_to(to)
	var d = INF
	for c2 in corners:
		if c2 != corner and not blocked(corner, c2, r) and not blocked(c2, to, r):
			d = minf(d, corner.distance_to(c2) + c2.distance_to(to))
	return d

static func blocked(a, b, r) -> Variant:
	var h = HALF + Vector2(r, r)
	var pts = [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, pts[i], pts[(i + 1) % 4]) != null:
			return true
	return false

static func push_out(pos, margin) -> Variant:
	# Moves a point inside the (grown) base rectangle to its nearest edge.
	if not inside_base(pos, margin):
		return pos
	var dx = HALF.x + margin - absf(pos.x)
	var dy = HALF.y + margin - absf(pos.y)
	if dx < dy:
		pos.x = (HALF.x + margin) * (1.0 if pos.x >= 0 else -1.0)
	else:
		pos.y = (HALF.y + margin) * (1.0 if pos.y >= 0 else -1.0)
	return pos

static func pad_pos(i) -> Variant:
	return GameSim.DOOR_POS[i] + GameSim.DOOR_DIR[i] * PAD_DIST

static func gen_nodes(sim: GameSim) -> void:
	sim.nodes.clear()
	var geometry = sim.world
	var primary_count: int = int((4 + 3 * sim.n0) * GameSim.NODE_MUL)
	geometry.ensure_home_farm_resources(primary_count)
	var ambient = []
	var home_count = Cs.arr(3, 0)
	for site in geometry.harvest_sites:
		var node = site.create_node()
		if site.type < 3 and WorldHomeFarms.in_home_farm_2(site.pos, site.type) and home_count[site.type] < primary_count:
			node["ambient"] = false
			home_count[site.type] += 1
			sim.nodes.append(node)
		else:
			ambient.append(node)
	var occupied = []
	occupied.append_array(sim.nodes)
	occupied.append_array(ambient)
	sim.world.rebuild(occupied, sim.towers)
	for i in range(primary_count):
		var site: int = TITANIUM_SITES[i % TITANIUM_SITES.size()]
		var centre: Vector2 = geometry.lm_at.get(site, IslandMap.by_id(site).pos)
		var spread: float = 6 * T
		var spot = null
		for attempt in range(300):
			var p: Vector2 = centre + Vector2.from_angle(sim.rng.randf() * TAU) * spread * sqrt(sim.rng.randf())
			if geometry.in_expedition_aisle(p):
				continue
			if geometry.in_compound_passage(p):
				continue
			if geometry.in_lookout_passage(p):
				continue
			if IslandMap.in_bridge_approach(p, T):
				continue
			if (site == 5 or site == 7) and WorldLandmarkDetails.soil_coverage(Cs.first_or_default(WorldGeometry.landmark_soils, func(s): return s.id == site), p - centre) < 0.95:
				continue
			# The cave supplies fixed ore veins and exterior scree, with clear walkways between them.
			if sim.world.in_cave_region(p, T) or Cs.has_point(sim.world.garden_bounds.grow(T), p) or Cs.has_point(sim.world.weather_room.grow(T), p):
				continue
			var wd: float = float(wall_dist(p))
			if not IslandMap.on_grass(p, 1.5 * T) or wd < 3 * T or in_door_lane(p) or SimPhases.near_pad(sim, p):
				continue
			if wd < float(SAFE_D) + 3 * T:
				continue
			if sim.world.terrain_at(p, 0.5 * T) == 1 or sim.world.terrain_at(p, 0.5 * T) == 5 or Vector2(sim.world.resolve(p, T)).distance_to(p) > 0.01 or sim.nodes.any(func(n): return n.pos.distance_to(p) <= 2.5 * T):
				continue
			spot = p
			break
		# a crowded site: anywhere in the right zone
		if spot == null: spot = rand_zone_point(sim, SAFE_D + 3 * T, ISLAND)
		sim.nodes.append({"type": 3, "pos": spot, "amount": 5})
	# The visible forest, rocks and herbs use the same gathering rules as the original resource clusters.
	sim.nodes.append_array(ambient)
	sim.world.rebuild(sim.nodes, sim.towers)

static func obstacle_hit(sim: GameSim, a, b, radius = null, ignore = null) -> Variant:
	if radius == null: radius = 0.0
	if ignore == null: ignore = Vector2.INF
	var hit_: float = float(sim.world.first_hit(a, b, radius, true, ignore))
	for w in movement_walls(sim):
		hit_ = minf(hit_, WorldGeometry.segment_box(a, b, w.grow(radius)))
	return hit_

static func line_clear(sim: GameSim, a, b, ignore = null) -> Variant:
	if ignore == null: ignore = Vector2.INF
	return obstacle_hit(sim, a, b, 0.0, ignore) == INF

static func move_actor(sim: GameSim, from, to, radius, ignore_scenery: bool = false) -> Variant:
	# typed all the way (src/world/WorldGeometry.FastMove.cs): every body moves through here every tick
	var mask: int = door_mask(sim)
	var f: Vector2 = Vector2(from)
	var r: float = float(radius)
	# the sea stops everyone: slide along the coast (src/world/IslandMap.cs)
	var moved: Vector2 = IslandMap.keep(f, sim.world.move_body_fast(f, IslandMap.keep(f, Vector2(to), r), r, wall_rects(mask), ignore_scenery), r)
	return collide_fast(moved, r, mask)

static func navigate(sim: GameSim, from, to, radius, outside = null) -> Variant:
	if outside == null: outside = true
	var barriers = outside_navigation_walls if outside else wall_rects(door_mask(sim))
	return sim.world.waypoint_fast(Vector2(from), Vector2(to), float(radius), barriers)

static func movement_walls(sim: GameSim) -> Variant:
	var mask: int = door_mask(sim)
	var _v1 = wall_sets[mask]
	return _v1 if _v1 != null else walls([mask & 1 != 0, mask & 2 != 0, mask & 4 != 0])
