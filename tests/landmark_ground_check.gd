class_name LandmarkGroundCheck
extends Node
# Compare the fast, spatially filtered decoration queries against the existing terrain rules.

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	var w = WorldGeometry.new()
	check_expedition_sites(w)
	check_compound_perimeters(w)
	check_lookouts(w)
	var flats = Cs.first_or_default(WorldGeometry.landmark_soils, func(s): return s.id == 3)
	if WorldGeometry.home_farm_radii.x * WorldGeometry.home_farm_radii.y >= 6.5 * 6.5 * 32 * 32:
		Cs.fail("The home gathering footprint was not made more compact")
		return
	for _it1 in [[6, 9.0 * 6.4], [13, 12.4 * 7.6]]:
		var id = _it1[0]
		var baseline_area = _it1[1]
		var footprint: Rect2 = w.compounds[id]
		var expected: float = 1.5 * WorldGeometry.YARD_AREA_SCALE if id == 13 else 1.5
		if abs(footprint.get_area() / (32 * 32) / baseline_area - expected) > 0.001:
			Cs.fail("Compound %s did not gain 50 percent floor area" % [Cs.s(id)])
			return
		for corner in [footprint.position, footprint.end, Vector2(footprint.position.x, footprint.end.y), Vector2(footprint.end.x, footprint.position.y)]:
			if not IslandMap.on_land(corner, 10) or IslandMap.in_river(corner, IslandMap.RIVER_BANK):
				Cs.fail("Expanded compound %s extends into water" % [Cs.s(id)])
				return
	for id in w.compound_entrances:
		var entry = w.compound_entrances[id]
		if not IslandMap.on_land(entry, 10) or not w.resolve_fast(entry, 10).is_equal_approx(entry):
			Cs.fail("Compound %s entrance is obstructed" % [id])
			return
	var compared: int = 0
	var segments: int = 0
	for _unused in w.lm_at:
		var centre = w.lm_at[_unused]
		var area = Rect2(centre - Vector2(250, 180), Vector2(500, 360))
		var mask = LandmarkGroundMask.new(w, area)
		segments += mask.segment_count
		for margin in [4.0, 8.0]:
			var y: float = area.position.y
			while y < area.end.y:
				var x: float = area.position.x
				while x < area.end.x:
					var p: Vector2 = Vector2(x, y)
					var expected: bool = w.terrain_at(p, margin) == 0 or w.terrain_at(p, margin) == 4 or w.terrain_at(p, margin) == 9
					if mask.can_paint(p, margin) != expected:
						Cs.fail("Ground mask differs at %s, margin %s" % [Cs.s(p), Cs.s(margin)])
						return
					compared += 1
					x += 16
				y += 16
	var cave = Cs.first_or_default(WorldGeometry.landmark_soils, func(s): return s.id == 16)
	if w.cave_centre.x >= 0 or w.cave_centre.y <= 0 or abs(cave.rx * cave.ry / (7.5 * 5.2 * 1.5) - 3) > 0.001:
		Cs.fail("The tripled cave region must remain in the southwest")
		return
	var cave_area = Rect2(w.cave_centre - WorldGeometry.cave_radii, WorldGeometry.cave_radii * 2)
	var cave_mask = LandmarkGroundMask.new(w, cave_area)
	var cave_cells: int = 0
	var y: float = cave_area.position.y
	while y < cave_area.end.y:
		var x: float = cave_area.position.x
		while x < cave_area.end.x:
			var p: Vector2 = Vector2(x, y)
			if not w.in_cave_region(p):
				x += 4
				continue
			if not IslandMap.on_land(p) or IslandMap.in_river(p, IslandMap.RIVER_BANK + 3):
				x += 4
				continue
			if WorldLandmarkDetails.soil_coverage(cave, p - w.soil_centre(cave)) != 1 or not cave_mask.can_paint(p, 3, true, false):
				Cs.fail("Uncovered cave ground at %s" % [Cs.s(p)])
				return
			cave_cells += 1
			x += 4
		y += 4
	for _it2 in w.cave_walls:
		var face = _it2[0]
		var cap = _it2[1]
		for p in face + cap:
			if not w.in_cave_region(p):
				Cs.fail("Cave wall extends beyond its rock ground at %s" % [Cs.s(p / 32)])
				return
	var mining_nodes = []
	for site in w.harvest_sites:
		mining_nodes.append(site.create_node())
	w.rebuild(mining_nodes, [])
	var weather_walker: Vector2 = w.weather_entrance + Vector2(0, 60)
	for i in range(90):
		weather_walker = w.move_body_fast(weather_walker, weather_walker.move_toward(w.weather_centre, 3), 10, [])
	if weather_walker.distance_to(w.weather_centre) > 3 or not w.is_weather_interior(weather_walker):
		Cs.fail("The weather hut cannot be entered through its south doorway")
		return
	for i in range(90):
		weather_walker = w.move_body_fast(weather_walker, weather_walker.move_toward(w.weather_entrance + Vector2(0, 60), 3), 10, [])
	if w.is_weather_interior(weather_walker):
		Cs.fail("The weather hut cannot be exited")
		return
	for side in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2(0.7, 1)]:
		var p: Vector2 = w.weather_centre + WorldGeometry.weather_half * side + side * 40
		for i in range(50):
			p = w.move_body_fast(p, p.move_toward(w.weather_centre, 3), 10, [])
		if w.is_weather_interior(p):
			Cs.fail("A weather hut wall can be walked through")
			return
	if w.harvest_sites.any(func(s): return w.weather_room.has_point(s.pos)):
		Cs.fail("Harvestable resources inside the display-only weather hut")
		return
	if w.fishing_rods.size() != 3 or w.fishing_fish.size() < 4 or w.fishing_litter.size() < 8:
		Cs.fail("The fishing pier lacks rods, jumping fish or litter")
		return
	for fish in w.fishing_fish:
		if IslandMap.on_land(fish, -8):
			Cs.fail("A jumping fish is on dry land or on the deck")
			return
	print("WEATHER / PIER ALL OK: walkable room, solid walls, %s rods, %s fish and %s litter props" % [w.fishing_rods.size(), w.fishing_fish.size(), w.fishing_litter.size()])
	if w.garden_centre.y > 11 * 32 or w.garden_centre.y < 9 * 32 or w.garden_centre.x > -64 * 32 or w.garden_centre.x < -68 * 32:
		Cs.fail("The garden did not move north to the marked west-bank clearing")
		return
	var garden_walker: Vector2 = w.garden_entrance + Vector2(0, 45)
	var garden_goal: Vector2 = w.garden_centre - Vector2(0, 4 * 32)
	for i in range(130):
		garden_walker = w.move_body_fast(garden_walker, garden_walker.move_toward(garden_goal, 3), 10, [])
	if garden_walker.distance_to(garden_goal) > 3:
		Cs.fail("Garden gate or central aisle is blocked")
		return
	for _it3 in [[w.garden_centre + Vector2(-WorldGeometry.garden_half.x - 40, 0), w.garden_centre], [w.garden_centre + Vector2(WorldGeometry.garden_half.x + 40, 0), w.garden_centre], [w.garden_centre + Vector2(0, -WorldGeometry.garden_half.y - 40), w.garden_centre], [w.garden_entrance + Vector2(100, 40), w.garden_centre + Vector2(100, 0)]]:
		var outside = _it3[0]
		var inside = _it3[1]
		var p: Vector2 = outside
		for i in range(40):
			p = w.move_body_fast(p, p.move_toward(inside, 3), 10, [])
		if Cs.has_point(w.garden_bounds.grow(-12), p):
			Cs.fail("A garden fence can be walked through")
			return
	for mask in w.cave_exterior_masks:
		if len(Geometry2D.triangulate_polygon(mask)) == 0:
			Cs.fail("Cave exterior mask is not drawable")
			return
	var walker: Vector2 = w.cave_entrance + Vector2(2 * 32, 0)
	var goal: Vector2 = w.cave_centre - Vector2(8.5 * 32, 0)
	var i: int = 0
	while i < 400 and walker.distance_to(goal) > 2:
		walker = w.move_body_fast(walker, walker.move_toward(goal, 3), 10, [])
		i += 1
	if walker.distance_to(goal) > 3:
		Cs.fail("The east-to-west cave entrance or mining aisle is blocked at %s, goal %s" % [Cs.s(walker / 32), Cs.s(goal / 32)])
		return
	print("CAVE GROUND ALL OK: %s opaque rock cells; east-to-west access is clear" % [cave_cells])
	if not cave.bare or WorldLandmarkDetails.soil_coverage(cave, Vector2.ZERO) != 1 or WorldLandmarkDetails.soil_coverage(cave, Vector2(0, 2 * 32)) != 1:
		Cs.fail("Cave mouth and forecourt must have opaque rock ground")
		return
	for soil in WorldGeometry.landmark_soils:
		var centre: Vector2 = w.soil_centre(soil)
		var area = Rect2(centre - Vector2(soil.rx, soil.ry) * 32, Vector2(soil.rx, soil.ry) * 64)
		var mask = LandmarkGroundMask.new(w, area)
		y = area.position.y
		while y < area.end.y:
			var x: float = area.position.x
			while x < area.end.x:
				var p: Vector2 = Vector2(x, y)
				if mask.can_paint(p, 3, true, false) and (w.terrain_at(p, 3) == 1 or w.terrain_at(p, 3) == 6 or w.terrain_at(p, 3) == 8 or IslandMap.in_river(p, IslandMap.RIVER_BANK + 3)):
					Cs.fail("Landmark ground overwrites water, a bridge or floor at %s" % [Cs.s(p)])
					return
				x += 16
			y += 16
	for row in w.scatter:
		if w.bare_landmark_ground(Vector2(row[0])):
			Cs.fail("Grass tufts on bare landmark ground")
			return
	print("LANDMARK GROUND ALL OK: %s queries match existing terrain; average %s nearby path segments per location" % [compared, segments / w.lm_at.size()])
	get_tree().quit()
	# catch (Exception Error) dropped

static func check_expedition_sites(w) -> void:
	for id in [5, 7, 11]:
		var site = w.expedition_sites[id]
		var soil = Cs.first_or_default(WorldGeometry.landmark_soils, func(s): return s.id == id)
		if not w.soil_centre(soil).is_equal_approx(site.centre) or not w.lm_at[id].is_equal_approx(site.centre):
			Cs.fail("Site %s ground / scenery / marker centres differ" % [id])
			return
		var y: float = -site.half.y
		while y <= site.half.y:
			var x: float = -site.half.x
			while x <= site.half.x:
				var p: Vector2 = site.centre + Vector2(x, y)
				if not IslandMap.on_land(p, 10) or IslandMap.in_river(p, IslandMap.RIVER_BANK + 8):
					Cs.fail("Site %s footprint extends into water at %s" % [id, Cs.s(p / 32)])
					return
				if WorldLandmarkDetails.soil_coverage(soil, p - site.centre) < 0.99:
					Cs.fail("Site %s ground does not cover its complete footprint at %s" % [id, Cs.s(p / 32)])
					return
				x += 16
			y += 16
		if id == 11:
			continue
		var sum: Vector2 = Vector2.ZERO
		var count: int = 0
		for v in w.expedition_vehicles:
			if v.id == id:
				sum += v.pos
				count += 1
		if count != (1 if id == 5 else 3) or not (sum / count).is_equal_approx(site.centre):
			Cs.fail("Vehicle group %s is not centred on its ground" % [id])
			return
	for f in w.expedition_cliffs:
		if len(Geometry2D.triangulate_polygon(f.face)) == 0 or len(Geometry2D.triangulate_polygon(f.cap)) == 0:
			Cs.fail("An exposed Northwind rock ledge is not drawable")
			return
	var nodes = []
	for s in w.harvest_sites:
		nodes.append(s.create_node())
	w.rebuild(nodes, [])
	for id in [5, 7, 11]:
		var site = w.expedition_sites[id]
		var from: Vector2 = site.centre + Vector2(0, site.half.y + 8) if id == 11 else site.centre + Vector2(-site.half.x - 5, 60 if id == 5 else 4)
		var goal: Vector2 = site.centre - Vector2(0, site.half.y + 8) if id == 11 else site.centre + Vector2(site.half.x + 5, 60 if id == 5 else 4)
		var walker: Vector2 = from
		var i: int = 0
		while i < 500 and walker.distance_to(goal) > 2:
			walker = w.move_body_fast(walker, walker.move_toward(goal, 3), 10, [])
			i += 1
		if walker.distance_to(goal) > 3:
			Cs.fail("Site %s walking passage blocked at %s" % [id, Cs.s(walker / 32)])
			return
	print("EXPEDITION SITES ALL OK: shared centres, complete dry ground, centred vehicles, walkable passages and drawable rock terraces")

static func check_compound_perimeters(w) -> void:
	for id in [6, 13]:
		var sections = Array(w.compound_boundaries.filter(func(s): return s.id == id)).duplicate()
		if Cs.distinct(sections.map(func(s): return s.side)).size() != 4:
			Cs.fail("Compound %s does not have all four perimeter sides" % [id])
			return
		for s in sections:
			if id == 6 and (len(Geometry2D.triangulate_polygon(s.face)) == 0 or len(Geometry2D.triangulate_polygon(s.cap)) == 0):
				Cs.fail("A damaged ruin wall is not drawable")
				return
			var mid: Vector2 = (s.a + s.b) / 2
			var _sw1 = s.side
			var out: Vector2 = Vector2.UP if _sw1 == 0 else Vector2.LEFT if _sw1 == 1 else Vector2.RIGHT if _sw1 == 2 else Vector2.DOWN
			for direction in [-1, 1]:
				var p: Vector2 = mid + out * direction * 42
				var goal: Vector2 = mid - out * direction * 42
				for i in range(60):
					p = w.move_body_fast(p, p.move_toward(goal, 3), 10, [])
				if (p - mid).dot(out) * direction < 14:
					Cs.fail("Compound %s side %s can be crossed through its wall/fence" % [id, s.side])
					return
		for radius in [10.0, 35.0]:
			var gate: Vector2 = w.compound_gates[id]
			var goal: Vector2 = w.lm_at[id] + Vector2(0, -35)
			var p: Vector2 = gate + Vector2(0, 48)
			var i: int = 0
			while i < 200 and p.distance_to(goal) > 2:
				p = w.move_body_fast(p, p.move_toward(goal, 3), radius, [])
				i += 1
			if p.distance_to(goal) > 3:
				Cs.fail("Compound %s gate / central aisle blocked for radius %s at %s" % [id, Cs.s(radius), Cs.s(p / 32)])
				return
			goal = gate + Vector2(0, 48)
			i = 0
			while i < 200 and p.distance_to(goal) > 2:
				p = w.move_body_fast(p, p.move_toward(goal, 3), radius, [])
				i += 1
			if p.distance_to(goal) > 3:
				Cs.fail("Compound %s cannot be exited" % [id])
				return
		if not w.compounds[id].get_center().is_equal_approx(w.lm_at[id]):
			Cs.fail("Compound floor and scenery centres differ")
			return
	print("COMPOUND PERIMETERS ALL OK: four solid sides each, open gates, player/boss entry and exit, drawable walls and shared centres")

static func check_lookouts(w) -> void:
	for id in [12, 17]:
		var site = w.lookouts[id]
		var soil = Cs.first_or_default(WorldGeometry.landmark_soils, func(s): return s.id == id)
		if not w.lm_at[id].is_equal_approx(site.centre) or not w.soil_centre(soil).is_equal_approx(site.deck.get_center()):
			Cs.fail("Lookout %s ground, platform and marker have different centres" % [id])
			return
		if len(Geometry2D.triangulate_polygon(site.outline)) == 0:
			Cs.fail("Lookout platform is not drawable")
			return
		var y: float = -site.radii.y
		while y <= site.radii.y:
			var x: float = -site.radii.x
			while x <= site.radii.x:
				var d: Vector2 = Vector2(x, y)
				var p: Vector2 = site.centre + d
				if (d / site.radii).length() > 1:
					x += 8
					continue
				if not IslandMap.on_land(p, 12) or WorldLandmarkDetails.soil_coverage(soil, d) < 0.999:
					Cs.fail("Lookout %s has uncovered or wet ground at %s" % [id, Cs.s(p / 32)])
					return
				x += 8
			y += 8
		for placement in w.lookout_placements.filter(func(p): return p[0] == id):
			for side in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var p: Vector2 = placement[1] + side * placement[2]
				if not IslandMap.on_land(p, 10) or WorldLandmarkDetails.soil_coverage(soil, p - site.centre) < 0.999:
					Cs.fail("Lookout %s fixture extends off its ground at %s" % [id, Cs.s(p / 32)])
					return
		for radius in [10.0, 35.0]:
			var p: Vector2 = w.compound_entrances[id]
			var goal: Vector2 = site.centre
			var i: int = 0
			while i < 180 and p.distance_to(goal) > 2:
				p = w.move_body_fast(p, p.move_toward(goal, 3), radius, [])
				i += 1
			if p.distance_to(goal) > 3:
				Cs.fail("Lookout %s entrance is blocked at %s" % [id, Cs.s(p / 32)])
				return
			goal = w.compound_entrances[id]
			i = 0
			while i < 180 and p.distance_to(goal) > 2:
				p = w.move_body_fast(p, p.move_toward(goal, 3), radius, [])
				i += 1
			if p.distance_to(goal) > 3:
				Cs.fail("Lookout %s exit is blocked" % [id])
				return
	if w.coral.size() < 18 or w.coral.size() != w.reef_beds.size():
		Cs.fail("Coral Lookout lacks a visible reef")
		return
	for bed in w.reef_beds:
		if len(Geometry2D.triangulate_polygon(bed)) == 0 or bed.any(func(p): return IslandMap.on_land(p, -8)):
			Cs.fail("A reef patch extends onto dry land or cannot be drawn")
			return
	for p in w.cape_scarp_face + w.cape_scarp_cap:
		var soil = Cs.first_or_default(WorldGeometry.landmark_soils, func(s): return s.id == 17)
		if not IslandMap.on_land(p, 8) or WorldLandmarkDetails.soil_coverage(soil, p - w.lm_at[17]) < 0.999:
			Cs.fail("The cape scarp is not covered by slate ground")
			return
	if len(Geometry2D.triangulate_polygon(w.cape_scarp_face)) == 0 or len(Geometry2D.triangulate_polygon(w.cape_scarp_cap)) == 0:
		Cs.fail("Cape rock rim is not drawable")
		return
	if w.cape_gulls.size() < 2 or w.cape_gulls.any(func(p): return IslandMap.on_land(p, -24)):
		Cs.fail("Cape seabirds are missing or over dry land")
		return
	print("LOOKOUTS ALL OK: shared centres, complete dry ground, covered fixtures, clear entrances, %s underwater reef patches and %s seabirds" % [w.coral.size(), w.cape_gulls.size()])
