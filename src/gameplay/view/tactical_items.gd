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
# seconds a thrown flask flies before it splashes
const FLASK_FLIGHT: float = 0.3

# constants shared with Main
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

func draw_tactical_areas() -> void:
	var now: float = float(main.clock)
	var live = {}
	for a_ in main.snap.get("tactical", []):
		var kind = Cs.s(a_[0])
		var at: Vector2 = Vector2(a_[1])
		var key_ = [kind, at]
		Cs.set_add(live, key_)
		var seen = area_seen.get(key_, 0.0)
		if not area_seen.has(key_):
			seen = now
			area_seen[key_] = seen
		var age: float = now - seen
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
		var open: float = clampf((age - FLASK_FLIGHT) / 0.25, 0.0, 1.0) if fresh else 1.0
		var r: float = 1.8 * T * ease(open, 0.4)
		main.draw_circle(at, r, Color(tint_, 0.13))
		main.draw_arc(at, r, 0, TAU, 32, Color(tint_, 0.8), 2.0)
		if fresh and open < 1.0:
			# the splash: glass and drops thrown out
			for i in range(8):
				var d: Vector2 = Vector2.from_angle(i * TAU / 8 + 0.3)
				var p: Vector2 = at + d * (6 + 26 * open) - Vector2(0, 10 * sin(open * PI))
				main.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(tint_.lightened(0.3), 1 - open))
		for i in range(5):
			var p: Vector2 = at + Vector2.from_angle(i * TAU / 5 + now * 0.25) * (r * 0.55)
			p.y -= 3.0 + 3.0 * sin(now * 3 + i)
			if kind == "heal":
				main.draw_line(p - Vector2.RIGHT * 3, p + Vector2.RIGHT * 3, tint_, 2.0)
				main.draw_line(p - Vector2.DOWN * 3, p + Vector2.DOWN * 3, tint_, 2.0)
			else:
				main.draw_rect(Rect2(p.round(), Vector2(3, 3)), tint_)
	# forget areas that are gone
	if area_seen.size() > live.size():
		var gone = []
		for k in area_seen.keys():
			if not live.has(k):
				gone.append(k)
		for k in gone:
			area_seen.erase(k)

func thrower_pos(owner, fallback: Vector2) -> Vector2:
	if owner == null:
		return fallback
	if owner == main.my_id:
		return Vector2(main.local_pos)
	var p = main.snap.ps.get(owner, null)
	return fallback if p == null else Vector2(main.shown_p.get(owner, p[2]))

# a flask tumbling along a throw arc
func draw_flask_flight(from: Vector2, to: Vector2, k: float, kind) -> void:
	var ground_: Vector2 = from.lerp(to, k)
	var height: float = 18 + 34 * sin(k * PI)
	main.shadow(ground_, 4)
	var at: Vector2 = ground_ - Vector2(0, height)
	main.draw_set_transform(at, k * 9.0, Vector2.ONE)
	main.inventory.draw_item_icon(main, "healing_flask" if kind == "heal" else "poison_flask", Vector2.ZERO, 1.0)
	main.draw_set_transform(Vector2.ZERO)

# a vine trap sprouting, then waiting
func draw_trap(at: Vector2, age: float) -> void:
	var grow: float = clampf(age / 0.35, 0.0, 1.0)
	var s: float = ease(grow, 0.4) * (1.0 + 0.25 * sin(grow * PI))
	var green = Color("98BE56")
	main.draw_arc(at, 17.0 * s, 0, TAU, 16, green, 2.0)
	# curling vines
	for i in range(4):
		var a_: float = i * TAU / 4 + float(main.clock) * 0.6
		var root: Vector2 = at + Vector2.from_angle(a_) * 12.0 * s
		var tip: Vector2 = root + Vector2(0, -6.0 * s) + Vector2.from_angle(a_ + 1.2) * 3.0 * sin(float(main.clock) * 3 + i)
		main.draw_line(root, tip, Color("5E8A34"), 2.0)
	if s > 0.05:
		main.draw_set_transform(at, 0, Vector2.ONE * s)
		main.inventory.draw_item_icon(main, "vine_trap", Vector2.ZERO, 1.0)
		main.draw_set_transform(Vector2.ZERO)
	if grow < 1.0:
		# soil kicked up as it bursts out
		for i in range(6):
			var p: Vector2 = at + Vector2.from_angle(i * TAU / 6) * (8 + 14 * grow) - Vector2(0, 8 * sin(grow * PI))
			main.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color("7A6046", 1 - grow))

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
