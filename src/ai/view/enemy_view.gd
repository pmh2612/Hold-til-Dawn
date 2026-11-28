class_name EnemyView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/ai/view/Main.EnemyView.cs.
# Owner: Vu Duc Viet Anh. How enemies and bosses look on the client: sprite choice, tint, attack and death
# frames, health bars, boss bar.
# Sprite sheets in art/chars/ belong to Mai Thien Ngon; this file only maps enemy state to them.
static var ENEMY_SKIN = ["grunt", "spitter", "wrecker", "wrecker"]
static var ENEMY_TINT = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
# sprite sheet per boss archetype, in GameSim.BOSS_KINDS order (Juggernaut .. Ironhide)
static var BOSS_SKIN = ["boss_juggernaut", "boss_broodmother", "boss_bio_cannon", "boss_burrower", "boss_gatebreaker", "boss_phantom", "boss_ironhide"]
# boss moves with a wind-up: it holds the first attack frame (arms up) until the move lands
static var BOSS_WIND = {"glow": true, "acid_lob": true, "spine_wind": true, "quake_wind": true, "ring_wind": true, "mirage_wind": true, "volt_call": true, "beam_wind": true, "charge_wind": true, "blow": true, "slam": true, "ambush": true}

# Snapshot fields 12/13 carry remaining special time and elapsed time since the slam landed.
# These clips contain the whole boss body, not a separate effect over the idle sprite.
static func boss_skill_animation(e: Array) -> Array:
	if int(e[1]) != GameSim.BOSS:
		return []
	var look: String = Cs.s(e[7])
	var left: float = float(e[12]) if e.size() > 12 else SimBosses.TELEGRAPH
	if int(e[6]) == GameSim.CHAINWARDEN:
		match look:
			"sweep_wind": return ["sweep_wind", maxf(0, SimChainwarden.SWEEP_WIND - left), false]
			"sweep_hit": return ["sweep_hit", maxf(0, SimChainwarden.SWEEP_HIT - left), false]
			"chain_wind": return ["chain_wind", maxf(0, SimChainwarden.HOOK_WIND - left), false]
			"chain_fly", "chain_return": return ["chain_cast", 0.0, true]
			"chain_pull": return ["chain_pull", maxf(0, SimChainwarden.PULL_TIME - left), false]
		return []
	if int(e[6]) != GameSim.JUGGERNAUT:
		return []
	var impact_age: float = float(e[13]) if e.size() > 13 else 99.0
	if impact_age >= 0 and impact_age < SimBosses.SLAM_IMPACT:
		return ["slam_hit", impact_age, false]
	if look == "slam":
		var frac_s: float = clampf((SimBosses.SLAM_WINDUP - left) / maxf(0.01, SimBosses.SLAM_WINDUP), 0.0, 0.999)
		return ["slam_wind", frac_s * 1.5, false]
	if look == "slam_impact":
		return ["slam_hit", maxf(0, SimBosses.SLAM_IMPACT - left), false]
	if look == "charge_wind":
		var frac_c: float = clampf((SimBosses.CHARGE_WINDUP - left) / maxf(0.01, SimBosses.CHARGE_WINDUP), 0.0, 0.999)
		return ["charge_wind", frac_c * 1.0, false]
	if look == "charge":
		return ["charge_run", 0.0, true]
	return []
# a dead enemy plays its "down" frames where it fell, lies there, then fades (seconds)
const CORPSE_TIME: float = 2.4
# a dead enemy plays its "down" frames where it fell, lies there, then fades (seconds)
const CORPSE_FADE: float = 0.6
# 3x replaces 2x: every boss, including attacks and corpses, is 1.5 times its former size.
# This is a world-space scale; boss sheets use 3 texels per logical unit so each
# displayed pixel is the same world size as an Engineer pixel.
const BOSS_DRAW_SCALE: float = 3.0
# what each enemy on screen was last drawn as (by id), so it can fall over where it died
var en_seen = {}
var corpses = []
# bosses holding a wind-up, and when their move landed
var winding = {}
var strike_at = {}
var chain_tips = {}
var sweep_seen = {}
var sweep_fx: Texture2D = null

# constants shared with Main
const GOLD = Main.GOLD
const INK = Main.INK
const NEON_PINK = Main.NEON_PINK
const NEON_RED = Main.NEON_RED
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

# Enemies drawn last frame that are gone from the snapshot died (or the night ended under them): they fall.
func note_fallen(shown) -> void:
	for key_ in Array(en_seen.keys()).duplicate():
		var _d1 = en_seen[key_]
		var id = _d1[0]
		var look = _d1[1]
		if not shown.has(id):
			look.at = float(main.clock)
			corpses.append(look)
			en_seen.erase(key_)

# out of a match: nothing carries over to the next one
func forget_fallen() -> void:
	en_seen.clear()
	corpses.clear()
	winding.clear()
	strike_at.clear()
	chain_tips.clear()
	sweep_seen.clear()
	main.boss_fx_view.cloak_trails.clear()

# depth items [foot y, 12, index] for the corpses still showing
func corpse_items(items) -> void:
	Cs.remove_all(corpses, func(c): return float(main.clock) - c.at > CORPSE_TIME)
	var i: int = 0
	while i < corpses.size():
		# under anyone standing on the same spot
		if main.enemy_visible_at(corpses[i].foot, corpses[i].type):
			items.append([corpses[i].foot.y - 1.0, 12, i])
		i += 1

func draw_corpse(i: int) -> void:
	var c = corpses[i]
	var t: float = float(main.clock) - c.at
	var mod_: Color = c.mod
	mod_.a *= clampf((CORPSE_TIME - t) / CORPSE_FADE, 0.0, 1.0)
	main.player_view.char_(c.key, c.skin, c.foot, null, c.s, mod_, false, "idle", "down", t)

# Ground markers of boss moves (BAL-43): circle (slam, surfacing), line (charge) and arc (ambush).
# The inner fill grows as the hit comes closer.
func draw_telegraphs() -> void:
	for tl in main.snap.get("tele", []):
		var pos: Vector2 = Vector2(tl[0])
		# Only bosses create these warnings; the whole team must see them beyond personal sight.
		var r: float = float(tl[1])
		var left: float = float(tl[2])
		var kind = Cs.s(tl[3]) if tl.size() > 3 else "circle"
		var fx_style: String = Cs.s(tl[8]) if tl.size() > 8 else ""
		var boost: float = 1.0 + main.night_level * 1.5
		if kind == "line":
			var end: Vector2 = Vector2(tl[4])
			var span: Vector2 = end - pos
			var dist: float = maxf(1.0, span.length())
			var dir: Vector2 = span / dist
			var side: Vector2 = dir.orthogonal() * r
			var quad = [pos + side, end + side, end - side, pos - side]
			var k: float = clampf(1.0 - left, 0.0, 1.0)
			if fx_style == "jugg_charge":
				var pulse: float = 0.72 + 0.28 * sin(float(main.clock) * 18.0)
				var jugg_boost: float = 1.0 + main.night_level * 0.9
				main.draw_colored_polygon(quad, Color(0.95 * jugg_boost, 0.22, 0.14, 0.16 + 0.08 * k))
				var mid_j: Vector2 = pos.lerp(end, k)
				main.draw_colored_polygon([pos + side, mid_j + side, mid_j - side, pos - side], Color(1.25 * jugg_boost, 0.42 * jugg_boost, 0.16, 0.28 + 0.16 * k))
				# Animated forward chevrons scrolling along the rush lane to communicate direction and exact width.
				var spacing: float = 42.0
				var shift: float = fmod(float(main.clock) * 140.0, spacing)
				var d_along: float = shift
				var chev_col: Color = Color(1.45 * jugg_boost, 0.85 * jugg_boost, 0.3, (0.55 + 0.35 * k) * pulse)
				while d_along < dist - 14.0:
					var tip_c: Vector2 = pos + dir * (d_along + 14.0)
					var back_c: Vector2 = pos + dir * d_along
					main.draw_polyline([back_c + side * 0.62, tip_c, back_c - side * 0.62], chev_col, 2.6)
					d_along += spacing
				# Outer dark ink rail + bright crimson-amber outline + leading surge bar.
				main.draw_polyline([pos + side, end + side, end - side, pos - side, pos + side], INK, 4.4)
				main.draw_polyline([pos + side, end + side, end - side, pos - side, pos + side], Color(1.45 * jugg_boost, 0.48 * jugg_boost, 0.22, 0.92 * pulse), 2.4)
				main.draw_line(mid_j + side, mid_j - side, Color(1.55 * jugg_boost, 1.1 * jugg_boost, 0.42, 0.95), 3.0)
				continue
			var fill_col: Color = Color(0.85, 0.65, 0.3, 0.2) if fx_style == "spine" else Color(1.3 * boost, 0.58 * boost, 0.14, 0.2) if fx_style == "quake" else Color(1.0, 0.1, 0.3, 0.18)
			var grow_col: Color = Color(0.95, 0.78, 0.42, 0.36) if fx_style == "spine" else Color(1.6 * boost, 0.82 * boost, 0.22, 0.36) if fx_style == "quake" else Color(1.0, 0.15, 0.3, 0.3)
			var edge_col: Color = Color(0.98, 0.85, 0.55, 0.9) if fx_style == "spine" else Color(1.75 * boost, 1.05 * boost, 0.3, 0.95) if fx_style == "quake" else NEON_RED
			main.draw_colored_polygon(quad, fill_col)
			var mid: Vector2 = pos.lerp(end, k)
			main.draw_colored_polygon([pos + side, mid + side, mid - side, pos - side], grow_col)
			main.draw_polyline([pos + side, end + side, end - side, pos - side, pos + side], edge_col, 2.2)
			continue
		if kind == "arc":
			var ang: float = float(tl[5])
			var half: float = float(tl[6]) / 2
			var arc_fill: Color = Color(0.4, 1.35 * boost, 1.85 * boost, 0.2) if fx_style == "phantom" else Color(1.0, 0.1, 0.3, 0.18)
			var arc_grow: Color = Color(0.55, 1.75 * boost, 2.2 * boost, 0.38) if fx_style == "phantom" else Color(1.0, 0.15, 0.3, 0.35)
			var arc_edge: Color = Color(0.75, 2.0 * boost, 2.4 * boost, 0.95) if fx_style == "phantom" else NEON_RED
			main.draw_colored_polygon(arc_fan(pos, r, ang, half), arc_fill)
			main.draw_colored_polygon(arc_fan(pos, r * (1.0 - left), ang, half), arc_grow)
			main.draw_arc(pos, r, ang - half, ang + half, 24, arc_edge, 3)
			continue
		if fx_style == "ring":
			var inner_r: float = float(tl[9]) if tl.size() > 9 else 2.0 * T
			var k: float = 1.0 - left
			main.draw_arc(pos, r, 0, TAU, 48, Color(1.6 * boost, 0.85 * boost, 0.22, 0.65), 2.5)
			main.draw_arc(pos, inner_r, 0, TAU, 36, Color(1.8 * boost, 1.15 * boost, 0.35, 0.95), 3.0)
			main.draw_arc(pos, inner_r + 12.0 * k, 0, TAU, 36, Color(1.65 * boost, 0.78 * boost, 0.2, 0.45 * k), 8.0)
			continue
		if fx_style == "jugg_slam":
			var k_s: float = clampf(1.0 - left, 0.0, 1.0)
			var pulse_s: float = 0.74 + 0.26 * sin(float(main.clock) * (14.0 + 18.0 * k_s))
			var jugg_boost_s: float = 1.0 + main.night_level * 0.9
			# Outer blast zone + expanding shock ring that meets the rim on impact.
			main.draw_circle(pos, r, Color(0.95 * jugg_boost_s, 0.22, 0.14, 0.15 + 0.08 * k_s))
			main.draw_circle(pos, r * k_s, Color(1.28 * jugg_boost_s, 0.42 * jugg_boost_s, 0.16, 0.26 + 0.16 * k_s))
			main.draw_arc(pos, r, 0, TAU, 48, INK, 5.2)
			main.draw_arc(pos, r, 0, TAU, 48, Color(1.45 * jugg_boost_s, 0.45 * jugg_boost_s, 0.2, 0.95 * pulse_s), 3.0)
			main.draw_arc(pos, maxf(4.0, r * k_s), 0, TAU, 40, Color(1.55 * jugg_boost_s, 1.08 * jugg_boost_s, 0.38, 0.92), 2.6)
			# 8 rotating radial hazard ticks converging inward along the slam perimeter.
			var spin: float = float(main.clock) * 1.15
			var tick_in: float = r * (0.86 - 0.14 * k_s)
			for ti in range(8):
				var ta: float = spin + float(ti) * (TAU / 8.0)
				var td: Vector2 = Vector2.from_angle(ta)
				main.draw_line(pos + td * tick_in, pos + td * (r - 2.0), Color(1.5 * jugg_boost_s, 0.88 * jugg_boost_s, 0.32, 0.85 * pulse_s), 2.4)
			continue
		if tl.size() > 7 and tl[7] != null:
			# Bio-Cannon targeted acid lob: readable green target zone + arcing acid bomb in flight.
			var progress: float = clampf(1.0 - left, 0.0, 1.0)
			var acid_boost: float = 1.0 + main.night_level * 0.55
			main.draw_circle(pos, r, Color(0.28, 0.78 * acid_boost, 0.22, 0.14))
			main.draw_circle(pos, r * progress, Color(0.38, 0.96 * acid_boost, 0.26, 0.24))
			main.draw_arc(pos, r, 0, TAU, 36, Color(0.45, 1.15 * acid_boost, 0.30, 0.85), 2.6)
			var from: Vector2 = Vector2(tl[7])
			var ground_at: Vector2 = from.lerp(pos, progress)
			var arc_lift: float = sin(progress * PI)
			var arc_h: float = 22.0 * (1.0 - progress) + 74.0 * arc_lift
			var glob_at: Vector2 = ground_at - Vector2(0, arc_h)
			main.shadow(ground_at, 11.0 * (1.0 - 0.3 * arc_lift))
			# Dotted trajectory trail behind the lobbed acid bomb.
			for di in range(5):
				var dt_u: float = maxf(0.0, progress - (di + 1) * 0.045)
				var dp: Vector2 = from.lerp(pos, dt_u) - Vector2(0, 22.0 * (1.0 - dt_u) + 74.0 * sin(dt_u * PI))
				var sz: float = maxf(2.5, 7.5 - di * 1.1)
				main.draw_rect(Rect2((dp - Vector2.ONE * (sz * 0.5)).round(), Vector2(sz, sz)), Color(0.42, 1.15 * acid_boost, 0.28, 0.78 - di * 0.14))
			var prev_u: float = maxf(0.0, progress - 0.02)
			var prev_pt: Vector2 = from.lerp(pos, prev_u) - Vector2(0, 22.0 * (1.0 - prev_u) + 74.0 * sin(prev_u * PI))
			var flight_ang: float = (glob_at - prev_pt).angle() if glob_at.distance_squared_to(prev_pt) > 0.5 else (pos - from).angle()
			var bomb_scale: float = 1.05 + 0.25 * arc_lift
			var bomb_idx: int = int(floor(float(main.clock) * 14.0)) % 4
			var bomb_mod: Color = Color(0.82 + main.night_level * 0.18, 0.95 * acid_boost, 0.64 + main.night_level * 0.12)
			if not main.boss_fx_view.draw_sheet_frame("acid_bomb", 4, bomb_idx, glob_at, flight_ang, Vector2(bomb_scale, bomb_scale), bomb_mod):
				main.inventory.draw_fx("orb", glob_at, flight_ang, 2.3 + 0.55 * arc_lift, bomb_mod)
			continue
		main.draw_circle(pos, r, Color(1.0, 0.1, 0.3, 0.16))
		main.draw_circle(pos, r * (1.0 - left), Color(1.0, 0.15, 0.3, 0.35))
		main.draw_arc(pos, r, 0, TAU, 48, NEON_RED, 3)

func draw_acid_pools() -> void:
	var now: float = float(main.clock)
	for pool in main.snap.get("acid_pools", []):
		var spot: Vector2 = Vector2(pool[0])
		var r: float = float(pool[1])
		var left: float = float(pool[2])
		var dur: float = maxf(0.1, float(pool[3]))
		var fade_in: float = clampf((dur - left) / 0.2, 0.0, 1.0)
		var fade_out: float = clampf(left / 0.8, 0.0, 1.0)
		var alpha: float = fade_in * fade_out
		var scale_r: float = r * (0.45 + 0.55 * ease(fade_in, 0.45))
		var seed_v: float = spot.x * 0.031 + spot.y * 0.017
		var f_idx: int = int(floor(now * 8.0 + seed_v)) % 6
		var sc: float = scale_r / 68.0
		var boost: float = 1.0 + main.night_level * 0.5
		var pool_mod := Color(0.80 + main.night_level * 0.15, 0.94 * boost, 0.66 + main.night_level * 0.12, 0.88 * alpha)
		if main.boss_fx_view.draw_sheet_frame("acid_pool", 6, f_idx, spot, fmod(seed_v, TAU), Vector2(sc, sc), pool_mod):
			continue
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var core := PackedVector2Array()
		var segs: int = 24
		for i in range(segs):
			var a: float = float(i) * TAU / float(segs)
			var wobble: float = 1.0 + 0.09 * sin(a * 3.0 + seed_v) + 0.06 * cos(a * 5.0 - seed_v * 1.3) + 0.03 * sin(a * 2.0 + now * 2.4)
			var dir: Vector2 = Vector2.from_angle(a)
			outer.append(spot + dir * (scale_r * wobble))
			inner.append(spot + dir * (scale_r * 0.84 * wobble))
			core.append(spot + dir * (scale_r * 0.52 * (wobble + 0.04 * cos(a * 3.0 - now * 3.0))))
		main.draw_colored_polygon(outer, Color(0.14, 0.52 * boost, 0.18, 0.65 * alpha))
		main.draw_colored_polygon(inner, Color(0.28, 0.82 * boost, 0.24, 0.62 * alpha))
		main.draw_colored_polygon(core, Color(0.50, 1.05 * boost, 0.34, 0.48 * alpha))

func sweep_texture() -> Texture2D:
	if sweep_fx == null and ResourceLoader.exists("res://art/fx/chainwarden_sweep.png"):
		sweep_fx = load("res://art/fx/chainwarden_sweep.png")
	return sweep_fx

func draw_chainwarden_sweep_at(foot: Vector2, face: float, elapsed: float) -> void:
	var tex: Texture2D = sweep_texture()
	if tex == null:
		return
	var frames: int = 6
	var frame_w: float = float(tex.get_width()) / float(frames)
	var frame_h: float = float(tex.get_height())
	var idx: int = clampi(int(floor(elapsed / SimChainwarden.SWEEP_HIT * float(frames))), 0, frames - 1)
	var origin: Vector2 = foot - Vector2(0, 34)
	main.draw_set_transform(origin, face, Vector2.ONE)
	main.draw_texture_rect_region(tex, Rect2(-Vector2(frame_w, frame_h) * 0.5, Vector2(frame_w, frame_h)), Rect2(idx * frame_w, 0.0, frame_w, frame_h), Color.WHITE)
	main.draw_set_transform(Vector2.ZERO)

func draw_chainwarden_sweeps() -> void:
	var active_ids := {}
	for e in main.snap.get("en", []):
		if int(e[1]) != GameSim.BOSS or int(e[6]) != GameSim.CHAINWARDEN:
			continue
		var look: String = Cs.s(e[7]) if e.size() > 7 else ""
		if look != "sweep_hit":
			continue
		var id: int = int(e[0])
		active_ids[id] = true
		var foot: Vector2 = Vector2(main.shown_e.get(id, e[2]))
		if not main.enemy_visible_at(foot, int(e[1])):
			continue
		var left: float = float(e[12]) if e.size() > 12 else 0.0
		var snap_elapsed: float = clampf(SimChainwarden.SWEEP_HIT - left, 0.0, SimChainwarden.SWEEP_HIT)
		if not sweep_seen.has(id):
			sweep_seen[id] = float(main.clock) - snap_elapsed
		var elapsed: float = clampf(float(main.clock) - float(sweep_seen[id]), 0.0, SimChainwarden.SWEEP_HIT - 0.001)
		draw_chainwarden_sweep_at(foot, float(e[8]), elapsed)
	for id in sweep_seen.keys():
		if not active_ids.has(id):
			sweep_seen.erase(id)

func draw_chains() -> void:
	var live_ids := {}
	for chain in main.snap.get("chains", []):
		var boss_id: int = int(chain[3]) if chain.size() > 3 else -1
		var act: String = Cs.s(chain[4]) if chain.size() > 4 else ""
		var target_id: int = int(chain[2]) if chain.size() > 2 else -1
		var boss_pos: Vector2 = Vector2(main.shown_e.get(boss_id, chain[0])) if boss_id >= 0 else Vector2(chain[0])
		var raw_tip: Vector2 = Vector2(chain[1])
		# Keep pulled targets locked directly onto their smoothly rendered position (zero 20Hz lag).
		var tip_pos: Vector2 = raw_tip
		if target_id >= 0:
			if target_id == main.my_id:
				tip_pos = Vector2(main.local_pos)
			elif main.shown_p.has(target_id):
				tip_pos = Vector2(main.shown_p[target_id])
		elif boss_id >= 0:
			if main.sim != null:
				for sim_e in main.sim.enemies:
					if int(sim_e.id) == boss_id:
						raw_tip = Vector2(sim_e.get("chain_tip", raw_tip))
						if sim_e.act == "chain_return":
							raw_tip = Vector2(sim_e.pos).lerp(raw_tip, clampf(float(sim_e.act_t) / 0.2, 0.0, 1.0))
						break
			var prev_tip: Vector2 = Vector2(chain_tips.get(boss_id, raw_tip))
			tip_pos = prev_tip.lerp(raw_tip, minf(1.0, maxf(0.25, float(main.get_process_delta_time()) * 28.0)))
			chain_tips[boss_id] = tip_pos
			live_ids[boss_id] = true
		var aim_dir: Vector2 = (tip_pos - boss_pos).normalized() if tip_pos.distance_squared_to(boss_pos) > 1.0 else Vector2.from_angle(float(chain[5]) if chain.size() > 5 else 0.0)
		var start: Vector2 = boss_pos - Vector2(0, 44) + aim_dir * 20.0
		var end: Vector2 = tip_pos - Vector2(0, 18)
		var span: Vector2 = end - start
		var length: float = span.length()
		if length < 2.0:
			continue
		var direction: Vector2 = span / length
		var side: Vector2 = direction.orthogonal()
		var sag: float = 0.0 if target_id >= 0 else (4.0 if act == "chain_fly" else 8.0)
		var links: int = mini(64, maxi(2, ceili(length / 7.5)))
		for i in range(links):
			var u: float = (i + 0.5) / float(links)
			var at: Vector2 = start.lerp(end, u) + Vector2(0, sin(u * PI) * sag)
			var half: float = 2.4 if i % 2 == 0 else 1.1
			var link := PackedVector2Array([at - direction * 3.4, at + side * half, at + direction * 3.4, at - side * half, at - direction * 3.4])
			main.draw_polyline(link, Color("17212C"), 3.2)
			main.draw_polyline(link, Color("DCE6E9") if i % 2 == 0 else Color("8DA7B6"), 1.3)
		# Heavy barbed iron-gold hook head at the chain tip.
		var hook_pts := PackedVector2Array([end - direction * 8.0, end + direction * 5.0, end + side * 7.0 + direction * 1.0, end + side * 6.0 - direction * 6.0])
		main.draw_polyline(hook_pts, Color("17212C"), 4.6)
		main.draw_polyline(hook_pts, Color("FFD579"), 2.4)
		if target_id >= 0:
			# Subtle taut-latch gleam around the hooked target.
			main.draw_circle(end, 4.5, Color(1.0, 0.88, 0.5, 0.55))
	for id in chain_tips.keys():
		if not live_ids.has(id):
			chain_tips.erase(id)

static func arc_fan(c: Vector2, r: float, ang: float, half: float) -> Variant:
	var pts = Cs.arr(18, Vector2.ZERO)
	pts[0] = c
	for i in range(17):
		pts[i + 1] = c + Vector2.from_angle(ang - half + 2 * half * i / 16.0) * maxf(r, 1.0)
	return pts

func draw_enemy(e, foot) -> void:
	var ty: int = int(e[1])
	var look = Cs.s(e[7]) if e.size() > 7 else ""
	# each boss archetype has its own sheet (art/chars/boss_*.png from tools/PixelBosses.cs)
	var skin = BOSS_SKIN[int(e[6])] if ty == GameSim.BOSS else ENEMY_SKIN[ty]
	var key_ = "e%d" % [e[0]]
	if look == "cloak":
		en_seen.erase(key_)
		# Invisible while cloaked; BossFxView renders its glowing movement trail, plus a close-range shimmer ring.
		if main.local_pos.distance_to(foot) < 2.5 * T:
			var cl_boost: float = 1.0 + main.night_level * 0.85
			main.draw_arc(foot - Vector2(0, 16), e[5] * 0.8, 0, TAU, 24, Color(0.55, 1.15 * cl_boost, 1.45 * cl_boost, 0.28), 2)
		return
	if look == "burrow" or look == "surface":
		# Churning subterranean earth mound proportional to Burrower's body footprint & eruption crater.
		en_seen.erase(key_)
		var now_b: float = float(main.clock)
		var r_b: float = float(e[5])
		var rumble := Vector2(sin(now_b * 34.0) * 2.0, cos(now_b * 29.0) * 1.4)
		var base_c: Vector2 = Vector2(foot) + rumble
		main.shadow(base_c + Vector2(0, 4), r_b * 1.35)
		var outer := PackedVector2Array()
		var mid := PackedVector2Array()
		var segs: int = 16
		for i in range(segs):
			var a: float = float(i) * TAU / float(segs)
			var jag: float = 1.0 + 0.14 * sin(a * 5.0 + now_b * 10.0) + 0.08 * cos(a * 3.0 - now_b * 7.0)
			outer.append(base_c + Vector2(cos(a) * r_b * 1.25 * jag, sin(a) * r_b * 0.78 * jag))
			mid.append(base_c + Vector2(cos(a) * r_b * 0.88 * jag, sin(a) * r_b * 0.54 * jag - 5.0))
		main.draw_colored_polygon(outer, INK)
		var outer_in := PackedVector2Array()
		for pt in outer:
			outer_in.append(base_c.lerp(pt, 0.91))
		main.draw_colored_polygon(outer_in, Color("634326"))
		main.draw_colored_polygon(mid, Color("BA884E"))
		# Churning pixel clods & pale bone-crest glint breaking the dirt crest
		for ci in range(6):
			var ca: float = float(ci) * TAU / 6.0 + now_b * 4.5
			var cr: float = r_b * (0.45 + 0.45 * fposmod(now_b * 2.2 + ci * 0.37, 1.0))
			var lift_c: float = sin(fposmod(now_b * 2.2 + ci * 0.37, 1.0) * PI) * 14.0
			var cp: Vector2 = base_c + Vector2(cos(ca) * cr, sin(ca) * cr * 0.58 - lift_c)
			var csz: float = 7.0 if ci % 2 == 0 else 5.0
			main.draw_rect(Rect2((cp - Vector2.ONE * (csz * 0.5 + 1.0)).round(), Vector2.ONE * (csz + 2.0)), INK)
			main.draw_rect(Rect2((cp - Vector2.ONE * (csz * 0.5)).round(), Vector2.ONE * csz), Color("F2D59B") if ci % 2 == 0 else Color("DEC494"))
		return
	# the character's own size (the sheet cell has room around it for its attack)
	var art = main.cinfo.chars[skin]
	var size: float = float(art.get("body", art.size)) / float(art.get("resolution", 1.0))
	# GDD size in tiles over the sprite's own size: the 40 px Wrecker is drawn 1:1. A boss is drawn much bigger
	# than its body (BOSS_DRAW_SCALE), so it towers over the players but still fits through a door.
	var s: float = BOSS_DRAW_SCALE if ty == GameSim.BOSS else float(e[5] / (0.5 * T) * 32.0 / size)
	var mod_: Color = ENEMY_TINT[ty]
	if ty == GameSim.BOSS:
		mod_ = Color.WHITE
		# wind-ups glow; recovery, stagger and climb-out (the weak windows) look dim
		if look == "glow" or look == "acid_lob":
			mod_ = mod_.lerp(Color(0.75, 1.32, 0.62), 0.4 + 0.4 * sin(main.clock * 18.0))
		elif look in ["volt_call", "beam_wind", "beam_sweep"]:
			mod_ = mod_.lerp(Color(0.62, 1.12, 1.38), 0.4 + 0.4 * sin(main.clock * 22.0))
		elif look in ["mirage_wind", "mirage_dash"]:
			mod_ = mod_.lerp(Color(0.75, 1.85, 2.3), 0.5 + 0.5 * sin(main.clock * 18.0))
		elif look in ["quake_wind", "ring_wind"]:
			mod_ = mod_.lerp(Color(2.4, 1.45, 0.45), 0.5 + 0.5 * sin(main.clock * 18.0))
		elif look in ["spine_wind", "charge_wind", "blow", "slam", "ambush"]:
			mod_ = mod_.lerp(Color(2.2, 1.6, 0.6), 0.5 + 0.5 * sin(main.clock * 18.0))
		elif look in ["recover", "stagger", "climb", "exposed"]:
			mod_ = mod_.darkened(0.35)
		elif look == "shown":
			mod_ = mod_.lerp(Color(0.8, 0.7, 1.0), 0.4)
	# Bosses need extra contrast beyond personal light; ordinary enemies keep their usual night tint.
	if main.snap.get("ph", "") == "night":
		mod_ *= 2.2 if ty == GameSim.BOSS else 1.5
		mod_.a = 1.0
	en_seen[key_] = [e[0], Cs.init(Fallen.new(), {"key": key_, "skin": skin, "s": s, "mod": ENEMY_TINT[ty], "foot": Vector2(foot), "type": ty})]
	if main.flash.has(e[0]):
		mod_ = Color(2.0, 2.0, 2.0)
	# attack frames: on each hit or spit (snapshot field 9); a boss holds the wind-up frame through its
	# wind-up and strikes when the move lands
	var play = null
	var play_t: float = 0.0
	var loop: bool = false
	var now: float = float(main.clock)
	var start: float = main.anim.swing_start(key_, e.size() > 9 and e[9])
	if ty == GameSim.BOSS and BOSS_WIND.has(look):
		Cs.set_add(winding, key_)
		play = "attack"
	else:
		if winding.erase(key_):
			# straight to the slam (frame 1 of 4 at 10 frames/s)
			strike_at[key_] = now - 0.1
		var sa = strike_at.get(key_, 0.0)
		var from: float = maxf(start, sa if strike_at.has(key_) else -1.0)
		if from >= 0 and now - from < main.anim.anim_length(skin, "attack"):
			play = "attack"
			play_t = now - from
	var skill: Array = boss_skill_animation(e)
	if not skill.is_empty():
		play = skill[0]
		play_t = skill[1]
		loop = skill[2]
		winding.erase(key_)
		strike_at.erase(key_)
	main.player_view.char_(key_, skin, foot, float(e[8]) if ty == GameSim.BOSS else null, s, mod_, play == "attack" or not skill.is_empty(), play if not skill.is_empty() else "idle", play, play_t, loop)
	if main.snap.get("rooted", {}).has(e[0]):
		main.tactical_items.draw_vine_root(e, Vector2(foot), size * s)
	if e.size() > 10 and e[10]:
		var at: Vector2 = Vector2(foot) - Vector2(0, size * s * 0.65)
		main.draw_arc(at, 9.0, 0, TAU, 12, Color("DDD681"), 2.0)
		for i in range(3):
			main.draw_circle(at + Vector2.from_angle(i * TAU / 3 + float(main.clock) * 3) * 9.0, 2.0, Color("FFF3B4"))
	if e.size() > 11 and e[11]:
		main.draw_arc(Vector2(foot), float(e[5]), 0, TAU, 20, Color("83DDD8"), 3.0)
	if e[3] < e[4] and ty != GameSim.BOSS:
		main.bar(foot - Vector2(0, size * 0.7 * s + 4), e[5] * 2.2, e[3] / e[4], NEON_RED)

# --- HUD drawing (screen space) -----------------------------------------
# Night: how many of the night's enemies are down, under the generator panel. It fills as they die; full (and
# the three supplies in) means dawn comes (src/ai/sim_night_spawns.gd).
const NIGHT_BAR_H: float = 30.0

func draw_night_bar(c, cx: float) -> void:
	if main.snap.get("ph", "") != "night":
		return
	var nq = main.snap.get("nq", null)
	if nq == null or int(nq[1]) <= 0:
		return
	var down: int = int(nq[0])
	var all: int = int(nq[1])
	var frac: float = clampf(float(down) / all, 0.0, 1.0)
	var box_ = Rect2(cx - 160, 56, 320, NIGHT_BAR_H - 4)
	var cw = c
	main.panel(cw, box_)
	main.text(cw, Vector2(cx - 150, 70), "NIGHT %d" % [main.snap.k], 11, GOLD, 0, -1.0, true)
	var bar_ = Rect2(cx - 90, 64, 240, 7)
	c.draw_rect(bar_.grow(1), INK)
	c.draw_rect(bar_, Color(0.22, 0.24, 0.3))
	# red while the night still has enemies, green once the last one is down
	var fill: Color = Color("3DBE5A") if frac >= 1.0 else NEON_RED.lerp(Color("F2B544"), frac)
	c.draw_rect(Rect2(bar_.position, Vector2(bar_.size.x * frac, bar_.size.y)), fill)

func draw_boss_bar(c, cx) -> void:
	for e in main.snap.en:
		if e[1] == GameSim.BOSS:
			# below the night bar
			var dy: float = NIGHT_BAR_H if main.snap.get("ph", "") == "night" else 0.0
			var br = Rect2(cx - 230, 66 + dy, 460, 10)
			main.text(c, Vector2(cx - 230, 62 + dy), SimBosses.boss_title(e[6]).to_upper(), 12, NEON_PINK, 1, 460, true)
			c.draw_rect(br.grow(2), INK)
			c.draw_rect(Rect2(br.position, Vector2(br.size.x * e[3] / e[4], br.size.y)), NEON_PINK)
			for x in [br.position.x - 6, br.end.x + 6]:
				main.diamond(c, Vector2(x, br.get_center().y), 8, NEON_PINK)

class Fallen:
	var type: int = -1
	var key
	var skin
	var s: float = 0.0
	var at: float = 0.0
	var mod: Color = Color(0, 0, 0, 0)
	var foot: Vector2 = Vector2.ZERO
