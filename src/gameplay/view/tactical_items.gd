class_name TacticalItemsView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/gameplay/view/Main.TacticalItems.cs.
# Owner: Pham Minh Hieu. How the tactical items look in use:
#   flasks   - fly from the thrower in an arc, then splash and leave their pulsing area
#   vine trap - sprouts out of the ground, then waits with its vines curling
#   blast    - the explosive arrow's burst: a flash, a ring and flying sparks
#   haste    - streaks behind a hasted runner and sparks round their feet
#   long spear / stun maul - drawn moving over the spear / hammer frames: a thrust out and back, an overhead
#   blow that lands with a shock ring and stars
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

func draw_tactical_weapon(id, p, foot: Vector2, aim: float) -> void:
	draw_haste(id, p, foot)
	var w = Cs.s(p[8])
	if not p[11] or not (w == "long_spear" or w == "stun_maul"):
		return
	var start: float = main.anim.swing_start(Cs.s(id), true)
	var k: float = clampf((float(main.clock) - start) / 0.25, 0.0, 1.0)
	var dir: Vector2 = Vector2.from_angle(aim)
	var side: Vector2 = dir.orthogonal()
	var hand: Vector2 = foot - Vector2(0, 18)
	var ink = Color(0.08, 0.07, 0.1)
	if w == "long_spear":
		# drawn back, driven out to full reach, pulled back
		var out: float = -8.0 * (k / 0.25) if k < 0.25 else lerpf(-8.0, 22.0, (k - 0.25) / 0.3) if k < 0.55 else lerpf(22.0, 4.0, (k - 0.55) / 0.45)
		var butt: Vector2 = hand - dir * 12 + dir * out
		var tip: Vector2 = hand + dir * 46 + dir * out
		main.draw_line(butt, tip, ink, 5)
		main.draw_line(butt, tip, Color("C39058"), 3)
		main.draw_colored_polygon([tip + dir * 13, tip + side * 5, tip - side * 5], Color("DBE9D7"))
		main.draw_polyline([tip + dir * 13, tip + side * 5, tip - side * 5, tip + dir * 13], ink, 1.5)
		if k > 0.35 and k < 0.75:
			# the thrust streak
			var a_: float = 1.0 - absf(k - 0.55) / 0.2
			main.draw_line(tip + dir * 15 - side * 3, tip + dir * 34 - side * 3, Color(1, 1, 1, 0.6 * a_), 2.0)
			main.draw_line(tip + dir * 15 + side * 3, tip + dir * 30 + side * 3, Color(1, 1, 1, 0.6 * a_), 2.0)
	else:
		# raised high behind, brought down hard in front, a shock where it lands
		var swing: float = lerpf(0.0, -0.4, k / 0.3) if k < 0.3 else lerpf(-0.4, 1.0, ease(clampf((k - 0.3) / 0.3, 0.0, 1.0), 2.4))
		var lift: float = (1.0 - swing) * 22.0
		var head: Vector2 = hand + dir * (12 + 18 * swing) - Vector2(0, lift)
		main.draw_line(hand, head, ink, 6)
		main.draw_line(hand, head, Color("B48550"), 4)
		var hd: Vector2 = (head - hand).normalized()
		var hs: Vector2 = hd.orthogonal()
		var block = [head + hd * 6 + hs * 12, head + hd * 6 - hs * 12, head - hd * 6 - hs * 12, head - hd * 6 + hs * 12]
		main.draw_colored_polygon(block, Color("A0CEE0"))
		main.draw_polyline([block[0], block[1], block[2], block[3], block[0]], ink, 1.5)
		if k >= 0.6:
			var i: float = (k - 0.6) / 0.4
			var ground_: Vector2 = foot + dir * 30
			main.draw_set_transform(ground_, 0, Vector2(1.0, 0.45))
			main.draw_arc(Vector2.ZERO, 8 + 22 * i, 0, TAU, 24, Color("DDD681", 1 - i), 2.5)
			main.draw_set_transform(Vector2.ZERO)
			for s in range(3):
				main.draw_circle(ground_ - Vector2(0, 12 + 6 * i) + Vector2.from_angle(s * TAU / 3 + i * 4) * 9, 2.0, Color("FFF3B4", 1 - i))
