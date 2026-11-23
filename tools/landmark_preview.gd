class_name LandmarkPreview
extends Node
# Atlas review tool: actual game renderer, all 18 landmarks, no HUD. Not part of the shipping scene.
# godot --path . tools/LandmarkPreview.tscn -- --out=.tmp/landmark-review [--landmark=9] [--night]

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	await capture()
	# catch (Exception Error) dropped

func capture() -> void:
	var out = "res://.tmp/landmark-review"
	var only: int = 0
	var night: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = ProjectSettings.globalize_path(arg.substr(6))
		if arg.begins_with("--landmark="):
			only = arg.substr(11).to_int()
		if arg == "--night":
			night = true
	DirAccess.make_dir_recursive_absolute(out)
	var game = Main.new()
	add_child(game)
	game.start_local()
	game.sim.action(1, "start", 0)
	game.sim.next_wave = INF
	game.sim.set_count(game.sim.players[1], "titanium_armour", 1)
	game.set_physics_process(false)
	var w = game.geometry
	# Catch silent placement rejection of the large new silhouettes during every visual review.
	for hero in ["lm_radar_0", "lm_crane_0", "lm_arch_0", "lm_scope_0"]:
		if not w.lm_props.any(func(p): return p[1] == hero):
			Cs.fail("Landmark prop was not placed: %s" % [hero])
			return
	for _it1 in w.lm_props + w.lm_ground:
		var p = _it1[0]
		var sprite = _it1[1]
		if not FileAccess.file_exists("res://art/landmarks/%s.png" % [sprite]) and not FileAccess.file_exists("res://art/nature/%s.png" % [sprite]):
			Cs.fail("Missing landmark sprite: %s" % [sprite])
			return
	for landmark in IslandMap.landmarks:
		var id: int = landmark.id
		if only != 0 and only != id:
			continue
		var _t2
		var at
		if id == 1:
			_t2 = Vector2.ZERO
		else:
			at = w.lm_at.get(id, Vector2.ZERO)
			_t2 = at if w.lm_at.has(id) else landmark.pos
		var centre: Vector2 = _t2
		if id == 8:
			centre = w.swamp_centre
		if id == 15 and w.ponds.size() > 0:
			centre = w.ponds[0].centre
		# Tall props need room above their foot. The wreck and outpost need a wider framing.
		centre += Vector2(0, -32 if id == 6 or id == 9 or id == 13 or id == 14 or id == 16 else -12)
		game.sim.teleport(game.sim.players[1], IslandMap.pull_inland(centre + Vector2(0, 100), 12))
		game.sim.phase = "night" if night else "day"
		game.sim.active = []
		game.on_snap(game.sim.snapshot())
		game.local_pos = game.sim.players[1].pos
		game._process(0.016)
		game.set_process(false)
		game.hud.visible = false
		game.banner.visible = false
		var camera = game.cam
		camera.position = centre
		camera.zoom = Vector2.ONE * (1.0 if id == 1 or id == 8 or id == 14 else 1.5)
		camera.reset_smoothing()
		game.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		# Normal gameplay advances these jobs in _Process; this tool freezes the game for screenshots.
		while game.landmark_details.has_pending_landmark_ground:
			game.landmark_details.tick_landmark_ground()
			game.queue_redraw()
			await RenderingServer.frame_post_draw
		var img = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
		var path = out.path_join("%s-%02d.png" % ["night" if night else "after", id])
		var result = img.save_png(path)
		if result != OK:
			Cs.fail("Cannot save %s: %s" % [path, Cs.s(result)])
			return
		print("LANDMARK %02d: %s -> %s" % [id, landmark.name, path])
		# Let the engine flush the rendering resources before the next teleport.
		await get_tree().process_frame
	get_tree().quit()
