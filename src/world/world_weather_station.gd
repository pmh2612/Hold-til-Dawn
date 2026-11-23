class_name WorldWeatherStation
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldWeatherStation.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

# constants shared with WorldGeometry
const TL = WorldGeometry.TL

static func is_weather_interior(world: WorldGeometry, p: Vector2) -> bool:
	return Cs.has_point(world.weather_room.grow(-10), p)

static func build_weather_station(world: WorldGeometry) -> void:
	world.weather_centre = WorldLandmarkScale.compound_spot(world, 9, WorldGeometry.weather_half + Vector2(56, 80))
	world.lm_at[9] = world.weather_centre
	world.compounds[9] = world.weather_room
	world.weather_walls.clear()
	world.weather_wall_faces.clear()
	var nw: Vector2 = world.weather_room.position
	var se: Vector2 = world.weather_room.end
	_build_weather_station_wall(world, nw, Vector2(se.x, nw.y))
	_build_weather_station_wall(world, nw, Vector2(nw.x, se.y))
	_build_weather_station_wall(world, Vector2(se.x, nw.y), se)
	_build_weather_station_wall(world, Vector2(nw.x, se.y), world.weather_entrance - Vector2(42, 0))
	_build_weather_station_wall(world, world.weather_entrance + Vector2(42, 0), se)
	world.floors.append([world.weather_room, false])
	WorldLandmarks.clear(world, world.weather_centre, 8 * TL)
	world.compound_entrances[9] = world.weather_entrance + Vector2(0, 40)
	# Scenery only: these names have no harvest, use, loot or crafting behaviour.
	WorldLandmarks.prop(world, world.weather_centre + Vector2(-76, -55), "lm_console_0")
	WorldLandmarks.prop(world, world.weather_centre + Vector2(78, -61), "lm_rack_0")
	WorldLandmarks.solid(world, world.weather_centre + Vector2(-76, -55), 24)
	WorldLandmarks.solid(world, world.weather_centre + Vector2(78, -61), 22)
	WorldLandmarks.prop(world, world.weather_centre + Vector2(104, 35), "lm_crate_0")
	WorldLandmarks.solid(world, world.weather_centre + Vector2(104, 35), 16)
	WorldLandmarks.prop(world, world.weather_centre + Vector2(-224, -16), "lm_radar_0")
	WorldLandmarks.solid(world, world.weather_centre + Vector2(-224, -16), 14)
	WorldLandmarks.prop(world, world.weather_centre + Vector2(220, 20), "lm_solar_0")
	WorldLandmarks.solid(world, world.weather_centre + Vector2(220, 20), 15)
	WorldLandmarks.prop(world, world.weather_centre + Vector2(205, -112), "lm_windsock_0")
	WorldLandmarks.solid(world, world.weather_centre + Vector2(205, -112), 5)

# local function Wall of the method above
static func _build_weather_station_wall(world: WorldGeometry, a: Vector2, b: Vector2) -> void:
	world.weather_walls.append([a, b])
	WorldLandmarkScale.compound_line(world, a, b, 9)
	world.weather_wall_faces.append([a, b, b - Vector2(0, 56), a - Vector2(0, 56)])
