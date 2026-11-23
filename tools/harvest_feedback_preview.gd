class_name HarvestFeedbackPreview
extends Main
# Review the actual resource/player renderer through a complete harvest, without world or HUD clutter.
# godot --path . tools/HarvestFeedbackPreview.tscn -- --out=res://.tmp/harvest-clarity/frames
var review_frame: int = 0
var last_stage: int = -1
var lit_frames: int = 0
var finished: bool = false
var out = "res://.tmp/harvest-clarity/frames"
var types = [0, 1, 2]
var names = ["node_wood", "node_stone", "node_herb"]

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	super._ready()
	for child in get_children():
		var item = child
		if child is CanvasItem:
			item.visible = false
		var layer = child
		if child is CanvasLayer:
			layer.visible = false
	cam.enabled = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sim = GameSim.new()
	for i in range(3):
		sim.add_player(i + 1, "Preview", i)
	sim.start_match()
	sim.nodes = []
	for i in range(3):
		var pos = Vector2(160 + i * 320, 230)
		sim.nodes.append({"type": types[i], "pos": pos, "amount": 5, "sprite": names[i] + "_0"})
		var p = sim.players[i + 1]
		p.pos = pos + Vector2(0, 40)
		p.activity = "gather"
		p.activity_target = pos
	my_id = -1
	on_snap(sim.snapshot())
	# catch (Exception E) dropped

func _physics_process(delta: float) -> void:
	pass

func _process(delta: float) -> void:
	if finished:
		return
	clock = review_frame * 0.1
	for n in sim.nodes:
		n["amount"] = maxi(0, 5 - int(float(clock) * 0.35))
	for id in sim.players:
		var p = sim.players[id]
		p.gather_acc = fposmod(float(clock) * 0.35, 1)
		if float(clock) >= 14.3:
			p.activity = "idle"
	on_snap(sim.snapshot())
	queue_redraw()

func _draw() -> void:
	if finished:
		return
	# try (GDScript has no exceptions; the body runs unguarded)
	draw_rect(get_viewport_rect(), Color("30383D"))
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(32, 45), "Harvesting: wood / stone / herbs", 22)
	node_break.prepare_harvest_feedback()
	var i: int = 0
	for n in snap.nodes:
		var pos: Vector2 = Vector2(n[1])
		var amount: int = int(n[2])
		var name = node_break.node_sprite(n, 0)
		if amount > 0:
			var expected = names[i] + ("_0" if amount == 5 else "_dmg%s_0" % [5 - amount])
			if name != expected:
				Cs.fail("Wrong harvested sprite: " + name)
				return
		var tint: Color = node_break.node_modulate(n)
		if tint.r > 1:
			lit_frames += 1
		if node_break.node_offset(n).length() > 2.1 or node_break.node_scale(n) != 1:
			Cs.fail("Resource deformed during impact")
			return
		sprite_2(name, pos + node_break.node_offset(n), 1, tint)
		player_view.draw_player(i + 1, snap.ps[i + 1], pos + Vector2(0, 40))
		draw_string(font, pos + Vector2(-54, 108), "%s / %s of 5" % [Cs.s(GameSim.ROLES[i]), amount], 16)
		i += 1
	node_break.draw_chips()
	node_break.draw_harvest_feedback()
	var stage: int = mini(5, int(float(clock) * 0.35))
	var save: bool = review_frame % 5 == 0 or stage != last_stage
	last_stage = stage
	var _old1 = review_frame
	review_frame += 1
	var at: int = _old1
	var last: bool = review_frame >= 151
	if last:
		finished = true
		set_process(false)
	if save:
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		im.linear_to_srgb()
		im.save_png(out.path_join("frame-%03d.png" % [at]))
	if last:
		if lit_frames < 30:
			Cs.fail("Harvest impacts were not rendered")
			return
		print("HARVEST FEEDBACK ALL OK: six stages, per-swing impacts, fixed footprints and active progress indicators")
		get_tree().quit()
	# catch (Exception E) dropped
