class_name WorldExpeditionSites
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldExpeditionSites.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

static func expedition_half(id: int) -> Vector2:
	return Vector2(220, 144) if id == 5 else Vector2(306, 183) if id == 7 else Vector2(204, 222) if id == 11 else Vector2.ZERO

static func expedition_centre(world: WorldGeometry, id: int, half: Vector2) -> Vector2:
	var c: Vector2 = WorldLandmarkScale.compound_spot(world, id, half)
	world.expedition_sites[id] = ExpeditionSite.new(id, c, half)
	world.lm_at[id] = c
	# Keep random vegetation out of the designed ground and the walking corridors.
	WorldLandmarks.clear(world, c, half.length() + 12)
	world.compound_entrances[id] = c + Vector2(0, half.y - 12)
	return c

static func expedition_prop(world: WorldGeometry, p: Vector2, sprite) -> void:
	WorldLandmarks.prop(world, p.round(), sprite)

static func expedition_car(world: WorldGeometry, id: int, p: Vector2, model: int, tilt: float = 0) -> void:
	world.expedition_vehicles.append(ExpeditionVehicle.new(id, p, model, tilt))
	var half: float = 70 if model == 0 else 82
	# Preserve a path around the trucks. The body, rather than an oversized circular sprite, is solid.
	WorldLandmarkScale.compound_line(world, p + Vector2(-half + 15, -15), p + Vector2(half - 15, -15), 22)

static func build_bayside_scene(world: WorldGeometry) -> void:
	var c: Vector2 = expedition_centre(world, 5, expedition_half(5))
	expedition_car(world, 5, c, 0, -0.12)
	# A snapped roadside barrier, a winch and recovered cargo describe a failed rescue attempt.
	expedition_prop(world, c + Vector2(-150, -74), "lm_barricade_0")
	expedition_prop(world, c + Vector2(-79, -110), "lm_barricade_0")
	expedition_prop(world, c + Vector2(157, 10), "lm_cable_0")
	WorldLandmarks.solid(world, c + Vector2(157, 3), 14)
	expedition_prop(world, c + Vector2(128, -73), "lm_crate_0")
	expedition_prop(world, c + Vector2(178, -57), "lm_drum_1")
	expedition_prop(world, c + Vector2(-134, 80), "lm_scrap_0")
	expedition_prop(world, c + Vector2(-63, 111), "lm_rope_0")
	expedition_prop(world, c + Vector2(141, 103), "lm_warning_0")

static func build_convoy_scene(world: WorldGeometry) -> void:
	var c: Vector2 = expedition_centre(world, 7, expedition_half(7))
	# Symmetric foot anchors centre the whole convoy, rather than using the truck in one side lane.
	expedition_car(world, 7, c + Vector2(-178, -38), 1, -0.04)
	expedition_car(world, 7, c + Vector2(0, 76), 2, 0.035)
	expedition_car(world, 7, c + Vector2(178, -38), 3, -0.07)
	expedition_prop(world, c + Vector2(-241, 117), "lm_barricade_0")
	expedition_prop(world, c + Vector2(230, 123), "lm_barricade_0")
	expedition_prop(world, c + Vector2(-135, -133), "lm_cargo_stack_0")
	expedition_prop(world, c + Vector2(-49, -118), "lm_pallet_0")
	expedition_prop(world, c + Vector2(42, -130), "lm_crate_0")
	expedition_prop(world, c + Vector2(111, -117), "lm_drum_0")
	expedition_prop(world, c + Vector2(5, -154), "lm_radio_0")
	expedition_prop(world, c + Vector2(183, 88), "lm_scrap_0")
	expedition_prop(world, c + Vector2(-133, 122), "lm_expedition_0")
	expedition_prop(world, c + Vector2(249, -127), "lm_warning_0")

static func build_northwind_scene(world: WorldGeometry) -> void:
	var c: Vector2 = expedition_centre(world, 11, expedition_half(11))
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
			world.expedition_cliffs.append(ExpeditionCliff.new(a, b, face, cap))
			WorldLandmarkScale.compound_line(world, a, b, 12)
	expedition_prop(world, c + Vector2(-143, -187), "lm_windsock_0")
	expedition_prop(world, c + Vector2(133, -183), "lm_cairn_0")
	WorldLandmarks.solid(world, c + Vector2(133, -183), 12)
	expedition_prop(world, c + Vector2(-135, 194), "lm_signpost_0")
	expedition_prop(world, c + Vector2(134, 190), "lm_cairn_0")
	WorldLandmarks.solid(world, c + Vector2(134, 190), 12)
	expedition_prop(world, c + Vector2(168, -43), "lm_expedition_0")

static func in_expedition_aisle(world: WorldGeometry, p: Vector2) -> bool:
	for site in world.expedition_sites.values():
		var d: Vector2 = p - site.centre
		if site.id == 11 and absf(d.x) < 63 and absf(d.y) < site.half.y + 32:
			return true
		if (site.id == 5 or site.id == 7) and absf(d.y - (60 if site.id == 5 else 4)) < 28 and absf(d.x) < site.half.x + 20:
			return true
	return false

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
