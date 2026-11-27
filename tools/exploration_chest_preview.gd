class_name ExplorationChestPreview
extends Node

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	var out = "res://.tmp/expedition-chests"
	DirAccess.make_dir_recursive_absolute(out)
	var game = Main.new()
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sim = GameSim.new()
	game.sim.add_player(1, "Scout", 0)
	game.sim.add_player(2, "Engineer", 2)
	game.sim.start_match()
	game.my_id = 1
	var p = game.sim.players[1]
	var chest = game.sim.exploration_chests.filter(func(c): return c.landmark > 4)[0]
	var camera = game.cam
	var names = ["sealed", "unlocking", "opened", "storage", "radio-table", "radio-missing", "radio-parts", "radio-ready", "radio-build", "radio-online", "craft-weapons", "craft-equipment", "craft-locked", "map"]
	var stage: int = 0
	while stage < names.size():
		var name_: String = names[stage]
		var crafting: bool = name_.begins_with("craft-")
		var at: Vector2 = chest.pos if stage < 4 else GameSim.WORKBENCH_POS if crafting else GameSim.RADIO_POS
		game.sim.teleport(p, at + Vector2(0, 32) if stage < 4 else at + Vector2(0, 24))
		if stage == 0:
			game.sim.set_count(p, "chest_key", 2)
		if stage == 1:
			p.inter = true
			game.sim.interact(p, 1.0)
		if stage == 2:
			p.inter = true
			game.sim.interact(p, 1.1)
		game.inventory.bag_open = stage == 3
		game.exploration_chests.bag_exploration_chest = chest.id if stage == 3 else -1
		game.local_pos = p.pos
		game.pending_inputs.clear()
		var radio_panel: bool = name_ in ["radio-missing", "radio-parts", "radio-ready", "radio-build", "radio-online"]
		if name_ == "radio-parts":
			game.sim.rescue_components = [1, 1, 0]
		if name_ == "radio-ready":
			game.sim.rescue_components = [1, 1, 1]
		if radio_panel:
			game.sim.action(p.id, "radio_open", null)
		if name_ == "radio-build":
			game.sim.action(p.id, "radio_repair", null)
			game.sim.try_build_radio(p, 2.5)
		if name_ == "radio-online":
			game.sim.try_build_radio(p, 2.6)
			assert(game.sim.radio_built)
		if crafting:
			p.inter = false
			game.sim.unlock = 0 if name_ == "craft-locked" else 2
			for res in GameSim.RES:
				game.sim.set_count(p, res, 20)
			game.craft_panel.select_craft_category(0 if name_ != "craft-equipment" else 1)
			game.craft_panel.craft_sel = 16 if name_ == "craft-weapons" else 9 if name_ == "craft-equipment" else 6
		game.craft_panel.radio_mode = radio_panel
		game.craft_open = crafting or radio_panel
		game.local_pos = p.pos
		game.minimap.map_big = name_ == "map"
		game.sim.clock += 0.5
		game.on_snap(game.sim.snapshot())
		if stage == 2 and (not chest.opened or not game.inventory.bag_open or game.exploration_chests.bag_exploration_chest != chest.id):
			Cs.fail("Unlocking must automatically open the correct storage panel")
			return
		game.inventory.bag_open = stage == 3
		game.exploration_chests.bag_exploration_chest = chest.id if stage == 3 else -1
		if stage == 3 and game.inventory.bag_slots(Vector2(960, 540), game.sim.snapshot().get("ps").get(1)).size() != 16:
			Cs.fail("Chest UI must have eight bag and eight chest slots")
			return
		game.local_tp = p.tp
		game.pending_inputs.clear()
		for frame in range(20):
			game._process(0.016)
			game.landmark_details.tick_landmark_ground()
			camera.position = at
			camera.zoom = Vector2.ONE * (2 if stage < 4 else 2.5)
			camera.reset_smoothing()
			game.hud.visible = true
			game.banner.visible = false
			game.queue_redraw()
			game.hud.queue_redraw()
			await RenderingServer.frame_post_draw
		var shot = get_viewport().get_texture().get_image()
		shot.save_png("%s/%s.png" % [out, names[stage]])
		print("CHEST PREVIEW OK: " + names[stage])
		stage += 1
	get_tree().quit()
	# catch (Exception E) dropped
