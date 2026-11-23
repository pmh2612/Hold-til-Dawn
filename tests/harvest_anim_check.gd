class_name HarvestAnimCheck
extends Main
# Exercises the actual player renderer with resource snapshots, all roles and all eight facings.
var pass_: int = 0
var expected = ["gather_wood", "gather_stone", "gather_herb", "gather_stone"]
var shot = ""

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	super._ready()
	start_local()
	sim.action(1, "start", 0)
	sim.nodes = []
	for type in range(4):
		sim.nodes.append({"type": type, "pos": Vector2(900 + type * 100, 900), "amount": 5})
	on_snap(sim.snapshot())
	for type in range(4):
		if harvest_view.gather_animation(Vector2(900 + type * 100, 900)) != expected[type]:
			Cs.fail("Wrong resource animation")
			return
	# A new world at the same node count must replace the cached resource classification too.
	sim.nodes[0]["type"] = 2
	on_snap(sim.snapshot())
	if harvest_view.gather_animation(Vector2(900, 900)) != "gather_herb":
		Cs.fail("Stale resource animation cache")
		return
	sim.nodes[0]["type"] = 0
	on_snap(sim.snapshot())
	for skin in ["scout", "healer", "engineer"]:
		var info = cinfo.chars[skin]
		var im = load("res://art/chars/%s.png" % [skin]).get_image()
		var size: int = int(info.size)
		for name in Cs.distinct(expected):
			var anim = info.anims[name]
			var first: int = int(anim[0])
			var count: int = int(anim[1])
			if first < 30 or (first + count) * size > im.get_width() or im.get_height() != 8 * size:
				Cs.fail("Invalid sheet bounds")
				return
			for dir in range(8):
				var hashes = {}
				var frame: int = 0
				while frame < count:
					var cell = im.get_region(Rect2i((first + frame) * size, dir * size, size, size))
					if cell.is_invisible():
						Cs.fail("Empty harvesting frame")
						return
					Cs.set_add(hashes, cell.get_data().hex_encode().sha256_text())
					frame += 1
				if hashes.size() < 4:
					Cs.fail("Harvesting pose is static")
					return
	set_physics_process(false)
	for child in get_children():
		var item = child
		if child is CanvasItem:
			item.visible = false
		var layer = child
		if child is CanvasLayer:
			layer.visible = false
	var camera = cam
	camera.enabled = false
	my_id = -999
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.substr(7)
	if DisplayServer.get_name() == "headless":
		print("HARVEST ANIM ALL OK: resource selection/cache and 432 sprite cells (run without --headless to exercise drawing)")
		get_tree().quit()
	# catch (Exception E) dropped

func _process(delta: float) -> void:
	clock = pass_ * 0.09
	queue_redraw()

func _draw() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	draw_rect(get_viewport_rect(), Color("252B34"))
	var font = ThemeDB.fallback_font
	var skins = ["Scout", "Healer", "Engineer"]
	for role in range(3):
		for type in range(4):
			var key: int = 100 + role * 4 + type
			var foot = Vector2(125 + type * 270, 140 + role * 175)
			var target = Vector2(900 + type * 100, 900)
			var p = snap.ps[1].duplicate()
			var angle: float = pass_ / 12 % 8 * PI / 4
			p[1] = role
			p[2] = target - Vector2.from_angle(angle) * 35
			p[5] = 0
			p[11] = false
			p[22] = "gather"
			p[23] = target
			player_view.draw_player(key, p, foot)
			draw_string(font, foot + Vector2(-85, 32), "%s / %s" % [skins[role], Cs.s(GameSim.RES[type])], 16)
			if Cs.s(anim_state[key][0]) != expected[type]:
				Cs.fail("Renderer did not choose harvesting sprite")
				return
	pass_ += 1
	if pass_ == 96:
		print("HARVEST ANIM ALL OK: 3 characters, 4 resources, 8 directions, looping renderer and 432 sprite cells")
		if shot != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()
	# catch (Exception E) dropped
