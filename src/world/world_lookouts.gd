class_name WorldLookouts
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldLookouts.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

static func lookout_radii(id: int) -> Vector2:
	return Vector2(188, 144) if id == 12 else Vector2(184, 168)

static func lookout_spot(world: WorldGeometry, id: int) -> Vector2:
	var want: Vector2 = WorldLandmarks.at(world, id) + (WorldLandmarks.tl(-4, 12) if id == 17 else WorldLandmarks.tl(3, -10))
	var half: Vector2 = lookout_radii(id)
	var best: Vector2 = want
	var score: float = INF
	# Fit the complete scene before placing anything; coastal props no longer get scattered independently.
	for y in range(-24, 25):
		for x in range(-24, 25):
			var c: Vector2 = (want + WorldLandmarks.tl(x * 0.5, y * 0.5)).round()
			var cost: float = c.distance_squared_to(want)
			if cost >= score:
				continue
			var fits: bool = true
			var dy: int = -2
			while dy <= 2 and fits:
				for dx in range(-2, 3):
					var p: Vector2 = c + half * Vector2(dx * 0.5, dy * 0.5)
					if not IslandMap.on_land(p, 22) or IslandMap.in_river(p, 48) or WorldLandmarks.in_clear(world, p, 12) or WorldGeometry.near_pad(p):
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

static func new_lookout(world: WorldGeometry, id: int, deck_half: Vector2) -> Variant:
	var c: Vector2 = lookout_spot(world, id)
	var half: Vector2 = lookout_radii(id)
	var outline = [c + Vector2(-112, -70), c + Vector2(112, -70), c + Vector2(112, 70), c + Vector2(-112, 70)] if id == 12 else [c + Vector2(-88, -98), c + Vector2(88, -98), c + Vector2(126, -60), c + Vector2(126, 60), c + Vector2(88, 98), c + Vector2(-88, 98), c + Vector2(-126, 60), c + Vector2(-126, -60)]
	var site = LookoutSite.new(id, c, half, Rect2(c - deck_half, deck_half * 2), outline)
	world.lookouts[id] = site
	world.lm_at[id] = c
	world.floors.append([site.deck, false])
	WorldLandmarks.clear(world, c, half.length() + 32)
	world.compound_entrances[id] = c + Vector2(0, (1 if id == 12 else -1) * (half.y - 12))
	return site

static func lookout_prop(world: WorldGeometry, site, offset: Vector2, sprite, foot_radius: float = 12) -> void:
	var p: Vector2 = site.centre + offset
	WorldLandmarks.prop(world, p, sprite)
	world.lookout_placements.append([site.id, p, foot_radius])

static func lookout_fixture(world: WorldGeometry, site, offset: Vector2, model: int, radius: float) -> void:
	var p: Vector2 = site.centre + offset
	world.lookout_objects.append(LookoutObject.new(site.id, model, p))
	world.lookout_placements.append([site.id, p, radius])
	if radius > 0:
		WorldLandmarks.solid(world, p, radius)

static func lookout_railing(world: WorldGeometry, id: int, a: Vector2, b: Vector2) -> void:
	WorldLandmarkScale.compound_line(world, a, b, 7)
	var count: int = maxi(1, int(ceilf(a.distance_to(b) / 48)))
	var i: int = 0
	while i < count:
		world.lookout_rails.append(LookoutRail.new(id, a.lerp(b, i / float(count)), a.lerp(b, (i + 1.0) / count)))
		i += 1

static func build_coral_lookout(world: WorldGeometry) -> void:
	var site = new_lookout(world, 12, Vector2(112, 70))
	var c: Vector2 = site.centre
	# A bleached timber marine lookout, reef identification board and abandoned diving equipment.
	world.lookout_objects.append(LookoutObject.new(12, 0, c + Vector2(0, -48)))
	world.lookout_placements.append([12, c + Vector2(-48, -48), 9])
	world.lookout_placements.append([12, c + Vector2(48, -48), 9])
	WorldLandmarks.solid(world, c + Vector2(-48, -48), 9)
	WorldLandmarks.solid(world, c + Vector2(48, -48), 9)
	lookout_fixture(world, site, Vector2(-146, 24), 1, 15)
	lookout_fixture(world, site, Vector2(144, 45), 2, 18)
	lookout_fixture(world, site, Vector2(-69, 33), 6, 16)
	lookout_prop(world, site, Vector2(72, 17), "lm_scope_0", 9)
	lookout_prop(world, site, Vector2(-142, -67), "lm_buoys_0", 10)
	lookout_prop(world, site, Vector2(133, 81), "lm_lifering_0", 10)
	lookout_prop(world, site, Vector2(-106, 100), "lm_rope_0", 8)
	var e = site.outline
	lookout_railing(world, 12, e[0], e[1])
	lookout_railing(world, 12, e[0], e[3])
	lookout_railing(world, 12, e[1], e[2])
	lookout_railing(world, 12, e[3], c + Vector2(-48, 70))
	lookout_railing(world, 12, c + Vector2(48, 70), e[2])
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
		world.coral.append(beds[i][0])
		world.reef_beds.append(beds[i][1])
		i += 1

static func build_south_cape_lookout(world: WorldGeometry) -> void:
	var site = new_lookout(world, 17, Vector2(126, 98))
	var c: Vector2 = site.centre
	# Cold slate, a compass terrace, a navigation beacon and storm-worn signal equipment.
	lookout_fixture(world, site, Vector2(110, 28), 3, 21)
	lookout_fixture(world, site, Vector2(-128, -86), 4, 8)
	lookout_fixture(world, site, Vector2(116, -88), 5, 14)
	lookout_fixture(world, site, Vector2(-94, 96), 6, 16)
	lookout_prop(world, site, Vector2(-82, 17), "lm_scope_0", 9)
	lookout_prop(world, site, Vector2(125, 107), "lm_lifering_0", 8)
	lookout_prop(world, site, Vector2(-139, 48), "lm_rope_0", 8)
	var e = site.outline
	for i in range(1, e.size()):
		lookout_railing(world, 17, e[i], e[(i + 1) % e.size()])
	# North is the landward approach; preserve a wide gap in the parapet.
	lookout_railing(world, 17, e[0], c + Vector2(-48, -98))
	lookout_railing(world, 17, c + Vector2(48, -98), e[1])
	var rim = [Vector2(-138, 77), Vector2(-104, 124), Vector2(-54, 147), Vector2(45, 144), Vector2(124, 110), Vector2(151, 59)]
	world.cape_scarp_face = Cs.arr(rim.size() * 2, Vector2.ZERO)
	world.cape_scarp_cap = Cs.arr(rim.size() * 2, Vector2.ZERO)
	for i in range(rim.size()):
		var p: Vector2 = c + rim[i]
		world.cape_scarp_face[i] = p
		world.cape_scarp_face[-(i + 1)] = p + Vector2(0, 12)
		world.cape_scarp_cap[i] = p
		world.cape_scarp_cap[-(i + 1)] = p - Vector2(0, 14)
	for i in range(5):
		for y in range(180, 601, 12):
			var p: Vector2 = c + Vector2(-240 + i * 120, y)
			if IslandMap.on_land(p, -48):
				continue
			world.cape_gulls.append(p)
			break

static func in_lookout_passage(world: WorldGeometry, p: Vector2) -> bool:
	for site in world.lookouts.values():
		if absf(p.x - site.centre.x) < 32 and Cs.has_point(site.deck.grow(90), p):
			return true
	return false

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
