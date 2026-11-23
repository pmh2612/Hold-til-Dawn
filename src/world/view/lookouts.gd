class_name LookoutsView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.Lookouts.cs.
static var reef_roof = [Vector2(-70, -66), Vector2(-43, -95), Vector2(56, -95), Vector2(75, -66)]
static var beacon_hood = [Vector2(-21, -78), Vector2(0, -95), Vector2(21, -78)]
static var compass_north = [Vector2(0, -48), Vector2(-9, 0), Vector2(0, -9), Vector2(9, 0)]
static var compass_south = [Vector2(0, 48), Vector2(-9, 0), Vector2(0, 9), Vector2(9, 0)]

var main: Main

func _init(host: Main) -> void:
	main = host

func lookout_items(items, view: Rect2) -> void:
	if main.weather_station.interior_active:
		return
	var w = main.geometry
	var i: int = 0
	while i < w.lookout_objects.size():
		var s = w.lookout_objects[i]
		if Cs.has_point(view.grow(150), s.pos):
			items.append([s.pos.y, 19, i])
		i += 1
	i = 0
	while i < w.lookout_rails.size():
		var s = w.lookout_rails[i]
		if Cs.has_point(view.grow(70), (s.a + s.b) / 2):
			items.append([maxf(s.a.y, s.b.y), 20, i])
		i += 1

func draw_lookout_ground(w, view: Rect2, time: float) -> void:
	for site in w.lookouts.values():
		if not Rect2(site.centre - site.radii, site.radii * 2).grow(75).intersects(view):
			continue
		var c: Vector2 = site.centre
		if site.id == 12:
			main.draw_rect(site.deck.grow(5), ExpeditionSitesView.ep("536F68"))
			main.draw_rect(site.deck, ExpeditionSitesView.ep("B4B69A"))
			var y: float = site.deck.position.y + 3
			while y < site.deck.end.y:
				main.draw_line(Vector2(site.deck.position.x + 2, y), Vector2(site.deck.end.x - 2, y), ExpeditionSitesView.ep("7D9581"), 2)
				for i in range(4):
					var p: Vector2 = Vector2(site.deck.position.x + 25 + i * 55, y + 2)
					main.draw_rect(Rect2(p, Vector2(1, 1)), ExpeditionSitesView.ep("506D65"))
				y += 9
			# Shell fragments and bleached coral rubble identify the whole clearing, not only the pavilion.
			for i in range(30):
				var a_: float = i * 2.39996
				var p: Vector2 = c + Vector2(cos(a_) * 164, sin(a_) * 116)
				main.draw_arc(p.round(), 3 + i % 3, PI, TAU, 7, ExpeditionSitesView.ep("F1D6C2" if i % 2 == 0 else "E5DCC0"), 2)
				main.draw_line(p + Vector2(-2, 1), p + Vector2(2, 1), ExpeditionSitesView.ep("AB9E8D"), 1)
			for i in range(5):
				main.draw_rect(Rect2(c + Vector2(-36, 73 + i * 8), Vector2(72, 6)), ExpeditionSitesView.ep("B0B398" if i % 2 == 0 else "8C9C85"))
		else:
			main.terrain_view.fill_static(w.cape_scarp_face, ExpeditionSitesView.ep("465F63"))
			main.terrain_view.fill_static(w.cape_scarp_cap, ExpeditionSitesView.ep("A4B2A5"))
			main.terrain_view.fill_static(site.outline, ExpeditionSitesView.ep("A8B9B0"))
			for i in range(24):
				var p: Vector2 = c + Vector2(-105 + i * 37 % 205, -81 + i * 29 % 163)
				if (p - c).length() < 55:
					continue
				main.draw_line(p, p + Vector2(7 + i % 9, 3), ExpeditionSitesView.ep("6F8983"), 1)
				main.draw_line(p + Vector2(7 + i % 9, 3), p + Vector2(10 + i % 9, 8), ExpeditionSitesView.ep("6F8983"), 1)
			main.draw_set_transform(c)
			main.draw_arc(Vector2.ZERO, 56, 0, TAU, 48, ExpeditionSitesView.ep("5B7F79"), 2)
			main.draw_arc(Vector2.ZERO, 61, 0, TAU, 48, ExpeditionSitesView.ep("D2D4B9"), 2)
			for i in range(16):
				var d: Vector2 = Vector2.from_angle(i * TAU / 16)
				main.draw_line(d * (46 if i % 4 == 0 else 51), d * 56, ExpeditionSitesView.ep("577972"), 2)
			main.terrain_view.fill_static(compass_north, ExpeditionSitesView.ep("476E6D"), false)
			main.terrain_view.fill_static(compass_south, ExpeditionSitesView.ep("CCB88E"), false)
			main.draw_set_transform(c, PI / 2)
			main.terrain_view.fill_static(compass_north, ExpeditionSitesView.ep("65857F"), false)
			main.terrain_view.fill_static(compass_south, ExpeditionSitesView.ep("DBCFB0"), false)
			main.draw_set_transform(Vector2.ZERO)
			main.draw_circle(c, 6, ExpeditionSitesView.ep("D7C494"))
			main.draw_circle(c, 2, ExpeditionSitesView.ep("536E69"))
			main.draw_string(ThemeDB.fallback_font, c + Vector2(-4, -66), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ExpeditionSitesView.ep("3F6464"))
			main.draw_string(ThemeDB.fallback_font, c + Vector2(-4, 78), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ExpeditionSitesView.ep("3F6464"))
	if main.weather_station.interior_active:
		return
	for i in range(w.coral.size()):
		var p: Vector2 = w.coral[i]
		if not Cs.has_point(view.grow(32), p):
			continue
		main.terrain_view.fill_static(w.reef_beds[i], Color("55ADAB" if i % 2 == 0 else "78BBAE", 0.27), false)
		var col: Color = LandmarkView.CORAL[i % LandmarkView.CORAL.size()]
		col.a = 0.64 + 0.08 * sin(time * 1.2 + i)
		if i % 3 == 0:
			for k in range(-2, 3):
				var d: Vector2 = Vector2.from_angle((k + 2) * 0.68 + 0.2 + i * 1.4)
				var tip: Vector2 = p + d * 14
				main.draw_line(p, tip, col, 3)
				main.draw_line(p + d * 8, tip + d.orthogonal() * 4, col.lightened(0.22), 2)
		else:
			for k in range(5):
				var q: Vector2 = p + Vector2.from_angle(k * 2.4 + i) * (5 + k % 3 * 2)
				main.draw_circle(q.round(), 4 + k % 3, col)
				main.draw_circle((q - Vector2(1, 1)).round(), 2, col.lightened(0.3))
		main.draw_line(p + Vector2(-9, 18), p + Vector2(9, 18), Color("B8E3D7", 0.2 + 0.1 * sin(time + i)), 1)
	for i in range(w.cape_gulls.size()):
		var p: Vector2 = w.cape_gulls[i] + Vector2(sin(time * 0.5 + i) * 16, cos(time * 0.7 + i) * 6)
		if not view.has_point(p):
			continue
		var wing: float = 3 + sin(time * 3 + i) * 3
		main.draw_line(p - Vector2(8, wing), p, ExpeditionSitesView.ep("E1E4CC"), 2)
		main.draw_line(p, p + Vector2(8, -wing), ExpeditionSitesView.ep("E1E4CC"), 2)

func draw_lookout_rail(index: int) -> void:
	var s = main.geometry.lookout_rails[index]
	var a_: Vector2 = s.a
	var b: Vector2 = s.b
	var wood: bool = s.id == 12
	var body: Color = ExpeditionSitesView.ep("729D91" if wood else "738F8B")
	var light: Color = ExpeditionSitesView.ep("D4DAC1" if wood else "C0CFC1")
	var h: float = 28 if wood else 17
	main.draw_line(a_, b, ExpeditionSitesView.ep("4D6D66"), 5)
	main.draw_line(a_ - Vector2(0, h), b - Vector2(0, h), light, 5)
	if wood:
		main.draw_line(a_ - Vector2(0, 12), b - Vector2(0, 12), body, 3)
	for i in range(3):
		var p: Vector2 = a_.lerp(b, i / 2.0)
		main.draw_line(p, p - Vector2(0, h + 3), body, 4 if wood else 6)
		main.draw_line(p - Vector2(1, 1), p - Vector2(1, h + 3), light, 1)

func draw_lookout_object(index: int) -> void:
	var s = main.geometry.lookout_objects[index]
	main.draw_set_transform(s.pos)
	var _sw1 = s.model
	# Coral pavilion, faded sea-green roof and salt-bleached posts.
	if _sw1 == 0:
		for side in range(-1, 2, 2):
			main.draw_line(Vector2(side * 48, 0), Vector2(side * 48, -72), ExpeditionSitesView.ep("586F60"), 8)
			main.draw_line(Vector2(side * 48 - 2, -2), Vector2(side * 48 - 2, -70), ExpeditionSitesView.ep("D9DCC1"), 3)
		main.draw_rect(Rect2(-58, -22, 116, 7), ExpeditionSitesView.ep("7D9A84"))
		main.draw_line(Vector2(-56, -17), Vector2(54, -17), ExpeditionSitesView.ep("D2D8BA"), 2)
		main.terrain_view.fill_static(reef_roof, ExpeditionSitesView.ep("4D9D95"), false)
		main.draw_line(Vector2(-69, -65), Vector2(74, -65), ExpeditionSitesView.ep("CEE0CA"), 6)
		for i in range(13):
			main.draw_line(Vector2(-65 + i * 11, -69), Vector2(-40 + i * 8, -92), ExpeditionSitesView.ep("7DBAB0" if i % 2 == 0 else "397C79"), 2)
		main.draw_line(Vector2(-43, -96), Vector2(56, -96), ExpeditionSitesView.ep("B8D0BC"), 3)
		main.draw_rect(Rect2(-24, -57, 48, 13), ExpeditionSitesView.ep("DCD8B4"))
		main.draw_line(Vector2(-18, -50), Vector2(17, -50), ExpeditionSitesView.ep("497A75"), 2)
	# Illustrated reef identification board.
	# Maritime bearing/chart board with a different palette.
	elif _sw1 == 1 or _sw1 == 5:
		main.draw_line(Vector2(-18, 1), Vector2(-18, -30), ExpeditionSitesView.ep("6B7863"), 5)
		main.draw_line(Vector2(18, 1), Vector2(18, -30), ExpeditionSitesView.ep("6B7863"), 5)
		main.draw_rect(Rect2(-28, -59, 56, 38), ExpeditionSitesView.ep("5E7D72"))
		main.draw_rect(Rect2(-24, -55, 48, 30), ExpeditionSitesView.ep("8AC5B7" if s.model == 1 else "D2C9A6"))
		if s.model == 1:
			for i in range(4):
				var p: Vector2 = Vector2(-17 + i * 11, -32)
				main.draw_line(p, p + Vector2(-3, -12), LandmarkView.CORAL[i], 2)
				main.draw_line(p - Vector2(1, 6), p + Vector2(4, -13), LandmarkView.CORAL[i], 2)
		else:
			main.draw_line(Vector2(-19, -48), Vector2(9, -42), ExpeditionSitesView.ep("6F8C80"), 2)
			main.draw_line(Vector2(9, -42), Vector2(-9, -28), ExpeditionSitesView.ep("6F8C80"), 2)
			main.draw_circle(Vector2(14, -34), 6, ExpeditionSitesView.ep("8E7358"))
			main.draw_line(Vector2(14, -42), Vector2(14, -26), ExpeditionSitesView.ep("DBD5B7"), 1)
	# Air cylinders, fins and diving mask on a marine equipment rack.
	elif _sw1 == 2:
		main.draw_rect(Rect2(-24, -54, 48, 5), ExpeditionSitesView.ep("D7D8BA"))
		for side in range(-1, 2, 2):
			main.draw_line(Vector2(side * 23, 1), Vector2(side * 23, -54), ExpeditionSitesView.ep("698777"), 4)
			main.draw_rect(Rect2(side * 10 - 6, -39, 12, 32), ExpeditionSitesView.ep("D2BE82" if side < 0 else "9EBDC0"))
			main.draw_rect(Rect2(side * 10 - 3, -44, 6, 5), ExpeditionSitesView.ep("475F5A"))
			main.draw_rect(Rect2(side * 10 - 6, -19, 12, 4), ExpeditionSitesView.ep("426A65"))
		main.draw_rect(Rect2(-14, -50, 28, 10), ExpeditionSitesView.ep("456C70"))
		main.draw_rect(Rect2(-10, -48, 8, 5), ExpeditionSitesView.ep("BAD8CB"))
		main.draw_rect(Rect2(2, -48, 8, 5), ExpeditionSitesView.ep("BAD8CB"))
		main.draw_line(Vector2(16, -41), Vector2(24, -51), ExpeditionSitesView.ep("BBA67A"), 3)
		main.draw_line(Vector2(-17, -4), Vector2(-26, 7), ExpeditionSitesView.ep("3F7F83"), 6)
	# Short navigation beacon: masonry plinth, striped body and amber lantern.
	elif _sw1 == 3:
		main.draw_rect(Rect2(-25, -8, 50, 15), ExpeditionSitesView.ep("536F70"))
		main.draw_rect(Rect2(-20, -57, 40, 53), ExpeditionSitesView.ep("D3D7BF"))
		for i in range(3):
			main.draw_rect(Rect2(-20, -51 + i * 18, 40, 8), ExpeditionSitesView.ep("A46C53"))
		main.draw_rect(Rect2(-17, -76, 34, 21), ExpeditionSitesView.ep("3D6468"))
		main.draw_rect(Rect2(-13, -73, 26, 15), ExpeditionSitesView.ep("D8B36F"))
		for side in range(-1, 2, 2):
			main.draw_line(Vector2(side * 7, -74), Vector2(side * 7, -57), ExpeditionSitesView.ep("607773"), 2)
		main.terrain_view.fill_static(beacon_hood, ExpeditionSitesView.ep("426C70"), false)
		main.draw_circle(Vector2(0, -66), 4, Color(1.6, 1.05, 0.43, 0.75 + 0.15 * sin(float(main.clock) * 2)))
		main.draw_rect(Rect2(-6, -19, 12, 16), ExpeditionSitesView.ep("4C6765"))
	# Storm signal mast, with staggered fabric strips rather than another hut.
	elif _sw1 == 4:
		main.draw_line(Vector2(0, 2), Vector2(0, -101), ExpeditionSitesView.ep("4F6F70"), 6)
		main.draw_line(Vector2(-2, 0), Vector2(-2, -101), ExpeditionSitesView.ep("BCC9BA"), 2)
		main.draw_line(Vector2(-7, -103), Vector2(7, -103), ExpeditionSitesView.ep("C4CBB2"), 3)
		for j in range(3):
			for i in range(6):
				main.draw_rect(Rect2(2 + i * 6, -96 + j * 24 + sin(float(main.clock) * 2.2 + i * 0.5 + j) * 3, 6, 12 - i), ExpeditionSitesView.ep("CFA06F" if (i + j) % 2 == 0 else "E4D9B4"))
		main.draw_line(Vector2(0, -62), Vector2(-18, 4), ExpeditionSitesView.ep("8A9B88"), 1)
	# Weathered bench.
	else:
		main.draw_line(Vector2(-22, 0), Vector2(-22, -14), ExpeditionSitesView.ep("546D64"), 4)
		main.draw_line(Vector2(22, 0), Vector2(22, -14), ExpeditionSitesView.ep("546D64"), 4)
		main.draw_rect(Rect2(-28, -21, 56, 11), ExpeditionSitesView.ep("B6C1A2" if s.id == 12 else "A5AAA0"))
		main.draw_line(Vector2(-27, -19), Vector2(27, -19), ExpeditionSitesView.ep("D0D6B9"), 2)
		main.draw_rect(Rect2(-28, -34, 56, 8), ExpeditionSitesView.ep("7D9885"))
	main.draw_set_transform(Vector2.ZERO)
