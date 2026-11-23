class_name CompoundBoundariesView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.CompoundBoundaries.cs.

var main: Main

func _init(host: Main) -> void:
	main = host

func compound_boundary_items(items, view: Rect2) -> void:
	if main.weather_station.interior_active:
		return
	var w = main.geometry
	var i: int = 0
	while i < w.compound_boundaries.size():
		var s = w.compound_boundaries[i]
		if Rect2(s.a.min(s.b), (s.b - s.a).abs()).grow(85).intersects(view):
			items.append([maxf(s.a.y, s.b.y), 18, i])
		i += 1

func draw_compound_boundary(index: int) -> void:
	var s = main.geometry.compound_boundaries[index]
	var a_: Vector2 = s.a
	var b: Vector2 = s.b
	var lift: Vector2 = Vector2(0, -s.height)
	if s.id == 13:
		# Chain-link mesh remains transparent, with sturdy posts, top rail and a concrete toe.
		main.draw_line(a_, b, ExpeditionSitesView.ep("535E59"), 7)
		if s.wire.size() > 0:
			main.draw_multiline(s.wire, Color("8D9E98", 0.75), 1)
		main.draw_line(a_ + lift, b + lift, ExpeditionSitesView.ep("9DA9A0"), 3)
		main.draw_line(a_ + Vector2(0, -5), b + Vector2(0, -5), ExpeditionSitesView.ep("788A81"), 2)
		main.draw_line(a_, a_ + lift - Vector2(0, 7), ExpeditionSitesView.ep("414F4B"), 6)
		main.draw_line(a_ - Vector2(1, 0), a_ + lift - Vector2(1, 7), ExpeditionSitesView.ep("B5B9A6"), 2)
		main.draw_line(b, b + lift - Vector2(0, 7), ExpeditionSitesView.ep("657970"), 4)
		# A rusted, bent security wire follows the top instead of floating over the entrance.
		for i in range(4):
			var p: Vector2 = a_.lerp(b, (i + 0.5) / 4) + lift - Vector2(0, 5)
			main.draw_line(p - Vector2(3, 3), p + Vector2(3, 2), ExpeditionSitesView.ep("9E9378"), 1)
			main.draw_line(p - Vector2(3, -2), p + Vector2(3, -3), ExpeditionSitesView.ep("9E9378"), 1)
		return
	main.terrain_view.fill_static(s.face, ExpeditionSitesView.ep("A8AA99" if s.side == 0 else "8E9688" if s.side == 3 else "747F76"))
	main.terrain_view.fill_static(s.cap, ExpeditionSitesView.ep("C6C3A9"))
	main.draw_line(a_, b, ExpeditionSitesView.ep("515F57"), 5)
	main.draw_line(a_ - Vector2(0, 8), b - Vector2(0, 8), ExpeditionSitesView.ep("6B796C"), 2)
	if s.side == 0 or s.side == 3:
		var x0: float = minf(a_.x, b.x) + 4
		var x1: float = maxf(a_.x, b.x) - 4
		# Exposed brick beneath flaking plaster and diagonal settlement cracks.
		for row in range(3):
			var x: float = x0 + row % 2 * 6
			while x < x1 - 8:
				var p: Vector2 = Vector2(x, a_.y - 11 - row * 7)
				if int(x) % 3 != 0:
					main.draw_rect(Rect2(p, Vector2(11, 5)), ExpeditionSitesView.ep("8D7360" if row % 2 == 0 else "9B8267"))
				x += 13
		var crack: Vector2 = a_.lerp(b, 0.68)
		main.draw_line(crack + Vector2(-5, -s.height + 9), crack + Vector2(2, -24), ExpeditionSitesView.ep("56645D"), 2)
		main.draw_line(crack + Vector2(2, -24), crack + Vector2(-6, -9), ExpeditionSitesView.ep("56645D"), 2)
		if s.side == 0 and index % 2 == 0:
			var p: Vector2 = a_.lerp(b, 0.43) + Vector2(-12, -49)
			main.draw_rect(Rect2(p - Vector2(3, 3), Vector2(30, 27)), ExpeditionSitesView.ep("6D7C73"))
			main.draw_rect(Rect2(p, Vector2(24, 21)), ExpeditionSitesView.ep("253B38"))
			main.draw_line(p + Vector2(10, 0), p + Vector2(13, 21), ExpeditionSitesView.ep("8D9782"), 2)
			main.draw_line(p + Vector2(0, 11), p + Vector2(24, 8), ExpeditionSitesView.ep("94A08E"), 2)
			main.draw_line(p + Vector2(17, 1), p + Vector2(21, 8), ExpeditionSitesView.ep("C0C7AE"), 1)
	# Twisted reinforcement and patchy vines make all four surviving sides visibly abandoned.
	var rebar: Vector2 = a_.lerp(b, 0.35) + lift
	main.draw_line(rebar, rebar + Vector2(2, -11), ExpeditionSitesView.ep("6D594B"), 2)
	main.draw_line(rebar + Vector2(2, -11), rebar + Vector2(9, -14), ExpeditionSitesView.ep("B19B78"), 1)
	if index % 3 == 0:
		var p: Vector2 = a_.lerp(b, 0.18)
		main.draw_line(p - Vector2(0, 3), p - Vector2(3, 32), ExpeditionSitesView.ep("405E3E"), 2)
		for i in range(5):
			main.draw_rect(Rect2(p + Vector2(-7 if i % 2 == 0 else 0, -7 - i * 5), Vector2(6, 3)), ExpeditionSitesView.ep("6A8154"))
