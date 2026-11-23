class_name BaseFogView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.BaseFog.cs.
# Owner: Vu Duc Viet Anh. From outside the base you cannot see into it: a roof covers the floor inside the walls
# and nothing standing inside is drawn (players, enemies, drops, the workbench, hits, boss markers).
# The walls, doors, door towers and the lighthouse (the beacon, rising through the roof) still show.
# Step inside and everything shows again; the roof fades so walking through a door does not flash.
# 0: inside is visible, 1: hidden
var base_fog: float = 0.0
var base_fog_clock: float = 0.0
# how fast the fog comes and goes (full change in 1 / this seconds)
const BASE_FOG_SPEED: float = 4.0
# what is drawn over the floor inside the walls
const BASE_FOG_COL: Color = Color(0.07, 0.08, 0.1)

# constants shared with Main
const LIGHTHOUSE = Main.LIGHTHOUSE
const LIGHTHOUSE_SCALE = Main.LIGHTHOUSE_SCALE
const WALL_H = Main.WALL_H

var main: Main

func _init(host: Main) -> void:
	main = host

# call once per frame before drawing the world
func tick_base_fog() -> void:
	var now: float = float(main.clock)
	var dt: float = clampf(now - base_fog_clock, 0.0, 0.1)
	base_fog_clock = now
	var out: bool = not SimWorld.inside_base(main.local_pos)
	base_fog = move_toward(base_fog, 1.0 if out else 0.0, dt * BASE_FOG_SPEED)

# whether something at this spot is hidden from you
func hidden_in_base(pos: Vector2) -> bool:
	return base_fog > 0.5 and SimWorld.inside_base(pos)

# From outside, the base has a roof: flat riveted slabs in the walls' concrete laid between the wall tops (lifted by the wall height,
# like the walls' top faces), rusting at the seams, with vent grates. The lighthouse rises through the
# middle of it and is drawn on top (a depth item). Under it, the floor goes dark, which is what shows through an
# open door. Drawn on the ground layer, so the walls and everything outside draw over it.
var roof_alpha: float = 0.0
# the roof is about 1500 rects a frame from outside: its colours are parsed once, not on every rect
static var roof_hex = {}
const ROOF_SLAB: Color = Color("B0A58B")
const ROOF_SLAB_LIT: Color = Color("C6BBA1")
static var RIVETS = [Vector2(2, 2), Vector2(32 - 4, 2), Vector2(2, 25 - 4), Vector2(32 - 4, 25 - 4), Vector2(32 / 2 - 1, 2), Vector2(32 / 2 - 1, 25 - 4)]

func rf_2(hex_, a_: float = 1.0) -> Color:
	var c = roof_hex.get(hex_, Color(0, 0, 0, 0))
	if not roof_hex.has(hex_):
		c = Color(hex_)
		roof_hex[hex_] = c
	c.a = a_ * roof_alpha
	return c

func rf(c: Color) -> Color:
	c.a *= roof_alpha
	return c

static func roof_rect() -> Rect2:
	var h: Vector2 = Vector2(GameSim.HALF)
	var in_: float = float(GameSim.WALL_IN)
	var lift: float = float(WALL_H)
	return Rect2(-h.x + in_, -h.y + in_ - lift, 2 * (h.x - in_), 2 * (h.y - in_))

func draw_base_fog() -> void:
	if base_fog <= 0.0:
		return
	roof_alpha = smoothstep(0.0, 1.0, base_fog)
	var h: Vector2 = Vector2(GameSim.HALF)
	# the dark inside, seen through the doorways
	var dark = BASE_FOG_COL
	dark.a = roof_alpha
	main.draw_rect(Rect2(-h, h * 2), dark)
	var r: Rect2 = roof_rect()
	var x0: float = r.position.x
	var y0: float = r.position.y
	# riveted concrete slabs in the walls' cream, each a shade apart, rust bleeding from some seams (the rim around them is the walls'
	# concrete coping, src/world/view/base_look.gd)
	main.draw_rect(r, rf_2("8A8069"))
	var pw: int = 32
	var ph: int = 25
	var y: float = y0
	while y < r.end.y:
		var x: float = x0
		while x < r.end.x:
			var p = Rect2(x + 1, y + 1, pw - 1, ph - 1).intersection(r)
			if not p.has_area():
				x += pw
				continue
			var hs: int = BaseLookView.hash_(roundi(x), roundi(y) + 999)
			main.draw_rect(p, rf(ROOF_SLAB.lerp(ROOF_SLAB_LIT, hs % 100 / 100.0)))
			main.draw_rect(Rect2(p.position, Vector2(p.size.x, 1)), rf_2("DDD3BB", 0.8))
			main.draw_rect(Rect2(p.position, Vector2(1, p.size.y)), rf_2("DDD3BB", 0.5))
			main.draw_rect(Rect2(p.position.x, p.end.y - 1, p.size.x, 1), rf_2("857B66", 0.6))
			# rivets at the corners and halfway along the long edges
			for rv in RIVETS:
				var at: Vector2 = p.position + rv
				if p.has_point(at):
					main.draw_rect(Rect2(at, Vector2.ONE), rf_2("E8E0CB"))
					main.draw_rect(Rect2(at + Vector2(0, 1), Vector2.ONE), rf_2("7A705C", 0.7))
			# weathering: rust blooms and streaks, a few pale patches
			if hs % 3 == 0:
				var n: int = 4 + (hs >> 3) % 6
				var c: Vector2 = p.position + Vector2(4 + (hs >> 5) % (pw - 10), 4 + (hs >> 9) % (ph - 10))
				for k in range(n):
					var hk: int = BaseLookView.hash_(hs, k)
					var d: Vector2 = Vector2(hk % 7 - 3, (hk >> 4) % 5 - 2)
					var blot = Rect2(c + d, Vector2(1 + (hk >> 8) % 3, 1 + (hk >> 11) % 2)).intersection(p)
					if blot.has_area():
						main.draw_rect(blot, rf_2("74401F" if (hk >> 13) % 3 == 0 else "9C5B33", 0.75))
				# a run toward the south edge
				var run = Rect2(c, Vector2(1, 3 + (hs >> 14) % 8)).intersection(p)
				if run.has_area():
					main.draw_rect(run, rf_2("9C5B33", 0.5))
			elif hs % 7 == 1:
				main.draw_rect(Rect2(p.position + Vector2(5, 6), Vector2(10, 5)).intersection(p), rf_2("E2D9C3", 0.4))
			x += pw
		y += ph
	# vent grates in concrete frames
	for v in [Vector2(-118, 28), Vector2(84, -22), Vector2(-104, -96), Vector2(102, 34)]:
		self.roof_grate(Rect2(v, Vector2(26, 12)))
	# the lighthouse's shadow across the roof by day (the sun is low in the south-east); it comes up through
	# the roof, which is lifted by the wall height
	var foot: Vector2 = Vector2(LIGHTHOUSE) - Vector2(0, float(WALL_H))
	if main.snap.get("ph", "") == "day":
		var sh = [foot + Vector2(-16, 4), foot + Vector2(16, 0), foot + Vector2(-104, -98), foot + Vector2(-128, -84)]
		for k in range(len(sh)):
			sh[k] = sh[k].clamp(r.position, r.end)
		main.draw_colored_polygon(sh, rf_2("000000", 0.28))
	# where the lighthouse comes up through the roof: a rusty steel collar
	self.roof_ellipse(foot + Vector2(4, 2), 34, 9, rf_2("000000", 0.3))
	self.roof_ellipse(foot, 30, 8, rf_2("6B5444"))
	self.roof_ellipse(foot, 30, 8, rf_2("2E353D"), false)
	self.roof_ellipse(foot, 26, 6, rf_2("8A6A4E"), false)

# a vent grate: concrete frame, dark slats
func roof_grate(g: Rect2) -> void:
	main.draw_rect(Rect2(g.position + Vector2(2, 3), g.size), rf_2("000000", 0.3))
	main.draw_rect(g.grow(2), rf_2("2E353D"))
	main.draw_rect(g.grow(1), rf_2("C8BDA3"))
	main.draw_rect(g, rf_2("23282E"))
	var x: float = g.position.x + 2
	while x < g.end.x - 1:
		main.draw_rect(Rect2(x, g.position.y + 1, 1, g.size.y - 2), rf_2("8A8069"))
		x += 3.0
	main.draw_rect(Rect2(g.position.x, g.position.y, g.size.x, 1), rf_2("000000", 0.4))

func roof_ellipse(c: Vector2, rx: float, ry: float, col: Color, filled: bool = true) -> void:
	var pts = Cs.arr(24, Vector2.ZERO)
	for k in range(24):
		var a_: float = k * TAU / 24
		pts[k] = c + Vector2(cos(a_) * rx, sin(a_) * ry)
	if filled:
		main.draw_colored_polygon(pts, col)
	else:
		var ring = Cs.arr(25, Vector2.ZERO)
		Cs.copy_to(pts, ring, 0)
		ring[24] = pts[0]
		main.draw_polyline(ring, col, 1.0)

# From outside only the part of the lighthouse above the roof shows: the sprite is cut where it comes
# up through the roof's collar (DrawBaseFog). Inside, or while the roof is fading out, it is drawn whole.
func draw_lighthouse(pos: Vector2, mod_: Color) -> void:
	var p = main.prop.get("lighthouse")
	if p == null:
		return
	if base_fog <= 0.5:
		main.draw_prop("lighthouse", pos, mod_)
		return
	var tex = p[0]
	var sc: float = float(LIGHTHOUSE_SCALE)
	var anchor: Vector2 = Vector2(p[1])
	var size: Vector2 = tex.get_size()
	# texture rows above the roof line (the roof sits WALL_H above the ground)
	var keep: float = clampf(anchor.y - float(WALL_H) / sc, 0.0, size.y)
	var src = Rect2(0, 0, size.x, keep)
	var dst = Rect2((pos - anchor * sc).round(), Vector2(size.x, keep) * sc)
	main.draw_texture_rect_region(tex, dst, src, mod_)

# whether a depth item (see Main._Draw) stands inside the base and is hidden from you
func hidden_item(it) -> bool:
	if base_fog <= 0.5 and not main.weather_station.interior_active:
		return false
	var kind: int = int(it[1])
	var pos: Vector2 = Vector2.ZERO
	# scatter and nodes, enemies, props
	if kind == 0 or kind == 2:
		pos = Vector2(it[3])
	# the lighthouse is seen over the walls
	elif kind == 6:
		if Cs.s(it[2]) == "lighthouse":
			return false
		pos = Vector2(it[3])
	# players
	elif kind == 3:
		pos = Vector2(it[4])
	# projectiles, drops, arrows
	elif kind == 4 or kind == 5 or kind == 11:
		pos = Vector2(it[2][0])
	elif kind == 21:
		pos = Vector2(it[2][1])
	elif kind == 22:
		pos = GameSim.RADIO_POS
	elif kind == 12:
		pos = main.enemy_view.corpses[int(it[2])].foot
	# walls, broken doors, pillars, towers and built walls are never hidden
	else:
		return false
	return self.hidden_in_base(pos) or main.weather_station.hidden_outside_interior(pos)
