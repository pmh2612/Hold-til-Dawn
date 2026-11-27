class_name SurvivalPreview
extends Node
# Capture the actual renderer and HUD for the exploration / rescue update.

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	DirAccess.make_dir_recursive_absolute("res://.tmp/survival-preview")
	var game = Main.new()
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sim = GameSim.new()
	game.sim.add_player(1, "Engineer", 2)
	game.sim.start_match()
	game.my_id = 1
	var p = game.sim.players[1]
	var w = game.geometry
	for stage in range(6):
		var at: Vector2 = IslandMap.bridges[0][1] if stage == 0 else w.swamp_centre if stage == 1 else w.lm_at[9] if stage == 2 else GameSim.WORKBENCH_POS
		game.sim.teleport(p, at + Vector2(0, 24 if stage >= 3 else 65))
		p.hp = p.maxhp * 0.2 if stage == 4 else p.maxhp
		if stage == 5:
			p.pos = game.sim.free_tower_spot(0) + Vector2(0, 40)
			at = game.sim.free_tower_spot(0)
			game.sim.build_tower(p, at)
			game.sim.tick_tower_construction(p, 3)
		game.local_pos = p.pos
		game.craft_open = stage == 3
		game.craft_panel.select_craft_category(0)
		game.craft_panel.craft_sel = 1
		game.on_snap(game.sim.snapshot())
		game.local_tp = p.tp
		game.pending_inputs.clear()
		var camera = game.cam
		for frame in range(20):
			game._process(0.016)
			game.landmark_details.tick_landmark_ground()
			camera.position = at - Vector2(0, 30 if stage == 2 else 0)
			camera.zoom = Vector2.ONE * (1.25 if stage == 1 or stage == 2 else 1.5)
			camera.reset_smoothing()
			game.hud.visible = stage >= 3
			game.banner.visible = false
			game.queue_redraw()
			game.hud.queue_redraw()
			await RenderingServer.frame_post_draw
		var shot = get_viewport().get_texture().get_image()
		shot.save_png("res://.tmp/survival-preview/%s.png" % [stage])
		print("SURVIVAL PREVIEW %s OK" % [stage])
	print("SURVIVAL RENDER ALL OK")
	get_tree().quit()
	# catch (Exception Error) dropped
