class_name LandmarkGroundMask
extends RefCounted
# Static terrain queries for a small decoration patch. Keep only nearby route segments, floors and ponds,
# and pre-check bilinear grid bounds instead of testing every feature on the island for each painted pixel.
# This never changes gameplay collision or navigation.
var world
var segments = []
var floors: Array[Rect2] = []
var ponds: Array = []
var mask_max_margin: float = 8.0
var no_river: bool = false
var all_inland: bool = false
var all_grass: bool = false
var has_dock: bool = false
var has_bridge: bool = false

var segment_count: int:
	get:
		return segments.size()

func _init(world_, area: Rect2, max_margin: float = 8, include_trails: bool = true) -> void:
	self.world = world_
	mask_max_margin = max_margin
	var floor_area: Rect2 = area.grow(max_margin + 2.0)
	for _it1 in world_.floors:
		var floor_: Rect2 = _it1[0]
		if floor_.intersects(floor_area):
			floors.append(floor_)
	for pond in world_.ponds:
		var reach: float = pond.radius * 1.6 + max_margin + 2.0
		var pond_bounds := Rect2(pond.centre - Vector2.ONE * reach, Vector2.ONE * (reach * 2.0))
		if pond_bounds.intersects(area):
			ponds.append(pond)
	_precompute_grid_flags(area.grow(2.0), max_margin)
	var span: Rect2 = area.grow(max_margin + 2.0)
	for d in IslandMap.docks:
		if d.intersects(span):
			has_dock = true
			break
	for i in range(IslandMap.bridges.size()):
		if IslandMap.bridge_deck(i).intersects(span):
			has_bridge = true
			break
	if not include_trails:
		return
	for _it1 in world_.trails:
		var path = _it1[0]
		var width = _it1[1]
		var i: int = 0
		while i < path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var delta: Vector2 = b - a
			var bounds: Rect2 = Rect2(a.min(b), delta.abs()).grow(width / 2 + max_margin)
			if bounds.intersects(area):
				segments.append([a, delta, maxf(delta.length_squared(), 0.001), width / 2])
			i += 1

func _precompute_grid_flags(area: Rect2, max_margin: float) -> void:
	var tl: float = IslandMap.TL
	var reach: float = float(IslandMap.REACH)
	var step: float = IslandMap.STEP
	var n: int = IslandMap.N
	var fx0: float = (area.position.x / tl + reach) / step
	var fy0: float = (area.position.y / tl + reach) / step
	var fx1: float = (area.end.x / tl + reach) / step
	var fy1: float = (area.end.y / tl + reach) / step
	if fx0 >= 0.0 and fy0 >= 0.0 and fx1 < float(n - 1) and fy1 < float(n - 1):
		var gx0: int = int(floorf(fx0))
		var gy0: int = int(floorf(fy0))
		var gx1: int = mini(n - 1, int(floorf(fx1)) + 1)
		var gy1: int = mini(n - 1, int(floorf(fy1)) + 1)
		var coast_g = IslandMap.coast_depth
		var grass_g = IslandMap.grass_depth
		var inland_ok: bool = true
		var grass_ok: bool = true
		for gy in range(gy0, gy1 + 1):
			var row_off: int = gy * n
			for gx in range(gx0, gx1 + 1):
				var idx: int = row_off + gx
				if inland_ok and coast_g[idx] < 0.0:
					inland_ok = false
				if grass_ok and grass_g[idx] < max_margin:
					grass_ok = false
			if not inland_ok and not grass_ok:
				break
		all_inland = inland_ok
		all_grass = grass_ok
	if IslandMap.river_grid == null:
		no_river = true
		return
	var rstep: float = IslandMap.RSTEP
	var rn: int = IslandMap.RN
	var rx0: int = maxi(0, int(floorf((area.position.x / tl + reach) / rstep)))
	var ry0: int = maxi(0, int(floorf((area.position.y / tl + reach) / rstep)))
	var rx1: int = mini(rn - 1, int(floorf((area.end.x / tl + reach) / rstep)) + 1)
	var ry1: int = mini(rn - 1, int(floorf((area.end.y / tl + reach) / rstep)) + 1)
	var river_clear: float = IslandMap.RIVER_HALF + IslandMap.RIVER_BANK + max_margin
	var rgrid = IslandMap.river_grid
	var river_ok: bool = true
	for gy in range(ry0, ry1 + 1):
		var row_off: int = gy * rn
		for gx in range(rx0, rx1 + 1):
			if rgrid[row_off + gx] < river_clear:
				river_ok = false
				break
		if not river_ok:
			break
	no_river = river_ok

# Same accepted terrain types as TerrainAt(P, Margin) is 0 or 4 or 9, within the constructor's area.
func can_paint(p: Vector2, margin: float, allow_beach: bool = false, preserve_trails: bool = true) -> bool:
	var fast: bool = margin <= mask_max_margin and margin >= 0.0
	if not (fast and no_river):
		if IslandMap.in_river(p, IslandMap.RIVER_BANK + margin):
			return false
	if not (fast and all_inland):
		if margin >= 0.0:
			if IslandMap.depth(p) < 0.0 and not (has_dock and IslandMap.on_dock(p, 0.0)) and not (has_bridge and IslandMap.on_bridge(p, 0.0)):
				return false
		elif not IslandMap.on_land(p):
			return false
	if not allow_beach and not (fast and all_grass):
		if IslandMap.grass_in(p) < margin:
			return false
	for floor_: Rect2 in floors:
		if p.x >= floor_.position.x - margin and p.y >= floor_.position.y - margin and p.x < floor_.end.x + margin and p.y < floor_.end.y + margin:
			return false
	for pond in ponds:
		var reach: float = pond.radius * 1.6 + margin
		if p.distance_squared_to(pond.centre) < reach * reach and IslandMap.in_polygon(pond.edge, p):
			return false
	# Hidden routes should not leave grass-coloured slashes across a landmark's soil.
	if not preserve_trails:
		return true
	for _it2 in segments:
		var a: Vector2 = _it2[0]
		var delta: Vector2 = _it2[1]
		var length2: float = _it2[2]
		var half_width: float = _it2[3]
		var t: float = clampf((p - a).dot(delta) / length2, 0.0, 1.0)
		var reach: float = half_width + margin
		if p.distance_squared_to(a + delta * t) < reach * reach:
			return false
	return true
