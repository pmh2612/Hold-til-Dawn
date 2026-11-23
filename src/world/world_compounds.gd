class_name WorldCompounds
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldCompounds.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.
static var ruin_half: Vector2 = Vector2(4.5, 3.2) * TL * LANDMARK_SCALE
static var yard_half: Vector2 = Vector2(6.2, 3.8) * TL * LANDMARK_SCALE * sqrt(YARD_AREA_SCALE)

# constants shared with WorldGeometry
const LANDMARK_SCALE = WorldGeometry.LANDMARK_SCALE
const TL = WorldGeometry.TL
const YARD_AREA_SCALE = WorldGeometry.YARD_AREA_SCALE

static func build_compound_perimeter(world: WorldGeometry, id: int, floor_: Rect2, gate_width: float) -> void:
	var edge: Rect2 = floor_.grow(-8)
	var nw: Vector2 = edge.position
	var se: Vector2 = edge.end
	var gate: Vector2 = Vector2(floor_.get_center().x, se.y)
	world.compound_gates[id] = gate
	world.compound_entrances[id] = gate + Vector2(0, 28)
	_build_compound_perimeter_side(world, nw, Vector2(se.x, nw.y), 0, id)
	_build_compound_perimeter_side(world, nw, Vector2(nw.x, se.y), 1, id)
	_build_compound_perimeter_side(world, Vector2(se.x, nw.y), se, 2, id)
	_build_compound_perimeter_side(world, Vector2(nw.x, se.y), gate - Vector2(gate_width / 2, 0), 3, id)
	_build_compound_perimeter_side(world, gate + Vector2(gate_width / 2, 0), se, 3, id)

# local function Side of the method above
static func _build_compound_perimeter_side(world: WorldGeometry, a: Vector2, b: Vector2, side_id: int, id) -> void:
	WorldLandmarkScale.compound_line(world, a, b, 8)
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
		world.compound_boundaries.append(CompoundBoundary.new(id, side_id, p, q, height, face, cap, Array(wire).duplicate()))
		i += 1

static func build_ruined_compound(world: WorldGeometry) -> void:
	var c: Vector2 = WorldLandmarkScale.compound_spot(world, 6, ruin_half)
	var floor_ = Rect2(c - ruin_half, ruin_half * 2)
	world.floors.append([floor_, true])
	world.compounds[6] = floor_
	world.lm_at[6] = c
	build_compound_perimeter(world, 6, floor_, 100)
	# The whole roof has fallen in; four standing, damaged walls describe the original base.
	WorldLandmarks.prop(world, c + Vector2(-94, 14), "lm_roof_fallen_0")
	WorldLandmarkScale.compound_line(world, c + Vector2(-130, 7), c + Vector2(-67, 18), 15)
	WorldLandmarks.prop(world, c + Vector2(103, 48), "lm_roof_fallen_0")
	WorldLandmarkScale.compound_line(world, c + Vector2(75, 40), c + Vector2(135, 51), 14)
	WorldLandmarks.prop(world, c + Vector2(-107, -70), "lm_rack_0")
	WorldLandmarks.solid(world, c + Vector2(-107, -75), 15)
	WorldLandmarks.prop(world, c + Vector2(81, -69), "lm_console_0")
	WorldLandmarks.prop(world, c + Vector2(135, -60), "lm_mast_0")
	WorldLandmarks.prop(world, c + Vector2(77, -13), "lm_radio_0")
	WorldLandmarks.prop(world, c + Vector2(-133, 80), "lm_generator_0")
	WorldLandmarks.solid(world, c + Vector2(-133, 75), 15)
	WorldLandmarks.prop(world, c + Vector2(-77, 88), "lm_cable_0")
	WorldLandmarks.prop(world, c + Vector2(136, 87), "lm_crate_0")
	WorldLandmarks.prop(world, c + Vector2(104, -88), "lm_crate_0")
	WorldLandmarks.prop(world, c + Vector2(-49, -81), "lm_expedition_0")
	WorldLandmarks.prop(world, c + Vector2(132, -4), "lm_drum_1")
	WorldLandmarks.prop(world, c + Vector2(-129, -31), "lm_rubble_0")
	WorldLandmarks.prop(world, c + Vector2(100, 22), "lm_rubble_1")
	WorldLandmarks.prop(world, c + Vector2(-62, 54), "lm_rubble_1")
	WorldLandmarks.prop(world, c + Vector2(65, 88), "lm_rubble_0")
	WorldLandmarks.prop(world, c + Vector2(-81, -99), "lm_scrap_0")
	WorldLandmarks.prop(world, c + Vector2(-133, 113), "lm_warning_0")
	WorldLandmarks.clear(world, c, ruin_half.length() + TL)

static func build_container_compound(world: WorldGeometry) -> void:
	var c: Vector2 = WorldLandmarkScale.compound_spot(world, 13, yard_half)
	var floor_ = Rect2(c - yard_half, yard_half * 2)
	world.floors.append([floor_, true])
	world.compounds[13] = floor_
	world.lm_at[13] = c
	build_compound_perimeter(world, 13, floor_, 144)
	# Rear bays, another long container at the front and a genuinely open end-on container.
	for _it1 in [[c + Vector2(-142, -105), "lm_container_1"], [c + Vector2(142, -105), "lm_container_0"], [c + Vector2(-157, 108), "lm_container_0"]]:
		var p = _it1[0]
		var sprite = _it1[1]
		WorldLandmarks.prop(world, p, sprite)
		WorldLandmarkScale.compound_line(world, p + Vector2(-75, -8), p + Vector2(75, -8), 18)
	var open: Vector2 = c + Vector2(224, 73)
	WorldLandmarks.prop(world, open, "lm_container_end_0")
	WorldLandmarkScale.compound_line(world, open + WorldLandmarks.tl(-1, -2.6), open + WorldLandmarks.tl(-1, -0.25), 10)
	WorldLandmarkScale.compound_line(world, open + WorldLandmarks.tl(1, -2.6), open + WorldLandmarks.tl(1, -0.25), 10)
	WorldLandmarkScale.compound_line(world, open + WorldLandmarks.tl(-1, -2.6), open + WorldLandmarks.tl(1, -2.6), 10)
	WorldLandmarks.prop(world, c + Vector2(-110, 12), "lm_forklift_0")
	WorldLandmarkScale.compound_line(world, c + Vector2(-133, 5), c + Vector2(-91, 5), 15)
	WorldLandmarks.prop(world, c + Vector2(-258, 25), "lm_crane_0")
	WorldLandmarks.solid(world, c + Vector2(-258, 25), 18)
	WorldLandmarks.prop(world, c + Vector2(-89, -42), "lm_pallet_0")
	WorldLandmarks.prop(world, c + Vector2(-81, -37), "lm_cargo_stack_0")
	WorldLandmarks.prop(world, c + Vector2(91, 48), "lm_cargo_stack_0")
	WorldLandmarks.prop(world, c + Vector2(146, 134), "lm_pallet_0")
	WorldLandmarks.prop(world, c + Vector2(-256, 143), "lm_cable_0")
	WorldLandmarks.prop(world, c + Vector2(-52, 139), "lm_expedition_0")
	WorldLandmarks.prop(world, c + Vector2(261, 143), "lm_console_0")
	WorldLandmarks.prop(world, c + Vector2(93, 163), "lm_warning_0")
	WorldLandmarks.prop(world, c + Vector2(-95, 161), "lm_warning_0")
	for i in range(6):
		WorldLandmarks.prop(world, c + Vector2(84 + i % 3 * 26, 106 + i / 3 * 28), "lm_drum_" + str(i % 2))
	WorldLandmarks.prop(world, c + Vector2(-254, -37), "lm_cart_0")
	WorldLandmarks.prop(world, c + Vector2(254, -151), "lm_crate_0")
	WorldLandmarks.prop(world, c + Vector2(-250, -153), "lm_crate_0")
	WorldLandmarks.clear(world, c, yard_half.length() + TL)

static func in_compound_passage(world: WorldGeometry, p: Vector2) -> bool:
	for id in world.compounds:
		var floor_ = world.compounds[id]
		if (id == 6 or id == 13) and Cs.has_point(floor_.grow(48), p) and absf(p.x - floor_.get_center().x) < 35:
			return true
	return false

static func build_cave_compound(world: WorldGeometry) -> void:
	WorldCave.build_walkable_cave(world)

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
