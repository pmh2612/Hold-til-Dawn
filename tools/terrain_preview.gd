class_name TerrainPreview
extends Node
# Review the real game renderer after changes to geography or landmark surfaces.

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	var out = "res://.tmp/terrain-review"
	DirAccess.make_dir_recursive_absolute(out)
	var game = Main.new()
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sim = GameSim.new()
	game.sim.add_player(1, "Engineer", 2)
	game.sim.start_match()
	game.my_id = 1
	if game.sim.phase != "day":
		Cs.fail("Preview failed to start a match")
		return
	var player = game.sim.players[1]
	var world = game.geometry
	var camera = game.cam
	var cave_review: bool = OS.get_cmdline_user_args().find("--cave-review") >= 0
	var garden_review: bool = OS.get_cmdline_user_args().find("--garden-review") >= 0
	var station_review: bool = OS.get_cmdline_user_args().find("--station-review") >= 0
	var farm_review: bool = OS.get_cmdline_user_args().find("--farm-review") >= 0
	var expedition_review: bool = OS.get_cmdline_user_args().find("--expedition-review") >= 0
	var compound_review: bool = OS.get_cmdline_user_args().find("--compound-review") >= 0
	var lookout_review: bool = OS.get_cmdline_user_args().find("--lookout-review") >= 0
	var focus: bool = cave_review or garden_review or station_review or farm_review or expedition_review or compound_review or lookout_review
	if focus:
		game.sim.exploration_chests.clear()  # Keep random chests out of focused landmark art review.
	var night: bool = OS.get_cmdline_user_args().find("--night") >= 0
	game.sim.phase = "night" if night else "day"
	for stage in range(32 if focus else 23):
		if focus and not (cave_review and (stage == 14 or stage == 18 or stage == 22 or stage == 23 or stage == 24 or stage == 26) or garden_review and (stage == 16 or stage == 22 or stage == 25) or station_review and (stage == 7 or stage == 8 or stage == 27 or stage == 28 or stage == 29 or stage == 30 or stage == 31) or farm_review and (stage == 0 or stage == 1 or stage == 2 or stage == 16 or stage == 17 or stage == 18 or stage == 19 or stage == 20 or stage == 21 or stage == 22) or expedition_review and (stage == 3 or stage == 5 or stage == 9 or stage == 22) or compound_review and (stage == 4 or stage == 11 or stage == 22) or lookout_review and (stage == 10 or stage == 15 or stage == 22)):
			continue
		var id: int = 10 if stage >= 30 else 9 if stage >= 27 else stage + 2 if stage < 17 else 18 if stage == 25 else 16 if stage >= 23 else 0
		var at: Vector2 = world.lm_at[id] if id > 0 else IslandMap.bridges[stage - 17][1] if stage < 22 else Vector2.ZERO
		if id == 8:
			at = world.swamp_centre
		if id == 15:
			at = world.ponds[0].centre
		var player_at: Vector2 = world.cave_entrance + Vector2(24, 0) if id == 16 else at + Vector2(0, 120)
		if stage == 24:
			player_at = world.cave_centre - Vector2(3 * 32, 0)
		if id == 18:
			player_at = world.garden_centre
		if stage == 25:
			player_at = world.garden_entrance + Vector2(0, 32)
		if id == 9:
			player_at = world.weather_centre if stage == 28 else world.weather_entrance + Vector2(0, 50)
		if id == 10:
			player_at = world.lm_at[10] - Vector2(90, 0)
		if id == 2 or id == 3 or id == 4:
			player_at = at
		if id == 6 or id == 13:
			player_at = at + Vector2(0, 32)
		if id == 12 or id == 17:
			player_at = at
		game.sim.teleport(player, IslandMap.pull_inland(player_at, 12))
		game.local_pos = player.pos
		game.on_snap(game.sim.snapshot())
		game.local_tp = player.tp
		game.pending_inputs.clear()
		game.minimap.map_big = stage == 22
		var frame: int = 0
		while frame < (36 if focus else 12) or game.landmark_details.has_pending_landmark_ground:
			game._process(0.016)
			game.landmark_details.tick_landmark_ground()
			camera.position = world.cave_centre if id == 16 else at
			if id == 18:
				camera.position -= Vector2(0, 24)
			if id == 2 or id == 3 or id == 4:
				camera.position -= Vector2(0, 22)
				camera.zoom = Vector2.ONE * 1.2
				camera.reset_smoothing()
			camera.zoom = Vector2.ONE * (0.9 if id == 16 else 1.0 if id == 18 else 1.25 if id == 6 or id == 13 else 1.5)
			camera.reset_smoothing()
			if stage == 23 or stage == 26:
				camera.position = world.cave_entrance - Vector2(2 * 32, 0)
				camera.zoom = Vector2.ONE * 1.5
				camera.reset_smoothing()
			if stage == 25:
				camera.position = world.garden_entrance - Vector2(0, 55)
				camera.zoom = Vector2.ONE * 1.5
				camera.reset_smoothing()
			if id == 9:
				camera.position = world.weather_centre - Vector2(0, 8)
				camera.zoom = Vector2.ONE * 1.3
				camera.reset_smoothing()
			if id == 10:
				camera.position = world.lm_at[10] - Vector2(60, 15)
				camera.zoom = Vector2.ONE * 1.65
				camera.reset_smoothing()
			if expedition_review and (id == 5 or id == 7 or id == 11):
				camera.position = world.lm_at[id] - Vector2(0, 18)
				camera.zoom = Vector2.ONE * (1.35 if id == 7 else 0.95 if id == 11 else 1.3)
				camera.reset_smoothing()
			if compound_review and (id == 6 or id == 13):
				camera.position = at - Vector2(0, 30)
				camera.zoom = Vector2.ONE * (1.1 if id == 13 else 1.45)
				camera.reset_smoothing()
			if lookout_review and (id == 12 or id == 17):
				camera.position = at + Vector2(35 if id == 12 else 0, -90 if id == 12 else 35)
				camera.zoom = Vector2.ONE * (1.0 if id == 12 else 1.1)
				camera.reset_smoothing()
			if stage >= 30:
				game.clock = 5.8 if stage == 30 else 6.65  # Repeatable airborne fish / landing splash captures.
			game.hud.visible = stage == 22
			game.banner.visible = false
			game.queue_redraw()
			game.hud.queue_redraw()
			await RenderingServer.frame_post_draw
			frame += 1
		var shot = get_viewport().get_texture().get_image()
		if stage == 24 and game.cave_view.cave_roof_opacity > 0.01:
			Cs.fail("The cave roof did not reveal its interior")
			return
		if stage == 24:
			if not game.cave_view.cave_interior_active or not game.cave_view.hidden_outside_cave(world.cave_entrance + Vector2(80, 0)) or game.cave_view.hidden_outside_cave(Vector2(player.pos)):
				Cs.fail("Cave isolation hides the wrong objects")
				return
			for p in [Vector2i(5, 5), Vector2(shot.get_width() - 6, 5), Vector2(5, shot.get_height() - 6), Vector2(shot.get_width() - 6, shot.get_height() - 6)]:
				var pixel: Color = shot.get_pixelv(p)
				if pixel.r > 0.1 or pixel.g > 0.1 or pixel.b > 0.1:
					Cs.fail("Exterior scenery remains visible from inside the cave")
					return
		if stage == 26 and (game.cave_view.cave_interior_active or game.cave_view.cave_roof_opacity < 0.99):
			Cs.fail("The exterior did not reappear after exiting the cave")
			return
		if stage == 28:
			if not game.weather_station.weather_interior_active or game.weather_station.weather_roof_opacity > 0.01 or not game.weather_station.hidden_outside_interior(world.weather_entrance + Vector2(0, 80)) or game.weather_station.hidden_outside_interior(world.weather_centre):
				Cs.fail("Weather hut cutaway hides the wrong scene")
				return
			for x in range(shot.get_width()):
				_ready_check_outside(Vector2i(x, 5), shot)
				_ready_check_outside(Vector2i(x, shot.get_height() - 6), shot)
			for y in range(shot.get_height()):
				_ready_check_outside(Vector2i(5, y), shot)
				_ready_check_outside(Vector2i(shot.get_width() - 6, y), shot)
		if stage == 29 and (game.weather_station.weather_interior_active or game.weather_station.weather_roof_opacity < 0.99):
			Cs.fail("Weather hut exterior did not return on exit")
			return
		var name = "weather-entry" if stage == 27 else "weather-interior" if stage == 28 else "weather-exit" if stage == 29 else "fishing-jump-%s" % [stage - 29] if stage >= 30 else "cave-entry" if stage == 23 else "cave-interior" if stage == 24 else "garden-entry" if stage == 25 else "cave-exit" if stage == 26 else "landmark-%02d" % [id] if id > 0 else "bridge-%s" % [stage - 17] if stage < 22 else "map"
		if night:
			name += "-night"
		shot.save_png("%s/%s.png" % [out, name])
		print("TERRAIN PREVIEW %s: %s" % [name, Cs.s(at / 32)])
	print("TERRAIN PREVIEW ALL OK")
	get_tree().quit()
	# catch (Exception Error) dropped

# local function CheckOutside of the method above
func _ready_check_outside(p: Vector2i, shot) -> void:
	var pixel: Color = shot.get_pixelv(p)
	if pixel.r > 0.1 or pixel.g > 0.1 or pixel.b > 0.1:
		Cs.fail("Exterior scenery is visible from inside the weather hut at %s" % [Cs.s(p)])
		return
