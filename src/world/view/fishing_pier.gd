class_name FishingPierView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.FishingPier.cs.
static var pier_fish_body = [Vector2(-10, 0), Vector2(-4, -5), Vector2(6, -4), Vector2(11, 0), Vector2(6, 4), Vector2(-4, 4)]
static var pier_fish_tail = [Vector2(-7, 0), Vector2(-15, -6), Vector2(-15, 6)]

var main: Main

func _init(host: Main) -> void:
	main = host

func fishing_rod_items(items, view: Rect2) -> void:
	var w = main.geometry
	if main.weather_station.interior_active:
		return
	var i: int = 0
	while i < w.fishing_rods.size():
		if Cs.has_point(view.grow(90), w.fishing_rods[i][0]):
			items.append([w.fishing_rods[i][0].y, 15, i])
		i += 1

func draw_fishing_rod(index: int) -> void:
	var _d1 = main.geometry.fishing_rods[index]
	var foot = _d1[0]
	var side = _d1[1]
	var tip: Vector2 = foot + Vector2(-32, side * 35 - 22)
	var mid: Vector2 = foot.lerp(tip, 0.6) + Vector2(5, -7)
	main.draw_line(foot + Vector2(0, 6), foot + Vector2(0, -13), Color("605B45"), 4)
	main.draw_line(foot + Vector2(6, 4), foot + Vector2(-5, -7), Color("AB9466"), 3)
	main.draw_line(foot, mid, Color("B69A64"), 3)
	main.draw_line(mid, tip, Color("D0BA84"), 2)
	main.draw_line(foot, foot.lerp(mid, 0.24), Color("4B4438"), 5)
	main.draw_circle(foot.lerp(mid, 0.25) + Vector2(4, 0), 4, Color("BEC3B0"))
	main.draw_circle(foot.lerp(mid, 0.25) + Vector2(4, 0), 2, Color("535D58"))
	var float_: Vector2 = foot + Vector2(-37, side * 56)
	var sag: Vector2 = tip.lerp(float_, 0.5) + Vector2(8, 5)
	main.draw_line(tip, sag, Color("C3CCB3", 0.7), 1)
	main.draw_line(sag, float_, Color("C3CCB3", 0.7), 1)
	float_.y += sin(float(main.clock) * 2 + index * 2) * 1.5
	main.draw_rect(Rect2(float_.round() - Vector2(2, 3), Vector2(4, 7)), Color("E8DAB6"))
	main.draw_rect(Rect2(float_.round() - Vector2(2, 3), Vector2(4, 3)), Color("C55B42"))

func draw_fishing_life(w, view: Rect2, time: float) -> void:
	var _c1 = main.weather_station.interior_active
	var pier
	if not _c1:
		pier = w.lm_at.get(10, Vector2.ZERO)
		_c1 = not w.lm_at.has(10)
	if _c1 or not Cs.has_point(view.grow(360), pier):
		return
	for l in range(w.fishing_litter.size()):
		var _d2 = w.fishing_litter[l]
		var p = _d2[0]
		var kind = _d2[1]
		if not view.has_point(p):
			continue
		main.draw_rect(Rect2(p + Vector2(-5, 2), Vector2(12, 3)), Color("343F35", 0.4))
		# Crumpled bait wrappers.
		if kind == 0:
			main.terrain_view.fill_static(w.fishing_litter_faces[l], Color("C9C09A"))
			main.draw_line(p + Vector2(-2, -2), p + Vector2(4, 1), Color("987C55"), 2)
		# Empty drink tins.
		elif kind == 1:
			main.draw_rect(Rect2(p - Vector2(4, 5), Vector2(8, 10)), Color("9AABA2"))
			main.draw_rect(Rect2(p - Vector2(4, 2), Vector2(8, 4)), Color("AB6450"))
			main.draw_line(p + Vector2(-3, -5), p + Vector2(3, -5), Color("D0D2B8"), 2)
		# Discarded green bottles.
		elif kind == 2:
			main.draw_rect(Rect2(p - Vector2(5, 2), Vector2(10, 5)), Color("4D7B68"))
			main.draw_rect(Rect2(p + Vector2(5, -1), Vector2(4, 3)), Color("729680"))
			main.draw_line(p - Vector2(3, 1), p + Vector2(3, -1), Color("ABC1A1"), 1)
		# Coiled fishing line and a rusty hook.
		else:
			main.draw_arc(p, 6, 0, TAU * 1.7, 16, Color("B7AE85"), 1)
			main.draw_line(p + Vector2(5, 0), p + Vector2(11, 4), Color("A4A18B"), 1)
	# At most eight visual fish, with cached sea positions and staggered jumps. No physics, AI or spawning.
	for i in range(w.fishing_fish.size()):
		var water: Vector2 = w.fishing_fish[i]
		if not Cs.has_point(view.grow(45), water):
			continue
		var cycle: float = 5.2 + i % 3 * 0.9
		var phase: float = fposmod(time + i * 1.37, cycle)
		if phase > 2.1:
			continue
		var t: float = minf(phase / 1.15, 1)
		var arc: float = sin(t * PI)
		var sign_: int = 1 if i % 2 == 0 else -1
		var fish: Vector2 = (water + Vector2((t - 0.5) * 42 * sign_, -arc * (30 + i % 3 * 8))).round()
		var foam: Color = Color("BCDAD1", (1 - phase / 2.1) * 0.75)
		var ripple: Vector2 = water + Vector2(-21 * sign_ if phase < 1.15 else 21 * sign_, 0)
		var radius: float = 5 + (phase if phase < 1.15 else phase - 1.15) * 16
		main.draw_set_transform(ripple.round(), 0, Vector2(1, 0.4))
		main.draw_arc(Vector2.ZERO, radius, 0, TAU, 16, foam, 1)
		main.draw_set_transform(Vector2.ZERO)
		if phase >= 1.15:
			var splash: float = (phase - 1.15) / 0.95
			for k in range(4):
				main.draw_rect(Rect2((ripple + Vector2((k - 1.5) * splash * 15, -sin(splash * PI) * (14 if k % 2 == 0 else 22))).round(), Vector2(2, 3)), foam)
			continue
		main.draw_set_transform(fish, (t - 0.5) * 1.3 * sign_, Vector2(sign_, 1))
		main.draw_colored_polygon(pier_fish_body, Color("9FC7BA" if i % 2 == 0 else "C4C7A5"))
		main.draw_colored_polygon(pier_fish_tail, Color("5F9997"))
		main.draw_line(Vector2(-4, 2), Vector2(6, 2), Color("E0E2BF"), 2)
		main.draw_rect(Rect2(6, -2, 2, 2), Color("273F43"))
		main.draw_set_transform(Vector2.ZERO)
