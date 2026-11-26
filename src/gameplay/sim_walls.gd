class_name SimWalls
extends RefCounted

# Part of GameSim (game_sim.gd); in the C# version this was src/gameplay/GameSim.Walls.cs.
# Rules only: the match state lives on GameSim, passed in as `sim`.
const MAX_WALLS: int = 30

# constants shared with GameSim
const BUILD_REACH = GameSim.BUILD_REACH
const T = GameSim.T
const WALL_DOOR_GAP = GameSim.WALL_DOOR_GAP
const WRECKER = GameSim.WRECKER

# Why a structure cannot go there, or "" when it can (shared by the server and the client preview).
static func wall_spot_problem(pos, vert: bool, world_, walls_) -> Variant:
	for piece in WorldGeometry.wall_pieces(pos, vert):
		if SimWorld.inside_base(piece, 0.6 * T):
			return "Walls go outside the base"
		for i in 3:
			if piece.distance_to(GameSim.DOOR_POS[i]) < WALL_DOOR_GAP * T:
				return "Keep 3 tiles from door"
		if not IslandMap.on_grass(Vector2(piece), T):
			return "Too close to the shore"
		if world_.resolve(piece, 0.5 * T) != piece:
			return "Something is in the way"
	return ""

static func snap_to_tile(pos: Vector2) -> Vector2:
	return (pos / T).round() * T

# Action "build": [kind, position, vertical]; kind is "wood", "stone" or "tower".
static func build(sim: GameSim, p, arg) -> void:
	if not arg is Array or arg.size() < 3 or not arg[1] is Vector2:
		return
	var kind = Cs.s(arg[0])
	var pos: Vector2 = Vector2(arg[1])
	if kind == "tower":
		SimTowers.build_tower(sim, p, pos)
		return
	SimPlayers.note(sim, p, "T: tower")

static func player_on_wall(sim: GameSim, pos: Vector2, vert: bool) -> bool:
	for piece in WorldGeometry.wall_pieces(pos, vert):
		for q in sim.players.values():
			if q.pos.distance_to(piece) < 0.9 * T:
				return true
	return false

# The wall an enemy is pressed against, if any.
static func wall_touching(sim: GameSim, pos, r) -> Variant:
	for w in sim.built_walls:
		for piece in WorldGeometry.wall_pieces(w.pos, w.vert):
			if pos.distance_to(piece) <= r + WorldGeometry.WALL_PIECE * T + 4.0:
				return w
	return null

static func damage_wall(sim: GameSim, e, w, dmg) -> void:
	w.hp -= dmg * (2.0 if e.type == WRECKER else 1.0)
	if w.hp <= 0:
		sim.built_walls = sim.built_walls.filter(func(x): return x.id != w.id)
		SimPlayers.say(sim, "A %s was destroyed" % [GameSim.WALL_KINDS[w.kind][0].to_lower()])
