class_name SimDrops
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/ai/GameSim.Drops.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
const DROP_TTL = 30.0
static var DROPS = [[0.1, ["wood", "stone", "herb"], 1, 2], [0.15, ["bandage"], 1, 1], [0.2, ["titanium"], 2, 2]]

# constants shared with GameSim
const BOSS = GameSim.BOSS
const T = GameSim.T

static func drop(sim: GameSim, e) -> void:
	# summoned Grunts drop nothing (BAL-43)
	if e.get("summon", false):
		return
	if e.type == BOSS:
		add_drop(sim, e.pos, "titanium", 10)
		add_drop(sim, e.pos + Vector2(0.6 * T, 0), "bandage", 3)
		return
	var d = DROPS[e.type]
	if sim.rng.randf() < minf(1.0, d[0] * GameSim.DROP_MUL):
		add_drop(sim, e.pos, d[1][sim.rng.randi() % d[1].size()], sim.rng.randi_range(d[2], d[3]))

static func add_drop(sim: GameSim, pos, item, n) -> void:
	sim.drops.append({"pos": pos, "item": item, "n": n, "ttl": DROP_TTL})

static func tick_drops(sim: GameSim, dt) -> void:
	for d in sim.drops:
		# items dropped by players never vanish and are picked up with E (src/gameplay/sim_inventory.gd)
		if d.get("player", false):
			continue
		d.ttl -= dt
		for p in sim.players.values():
			# MEC-23: walk over it with free inventory space, never from inside the base
			if d.ttl > 0 and p.state == 0 and not SimWorld.inside_base(p.pos) and p.pos.distance_to(d.pos) <= 0.8 * T and SimInventory.room(sim, p, d.item) > 0:
				var left: int = SimInventory.add_to(p.inv, d.item, int(d.n))
				SimPlayers.note(sim, p, "+%d %s" % [d.n - left, SimInventory.item_name(d.item)])
				d.n = left
				if left == 0:
					d.ttl = 0.0
	sim.drops = sim.drops.filter(func(d): return d.get("player", false) or d.ttl > 0)
