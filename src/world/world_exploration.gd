class_name WorldExploration
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldExploration.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

# constants shared with WorldGeometry
const COLD = WorldGeometry.COLD
const LANDMARK_SCALE = WorldGeometry.LANDMARK_SCALE
const TL = WorldGeometry.TL

# Stone steps where a path climbs a hill. (The rivers and their bridges are src/world/IslandRivers.cs.)
static func build_ramps(world: WorldGeometry) -> void:
	world.ramps.clear()
	for h in IslandMap.hills:
		var _d1 = WorldLandmarks.on_path(world, h.top)
		var at_ = _d1[0]
		var along = _d1[1]
		if at_.distance_to(h.top) > 18 * TL:
			continue
		world.ramps.append([at_, along])
		for i in range(-4, 5):
			world.steps.append([at_ + along * i * 0.7 * TL, along.orthogonal()])

static func dress_exploration(world: WorldGeometry) -> void:
	var r = CsRandom.new(802)
	# Every named site gets a distinct supporting scene; these props never become resource nodes.
	for id in range(2, 19):
		if id == 2 or id == 3 or id == 4 or id == 5 or id == 6 or id == 7 or id == 9 or id == 11 or id == 12 or id == 13 or id == 16 or id == 17 or id == 18:
			continue  # dedicated site dressing
		var props = ["lm_cart_0", "lm_warning_0", "lm_cargo_stack_0"] if id == 5 or id == 7 else ["lm_console_0", "lm_cargo_stack_0", "lm_warning_0"] if id == 6 or id == 9 or id == 13 else ["lm_waterpump_0", "lm_rainbarrel_0", "lm_signpost_0"] if id == 8 or id == 15 or id == 18 else ["lm_cargo_stack_0", "lm_rope_0", "lm_buoys_0"] if id == 10 or id == 12 or id == 14 else ["lm_tent_0", "lm_warning_0", "lm_expedition_0"]
		for i in range(props.size()):
			for try in range(12):
				var a: float = i * 2.1 + try * 0.52
				var p: Vector2 = world.lm_at.get(id, WorldLandmarks.at(world, id)) + Vector2.from_angle(a) * (4.8 + try * 0.3) * TL * LANDMARK_SCALE
				if WorldLandmarkDetails.dress_at(world, p, props[i], 12 if i == 0 else 0):
					break
	# Survey camps, broken carts and signs in unnamed spaces, along trails rather than isolated clutter.
	for _it1 in world.trails:
		var path = _it1[0]
		var width = _it1[1]
		if path.size() < 18:
			continue
		for i in range(12, path.size() - 2, 32):
			var along: Vector2 = (path[i + 1] - path[i]).normalized()
			var p: Vector2 = path[i] + along.orthogonal() * (width / 2 + 2 * TL) * (-1 if r.next(2) == 0 else 1)
			if IslandMap.near(p, 10 * TL) != null or p.length() < 26 * TL or WorldLandmarks.in_clear(world, p, 2 * TL):
				continue
			var _sw2 = r.next(4)
			var prop_ = "lm_tent_0" if _sw2 == 0 else "lm_cart_0" if _sw2 == 1 else "lm_warning_0" if _sw2 == 2 else "lm_cargo_stack_0"
			if WorldLandmarkDetails.dress_at(world, p, prop_, 12):
				WorldLandmarkDetails.dress_at(world, p + along * 1.6 * TL, "lm_expedition_0")

static func fill_resource_gaps(world: WorldGeometry, variants) -> void:
	var r = CsRandom.new(317)
	var occupied = []
	var natural: int = 0
	for d in world.deco:
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
					if WorldGeometry.wall_dist(p) < 10 * TL or not IslandMap.on_grass(p, TL) or WorldTerrain.terrain_blocked(world, p, TL) or WorldGeometry.lane(p) or WorldGeometry.near_pad(p):
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
					world.deco.append([p.round(), name, 1.0, COLD])
					occupied.append(p)
					natural += 1
					k += 1
				x += 6 * TL
			y += 6 * TL
