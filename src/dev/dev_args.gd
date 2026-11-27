class_name DevArgs
extends RefCounted

# Part of Main (main.gd); in the C# version this was in Main.cs.
# Owner: Mai Thien Ngon.

# constants shared with Main
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

# Screenshot and playtest helpers: --kit (some materials and a bow), --arsenal (every weapon), --walls, --towers, --goto=x,y (tiles) or --goto=wood|stone|herb|titanium|sup:N, --gathered=0..5, --panel=bag|craft|build|pause|map,
# --boss=0..6 (night 2 with that boss 9 tiles in front of door A, you beside it).
func dev_args(args) -> void:
	for a_ in args:
		var me = main.sim.players.get(1)
		if me == null or main.sim.phase == "lobby":
			return
		if a_ == "--kit":
			main.sim.set_count(me, "wood", 30)
			main.sim.set_count(me, "stone", 12)
			main.sim.set_count(me, "titanium", 8)
			main.sim.set_count(me, "bow", 1)
			main.sim.set_count(me, "arrow", 10)
			main.sim.set_count(me, "bandage", 2)
			main.sim.unlock = 2
		elif a_ == "--arsenal":
			# every weapon in the hotbar (keys 1-4: spear, blade, hammer, bow) to look at each attack; for fists,
			# drag one of them into the bag (Tab) and select the empty slot
			me.inv = SimInventory.empty_slots(GameSim.INV_SLOTS)
			me.inv[0] = ["stone_spear", 1]
			me.inv[1] = ["titanium_blade", 1]
			me.inv[2] = ["hammer", 1]
			me.inv[3] = ["bow", 1]
			main.sim.set_count(me, "arrow", 99)
			me.sel = 0
		elif a_ == "--walls":
			# a wood and a stone wall beside door A, to look at
			var d: Vector2 = Vector2(GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 5 * T)
			main.sim.built_walls.append({"id": 9001, "kind": "wood", "pos": SimWalls.snap_to_tile(d + Vector2(0, -3 * T)), "vert": true, "hp": 200.0, "maxhp": 200.0})
			main.sim.built_walls.append({"id": 9002, "kind": "stone", "pos": SimWalls.snap_to_tile(d + Vector2(-2 * T, 4 * T)), "vert": false, "hp": 300.0, "maxhp": 400.0})
			main.sim.teleport(me, d + Vector2(2 * T, 0))
		elif a_ == "--towers":
			# a tower beside each landing pad (the third one badly damaged), you beside the first
			main.sim.free_tower = false
			for i in range(GameSim.MAX_TOWERS):
				main.sim.place_tower(i, main.sim.free_tower_spot(i))
			main.sim.towers[2].hp = 60.0
			main.sim.world.rebuild(main.sim.nodes, main.sim.towers, main.sim.built_walls)
			main.sim.teleport(me, main.sim.towers[0].pos + Vector2(-2 * T, -1.0 * T))
		elif a_.begins_with("--gathered="):
			# every node left with N units (0..5), to look at the broken stages
			for nd in main.sim.nodes:
				nd.amount = a_.substr(11).to_int()
		elif a_.substr(7) in GameSim.RES and a_.begins_with("--goto="):
			# --goto=wood|stone|herb|titanium: next to the nearest node of that kind (titanium is all in the outer zone)
			var kind: int = GameSim.RES.find(a_.substr(7))
			var best: Vector2 = Vector2.ZERO
			for nd in main.sim.nodes:
				if int(nd.type) == kind and (best == Vector2.ZERO or Vector2(nd.pos).length() < best.length()):
					best = Vector2(nd.pos)
			main.sim.teleport(me, best + Vector2(0, 1.5 * T))
		elif a_.begins_with("--goto=sup:"):
			# --goto=sup:N: two tiles south of exploration chest N
			var n: int = a_.substr(11).to_int()
			if n >= 0 and n < main.sim.exploration_chests.size():
				main.sim.teleport(me, IslandMap.pull_inland(main.sim.exploration_chests[n].pos + Vector2(0, 2.0 * T), T))
		elif a_.begins_with("--goto=lm:"):
			# --goto=lm:N: in front of landmark N's structure (src/world/world_landmarks.gd)
			var id: int = a_.substr(10).to_int()
			var _v1 = (IslandMap.by_id(id).pos if IslandMap.by_id(id) != null else null)
			var at: Vector2 = _v1 if _v1 != null else Vector2.ZERO
			var wg = main.geometry
			var _c2 = main.geometry is WorldGeometry
			var built
			if _c2:
				built = wg.lm_at.get(id, Vector2.ZERO)
				_c2 = wg.lm_at.has(id)
			if _c2:
				at = built
			main.sim.teleport(me, IslandMap.pull_inland(at + Vector2(0, 2.5 * T), T))
		elif a_.begins_with("--goto="):
			# --goto=x,y in tiles from the base centre, to look at a part of the island
			var xy = a_.substr(7).split(",")
			main.sim.teleport(me, Vector2(xy[0].to_float(), xy[1].to_float()) * T)
		elif a_.begins_with("--night="):
			# A playable night with the normal spawn director (unlike the lighting-only --night).
			var number: int = clampi(a_.substr(8).to_int(), 1, 5)
			main.sim.k = number
			main.sim.unlock = 2 if number >= 3 else 1 if number >= 2 else 0
			main.sim.enemies.clear()
			main.sim.proj.clear()
			main.sim.tele.clear()
			if number == 5:
				main.sim.rescue_components = [1, 1, 1]
				main.sim.radio_parts_placed = [1, 1, 1]
				main.sim.radio_built = true
			main.sim.dawn()
			main.sim.night()
		elif a_ == "--rescue-preview":
			# Final-night extension: pad A is already clear for 5 of the required 10 seconds.
			main.sim.k = 5
			main.sim.rescue_components = [1, 1, 1]
			main.sim.radio_parts_placed = [1, 1, 1]
			main.sim.radio_built = true
			main.sim.enemies.clear()
			main.sim.proj.clear()
			main.sim.tele.clear()
			main.sim.dawn()
			main.sim.night()
			main.sim.t = 0.0
			main.sim.ext = 60.0
			main.sim.pad_clear = [5.0, 0.0, 0.0]
			main.sim.next_wave = INF
			# Stationary blockers keep the other pads from progressing during this five-second review.
			for i in [1, 2]:
				var guard = main.sim.spawn(GameSim.GRUNT, i, 10)
				guard.pos = SimWorld.pad_pos(i)
				guard.stun_until = INF
			main.sim.teleport(me, SimWorld.pad_pos(0) + Vector2(-T, T))
			main.zoom_i = 0
		elif a_ == "--win":
			# Open the real post-rescue result screen without playing five nights.
			main.sim.k = 5
			SimPhases.end(main.sim, true, "Helicopter landed at pad A")
		elif a_ == "--night":
			# straight to night 1 with no waves, to look at the night colours; an Engineer standing in the base
			# (--goto before it) stays inside
			var keep: Vector2 = Vector2(me.pos)
			main.sim.night()
			main.sim.next_wave = INF
			if me.role == 2 and SimWorld.inside_base(keep):
				me.inside = true
				main.sim.teleport(me, keep)
		elif a_.begins_with("--zoom="):
			# --zoom=0..2: the camera zoom step (0 is the widest), as the mouse wheel sets it
			main.zoom_i = clampi(a_.substr(7).to_int(), 0, Main.ZOOMS.size() - 1)
		elif a_.begins_with("--panel="):
			var p = a_.substr(8)
			main.inventory.bag_open = p == "bag"
			main.craft_open = p == "craft"
			main.pause_menu.paused = p == "pause"
			main.minimap.map_big = p == "map"
			if p == "build":
				main.build_menu.build_open = true
				main.build_menu.build_kind = "wood"
		elif a_.begins_with("--boss="):
			main.sim.boss_plan = [a_.substr(7).to_int(), 0]
			main.sim.k = 2
			main.sim.night()
			main.sim.active = [0]
			main.sim.next_wave = INF
			main.sim.boss_spawned = true
			main.sim.spawn_boss()
			var b = main.sim.boss()
			b.pos = GameSim.DOOR_POS[0] + GameSim.DOOR_DIR[0] * 9 * T
			main.sim.teleport(me, b.pos + Vector2(2.5 * T, 0.5 * T))
