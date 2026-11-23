class_name WorldRivers
extends RefCounted

# Part of WorldGeometry (src/world/world_geometry.gd); in the C# version this was src/world/WorldRivers.cs.
# Builds part of the island; the world data lives on WorldGeometry, passed in as `world`.
# Owner: Vu Duc Viet Anh. Where the paths meet the rivers (src/world/IslandRivers.cs). A path that crosses on a
# bridge runs on over it. A path the water cuts anywhere else stops at the bank and turns along it to the nearest
# bridge on that side, so no path just ends at the water; one too far from any bridge ends at the bank.
# the longest walk along a bank to a bridge, in tiles
const BANK_WALK: float = 45.0

# constants shared with WorldGeometry
const TL = WorldGeometry.TL

static func cut_paths_at_rivers(world: WorldGeometry) -> void:
	if IslandMap.rivers.size() == 0:
		return
	var out = []
	var extra = []
	var k: int = 0
	while k < world.trails.size():
		var _d1 = world.trails[k]
		var path = _d1[0]
		var width = _d1[1]
		var pieces = cut_path(world, path, width)
		# the first piece keeps the path's place in the list (the door roads are the first three)
		out.append([pieces[0], width] if pieces.size() > 0 else [path, width])
		var i: int = 1
		while i < pieces.size():
			extra.append([pieces[i], width])
			i += 1
		k += 1
	world.trails.clear()
	world.trails.append_array(out)
	world.trails.append_array(extra)

static func wet(world: WorldGeometry, p: Vector2, width: float) -> bool:
	return IslandMap.in_river(p, IslandMap.RIVER_BANK + width / 2) and not IslandMap.near_bridge(p)

static func cut_path(world: WorldGeometry, path, width: float) -> Variant:
	var pieces = []
	var i: int = 0
	while i < path.size():
		while i < path.size() and wet(world, path[i], width):
			i += 1
		var start: int = i
		while i < path.size() and not wet(world, path[i], width):
			i += 1
		if i - start < 2:
			continue
		var piece = Array(path.slice(start, i)).duplicate()
		# cut by water at either end: turn along the bank to a bridge
		if i < path.size():
			piece.append_array(bank_walk(world, path[i - 1], width))
		if start > 0:
			var before = bank_walk(world, path[start], width)
			before.reverse()
			Cs.insert_range(piece, 0, before)
		pieces.append(Array(piece).duplicate())
	if pieces.size() == 0:
		pieces.append(path)
	return pieces

# From a path's last dry point by a river, along that bank to the nearest bridge on the river (empty when
# there is none near enough, or the bank runs into the sea first).
static func bank_walk(world: WorldGeometry, from: Vector2, width: float) -> Variant:
	var walk = []
	var best: int = -1
	var at_: int = 0
	var bd: float = 3.4028235e38
	for r in range(IslandMap.rivers.size()):
		var p = IslandMap.rivers[r]
		for j in range(p.size()):
			var d: float = p[j].distance_squared_to(from)
			if d < bd:
				bd = d
				best = r
				at_ = j
	if best < 0:
		return walk
	var river = IslandMap.rivers[best]
	var target: int = -1
	var steps_: float = 3.4028235e38
	for _it1 in IslandMap.bridges:
		var r = _it1[0]
		var bridge = _it1[1]
		if r != best:
			continue
		var bi: int = 0
		var bbd: float = 3.4028235e38
		for j in range(river.size()):
			var d: float = river[j].distance_squared_to(bridge)
			if d < bbd:
				bbd = d
				bi = j
		if absi(bi - at_) < steps_:
			steps_ = absi(bi - at_)
			target = bi
	# the river's points are half a tile apart
	if target < 0 or steps_ * 0.5 > BANK_WALK:
		return walk
	var side: float = signf((from - river[at_]).dot(_bank_walk_normal(world, at_, river)))
	if side == 0:
		side = 1
	var off: float = IslandMap.RIVER_HALF + IslandMap.RIVER_BANK + width / 2 + 0.3 * TL
	var dir: int = signi(target - at_)
	# every other point (a tile apart), stopping where the bridge's deck begins
	var j: int = at_
	while j != target:
		if (j - at_) % 2 != 0:
			j += dir
			continue
		var p: Vector2 = river[j] + _bank_walk_normal(world, j, river) * side * off
		if IslandMap.depth(p) < TL:
			return []
		if IslandMap.near_bridge(p, 0.5 * TL):
			break
		walk.append(p)
		j += dir
	# onto the end of the deck
	var deck: Vector2 = river[target] + _bank_walk_normal(world, target, river) * side * (IslandMap.BRIDGE_HALF_LEN - 0.5 * TL)
	walk.append(deck)
	return walk

# local function Normal of the method above
static func _bank_walk_normal(world: WorldGeometry, j: int, river) -> Vector2:
	var along: Vector2 = (river[mini(j + 1, river.size() - 1)] - river[maxi(j - 1, 0)]).normalized()
	return Vector2(-along.y, along.x)
