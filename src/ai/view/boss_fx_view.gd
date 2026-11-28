class_name BossFxView
extends RefCounted

# Client-side animated pixel-art world effects (from art/fx/*.png) for all bosses.
# Bright HDR night modulation preserves readability in darkness while keeping crisp pixel ink.
const T = Main.T
const INK = Main.INK

var main: Main
var fx_cache: Dictionary = {}
var cloak_trails: Dictionary = {}

func _init(host: Main) -> void:
	main = host

func fx_tex(name_: String) -> Texture2D:
	if fx_cache.has(name_):
		return fx_cache[name_]
	var path: String = "res://art/fx/%s.png" % name_
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	fx_cache[name_] = tex
	return tex

func draw_sheet_frame(name_: String, frames: int, idx: int, at: Vector2, angle: float = 0.0, scale_v: Vector2 = Vector2.ONE, mod_: Color = Color.WHITE, anchor_norm: Vector2 = Vector2(0.5, 0.5)) -> bool:
	var tex: Texture2D = fx_tex(name_)
	if tex == null:
		return false
	var fw: float = float(tex.get_width()) / float(frames)
	var fh: float = float(tex.get_height())
	var f: int = clampi(idx, 0, frames - 1)
	main.draw_set_transform(at, angle, scale_v)
	main.draw_texture_rect_region(tex, Rect2(-Vector2(fw * anchor_norm.x, fh * anchor_norm.y), Vector2(fw, fh)), Rect2(f * fw, 0.0, fw, fh), mod_)
	main.draw_set_transform(Vector2.ZERO)
	return true

func hdr_mod(tint: Color, alpha: float = 1.0, night_boost: float = 1.45) -> Color:
	var m: float = 1.0 + main.night_level * night_boost
	return Color(tint.r * m, tint.g * m, tint.b * m, alpha)

func draw_ground_fx() -> void:
	var boost: float = 1.0 + main.night_level * 1.6
	draw_phantom_cloak_trails()
	for fx in main.snap.get("boss_fx", []):
		var kind: String = Cs.s(fx[0])
		if kind == "jugg_slam":
			draw_jugg_slam(Vector2(fx[1]), float(fx[2]), float(fx[3]))
		elif kind == "spine_wave":
			draw_spine_wave(Vector2(fx[1]), float(fx[2]), float(fx[3]), float(fx[4]), boost)
		elif kind == "quake_fissure":
			draw_quake_fissure(Vector2(fx[1]), float(fx[2]), float(fx[3]), float(fx[4]), int(fx[5]), boost)
		elif kind == "tremor_ring":
			draw_tremor_ring(Vector2(fx[1]), float(fx[2]), float(fx[3]), float(fx[4]), float(fx[5]))
		elif kind == "burrow_pop":
			draw_burrow_pop(Vector2(fx[1]), float(fx[2]), float(fx[3]))
		elif kind == "lightning_bolt":
			draw_lightning_ground(Vector2(fx[1]), float(fx[2]), float(fx[3]), float(fx[4]), float(fx[5]), boost)
		elif kind == "mirage_cross":
			draw_mirage_ground(Cs.s(fx[1]), float(fx[2]), float(fx[3]), fx[4], boost)

func draw_air_fx() -> void:
	var boost: float = 1.0 + main.night_level * 1.75
	draw_jugg_charge_fx()
	for fx in main.snap.get("boss_fx", []):
		var kind: String = Cs.s(fx[0])
		if kind == "bio_barrage":
			draw_bio_barrage(Vector2(fx[1]), float(fx[2]), float(fx[3]))
		elif kind == "mirage_cross":
			draw_mirage_clones(Cs.s(fx[1]), float(fx[2]), float(fx[3]), fx[4], boost)
		elif kind == "phantom_slash":
			draw_phantom_slash(Vector2(fx[1]), float(fx[2]), float(fx[3]), float(fx[4]))
		elif kind == "phantom_cloak":
			draw_phantom_cloak(Vector2(fx[1]), float(fx[2]), float(fx[3]))
		elif kind == "lightning_bolt":
			draw_lightning_air(Vector2(fx[1]), float(fx[2]), float(fx[3]), float(fx[4]), float(fx[5]))
		elif kind == "arc_beam":
			draw_arc_beam(Cs.s(fx[1]), Vector2(fx[2]), float(fx[3]), float(fx[4]), float(fx[5]), float(fx[6]), float(fx[7]), boost)

# --- NOX-01 Juggernaut --------------------------------------------------
func draw_jugg_slam(spot: Vector2, t: float, dur: float) -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	var idx: int = clampi(int(floor(k * 6.0)), 0, 5)
	var alpha: float = clampf((1.0 - k) / 0.25, 0.0, 1.0) if k > 0.75 else 1.0
	draw_sheet_frame("juggernaut_slam", 6, idx, spot, 0.0, Vector2.ONE * 1.05, hdr_mod(Color(1.08, 1.02, 0.92), alpha, 1.25))

func draw_jugg_charge_fx() -> void:
	var f_idx: int = int(floor(float(main.clock) * 14.0)) % 4
	for e in main.snap.get("en", []):
		if int(e[1]) != GameSim.BOSS or int(e[6]) != GameSim.JUGGERNAUT:
			continue
		if Cs.s(e[7]) != "charge":
			continue
		var foot: Vector2 = Vector2(main.shown_e.get(int(e[0]), e[2]))
		if not main.enemy_visible_at(foot, int(e[1])):
			continue
		var face: float = float(e[8])
		var at: Vector2 = foot - Vector2(0, 26.0) + Vector2.from_angle(face) * 10.0
		draw_sheet_frame("juggernaut_charge", 4, f_idx, at, face, Vector2.ONE * 1.1, hdr_mod(Color(1.08, 1.0, 0.9), 0.96, 1.3))

# --- NOX-03 Bio-Cannon --------------------------------------------------
func draw_bio_barrage(spot: Vector2, t: float, dur: float) -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	var idx: int = clampi(int(floor(k * 5.0)), 0, 4)
	var alpha: float = clampf((1.0 - k) / 0.28, 0.0, 1.0) if k > 0.72 else 1.0
	draw_sheet_frame("bio_barrage_burst", 5, idx, spot - Vector2(0, 32.0), 0.0, Vector2.ONE * 1.25, hdr_mod(Color(0.78, 0.96, 0.68), alpha, 0.65))

# --- NOX-04 Burrower ----------------------------------------------------
func draw_spine_wave(origin: Vector2, base_ang: float, t: float, dur: float, boost: float) -> void:
	var wave_frac: float = clampf(t / SimBossSkills.SPINE_WAVE_TIME, 0.0, 1.0)
	var fade: float = clampf((dur - t) / 0.28, 0.0, 1.0)
	var reach: float = wave_frac * SimBossSkills.SPINE_RANGE
	var mod_c: Color = hdr_mod(Color(1.05, 1.0, 0.9), fade, 1.15)
	for off in [-SimBossSkills.SPINE_SPREAD, 0.0, SimBossSkills.SPINE_SPREAD]:
		var dir: Vector2 = Vector2.from_angle(base_ang + off)
		var tip: Vector2 = origin + dir * reach
		main.draw_line(origin, tip, Color(0.22, 0.15, 0.1, 0.85 * fade), 7.0)
		main.draw_line(origin, tip, Color(0.85 * boost, 0.65 * boost, 0.36, 0.5 * fade), 2.5)
		var count: int = 6
		for s in range(count):
			var dist: float = (s + 1) * (SimBossSkills.SPINE_RANGE / float(count))
			if dist > reach + 10.0:
				continue
			var appear_t: float = (dist / SimBossSkills.SPINE_RANGE) * SimBossSkills.SPINE_WAVE_TIME
			var age: float = maxf(0.0, t - appear_t)
			var life: float = maxf(0.15, dur - appear_t)
			var idx: int = clampi(int(floor(age / life * 6.0)), 0, 5)
			var at: Vector2 = origin + dir * dist
			var sc: float = 0.88 + 0.24 * (float(s) / float(count - 1))
			draw_sheet_frame("burrower_spine", 6, idx, at, 0.0, Vector2(sc, sc), mod_c, Vector2(0.5, 0.86))

func draw_burrow_pop(spot: Vector2, t: float, dur: float) -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	var idx: int = clampi(int(floor(k * 6.0)), 0, 5)
	var alpha: float = clampf((1.0 - k) / 0.22, 0.0, 1.0) if k > 0.78 else 1.0
	draw_sheet_frame("burrow_erupt", 6, idx, spot, 0.0, Vector2.ONE * 0.96, hdr_mod(Color(1.05, 1.0, 0.9), alpha, 1.15), Vector2(0.5, 0.56))

# --- NOX-05 Earthshaker -------------------------------------------------
func draw_quake_fissure(origin: Vector2, ang: float, t: float, dur: float, fired: int, boost: float) -> void:
	var dir: Vector2 = Vector2.from_angle(ang)
	var fade: float = clampf((dur - t) / 0.35, 0.0, 1.0)
	var max_len: float = float(fired) * SimBossSkills.QUAKE_STEP_DIST
	if max_len > 1.0:
		main.draw_line(origin, origin + dir * max_len, Color(0.24, 0.12, 0.07, 0.88 * fade), 10.0)
		main.draw_line(origin, origin + dir * max_len, Color(1.4 * boost, 0.72 * boost, 0.2, 0.8 * fade), 3.5)
	for idx in range(fired):
		var age: float = t - idx * SimBossSkills.QUAKE_BLAST_GAP
		if age < 0.0 or age > 0.55:
			continue
		var k: float = clampf(age / 0.55, 0.0, 1.0)
		var f_idx: int = clampi(int(floor(k * 6.0)), 0, 5)
		var b_fade: float = clampf((1.0 - k) / 0.25, 0.0, 1.0) if k > 0.75 else 1.0
		var spot: Vector2 = origin + dir * ((idx + 1) * SimBossSkills.QUAKE_STEP_DIST)
		draw_sheet_frame("earthshaker_fissure", 6, f_idx, spot, 0.0, Vector2.ONE * 1.05, hdr_mod(Color(1.15, 0.98, 0.85), b_fade, 1.5), Vector2(0.5, 0.58))

func draw_tremor_ring(origin: Vector2, t: float, dur: float, min_r: float, max_r: float) -> void:
	var progress: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	var fade: float = minf(1.0, progress / 0.08) * clampf((1.0 - progress) / 0.18, 0.0, 1.0)
	var cur_r: float = lerpf(min_r, max_r, progress)
	var f_idx: int = clampi(int(floor(progress * 6.0)), 0, 5)
	# Match the sprite's authored ring radius (54..138 px across 6 frames) to the exact simulation radius!
	var sprite_r: float = lerpf(54.0, 138.0, float(f_idx) / 5.0)
	var sc: float = cur_r / maxf(1.0, sprite_r)
	draw_sheet_frame("earthshaker_ring", 6, f_idx, origin, 0.0, Vector2(sc, sc), hdr_mod(Color(1.18, 0.98, 0.82), fade, 1.55))

# --- NOX-06 Phantom -----------------------------------------------------
func draw_mirage_ground(phase: String, t: float, dur: float, lines: Array, boost: float) -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	if phase == "wind":
		var alpha: float = 0.35 + 0.55 * k
		for pair in lines:
			var a: Vector2 = Vector2(pair[0])
			var b: Vector2 = Vector2(pair[1])
			var d: Vector2 = (b - a).normalized() if b.distance_squared_to(a) > 1.0 else Vector2.RIGHT
			var side: Vector2 = d.orthogonal() * (0.45 * T)
			main.draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), Color(0.35, 1.15 * boost, 1.65 * boost, 0.16 * alpha))
			main.draw_line(a, b, Color(0.65, 1.8 * boost, 2.2 * boost, 0.85 * alpha), 2.5)
		return
	var f_idx: int = clampi(int(floor(k * 3.0)), 0, 2) if phase == "dash" else clampi(3 + int(floor(k * 2.0)), 3, 4)
	var alpha_d: float = 1.0 if phase == "dash" else clampf(1.0 - k, 0.0, 1.0)
	for pair in lines:
		var a: Vector2 = Vector2(pair[0])
		var b: Vector2 = Vector2(pair[1])
		var tip: Vector2 = a.lerp(b, 1.0 if phase == "fade" else k)
		var span: Vector2 = tip - a
		var dist: float = span.length()
		if dist < 6.0:
			continue
		var sc_x: float = dist / 112.0
		draw_sheet_frame("phantom_dash", 5, f_idx, a.lerp(tip, 0.5) - Vector2(0, 18.0), span.angle(), Vector2(sc_x, 1.05), hdr_mod(Color(0.85, 1.15, 1.3), alpha_d, 1.6))

func draw_mirage_clones(phase: String, t: float, dur: float, lines: Array, boost: float) -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	var alpha: float = (0.45 + 0.35 * sin(k * PI * 3.0) * 0.25 + 0.25 * k) if phase == "wind" else (1.0 - k) * 0.7 if phase == "fade" else 0.85
	var clone_mod := Color(0.62 * boost, 1.55 * boost, 2.05 * boost, clampf(alpha, 0.0, 0.9))
	for i in range(1, lines.size()):
		var a: Vector2 = Vector2(lines[i][0])
		var b: Vector2 = Vector2(lines[i][1])
		var ang: float = (b - a).angle()
		var pos: Vector2 = a if phase == "wind" else b if phase == "fade" else a.lerp(b, k)
		var play_anim = "attack" if phase != "wind" else null
		main.player_view.char_("mirage_%d" % i, "boss_phantom", pos, ang, EnemyView.BOSS_DRAW_SCALE, clone_mod, true, "mirage", play_anim, 0.15 if phase == "dash" else 0.0)

func draw_phantom_slash(origin: Vector2, ang: float, t: float, dur: float) -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	var idx: int = clampi(int(floor(k * 6.0)), 0, 5)
	var alpha: float = clampf((1.0 - k) / 0.22, 0.0, 1.0) if k > 0.78 else 1.0
	draw_sheet_frame("phantom_slash", 6, idx, origin - Vector2(0, 20.0), ang, Vector2.ONE * 1.05, hdr_mod(Color(0.88, 1.15, 1.3), alpha, 1.65))

func draw_phantom_cloak(spot: Vector2, t: float, dur: float) -> void:
	var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
	var idx: int = clampi(int(floor(k * 6.0)), 0, 5)
	var alpha: float = clampf((1.0 - k) / 0.25, 0.0, 1.0) if k > 0.75 else 1.0
	draw_sheet_frame("phantom_cloak", 6, idx, spot - Vector2(0, 22.0), 0.0, Vector2.ONE * 1.1, hdr_mod(Color(0.76, 1.02, 1.2), alpha, 0.95))

func draw_phantom_cloak_trails() -> void:
	var now: float = float(main.clock)
	var trail_life: float = 0.65
	var active_cloaked := {}
	for e in main.snap.get("en", []):
		if int(e[1]) != GameSim.BOSS or int(e[6]) != GameSim.PHANTOM:
			continue
		if Cs.s(e[7]) != "cloak":
			continue
		var id: int = int(e[0])
		active_cloaked[id] = true
		var foot: Vector2 = Vector2(main.shown_e.get(id, e[2]))
		var pts: Array = cloak_trails.get(id, [])
		if pts.is_empty() or Vector2(pts[-1][0]).distance_to(foot) >= 6.0:
			pts.append([foot, now])
			if pts.size() > 28:
				pts.pop_front()
		cloak_trails[id] = pts
	var c_boost: float = 1.0 + main.night_level * 0.75
	for id in Array(cloak_trails.keys()):
		var pts: Array = cloak_trails[id]
		var kept: Array = []
		for item in pts:
			if now - float(item[1]) <= trail_life:
				kept.append(item)
		if kept.is_empty():
			if not active_cloaked.has(id):
				cloak_trails.erase(id)
			continue
		cloak_trails[id] = kept
		# Glowing icy spectral streaks connecting Phantom's cloaked movement path.
		for i in range(1, kept.size()):
			var a: Vector2 = Vector2(kept[i - 1][0]) - Vector2(0, 14.0)
			var b: Vector2 = Vector2(kept[i][0]) - Vector2(0, 14.0)
			var age: float = now - float(kept[i][1])
			var fade: float = clampf(1.0 - age / trail_life, 0.0, 1.0)
			var w_outer: float = 10.0 * fade
			var w_core: float = 4.0 * fade
			main.draw_line(a, b, Color(0.26, 0.85 * c_boost, 1.28 * c_boost, 0.34 * fade), w_outer)
			main.draw_line(a, b, Color(0.72, 1.25 * c_boost, 1.48 * c_boost, 0.78 * fade), w_core)
			# Scattered glowing spectral diamond motes peeling off the moving trail.
			var side: Vector2 = (b - a).normalized().orthogonal() if b.distance_squared_to(a) > 0.5 else Vector2.UP
			var drift: float = (1.0 - fade) * 10.0 * (1.0 if i % 2 == 0 else -1.0)
			var mp: Vector2 = a.lerp(b, 0.5) + side * drift - Vector2(0, (1.0 - fade) * 8.0)
			var sz: float = maxf(2.0, 5.5 * fade)
			main.draw_rect(Rect2((mp - Vector2.ONE * (sz * 0.5)).round(), Vector2(sz, sz)), Color(0.8, 1.32 * c_boost, 1.52 * c_boost, 0.82 * fade))
		# Soft ghostly foot pulse at the leading edge while still cloaked.
		if active_cloaked.has(id):
			var head: Vector2 = Vector2(kept[-1][0])
			var pulse: float = 0.65 + 0.35 * sin(now * 16.0)
			main.draw_circle(head - Vector2(0, 10.0), 10.0 * pulse, Color(0.35, 0.95 * c_boost, 1.38 * c_boost, 0.25))
			main.draw_circle(head - Vector2(0, 10.0), 4.5, Color(0.85, 1.35 * c_boost, 1.55 * c_boost, 0.62 * pulse))

# --- NOX-07 Voltspire ---------------------------------------------------
func draw_lightning_ground(spot: Vector2, r: float, t: float, warn: float, _dur: float, _boost: float) -> void:
	if t >= warn:
		return
	var k: float = clampf(t / maxf(0.01, warn), 0.0, 1.0)
	var volt_boost: float = 1.0 + main.night_level * 0.55
	main.draw_circle(spot, r, Color(0.22, 0.72 * volt_boost, 1.08 * volt_boost, 0.14))
	main.draw_circle(spot, r * k, Color(0.32, 0.92 * volt_boost, 1.25 * volt_boost, 0.22))
	main.draw_arc(spot, r, 0, TAU, 32, Color(0.42, 1.08 * volt_boost, 1.38 * volt_boost, 0.85), 2.4)
	var pulse: float = 6.0 + 6.0 * sin(t * 28.0)
	main.draw_line(spot - Vector2(pulse, 0), spot + Vector2(pulse, 0), Color(0.55, 1.15 * volt_boost, 1.42 * volt_boost, 0.78), 1.8)
	main.draw_line(spot - Vector2(0, pulse), spot + Vector2(0, pulse), Color(0.55, 1.15 * volt_boost, 1.42 * volt_boost, 0.78), 1.8)

func draw_lightning_air(spot: Vector2, r: float, t: float, warn: float, dur: float) -> void:
	if t < warn:
		return
	var k: float = clampf((t - warn) / maxf(0.01, dur - warn), 0.0, 1.0)
	var idx: int = clampi(int(floor(k * 6.0)), 0, 5)
	var alpha: float = clampf((1.0 - k) / 0.25, 0.0, 1.0) if k > 0.75 else 1.0
	var sc_x: float = maxf(1.0, r / 54.0)
	draw_sheet_frame("volt_lightning", 6, idx, spot, 0.0, Vector2(sc_x, 1.12), hdr_mod(Color(0.72, 0.94, 1.06), alpha, 0.65), Vector2(0.5, 210.0 / 256.0))

func draw_arc_beam(phase: String, origin: Vector2, ang: float, end_ang: float, reach: float, t: float, dur: float, _boost: float) -> void:
	var start: Vector2 = origin - Vector2(0, 42.0)
	var dir: Vector2 = Vector2.from_angle(ang)
	var tip: Vector2 = start + dir * reach
	if phase == "wind":
		var k: float = clampf(t / maxf(0.01, dur), 0.0, 1.0)
		var pulse: float = 0.55 + 0.45 * sin(t * 24.0)
		var volt_boost: float = 1.0 + main.night_level * 0.55
		main.draw_line(start, tip, Color(0.32, 0.95 * volt_boost, 1.32 * volt_boost, (0.3 + 0.45 * k) * pulse), 2.2 + 1.3 * k)
		var sweep_r: float = minf(reach, 4.5 * T)
		main.draw_arc(start, sweep_r, minf(ang, end_ang), maxf(ang, end_ang), 20, Color(0.32, 0.92 * volt_boost, 1.28 * volt_boost, 0.42 * k), 1.8)
		main.draw_circle(start, 6.5 + 4.5 * k, Color(0.48, 1.08 * volt_boost, 1.38 * volt_boost, 0.55 * k))
		return
	var fade: float = (1.0 - clampf(t / maxf(0.01, dur), 0.0, 1.0)) if phase == "fade" else 1.0
	var f_idx: int = int(floor(float(main.clock) * 16.0)) % 4
	# Authored beam span is 254px (from muzzle x=18 to tip x=272 inside 288x64 cell).
	var sc_x: float = maxf(0.15, reach / 254.0)
	var sc_y: float = 0.9 + 0.15 * fade
	draw_sheet_frame("volt_beam", 4, f_idx, start, ang, Vector2(sc_x, sc_y), hdr_mod(Color(0.74, 0.95, 1.06), fade, 0.65), Vector2(18.0 / 288.0, 0.5))
