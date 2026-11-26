class_name SimSupplies
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/world/GameSim.Supplies.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
static var RESCUE_IDS = ["locator_radio"]
const SUPPLY_COUNT: int = 3
const SUPPLY_PICK: float = 1.1
const RADIO_BUILD_TIME: float = 5.0
const CHEST_MIN_SPACING: float = 20.0 * GameSim.T
const CHEST_REGIONS: int = 9
const SCATTER_LANDMARK_CLEARANCE: float = 520.0
# Count beaches and offshore pier decks too; river banks are not coastline.
const CHEST_COAST_BAND: float = 10.0 * GameSim.T
const CHEST_COAST_LIMIT: int = 3
static var chest_prop_anchors = null

# constants shared with GameSim
const CHEST_REACH = GameSim.CHEST_REACH
const CHEST_UNLOCK_TIME = GameSim.CHEST_UNLOCK_TIME

static func rescue_kind(id) -> int:
	return RESCUE_IDS.find(id)

static func supplies_got(sim: GameSim) -> int:
	var count_: int = 0
	for n in sim.rescue_components:
		if n > 0:
			count_ += 1
	return count_

static func supplies_all_in(sim: GameSim) -> bool:
	return sim.radio_built

static func craft_have(sim: GameSim, p, id) -> int:
	var kind: int = GameSim.COMPONENT_IDS.find(id)
	return sim.rescue_components[kind] if kind >= 0 else SimInventory.count(sim, p, id)

static func cancel_radio_build(sim: GameSim) -> void:
	sim.radio_builder = null
	sim.radio_build_t = 0

static func clear_supplies(sim: GameSim) -> void:
	sim.exploration_chests.clear()
	Cs.array_clear(sim.rescue_components)
	Cs.array_clear(sim.radio_parts_placed)
	sim.radio_built = false
	cancel_radio_build(sim)
	for p in sim.players.values():
		cancel_chest_unlock(sim, p)
		p.open_chest = -1
		p.chest_use_seq = 0

static func place_supplies(sim: GameSim) -> void:
	clear_supplies(sim)
	cache_chest_scenery(sim)
	var random = sim.rng
	var places = Array(IslandMap.landmarks).duplicate()
	Cs.remove_all(places, func(l): return l.id <= 4)
	for i in range(places.size() - 1, 0, -1):
		var j: int = random.randi_range(0, i)
		var _t1 = places[j]
		var _t2 = places[i]
		places[i] = _t1
		places[j] = _t2
	var regions = range(CHEST_REGIONS)
	for i in range(regions.size() - 1, 0, -1):
		var j: int = random.randi_range(0, i)
		var old = regions[i]
		regions[i] = regions[j]
		regions[j] = old
	var support = GameSim.CHEST_SUPPORT.duplicate()
	for i in range(support.size() - 1, 0, -1):
		var j: int = random.randi_range(0, i)
		var _t3 = support[j]
		var _t4 = support[i]
		support[i] = _t3
		support[j] = _t4
	# Ten distinct landmarks, balanced across the island rather than taking the first ten shuffled sites.
	# One scattered chest per geographic region; the tenth fills the least populated region.
	# Parts can still be in any of the twenty chests.
	var part_chests = range(20)
	for i in range(19, 0, -1):
		var j: int = random.randi_range(0, i)
		var old = part_chests[i]
		part_chests[i] = part_chests[j]
		part_chests[j] = old
	for i in range(20):
		var c = ExplorationChest.new()
		c.id = i
		if i < 10:
			var counts = chest_region_counts(sim)
			var choice: int = 0
			for j in range(1, places.size()):
				if counts[chest_region(sim.world.lm_at[places[j].id])] < counts[chest_region(sim.world.lm_at[places[choice].id])]:
					choice = j
			var landmark = places[choice]
			places.remove_at(choice)
			c.landmark = landmark.id
			c.pos = chest_spot(sim, landmark, random.randf_range(0, TAU))
		else:
			var region: int = regions[i - 10] if i < 19 else least_populated_region(sim, regions)
			c.pos = scattered_chest_spot(sim, random, region)
		SimInventory.add_to(c.slots, "wood", random.randi_range(4, 10))
		SimInventory.add_to(c.slots, "stone", random.randi_range(3, 8))
		SimInventory.add_to(c.slots, "herb", random.randi_range(2, 5))
		SimInventory.add_to(c.slots, "titanium", random.randi_range(1, 3))
		# Named sites always get one support; scattered sites have a 35% chance. Eight slots suffice.
		if i < 10 or random.randf() < 0.35:
			SimInventory.add_to(c.slots, support[i % support.size()], 1)
		var part: int = part_chests.find(i)
		if part < 3:
			c.component = part
			SimInventory.add_to(c.slots, GameSim.COMPONENT_IDS[part], 1)
		sim.exploration_chests.append(c)

static func chest_region(at: Vector2) -> int:
	var local: Vector2 = (at - IslandMap.box.position) / IslandMap.box.size
	return clampi(int(local.y * 3), 0, 2) * 3 + clampi(int(local.x * 3), 0, 2)

static func chest_region_bounds(region: int) -> Rect2:
	return Rect2(IslandMap.box.position + Vector2(region % 3, region / 3) * IslandMap.box.size / 3, IslandMap.box.size / 3)

static func chest_region_counts(sim: GameSim) -> Array:
	var counts = Cs.arr(CHEST_REGIONS, 0)
	for chest in sim.exploration_chests:
		counts[chest_region(chest.pos)] += 1
	return counts

static func least_populated_region(sim: GameSim, regions: Array) -> int:
	var counts = chest_region_counts(sim)
	var best: int = regions[0]
	for region in regions:
		if counts[region] < counts[best]:
			best = region
	return best

static func nearest_chest_distance_squared(sim: GameSim, at: Vector2) -> float:
	var distance: float = INF
	for other in sim.exploration_chests:
		distance = minf(distance, other.pos.distance_squared_to(at))
	return distance

static func coastal_chest(at: Vector2) -> bool:
	return IslandMap.depth(at) <= CHEST_COAST_BAND

static func coastal_chest_count(sim: GameSim) -> int:
	var count_: int = 0
	for chest in sim.exploration_chests:
		if coastal_chest(chest.pos):
			count_ += 1
	return count_

static func scattered_chest_free(sim: GameSim, at: Vector2) -> bool:
	for centre in sim.world.lm_at.values():
		if at.distance_squared_to(centre) < SCATTER_LANDMARK_CLEARANCE * SCATTER_LANDMARK_CLEARANCE:
			return false
	return chest_spot_free(sim, at, sim.chest_scenery)

static func scattered_chest_spot(sim: GameSim, random, region: int) -> Vector2:
	var bounds: Rect2 = chest_region_bounds(region).grow(-32)
	var best: Vector2 = Vector2.INF
	var best_distance: float = -1
	var best_coastal: bool = true
	var found: int = 0
	# Prefer inland sites, then the widest gap among eight valid samples. Startup only.
	for attempt in range(1024):
		var at: Vector2 = (bounds.position + Vector2(random.randf(), random.randf()) * bounds.size).round()
		if not scattered_chest_free(sim, at):
			continue
		var distance: float = nearest_chest_distance_squared(sim, at)
		var coastal: bool = coastal_chest(at)
		if not best.is_finite() or (best_coastal and not coastal) or (best_coastal == coastal and distance > best_distance):
			best = at
			best_distance = distance
			best_coastal = coastal
		found += 1
		if found >= 8:
			break
	if best.is_finite():
		return best
	# A deterministic bounded fallback also prefers inland ground and obeys the coastal cap.
	var coastal_fallback: Vector2 = Vector2.INF
	for y in range(ceili(bounds.position.y), floori(bounds.end.y), 96):
		for x in range(ceili(bounds.position.x), floori(bounds.end.x), 96):
			var at = Vector2(x, y)
			if scattered_chest_free(sim, at):
				if not coastal_chest(at):
					return at
				if not coastal_fallback.is_finite():
					coastal_fallback = at
	if coastal_fallback.is_finite():
		return coastal_fallback
	Cs.fail("No accessible scattered chest spot in region %d" % region)
	return Vector2.ZERO

static func chest_spot(sim: GameSim, l, angle: float) -> Vector2:
	var w = sim.world
	var centre: Vector2 = w.lm_at.get(l.id, l.pos)
	var search = Rect2(centre - Vector2.ONE * 432, Vector2.ONE * 864)
	var scenery = sim.chest_scenery.filter(func(b): return b.intersects(search))
	# Search the full inland side first, reserving the small coastal budget for narrow shore sites.
	for allow_coast in [false, true]:
		var ring: float = 2
		while ring <= 12:
			for i in range(24):
				var at: Vector2 = (centre + Vector2.from_angle(angle + i * TAU / 24) * ring * 32).round()
				if not allow_coast and coastal_chest(at):
					continue
				if chest_region(at) == chest_region(centre) and chest_spot_free(sim, at, scenery):
					return at
			ring += 0.75
	Cs.fail("No accessible chest spot at landmark %s" % [l.id])
	return Vector2.ZERO

static func chest_spot_free(sim: GameSim, at: Vector2, scenery) -> bool:
	# Reject cheap distance / water checks before scanning the full artwork and resource caches.
	if nearest_chest_distance_squared(sim, at) < CHEST_MIN_SPACING * CHEST_MIN_SPACING:
		return false
	if coastal_chest(at) and coastal_chest_count(sim) >= CHEST_COAST_LIMIT:
		return false
	var w = sim.world
	if Cs.has_point(w.weather_room.grow(48), at) or not IslandMap.on_land(at, 32) or w.terrain_at(at) == 1 or SimWorld.inside_base(at) or IslandMap.in_bridge_approach(at, 32):
		return false
	var footprint = Rect2(at - Vector2(20, 33), Vector2(40, 40)).grow(8)
	for bounds in scenery:
		if bounds.intersects(footprint):
			return false
	for resource in sim.chest_resources:
		if resource.distance_squared_to(at) < 56 * 56:
			return false
	if not w.resolve_fast(at, 26).is_equal_approx(at):
		return false
	return not w.in_cave_region(at) or w.in_cave_floor(at)

# Physical trunks/vehicle bodies are smaller than their pictures. Reserve the complete artwork too.
# Cache once at placement, with no texture loads, scene nodes or per-frame scenery scans.
static func cache_chest_scenery(sim: GameSim) -> void:
	sim.chest_scenery.clear()
	sim.chest_resources.clear()
	if chest_prop_anchors == null:
		chest_prop_anchors = {}
		var index = JSON.parse_string(FileAccess.get_file_as_string("res://art/landmarks/index.json"))
		for key in index.keys():
			var meta = index[key]
			chest_prop_anchors[str(key)] = Vector2(float(meta[0]), float(meta[1]))
	var w = sim.world
	for _it1 in w.lm_props:
		var at = _it1[0]
		var sprite = _it1[1]
		var anchor: Vector2 = chest_prop_anchors.get(sprite, Vector2(32, 48))
		sim.chest_scenery.append(Rect2(at - anchor, Vector2(anchor.x * 2, anchor.y + 12)))
	for v in w.expedition_vehicles:
		sim.chest_scenery.append(Rect2(v.pos - Vector2(112, 120), Vector2(224, 150)))
	for cliff in w.expedition_cliffs:
		add_bounds(sim, cliff.cap)
	for b in w.compound_boundaries:
		add_bounds(sim, b.face)
	for o in w.lookout_objects:
		sim.chest_scenery.append(Rect2(o.pos - (Vector2(88, 110) if o.model == 0 else Vector2(38, 106)), Vector2(176, 140) if o.model == 0 else Vector2(76, 125)))
	for node in sim.nodes:
		var type: int = int(node.get("type"))
		var at: Vector2 = Vector2(node.get("pos"))
		sim.chest_resources.append(at)
		var width: float = 42 if type == 0 else 18 if type == 2 else 28
		var height: float = 110 if type == 0 else 26 if type == 2 else 60
		sim.chest_scenery.append(Rect2(at - Vector2(width, height), Vector2(width * 2, height + 10)))

static func add_bounds(sim: GameSim, points) -> void:
	if points.size() == 0:
		return
	var lo: Vector2 = points[0]
	var hi: Vector2 = points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	sim.chest_scenery.append(Rect2(lo, hi - lo))

static func chest_by_id(sim: GameSim, id: int) -> Variant:
	return sim.exploration_chests[id] if id >= 0 and id < sim.exploration_chests.size() else null

static func in_chest_reach(sim: GameSim, p, c) -> bool:
	return c != null and p.state == 0 and (sim.phase == "day" or sim.phase == "dusk" or sim.phase == "night") and not p.inside and Vector2(p.pos).distance_squared_to(c.pos) <= CHEST_REACH * CHEST_REACH and SimWorld.line_clear(sim, p.pos, c.pos)

static func can_access_chest(sim: GameSim, p, c) -> bool:
	return c != null and c.opened and in_chest_reach(sim, p, c)

static func open_chest_panel(sim: GameSim, p, id: int) -> void:
	var c = chest_by_id(sim, id)
	if not can_access_chest(sim, p, c):
		return
	cancel_chest_unlock(sim, p)
	p.open_chest = id
	p.chest_use_seq = p.get("chest_use_seq", 0) + 1
	p.inter = false
	p.activity = "loot"
	p.activity_target = c.pos

static func cancel_chest_unlock(sim: GameSim, p) -> void:
	var c = chest_by_id(sim, p.get("unlock_chest", -1))
	if c != null and c.unlocker == int(p.id):
		c.unlocker = null
		c.unlock_progress = 0
	p.unlock_chest = -1
	p.unlock_t = 0.0

static func unlock_interrupted(sim: GameSim, p, c) -> bool:
	return not in_chest_reach(sim, p, c) or not p.inter or p.atk or p.craft_idx >= 0 or float(p.channel) > 0 or SimInventory.count(sim, p, "chest_key") == 0 or Vector2(p.pos).distance_squared_to(Vector2(p.unlock_pos)) > 16 or float(p.taken) != float(p.unlock_damage)

static func tick_chest_access(sim: GameSim) -> void:
	for p in sim.players.values():
		var id: int = p.get("unlock_chest", -1)
		if id >= 0 and unlock_interrupted(sim, p, chest_by_id(sim, id)):
			cancel_chest_unlock(sim, p)
			p.inter = false
		if p.get("open_chest", -1) >= 0 and not can_access_chest(sim, p, chest_by_id(sim, int(p.open_chest))):
			p.open_chest = -1

static func try_loot_chest(sim: GameSim, p, dt: float = 0.05) -> bool:
	var current_phase = sim.phase
	if p.state != 0 or not (current_phase == "day" or current_phase == "dusk" or current_phase == "night"):
		return false
	for c in sim.exploration_chests:
		if not in_chest_reach(sim, p, c):
			continue
		if c.opened:
			open_chest_panel(sim, p, c.id)
			return true
		if SimInventory.count(sim, p, "chest_key") == 0:
			SimPlayers.note(sim, p, "Need chest key")
			p.inter = false
			return true
		var player_id: int = int(p.id)
		if c.unlocker != null and c.unlocker != player_id:
			SimPlayers.note(sim, p, "Chest in use")
			return true
		if int(p.unlock_chest) != c.id:
			cancel_chest_unlock(sim, p)
			p.unlock_chest = c.id
			p.unlock_pos = p.pos
			p.unlock_damage = p.taken
			c.unlocker = player_id
		if unlock_interrupted(sim, p, c):
			cancel_chest_unlock(sim, p)
			return true
		p.unlock_t += maxf(0, dt)
		c.unlock_progress = minf(1, float(p.unlock_t) / CHEST_UNLOCK_TIME)
		p.activity = "loot"
		p.activity_target = c.pos
		if float(p.unlock_t) + 0.00001 >= CHEST_UNLOCK_TIME and SimInventory.take(sim, p, "chest_key", 1):
			c.opened = true
			c.opened_at = float(sim.clock)
			cancel_chest_unlock(sim, p)
			open_chest_panel(sim, p, c.id)
			p.note = ""
			p.note_t = 0
		return true
	cancel_chest_unlock(sim, p)
	return false

# Only physically reachable, unlocked contents are published for the player's storage panel.
static func chest_contents_snapshot(sim: GameSim) -> Variant:
	var views = {}
	for p in sim.players.values():
		var c = chest_by_id(sim, p.get("open_chest", -1))
		if can_access_chest(sim, p, c):
			views[p.id] = [c.id, Array(c.slots.map(func(s):
				var a = s
				return Array(a).duplicate() if s is Array else s
			)).duplicate()]
	return views

static func at_radio(sim: GameSim, p) -> bool:
	return SimPlayers.in_base_to_work(sim, p) and SimWorld.near_radio(Vector2(p.pos))

static func place_radio_parts(sim: GameSim, p) -> void:
	if sim.radio_built or p.state != 0 or not at_radio(sim, p) or sim.phase != "day":
		return
	# C opens the station and transfers found quest parts into its three permanent slots.
	for i in range(3):
		if sim.rescue_components[i] > 0 and sim.radio_parts_placed[i] == 0:
			sim.radio_parts_placed[i] = 1

static func try_build_radio(sim: GameSim, p, dt: float) -> bool:
	if sim.radio_built or p.state != 0 or not at_radio(sim, p):
		return false
	if sim.phase != "day":
		SimPlayers.note(sim, p, "Day only")
		return true
	if p.atk or p.craft_idx >= 0 or p.channel > 0 or p.get("tower_build_t", 0.0) > 0 or p.get("repair_kit_t", 0.0) > 0:
		SimPlayers.note(sim, p, "Busy")
		return true
	if sim.radio_parts_placed.count(1) < 3:
		SimPlayers.note(sim, p, "Radio: %d/3 parts" % [sim.radio_parts_placed.count(1)])
		return true
	var id: int = int(p.id)
	if sim.radio_builder != null and sim.radio_builder != id:
		SimPlayers.note(sim, p, "Radio in use")
		return true
	if not sim.radio_builder != null:
		sim.radio_builder = id
		sim.radio_build_pos = p.pos
		sim.radio_build_damage = p.taken
		p.inter = false
	if Vector2(p.pos).distance_squared_to(sim.radio_build_pos) > 16 or float(p.taken) != sim.radio_build_damage:
		cancel_radio_build(sim)
		return true
	sim.radio_build_t += maxf(0, dt)
	p.activity = "craft"
	p.activity_target = GameSim.RADIO_POS
	if sim.radio_build_t + 0.00001 >= RADIO_BUILD_TIME:
		sim.radio_built = true
		cancel_radio_build(sim)
		SimPlayers.say(sim, "Radio online")
	return true

# Public chest state only. Contents and component assignments stay hidden.
static func supply_snapshot(sim: GameSim) -> Variant:
	var rows = []
	for c in sim.exploration_chests:
		rows.append([c.id, c.pos, c.empty, c.landmark, c.opened, c.unlock_progress, clampf((float(sim.clock) - c.opened_at) / 0.35, 0, 1) if c.opened else 0])
	return rows

static func rescue_snapshot(sim: GameSim) -> Variant:
	return [sim.rescue_components.duplicate(), sim.radio_built, sim.radio_build_t / RADIO_BUILD_TIME, sim.radio_parts_placed.duplicate()]

class ExplorationChest:
	var id: int = 0
	var landmark: int = 0
	var component: int = -1
	var pos: Vector2 = Vector2.ZERO
	var opened: bool = false
	var opened_at: float = 0.0
	var unlocker
	var unlock_progress: float = 0.0
	# Day patrol budget only; this never restricts access to the chest.
	var patrol_day: int = 0
	var patrol_spawned: int = 0
	var slots = SimInventory.empty_slots(GameSim.EXPLORATION_CHEST_SLOTS)

	var empty: bool:
		get:
			return slots.all(func(s): return s == null)
