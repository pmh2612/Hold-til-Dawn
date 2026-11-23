extends Node

func _ready() -> void:
	var out = "res://.tmp/gameplay-refine"
	DirAccess.make_dir_recursive_absolute(out)
	var game = Main.new()
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_local()
	game.sim.players[1].role = 2
	game.sim.start_match()
	var s = game.sim
	var p = s.players[1]
	var field: Vector2 = s.free_tower_spot(0)
	var chest = s.exploration_chests[0]
	var node = s.nodes.filter(func(n): return n.type == 1 and n.amount > 0)[0]
	var near_enemy = s.spawn(GameSim.GRUNT, 0, 0.0)
	near_enemy.pos = field + Vector2(2.5, 0) * GameSim.T
	var far_enemy = s.spawn(GameSim.SPITTER, 0, 0.0)
	far_enemy.pos = field + Vector2(7.0, 0) * GameSim.T
	for stage in ["idle", "placement", "repair", "unlocking", "opened", "gathering", "night-engineer", "help", "map"]:
		s.phase = "day"
		p.activity = "idle"
		p.atk = false
		p.inter = false
		p.gather_acc = 0.0
		p.revive_p = 0.0
		game.gameplay_hud.help_open = false
		game.build_menu.close_build()
		game.minimap.map_big = stage == "map"
		var at = chest.pos if stage in ["unlocking", "opened"] else node.pos if stage == "gathering" else field
		s.teleport(p, at + Vector2(0, 34))
		if stage == "repair":
			s.place_tower(0, field)
			s.towers[0].hp = 180.0
			s.set_count(p, "wood", 10)
			p.inter = true
			s.interact(p, 0.1)
		if stage == "unlocking":
			s.set_count(p, "chest_key", 1)
			p.inter = true
			s.interact(p, 1.0)
		if stage == "opened":
			p.inter = true
			s.interact(p, 1.1)
		if stage == "gathering":
			p.activity = "gather"
			p.activity_target = node.pos
			p.gather_acc = 0.55
		if stage == "night-engineer":
			s.phase = "night"
			s.t = 200.0
			s.towers = [null, null, null]
		game.local_pos = p.pos
		game.local_tp = p.tp
		game.pending_inputs.clear()
		game.on_snap(s.snapshot())
		game.local_pos = p.pos
		game.inventory.bag_open = false
		if stage == "placement":
			game.gameplay_hud.gameplay_key(KEY_T)
		if stage == "help":
			game.gameplay_hud.gameplay_key(KEY_H)
		for i in range(12):
			game._process(0.016)
			game.cam.position = at
			game.cam.zoom = Vector2.ONE * 2
			game.cam.reset_smoothing()
			game.queue_redraw()
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, stage])
		print("GAMEPLAY PREVIEW OK: " + stage)
	game.queue_free()
	get_tree().quit()
