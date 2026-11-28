class_name EnemyDesignPreview
extends Main
# Review the shipped sheets through the game's renderer, at the game's actual drawing scales.
# --headless validates all cells; otherwise saves idle/attack/corpse screenshots and exercises 8 facings.
var review_frame: int = 0
var finished: bool = false
var interactive: bool = false
var juggernaut_skills: bool = false
var chainwarden_skills: bool = false
var animation_time: float = 0.0
var names = ["grunt", "spitter", "wrecker", "boss_juggernaut", "boss_broodmother", "boss_bio_cannon", "boss_burrower", "boss_gatebreaker", "boss_phantom", "boss_ironhide"]

func _ready() -> void:
	# Review only artwork: no island generation, audio mixer, AI or match simulation.
	Engine.max_fps = 60
	interactive = "--interactive" in OS.get_cmdline_user_args()
	juggernaut_skills = "--juggernaut-skills" in OS.get_cmdline_user_args()
	chainwarden_skills = "--chainwarden-skills" in OS.get_cmdline_user_args()
	cinfo = JSON.parse_string(FileAccess.get_file_as_string("res://art/chars/chars.json"))
	var bosses = JSON.parse_string(FileAccess.get_file_as_string("res://art/chars/bosses.json"))
	cinfo.chars.merge(bosses.chars)
	for skin in cinfo.chars:
		csheet[skin] = load("res://art/chars/%s.png" % skin)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	snap = {"ph": "day"}
	my_id = -1
	var checked: int = 0
	for name in names:
		var info = cinfo.chars[name]
		var cell: int = int(info.size)
		var resolution: int = int(info.get("resolution", 1))
		var is_boss: bool = name.begins_with("boss_")
		var scale_: float = EnemyView.BOSS_DRAW_SCALE if is_boss else 1.0
		if (is_boss and not info.get("pixel_art", false)) or info.get("smooth", false) or not is_equal_approx(scale_ / resolution, 1.0):
			Cs.fail("Enemy pixel density differs from Engineer: %s" % name)
			return
		var gutter: int = int(info.get("gutter", 0))
		var anchor := (Vector2(info.anchor[0], info.anchor[1]) - Vector2.ONE * gutter) / resolution
		var expected_anchor := Vector2(28, 46) if name == "wrecker" else Vector2(24, 46) if name.begins_with("boss_") else Vector2(24, 37)
		var expected_gutter: int = 2 * resolution if is_boss else 0
		if gutter != expected_gutter or not anchor.is_equal_approx(expected_anchor):
			Cs.fail("Incorrect padded foot anchor: %s" % name)
			return
		if not is_boss and (cell != (56 if name == "wrecker" else 48) or info.body != (40 if name == "wrecker" else 32)):
			Cs.fail("Original regular enemy layout was changed: %s" % name)
			return
		var sheet = load("res://art/chars/%s.png" % [name]).get_image()
		var columns: int = 32 if name == "boss_juggernaut" else 38 if name == "boss_broodmother" else 14
		if sheet.get_width() != cell * columns or sheet.get_height() != cell * 8:
			Cs.fail("Unexpected sheet layout: %s" % [name])
			return
		var colours := {}
		var bytes: PackedByteArray = sheet.get_data()
		for offset in range(0, bytes.size(), 4):
			if bytes[offset + 3] == 255:
				colours[(int(bytes[offset]) << 16) | (int(bytes[offset + 1]) << 8) | int(bytes[offset + 2])] = true
		if colours.size() > 40:
			Cs.fail("Enemy palette exceeds 40 colours: %s" % name)
			return
		for row in range(8):
			for col in range(columns):
				var pose = sheet.get_region(Rect2i(col * cell, row * cell, cell, cell))
				if pose.is_invisible():
					Cs.fail("Missing pose: %s/%s/%s" % [name, row, col])
					return
				if is_boss and pose.detect_alpha() == Image.ALPHA_BLEND:
					Cs.fail("Antialiased edge in pixel art: %s/%s/%s" % [name, row, col])
					return
				# Filtering must not sample an adjacent attack/corpse into the idle frame.
				for border in ([Rect2i(0, 0, cell, gutter), Rect2i(0, cell - gutter, cell, gutter), Rect2i(0, 0, gutter, cell), Rect2i(cell - gutter, 0, gutter, cell)] if gutter > 0 else []):
					if not pose.get_region(border).is_invisible():
						Cs.fail("Animation cell bleed: %s/%s/%s" % [name, row, col])
						return
				checked += 1
		if name == "boss_juggernaut":
			for clip_name in ["slam_wind", "slam_hit", "charge_wind", "charge_run"]:
				var clip: Array = info.anims[clip_name]
				for row in range(8):
					var unique: Dictionary = {}
					for col in range(int(clip[0]), int(clip[0]) + int(clip[1])):
						var pixels: PackedByteArray = sheet.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_data()
						unique[hash(pixels)] = true
					if unique.size() < 3:
						Cs.fail("Juggernaut skill does not animate in direction %s: %s" % [row, clip_name])
						return
		elif name == "boss_broodmother":
			for clip_name in ["sweep_wind", "sweep_hit", "chain_wind", "chain_cast", "chain_pull"]:
				var clip: Array = info.anims[clip_name]
				for row in range(8):
					var unique: Dictionary = {}
					for col in range(int(clip[0]), int(clip[0]) + int(clip[1])):
						var pixels: PackedByteArray = sheet.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_data()
						unique[hash(pixels)] = true
					if unique.size() < 3:
						Cs.fail("Chainwarden skill does not animate in direction %s: %s" % [row, clip_name])
						return
	var fx_specs: Array = [
		["chainwarden_sweep", 272, 272, 6, 5],
		["juggernaut_slam", 224, 224, 6, 5],
		["juggernaut_charge", 160, 128, 4, 3],
		["bio_barrage_burst", 144, 144, 5, 4],
		["acid_bomb", 56, 56, 4, 3],
		["acid_pool", 160, 160, 6, 5],
		["burrow_erupt", 176, 176, 6, 5],
		["burrower_spine", 56, 72, 6, 5],
		["earthshaker_fissure", 128, 128, 6, 5],
		["earthshaker_ring", 320, 320, 6, 5],
		["phantom_slash", 208, 208, 6, 5],
		["phantom_dash", 128, 64, 5, 4],
		["phantom_cloak", 160, 160, 6, 5],
		["volt_lightning", 128, 256, 6, 5],
		["volt_beam", 288, 64, 4, 3]
	]
	for spec in fx_specs:
		var fx_name: String = spec[0]
		var fw: int = int(spec[1])
		var fh: int = int(spec[2])
		var fcount: int = int(spec[3])
		var min_unique: int = int(spec[4])
		var fx_tex = load("res://art/fx/%s.png" % fx_name)
		var fx_img: Image = fx_tex.get_image() if fx_tex != null else null
		if fx_img == null or fx_img.get_width() != fw * fcount or fx_img.get_height() != fh:
			Cs.fail("Missing or mis-sized boss FX sheet: %s" % fx_name)
			return
		var fx_unique: Dictionary = {}
		for col in range(fcount):
			var frame_img: Image = fx_img.get_region(Rect2i(col * fw, 0, fw, fh))
			if frame_img.is_invisible() or frame_img.detect_alpha() == Image.ALPHA_BLEND:
				Cs.fail("Invalid boss FX frame: %s/%s" % [fx_name, col])
				return
			fx_unique[hash(frame_img.get_data())] = true
		if fx_unique.size() < min_unique:
			Cs.fail("Boss FX sheet does not animate across frames: %s" % fx_name)
			return
	if absf(EnemyView.BOSS_DRAW_SCALE / 2.0 - 1.5) > 0.001:
		Cs.fail("Incorrect boss scale")
		return
	print("ENEMY DESIGN ASSETS OK: %s pixel-art cells, 3 original enemies and 7 current bosses, world scale preserved" % [checked])
	DirAccess.make_dir_recursive_absolute("res://.tmp/enemy-redesign/rendered")
	if DisplayServer.get_name() == "headless":
		finished = true
		get_tree().quit()
	# catch (Exception E) dropped

func _physics_process(delta: float) -> void:
	pass

func _process(delta: float) -> void:
	if not finished:
		animation_time += delta
		clock = animation_time if interactive else review_frame * 0.05
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _draw() -> void:
	if finished:
		return
	# try (GDScript has no exceptions; the body runs unguarded)
	draw_rect(get_viewport_rect(), Color("252D35"))
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(24, 28), "ENEMY ART / actual in-game size", 20)
	draw_string(font, Vector2(650, 65), "Engineer / pixel-size reference", 13)
	player_view.char_("reference", "engineer", Vector2(715, 110), PI / 2, 1.0, Color.WHITE)
	var shown = {}
	var cycle: int = int(animation_time * 20) % 240 if interactive else review_frame
	for i in range(0 if juggernaut_skills or chainwarden_skills else names.size()):
		var boss: bool = i >= 3
		var index: int = i - 3
		var foot = Vector2(120 + index % 4 * 230, 300 + index / 4 * 200) if boss else Vector2(100 + i * 200, 110)
		var key = "e%s" % [100 + i]
		var angle: float = cycle / 12 % 8 * PI / 4
		# Supply a stable foot and facing just as the interpolation cache does in a match.
		cmove[key] = [foot, -1.0 if cycle < 96 else float(clock), angle, -1]
		if cycle < 192:
			var enemy = [100 + i, GameSim.BOSS if boss else i, foot, 100.0, 100.0, 35.2 if boss else 20.0 if i == 2 else 16.0, index if boss else -1, "glow" if cycle >= 96 and cycle % 12 < 4 else "", angle, cycle >= 96 and cycle % 12 < 4]
			enemy_view.draw_enemy(enemy, foot)
			shown[100 + i] = true
		draw_string(font, foot + Vector2(-55, 20), names[i].replace("boss_", ""), 13)
	if chainwarden_skills:
		draw_chainwarden_skills()
	elif juggernaut_skills:
		draw_juggernaut_skills()
	else:
		enemy_view.note_fallen(shown)
	var corpses = []
	enemy_view.corpse_items(corpses)
	for item in corpses:
		enemy_view.draw_corpse(int(item[2]))
	var _old1 = review_frame
	review_frame += 1
	var captured_frame: int = _old1
	if not interactive and (captured_frame == 12 or captured_frame == 99 or captured_frame == 210):
		await RenderingServer.frame_post_draw
		var shot = get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.linear_to_srgb()
		shot.save_png("res://.tmp/enemy-redesign/rendered/%s-%03d.png" % ["chainwarden" if chainwarden_skills else "juggernaut" if juggernaut_skills else "frame", captured_frame])
	if not interactive and review_frame >= 240:
		finished = true
		print("ENEMY DESIGN RENDER OK: idle, walk, attacks, wind-ups and corpses across eight directions")
		get_tree().quit()
	# catch (Exception E) dropped

func draw_juggernaut_skills() -> void:
	for row in range(2):
		for col in range(4):
			var foot: Vector2 = Vector2(120 + col * 230, 285 + row * 210)
			var look: String = ["slam", "slam_impact", "charge_wind", "charge"][col]
			var left: float = SimBosses.SLAM_WINDUP - fposmod(float(clock), SimBosses.SLAM_WINDUP) if col == 0 else 1.0 - fposmod(float(clock), 1.0) if col == 2 else 0.0
			var age: float = fposmod(float(clock), SimBosses.SLAM_IMPACT) if col == 1 else 99.0
			var enemy: Array = [500 + row * 4 + col, GameSim.BOSS, foot, 100.0, 100.0, 35.2, GameSim.JUGGERNAUT, look, 0.0 if row == 0 else PI / 2, false, false, false, left, age]
			enemy_view.draw_enemy(enemy, foot)
			draw_string(ThemeDB.fallback_font, foot + Vector2(-90, 24), ["Slam / raise fists", "Slam / ground impact", "Charge / prepare", "Charge / sprint"][col], 13)

func draw_chainwarden_skills() -> void:
	for row in range(2):
		for col in range(5):
			var foot: Vector2 = Vector2(110 + col * 190, 285 + row * 210)
			var look: String = ["sweep_wind", "sweep_hit", "chain_wind", "chain_fly", "chain_pull"][col]
			var duration: float = [SimChainwarden.SWEEP_WIND, SimChainwarden.SWEEP_HIT, SimChainwarden.HOOK_WIND, .4, SimChainwarden.PULL_TIME][col]
			var left: float = duration - fposmod(float(clock), duration)
			var enemy: Array = [600 + row * 5 + col, GameSim.BOSS, foot, 100.0, 100.0, 35.2, GameSim.CHAINWARDEN, look, 0.0 if row == 0 else PI / 2, false, false, false, left, 99.0]
			enemy_view.draw_enemy(enemy, foot)
			if col == 1:
				enemy_view.draw_chainwarden_sweep_at(foot, 0.0 if row == 0 else PI / 2, SimChainwarden.SWEEP_HIT - left)
			draw_string(ThemeDB.fallback_font, foot + Vector2(-65, 24), ["Sweep / prepare", "Sweep / strike", "Hook / prepare", "Hook / throw", "Hook / pull"][col], 13)
	snap.chains = [[Vector2(680, 495), Vector2(840, 495), -1]]
	enemy_view.draw_chains()
