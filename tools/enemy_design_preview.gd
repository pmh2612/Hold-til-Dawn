class_name EnemyDesignPreview
extends Main
# Review the shipped sheets through the game's renderer, at the game's actual drawing scales.
# --headless validates all cells; otherwise saves idle/attack/corpse screenshots and exercises 8 facings.
var review_frame: int = 0
var finished: bool = false
var names = ["grunt", "spitter", "wrecker", "boss_juggernaut", "boss_broodmother", "boss_bio_cannon", "boss_burrower", "boss_gatebreaker", "boss_phantom", "boss_ironhide"]

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
	sim = GameSim.new()
	sim.add_player(1, "Scale reference", 0)
	sim.start_match()
	my_id = -1
	on_snap(sim.snapshot())
	var checked: int = 0
	for name in names:
		var info = cinfo.chars[name]
		var cell: int = int(info.size)
		var sheet = load("res://art/chars/%s.png" % [name]).get_image()
		if sheet.get_width() != cell * 14 or sheet.get_height() != cell * 8:
			Cs.fail("Unexpected sheet layout: %s" % [name])
			return
		for row in range(8):
			for col in range(14):
				var pose = sheet.get_region(Rect2i(col * cell, row * cell, cell, cell))
				if pose.is_invisible():
					Cs.fail("Missing pose: %s/%s/%s" % [name, row, col])
					return
				checked += 1
	if absf(EnemyView.BOSS_DRAW_SCALE / 2.0 - 1.5) > 0.001:
		Cs.fail("Incorrect boss scale")
		return
	print("ENEMY DESIGN ASSETS OK: %s cells, 10 sheets, boss scale 1.5 times previous" % [checked])
	DirAccess.make_dir_recursive_absolute("res://.tmp/enemy-redesign/rendered")
	if DisplayServer.get_name() == "headless":
		finished = true
		get_tree().quit()
	# catch (Exception E) dropped

func _physics_process(delta: float) -> void:
	pass

func _process(delta: float) -> void:
	if not finished:
		clock = review_frame * 0.05
		queue_redraw()

func _draw() -> void:
	if finished:
		return
	# try (GDScript has no exceptions; the body runs unguarded)
	draw_rect(get_viewport_rect(), Color("252D35"))
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 28), "ENEMY REDESIGN / actual in-game size", 20)
	draw_string(font, Vector2(650, 65), "Scout / size reference", 13)
	player_view.char_("reference", "scout", Vector2(715, 110), PI / 2, 1.0, Color.WHITE)
	var shown = {}
	for i in range(names.size()):
		var boss: bool = i >= 3
		var index: int = i - 3
		var foot = Vector2(120 + index % 4 * 230, 300 + index / 4 * 200) if boss else Vector2(100 + i * 200, 110)
		var key = "e%s" % [100 + i]
		var angle: float = review_frame / 12 % 8 * PI / 4
		# Supply a stable foot and facing just as the interpolation cache does in a match.
		cmove[key] = [foot, -1.0 if review_frame < 96 else float(clock), angle, -1]
		if review_frame < 192:
			var enemy = [100 + i, GameSim.BOSS if boss else i, foot, 100.0, 100.0, 28.8 if boss else 20.0 if i == 2 else 16.0, index if boss else -1, "glow" if review_frame >= 96 and review_frame % 12 < 4 else "", angle, review_frame >= 96 and review_frame % 12 < 4]
			enemy_view.draw_enemy(enemy, foot)
			shown[100 + i] = true
		draw_string(font, foot + Vector2(-55, 20), names[i].replace("boss_", ""), 13)
	enemy_view.note_fallen(shown)
	var corpses = []
	enemy_view.corpse_items(corpses)
	for item in corpses:
		enemy_view.draw_corpse(int(item[2]))
	var _old1 = review_frame
	review_frame += 1
	var captured_frame: int = _old1
	if captured_frame == 12 or captured_frame == 99 or captured_frame == 210:
		await RenderingServer.frame_post_draw
		var shot = get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.linear_to_srgb()
		shot.save_png("res://.tmp/enemy-redesign/rendered/frame-%03d.png" % [captured_frame])
	if review_frame >= 216:
		finished = true
		print("ENEMY DESIGN RENDER OK: idle, walk, attacks, wind-ups and corpses across eight directions")
		get_tree().quit()
	# catch (Exception E) dropped
