class_name ResourceLayoutCheck
extends Node

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	var s = GameSim.new()
	s.add_player(1, "Engineer", 2)
	s.add_player(2, "Scout", 0)
	s.start_match()
	var w = s.world
	for b in range(IslandMap.bridges.size()):
		var c: Vector2 = IslandMap.bridges[b][1]
		for radius in [9.6, 16.0, 35.0]:
			# Both directions, including the large boss body, can still cross the whole bridge.
			for sign_ in [-1, 1]:
				var start: Vector2 = c + Vector2(sign_ * (IslandMap.BRIDGE_HALF_LEN + 36), 0)
				var goal: Vector2 = c - Vector2(sign_ * (IslandMap.BRIDGE_HALF_LEN + 36), 0)
				var p: Vector2 = start
				for i in range(140):
					p = Vector2(s.move_actor(p, p.move_toward(goal, 3), radius))
				if p.distance_to(goal) > 4:
					Cs.fail("Bridge %s no longer supports radius %s: %s -> %s" % [b, Cs.s(radius), Cs.s(p / 32), Cs.s(goal / 32)])
					return
		for x in [-IslandMap.BRIDGE_HALF_LEN + 24, 0, IslandMap.BRIDGE_HALF_LEN - 24]:
			for side in [-1, 1]:
				var p: Vector2 = c + Vector2(x, 0)
				for i in range(100):
					p = w.move_body_fast(p, p + Vector2(0, side * 6), 9.6, [])
				var limit: float = IslandMap.BRIDGE_RAIL_OFFSET - IslandMap.BRIDGE_RAIL_RADIUS - 9.6
				if side * (p.y - c.y) > limit + 1.5:
					Cs.fail("Bridge %s rail can be crossed at %s" % [b, Cs.s(x)])
					return
				# Entering sideways from the bank must also stop at the rail.
				p = c + Vector2(x, side * (IslandMap.BRIDGE_RAIL_OFFSET + 36))
				for i in range(50):
					p = w.move_body_fast(p, p + Vector2(0, -side * 4), 9.6, [])
				if side * (p.y - c.y) < IslandMap.BRIDGE_RAIL_OFFSET + 16:
					Cs.fail("Bridge %s can be entered through a side rail" % [b])
					return
	print("BRIDGE RAILS ALL OK: all five bridges, both sides, dry abutments and boss crossings")
	var nodes = Array(s.nodes).duplicate()
	var minimum = [36, 32, 36]
	for type in range(3):
		var c: Vector2 = WorldHomeFarms.home_farm_centre(type)
		var here = Array(nodes.filter(func(n): return int(n["type"]) == type and WorldHomeFarms.in_home_farm_2(Vector2(n["pos"]), type))).duplicate()
		var soil = Cs.first_or_default(WorldGeometry.landmark_soils, func(p): return p.id == type + 2)
		if here.size() < minimum[type] or w.lm_at[type + 2] != c or w.soil_centre(soil) != c:
			Cs.fail("Home farm and its soil have different centres or insufficient resources")
			return
		if here.filter(func(n): return not n.get("ambient", true)).size() != 10 * GameSim.NODE_MUL:
			Cs.fail("Primary home resources were duplicated or lost")
			return
		for n in here:
			var p: Vector2 = Vector2(n["pos"])
			for offset in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				if WorldLandmarkDetails.soil_coverage(soil, p - c + offset * (Harvestables.radius(n) + 3)) < 0.999:
					Cs.fail("Home %s resource has exposed grass around its footprint at %s" % [type, Cs.s(p / 32)])
					return
		var walker: Vector2 = c - Vector2(WorldGeometry.home_farm_radii.x + 24, 0)
		var goal: Vector2 = c + Vector2(WorldGeometry.home_farm_radii.x + 24, 0)
		for i in range(150):
			walker = Vector2(s.move_actor(walker, walker.move_toward(goal, 3), 9.6))
		if walker.distance_to(goal) > 3:
			Cs.fail("Home farm %s central aisle is blocked" % [type])
			return
		var outside: int = nodes.filter(func(n): return int(n["type"]) == type and not WorldHomeFarms.in_home_farm(Vector2(n["pos"]))).size()
		if outside != w.outside_after[type] or absf(w.outside_after[type] - w.outside_before[type] * 0.75) > 3.5:
			Cs.fail("Outer material %s did not decrease by 25 percent" % [type])
			return
		print("HOME FARM %s: %s nodes, opaque ground, clear aisle; outer %s -> %s" % [type, here.size(), w.outside_before[type], w.outside_after[type]])
	if w.harvest_sites.filter(func(p): return p.type == 3 and w.in_cave_floor(p.pos)).size() != 19:
		Cs.fail("The wood/stone/herb reduction changed titanium veins")
		return
	if w.garden_beds.any(func(b): return w.harvest_sites.filter(func(p): return p.type == 2 and b.has_point(p.pos)).size() != 6):
		Cs.fail("The outer herb reduction did not preserve all six garden beds")
		return
	var titanium = Array(nodes.filter(func(n): return int(n["type"]) == 3 and not n.get("ambient", false))).duplicate()
	var sites = [5, 6, 7, 13, 14]
	for i in range(titanium.size()):
		var id: int = sites[i % sites.size()]
		if not (id == 5 or id == 7):
			continue
		var p: Vector2 = Vector2(titanium[i]["pos"])
		var soil = Cs.first_or_default(WorldGeometry.landmark_soils, func(s): return s.id == id)
		if WorldLandmarkDetails.soil_coverage(soil, p - w.lm_at[id]) < 0.95 or w.in_expedition_aisle(p):
			Cs.fail("Titanium at site %s follows the old map centre or blocks a passage" % [id])
			return
	for id in [5, 7, 11]:
		var site = w.expedition_sites[id]
		var p: Vector2 = site.centre + Vector2(0, site.half.y + 8) if id == 11 else site.centre + Vector2(-site.half.x - 5, 60 if id == 5 else 4)
		var goal: Vector2 = site.centre - Vector2(0, site.half.y + 8) if id == 11 else site.centre + Vector2(site.half.x + 5, 60 if id == 5 else 4)
		var i: int = 0
		while i < 500 and p.distance_to(goal) > 2:
			p = Vector2(s.move_actor(p, p.move_toward(goal, 3), 9.6))
			i += 1
		if p.distance_to(goal) > 3:
			Cs.fail("Resources block expedition passage %s at %s" % [id, Cs.s(p / 32)])
			return
	for id in [6, 13]:
		var gate: Vector2 = w.compound_gates[id]
		var goal: Vector2 = w.lm_at[id] + Vector2(0, -35)
		var p: Vector2 = gate + Vector2(0, 48)
		var i: int = 0
		while i < 200 and p.distance_to(goal) > 2:
			p = Vector2(s.move_actor(p, p.move_toward(goal, 3), 9.6))
			i += 1
		if p.distance_to(goal) > 3:
			Cs.fail("Resources obstruct compound %s entrance at %s" % [id, Cs.s(p / 32)])
			return
		goal = gate + Vector2(0, 48)
		i = 0
		while i < 200 and p.distance_to(goal) > 2:
			p = Vector2(s.move_actor(p, p.move_toward(goal, 3), 9.6))
			i += 1
		if p.distance_to(goal) > 3:
			Cs.fail("Resources obstruct compound %s exit" % [id])
			return
	print("COMPOUND RESOURCE ACCESS ALL OK: both enclosed compounds can be entered and exited with all resources present")
	for id in [12, 17]:
		var p: Vector2 = w.compound_entrances[id]
		var goal: Vector2 = w.lm_at[id]
		var i: int = 0
		while i < 180 and p.distance_to(goal) > 2:
			p = Vector2(s.move_actor(p, p.move_toward(goal, 3), 9.6))
			i += 1
		if p.distance_to(goal) > 3:
			Cs.fail("Resources block lookout %s entrance" % [id])
			return
		goal = w.compound_entrances[id]
		i = 0
		while i < 180 and p.distance_to(goal) > 2:
			p = Vector2(s.move_actor(p, p.move_toward(goal, 3), 9.6))
			i += 1
		if p.distance_to(goal) > 3:
			Cs.fail("Resources block lookout %s exit" % [id])
			return
	print("LOOKOUT RESOURCE ACCESS ALL OK: both observation decks remain accessible with all resources present")
	print("EXPEDITION RESOURCE ACCESS ALL OK: titanium follows rebuilt scenes and every passage remains clear with all resources present")
	print("RESOURCE LAYOUT ALL OK")
	get_tree().quit()
	# catch (Exception E) dropped
