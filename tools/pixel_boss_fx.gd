extends Node
## Offline native pixel-art skill FX sheet authoring for all bosses (matching chainwarden_sweep.png).
## Produces crisp binary-alpha sprite sheets in art/fx/ with #141019 outlines and 3-tone shading.
## Run: godot --headless --path . tools/PixelBossFx.tscn

const INK := Color("141019")

func _ready() -> void:
	var out := "res://art/fx"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	gen_juggernaut_slam(out)
	gen_juggernaut_charge(out)
	gen_bio_barrage_burst(out)
	gen_acid_bomb(out)
	gen_acid_pool(out)
	gen_burrow_erupt(out)
	gen_burrower_spine(out)
	gen_earthshaker_fissure(out)
	gen_earthshaker_ring(out)
	gen_phantom_slash(out)
	gen_phantom_dash(out)
	gen_phantom_cloak(out)
	gen_volt_lightning(out)
	gen_volt_beam(out)
	print("BOSS SKILL FX GENERATION OK: 14 sprite sheets written to ", out)
	get_tree().quit()

# ---- Shared Crisp Pixel Primitives (Binary Alpha, Zero Antialiasing) -----------------------------
static func rect(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var x0: int = maxi(2, x)
	var y0: int = maxi(2, y)
	var x1: int = mini(im.get_width() - 2, x + w)
	var y1: int = mini(im.get_height() - 2, y + h)
	if x1 > x0 and y1 > y0:
		im.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), col)

static func pixel_line(im: Image, a: Vector2, b: Vector2, w: int, col: Color) -> void:
	var steps: int = maxi(1, ceili(a.distance_to(b) * 1.4))
	var half: int = w / 2
	for i in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		rect(im, roundi(p.x) - half, roundi(p.y) - half, w, w, col)

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

static func poly_shaded(im: Image, pts: Array, r: Array, rim: int = 2) -> void:
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

static func rbox(im: Image, x: int, y: int, w: int, h: int, r: Array, chamfer: int = 2) -> void:
	if w <= 0 or h <= 0:
		return
	var c: int = mini(chamfer, mini(w / 3, h / 3))
	var lit_t: int = clampi(h / 5, 1, 3)
	var lit_l: int = clampi(w / 5, 1, 3)
	var sh_b: int = clampi(h / 5, 1, 3)
	var sh_r: int = clampi(w / 5, 1, 3)
	for dy in range(h):
		var inset: int = (c - dy) if dy < c else (dy - (h - 1 - c)) if dy >= h - c else 0
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

static func diamond(im: Image, c: Vector2, rx: float, ry: float, col: Color) -> void:
	poly_fill(im, [c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)], col)

static func jagged_ring(im: Image, c: Vector2, r_in: float, r_out: float, segs: int, jag: float, seed_v: float, col: Color, y_squash: float = 1.0) -> void:
	for i in range(segs):
		var a0: float = float(i) * TAU / float(segs)
		var a1: float = float(i + 1) * TAU / float(segs)
		var j0: float = 1.0 + sin(a0 * 5.0 + seed_v) * jag + cos(a0 * 9.0 - seed_v) * (jag * 0.5)
		var j1: float = 1.0 + sin(a1 * 5.0 + seed_v) * jag + cos(a1 * 9.0 - seed_v) * (jag * 0.5)
		var ji0: float = 1.0 + sin(a0 * 4.0 - seed_v) * (jag * 0.6)
		var ji1: float = 1.0 + sin(a1 * 4.0 - seed_v) * (jag * 0.6)
		var d0: Vector2 = Vector2(cos(a0), sin(a0) * y_squash)
		var d1: Vector2 = Vector2(cos(a1), sin(a1) * y_squash)
		poly_fill(im, [c + d0 * (r_in * ji0), c + d0 * (r_out * j0), c + d1 * (r_out * j1), c + d1 * (r_in * ji1)], col)

static func outline_frame(im: Image, passes: int = 2, col: Color = INK) -> Image:
	var w: int = im.get_width()
	var h: int = im.get_height()
	var used: Rect2i = im.get_used_rect()
	if used.size == Vector2i.ZERO:
		return im
	var dst: PackedByteArray = im.get_data()
	var x0: int = maxi(0, used.position.x - passes)
	var y0: int = maxi(0, used.position.y - passes)
	var x1: int = mini(w - 1, used.end.x + passes - 1)
	var y1: int = mini(h - 1, used.end.y + passes - 1)
	var ir: int = col.r8
	var ig: int = col.g8
	var ib: int = col.b8
	for _p in range(passes):
		var src: PackedByteArray = dst.duplicate()
		for y in range(y0, y1 + 1):
			var row_o: int = y * w
			for x in range(x0, x1 + 1):
				var idx: int = (row_o + x) * 4
				if src[idx + 3] > 0:
					continue
				if (x > 0 and src[idx - 1] > 0) or (x < w - 1 and src[idx + 7] > 0) or (y > 0 and src[idx - w * 4 + 3] > 0) or (y < h - 1 and src[idx + w * 4 + 3] > 0):
					dst[idx] = ir
					dst[idx + 1] = ig
					dst[idx + 2] = ib
					dst[idx + 3] = 255
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.set_data(w, h, false, Image.FORMAT_RGBA8, dst)
	return out

static func save_sheet(out: String, name_: String, frames: Array[Image]) -> void:
	var fw: int = frames[0].get_width()
	var fh: int = frames[0].get_height()
	var sheet := Image.create_empty(fw * frames.size(), fh, false, Image.FORMAT_RGBA8)
	for i in range(frames.size()):
		sheet.blit_rect(frames[i], Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	if sheet.save_png(out.path_join(name_ + ".png")) != OK:
		push_error("Cannot save " + name_)
	print("FX SHEET OK: %s.png (%dx%d, %d frames)" % [name_, sheet.get_width(), sheet.get_height(), frames.size()])

# ---- 1. NOX-01 Juggernaut: Ground Slam Shockwave Crater (6x 224x224) -----------------------------
func gen_juggernaut_slam(out: String) -> void:
	var sz: int = 224
	var c := Vector2(sz * 0.5, sz * 0.5)
	var rock: Array = [Color("F2D49B"), Color("C2864B"), Color("6B3D26")]
	var hot: Array = [Color("FFFFE0"), Color("FFC44D"), Color("E06824")]
	var dust: Array = [Color("EFE0C0"), Color("BFA988"), Color("78644D")]
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 5.0
		var r_out: float = lerpf(42.0, 102.0, pow(t, 0.65))
		var thick: float = lerpf(26.0, 11.0, t)
		var r_in: float = maxf(10.0, r_out - thick)
		# Expanding jagged stone-dust shockwave ring
		if col < 5:
			jagged_ring(im, c, r_in, r_out, 24, 0.11, col * 0.7, rock[2])
			jagged_ring(im, c, r_in + 3.0, r_out - 2.0, 24, 0.09, col * 0.7, rock[1])
			jagged_ring(im, c, maxf(r_in + 4.0, r_out - 9.0), r_out - 2.0, 24, 0.08, col * 0.7, hot[1] if col < 3 else dust[0])
		# Blinding core burst on frames 0..1
		if col < 2:
			var cr: float = 34.0 if col == 0 else 22.0
			for i in range(8):
				var a: float = i * TAU / 8.0 + col * 0.3
				var d: Vector2 = Vector2.from_angle(a)
				var s: Vector2 = d.orthogonal()
				poly_fill(im, [c + s * 6.0, c + d * (cr + 18.0), c - s * 6.0], hot[1])
				poly_fill(im, [c + s * 3.0, c + d * (cr + 8.0), c - s * 3.0], hot[0])
		# Radiating jagged seismic ground fissures (8 spokes)
		var crack_len: float = lerpf(48.0, 96.0, minf(1.0, t * 1.4))
		for i in range(8):
			var a: float = i * TAU / 8.0 + 0.18
			var d: Vector2 = Vector2.from_angle(a)
			var s: Vector2 = d.orthogonal()
			var p0: Vector2 = c + d * 12.0
			var p1: Vector2 = c + d * (crack_len * 0.52) + s * (6.0 if i % 2 == 0 else -6.0)
			var p2: Vector2 = c + d * crack_len + s * (-4.0 if i % 2 == 0 else 4.0)
			var w: int = 5 if col < 3 else 3
			pixel_line(im, p0, p1, w + 2, INK)
			pixel_line(im, p1, p2, w, INK)
			if col < 4:
				pixel_line(im, p0, p1, maxi(2, w - 1), hot[1] if col < 2 else hot[2])
				if col < 2:
					pixel_line(im, p0, p1.lerp(p2, 0.5), 2, hot[0])
		# Flying angular boulders & dust blocks bursting outward
		for i in range(10):
			var a: float = i * TAU / 10.0 + 0.4
			var dist: float = lerpf(24.0, 98.0, t) + (i % 3) * 6.0
			var lift: float = sin(t * PI) * (20.0 + (i % 3) * 8.0)
			var bp: Vector2 = c + Vector2.from_angle(a) * dist - Vector2(0, lift)
			var bsz: int = (10 if i % 2 == 0 else 7) if col < 4 else 5
			rbox(im, roundi(bp.x - bsz * 0.5), roundi(bp.y - bsz * 0.5), bsz, bsz, rock if i % 2 == 0 else dust, 2)
		frames.append(outline_frame(im, 2))
	save_sheet(out, "juggernaut_slam", frames)

# ---- 2. NOX-01 Juggernaut: Bull Charge Gust & Debris (4x 160x128) --------------------------------
func gen_juggernaut_charge(out: String) -> void:
	var fw: int = 160
	var fh: int = 128
	var cy: float = fh * 0.5
	var gust: Array = [Color("FFFFE0"), Color("FFD066"), Color("D97636")]
	var dust: Array = [Color("EFE0C0"), Color("BFA988"), Color("6B5642")]
	var frames: Array[Image] = []
	for col in range(4):
		var im := Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
		var shift: float = float(col) * 8.0
		# Leading shock-cone chevron wrapping the charging bull horns (pointing +X)
		var nose_x: float = 142.0 - (col % 2) * 3.0
		var cone_pts: Array = [
			Vector2(nose_x, cy),
			Vector2(nose_x - 36.0, cy - 42.0),
			Vector2(nose_x - 48.0, cy - 36.0),
			Vector2(nose_x - 16.0, cy),
			Vector2(nose_x - 48.0, cy + 36.0),
			Vector2(nose_x - 36.0, cy + 42.0)
		]
		poly_fill(im, cone_pts, gust[2])
		var inner_pts: Array = [
			Vector2(nose_x - 3.0, cy),
			Vector2(nose_x - 34.0, cy - 36.0),
			Vector2(nose_x - 40.0, cy - 32.0),
			Vector2(nose_x - 12.0, cy),
			Vector2(nose_x - 40.0, cy + 32.0),
			Vector2(nose_x - 34.0, cy + 36.0)
		]
		poly_fill(im, inner_pts, gust[1])
		pixel_line(im, Vector2(nose_x - 4.0, cy), Vector2(nose_x - 28.0, cy - 26.0), 3, gust[0])
		pixel_line(im, Vector2(nose_x - 4.0, cy), Vector2(nose_x - 28.0, cy + 26.0), 3, gust[0])
		# Trailing speed streaks & kicking dust cubes behind the boss
		for i in range(4):
			var sy: int = roundi(cy + (i - 1.5) * 24.0)
			var sx: int = roundi(20.0 + fposmod(i * 19.0 - shift, 56.0))
			var slen: int = 34 + (i % 2) * 16
			rect(im, sx, sy - 2, slen, 5, gust[1] if i in [1, 2] else dust[1])
			rect(im, sx + slen - 12, sy - 2, 12, 3, gust[0] if i in [1, 2] else dust[0])
		for d in range(6):
			var dx: int = roundi(14.0 + fposmod(d * 21.0 - shift * 1.4, 72.0))
			var dy: int = roundi(cy + (-34.0 if d % 2 == 0 else 28.0) + (d % 3 - 1) * 7.0)
			var dsz: int = 8 + (d % 2) * 4
			rbox(im, dx, dy, dsz, dsz, dust, 2)
		frames.append(outline_frame(im, 2))
	save_sheet(out, "juggernaut_charge", frames)

# ---- 3. NOX-03 Bio-Cannon: 16-Orb Barrage Muzzle Acid Burst (5x 144x144) -------------------------
func gen_bio_barrage_burst(out: String) -> void:
	var sz: int = 144
	var c := Vector2(sz * 0.5, sz * 0.5)
	var acid: Array = [Color("F4FFAA"), Color("7BF538"), Color("2D7A22")]
	var frames: Array[Image] = []
	for col in range(5):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 4.0
		var r_out: float = lerpf(28.0, 66.0, pow(t, 0.7))
		var r_in: float = maxf(6.0, r_out - lerpf(20.0, 7.0, t))
		if col < 4:
			jagged_ring(im, c, r_in, r_out, 16, 0.16, col * 0.9, acid[2])
			jagged_ring(im, c, r_in + 2.0, r_out - 2.0, 16, 0.13, col * 0.9, acid[1])
		# 16 sharp radiating acid splash needles matching the 16-orb ring!
		for i in range(16):
			var a: float = i * TAU / 16.0
			var d: Vector2 = Vector2.from_angle(a)
			var s: Vector2 = d.orthogonal()
			var p0: Vector2 = c + d * lerpf(14.0, 44.0, t)
			var p1: Vector2 = c + d * (r_out + (10.0 if col < 3 else 4.0))
			if col < 4:
				poly_fill(im, [p0 + s * 3.0, p1, p0 - s * 3.0], acid[1] if i % 2 == 0 else acid[0])
			else:
				var dp: Vector2 = c + d * (52.0 + (i % 2) * 8.0)
				rbox(im, roundi(dp.x - 3), roundi(dp.y - 3), 6, 6, acid, 1)
		if col < 2:
			diamond(im, c, 24.0 - col * 8.0, 24.0 - col * 8.0, acid[0])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "bio_barrage_burst", frames)

# ---- 4. NOX-03 Bio-Cannon: Lobbed Acid Bomb in Flight (4x 56x56) ---------------------------------
func gen_acid_bomb(out: String) -> void:
	var sz: int = 56
	var c := Vector2(30, 28)
	var acid: Array = [Color("F4FFAA"), Color("7BF538"), Color("2A7520")]
	var frames: Array[Image] = []
	for col in range(4):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var pulse: int = [0, 2, 1, -1][col]
		# Organic streaming toxic bomb pointing +X (trailing volatile acid tendrils on -X)
		var tail_y1: float = 20.0 + sin(col * 1.6) * 4.0
		var tail_y2: float = 36.0 - sin(col * 1.6) * 4.0
		poly_fill(im, [Vector2(8, tail_y1), Vector2(28, 17), Vector2(28, 25)], acid[2])
		poly_fill(im, [Vector2(6, 28), Vector2(28, 22), Vector2(28, 34)], acid[1])
		poly_fill(im, [Vector2(10, tail_y2), Vector2(28, 31), Vector2(28, 39)], acid[2])
		# Chunky beveled acid globule head
		var bw: int = 24 + pulse
		var bh: int = 22 - pulse / 2
		rbox(im, roundi(c.x - bw * 0.45), roundi(c.y - bh * 0.5), bw, bh, acid, 5)
		# Blazing white-lime bubbling core
		rbox(im, roundi(c.x - 5), roundi(c.y - 5), 11, 10, [Color("FFFFFF"), acid[0], acid[1]], 3)
		# Detached pixel splash drops trailing behind
		for di in range(3):
			var dx: int = 6 + ((di * 7 + col * 3) % 14)
			var dy: int = 16 + di * 11 + ((col + di) % 2) * 3
			rect(im, dx, dy, 4, 4, acid[0] if di == 1 else acid[1])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "acid_bomb", frames)

# ---- 5. NOX-03 Bio-Cannon: Bubbling Toxic Acid Pool (6x 160x160) ---------------------------------
func gen_acid_pool(out: String) -> void:
	var sz: int = 160
	var c := Vector2(sz * 0.5, sz * 0.5)
	var deep := Color("1D5E1D")
	var mid := Color("4EC92E")
	var bright := Color("94FA48")
	var hi := Color("F4FFAA")
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var ph: float = float(col) * TAU / 6.0
		# Irregular lobed organic toxic puddle (no plain circle!)
		var outer_pts: Array = []
		var mid_pts: Array = []
		var core_pts: Array = []
		var segs: int = 24
		for i in range(segs):
			var a: float = float(i) * TAU / float(segs)
			var wob: float = 1.0 + 0.11 * sin(a * 3.0 + 0.4) + 0.07 * cos(a * 5.0 - 0.8) + 0.03 * sin(a * 2.0 + ph)
			var d: Vector2 = Vector2.from_angle(a)
			outer_pts.append(c + d * (68.0 * wob))
			mid_pts.append(c + d * (58.0 * wob))
			core_pts.append(c + d * (36.0 * (wob + 0.05 * cos(a * 3.0 - ph))))
		poly_fill(im, outer_pts, deep)
		poly_fill(im, mid_pts, mid)
		poly_fill(im, core_pts, bright)
		# Swirling neon acid vein arcs inside the puddle
		for v in range(3):
			var va: float = ph * 0.5 + v * TAU / 3.0
			var p0: Vector2 = c + Vector2.from_angle(va) * 20.0
			var p1: Vector2 = c + Vector2.from_angle(va + 0.6) * 42.0
			var p2: Vector2 = c + Vector2.from_angle(va + 1.1) * 52.0
			pixel_line(im, p0, p1, 4, bright)
			pixel_line(im, p1, p2, 3, hi)
		# Animated rising & popping square pixel acid blisters across the pool!
		var bub_specs: Array = [
			[Vector2(-24, -18), 0], [Vector2(26, -12), 2], [Vector2(-10, 24), 4],
			[Vector2(22, 26), 1], [Vector2(-34, 8), 3], [Vector2(4, -30), 5], [Vector2(0, 4), 2]
		]
		for spec in bub_specs:
			var bp: Vector2 = c + Vector2(spec[0])
			var age: int = (col + int(spec[1])) % 6
			if age <= 2:
				var bs: int = [6, 10, 13][age]
				rbox(im, roundi(bp.x - bs * 0.5), roundi(bp.y - bs * 0.5 - age * 2), bs, bs, [hi, bright, deep], 2)
				rect(im, roundi(bp.x - bs * 0.5 + 2), roundi(bp.y - bs * 0.5 - age * 2 + 2), 3, 2, Color("FFFFFF"))
			elif age == 3:
				# Popping acid ring droplets!
				for da in [0, 1, 2, 3]:
					var dp: Vector2 = bp + Vector2.from_angle(da * PI * 0.5 + 0.4) * 9.0
					rect(im, roundi(dp.x - 2), roundi(dp.y - 2), 4, 4, hi)
		frames.append(outline_frame(im, 2))
	save_sheet(out, "acid_pool", frames)

# ---- 6. NOX-04 Burrower: Subterranean Ambush Eruption (6x 176x176) -------------------------------
func gen_burrow_erupt(out: String) -> void:
	var sz: int = 176
	var c := Vector2(sz * 0.5, sz * 0.5)
	var sand: Array = [Color("F2D59B"), Color("BA884E"), Color("634326")]
	var bone: Array = [Color("FFF5DC"), Color("DEC494"), Color("8C7354")]
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 5.0
		var r_out: float = lerpf(32.0, 78.0, pow(t, 0.65))
		var r_in: float = maxf(8.0, r_out - lerpf(22.0, 10.0, t))
		# Shattered caldera ring
		if col < 5:
			jagged_ring(im, c, r_in, r_out, 20, 0.14, col * 1.1, sand[2])
			jagged_ring(im, c, r_in + 3.0, r_out - 3.0, 20, 0.12, col * 1.1, sand[1])
			jagged_ring(im, c, r_in + 6.0, r_out - 6.0, 20, 0.10, col * 1.1, sand[0])
		# Erupting central earth-and-bone geyser spikes (frames 0..3)
		if col < 4:
			for i in range(6):
				var a: float = i * TAU / 6.0 + 0.25
				var base_p: Vector2 = c + Vector2.from_angle(a) * (14.0 + col * 8.0)
				var h_sp: float = (44.0 if col < 2 else 30.0) * (1.0 - t * 0.35)
				var tilt: float = cos(a) * 14.0
				poly_shaded(im, [base_p + Vector2(-7, 4), base_p + Vector2(tilt, -h_sp), base_p + Vector2(7, 4)], bone if i % 2 == 0 else sand, 2)
		# Flying sandstone clods & bone shards
		for i in range(10):
			var a: float = i * TAU / 10.0 + 0.15
			var dist: float = lerpf(16.0, 76.0, t) + (i % 2) * 8.0
			var lift: float = sin(t * PI) * (30.0 + (i % 3) * 10.0)
			var p: Vector2 = c + Vector2.from_angle(a) * dist - Vector2(0, lift)
			var sz_c: int = 9 if col < 4 else 6
			rbox(im, roundi(p.x - sz_c * 0.5), roundi(p.y - sz_c * 0.5), sz_c, sz_c, sand if i % 3 != 0 else bone, 2)
		frames.append(outline_frame(im, 2))
	save_sheet(out, "burrow_erupt", frames)

# ---- 7. NOX-04 Burrower: Erupting Bone Spine Pillar (6x 56x72) -----------------------------------
func gen_burrower_spine(out: String) -> void:
	var fw: int = 56
	var fh: int = 72
	var bx: float = fw * 0.5
	var by: float = 62.0
	var bone: Array = [Color("FFF5DC"), Color("DEC494"), Color("8C7354")]
	var dirt: Array = [Color("E3BD7C"), Color("9E7242"), Color("543820")]
	var frames: Array[Image] = []
	# 0: ground cracks + tip peeks; 1: shoots halfway up; 2-3: full towering 3-prong bone cluster; 4: cracks/shrinks; 5: crumbling rubble
	var h_scales: Array = [0.28, 0.72, 1.0, 0.96, 0.55, 0.2]
	for col in range(6):
		var im := Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
		var hs: float = float(h_scales[col])
		# Cracked earth base mound
		rbox(im, roundi(bx - 18), roundi(by - 5), 36, 10, dirt, 3)
		if col < 5:
			# Left & right angled flank spikes
			poly_shaded(im, [Vector2(bx - 12, by), Vector2(bx - 21, by - 32.0 * hs), Vector2(bx - 2, by)], bone, 2)
			poly_shaded(im, [Vector2(bx + 2, by), Vector2(bx + 21, by - 30.0 * hs), Vector2(bx + 12, by)], bone, 2)
			# Towering jagged central bone stalagmite
			poly_shaded(im, [Vector2(bx - 9, by + 1), Vector2(bx - 5, by - 26.0 * hs), Vector2(bx, by - 54.0 * hs), Vector2(bx + 6, by - 24.0 * hs), Vector2(bx + 9, by + 1)], bone, 2)
			# Bright ridge glint on peak frames
			if col in [1, 2, 3]:
				pixel_line(im, Vector2(bx - 1, by - 48.0 * hs), Vector2(bx - 2, by - 14.0 * hs), 2, Color("FFFFFF"))
		# Flying dirt chips on burst & crumble frames
		if col in [0, 1, 4, 5]:
			for di in [-16, -7, 8, 17]:
				var dy: int = roundi(by - (14.0 if col in [1, 4] else 6.0) - absf(di) * 0.35)
				rbox(im, roundi(bx + di - 2), dy, 5, 5, bone if col >= 4 else dirt, 1)
		frames.append(outline_frame(im, 2))
	save_sheet(out, "burrower_spine", frames)

# ---- 8. NOX-05 Earthshaker: Volcanic Magma Fissure Pillar (6x 128x128) ---------------------------
func gen_earthshaker_fissure(out: String) -> void:
	var sz: int = 128
	var c := Vector2(sz * 0.5, sz * 0.5 + 10.0)
	var rock: Array = [Color("9CAAB5"), Color("536473"), Color("28323D")]
	var lava: Array = [Color("FFFFD8"), Color("FFAE33"), Color("D94A1E")]
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 5.0
		var r_cr: float = lerpf(24.0, 52.0, pow(t, 0.6))
		# Scorching lava crater ring on ground
		if col < 5:
			jagged_ring(im, c, maxf(8.0, r_cr - 14.0), r_cr, 16, 0.14, col * 0.8, lava[2], 0.72)
			jagged_ring(im, c, maxf(10.0, r_cr - 10.0), r_cr - 3.0, 16, 0.12, col * 0.8, lava[1], 0.72)
		# Violent erupting magma-rock geyser column (peaks on frames 1..2)
		if col < 4:
			var h: float = [46.0, 68.0, 60.0, 36.0][col]
			var w_base: float = [22.0, 26.0, 22.0, 16.0][col]
			# Glowing molten core pillar
			poly_shaded(im, [
				c + Vector2(-w_base, 6), c + Vector2(-w_base * 0.6, -h * 0.65),
				c + Vector2(0, -h), c + Vector2(w_base * 0.6, -h * 0.65), c + Vector2(w_base, 6)
			], lava, 3)
			# Jagged shattered basalt slabs erupting around the molten plume
			for s in [-1.0, 1.0]:
				poly_shaded(im, [
					c + Vector2(s * 12.0, 8), c + Vector2(s * 28.0, -h * 0.52),
					c + Vector2(s * 18.0, -h * 0.62), c + Vector2(s * 4.0, 6)
				], rock, 2)
		# Flying incandescent embers & basalt blocks
		for i in range(8):
			var a: float = i * TAU / 8.0 + 0.35
			var dist: float = lerpf(14.0, 54.0, t)
			var lift: float = sin(t * PI) * 34.0 + (i % 2) * 10.0
			var p: Vector2 = c + Vector2(cos(a) * dist, sin(a) * dist * 0.65 - lift)
			if i % 2 == 0:
				rbox(im, roundi(p.x - 4), roundi(p.y - 4), 8, 8, rock, 2)
			else:
				rect(im, roundi(p.x - 3), roundi(p.y - 3), 6, 6, lava[0] if col < 3 else lava[1])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "earthshaker_fissure", frames)

# ---- 9. NOX-05 Earthshaker: Expanding Tremor Donut Ring (6x 320x320) -----------------------------
func gen_earthshaker_ring(out: String) -> void:
	var sz: int = 320
	var c := Vector2(sz * 0.5, sz * 0.5)
	var rock: Array = [Color("B8C4CC"), Color("637482"), Color("2F3B47")]
	var lava: Array = [Color("FFFFD8"), Color("FFB43B"), Color("E0541B")]
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 5.0
		# Donut ring marching outward from inner safe zone to full radius
		var r_mid: float = lerpf(54.0, 138.0, t)
		var band: float = lerpf(24.0, 14.0, t)
		var r_in: float = maxf(30.0, r_mid - band * 0.5)
		var r_out: float = r_mid + band * 0.5
		# Glowing tectonic lava base band
		jagged_ring(im, c, r_in, r_out, 36, 0.06, col * 0.9, lava[2])
		jagged_ring(im, c, r_in + 3.0, r_out - 3.0, 36, 0.05, col * 0.9, lava[1])
		jagged_ring(im, c, r_mid - 3.0, r_mid + 3.0, 36, 0.04, col * 0.9, lava[0])
		# Upheaving jagged basalt rock teeth marching all around the ring perimeter!
		var teeth: int = 16
		for i in range(teeth):
			var a: float = float(i) * TAU / float(teeth) + col * 0.14
			var d: Vector2 = Vector2.from_angle(a)
			var s: Vector2 = d.orthogonal()
			var p_base: Vector2 = c + d * r_mid
			var h_t: float = (18.0 if i % 2 == 0 else 13.0) * (1.0 - t * 0.28)
			poly_shaded(im, [p_base - s * 7.0, p_base + d * 6.0 - Vector2(0, h_t), p_base + s * 7.0], rock, 2)
			if col < 4 and i % 2 == 0:
				var sp: Vector2 = p_base + d * 10.0 - Vector2(0, h_t * 0.8)
				rect(im, roundi(sp.x - 2), roundi(sp.y - 2), 5, 5, lava[0])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "earthshaker_ring", frames)

# ---- 10. NOX-06 Phantom: Shadow Ambush Triple Frost-Claw Slash (6x 208x208) ----------------------
func gen_phantom_slash(out: String) -> void:
	var sz: int = 208
	var half: float = sz * 0.5
	var frost: Array = [Color("FFFFFF"), Color("78F2FF"), Color("2B77A8")]
	var mist := Color("1D3863")
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 5.0
		var lead_t: float = clampf(0.24 + pow(t, 0.72) * 0.82, 0.24, 1.0)
		var start_a: float = -PI / 3.0
		var end_a: float = PI / 3.0
		var head_a: float = lerpf(start_a, end_a, lead_t)
		var tail_a: float = lerpf(start_a, end_a, maxf(0.0, lead_t - (0.58 if col < 4 else 0.42 if col == 4 else 0.24)))
		# Three parallel razor-sharp frost claw crescents spanning the 120-degree ambush arc!
		if head_a > tail_a + 0.04:
			var radii: Array = [92.0, 74.0, 56.0]
			var widths: Array = [14.0, 10.0, 7.0]
			var steps: int = 16
			for ci in range(3):
				var r_base: float = float(radii[ci])
				var w_max: float = float(widths[ci]) * (1.0 if col < 4 else 0.6 if col == 4 else 0.35)
				var pts_dark: Array = []
				var pts_lit: Array = []
				for s in range(steps + 1):
					var u: float = float(s) / float(steps)
					var a: float = lerpf(tail_a, head_a, u)
					var taper: float = sin(u * PI)
					var r_out: float = r_base - (1.0 - taper) * 4.0
					pts_dark.append(Vector2(half, half) + Vector2.from_angle(a) * r_out)
					pts_lit.append(Vector2(half, half) + Vector2.from_angle(a) * (r_out - 1.0))
				for s in range(steps, -1, -1):
					var u: float = float(s) / float(steps)
					var a: float = lerpf(tail_a, head_a, u)
					var taper: float = sin(u * PI)
					var r_out: float = r_base - (1.0 - taper) * 4.0
					pts_dark.append(Vector2(half, half) + Vector2.from_angle(a) * (r_out - maxf(2.0, w_max * taper)))
					pts_lit.append(Vector2(half, half) + Vector2.from_angle(a) * (r_out - maxf(1.5, w_max * 0.55 * taper)))
				poly_fill(im, pts_dark, mist if ci == 0 else frost[2])
				poly_fill(im, pts_lit, frost[1] if col < 5 else frost[2])
				# White-hot crystalline leading rim on top claw arc
				if ci < 2 and col < 5:
					for s in range(7, steps):
						var a0: float = lerpf(tail_a, head_a, float(s) / float(steps))
						var a1: float = lerpf(tail_a, head_a, float(s + 1) / float(steps))
						pixel_line(im, Vector2(half, half) + Vector2.from_angle(a0) * (r_base - 3.0), Vector2(half, half) + Vector2.from_angle(a1) * (r_base - 3.0), 3 if col < 3 else 2, frost[0])
		# Shattering diamond ice-crystal shards flung along the slash arc
		for si in range(7):
			var sa: float = lerpf(tail_a, head_a, 0.15 + si * 0.13)
			var sr: float = 52.0 + (si % 3) * 20.0 + col * 2.0
			var sp: Vector2 = Vector2(half, half) + Vector2.from_angle(sa) * sr
			var dsz: float = 6.0 if col < 4 else 4.0
			diamond(im, sp, dsz, dsz * 0.65, frost[0] if si % 2 == 0 else frost[1])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "phantom_slash", frames)

# ---- 11. NOX-06 Phantom: Mirage Cross Spectral Dash Streak (5x 128x64) ---------------------------
func gen_phantom_dash(out: String) -> void:
	var fw: int = 128
	var fh: int = 64
	var cy: float = fh * 0.5
	var frost: Array = [Color("FFFFFF"), Color("7AF4FF"), Color("2A74A8")]
	var frames: Array[Image] = []
	for col in range(5):
		var im := Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 4.0
		var thick: float = lerpf(18.0, 5.0, t)
		var x0: float = lerpf(8.0, 34.0, t)
		var x1: float = 120.0
		# Piercing frost-blade dash spearhead + triple spectral ribbon wake
		poly_fill(im, [Vector2(x0, cy - thick * 0.35), Vector2(x1 - 14.0, cy - thick * 0.55), Vector2(x1, cy), Vector2(x1 - 14.0, cy + thick * 0.55), Vector2(x0, cy + thick * 0.35)], frost[2])
		poly_fill(im, [Vector2(x0 + 8.0, cy - thick * 0.2), Vector2(x1 - 16.0, cy - thick * 0.35), Vector2(x1 - 2.0, cy), Vector2(x1 - 16.0, cy + thick * 0.35), Vector2(x0 + 8.0, cy + thick * 0.2)], frost[1])
		pixel_line(im, Vector2(x0 + 12.0, cy), Vector2(x1 - 6.0, cy), maxi(2, roundi(thick * 0.25)), frost[0])
		# Crystalline frost shards peeling off above & below
		for i in range(6):
			var sx: float = lerpf(x0 + 10.0, x1 - 12.0, float(i) / 5.0)
			var sy: float = cy + (-1.0 if i % 2 == 0 else 1.0) * (10.0 + t * 14.0 + (i % 3) * 3.0)
			diamond(im, Vector2(sx, sy), 5.0 - t * 2.0, 3.0, frost[0] if i % 2 == 0 else frost[1])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "phantom_dash", frames)

# ---- 11b. NOX-06 Phantom: Shadow Cloak Vanish Burst (6x 160x160) ---------------------------------
func gen_phantom_cloak(out: String) -> void:
	var sz: int = 160
	var c := Vector2(sz * 0.5, sz * 0.5 + 14.0)
	var frost: Array = [Color("FFFFFF"), Color("78F2FF"), Color("2A74A8")]
	var shadow: Array = [Color("5B4A8A"), Color("2A214A"), Color("18122B")]
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 5.0
		# Ground shadow-frost ring imploding then bursting outward as Phantom vanishes
		var r_out: float = lerpf(26.0, 68.0, pow(t, 0.7))
		var r_in: float = maxf(6.0, r_out - lerpf(18.0, 6.0, t))
		if col < 5:
			jagged_ring(im, c + Vector2(0, 14), r_in, r_out, 20, 0.14, col * 1.1, shadow[1], 0.55)
			jagged_ring(im, c + Vector2(0, 14), r_in + 2.0, r_out - 2.0, 20, 0.11, col * 1.1, frost[2] if col < 4 else shadow[0], 0.55)
		# Dissolving spectral hooded wisp column rising & splitting into shards (frames 0..3)
		if col < 4:
			var h: float = lerpf(78.0, 44.0, t)
			var w: float = lerpf(30.0, 10.0, t)
			var rise: float = t * 26.0
			poly_shaded(im, [
				c + Vector2(-w, 12.0 - rise),
				c + Vector2(-w * 0.7, -h * 0.65 - rise),
				c + Vector2(0.0, -h - rise),
				c + Vector2(w * 0.7, -h * 0.65 - rise),
				c + Vector2(w, 12.0 - rise)
			], shadow, 2)
			poly_fill(im, [
				c + Vector2(-w * 0.45, 4.0 - rise),
				c + Vector2(0.0, -h * 0.85 - rise),
				c + Vector2(w * 0.45, 4.0 - rise)
			], frost[1] if col < 2 else frost[2])
			if col < 2:
				diamond(im, c + Vector2(0, -h * 0.45 - rise), 14.0 - col * 4.0, 20.0 - col * 5.0, frost[0])
		# Swirling spectral diamond wisps & frost sparks dispersing outward and upward
		for i in range(10):
			var a: float = i * TAU / 10.0 + col * 0.35
			var dist: float = lerpf(16.0, 62.0, t) + (i % 2) * 8.0
			var lift: float = 10.0 + t * 54.0 + (i % 3) * 10.0
			var p: Vector2 = c + Vector2(cos(a) * dist, sin(a) * dist * 0.55 - lift)
			var dsz: float = lerpf(8.0, 3.5, t)
			diamond(im, p, dsz, dsz * 0.8, frost[0] if i % 3 == 0 else frost[1] if i % 3 == 1 else shadow[0])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "phantom_cloak", frames)

# ---- 12. NOX-07 Voltspire: Sky-to-Ground Forked Thunderbolt (6x 128x256) -------------------------
func gen_volt_lightning(out: String) -> void:
	var fw: int = 128
	var fh: int = 256
	var cx: float = fw * 0.5
	var hit_y: float = 210.0
	var elec: Array = [Color("FFFFFF"), Color("78F6FF"), Color("2488D6")]
	var scorch := Color("20324A")
	var frames: Array[Image] = []
	for col in range(6):
		var im := Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
		var t: float = float(col) / 5.0
		# Ground electric blast crater & crackling arc ring
		var r_g: float = lerpf(28.0, 56.0, pow(t, 0.7))
		if col < 5:
			jagged_ring(im, Vector2(cx, hit_y), maxf(8.0, r_g - (16.0 if col < 3 else 8.0)), r_g, 20, 0.15, col * 1.4, elec[2] if col < 4 else scorch, 0.65)
			if col < 4:
				jagged_ring(im, Vector2(cx, hit_y), maxf(10.0, r_g - 11.0), r_g - 3.0, 20, 0.12, col * 1.4, elec[1], 0.65)
			if col < 2:
				diamond(im, Vector2(cx, hit_y), 26.0, 17.0, elec[0])
		# Towering jagged forked thunderbolt from sky to hit_y (frames 0..3)
		if col < 4:
			var bolt_w: int = [16, 12, 8, 4][col]
			var core_w: int = [8, 6, 4, 2][col]
			var pts: Array[Vector2] = [Vector2(cx + (col - 1) * 4.0, 6.0)]
			var segs: int = 8
			for s in range(1, segs):
				var u: float = float(s) / float(segs)
				var j: float = sin(col * 2.9 + s * 2.4) * (18.0 if s < segs - 1 else 8.0)
				pts.append(Vector2(cx + j, lerpf(6.0, hit_y, u)))
			pts.append(Vector2(cx, hit_y))
			for s in range(pts.size() - 1):
				pixel_line(im, pts[s], pts[s + 1], bolt_w, elec[2])
			for s in range(pts.size() - 1):
				pixel_line(im, pts[s], pts[s + 1], maxi(2, bolt_w - 4), elec[1])
			for s in range(pts.size() - 1):
				pixel_line(im, pts[s], pts[s + 1], core_w, elec[0])
			# Sharp crackling side fork branches
			for fi in [2, 4, 6]:
				var origin_f: Vector2 = pts[fi]
				var dir_x: float = 1.0 if (fi + col) % 2 == 0 else -1.0
				var mid_f: Vector2 = origin_f + Vector2(dir_x * 20.0, 14.0)
				var tip_f: Vector2 = mid_f + Vector2(dir_x * 16.0, 22.0)
				pixel_line(im, origin_f, mid_f, 4, elec[1])
				pixel_line(im, mid_f, tip_f, 2, elec[0])
		# Crackling rising plasma sparks around impact point
		for sp in range(8):
			var a: float = sp * TAU / 8.0 + col * 0.5
			var dist: float = lerpf(16.0, 52.0, t)
			var lift: float = sin(t * PI) * 28.0 + (sp % 3) * 8.0
			var p: Vector2 = Vector2(cx + cos(a) * dist, hit_y + sin(a) * dist * 0.55 - lift)
			diamond(im, p, 5.0 if col < 4 else 3.0, 5.0 if col < 4 else 3.0, elec[0] if sp % 2 == 0 else elec[1])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "volt_lightning", frames)

# ---- 13. NOX-07 Voltspire: Sweeping Plasma Arc Beam (4x 288x64) ----------------------------------
func gen_volt_beam(out: String) -> void:
	var fw: int = 288
	var fh: int = 64
	var cy: float = fh * 0.5
	var elec: Array = [Color("FFFFFF"), Color("78F6FF"), Color("1E7FD6")]
	var frames: Array[Image] = []
	for col in range(4):
		var im := Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
		var ph: float = float(col) * 1.7
		# Outer plasma sheath (full reach 288px, tapered slightly at muzzle & tip)
		rect(im, 14, roundi(cy - 12), fw - 26, 24, elec[2])
		rect(im, 12, roundi(cy - 7), fw - 22, 14, elec[1])
		rect(im, 10, roundi(cy - 3), fw - 18, 6, elec[0])
		# Pulsing plasma energy nodes travelling down the beam
		for ni in range(7):
			var nx: float = 28.0 + fposmod(ni * 40.0 + col * 14.0, fw - 44.0)
			diamond(im, Vector2(nx, cy), 12.0, 14.0, elec[1])
			diamond(im, Vector2(nx, cy), 6.0, 7.0, elec[0])
		# Two jagged crackling Tesla lightning filaments coiling around the laser core
		for strand in [-1.0, 1.0]:
			var prev := Vector2(14.0, cy)
			var steps: int = 16
			for s in range(1, steps + 1):
				var u: float = float(s) / float(steps)
				var sx: float = lerpf(14.0, float(fw - 12), u)
				var sy: float = cy + sin(ph + s * 1.9 + strand * 1.5) * 18.0 * strand
				var cur := Vector2(sx, sy)
				pixel_line(im, prev, cur, 3, elec[1] if strand > 0 else elec[0])
				prev = cur
		# Blazing muzzle star flare at left origin (x = 16)
		diamond(im, Vector2(18, cy), 14.0, 24.0, elec[1])
		diamond(im, Vector2(18, cy), 8.0, 14.0, elec[0])
		# Sizzling electric spark burst at beam tip (x = fw - 14)
		diamond(im, Vector2(fw - 16, cy), 14.0, 20.0, elec[1])
		diamond(im, Vector2(fw - 16, cy), 7.0, 10.0, elec[0])
		frames.append(outline_frame(im, 2))
	save_sheet(out, "volt_beam", frames)
