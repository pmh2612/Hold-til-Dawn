extends Node

func _ready() -> void:
	var out = "res://.tmp/river-mouths"
	DirAccess.make_dir_recursive_absolute(out)
	var game = Main.new()
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sim = GameSim.new()
	game.sim.add_player(1, "Engineer", 2)
	game.sim.start_match()
	game.my_id = 1
	var shots: Array = []
	for r in range(IslandMap.rivers.size()):
		var path = IslandMap.rivers[r]
		for end in range(2):
			var closest: float = INF
			var at: Vector2 = Vector2.ZERO
			var start: int = 0 if end == 0 else path.size() / 2
			var stop: int = path.size() / 2 if end == 0 else path.size()
			for i in range(start, stop):
				var d: float = absf(IslandMap.depth(path[i]))
				if d < closest:
					closest = d
					at = path[i]
			shots.append(["river-%d-%s" % [r, "north" if end == 0 else "south"], at])
	shots.append(["bridge", IslandMap.bridges[0][1]])
	for shot in shots:
		var p = game.sim.players[1]
		game.sim.teleport(p, IslandMap.pull_inland(shot[1] + Vector2(140, 0), 14))
		game.local_pos = p.pos
		game.local_tp = p.tp
		game.pending_inputs.clear()
		game.on_snap(game.sim.snapshot())
		for frame in range(20):
			game._process(0.016)
			game.landmark_details.tick_landmark_ground()
			game.cam.position = shot[1]
			game.cam.zoom = Vector2.ONE * 1.4
			game.cam.reset_smoothing()
			game.hud.visible = false
			game.banner.visible = false
			game.queue_redraw()
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
		print("RIVER MOUTH PREVIEW OK: " + shot[0])
	get_tree().quit()
