class_name TacticalItemsView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/gameplay/view/Main.TacticalItems.cs.
# Owner: Pham Minh Hieu. How the tactical items look in use:
#   flasks   - fly from the thrower in an arc, then splash and leave their pulsing area
#   vine trap - sprouts out of the ground, then waits with its vines curling
#   blast    - the explosive arrow's burst: a flash, a ring and flying sparks
#   haste    - streaks behind a hasted runner and sparks round their feet
# Compact weapons are baked into the character PNGs; cyan attack trails show melee reach.
# when this client first saw each tactical area (by kind and spot), for its opening animation
var area_seen = {}
# active client-side vine-snap bursts when a trap triggers on an enemy: [{pos, at}]
var trap_snaps: Array = []
# cached active healing area positions this frame so player_view can show per-character heal particles
var active_heal_spots: Array = []
# seconds a thrown flask flies before it splashes
const FLASK_FLIGHT: float = 0.3
const TRAP_SNAP_DURATION: float = 0.55

# constants shared with Main
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

func draw_tactical_areas() -> void:
	var now: float = float(main.clock)
	var live = {}
	active_heal_spots.clear()
	for a_ in main.snap.get("tactical", []):
		var kind = Cs.s(a_[0])
		var at: Vector2 = Vector2(a_[1])
		var key_ = [kind, at]
		Cs.set_add(live, key_)
		var seen = area_seen.get(key_, 0.0)
		if not area_seen.has(key_):
			seen = now
			area_seen[key_] = seen
		var age: float = maxf(0.0, now - seen)
		if kind == "trap":
			draw_trap(at, age)
			continue
		var tint_: Color = Color("6CE4BA" if kind == "heal" else "A1C64A" if kind == "poison" else "FF9B45")
		if kind == "blast":
			draw_blast(at, age, tint_)
			continue
		# a flask: in the air first (only for one thrown just now: an old area seen late has no flight)
		var left: float = float(a_[2])
		var fresh: bool = left > 5.0 - FLASK_FLIGHT - 0.1
		if fresh and age < FLASK_FLIGHT:
			var from: Vector2 = thrower_pos(a_[3] if a_.size() > 3 else null, at)
			draw_flask_flight(from, at, age / FLASK_FLIGHT, kind)
			continue
		var open: float = clampf((age - FLASK_FLIGHT) / 0.3, 0.0, 1.0) if fresh else 1.0
		var fade: float = clampf(left / 0.6, 0.0, 1.0)
		var r: float = 1.8 * T * ease(open, 0.38)
		if kind == "heal":
			active_heal_spots.append(at)
			draw_heal_zone(at, r, open, fade, fresh, now)
		else:
			draw_poison_zone(at, r, open, fade, fresh, now, tint_)
	# forget areas that are gone; when a vine trap disappears, trigger its snapping animation
	if area_seen.size() > live.size():
		var gone = []
		for k in area_seen.keys():
			if not live.has(k):
				gone.append(k)
		for k in gone:
			area_seen.erase(k)
			if Cs.s(k[0]) == "trap":
				trap_snaps.append({"pos": Vector2(k[1]), "at": now})
	# draw any active vine-trap snap bursts
	var keep_snaps: Array = []
	for snap_fx in trap_snaps:
		var snap_age: float = now - float(snap_fx.at)
		if snap_age >= 0.0 and snap_age < TRAP_SNAP_DURATION:
			draw_trap_snap(Vector2(snap_fx.pos), snap_age / TRAP_SNAP_DURATION)
			keep_snaps.append(snap_fx)
	trap_snaps = keep_snaps

func draw_heal_zone(at: Vector2, r: float, open: float, fade: float, fresh: bool, now: float) -> void:
	var mint := Color("6CE4BA")
	var bright := Color("D8FFF0")
	var pulse_phase: float = fposmod(now * 2.0, 1.0) # 0.5s pulse matching the +4 HP healing tick
	var breath: float = 0.88 + 0.12 * sin(now * 4.5)
	# Two-layer soft glow fill (outer mist + warmer luminous core)
	main.draw_circle(at, r, Color(mint, 0.14 * fade * breath))
	main.draw_circle(at, r * 0.56, Color(bright, 0.10 * fade * breath))
	# Expanding healing pulse ring every 0.5s
	var wave_r: float = r * (0.22 + 0.78 * ease(pulse_phase, 0.55))
	main.draw_arc(at, wave_r, 0.0, TAU, 32, Color(bright, (1.0 - pulse_phase) * 0.55 * fade), 2.0)
	# Outer rim + two counter-rotating luminous arcs
	main.draw_arc(at, r, 0.0, TAU, 36, Color(mint, 0.78 * fade), 2.0)
	var arc_a: float = now * 1.35
	main.draw_arc(at, r + 1.5, arc_a, arc_a + 1.25, 14, Color(bright, 0.85 * fade), 2.2)
	main.draw_arc(at, r + 1.5, arc_a + PI, arc_a + PI + 1.25, 14, Color(bright, 0.85 * fade), 2.2)
	var inner_a: float = -now * 1.1
	main.draw_arc(at, r * 0.74, inner_a, inner_a + 0.9, 10, Color(mint, 0.45 * fade), 1.5)
	main.draw_arc(at, r * 0.74, inner_a + PI, inner_a + PI + 0.9, 10, Color(mint, 0.45 * fade), 1.5)
	# Splash burst right after flask impact: centre flash, double shockwave, and 12 glass/mist droplets
	if fresh and open < 1.0:
		var inv_open: float = 1.0 - open
		main.draw_circle(at, r * (0.28 + 0.45 * open), Color(bright, 0.38 * inv_open))
		main.draw_arc(at, r * (0.35 + 0.8 * open), 0.0, TAU, 28, Color(bright, 0.85 * inv_open), 2.6)
		for i in range(12):
			var d: Vector2 = Vector2.from_angle(i * TAU / 12.0 + 0.25)
			var dist: float = 8.0 + (28.0 + float(i % 3) * 8.0) * open
			var p: Vector2 = at + d * dist - Vector2(0.0, (14.0 + float(i % 2) * 5.0) * sin(open * PI))
			var sz: float = 3.0 if i % 3 == 0 else 2.0
			main.draw_rect(Rect2((p - Vector2.ONE * (sz * 0.5)).round(), Vector2(sz, sz)), Color(bright if i % 2 == 0 else mint, inv_open))
	# 8 rising healing crosses (+) of varying sizes floating smoothly upward
	for i in range(8):
		var life: float = fposmod(now * 0.72 + float(i) * 0.125, 1.0)
		var ang: float = float(i) * TAU / 8.0 + now * 0.35
		var rad: float = r * (0.28 + 0.52 * (0.5 + 0.5 * sin(float(i) * 2.1 + 0.4)))
		var p: Vector2 = at + Vector2.from_angle(ang) * rad + Vector2(sin(now * 3.0 + i) * 2.0, -life * 20.0)
		var alpha: float = sin(life * PI) * fade
		var arm: float = 3.5 if i % 2 == 0 else 2.5
		var col: Color = Color(bright if i % 3 == 0 else mint, alpha * 0.95)
		main.draw_line(p - Vector2.RIGHT * arm, p + Vector2.RIGHT * arm, col, 2.0)
		main.draw_line(p - Vector2.DOWN * arm, p + Vector2.DOWN * arm, col, 2.0)
	# 6 rising spiral sparkles
	for i in range(6):
		var life: float = fposmod(now * 1.05 + float(i) / 6.0 + 0.3, 1.0)
		var ang: float = float(i) * TAU / 6.0 - now * 1.1 + life * 1.4
		var p: Vector2 = at + Vector2.from_angle(ang) * (r * (0.88 - 0.35 * life)) - Vector2(0.0, life * 16.0)
		main.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(bright, sin(life * PI) * 0.85 * fade))

func draw_poison_zone(at: Vector2, r: float, open: float, fade: float, fresh: bool, now: float, tint_: Color) -> void:
	main.draw_circle(at, r, Color(tint_, 0.13 * fade))
	main.draw_arc(at, r, 0, TAU, 32, Color(tint_, 0.8 * fade), 2.0)
	if fresh and open < 1.0:
		for i in range(8):
			var d: Vector2 = Vector2.from_angle(i * TAU / 8 + 0.3)
			var p: Vector2 = at + d * (6 + 26 * open) - Vector2(0, 10 * sin(open * PI))
			main.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(tint_.lightened(0.3), 1 - open))
	for i in range(5):
		var p: Vector2 = at + Vector2.from_angle(i * TAU / 5 + now * 0.25) * (r * 0.55)
		p.y -= 3.0 + 3.0 * sin(now * 3 + i)
		main.draw_rect(Rect2(p.round(), Vector2(3, 3)), Color(tint_, fade))

func thrower_pos(owner, fallback: Vector2) -> Vector2:
	if owner == null:
		return fallback
	if owner == main.my_id:
		return Vector2(main.local_pos)
	var p = main.snap.ps.get(owner, null)
	return fallback if p == null else Vector2(main.shown_p.get(owner, p[2]))

# a flask tumbling along a throw arc, with a luminous trail and soft landing marker
func draw_flask_flight(from: Vector2, to: Vector2, k: float, kind) -> void:
	var tint_: Color = Color("6CE4BA" if kind == "heal" else "A1C64A")
	var bright: Color = Color("D8FFF0" if kind == "heal" else "DDF29C")
	# Faint target landing ring growing as the flask descends
	main.draw_arc(to, 10.0 + 10.0 * k, 0.0, TAU, 20, Color(tint_, 0.25 + 0.35 * k), 1.5)
	# Arc trail sparkles behind the tumbling bottle
	for i in range(1, 6):
		var tk: float = k - float(i) * 0.055
		if tk < 0.0:
			continue
		var tg: Vector2 = from.lerp(to, tk)
		var th: float = 18.0 + 36.0 * sin(tk * PI)
		var tp: Vector2 = tg - Vector2(0.0, th)
		var sz: float = maxf(1.5, 4.0 - float(i) * 0.5)
		var al: float = (1.0 - float(i) / 6.0) * 0.8
		main.draw_rect(Rect2((tp - Vector2.ONE * (sz * 0.5)).round(), Vector2(sz, sz)), Color(bright if i <= 2 else tint_, al))
	var ground_: Vector2 = from.lerp(to, k)
	var height: float = 18.0 + 36.0 * sin(k * PI)
	main.shadow(ground_, 4.5 - 1.5 * sin(k * PI))
	var at: Vector2 = ground_ - Vector2(0.0, height)
	main.draw_set_transform(at, k * 10.5, Vector2.ONE * (1.0 + 0.12 * sin(k * PI)))
	main.inventory.draw_item_icon(main, "healing_flask" if kind == "heal" else "poison_flask", Vector2.ZERO, 1.0)
	main.draw_set_transform(Vector2.ZERO)

# a vine trap sprouting from broken soil, then waiting with breathing, curling thorny vines
func draw_trap(at: Vector2, age: float) -> void:
	var now: float = float(main.clock)
	var grow: float = clampf(age / 0.4, 0.0, 1.0)
	var s: float = ease(grow, 0.35) * (1.0 + 0.28 * sin(grow * PI))
	var breath: float = 1.0 + 0.06 * sin(now * 3.8 + at.x * 0.05)
	var green := Color("98BE56")
	var dark_vine := Color("3B6B29")
	var lit_vine := Color("7FB842")
	var thorn := Color("D9E88F")
	# Subtle disturbed earth patch underneath so the trap reads clearly on grass
	main.draw_circle(at + Vector2(0.0, 2.0), 15.0 * s, Color("3D3222", 0.34))
	main.draw_circle(at, 17.5 * s * breath, Color(green, 0.12))
	main.draw_arc(at, 17.5 * s * breath, 0.0, TAU, 20, Color(green, 0.72 + 0.2 * sin(now * 4.5)), 2.0)
	# 6 multi-segment curling vines with leaf tips swaying independently
	for i in range(6):
		var base_a: float = float(i) * TAU / 6.0 + now * 0.42
		var sway: float = sin(now * 4.2 + float(i) * 1.7)
		var root: Vector2 = at + Vector2.from_angle(base_a) * (10.5 * s)
		var mid: Vector2 = root + Vector2.from_angle(base_a + 0.45 * sway) * (5.5 * s) + Vector2(0.0, -4.5 * s)
		var tip: Vector2 = mid + Vector2.from_angle(base_a + 1.15 + 0.55 * sway) * (5.0 * s) + Vector2(0.0, -4.0 * s + sway * 1.8)
		main.draw_polyline(PackedVector2Array([root, mid, tip]), dark_vine, 3.0)
		main.draw_polyline(PackedVector2Array([root, mid, tip]), lit_vine, 1.4)
		# Small leaf bud / thorn glint at the curling tip
		main.draw_rect(Rect2((tip - Vector2.ONE).round(), Vector2(2.5, 2.5)), thorn)
	if s > 0.05:
		var bob: float = sin(now * 3.8 + at.y * 0.05) * 1.1 if grow >= 1.0 else 0.0
		main.draw_set_transform(at + Vector2(0.0, bob), sin(now * 2.4) * 0.06, Vector2.ONE * s * (0.98 + 0.04 * breath))
		main.inventory.draw_item_icon(main, "vine_trap", Vector2.ZERO, 1.0)
		main.draw_set_transform(Vector2.ZERO)
	if grow < 1.0:
		# Burst of soil clods, leaf flecks and an expanding ground ring as the trap erupts
		var inv_g: float = 1.0 - grow
		main.draw_arc(at, 10.0 + 18.0 * grow, 0.0, TAU, 18, Color(thorn, 0.75 * inv_g), 2.0)
		for i in range(10):
			var d: Vector2 = Vector2.from_angle(float(i) * TAU / 10.0 + 0.3)
			var p: Vector2 = at + d * (6.0 + (16.0 + float(i % 3) * 5.0) * grow) - Vector2(0.0, (11.0 + float(i % 2) * 4.0) * sin(grow * PI))
			var col: Color = Color("7A6046", inv_g) if i % 3 != 0 else Color(lit_vine, inv_g)
			main.draw_rect(Rect2(p.round(), Vector2(2.5, 2.5)), col)

# explosive vine-lashing burst when a trap triggers and snares an enemy
func draw_trap_snap(at: Vector2, k: float) -> void:
	var inv_k: float = 1.0 - k
	var dark_vine := Color("3B6B29", inv_k)
	var lit_vine := Color("88C946", inv_k)
	var thorn := Color("E4F59C", inv_k)
	main.draw_circle(at, 20.0 * (0.4 + 0.6 * k), Color(lit_vine.r, lit_vine.g, lit_vine.b, 0.25 * inv_k))
	main.draw_arc(at, 14.0 + 22.0 * ease(k, 0.4), 0.0, TAU, 24, Color(thorn.r, thorn.g, thorn.b, 0.85 * inv_k), 2.5)
	# 8 snapping vine lashes whipping inward and upward around the target
	for i in range(8):
		var ang: float = float(i) * TAU / 8.0 + k * 0.9
		var outer: Vector2 = at + Vector2.from_angle(ang) * (22.0 * (1.0 - 0.35 * k))
		var mid: Vector2 = at + Vector2.from_angle(ang + 0.55) * (12.0 * (1.0 - 0.2 * k)) - Vector2(0.0, 10.0 * sin(k * PI))
		var inner: Vector2 = at + Vector2.from_angle(ang + 1.1) * (5.0 + 4.0 * (1.0 - k)) - Vector2(0.0, 18.0 * ease(k, 0.5))
		main.draw_polyline(PackedVector2Array([outer, mid, inner]), dark_vine, 3.2)
		main.draw_polyline(PackedVector2Array([outer, mid, inner]), lit_vine, 1.5)
	# Flying leaf fragments & dirt
	for i in range(10):
		var d: Vector2 = Vector2.from_angle(float(i) * TAU / 10.0 + 0.2)
		var p: Vector2 = at + d * (8.0 + 26.0 * k) - Vector2(0.0, 16.0 * sin(k * PI) + float(i % 3) * 3.0)
		main.draw_rect(Rect2(p.round(), Vector2(3, 2)), thorn if i % 2 == 0 else lit_vine)

# Thorny living vines wrapped around a rooted enemy's feet and lower torso
func draw_vine_root(e, foot: Vector2, body_h: float) -> void:
	var now: float = float(main.clock)
	var r: float = maxf(10.0, float(e[5]) * 0.95)
	var h: float = clampf(body_h * 0.52, 12.0, 26.0)
	var dark_vine := Color("2E5920")
	var lit_vine := Color("82C445")
	var leaf := Color("D9EE8C")
	# Anchored root ring on the ground
	main.draw_set_transform(foot + Vector2(0.0, 1.0), 0.0, Vector2(1.0, 0.45))
	main.draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 18, dark_vine, 4.0)
	main.draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 18, lit_vine, 1.8)
	main.draw_set_transform(Vector2.ZERO)
	# 2 criss-crossing spiral vine bands gripping the enemy's legs and torso
	for band in range(2):
		var pts := PackedVector2Array()
		var dir_sign: float = 1.0 if band == 0 else -1.0
		for seg in range(7):
			var t: float = float(seg) / 6.0
			var x: float = lerpf(-r * 0.85, r * 0.85, t) * dir_sign
			var y: float = -2.0 - t * h + sin(t * PI) * 2.5 + sin(now * 5.0 + float(band) * 2.0 + t * 4.0) * 1.0
			pts.append(foot + Vector2(x, y))
		main.draw_polyline(pts, dark_vine, 3.2)
		main.draw_polyline(pts, lit_vine, 1.5)
	# 4 small sprouting leaves / thorns twitching on the binding vines
	for i in range(4):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var sway: float = sin(now * 6.0 + float(i) * 1.6) * 2.0
		var lp: Vector2 = foot + Vector2(side * (r * 0.78), -5.0 - float(i) * (h * 0.26))
		main.draw_line(lp, lp + Vector2(side * 4.0, -3.0 + sway), dark_vine, 2.2)
		main.draw_rect(Rect2((lp + Vector2(side * 3.5, -4.0 + sway)).round(), Vector2(2.5, 2.5)), leaf)

# Subtle healing aura & rising crosses directly on any living player standing inside a healing zone
func draw_heal_aura(id, p, foot: Vector2) -> void:
	if int(p[5]) != 0 or active_heal_spots.is_empty():
		return
	var inside_heal: bool = false
	var reach2: float = (1.8 * T) * (1.8 * T)
	for spot in active_heal_spots:
		if foot.distance_squared_to(Vector2(spot)) <= reach2:
			inside_heal = true
			break
	if not inside_heal:
		return
	var now: float = float(main.clock)
	var mint := Color("6CE4BA")
	var bright := Color("E2FFF5")
	var pulse: float = 0.65 + 0.35 * sin(now * 7.0)
	main.draw_set_transform(foot + Vector2(0.0, 1.0), 0.0, Vector2(1.0, 0.45))
	main.draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 18, Color(mint, 0.55 * pulse), 2.2)
	main.draw_set_transform(Vector2.ZERO)
	for i in range(3):
		var life: float = fposmod(now * 1.15 + float(int(id)) * 0.27 + float(i) / 3.0, 1.0)
		var x_off: float = (-10.0 + float(i) * 10.0) + sin(now * 4.0 + float(i)) * 2.0
		var at: Vector2 = foot + Vector2(x_off, -6.0 - life * 24.0)
		var alpha: float = sin(life * PI) * 0.95
		var col: Color = Color(bright if i == 1 else mint, alpha)
		main.draw_line(at - Vector2(2.5, 0.0), at + Vector2(2.5, 0.0), col, 1.8)
		main.draw_line(at - Vector2(0.0, 2.5), at + Vector2(0.0, 2.5), col, 1.8)

# the explosive arrow's burst over its short life
func draw_blast(at: Vector2, age: float, tint_: Color) -> void:
	var k: float = clampf(age / 0.35, 0.0, 1.0)
	var r: float = 1.5 * T
	main.draw_circle(at, r * (0.3 + 0.7 * k), Color(2.2, 1.5, 0.6, 0.5 * (1 - k)))
	main.draw_arc(at, r * (0.4 + 0.8 * k), 0, TAU, 32, Color(tint_, 1 - k), 3.0)
	for i in range(10):
		var d: Vector2 = Vector2.from_angle(i * TAU / 10 + 0.4)
		var p: Vector2 = at + d * r * (0.2 + 0.9 * k) - Vector2(0, 14 * sin(k * PI))
		main.draw_rect(Rect2(p.round(), Vector2(3, 3)), Color(1.8, 1.2, 0.5, 1 - k))

# haste: streaks behind a runner and sparks at the feet
func draw_haste(id, p, foot: Vector2) -> void:
	if p.size() <= 30 or not p[30]:
		return
	var m = main.cmove.get(id, null)
	var now: float = float(main.clock)
	var moving: bool = m != null and now - float(m[1]) < 0.15
	var gold = Color("F0C76B")
	if moving:
		var back: Vector2 = -Vector2.from_angle(float(m[2]))
		for i in range(3):
			var s: Vector2 = foot + Vector2(0, -8 - i * 9) + back * 10
			main.draw_line(s, s + back * (14 + 6 * sin(now * 20 + i)), Color(gold, 0.6), 2.0)
	for i in range(3):
		var k: float = fmod(now * 1.5 + i / 3.0, 1.0)
		var s: Vector2 = foot + Vector2(-9 + i * 9, -k * 22)
		main.draw_rect(Rect2(s.round(), Vector2(2, 2)), Color(gold, 1 - k))

# The original prototype paired NEON_CYAN with a white inner slash (cf44b5f Main.cs).
# Keep that palette with tapered ribbons, moving outward to actual gameplay reach.
# No sector/rectangle outline: only the brief attack trail is drawn under the actor.
# Bows show their range through the actual moving arrow projectiles.
func draw_attack_range(foot: Vector2, aim: float, weapon: String, progress: float) -> void:
	if weapon in ["bow", "starter_bow", "explosive_arrow"] or progress < 0.0 or progress >= 1.0:
		return
	var travel: float = clampf(progress / 0.6, 0.0, 1.0)
	var fade: float = minf(1.0, progress / 0.12) * minf(1.0, (1.0 - progress) / 0.3)
	var reach: float = weapon_reach(weapon)
	var radius: float = reach * (0.28 + 0.72 * travel)
	var blue := Color("267AD8")
	var cyan: Color = Main.NEON_CYAN
	var ice := Color("DCF9FF")
	if weapon == "long_spear":
		var dir := Vector2.from_angle(aim)
		draw_thrust_trail(foot, dir, radius, 10.0, Color(blue, 0.24 * fade))
		draw_thrust_trail(foot, dir, radius, 5.0, Color(cyan, 0.66 * fade))
		draw_thrust_trail(foot, dir, radius, 1.5, Color(ice, 0.90 * fade))
	else:
		# All ribbons lie inside the damage endpoint, including the soft blue rim.
		draw_slash_ribbon(foot, aim, radius, 9.0, Color(blue, 0.22 * fade))
		draw_slash_ribbon(foot, aim, radius, 5.0, Color(cyan, 0.70 * fade))
		draw_slash_ribbon(foot, aim, radius - 1.0, 1.5, Color(ice, 0.90 * fade))
		# A faint inner echo adds motion without a second hard range boundary.
		draw_slash_ribbon(foot, aim, maxf(3.0, radius - 9.0), 1.0, Color(cyan, 0.15 * fade))
	if progress > 0.2:
		# Three tiny fading motes, deterministic and bounded: no particle emitters.
		for i in range(3):
			var offset: float = (i - 1) * 0.46 if weapon != "long_spear" else 0.0
			var direction := Vector2.from_angle(aim + offset)
			var at: Vector2 = foot + direction * maxf(2.0, radius - 3.0 - i * 3.0)
			main.draw_rect(Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), Color(ice, 0.55 * fade))

# One small polygon per layer; opacity and thickness taper smoothly at both ends.
func draw_slash_ribbon(foot: Vector2, aim: float, radius: float, width: float, tint_: Color) -> void:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for edge in range(2):
		for index in range(17):
			var t: float = (index if edge == 0 else 16 - index) / 16.0
			var taper: float = pow(maxf(0.01, sin(t * PI)), 0.7)
			var r: float = maxf(1.0, radius - (width * taper if edge == 1 else 0.0))
			points.append(foot + Vector2.from_angle(aim - PI / 4 + t * PI / 2) * r)
			colours.append(Color(tint_, tint_.a * taper * (0.35 if edge == 1 else 1.0)))
	main.draw_polygon(points, colours)

func draw_thrust_trail(foot: Vector2, dir: Vector2, radius: float, width: float, tint_: Color) -> void:
	var side := dir.orthogonal()
	var tail: float = maxf(2.0, radius - 32.0)
	var middle: float = lerpf(tail, radius, 0.65)
	var points := PackedVector2Array([foot + dir * tail, foot + dir * middle - side * width, foot + dir * radius, foot + dir * middle + side * width])
	main.draw_polygon(points, PackedColorArray([Color(tint_, 0.0), tint_, Color(tint_, tint_.a * 0.9), tint_]))

static func weapon_reach(weapon: String) -> float:
	return float(GameSim.WEAPON_STATS["bow" if weapon == "explosive_arrow" else weapon][2]) * T

static func attack_outline(weapon: String, foot: Vector2, aim: float) -> PackedVector2Array:
	var reach: float = weapon_reach(weapon)
	var dir := Vector2.from_angle(aim)
	if weapon in ["bow", "starter_bow", "explosive_arrow"]:
		return PackedVector2Array([foot, foot + dir * reach])
	if weapon == "long_spear":
		var side := dir.orthogonal() * 10
		return PackedVector2Array([foot - side, foot + dir * reach - side, foot + dir * reach + side, foot + side])
	var outline := PackedVector2Array()
	for i in range(17):
		outline.append(foot + Vector2.from_angle(aim - PI / 4 + i * PI / 32) * reach)
	return outline
