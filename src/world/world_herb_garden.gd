class_name WorldHerbGarden
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldHerbGarden.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

# constants shared with WorldGeometry
const TL = WorldGeometry.TL

static func build_abandoned_garden(world: WorldGeometry) -> void:
	world.garden_centre = WorldLandmarks.at(world, 18).round()
	world.lm_at[18] = world.garden_centre
	world.garden_beds.clear()
	world.garden_fence.clear()
	for y in [-3.8, -0.3, 3.2]:
		for side in [-1, 1]:
			world.garden_beds.append(Rect2(world.garden_centre + WorldLandmarks.tl(side * 4.3 - 2.5, y - 1.1), WorldLandmarks.tl(5, 2.2)))
	var nw: Vector2 = world.garden_bounds.position
	var se: Vector2 = world.garden_bounds.end
	_build_abandoned_garden_fence(world, nw, Vector2(se.x, nw.y))
	_build_abandoned_garden_fence(world, nw, Vector2(nw.x, se.y))
	_build_abandoned_garden_fence(world, Vector2(se.x, nw.y), se)
	_build_abandoned_garden_fence(world, Vector2(nw.x, se.y), world.garden_entrance - WorldLandmarks.tl(1.5, 0))
	_build_abandoned_garden_fence(world, world.garden_entrance + WorldLandmarks.tl(1.5, 0), se)
	WorldLandmarks.prop(world, world.garden_entrance, "lm_arch_0")
	WorldLandmarks.solid(world, world.garden_entrance + Vector2(-46, 0), 8)
	WorldLandmarks.solid(world, world.garden_entrance + Vector2(46, 0), 8)
	WorldLandmarks.prop(world, world.garden_centre + WorldLandmarks.tl(-6.7, -5.0), "lm_waterpump_0")
	WorldLandmarks.prop(world, world.garden_centre + WorldLandmarks.tl(6.7, -5.0), "lm_rainbarrel_0")
	WorldLandmarks.prop(world, world.garden_centre + WorldLandmarks.tl(6.5, 5.0), "lm_pots_0")
	WorldLandmarks.prop(world, world.garden_centre + WorldLandmarks.tl(-6.5, 5.0), "lm_can_0")
	WorldLandmarks.clear(world, world.garden_centre, WorldGeometry.garden_half.length() + TL)
	world.compound_entrances[18] = world.garden_entrance + WorldLandmarks.tl(0, 1.2)

# local function Fence of the method above
static func _build_abandoned_garden_fence(world: WorldGeometry, a: Vector2, b: Vector2) -> void:
	WorldLandmarkScale.compound_line(world, a, b, 8)
	var n: int = maxi(1, int(ceilf(a.distance_to(b) / (1.6 * TL))))
	for i in range(n):
		world.garden_fence.append([a.lerp(b, i / float(n)).round(), a.lerp(b, (i + 1.0) / n).round()])

static func add_garden_herbs(world: WorldGeometry) -> void:
	var i: int = 0
	for bed in world.garden_beds:
		for y in [-0.43, 0.43]:
			for x in [-1.7, -0.57, 0.57, 1.7]:
				var p: Vector2 = (bed.get_center() + WorldLandmarks.tl(x, y)).round()
				var _old1 = i
				i += 1
				world.harvest_sites.append(Harvestables.Site.new(p, "node_herb_" + Cs.s(_old1 % 2), 2, 0))
