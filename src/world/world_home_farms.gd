class_name WorldHomeFarms
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldHomeFarms.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.
static var home_farm_minimum = [36, 32, 36]
static var home_farm_centres = [find_home_farm_centre(0), find_home_farm_centre(1), find_home_farm_centre(2)]

# constants shared with WorldGeometry
const TL = WorldGeometry.TL

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
	return ((p - home_farm_centre(type)) / (WorldGeometry.home_farm_radii + Vector2.ONE * margin)).length_squared() <= 1

static func build_home_farm_landmarks(world: WorldGeometry) -> void:
	var r = CsRandom.new(211)
	for type in range(3):
		var c: Vector2 = home_farm_centre(type)
		world.lm_at[type + 2] = c
		WorldLandmarks.clear(world, c, WorldGeometry.home_farm_radii.x + 24)
		var slots = world.home_farm_slots[type]
		slots.clear()
		for side in range(-1, 2, 2):
			var y: float = 26
			while y < WorldGeometry.home_farm_radii.y - 12:
				var x: float = -162
				while x <= 162:
					var p: Vector2 = (c + Vector2(x + float(r.next_double()) * 2 - 1, side * y + float(r.next_double()) * 2 - 1)).round()
					if not in_home_farm_2(p, type, -22 if type == 1 else -14) or not IslandMap.on_grass(p, 18) or WorldGeometry.near_pad(p) or WorldGeometry.lane(p) or WorldGeometry.wall_dist(p) < 3 * TL:
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
		WorldLandmarks.prop(world, c + Vector2(WorldGeometry.home_farm_radii.x + 14, 52), "lm_signpost_0")
		if type == 0:
			WorldLandmarks.prop(world, c + Vector2(-WorldGeometry.home_farm_radii.x - 4, 26), "lm_coconuts_0")

static func ensure_home_farm_resources(world: WorldGeometry, primary_count: int = 0) -> void:
	for type in range(3):
		var have: int = world.harvest_sites.filter(func(s): return s.type == type and in_home_farm_2(s.pos, type)).size()
		var want: int = maxi(home_farm_minimum[type], primary_count)
		var slots = world.home_farm_slots[type]
		if want > slots.size():
			Cs.fail("Home farm %s supports %s nodes; requested %s. Reduce NodeMultiplier." % [type, slots.size(), want])
			return
		for i in range(have, want):
			var rock: int = (0 if i % 2 == 0 else 3) if absf(slots[i].y - home_farm_centre(type).y) < 40 else i % 5
			var radius: float = 6 if type == 0 else (13 if rock == 0 else 18 if rock == 1 else 17 if rock == 2 else 10 if rock == 3 else 19) if type == 1 else 0
			var sprite = "lm_palm_" + str(i % 4) if type == 0 else "rock_" + str(rock) if type == 1 else "node_herb_" + str(i % 2)
			world.harvest_sites.append(Harvestables.Site.new(slots[i], sprite, type, radius))

static func thin_outside_resources(world: WorldGeometry) -> void:
	Cs.array_clear(world.outside_before)
	Cs.array_clear(world.outside_after)
	var groups = {}
	for s in world.harvest_sites:
		if s.type > 2 or in_home_farm(s.pos):
			continue
		var region: int = 180 + Cs.find_index(world.garden_beds, func(b): return b.has_point(s.pos)) if world.garden_bounds.has_point(s.pos) else 16 if WorldCave.in_cave_region(world, s.pos) else 0
		var key = [s.type, region]
		var group = groups.get(key, null)
		if not groups.has(key):
			group = []
			groups[key] = group
		group.append(s)
		world.outside_before[s.type] += 1
	var remove = {}
	for key in groups:
		var group = groups[key]
		var drop: int = int(Cs.round_even(group.size() * 0.25))
		# Spatial hashing distributes removals across the world instead of deleting one contiguous patch.
		Cs.sort_cmp(group, func(a, b): return Cs.compare(resource_order(a.pos), resource_order(b.pos)))
		var dropped: int = 0
		for i in range(drop):
			if not world.hand_placed.has(group[i]):
				Cs.set_add(remove, group[i])
				dropped += 1
		world.outside_after[key[0]] += group.size() - dropped
	Cs.remove_all(world.harvest_sites, func(s): return remove.has(s))
	var flat = []
	var outside: int = 0
	for d in world.scatter:
		var _c1 = in_home_farm(Vector2(d[0]))
		if not _c1:
			outside += 1
			_c1 = outside % 4 != 0
		if _c1:
			flat.append(d)
	world.scatter = flat

static func resource_order(p: Vector2) -> int:
	# C# uint arithmetic: wraps at 32 bits
	var h: int = Cs.u32(int(p.x) * 73856093 ^ int(p.y) * 19349663)
	h ^= h >> 16
	h = Cs.u32(h * 0x7feb352d)
	h ^= h >> 15
	return h
