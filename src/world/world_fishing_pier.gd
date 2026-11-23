class_name WorldFishingPier
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldFishingPier.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.

# constants shared with WorldGeometry
const LANDMARK_SCALE = WorldGeometry.LANDMARK_SCALE

static func build_fishing_details(world: WorldGeometry, land: Vector2) -> void:
	world.fishing_rods.clear()
	world.fishing_fish.clear()
	world.fishing_litter.clear()
	world.fishing_litter_faces.clear()
	var deck: Rect2 = IslandMap.docks[0]
	# Feet sit on the deck edge, with lines hanging out over the sea.
	for _it1 in [[0.18, -1], [0.47, 1], [0.76, -1]]:
		var fraction = _it1[0]
		var side = _it1[1]
		world.fishing_rods.append([Vector2(lerpf(deck.position.x, deck.end.x, fraction), land.y + side * 20 * LANDMARK_SCALE).round(), side])
	for i in range(8):
		var side: int = -1 if i % 2 == 0 else 1
		var p: Vector2 = Vector2(lerpf(deck.position.x - 34, deck.end.x - 48, (i + 0.5) / 8), land.y + side * (66 + i % 3 * 24))
		if not IslandMap.on_land(p, -16) and not IslandMap.on_land(p + Vector2(28, 0), -12) and not IslandMap.on_land(p - Vector2(28, 0), -12) and not Cs.has_point(deck.grow(24), p):
			world.fishing_fish.append(p.round())
	for i in range(12):
		var p: Vector2 = Vector2(lerpf(deck.position.x + 30, deck.end.x - 26, i / 5.0), land.y + (-1 if i % 2 == 0 else 1) * 17) if i < 5 else land + WorldLandmarks.tl(0.8 + i % 3 * 0.7, (-1 if i % 2 == 0 else 1) * (1.0 + i % 3 * 0.6))
		if i < 5 or IslandMap.on_land(p, 6):
			p = p.round()
			world.fishing_litter.append([p, i % 4])
			world.fishing_litter_faces.append([p + Vector2(-6, -3), p + Vector2(3, -5), p + Vector2(8, 1), p + Vector2(-2, 4)])
