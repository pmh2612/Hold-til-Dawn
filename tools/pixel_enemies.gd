extends Node
## Offline boss pixel-art authoring using native pixel-grid primitives matching
## Engineer, Healer, Scout, Grunt, Spitter and Wrecker (zero vector ovals/gradients).
## Regular enemies retain their original shipped artwork and are never written by this tool.
## Run: godot --headless --path . tools/PixelEnemies.tscn [-- --only=<boss>]
const GUTTER := 2 # Logical transparent pixels on every side of every pose.
const CELL := 48
const RES := 3
const S := CELL * RES # 144x144 authoring canvas per pose (1 texel = 1 Engineer world pixel).
const CX := 72
const GROUND := 138
const NAMES := ["boss_juggernaut", "boss_broodmother", "boss_bio_cannon", "boss_burrower", "boss_gatebreaker", "boss_phantom", "boss_ironhide"]
# Canonical rows matching PixelChars: right, down, left (mirrored), up, down_right, down_left (mirrored), up_left (mirrored), up_right.
const VIEWS := ["side", "down", "side", "up", "down3q", "down3q", "up3q", "up3q"]
const MIRROR_SRC := {2: 0, 5: 4, 6: 7}

# Shared ink / face colours matching PixelChars.gd exactly.
const INK := Color("141019")
const MOUTH := Color("120A16")
const FANG := Color("E8E3C8")
const DUST_LIT := Color("EFE2C4")
const DUST_MID := Color("C7B799")
const SPARK_W := Color("FFFFE0")
const SPARK_Y := Color("FFD55A")

var kind: String = ""
var pal: Dictionary = {}

func _ready() -> void:
	var out := "res://art/chars"
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).trim_prefix("boss_")
	DirAccess.make_dir_recursive_absolute(out)
	var bosses := {"chars": {}}
	if only != "" and FileAccess.file_exists(out.path_join("bosses.json")):
		bosses = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("bosses.json")))
	var generated: int = 0
	var poses: int = 0
	for name_ in NAMES:
		kind = name_.trim_prefix("boss_")
		if only != "" and kind != only:
			continue
		pal = boss_palette(kind)
		var padded_cell: int = CELL + GUTTER * 2 # 52 logical -> 156 px
		var cell_px: int = padded_cell * RES
		var columns: int = 32 if kind == "juggernaut" else 38 if kind == "broodmother" else 14
		var sheet := Image.create_empty(cell_px * columns, cell_px * 8, false, Image.FORMAT_RGBA8)
		var row_frames: Dictionary = {}
		for row in [0, 1, 3, 4, 7]:
			var view: String = VIEWS[row]
			var frames: Array[Image] = []
			frames.resize(columns)
			# Standing references for knocked-down poses (cols 10..13), matching PixelPoses.fall.
			var stand_open: Image = render_frame(view, 0, false)
			var stand_shut: Image = render_frame(view, 0, true)
			frames[0] = finish_pose(stand_open, null)
			for col in range(1, columns):
				if col in range(10, 14):
					frames[col] = make_down_frame(stand_open, stand_shut, view, col - 10)
				else:
					var fx_layer := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
					var body_im: Image = render_frame(view, col, false, fx_layer)
					frames[col] = finish_pose(body_im, fx_layer)
			row_frames[row] = frames
			for col in range(columns):
				sheet.blit_rect(frames[col], Rect2i(0, 0, S, S), Vector2i(col * cell_px + GUTTER * RES, row * cell_px + GUTTER * RES))
		# Mirror left-facing rows directly from right-facing rows, matching PixelChars.MIRRORED.
		for dst_row in MIRROR_SRC:
			var src_frames: Array = row_frames[MIRROR_SRC[dst_row]]
			for col in range(columns):
				var flipped: Image = src_frames[col].duplicate()
				flipped.flip_x()
				sheet.blit_rect(flipped, Rect2i(0, 0, S, S), Vector2i(col * cell_px + GUTTER * RES, dst_row * cell_px + GUTTER * RES))
		if sheet.save_png(out.path_join(name_ + ".png")) != OK:
			push_error("Cannot save " + name_)
			get_tree().quit(1)
			return
		if kind == "broodmother":
			var fx_dir: String = "res://art/fx" if out == "res://art/chars" else out
			generate_chainwarden_sweep(fx_dir)
		var metadata := {
			"size": cell_px,
			"body": CELL * RES,
			"anchor": [(CELL / 2.0 + GUTTER) * RES, (46.0 + GUTTER) * RES],
			"resolution": RES,
			"gutter": GUTTER * RES,
			"smooth": false,
			"pixel_art": true,
			"anims": {"attack": [6, 4, 10.0], "down": [10, 4, 8.0]}
		}
		if kind == "juggernaut":
			metadata.anims.merge({
				"slam_wind": [14, 6, 4.0],
				"slam_hit": [20, 4, 4.0 / 0.65],
				"charge_wind": [24, 4, 4.0],
				"charge_run": [28, 4, 16.0]
			})
		elif kind == "broodmother":
			metadata.anims.merge({
				"sweep_wind": [14, 6, 6.0 / 0.8],
				"sweep_hit": [20, 6, 6.0 / 0.35],
				"chain_wind": [26, 4, 4.0 / 0.55],
				"chain_cast": [30, 4, 12.0],
				"chain_pull": [34, 4, 4.0 / 0.55]
			})
		bosses.chars[name_] = metadata
		generated += 1
		poses += columns * 8
		var col_count: int = count_unique_colours(sheet)
		print("PIXEL ENEMY: ", name_, " / ", sheet.get_size(), " / ", col_count, " colours")
	var file := FileAccess.open(out.path_join("bosses.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(bosses, "\t"))
	file.close()
	print("PIXEL ENEMY GENERATION OK: %d boss atlases, %d poses, regular enemy artwork preserved" % [generated, poses])
	get_tree().quit()

func count_unique_colours(im: Image) -> int:
	var seen: Dictionary = {}
	var bytes: PackedByteArray = im.get_data()
	for i in range(0, bytes.size(), 4):
		if bytes[i + 3] == 255:
			seen[(int(bytes[i]) << 16) | (int(bytes[i + 1]) << 8) | int(bytes[i + 2])] = true
	return seen.size()

# ---- Palettes (3-tone ramps [lit, mid, shade] matching GDD / PixelChars style) -------------------
func ramp(a: String, b: String, c: String) -> Array:
	return [Color(a), Color(b), Color(c)]

func boss_palette(k: String) -> Dictionary:
	var base: Dictionary = {
		"bone": ramp("FFF0CF", "D9BD8A", "8C6B4E"),
		"steel": ramp("DCE6EC", "8DA7B6", "465E73"),
		"iron": ramp("6E7482", "454A57", "262933"),
		"acid": ramp("F4FFAA", "C4F244", "6B992C"),
		"hood": ramp("2B374A", "1A2333", "0E1421"),
		"gold": ramp("FFFFD8", "FFD55A", "D68236"),
		"cyan": ramp("F0FFFF", "68F2FF", "269CC4"),
		"eye": Color("FFE680"),
		"eye_hi": Color("FFFFEE"),
		"accent": Color("FFD55A"),
	}
	match k:
		"juggernaut":
			base["skin"] = ramp("ED8D48", "BA4E32", "713025")
			base["armor"] = base["bone"]
			base["eye"] = Color("FFD85A")
			base["accent"] = Color("FFE6A0")
		"broodmother": # NOX-02 Chainwarden
			base["skin"] = ramp("C3B58C", "81765A", "474137")
			base["armor"] = base["steel"]
			base["eye"] = Color("FFD55A")
			base["accent"] = Color("FFFFD8")
		"bio_cannon": # NOX-03 Bio-Cannon
			base["skin"] = ramp("8BB858", "4F753D", "263E2F")
			base["armor"] = ramp("526958", "34463C", "1C2824")
			base["eye"] = Color("E2FF6B")
			base["eye_hi"] = Color("FAFFD6")
			base["accent"] = Color("C4F244")
		"burrower": # NOX-04 Burrower
			base["skin"] = ramp("E3BE74", "A37842", "573E26")
			base["armor"] = base["bone"]
			base["snout"] = ramp("E6AA8E", "BD7C64", "7D4C3E")
			base["eye"] = Color("FF7244")
			base["eye_hi"] = Color("FFF2A8")
			base["accent"] = Color("FFF0CF")
		"gatebreaker": # NOX-05 Earthshaker
			base["skin"] = ramp("CE9D6A", "8A5E3B", "4A3324")
			base["armor"] = ramp("A8BAC4", "5F7585", "314252")
			base["crest"] = ramp("FF9654", "D65436", "7D2A24")
			base["eye"] = Color("FFB845")
			base["accent"] = Color("FF9640")
		"phantom": # NOX-06 Phantom
			base["skin"] = ramp("D6FAFF", "78C7DC", "3B6D94")
			base["armor"] = ramp("B8EEFA", "5598BA", "2A4D73")
			base["eye"] = Color("8CF7FF")
			base["eye_hi"] = Color("FFFFFF")
			base["accent"] = Color("F0FFFF")
		"ironhide": # NOX-07 Voltspire
			base["skin"] = ramp("9BB3C4", "547087", "2C4054")
			base["armor"] = base["steel"]
			base["eye"] = Color("7CF5FF")
			base["eye_hi"] = Color("FFFFFF")
			base["accent"] = Color("68F2FF")
	return base

# ---- Low-level crisp pixel-grid primitives (ZERO ovals, ZERO antialiasing) -----------------------
static func rect(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var x0: int = maxi(2, x)
	var y0: int = maxi(2, y)
	var x1: int = mini(im.get_width() - 2, x + w)
	var y1: int = mini(im.get_height() - 2, y + h)
	if x1 > x0 and y1 > y0:
		im.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), col)

static func rbox(im: Image, x: int, y: int, w: int, h: int, r: Array, chamfer: int = 3, inner_ink: bool = false) -> void:
	# Chamfered pixel block with flat upper-left 3-tone cel shading matching Engineer/Wrecker.
	if w <= 0 or h <= 0:
		return
	var c: int = mini(chamfer, mini(w / 3, h / 3))
	var lit_t: int = clampi(h / 5, 2, 5)
	var lit_l: int = clampi(w / 5, 2, 5)
	var sh_b: int = clampi(h / 5, 2, 5)
	var sh_r: int = clampi(w / 5, 2, 5)
	for dy in range(h):
		var inset: int = 0
		if dy < c:
			inset = c - dy
		elif dy >= h - c:
			inset = dy - (h - 1 - c)
		var rx: int = x + inset
		var rw: int = w - inset * 2
		if rw <= 0:
			continue
		var py: int = y + dy
		if dy < lit_t:
			rect(im, rx, py, rw, 1, r[0])
		elif dy >= h - sh_b:
			rect(im, rx, py, rw, 1, r[2])
		else:
			rect(im, rx, py, rw, 1, r[1])
			rect(im, rx, py, mini(lit_l, rw), 1, r[0])
			rect(im, rx + maxi(0, rw - sh_r), py, mini(sh_r, rw), 1, r[2])
	if inner_ink:
		# Crisp 1px top/bottom bevel line for layered armor plates.
		rect(im, x + c, y + h - 1, w - c * 2, 1, INK)

static func trap(im: Image, x_top: float, w_top: float, y_top: int, x_bot: float, w_bot: float, y_bot: int, r: Array, rim: int = 3) -> void:
	# Scanline stepped trapezoid with upper-left cel shading.
	if y_bot <= y_top:
		return
	var span: float = float(y_bot - y_top)
	var lit_t: int = mini(rim + 1, maxi(2, (y_bot - y_top) / 6))
	var sh_b: int = mini(rim + 1, maxi(2, (y_bot - y_top) / 6))
	for py in range(y_top, y_bot):
		var t: float = float(py - y_top) / span
		var cx: float = lerpf(x_top, x_bot, t)
		var hw: float = lerpf(w_top, w_bot, t) * 0.5
		var rx: int = roundi(cx - hw)
		var rw: int = maxi(1, roundi(hw * 2.0))
		if py < y_top + lit_t:
			rect(im, rx, py, rw, 1, r[0])
		elif py >= y_bot - sh_b:
			rect(im, rx, py, rw, 1, r[2])
		else:
			rect(im, rx, py, rw, 1, r[1])
			rect(im, rx, py, mini(rim, rw), 1, r[0])
			rect(im, rx + maxi(0, rw - rim), py, mini(rim, rw), 1, r[2])

static func poly_fill(im: Image, pts: Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var min_y: int = 9999
	var max_y: int = -9999
	for p in pts:
		min_y = mini(min_y, floori(p.y))
		max_y = maxi(max_y, ceili(p.y))
	min_y = maxi(2, min_y)
	max_y = mini(im.get_height() - 3, max_y)
	var n: int = pts.size()
	for y in range(min_y, max_y + 1):
		var fy: float = float(y) + 0.5
		var xs: Array[float] = []
		for i in range(n):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		var k: int = 0
		while k + 1 < xs.size():
			var x0: int = roundi(xs[k])
			var x1: int = roundi(xs[k + 1])
			rect(im, x0, y, maxi(1, x1 - x0), 1, col)
			k += 2

static func poly_shaded(im: Image, pts: Array, r: Array, rim: int = 3) -> void:
	if pts.size() < 3:
		return
	var min_y: int = 9999
	var max_y: int = -9999
	for p in pts:
		min_y = mini(min_y, floori(p.y))
		max_y = maxi(max_y, ceili(p.y))
	var h: int = maxi(1, max_y - min_y)
	var top_lit: int = min_y + mini(rim + 1, maxi(2, h / 5))
	var bot_sh: int = max_y - mini(rim + 1, maxi(2, h / 5))
	min_y = maxi(2, min_y)
	max_y = mini(im.get_height() - 3, max_y)
	var n: int = pts.size()
	for y in range(min_y, max_y + 1):
		var fy: float = float(y) + 0.5
		var xs: Array[float] = []
		for i in range(n):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		var k: int = 0
		while k + 1 < xs.size():
			var x0: int = roundi(xs[k])
			var x1: int = roundi(xs[k + 1])
			var rw: int = maxi(1, x1 - x0)
			if y < top_lit:
				rect(im, x0, y, rw, 1, r[0])
			elif y > bot_sh:
				rect(im, x0, y, rw, 1, r[2])
			else:
				rect(im, x0, y, rw, 1, r[1])
				rect(im, x0, y, mini(rim, rw), 1, r[0])
				rect(im, x0 + maxi(0, rw - rim), y, mini(rim, rw), 1, r[2])
			k += 2

static func pixel_line(im: Image, a: Vector2, b: Vector2, w: int, col: Color) -> void:
	var steps: int = maxi(1, ceili(a.distance_to(b) * 1.4))
	var half: int = w / 2
	for i in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		rect(im, roundi(p.x) - half, roundi(p.y) - half, w, w, col)

static func seg_quad(im: Image, a: Vector2, b: Vector2, w_a: float, w_b: float, r: Array) -> void:
	# Chunky angular pixel limb segment — crisp straight sides, flat ends, ZERO round joints!
	var d: Vector2 = b - a
	if d.length_squared() < 1.0:
		rbox(im, roundi(a.x - w_a * 0.5), roundi(a.y - w_a * 0.5), roundi(w_a), roundi(w_a), r, 2)
		return
	var perp: Vector2 = d.normalized().orthogonal()
	# Ensure perp points toward upper-left so lit rim is always consistent.
	if perp.dot(Vector2(-0.6, -0.8)) < 0.0:
		perp = -perp
	var ha: float = w_a * 0.5
	var hb: float = w_b * 0.5
	var p0: Vector2 = a + perp * ha
	var p1: Vector2 = b + perp * hb
	var p2: Vector2 = b - perp * hb
	var p3: Vector2 = a - perp * ha
	poly_fill(im, [p0, p1, p2, p3], r[1])
	# Crisp upper-left highlight strip (top 28% width) and lower-right shadow strip (bottom 28% width).
	var lit_in_a: Vector2 = a + perp * (ha * 0.42)
	var lit_in_b: Vector2 = b + perp * (hb * 0.42)
	poly_fill(im, [p0, p1, lit_in_b, lit_in_a], r[0])
	var sh_in_a: Vector2 = a - perp * (ha * 0.42)
	var sh_in_b: Vector2 = b - perp * (hb * 0.42)
	poly_fill(im, [sh_in_a, sh_in_b, p2, p3], r[2])

static func block_limb(im: Image, root: Vector2, mid: Vector2, tip: Vector2, w0: float, w1: float, r: Array) -> void:
	var w_mid: float = lerpf(w0, w1, 0.45)
	seg_quad(im, root, mid, w0, w_mid, r)
	seg_quad(im, mid, tip, w_mid, w1, r)
	# Small chamfered elbow/knee block so bends never leave a notch, still 100% angular.
	var jb: int = maxi(4, roundi(w_mid * 0.92))
	rbox(im, roundi(mid.x - jb * 0.5), roundi(mid.y - jb * 0.5), jb, jb, r, 2)

# Composite layer onto dst with a crisp 1px #141019 outline (identical to PixelPoses.over).
static func composite_layer(dst: Image, layer: Image, outline_px: int = 1) -> void:
	var used: Rect2i = layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var w: int = dst.get_width()
	var h: int = dst.get_height()
	var x0: int = maxi(0, used.position.x - outline_px)
	var y0: int = maxi(0, used.position.y - outline_px)
	var x1: int = mini(w - 1, used.end.x + outline_px)
	var y1: int = mini(h - 1, used.end.y + outline_px)
	var lb: PackedByteArray = layer.get_data()
	var db: PackedByteArray = dst.get_data()
	var ir: int = INK.r8
	var ig: int = INK.g8
	var ib: int = INK.b8
	if outline_px > 0:
		for y in range(y0, y1 + 1):
			var row_o: int = y * w
			for x in range(x0, x1 + 1):
				var idx: int = (row_o + x) * 4
				if lb[idx + 3] > 0:
					continue
				var touch: bool = false
				if x > 0 and lb[idx - 1] > 0:
					touch = true
				elif x < w - 1 and lb[idx + 7] > 0:
					touch = true
				elif y > 0 and lb[idx - w * 4 + 3] > 0:
					touch = true
				elif y < h - 1 and lb[idx + w * 4 + 3] > 0:
					touch = true
				if touch:
					db[idx] = ir
					db[idx + 1] = ig
					db[idx + 2] = ib
					db[idx + 3] = 255
	for y in range(used.position.y, used.end.y):
		var row_o: int = y * w
		for x in range(used.position.x, used.end.x):
			var idx: int = (row_o + x) * 4
			if lb[idx + 3] > 0:
				db[idx] = lb[idx]
				db[idx + 1] = lb[idx + 1]
				db[idx + 2] = lb[idx + 2]
				db[idx + 3] = 255
	dst.set_data(w, h, false, Image.FORMAT_RGBA8, db)

# Bold 2px outer silhouette outline (only outside the combined character, binary alpha).
static func finish_pose(body: Image, fx_layer: Image) -> Image:
	var w: int = body.get_width()
	var h: int = body.get_height()
	var out: Image = body.duplicate()
	var used: Rect2i = body.get_used_rect()
	if used.size != Vector2i.ZERO:
		var src: PackedByteArray = body.get_data()
		var dst: PackedByteArray = src.duplicate()
		var x0: int = maxi(0, used.position.x - 2)
		var y0: int = maxi(0, used.position.y - 2)
		var x1: int = mini(w - 1, used.end.x + 1)
		var y1: int = mini(h - 1, used.end.y + 1)
		var ir: int = INK.r8
		var ig: int = INK.g8
		var ib: int = INK.b8
		# Two crisp 4-connected dilations create a clean chamfered 2px pixel-art border!
		for _pass in range(2):
			var read_buf: PackedByteArray = dst.duplicate()
			for y in range(y0, y1 + 1):
				var row_o: int = y * w
				for x in range(x0, x1 + 1):
					var idx: int = (row_o + x) * 4
					if read_buf[idx + 3] > 0:
						continue
					var hit: bool = false
					if x > 0 and read_buf[idx - 1] > 0:
						hit = true
					elif x < w - 1 and read_buf[idx + 7] > 0:
						hit = true
					elif y > 0 and read_buf[idx - w * 4 + 3] > 0:
						hit = true
					elif y < h - 1 and read_buf[idx + w * 4 + 3] > 0:
						hit = true
					if hit:
						dst[idx] = ir
						dst[idx + 1] = ig
						dst[idx + 2] = ib
						dst[idx + 3] = 255
		out.set_data(w, h, false, Image.FORMAT_RGBA8, dst)
	if fx_layer != null:
		composite_layer(out, fx_layer, 0)
	return out

# ---- Knocked down / Death sequence (cols 10..13), matching PixelPoses.fall -----------------------
func make_down_frame(stand_open: Image, stand_shut: Image, view: String, stage: int) -> Image:
	var src: Image = stand_shut if stage == 3 else stand_open
	var legs_y: int = 104
	if stage == 0:
		# Stagger back, knees dip slightly.
		var shift_x: int = -4 if view in ["side", "down3q", "up3q"] else 0
		var im: Image = kneel_shift(src, legs_y, 4, shift_x)
		return finish_pose(im, null)
	elif stage == 1:
		# Knees buckle deeper and torso tilts backward.
		var shift_x: int = -7 if view in ["side", "down3q", "up3q"] else 0
		var im: Image = kneel_shift(src, legs_y, 11, shift_x)
		var rot: Image = rotate_nearest(im, deg_to_rad(-14.0), Vector2(CX, GROUND - 8), Vector2(0, 2))
		return finish_pose(rot, null)
	elif stage == 2:
		# Toppling backward mid-fall.
		var rot: Image = rotate_nearest(src, deg_to_rad(-54.0), Vector2(CX, 92), Vector2(0, 14))
		return finish_pose(fit_to_ground(rot, GROUND - 8), null)
	else:
		# Lying flat horizontally with eyes shut, matching Engineer/Grunt/Wrecker down frame 3.
		var rot: Image = rotate_nearest(src, deg_to_rad(-88.0), Vector2(CX, 84), Vector2.ZERO)
		return finish_pose(fit_to_ground(rot, GROUND), null)

static func kneel_shift(src: Image, legs_y: int, drop: int, shift_x: int) -> Image:
	var im := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	im.blit_rect(src, Rect2i(0, legs_y + drop, S, S - (legs_y + drop)), Vector2i(0, legs_y + drop))
	var dst_x: int = clampi(shift_x, -20, 20)
	im.blend_rect(src, Rect2i(maxi(0, -dst_x), 0, S - absi(dst_x), legs_y), Vector2i(maxi(0, dst_x), drop))
	return im

static func rotate_nearest(src: Image, radians: float, pivot: Vector2, offset: Vector2) -> Image:
	var out := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var used: Rect2i = src.get_used_rect()
	if used.size == Vector2i.ZERO:
		return out
	var cos_a: float = cos(-radians)
	var sin_a: float = sin(-radians)
	var sb: PackedByteArray = src.get_data()
	var db: PackedByteArray = out.get_data()
	for y in range(4, S - 4):
		var dy: float = float(y) - (pivot.y + offset.y)
		var row_o: int = y * S
		for x in range(4, S - 4):
			var dx: float = float(x) - (pivot.x + offset.x)
			var sx: int = roundi(dx * cos_a - dy * sin_a + pivot.x)
			var sy: int = roundi(dx * sin_a + dy * cos_a + pivot.y)
			if sx >= 0 and sy >= 0 and sx < S and sy < S:
				var sidx: int = (sy * S + sx) * 4
				if sb[sidx + 3] > 0:
					var didx: int = (row_o + x) * 4
					db[didx] = sb[sidx]
					db[didx + 1] = sb[sidx + 1]
					db[didx + 2] = sb[sidx + 2]
					db[didx + 3] = 255
	out.set_data(S, S, false, Image.FORMAT_RGBA8, db)
	return out

static func fit_to_ground(src: Image, target_bottom: int) -> Image:
	var used: Rect2i = src.get_used_rect()
	if used.size == Vector2i.ZERO:
		return src
	var out := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var dx: int = CX - (used.position.x + used.size.x / 2)
	var dy: int = target_bottom - used.end.y
	# Clamp so the silhouette never touches the 3px outline margin.
	dx = clampi(dx, 4 - used.position.x, (S - 4) - used.end.x)
	dy = clampi(dy, 4 - used.position.y, (S - 4) - used.end.y)
	out.blit_rect(src, used, used.position + Vector2i(dx, dy))
	return out

# ---- Master per-frame renderer -------------------------------------------------------------------
func render_frame(view: String, col: int, shut: bool, fx_layer: Image = null) -> Image:
	if kind == "broodmother":
		return render_chainwarden(view, col, shut, fx_layer)
	if kind == "juggernaut" and col >= 14:
		return render_juggernaut_skill(view, col, fx_layer)
	var side_v: bool = view == "side"
	var back_v: bool = view.begins_with("up")
	var three_q: bool = view.ends_with("3q")
	var w_sc: float = 0.68 if side_v else 0.90 if three_q else 1.0
	var face_dx: int = 8 if side_v else 5 if three_q else 0
	var ghost: bool = kind == "phantom"
	var heavy: bool = kind in ["juggernaut", "gatebreaker", "ironhide"]

	# Idle breath bob & walk stride — exact same rhythm as Engineer/Healer/Scout/Wrecker!
	var bob: int = 0
	var stride: int = 0
	var pose: int = 0 # 1=wind-up, 2=slam/strike, 3=impact, 4=recover
	var lean_x: int = 0
	if col == 1:
		bob = 3
	elif col == 2:
		bob = 3
		stride = 1
	elif col == 4:
		bob = 3
		stride = -1
	elif col in range(6, 10):
		pose = col - 5
		bob = [-4, 2, 5, 2][pose - 1]
		var dir_x: int = 1 if side_v or three_q else 0
		lean_x = dir_x * [-4, 4, 6, 2][pose - 1]

	var canvas := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	# 1) Back accessories visible behind legs/torso (cloak ribbons, dorsal blades, chimneys)
	var back_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	if ghost:
		draw_phantom_ribbons(back_l, view, bob, stride, pose)
	draw_back_gear(back_l, view, w_sc, bob, lean_x, false)
	composite_layer(canvas, back_l, 1)

	# 2) Legs & sturdy boots (or Phantom's jagged spectral cloak base)
	var legs_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	if ghost:
		draw_phantom_cloak(legs_l, view, w_sc, bob, stride, lean_x)
	else:
		draw_legs(legs_l, view, w_sc, stride, heavy)
	composite_layer(canvas, legs_l, 1)

	# 3) Far/rear arm (drawn behind torso on side/3q views; on up views both arms sit behind/beside)
	var both_front_atk: bool = not side_v and not back_v and pose > 0
	var far_arm_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	if side_v:
		draw_boss_arm(far_arm_l, -1, view, w_sc, bob, stride, pose, lean_x, true)
	elif back_v:
		draw_boss_arm(far_arm_l, -1, view, w_sc, bob, stride, pose, lean_x, true)
		draw_boss_arm(far_arm_l, 1, view, w_sc, bob, stride, pose, lean_x, false)
	elif not both_front_atk:
		draw_boss_arm(far_arm_l, -1, view, w_sc, bob, stride, pose, lean_x, true)
	composite_layer(canvas, far_arm_l, 1)

	# 4) Broad blocky torso + armor + waist belt + chest details
	var torso_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	if not ghost:
		draw_torso(torso_l, view, w_sc, bob, lean_x, heavy)
	draw_shoulders(torso_l, view, w_sc, bob, lean_x, heavy)
	if back_v:
		draw_back_gear(torso_l, view, w_sc, bob, lean_x, true)
	else:
		draw_chest_detail(torso_l, view, w_sc, face_dx, bob, lean_x)
	composite_layer(canvas, torso_l, 1)

	# 5) Prominent chunky pixel head, helmet/hood, horns/crest, square eyes & fang mouth
	var head_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	draw_head(head_l, view, w_sc, face_dx, bob, lean_x, shut)
	composite_layer(canvas, head_l, 1)

	# 6) Foreground / weapon arm (drawn cleanly on top with 1px ink border, matching PixelPoses!)
	if not back_v:
		var near_arm_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
		if both_front_atk:
			draw_boss_arm(near_arm_l, -1, view, w_sc, bob, stride, pose, lean_x, true)
		draw_boss_arm(near_arm_l, 1, view, w_sc, bob, stride, pose, lean_x, false)
		composite_layer(canvas, near_arm_l, 1)

	# 7) Impact dust & pixel sparks on attack frames 2-3 (unoutlined FX layer)
	if fx_layer != null and pose in [2, 3]:
		draw_attack_fx(fx_layer, view, pose)

	return canvas

# ---- Shared Chunky Anatomy Builders (Zero Ovals!) ------------------------------------------------
func draw_legs(im: Image, view: String, w_sc: float, stride: int, heavy: bool) -> void:
	var side_v: bool = view == "side"
	var leg_w: int = 18 if heavy else 15
	var foot_w: int = leg_w + 6
	var skin_r: Array = pal["skin"]
	var boot_r: Array = pal["iron"] if kind in ["juggernaut", "broodmother", "gatebreaker", "ironhide"] else pal["armor"]
	if side_v:
		# Side profile stride: angled pixel legs rooted cleanly under the hip (zero hip overhang!).
		var back_foot_x: int = CX - 4 - stride * 11
		var front_foot_x: int = CX + 4 + stride * 11
		var back_lift: int = 4 if stride < 0 else 0
		var front_lift: int = 4 if stride > 0 else 0
		for entry in [[CX - 3, back_foot_x, back_lift, true], [CX + 3, front_foot_x, front_lift, false]]:
			var hip_x: int = int(entry[0])
			var fx: int = int(entry[1])
			var lift: int = int(entry[2])
			var is_far: bool = bool(entry[3])
			var r_use: Array = [skin_r[1], skin_r[2], skin_r[2]] if is_far else skin_r
			var by: int = GROUND - lift
			seg_quad(im, Vector2(hip_x, 102), Vector2(fx, by - 9), float(leg_w), float(leg_w - 2), r_use)
			# Heavy shin guard / knee plate aligned along the leg
			if heavy or kind == "burrower":
				var kx: int = roundi(lerpf(float(hip_x), float(fx), 0.55))
				rbox(im, kx - leg_w / 2 + 2, 113 - lift / 2, leg_w - 2, 10, pal["armor"], 2, true)
			# Flat sturdy pixel boot extending slightly forward
			rbox(im, fx - leg_w / 2 - 1, by - 11, foot_w + 1, 11, boot_r, 2)
			rect(im, fx - leg_w / 2, by - 3, foot_w - 1, 3, INK)
	else:
		var spread: int = roundi((15.0 if heavy else 13.0) * w_sc)
		for side_s in [-1, 1]:
			var lx: int = CX + side_s * spread
			var lift: int = 6 if (stride > 0 and side_s < 0) or (stride < 0 and side_s > 0) else 0
			var by: int = GROUND - lift
			rbox(im, lx - leg_w / 2, 102, leg_w, by - 108, skin_r, 2)
			if heavy or kind == "burrower":
				rbox(im, lx - leg_w / 2 + 1, 112, leg_w - 2, 11, pal["armor"], 2, true)
			# Flat blocky boot
			rbox(im, lx - foot_w / 2, by - 11, foot_w, 11, boot_r, 2)
			rect(im, lx - foot_w / 2 + 2, by - 3, foot_w - 4, 3, boot_r[2])
			if kind == "burrower":
				# Chunky ivory digging toe-claws
				for tc in [-5, 0, 5]:
					rect(im, lx + tc - 1, by - 4, 3, 5, pal["bone"][0])

func draw_torso(im: Image, view: String, w_sc: float, bob: int, lean_x: int, heavy: bool) -> void:
	var side_v: bool = view == "side"
	var top_w: float = (62.0 if heavy else 52.0 if kind != "bio_cannon" else 56.0) * w_sc
	var bot_w: float = (48.0 if heavy else 42.0) * w_sc
	var y0: int = 60 + bob
	var y1: int = 108 + bob
	var tx: float = float(CX + lean_x)
	# Architectural broad-shouldered tapered torso block (ZERO egg ovals!)
	trap(im, tx, top_w, y0, tx, bot_w, y1, pal["skin"], 4)
	# Crisp horizontal shoulder top cap
	rect(im, roundi(tx - top_w * 0.5) + 3, y0, roundi(top_w) - 6, 4, pal["skin"][0])
	# Belt / armored waist band — directly echoes Engineer/Healer/Scout belt grammar!
	var bw: int = roundi(bot_w) + 4
	var belt_r: Array = pal["iron"] if kind != "bio_cannon" else pal["armor"]
	rbox(im, roundi(tx - bw * 0.5), y1 - 12, bw, 11, belt_r, 2, true)
	if not view.begins_with("up"):
		var bdx: int = 6 if side_v else 3 if view.ends_with("3q") else 0
		var buckle_c: Color = pal["accent"] if kind in ["gatebreaker", "ironhide", "bio_cannon"] else pal["gold"][1]
		rect(im, roundi(tx) + bdx - 5, y1 - 10, 10, 7, INK)
		rect(im, roundi(tx) + bdx - 4, y1 - 9, 8, 5, buckle_c)
		rect(im, roundi(tx) + bdx - 4, y1 - 9, 3, 2, SPARK_W)

func draw_shoulders(im: Image, view: String, w_sc: float, bob: int, lean_x: int, heavy: bool) -> void:
	if kind == "phantom":
		return
	var side_v: bool = view == "side"
	var tx: int = CX + lean_x
	var sy: int = 56 + bob
	match kind:
		"juggernaut":
			# Massive angular beveled bone shoulder-slabs with sharp bone spikes (NOT eggs!)
			var signs: Array = [0] if side_v else [-1, 1]
			for s in signs:
				var sx: int = tx + (0 if side_v else roundi(s * 30.0 * w_sc))
				var sw: int = 28 if side_v else 24
				rbox(im, sx - sw / 2, sy - 2, sw, 18, pal["bone"], 4, true)
				# Jagged upward bone spike on outer shoulder corner
				var sp_x: int = sx + (2 if side_v else s * 6)
				poly_shaded(im, [Vector2(sp_x - 5, sy), Vector2(sp_x + (3 if side_v else s * 7), sy - 16), Vector2(sp_x + 5, sy)], pal["bone"], 2)
		"gatebreaker", "ironhide":
			# Square riveted fortress shoulder blocks echoing Wrecker's signature slabs!
			var signs: Array = [0] if side_v else [-1, 1]
			for s in signs:
				var sx: int = tx + (0 if side_v else roundi(s * 30.0 * w_sc))
				var sw: int = 26 if side_v else 24
				rbox(im, sx - sw / 2, sy - 2, sw, 20, pal["armor"], 3, true)
				# Rivets & accent trim
				rect(im, sx - sw / 2 + 3, sy + 2, sw - 6, 3, pal["armor"][0])
				rect(im, sx - sw / 2 + 4, sy + 12, 3, 3, pal["accent"])
				rect(im, sx + sw / 2 - 7, sy + 12, 3, 3, pal["accent"])
				if kind == "gatebreaker":
					# Glowing amber magma crack across shoulder slab
					pixel_line(im, Vector2(sx - 6, sy + 7), Vector2(sx + 2, sy + 11), 2, pal["gold"][1])
					pixel_line(im, Vector2(sx + 2, sy + 11), Vector2(sx + 7, sy + 6), 2, pal["accent"])
				else:
					# NOX-07 Voltspire: tall stepped Tesla lightning spire rising from each shoulder!
					var spire_x: int = sx + (0 if side_v else s * 2)
					trap(im, float(spire_x), 6.0, sy - 38, float(spire_x), 14.0, sy - 1, pal["steel"], 2)
					# Glowing electric-cyan coil rings
					for cy in [sy - 11, sy - 21, sy - 30]:
						rect(im, spire_x - 6, cy, 12, 4, INK)
						rect(im, spire_x - 5, cy + 1, 10, 2, pal["cyan"][1])
						rect(im, spire_x - 4, cy + 1, 4, 2, pal["cyan"][0])
					# Glowing diamond Tesla arc tip (zero circles!)
					poly_shaded(im, [Vector2(spire_x, sy - 46), Vector2(spire_x + 6, sy - 40), Vector2(spire_x, sy - 34), Vector2(spire_x - 6, sy - 40)], pal["cyan"], 2)
					rect(im, spire_x - 2, sy - 41, 4, 3, pal["cyan"][0])
		"bio_cannon":
			# Armored shoulder collar flanges
			var signs: Array = [0] if side_v else [-1, 1]
			for s in signs:
				var sx: int = tx + (0 if side_v else roundi(s * 26.0 * w_sc))
				rbox(im, sx - 11, sy + 1, 22, 16, pal["armor"], 3, true)
				rect(im, sx - 6, sy + 5, 12, 4, pal["acid"][1])
		"burrower":
			# Segmented sandstone carapace shoulder plates
			var signs: Array = [0] if side_v else [-1, 1]
			for s in signs:
				var sx: int = tx + (0 if side_v else roundi(s * 25.0 * w_sc))
				rbox(im, sx - 11, sy + 2, 22, 16, pal["skin"], 3, true)
				rect(im, sx - 9, sy + 9, 18, 2, pal["skin"][2])

func draw_back_gear(im: Image, view: String, w_sc: float, bob: int, lean_x: int, on_back_view: bool) -> void:
	var side_v: bool = view == "side"
	var tx: int = CX + lean_x
	var y_base: int = 58 + bob
	match kind:
		"bio_cannon":
			# Twin tall rectangular/octagonal spore mortar chimneys with acid glow & coolant pipes!
			var xs: Array = [tx - 16, tx - 4] if side_v else [tx - roundi(26.0 * w_sc), tx + roundi(26.0 * w_sc)]
			for cx_ in xs:
				trap(im, float(cx_), 18.0, y_base - 38, float(cx_), 15.0, y_base + 14, pal["skin"], 3)
				# Dark armored barrel collar + acid rim
				rbox(im, cx_ - 11, y_base - 42, 22, 10, pal["acid"], 2, true)
				rect(im, cx_ - 7, y_base - 40, 14, 4, pal["hood"][1])
				rect(im, cx_ - 5, y_base - 39, 10, 2, pal["acid"][0])
				# Ribbed glowing acid coolant strip down chimney
				rect(im, cx_ - 2, y_base - 28, 5, 28, pal["acid"][2])
				rect(im, cx_ - 1, y_base - 26, 3, 24, pal["acid"][1])
				for ry in range(y_base - 24, y_base - 2, 7):
					rect(im, cx_ - 6, ry, 12, 2, pal["armor"][2])
			if on_back_view:
				# Back acid spine reservoir tank
				rbox(im, tx - 14, 68 + bob, 28, 30, pal["armor"], 3, true)
				for ry in [74, 83, 92]:
					rect(im, tx - 9, ry + bob, 18, 5, pal["acid"][1])
					rect(im, tx - 8, ry + bob, 8, 2, pal["acid"][0])
		"burrower":
			# Four bold stepped-pixel dorsal bone-plow spikes fanned cleanly past the head silhouette!
			var offsets: Array = [-24.0, -10.0, 4.0, 14.0] if side_v else [-31.0, -18.0, 18.0, 31.0]
			for i in range(4):
				var bx: float = float(tx) + float(offsets[i]) * (1.0 if side_v else w_sc)
				var h_sp: float = 36.0 if i in [1, 2] else 28.0
				var tilt: float = -8.0 if side_v else (-10.0 if i == 0 else -5.0 if i == 1 else 5.0 if i == 2 else 10.0)
				poly_shaded(im, [
					Vector2(bx - 6, y_base + 8),
					Vector2(bx + tilt, y_base - h_sp),
					Vector2(bx + 6, y_base + 8)
				], pal["bone"], 2)
			if on_back_view:
				# Segmented armadillo carapace ridges on back
				for ry in [70, 81, 92]:
					rbox(im, tx - roundi(22.0 * w_sc), ry + bob, roundi(44.0 * w_sc), 9, pal["skin"], 2, true)
		"juggernaut":
			if on_back_view:
				# Row of bone spine plates down the back
				for i in range(4):
					rbox(im, tx - 7, 66 + bob + i * 10, 14, 7, pal["bone"], 2, true)
		"gatebreaker":
			if on_back_view:
				# Riveted siege harness plate on back
				rbox(im, tx - roundi(20.0 * w_sc), 66 + bob, roundi(40.0 * w_sc), 34, pal["armor"], 3, true)
				pixel_line(im, Vector2(tx - 14, 70 + bob), Vector2(tx + 14, 96 + bob), 5, pal["iron"][1])
				pixel_line(im, Vector2(tx + 14, 70 + bob), Vector2(tx - 14, 96 + bob), 5, pal["iron"][1])
				rbox(im, tx - 6, 78 + bob, 12, 10, pal["gold"], 2)
		"ironhide":
			if on_back_view:
				# Tesla power-pack backpack with cyan conduit bars
				rbox(im, tx - roundi(19.0 * w_sc), 66 + bob, roundi(38.0 * w_sc), 34, pal["armor"], 3, true)
				for cx_ in [tx - 9, tx + 3]:
					rect(im, cx_, 72 + bob, 6, 22, pal["hood"][1])
					rect(im, cx_ + 1, 74 + bob, 4, 18, pal["cyan"][1])
					rect(im, cx_ + 1, 74 + bob, 2, 6, pal["cyan"][0])

func draw_chest_detail(im: Image, view: String, w_sc: float, face_dx: int, bob: int, lean_x: int) -> void:
	var tx: int = CX + lean_x + face_dx / 2
	var y0: int = 66 + bob
	match kind:
		"juggernaut":
			# Exposed stepped bone rib-bars matching Grunt's signature chest design!
			var rw: int = roundi(32.0 * w_sc)
			for i in range(3):
				var ry: int = y0 + 6 + i * 9
				rect(im, tx - rw / 2, ry, rw / 2 - 2, 4, pal["bone"][1])
				rect(im, tx - rw / 2, ry, rw / 2 - 4, 2, pal["bone"][0])
				rect(im, tx + 3, ry, rw / 2 - 2, 4, pal["bone"][1])
				rect(im, tx + 3, ry, rw / 2 - 4, 2, pal["bone"][0])
		"bio_cannon":
			# Recessed OCTAGONAL / SQUARED bio-mortar aperture (ZERO concentric circles!)
			var cw: int = roundi(28.0 * w_sc)
			rbox(im, tx - cw / 2, y0 + 2, cw, 28, pal["armor"], 5, true)
			rbox(im, tx - cw / 2 + 4, y0 + 6, cw - 8, 20, pal["hood"], 4)
			rbox(im, tx - cw / 2 + 8, y0 + 10, cw - 16, 12, pal["acid"], 2)
			rect(im, tx - 3, y0 + 13, 6, 5, pal["acid"][0])
			# Corner vents
			rect(im, tx - cw / 2 + 2, y0 + 4, 3, 3, pal["acid"][1])
			rect(im, tx + cw / 2 - 5, y0 + 4, 3, 3, pal["acid"][1])
		"burrower":
			# Stacked horizontal armored earth-belly plates
			var pw: int = roundi(34.0 * w_sc)
			for i in range(3):
				rbox(im, tx - pw / 2, y0 + 4 + i * 10, pw, 8, pal["skin"], 2, true)
		"gatebreaker":
			# Crossed dark-iron siege harness + glowing amber tectonic core buckle
			var hw: int = roundi(20.0 * w_sc)
			pixel_line(im, Vector2(tx - hw, y0 + 2), Vector2(tx + hw, y0 + 30), 6, pal["iron"][1])
			pixel_line(im, Vector2(tx + hw, y0 + 2), Vector2(tx - hw, y0 + 30), 6, pal["iron"][1])
			pixel_line(im, Vector2(tx - hw, y0 + 1), Vector2(tx + hw, y0 + 29), 2, pal["iron"][0])
			rbox(im, tx - 8, y0 + 10, 16, 12, pal["armor"], 2, true)
			rect(im, tx - 4, y0 + 13, 8, 6, pal["gold"][1])
			rect(im, tx - 3, y0 + 14, 4, 3, pal["gold"][0])
		"ironhide":
			# Heavy angular fortress cuirass + diamond electric Tesla core!
			var pw: int = roundi(42.0 * w_sc)
			rbox(im, tx - pw / 2, y0 - 2, pw, 34, pal["armor"], 5, true)
			# Recessed octagonal core housing
			rbox(im, tx - 12, y0 + 4, 24, 22, pal["hood"], 5)
			# Diamond plasma core (zero circles!)
			poly_shaded(im, [Vector2(tx, y0 + 7), Vector2(tx + 8, y0 + 15), Vector2(tx, y0 + 23), Vector2(tx - 8, y0 + 15)], pal["cyan"], 2)
			rect(im, tx - 3, y0 + 13, 6, 4, pal["cyan"][0])
			# Jagged lightning vents flanking core
			pixel_line(im, Vector2(tx - pw / 2 + 3, y0 + 6), Vector2(tx - 11, y0 + 13), 2, pal["cyan"][1])
			pixel_line(im, Vector2(tx + pw / 2 - 3, y0 + 6), Vector2(tx + 11, y0 + 13), 2, pal["cyan"][1])

func draw_head(im: Image, view: String, w_sc: float, face_dx: int, bob: int, lean_x: int, shut: bool) -> void:
	var side_v: bool = view == "side"
	var back_v: bool = view.begins_with("up")
	var three_q: bool = view.ends_with("3q")
	var hx: int = CX + lean_x + (6 if side_v else 2 if three_q else 0)
	var hy: int = 28 + bob
	var hw: int = roundi((34.0 if side_v else 38.0 if kind in ["juggernaut", "gatebreaker", "ironhide"] else 34.0) * (1.0 if side_v else lerpf(1.0, 0.94, 1.0 if three_q else 0.0)))
	var hh: int = 32

	if kind == "phantom":
		draw_phantom_head(im, view, hx, hy, face_dx, shut)
		return

	# Base chunky pixel skull (matching Engineer/Grunt/Wrecker blocky chamfered head!)
	rbox(im, hx - hw / 2, hy, hw, hh, pal["skin"], 5, true)
	# Heavy brow ridge
	rect(im, hx - hw / 2 + 4, hy + 11, hw - 8, 3, pal["skin"][2])

	# Boss-specific headgear / horns / helmet / crest
	match kind:
		"juggernaut":
			# Twin chunky angular stepped ivory bull horns!
			if side_v:
				poly_shaded(im, [Vector2(hx + 1, hy + 6), Vector2(hx + 24, hy - 15), Vector2(hx + 17, hy + 8)], pal["bone"], 2)
				poly_shaded(im, [Vector2(hx - 11, hy + 6), Vector2(hx - 4, hy - 19), Vector2(hx + 3, hy + 6)], pal["bone"], 2)
			else:
				for s in [-1, 1]:
					var bx: float = float(hx + s * (hw / 2 - 4))
					poly_shaded(im, [
						Vector2(bx - s * 5, hy + 8),
						Vector2(bx + s * 13, hy - 17),
						Vector2(bx + s * 6, hy + 13)
					], pal["bone"], 2)
					pixel_line(im, Vector2(bx + s * 9, hy - 12), Vector2(bx + s * 12, hy - 16), 2, pal["bone"][0])
		"gatebreaker":
			# Squared steel siege helm + tall crimson-amber crest fin!
			rbox(im, hx - hw / 2 - 2, hy - 4, hw + 4, 17, pal["armor"], 4, true)
			rect(im, hx - hw / 2 + 2, hy + 10, hw - 4, 3, pal["armor"][2])
			# Tall angular crest fin
			if side_v:
				poly_shaded(im, [Vector2(hx - 8, hy - 3), Vector2(hx + 4, hy - 20), Vector2(hx + 12, hy - 3)], pal["crest"], 2)
			else:
				rbox(im, hx - 4, hy - 19, 8, 17, pal["crest"], 2)
				rect(im, hx - 3, hy - 17, 3, 12, pal["gold"][0])
		"ironhide":
			# Heavy angular battle-mech iron helmet with brow visor & side ear-fins!
			rbox(im, hx - hw / 2 - 2, hy - 4, hw + 4, 19, pal["armor"], 4, true)
			# Center forehead crest ridge
			rbox(im, hx - 5, hy - 10, 10, 14, pal["steel"], 2)
			rect(im, hx - 2, hy - 8, 4, 10, pal["cyan"][1])
			if not side_v:
				rbox(im, hx - hw / 2 - 6, hy + 4, 6, 12, pal["iron"], 1)
				rbox(im, hx + hw / 2, hy + 4, 6, 12, pal["iron"], 1)
		"bio_cannon":
			# Acid-veined chitin brow crest & ridge
			rbox(im, hx - hw / 2 + 2, hy - 4, hw - 4, 9, pal["armor"], 3, true)
			for vx in [-8, 0, 8]:
				rect(im, hx + vx - 1, hy - 2, 3, 6, pal["acid"][1])
		"burrower":
			# Heavy flat-browed bone earth-plow plate with twin side horns (not a pointy roof!)
			rbox(im, hx - hw / 2 - 2, hy - 3, hw + 4, 13, pal["bone"], 3, true)
			rect(im, hx - hw / 2 + 2, hy + 6, hw - 4, 3, pal["bone"][2])
			if not side_v:
				for s in [-1, 1]:
					poly_shaded(im, [Vector2(hx + s * 11, hy), Vector2(hx + s * 19, hy - 11), Vector2(hx + s * 17, hy + 4)], pal["bone"], 1)
			else:
				poly_shaded(im, [Vector2(hx + 4, hy), Vector2(hx + 20, hy - 8), Vector2(hx + 14, hy + 5)], pal["bone"], 1)

	if back_v:
		# Subtle back-of-head shading detail
		rect(im, hx - hw / 2 + 6, hy + 16, hw - 12, 3, pal["skin"][2])
		return

	# Expressive square/rectangular glowing pixel eyes (matching Engineer/Grunt/Wrecker!)
	var ey: int = hy + 14
	if side_v:
		var ex: int = hx + hw / 2 - 11
		rect(im, ex - 2, ey - 1, 10, 8, INK)
		if shut:
			rect(im, ex, ey + 3, 7, 2, pal["skin"][2])
		else:
			rect(im, ex, ey, 7, 6, pal["eye"])
			rect(im, ex, ey, 3, 2, pal["eye_hi"])
	else:
		var shift: int = 4 if three_q else 0
		var lx: int = hx - 11 + shift
		var rx: int = hx + 4 + shift
		var lw: int = 7 if not three_q else 6
		var rw: int = 7
		for e_entry in [[lx, lw], [rx, rw]]:
			var ex: int = int(e_entry[0])
			var ew: int = int(e_entry[1])
			rect(im, ex - 1, ey - 1, ew + 2, 8, INK)
			if shut:
				rect(im, ex, ey + 3, ew, 2, pal["skin"][2])
			else:
				rect(im, ex, ey, ew, 6, pal["eye"])
				rect(im, ex, ey, 3, 2, pal["eye_hi"])

	# Mouth / Jaw / Snout (crisp rectangular fang bar matching Grunt & Wrecker!)
	var my: int = hy + 23
	if kind == "burrower":
		# Sturdy beveled mole digging snout + upward tusks!
		var sx: int = hx + (hw / 2 - 5 if side_v else (3 if three_q else 0))
		rbox(im, sx - 9, my - 4, 18, 10, pal["snout"], 3, true)
		rect(im, sx - 4, my - 1, 2, 3, INK)
		rect(im, sx + 2, my - 1, 2, 3, INK)
		# Two ivory tusks
		rect(im, sx - 7, my + 4, 3, 4, FANG)
		rect(im, sx + 4, my + 4, 3, 4, FANG)
	elif kind == "ironhide":
		# Armored mechanical steel grille jaw
		var gx: int = hx + (hw / 2 - 11 if side_v else (3 if three_q else 0))
		var gw: int = 12 if side_v else 18
		rbox(im, gx - gw / 2, my - 1, gw, 8, pal["iron"], 2)
		for dx in range(-gw / 2 + 3, gw / 2 - 2, 4):
			rect(im, gx + dx, my + 1, 2, 4, pal["cyan"][1])
	else:
		var mx: int = hx + (hw / 2 - 12 if side_v else (3 if three_q else 0))
		var mw: int = 13 if side_v else 20
		rect(im, mx - mw / 2, my, mw, 6, MOUTH)
		# Crisp square pixel fangs
		var teeth: Array = [-4, 1] if side_v else [-7, -2, 3, 7]
		for dx in teeth:
			rect(im, mx + dx, my, 3, 3, FANG)
		if kind == "bio_cannon":
			# Dripping neon-lime pixel acid strand from maw
			rect(im, mx + (3 if side_v else 1), my + 5, 3, 8, pal["acid"][1])
			rect(im, mx + (3 if side_v else 1), my + 11, 3, 3, pal["acid"][0])

# ---- Phantom (NOX-06) Dedicated Angular Spectral Wraith Silhouette -------------------------------
func draw_phantom_head(im: Image, view: String, hx: int, hy: int, face_dx: int, shut: bool) -> void:
	var side_v: bool = view == "side"
	var back_v: bool = view.begins_with("up")
	var three_q: bool = view.ends_with("3q")
	# Tall, sharply-peaked angular wraith hood with iconic slight tilt (ZERO circles!)
	var tip_x: float = float(hx - (12 if side_v else 9))
	poly_shaded(im, [
		Vector2(tip_x, hy - 19),
		Vector2(hx + (18 if side_v else 22), hy + 14),
		Vector2(hx + (16 if side_v else 24), hy + 34),
		Vector2(hx - (18 if side_v else 24), hy + 34),
		Vector2(hx - (16 if side_v else 22), hy + 14)
	], pal["skin"], 4)
	# Crisp inner hood fold rim & dark shadow edge
	pixel_line(im, Vector2(tip_x + 2, hy - 14), Vector2(hx + 16, hy + 14), 2, pal["skin"][0])
	pixel_line(im, Vector2(hx - 16, hy + 12), Vector2(hx + 16, hy + 12), 2, pal["armor"][2])
	if back_v:
		pixel_line(im, Vector2(hx, hy - 6), Vector2(hx, hy + 30), 3, pal["skin"][2])
		return
	# Deep angular dark hood cavity
	var fx: int = hx + (5 if side_v else 3 if three_q else 0)
	var fw: int = 18 if side_v else 24
	rbox(im, fx - fw / 2, hy + 8, fw, 22, pal["hood"], 4)
	# Piercing glowing frost-cyan rectangular eyes
	var ey: int = hy + 16
	if side_v:
		if shut:
			rect(im, fx, ey + 2, 7, 2, pal["armor"][2])
		else:
			rect(im, fx, ey, 8, 5, pal["eye"])
			rect(im, fx + 1, ey, 4, 2, pal["eye_hi"])
	else:
		var sh: int = 2 if three_q else 0
		for ex in [fx - 9 + sh, fx + 3 + sh]:
			if shut:
				rect(im, ex, ey + 2, 6, 2, pal["armor"][2])
			else:
				rect(im, ex, ey, 7, 5, pal["eye"])
				rect(im, ex + 1, ey, 3, 2, pal["eye_hi"])

func draw_phantom_cloak(im: Image, view: String, w_sc: float, bob: int, stride: int, lean_x: int) -> void:
	var tx: int = CX + lean_x
	var y0: int = 58 + bob
	var sway: int = stride * 5
	var hw_top: float = 24.0 * w_sc
	var hw_bot: float = 34.0 * w_sc
	# Jagged angular spectral mantle hovering cleanly above ground (no oval blobs!)
	poly_shaded(im, [
		Vector2(tx - hw_top, y0),
		Vector2(tx + hw_top, y0),
		Vector2(tx + hw_bot + sway, 124 + bob),
		Vector2(tx + hw_bot * 0.58 + sway, 136),
		Vector2(tx + hw_bot * 0.28 + sway, 122 + bob),
		Vector2(tx + sway, 138),
		Vector2(tx - hw_bot * 0.30 + sway, 122 + bob),
		Vector2(tx - hw_bot * 0.62 + sway, 135),
		Vector2(tx - hw_bot + sway, 123 + bob)
	], pal["skin"], 4)
	# Angular frost-mantle shoulder cowl
	trap(im, float(tx), hw_top * 2.2, y0 - 2, float(tx), hw_top * 2.5, y0 + 20, pal["armor"], 3)
	# Bright vertical spectral ridge folds
	pixel_line(im, Vector2(tx - 4, y0 + 18), Vector2(tx - 2 + sway, 130), 3, pal["skin"][0])
	pixel_line(im, Vector2(tx + 7, y0 + 20), Vector2(tx + 10 + sway, 126), 2, pal["skin"][2])

func draw_phantom_ribbons(im: Image, view: String, bob: int, stride: int, pose: int) -> void:
	var side_v: bool = view == "side"
	var sway: int = stride * 6 + (8 if pose in [2, 3] else 0)
	var signs: Array = [-1] if side_v else [-1, 1]
	for s in signs:
		var rx: float = float(CX + s * 22)
		poly_shaded(im, [
			Vector2(rx, 66 + bob),
			Vector2(rx + s * 20, 96 + bob),
			Vector2(rx + s * 10 + sway, 132),
			Vector2(rx + s * 13, 102 + bob),
			Vector2(rx - s * 2, 76 + bob)
		], pal["armor"], 2)

# ---- Chunky Boss Arms & Signature Weapons (Zero Round Hands / Zero Ball Joints!) -----------------
func draw_boss_arm(im: Image, sign_: int, view: String, w_sc: float, bob: int, stride: int, pose: int, lean_x: int, far: bool) -> void:
	var side_v: bool = view == "side"
	var back_v: bool = view.begins_with("up")
	var three_q: bool = view.ends_with("3q")
	var heavy: bool = kind in ["juggernaut", "gatebreaker", "ironhide"]
	var tx: int = CX + lean_x
	var root: Vector2 = Vector2(tx + (4 if side_v and not far else -8 if side_v else roundi(sign_ * 30.0 * w_sc)), 68 + bob + (3 if far else 0))
	var arm_w: float = 16.0 if heavy else 11.0 if kind == "phantom" else 13.0
	var fore_w: float = arm_w - 2.0
	var arm_r: Array = pal["armor"] if kind == "phantom" else pal["skin"]
	if far and side_v:
		arm_r = [arm_r[1], arm_r[2], arm_r[2]]

	# Resting / walking hand target
	var swing: float = float(stride * sign_) * (10.0 if side_v else 4.0)
	var hand: Vector2 = root + Vector2((swing if side_v else sign_ * 5.0), 38.0 - absf(swing) * 0.25)
	var elbow: Vector2 = root.lerp(hand, 0.5) + Vector2(sign_ * 4.0 if not side_v else -3.0, 0.0)

	# Attack poses (cols 6..9): bold, high-contrast silhouettes matching Wrecker & Grunt in PixelPoses!
	if pose > 0:
		var fwd_x: float = 1.0 if side_v else 0.7 if three_q else 0.0
		var inward: float = -float(sign_) * (16.0 if not side_v else 0.0)
		match pose:
			1: # High wind-up: arms/weapons raised high above shoulders!
				hand = root + Vector2(sign_ * 4.0 - fwd_x * 14.0, -40.0)
				elbow = root + Vector2(sign_ * 14.0 - fwd_x * 6.0, -16.0)
			2: # Strike / slam driving forcefully forward & inward!
				if back_v:
					hand = root + Vector2(sign_ * 8.0, -14.0)
					elbow = root + Vector2(sign_ * 12.0, -4.0)
				else:
					hand = root + Vector2(fwd_x * 36.0 + inward * 0.6, 22.0 if side_v else 34.0)
					elbow = root.lerp(hand, 0.48) + Vector2(sign_ * 8.0, -10.0)
			3: # Full impact hold — fists/weapons crash down & inward!
				if back_v:
					hand = root + Vector2(sign_ * 6.0, -6.0)
					elbow = root + Vector2(sign_ * 10.0, 2.0)
				else:
					hand = root + Vector2(fwd_x * 42.0 + inward, 36.0 if side_v else 46.0)
					elbow = root.lerp(hand, 0.5) + Vector2(sign_ * 6.0, -8.0)
			4: # Follow-through recover
				hand = root + Vector2(fwd_x * 18.0 + inward * 0.35, 30.0)
				elbow = root.lerp(hand, 0.5) + Vector2(sign_ * 5.0, -3.0)

	hand = hand.clamp(Vector2(14, 14), Vector2(S - 14, S - 14))
	elbow = elbow.clamp(Vector2(14, 14), Vector2(S - 14, S - 14))

	block_limb(im, root, elbow, hand, arm_w, fore_w, arm_r)
	# Armored wrist cuff / bracer
	var cuff_at: Vector2 = elbow.lerp(hand, 0.72)
	var cuff_w: int = roundi(fore_w + 3.0)
	var cuff_r: Array = pal["iron"] if kind in ["juggernaut", "gatebreaker"] else pal["armor"]
	rbox(im, roundi(cuff_at.x - cuff_w * 0.5), roundi(cuff_at.y - 4), cuff_w, 8, cuff_r, 1, true)

	# Chunky signature fists / claws / seismic hammer-block!
	if kind == "gatebreaker" and not far:
		# NOX-05 Earthshaker: massive beveled seismic stone-steel hammer-block with glowing amber magma cracks!
		var hw: int = 30
		var hh: int = 26
		var hx: int = roundi(hand.x) - hw / 2
		var hy: int = roundi(hand.y) - hh / 2 + 2
		rbox(im, hx, hy, hw, hh, pal["armor"], 3, true)
		rect(im, hx + 3, hy + 3, hw - 6, 4, pal["armor"][0])
		# Glowing amber magma fissures etched across the seismic block
		pixel_line(im, Vector2(hx + 4, hy + 11), Vector2(hx + 15, hy + 15), 3, pal["gold"][1])
		pixel_line(im, Vector2(hx + 15, hy + 15), Vector2(hx + hw - 5, hy + 10), 3, pal["accent"])
		pixel_line(im, Vector2(hx + 14, hy + 15), Vector2(hx + 18, hy + hh - 4), 2, pal["gold"][1])
		rect(im, hx + 13, hy + 13, 4, 4, pal["gold"][0])
	elif kind == "burrower":
		# Massive boxy fist + 3 huge ivory excavator digging scythe-claws!
		rbox(im, roundi(hand.x - 9), roundi(hand.y - 7), 18, 14, pal["skin"], 2, true)
		for ci in [-6, 0, 6]:
			var cx_: float = hand.x + float(ci)
			poly_shaded(im, [
				Vector2(cx_ - 3, hand.y + 4),
				Vector2(cx_ + (3 if side_v else 0), hand.y + 22),
				Vector2(cx_ + 3, hand.y + 4)
			], pal["bone"], 1)
	elif kind == "phantom":
		# Razor-sharp jagged frost claw blades!
		rbox(im, roundi(hand.x - 6), roundi(hand.y - 5), 12, 10, pal["armor"], 2)
		for ci in [-4, 0, 4]:
			var cx_: float = hand.x + float(ci)
			poly_fill(im, [Vector2(cx_ - 2, hand.y + 2), Vector2(cx_ - 4, hand.y + 20), Vector2(cx_ + 2, hand.y + 4)], pal["accent"])
			rect(im, roundi(cx_ - 1), roundi(hand.y + 3), 2, 10, pal["eye_hi"])
	elif kind == "ironhide":
		# Armored square Tesla gauntlet with bright cyan power knuckle bar
		rbox(im, roundi(hand.x - 10), roundi(hand.y - 8), 20, 17, pal["armor"], 3, true)
		rect(im, roundi(hand.x - 7), roundi(hand.y - 2), 14, 4, pal["cyan"][1])
		rect(im, roundi(hand.x - 5), roundi(hand.y - 2), 6, 2, pal["cyan"][0])
	elif kind == "bio_cannon":
		# Chitin-armored mortar fist with neon-green glowing vent
		rbox(im, roundi(hand.x - 9), roundi(hand.y - 8), 18, 16, pal["armor"], 3, true)
		rect(im, roundi(hand.x - 5), roundi(hand.y), 10, 4, pal["acid"][1])
	else:
		# Juggernaut heavy squared brawler fist with bright knuckle studs
		rbox(im, roundi(hand.x - 11), roundi(hand.y - 9), 22, 18, pal["skin"], 3, true)
		for kx in [-6, 0, 6]:
			rect(im, roundi(hand.x) + kx - 2, roundi(hand.y) - 5, 4, 4, pal["bone"][0])

func draw_attack_fx(im: Image, view: String, pose: int) -> void:
	if kind in ["bio_cannon", "phantom"]:
		return
	var y_hit: int = GROUND - 4
	var spread: int = 26 if pose == 2 else 36
	# Crisp pixel dust puffs & ground crack lines (matches PixelPoses smash dust!)
	for dx in [-spread, -spread / 2, 0, spread / 2, spread]:
		var px_: int = CX + dx
		var py_: int = y_hit - (6 if absi(dx) == spread / 2 else 2) - (4 if pose == 3 else 0)
		rect(im, px_ - 3, py_ - 3, 6, 6, DUST_MID)
		rect(im, px_ - 2, py_ - 3, 3, 3, DUST_LIT)
	if pose == 3:
		pixel_line(im, Vector2(CX - 34, y_hit + 2), Vector2(CX - 16, y_hit - 3), 2, INK)
		pixel_line(im, Vector2(CX + 16, y_hit - 3), Vector2(CX + 34, y_hit + 2), 2, INK)

# ---- NOX-01 Juggernaut Dedicated Skill Clips (cols 14..31, 100% Blocky Pixel Art!) ---------------
func render_juggernaut_skill(view: String, col: int, fx_layer: Image) -> Image:
	var side_v: bool = view == "side"
	var back_v: bool = view.begins_with("up")
	var three_q: bool = view.ends_with("3q")
	var w_sc: float = 0.68 if side_v else 0.90 if three_q else 1.0
	var face_dx: int = 8 if side_v else 5 if three_q else 0

	var wind: bool = col < 20
	var impact: bool = col >= 20 and col < 24
	var charge_w: bool = col >= 24 and col < 28
	var charge_r: bool = col >= 28
	var phase: int = col - 14 if wind else col - 20 if impact else col - 24 if charge_w else col - 28

	var bob: int = [4, 2, -2, -5, -6, -3][phase] if wind else [12, 11, 6, 2][phase] if impact else [4, 7, 10, 12][phase] if charge_w else [9, 6, 9, 5][phase]
	var stride: int = [1, 0, -1, 0][phase] if charge_r else (-1 if charge_w and phase >= 2 else 0)
	var lean_x: int = (1 if side_v or three_q else 0) * ([-2, -3, -2, -1, 0, 1][phase] if wind else [6, 7, 4, 2][phase] if impact else [4, 6, 8, 9][phase] if charge_w else [10, 12, 10, 8][phase])

	var canvas := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var legs_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	draw_legs(legs_l, view, w_sc, stride, true)
	composite_layer(canvas, legs_l, 1)

	var far_arm_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	draw_jugg_skill_arm(far_arm_l, -1, view, w_sc, bob, lean_x, col, phase, true)
	if back_v:
		draw_jugg_skill_arm(far_arm_l, 1, view, w_sc, bob, lean_x, col, phase, false)
	composite_layer(canvas, far_arm_l, 1)

	var torso_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	draw_torso(torso_l, view, w_sc, bob, lean_x, true)
	draw_shoulders(torso_l, view, w_sc, bob, lean_x, true)
	if back_v:
		draw_back_gear(torso_l, view, w_sc, bob, lean_x, true)
	else:
		draw_chest_detail(torso_l, view, w_sc, face_dx, bob, lean_x)
	composite_layer(canvas, torso_l, 1)

	var head_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var head_drop: int = 8 if charge_r or (charge_w and phase >= 2) else 0
	draw_head(head_l, view, w_sc, face_dx, bob + head_drop, lean_x, false)
	composite_layer(canvas, head_l, 1)

	if not back_v:
		var near_arm_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
		draw_jugg_skill_arm(near_arm_l, 1, view, w_sc, bob, lean_x, col, phase, false)
		composite_layer(canvas, near_arm_l, 1)

	# Slam impact rubble & ground cracks (crisp square pixel debris!)
	if fx_layer != null and impact and phase < 3:
		for i in range(5):
			var rx: int = 24 + i * 24
			var ry: int = GROUND - 4 - (2 - phase) * (5 + (i % 2) * 5)
			rect(fx_layer, rx - 3, ry - 3, 6, 6, INK)
			rect(fx_layer, rx - 2, ry - 2, 4, 4, DUST_MID)
			rect(fx_layer, rx - 2, ry - 2, 2, 2, DUST_LIT)
		pixel_line(fx_layer, Vector2(22, GROUND + 1), Vector2(42, GROUND - 4), 3, INK)
		pixel_line(fx_layer, Vector2(42, GROUND - 4), Vector2(58, GROUND + 1), 3, INK)
		pixel_line(fx_layer, Vector2(86, GROUND + 1), Vector2(102, GROUND - 4), 3, INK)
		pixel_line(fx_layer, Vector2(102, GROUND - 4), Vector2(122, GROUND + 1), 3, INK)
	elif fx_layer != null and wind and phase >= 3:
		# Rising golden charge sparks around raised fists
		var sy: int = 16 + (5 - phase) * 4
		for sx in [CX - 22, CX + 22]:
			rect(fx_layer, sx - 2, sy - 2, 4, 4, SPARK_Y)
			rect(fx_layer, sx - 1, sy - 1, 2, 2, SPARK_W)
	return canvas

func draw_jugg_skill_arm(im: Image, sign_: int, view: String, w_sc: float, bob: int, lean_x: int, col: int, phase: int, far: bool) -> void:
	var side_v: bool = view == "side"
	var three_q: bool = view.ends_with("3q")
	var tx: int = CX + lean_x
	var root: Vector2 = Vector2(tx + (4 if side_v and not far else -8 if side_v else roundi(sign_ * 30.0 * w_sc)), 66 + bob + (3 if far else 0))
	var arm_r: Array = [pal["skin"][1], pal["skin"][2], pal["skin"][2]] if far and side_v else pal["skin"]
	var elbow: Vector2
	var hand: Vector2
	var hot_fist: bool = false
	if col < 20:
		# Slam wind-up: both giant square fists rise high above the head!
		var t: float = float(phase) / 5.0
		var hx: float = float(tx) + (14.0 if side_v and not far else 4.0 if side_v else sign_ * lerpf(36.0, 20.0, t) * w_sc)
		hand = Vector2(hx, lerpf(84.0, 18.0, t))
		elbow = Vector2(root.x + (sign_ * lerpf(6.0, 14.0, t) if not side_v else 8.0), lerpf(80.0, 44.0, t))
		hot_fist = phase >= 3
	elif col < 24:
		# Slam impact: both fists hammer the ground, then rise back!
		var lift: float = [0.0, 4.0, 18.0, 32.0][phase]
		var fwd: float = 22.0 if side_v else 10.0 if three_q else 0.0
		hand = Vector2(tx + fwd + (0.0 if side_v else sign_ * 24.0 * w_sc), GROUND - 10.0 - lift)
		elbow = root.lerp(hand, 0.5) + Vector2(sign_ * 12.0 if not side_v else -6.0, -4.0)
	else:
		# Charge prepare / sprint: aggressive bull-charge arm pump!
		var pump: float = ([0.0, 8.0, 0.0, -8.0][phase] if col >= 28 else -phase * 2.5) * float(sign_)
		var fwd: float = (20.0 if not far else -12.0) if side_v else (12.0 if three_q else 0.0)
		hand = root + Vector2(fwd + (0.0 if side_v else sign_ * 8.0), 12.0 + pump)
		elbow = root + Vector2(sign_ * 10.0 - fwd * 0.3, 18.0 + pump * 0.6)

	hand = hand.clamp(Vector2(14, 14), Vector2(S - 14, S - 12))
	elbow = elbow.clamp(Vector2(14, 14), Vector2(S - 14, S - 12))
	block_limb(im, root, elbow, hand, 17.0, 15.0, arm_r)
	# Heavy iron cuff
	var cuff: Vector2 = elbow.lerp(hand, 0.72)
	rbox(im, roundi(cuff.x - 9), roundi(cuff.y - 4), 18, 8, pal["iron"], 1, true)
	# Giant square brawler fist (glints gold-white at slam peak!)
	rbox(im, roundi(hand.x - 12), roundi(hand.y - 10), 24, 20, pal["gold"] if hot_fist else pal["skin"], 3, true)
	for kx in [-7, 0, 7]:
		rect(im, roundi(hand.x) + kx - 2, roundi(hand.y) - 6, 4, 4, SPARK_W if hot_fist else pal["bone"][0])

# ---- NOX-02 Chainwarden (boss_broodmother.png, 38 cols — 100% Blocky Pixel Art!) -----------------
func render_chainwarden(view: String, col: int, shut: bool, fx_layer: Image) -> Image:
	var side_v: bool = view == "side"
	var back_v: bool = view.begins_with("up")
	var three_q: bool = view.ends_with("3q")
	var w_sc: float = 0.68 if side_v else 0.90 if three_q else 1.0

	var wind: bool = col >= 14 and col < 20
	var sweep: bool = col >= 20 and col < 26
	var hook_wind: bool = col >= 26 and col < 30
	var hook_cast: bool = col >= 30 and col < 34
	var pulling: bool = col >= 34
	var basic_atk: bool = col in range(6, 10)

	var progress: float = (col - 14) / 5.0 if wind else (col - 20) / 5.0 if sweep else (col - 26) / 3.0 if hook_wind else (col - 30) / 3.0 if hook_cast else (col - 34) / 3.0 if pulling else (col - 6) / 3.0 if basic_atk else 0.0
	var sweep_curve: float = 1.0 - pow(1.0 - progress, 2.2) if sweep else progress

	var bob: int = 3 if col in [1, 2, 4] else 0
	var stride: int = 1 if col == 2 else -1 if col == 4 else 0
	var lean_x: int = 0
	if wind:
		bob = roundi(5.0 * progress)
		lean_x = roundi(-9.0 * progress)
		stride = -1 if progress > 0.4 else 0
	elif sweep:
		bob = roundi(7.0 * sin(sweep_curve * PI))
		lean_x = roundi(lerpf(-9.0, 10.0, sweep_curve))
		stride = 1 if sweep_curve > 0.35 else -1
	elif hook_wind:
		bob = roundi(3.0 * progress)
		lean_x = roundi(-7.0 * progress)
	elif hook_cast:
		bob = roundi(4.0 - 2.0 * progress)
		lean_x = roundi(9.0 - 2.0 * sin(progress * PI))
		stride = 1
	elif pulling:
		bob = roundi(5.0 * progress)
		lean_x = roundi(-3.0 - 9.0 * progress)
		stride = -1
	elif basic_atk:
		bob = [-3, 3, 5, 2][col - 6]
		lean_x = [-4, 5, 7, 2][col - 6] if (side_v or three_q) else 0

	var tx: int = CX + lean_x
	var canvas := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)

	# 1) Armored greave legs
	var legs_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	draw_legs(legs_l, view, w_sc, stride, true)
	composite_layer(canvas, legs_l, 1)

	# 2) Far arm (and both arms on back view)
	var far_arm_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	draw_cw_arm(far_arm_l, -1, view, w_sc, tx, bob, col, progress, sweep_curve, true)
	if back_v:
		draw_cw_arm(far_arm_l, 1, view, w_sc, tx, bob, col, progress, sweep_curve, false)
	composite_layer(canvas, far_arm_l, 1)

	# 3) Heavy fortress iron cuirass + khaki tabard + diagonal pixel chain sash + square steel pauldrons!
	var torso_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var cw_top: float = 60.0 * w_sc
	var cw_bot: float = 48.0 * w_sc
	# Under-coat & belted tabard
	trap(im_or(torso_l), float(tx), cw_top, 60 + bob, float(tx), cw_bot, 110 + bob, pal["skin"], 3)
	# Heavy angular iron breastplate
	rbox(torso_l, tx - roundi(cw_top * 0.44), 60 + bob, roundi(cw_top * 0.88), 38, pal["steel"], 4, true)
	# Center ridge & rivets
	rect(torso_l, tx - 2, 64 + bob, 4, 30, pal["steel"][0])
	rect(torso_l, tx + 2, 64 + bob, 2, 30, pal["steel"][2])
	for rx_s in [-1, 1]:
		var rpx: int = tx + roundi(rx_s * cw_top * 0.32)
		rect(torso_l, rpx - 1, 66 + bob, 3, 3, pal["gold"][1])
		rect(torso_l, rpx - 1, 89 + bob, 3, 3, pal["gold"][1])
	# Heavy iron waist belt
	rbox(torso_l, tx - roundi(cw_bot * 0.54), 97 + bob, roundi(cw_bot * 1.08), 10, pal["iron"], 2, true)
	rect(torso_l, tx - 4, 99 + bob, 8, 6, pal["gold"][1])
	# Interlocking rectangular pixel iron chain draped across chest/back!
	for ci in range(5):
		var cx_: int = tx - roundi(16.0 * w_sc) + roundi(float(ci) * 8.0 * w_sc)
		var cy_: int = 75 + bob + roundi(sin(float(ci) * 0.8) * 8.0)
		draw_chain_link(torso_l, cx_, cy_, ci % 2 == 0)
	# Boxy beveled steel pauldrons (ZERO round balls!)
	var p_signs: Array = [0] if side_v else [-1, 1]
	for s in p_signs:
		var sx: int = tx + (0 if side_v else roundi(s * 30.0 * w_sc))
		rbox(torso_l, sx - 12, 56 + bob, 24, 18, pal["steel"], 3, true)
		rect(torso_l, sx - 9, 60 + bob, 18, 3, pal["steel"][0])
		rect(torso_l, sx - 9, 68 + bob, 18, 2, pal["iron"][2])
	composite_layer(canvas, torso_l, 1)

	# 4) Tall rectangular iron cage great-helm with glowing golden visor slit & vertical prison bars!
	var head_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var hx: int = tx + (5 if side_v else 2 if three_q else 0)
	var hy: int = 24 + bob
	var hw: int = 32 if side_v else 36
	# Khaki hood crown peeking slightly at top
	rbox(head_l, hx - hw / 2 + 4, hy - 3, hw - 8, 8, pal["skin"], 2)
	# Rectangular beveled iron prison mask / great-helm
	rbox(head_l, hx - hw / 2, hy + 2, hw, 34, pal["steel"], 3, true)
	# Top crown rim rivets
	rect(head_l, hx - hw / 2 + 3, hy + 5, hw - 6, 3, pal["steel"][0])
	if not back_v:
		var v_off: int = 4 if side_v else 3 if three_q else 0
		var vw: int = 16 if side_v else 24
		var vx: int = hx + v_off - vw / 2
		var vy: int = hy + 13
		# Dark visor recessed slot
		rect(head_l, vx - 1, vy - 1, vw + 2, 7, INK)
		if shut:
			rect(head_l, vx, vy + 2, vw, 2, pal["iron"][2])
		else:
			var bright_visor: bool = (wind and progress > 0.5) or (sweep and progress < 0.6)
			rect(head_l, vx, vy, vw, 5, SPARK_W if bright_visor else pal["gold"][1])
			rect(head_l, vx + 1, vy, vw - 4, 2, SPARK_W)
		# Crisp vertical iron prison-grille bars below visor
		var bar_y: int = hy + 22
		rect(head_l, vx, bar_y, vw, 11, pal["iron"][2])
		for bx in range(vx + 2, vx + vw - 2, 5):
			rect(head_l, bx, bar_y, 2, 11, pal["steel"][0])
	else:
		rect(head_l, hx - hw / 2 + 5, hy + 14, hw - 10, 3, pal["iron"][1])
		rect(head_l, hx - hw / 2 + 5, hy + 24, hw - 10, 3, pal["iron"][1])
	composite_layer(canvas, head_l, 1)

	# 5) Foreground weapon arm & barbed pixel chain hook
	if not back_v:
		var near_arm_l := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
		draw_cw_arm(near_arm_l, 1, view, w_sc, tx, bob, col, progress, sweep_curve, false)
		composite_layer(canvas, near_arm_l, 1)

	if fx_layer != null and wind and progress > 0.55:
		# Golden spark glint telegraphing sweep release!
		rect(fx_layer, tx - 3, 18 + bob, 6, 6, SPARK_Y)
		rect(fx_layer, tx - 1, 20 + bob, 2, 2, SPARK_W)

	return canvas

static func im_or(im: Image) -> Image:
	return im

func draw_chain_link(im: Image, cx_: int, cy_: int, wide: bool) -> void:
	# Rectangular pixel chain link (ZERO ovals!)
	var w: int = 9 if wide else 6
	var h: int = 6 if wide else 9
	var x0: int = cx_ - w / 2
	var y0: int = cy_ - h / 2
	rect(im, x0 - 1, y0 - 1, w + 2, h + 2, INK)
	rect(im, x0, y0, w, h, pal["steel"][1])
	rect(im, x0, y0, w, 2, pal["steel"][0])
	rect(im, x0, y0 + h - 2, w, 2, pal["steel"][2])
	if w >= 6 and h >= 6:
		rect(im, x0 + 2, y0 + 2, w - 4, h - 4, INK)

func draw_cw_arm(im: Image, sign_: int, view: String, w_sc: float, tx: int, bob: int, col: int, progress: float, sweep_curve: float, far: bool) -> void:
	var side_v: bool = view == "side"
	var back_v: bool = view.begins_with("up")
	var three_q: bool = view.ends_with("3q")
	var wind: bool = col >= 14 and col < 20
	var sweep: bool = col >= 20 and col < 26
	var hook_wind: bool = col >= 26 and col < 30
	var hook_cast: bool = col >= 30 and col < 34
	var pulling: bool = col >= 34
	var basic_atk: bool = col in range(6, 10)

	var base_ang: float = 0.0 if side_v else PI * 0.5 if view == "down" else -PI * 0.5 if view == "up" else PI * 0.25 if view == "down3q" else -PI * 0.25
	var root: Vector2 = Vector2(tx + (4 if side_v and not far else -8 if side_v else roundi(sign_ * 30.0 * w_sc)), 68 + bob + (3 if far else 0))
	var a: float = base_ang
	var reach: float = 10.0
	var lift: float = 0.0

	if wind:
		a = base_ang + (lerpf(-0.35, -1.65, progress) if sign_ > 0 else lerpf(0.2, -0.7, progress))
		reach = lerpf(12.0, 34.0, progress) if sign_ > 0 else lerpf(10.0, 20.0, progress)
		lift = -18.0 * progress if sign_ > 0 else -5.0 * progress
	elif sweep:
		a = base_ang + (lerpf(-1.6, 1.55, sweep_curve) if sign_ > 0 else lerpf(-0.6, 1.1, sweep_curve))
		reach = (38.0 if progress < 0.75 else lerpf(38.0, 26.0, (progress - 0.75) / 0.25)) if sign_ > 0 else 22.0
		lift = -9.0 * (1.0 - sweep_curve)
	elif hook_wind:
		a = base_ang + (-lerpf(0.2, 1.25, progress) if sign_ > 0 else 0.5)
		reach = lerpf(10.0, 26.0, progress) if sign_ > 0 else 12.0
		lift = -10.0 * progress if sign_ > 0 else 0.0
	elif hook_cast:
		a = base_ang + (0.08 * sin(progress * TAU) if sign_ > 0 else 0.6)
		reach = 36.0 - 5.0 * progress if sign_ > 0 else 14.0
		lift = -4.0 if sign_ > 0 else 0.0
	elif pulling:
		a = base_ang + (0.0 if sign_ > 0 else -0.25)
		reach = lerpf(34.0, 8.0, progress) if sign_ > 0 else lerpf(28.0, 6.0, progress)
		lift = lerpf(-3.0, -11.0, progress)
	elif basic_atk:
		a = base_ang + lerpf(-1.2, 1.2, progress)
		reach = 28.0 if sign_ > 0 else 14.0
	else:
		# Idle / Walk natural arm swing
		var sw: float = 7.0 if col == 2 else -7.0 if col == 4 else 0.0
		var hand_rest: Vector2 = root + Vector2((sw * sign_ if side_v else sign_ * 5.0), 34.0)
		var elb_rest: Vector2 = root.lerp(hand_rest, 0.5) + Vector2(sign_ * 4.0 if not side_v else -2.0, 0.0)
		var arm_r_rest: Array = [pal["skin"][1], pal["skin"][2], pal["skin"][2]] if far and side_v else pal["skin"]
		block_limb(im, root, elb_rest, hand_rest, 14.0, 12.0, arm_r_rest)
		rbox(im, roundi(hand_rest.x - 9), roundi(hand_rest.y - 7), 18, 15, pal["steel"], 2, true)
		if sign_ > 0:
			draw_cw_flail(im, hand_rest, base_ang, 22.0, false)
		return

	var hand: Vector2 = (root + Vector2(cos(a) * reach, 20.0 + lift + sin(a) * reach * 0.55)).clamp(Vector2(14, 14), Vector2(S - 14, S - 14))
	var elbow: Vector2 = (root.lerp(hand, 0.5) + Vector2(sign_ * 6.0, -4.0 if wind or sweep else 0.0)).clamp(Vector2(14, 14), Vector2(S - 14, S - 14))
	var arm_r: Array = [pal["skin"][1], pal["skin"][2], pal["skin"][2]] if far and side_v else pal["skin"]
	block_limb(im, root, elbow, hand, 14.0, 12.0, arm_r)
	# Square iron gauntlet
	rbox(im, roundi(hand.x - 9), roundi(hand.y - 7), 18, 15, pal["steel"], 2, true)
	# Internal chain + barbed hook (omitted during sweep_hit, hook_cast, and pulling so runtime FX owns it cleanly!)
	if sign_ > 0 and not sweep and not hook_cast and not pulling:
		var chain_len: float = lerpf(22.0, 36.0, progress) if wind else 22.0
		var tip_a: float = a + (-0.35 if wind else 0.0)
		draw_cw_flail(im, hand, tip_a, chain_len, wind and progress > 0.55)

func draw_cw_flail(im: Image, hand: Vector2, tip_a: float, chain_len: float, gold_glint: bool) -> void:
	var tip: Vector2 = (hand + Vector2(cos(tip_a) * chain_len, sin(tip_a) * chain_len * 0.65 + (0.0 if gold_glint else 14.0))).clamp(Vector2(10, 10), Vector2(S - 10, S - 10))
	for i in range(5):
		var at: Vector2 = hand.lerp(tip, float(i) / 4.0)
		draw_chain_link(im, roundi(at.x), roundi(at.y), i % 2 == 0)
	# Heavy angular barbed hook blade (ZERO ovals!)
	var fwd: Vector2 = (tip - hand).normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector2.DOWN
	var sv: Vector2 = fwd.orthogonal()
	var h_pts: Array = [
		tip - fwd * 5.0 - sv * 4.0,
		tip + fwd * 8.0 - sv * 1.0,
		tip + fwd * 5.0 + sv * 10.0,
		tip - fwd * 4.0 + sv * 6.0,
		tip - fwd * 2.0 + sv * 2.0
	]
	poly_shaded(im, h_pts, pal["gold"] if gold_glint else pal["bone"], 2)

# ---- Crisp Native Pixel-Art Chainwarden Sweep FX (art/fx/chainwarden_sweep.png, 6x 272x272) ------
func generate_chainwarden_sweep(fx_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(fx_dir)
	var frame_size: int = 272
	var half: float = frame_size * 0.5
	var frames: int = 6
	var sheet := Image.create_empty(frame_size * frames, frame_size, false, Image.FORMAT_RGBA8)
	var steel_r: Array = pal["steel"]
	var gold_r: Array = pal["gold"]
	for col in range(frames):
		var layer := Image.create_empty(frame_size, frame_size, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / float(frames - 1)
		var lead_t: float = minf(1.0, pow(t, 0.72) * 1.08)
		var start_ang: float = -PI / 3.0
		var end_ang: float = PI / 3.0
		var head_ang: float = lerpf(start_ang, end_ang, lead_t)
		var tail_ang: float = lerpf(start_ang, end_ang, maxf(0.0, lead_t - (0.58 if col < 4 else 0.42 if col == 4 else 0.24)))
		var max_r: float = 124.0
		var inner_r: float = 92.0 if col < 5 else 104.0
		# Angular stepped pixel slash crescent
		if head_ang > tail_ang + 0.05:
			var body_pts: Array = []
			var rim_pts: Array = []
			var steps: int = 16
			for s in range(steps + 1):
				var u: float = float(s) / float(steps)
				var a: float = lerpf(tail_ang, head_ang, u)
				var taper: float = sin(u * PI)
				var r_out: float = max_r - (1.0 - taper) * 6.0
				body_pts.append(Vector2(half, half) + Vector2.from_angle(a) * r_out)
				rim_pts.append(Vector2(half, half) + Vector2.from_angle(a) * (r_out - 1.0))
			for s in range(steps, -1, -1):
				var u: float = float(s) / float(steps)
				var a: float = lerpf(tail_ang, head_ang, u)
				var taper: float = sin(u * PI)
				var r_out: float = max_r - (1.0 - taper) * 6.0
				var r_in: float = lerpf(r_out - 4.0, inner_r, pow(taper, 0.65))
				body_pts.append(Vector2(half, half) + Vector2.from_angle(a) * r_in)
				var rim_in: float = r_out - maxf(3.0, (14.0 if col < 5 else 7.0) * taper)
				rim_pts.append(Vector2(half, half) + Vector2.from_angle(a) * rim_in)
			poly_fill(layer, body_pts, steel_r[2])
			poly_fill(layer, rim_pts, steel_r[0] if col < 4 else steel_r[1])
			# Bright gold/white leading edge streak
			for s in range(8, steps):
				var u0: float = float(s) / float(steps)
				var u1: float = float(s + 1) / float(steps)
				var p0: Vector2 = Vector2(half, half) + Vector2.from_angle(lerpf(tail_ang, head_ang, u0)) * (max_r - 4.0)
				var p1: Vector2 = Vector2(half, half) + Vector2.from_angle(lerpf(tail_ang, head_ang, u1)) * (max_r - 4.0)
				pixel_line(layer, p0, p1, 3 if col < 4 else 2, SPARK_W if col < 4 else SPARK_Y)
		# Whipping rectangular pixel chain links + angular barbed golden hook
		if col < 5:
			var link_count: int = 12
			var root: Vector2 = Vector2(half, half) + Vector2.from_angle(head_ang - 0.12) * 24.0
			var tip: Vector2 = Vector2(half, half) + Vector2.from_angle(head_ang) * (max_r - 4.0)
			var ctrl: Vector2 = Vector2(half, half) + Vector2.from_angle(head_ang - 0.24) * 78.0
			for i in range(link_count):
				var u: float = float(i) / float(link_count - 1)
				var inv: float = 1.0 - u
				var at: Vector2 = root * (inv * inv) + ctrl * (2.0 * inv * u) + tip * (u * u)
				draw_chain_link(layer, roundi(at.x), roundi(at.y), i % 2 == 0)
			var fwd: Vector2 = Vector2.from_angle(head_ang)
			var side_v: Vector2 = fwd.orthogonal()
			var h_pts: Array = [
				tip - fwd * 10.0 - side_v * 4.0,
				tip + fwd * 9.0 + side_v * 1.0,
				tip + fwd * 3.0 + side_v * 13.0,
				tip - fwd * 6.0 + side_v * 8.0,
				tip - fwd * 4.0 + side_v * 2.0
			]
			poly_shaded(layer, h_pts, gold_r, 2)
			pixel_line(layer, tip - fwd * 6.0 - side_v * 2.0, tip + fwd * 7.0, 2, SPARK_W)
		# Crisp square pixel sparks along the swept arc
		for sp in range(5):
			var sa: float = lerpf(tail_ang, head_ang, 0.25 + sp * 0.17)
			var sr: float = max_r - 12.0 + (sp % 3) * 6.0
			var p_sp: Vector2 = Vector2(half, half) + Vector2.from_angle(sa) * sr
			rect(layer, roundi(p_sp.x) - 2, roundi(p_sp.y) - 2, 5, 5, SPARK_W if sp % 2 == 0 else SPARK_Y)
		var finished: Image = finish_pose(layer, null)
		sheet.blit_rect(finished, Rect2i(0, 0, frame_size, frame_size), Vector2i(col * frame_size, 0))
	if sheet.save_png(fx_dir.path_join("chainwarden_sweep.png")) != OK:
		push_error("Cannot save chainwarden_sweep.png")
		get_tree().quit(1)
		return
	print("CHAINWARDEN SWEEP FX OK: %dx%d (%d frames)" % [sheet.get_width(), sheet.get_height(), frames])
