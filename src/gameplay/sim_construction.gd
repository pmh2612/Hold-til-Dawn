class_name SimConstruction
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/gameplay/GameSim.Construction.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
const TOWER_BUILD_TIME: float = 6.0

# constants shared with GameSim
const T = GameSim.T

static func cancel_all_construction(sim: GameSim) -> void:
	sim.construction.clear()
	for p in sim.players.values():
		p["tower_build_t"] = 0.0

static func construction_slot_taken(sim: GameSim, slot: int) -> bool:
	for job in sim.construction:
		if int(job.get("slot")) == slot:
			return true
	return false

static func reserve_tower(sim: GameSim, p, slot: int, at: Vector2) -> bool:
	for job in sim.construction:
		if int(job.get("slot")) == slot or int(job.get("owner")) == int(p.id) or Vector2(job.get("pos")).distance_to(at) < 2 * T:
			return false
	sim.construction.append({"slot": slot, "owner": p.id, "pos": at, "origin": p.pos, "taken": p.taken, "left": TOWER_BUILD_TIME})
	# Discard attack input sampled before the placement action reached the simulation.
	p.atk = false
	p.tower_build_t = TOWER_BUILD_TIME
	SimPlayers.note(sim, p, "Preparing dirt foundation and tower: 6 seconds. Stand still.")
	return true

static func tick_tower_construction(sim: GameSim, p, dt: float) -> bool:
	for i in range(sim.construction.size() - 1, -1, -1):
		var job = sim.construction[i]
		if int(job.get("owner")) != int(p.id):
			continue
		var at: Vector2 = Vector2(job.get("pos"))
		if p.state != 0 or p.role != 2 or SimInventory.count(sim, p, "hammer") <= 0 or p.inside or p.craft_idx >= 0 or p.atk or p.taken > job.get("taken") or Vector2(p.pos).distance_to(Vector2(job.get("origin"))) > 4:
			sim.construction.remove_at(i)
			p.tower_build_t = 0.0
			SimPlayers.note(sim, p, "Construction interrupted; materials kept")
			return false
		p.activity = "repair"
		p.activity_target = at
		var left: float = maxf(0, float(job.get("left")) - dt)
		job["left"] = left
		p.tower_build_t = left
		if left > 0:
			return true
		sim.construction.remove_at(i)
		# People may have walked across the foundation, or a wall may have been placed during the channel.
		var why = SimTowers.tower_spot_problem(at, sim.world)
		for q in sim.players.values():
			if q.id != p.id and Vector2(q.pos).distance_to(at) < 1.1 * T:
				why = "Someone is standing there"
		if sim.towers[job.get("slot")] != null:
			why = "Tower slot is occupied"
		if not sim.free_tower:
			if sim.unlock < 2:
				why = "Unlocks after the first boss"
			for id in GameSim.TOWER_COST:
				if SimInventory.count(sim, p, id) < GameSim.TOWER_COST[id]:
					why = "Need tower materials"
		if why != "":
			SimPlayers.note(sim, p, why + "; materials kept")
			return true
		if sim.free_tower:
			sim.free_tower = false
		else:
			for id in GameSim.TOWER_COST:
				SimInventory.take(sim, p, id, GameSim.TOWER_COST[id])
		SimTowers.place_tower(sim, job.get("slot"), at)
		sim.world.rebuild(sim.nodes, sim.towers, sim.built_walls)
		SimPlayers.note(sim, p, "Tower ready on dirt foundation")
		return true
	p.tower_build_t = 0.0
	return false

static func construction_snapshot(sim: GameSim) -> Variant:
	var result_ = []
	for job in sim.construction:
		result_.append([job.get("pos"), 1.0 - float(job.get("left")) / TOWER_BUILD_TIME, job.get("owner")])
	return result_
