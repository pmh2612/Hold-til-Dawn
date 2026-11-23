class_name ExpeditionSitesView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.ExpeditionSites.cs.
static var expedition_palette = {}

var main: Main

func _init(host: Main) -> void:
	main = host

static func ep(hex_) -> Color:
	var c = expedition_palette.get(hex_, Color(0, 0, 0, 0))
	if not expedition_palette.has(hex_):
		c = Color(hex_)
		expedition_palette[hex_] = c
	return c

# Cached outlines are immutable: FillStatic triangulates each one only once.
static var jeep_bonnet = [Vector2(-72, -38), Vector2(-55, -51), Vector2(-17, -47), Vector2(-13, -28), Vector2(-70, -25)]
static var open_bonnet = [Vector2(-59, -50), Vector2(-55, -77), Vector2(-20, -71), Vector2(-18, -47)]
static var broken_door = [Vector2(-4, -33), Vector2(12, -62), Vector2(38, -57), Vector2(29, -24)]
static var truck_top = [Vector2(-28, -66), Vector2(-12, -82), Vector2(81, -82), Vector2(91, -66)]

func expedition_items(items, view: Rect2) -> void:
	if main.weather_station.interior_active:
		return
	var w = main.geometry
	var i: int = 0
	while i < w.expedition_vehicles.size():
		var v = w.expedition_vehicles[i]
		if Cs.has_point(view.grow(155), v.pos):
			items.append([v.pos.y, 16, i])
		i += 1
	i = 0
	while i < w.expedition_cliffs.size():
		var f = w.expedition_cliffs[i]
		if Cs.has_point(view.grow(100), (f.a + f.b) / 2):
			items.append([maxf(f.a.y, f.b.y), 17, i])
		i += 1

func draw_expedition_vehicle(index: int) -> void:
	var v = main.geometry.expedition_vehicles[index]
	main.draw_set_transform(v.pos.round(), v.tilt)
	var jeep: bool = v.model == 0
	var left: int = -76 if jeep else -94
	var right: int = 75 if jeep else 94
	# A low 3/4-view chassis with distinct exposed engine, cabin, doors and cargo bed.
	main.draw_rect(Rect2(left + 8, -15, right - left, 23), Color("262A24", 0.40))
	main.draw_rect(Rect2(left, -29, right - left, 20), ep("242D29"))
	main.draw_rect(Rect2(left + 2, -34, right - left - 4, 14), ep("64715A"))
	main.draw_line(Vector2(left, -33), Vector2(right, -33), ep("A9A080"), 3)
	if jeep:
		main.terrain_view.fill_static(jeep_bonnet, ep("7C8164"), false)
		# The hood is folded up, exposing the engine block.
		main.draw_rect(Rect2(-61, -48, 40, 17), ep("1B292A"))
		for i in range(4):
			main.draw_rect(Rect2(-56 + i * 8, -44, 5, 10), ep("8B9290"))
		main.terrain_view.fill_static(open_bonnet, ep("6C7758"), false)
		main.draw_line(Vector2(-54, -73), Vector2(-24, -68), ep("ACAD8C"), 2)
		main.draw_rect(Rect2(-15, -72, 65, 38), ep("303D35"))
		main.draw_rect(Rect2(-18, -77, 70, 8), ep("9B9B76"))
		main.draw_rect(Rect2(-10, -66, 27, 21), ep("527C80"))
		main.draw_rect(Rect2(22, -65, 23, 20), ep("263B3C"))
		main.draw_line(Vector2(-8, -48), Vector2(11, -64), ep("ADC3B4"), 2)
		main.draw_line(Vector2(26, -64), Vector2(33, -54), ep("171F1C"), 2)
		main.draw_line(Vector2(33, -54), Vector2(44, -58), ep("171F1C"), 2)
		main.terrain_view.fill_static(broken_door, ep("8B9C8D"), false)
		main.draw_line(Vector2(12, -58), Vector2(31, -54), ep("C5CCB8"), 2)
		main.draw_rect(Rect2(48, -49, 23, 20), ep("4B624C"))
		main.draw_line(Vector2(50, -47), Vector2(67, -47), ep("91A17B"), 2)
		main.draw_line(Vector2(left, -27), Vector2(left - 4, -18), ep("A4AAA0"), 5)
		main.draw_circle(Vector2(left + 10, -26), 4, ep("CFBE86"))
	else:
		main.draw_rect(Rect2(-89, -54, 23, 24), ep("737F61"))
		main.draw_rect(Rect2(-66, -82, 37, 54), ep("4E6454"))
		main.draw_rect(Rect2(-69, -85, 43, 6), ep("9A9C79"))
		main.draw_rect(Rect2(-61, -75, 26, 23), ep("29464D"))
		main.draw_line(Vector2(-59, -55), Vector2(-41, -72), ep("9CB8AF"), 2)
		main.draw_rect(Rect2(-59, -44, 23, 12), ep("76846C"))
		main.draw_rect(Rect2(-41, -46, 7, 2), ep("BCC4AB"))
		main.draw_rect(Rect2(-27, -37, 118, 14), ep("535F49"))
		if v.model == 1:
			main.draw_rect(Rect2(-27, -68, 118, 30), ep("767D5D"))
			main.terrain_view.fill_static(truck_top, ep("9A9C74"), false)
			for i in range(5):
				main.draw_line(Vector2(-20 + i * 25, -65), Vector2(-20 + i * 25, -39), ep("545E43"), 3)
				main.draw_line(Vector2(-20 + i * 25, -65), Vector2(-9 + i * 25, -79), ep("BCB58B"), 2)
			main.draw_line(Vector2(43, -57), Vector2(55, -47), ep("2C352B"), 3)
			main.draw_line(Vector2(55, -47), Vector2(62, -53), ep("2C352B"), 3)
		else:
			for i in range(4):
				var x: float = -24 + i * 37
				main.draw_line(Vector2(x, -37), Vector2(x, -81), ep("8D9C91"), 3)
				if i < 3:
					main.draw_line(Vector2(x, -81), Vector2(x + 37, -81), ep("B4BAA4"), 2)
			for i in range(3):
				var box_ = Rect2(-15 + i * 32, -59 - i % 2 * 11, 29, 23 + i % 2 * 11)
				main.draw_rect(box_, ep("9F6B43" if v.model == 3 else "7D8B79"))
				main.draw_rect(box_, ep("39473A"), false, 2)
				main.draw_line(box_.position + Vector2(4, 3), box_.end - Vector2(4, 3), ep("C1B48A"), 2)
				main.draw_line(box_.position + Vector2(box_.size.x - 4, 3), box_.position + Vector2(4, box_.size.y - 3), ep("39473A"), 2)
			# Torn canvas hangs from the rear hoop, exposing the cargo.
			main.draw_rect(Rect2(-24, -79, 38, 9), ep("7F8760"))
			for i in range(4):
				main.draw_rect(Rect2(-24 + i * 8, -70, 5, 8 + i % 2 * 6), ep("636F50"))
			main.draw_line(Vector2(91, -36), Vector2(106, -22), ep("87907B"), 4)
		for i in range(7):
			main.draw_rect(Rect2(-22 + i * 17, -34, 2, 9), ep("ABB098"))
		main.draw_rect(Rect2(-98, -26, 9, 8), ep("A3A995"))
		main.draw_circle(Vector2(-82, -38), 4, ep("D2C793"))
	# Rust patches, exposed bare metal and punctured tyres retain their silhouette at game zoom.
	for i in range(9):
		main.draw_rect(Rect2(left + 12 + i * 16, -29 - i % 3 * 3, 7 + i % 3 * 2, 3), ep("935A36" if i % 2 == 0 else "BEC1A2"))
	for i in range(30):
		var p: Vector2 = Vector2(left + 8 + i * 43 % (right - left - 15), -24 + i % 3 * 3)
		main.draw_rect(Rect2(p, Vector2(2 + i % 3, 1)), ep("C6C4A8" if i % 3 == 0 else "A66F49" if i % 3 == 1 else "3C4E3B"))
	draw_expedition_wheel(Vector2(-48 if jeep else -64, -5), 14 if jeep else 16, v.model == 3)
	draw_expedition_wheel(Vector2(49 if jeep else 38, -5), 14 if jeep else 16, true)
	if not jeep:
		draw_expedition_wheel(Vector2(72, -5), 16, false)
	main.draw_set_transform(Vector2.ZERO)

func draw_expedition_wheel(p: Vector2, radius: float, flat: bool) -> void:
	main.draw_circle(p, radius, ep("18221F"))
	main.draw_circle(p, radius - 3, ep("37413A"))
	main.draw_circle(p, radius - 6, ep("8B9381"))
	main.draw_circle(p, 3, ep("303E36"))
	for i in range(6):
		var d: Vector2 = Vector2.from_angle(i * TAU / 6)
		main.draw_line(p + d * (radius - 3), p + d * (radius - 1), ep("5A6252"), 2)
	if flat:
		main.draw_rect(Rect2(p + Vector2(-radius + 2, radius - 6), Vector2(radius * 2 - 4, 7)), ep("514F3D"))

func draw_expedition_cliff(index: int) -> void:
	var f = main.geometry.expedition_cliffs[index]
	main.terrain_view.fill_static(f.face, ep("676F67"))
	main.terrain_view.fill_static(f.cap, ep("B2B09A"))
	main.draw_line(f.a, f.b, ep("444F49"), 3)
	for i in range(1, 4):
		var lift: Vector2 = Vector2(0, -i * 7)
		main.draw_line(f.a + lift, f.b + lift, ep("929783" if i == 2 else "7C8477"), 2)
	var crack: Vector2 = f.a.lerp(f.b, 0.55)
	main.draw_line(crack - Vector2(3, 27), crack + Vector2(2, -13), ep("4E5C54"), 2)
	main.draw_line(crack + Vector2(2, -13), crack + Vector2(-5, -3), ep("4E5C54"), 2)
	for i in range(12):
		var p: Vector2 = f.a.lerp(f.b, (i + 1) / 14.0) + Vector2(0, -38 - i % 3 * 4)
		main.draw_rect(Rect2(p.round(), Vector2(3 + i % 3, 2)), ep("D1C9AA" if i % 2 == 0 else "879486"))

func draw_expedition_ground(w, view: Rect2) -> void:
	for site in w.expedition_sites.values():
		if not Rect2(site.centre - site.half, site.half * 2).grow(90).intersects(view):
			continue
		var c: Vector2 = site.centre
		if site.id == 11:
			# Broad stone treads make the ascent readable even after the former yellow routes were removed.
			for i in range(23):
				var y: float = -173 + i * 16
				var width: float = 51 + (i % 3 - 1) * 3
				main.draw_rect(Rect2(c + Vector2(-width, y + 3), Vector2(width * 2, 12)), ep("5B6D69"))
				main.draw_rect(Rect2(c + Vector2(-width, y), Vector2(width * 2, 10)), ep("ACB7B0" if i % 3 == 0 else "929F99"))
				main.draw_line(c + Vector2(-width + 2, y), c + Vector2(width - 2, y), ep("C1CAC2"), 2)
				# Offset joints, missing corners and weathering break up the regular stair silhouette.
				var joint: float = -18 + i % 3 * 11
				main.draw_line(c + Vector2(joint, y + 1), c + Vector2(joint - 2, y + 10), ep("657871"), 2)
				main.draw_line(c + Vector2(joint + 32, y + 1), c + Vector2(joint + 30, y + 9), ep("657871"), 1)
				main.draw_rect(Rect2(c + Vector2(-width if i % 2 == 0 else width - 5, y + 6), Vector2(5, 4)), ep("717E71"))
				var crack: float = -21 + i * 17 % 39
				main.draw_line(c + Vector2(crack, y + 2), c + Vector2(crack + 4, y + 8), ep("778272"), 1)
			for side in range(-1, 2, 2):
				for i in range(6):
					var p: Vector2 = c + Vector2(side * 66, -186 + i * 75)
					main.draw_line(p, p + Vector2(0, -22), ep("5B6352"), 4)
					main.draw_line(p + Vector2(-1, -22), p + Vector2(-1, -4), ep("B9B192"), 1)
					if i < 5:
						main.draw_line(p + Vector2(0, -18), p + Vector2(0, 57), ep("9A9575"), 2)
			# A separate pennant makes the direction of the north wind visible.
			var flag: Vector2 = c + Vector2(-77, -179)
			main.draw_line(flag, flag + Vector2(0, -52), ep("535E57"), 3)
			for i in range(7):
				main.draw_rect(Rect2(flag + Vector2(2 + i * 5, -51 + sin(float(main.clock) * 2 + i * 0.5) * 3), Vector2(5, 11 - i)), ep("C7B483" if i % 2 == 0 else "885D42"))
			continue
		# Churned mud under each vehicle, with tyre ruts on both sides of each wheel line.
		for v in w.expedition_vehicles:
			if v.id != site.id:
				continue
			main.draw_set_transform(v.pos + Vector2(0, 3), v.tilt, Vector2(1, 0.28))
			main.draw_circle(Vector2.ZERO, 83 if v.model == 0 else 104, ep("5C5945"))
			main.draw_circle(Vector2(13, 9), 60 if v.model == 0 else 81, ep("69624B"))
			main.draw_set_transform(Vector2.ZERO)
			for i in range(16):
				for side in range(-1, 2, 2):
					var p: Vector2 = v.pos + Vector2(-112 + i * 13, side * 21 + 9)
					main.draw_line(p, p + Vector2(7, 2), ep("544D3D"), 3)
		if site.id == 5:
			for i in range(16):
				for side in range(-1, 2, 2):
					var p: Vector2 = c + Vector2(-160 + i * 7, -110 + i * 6 + side * 16)
					main.draw_line(p, p + Vector2(5, 4), ep("605A46"), 4)
			main.draw_line(c + Vector2(74, -9), c + Vector2(145, 1), ep("C0B9A0"), 2)
			main.draw_line(c + Vector2(82, -6), c + Vector2(115, 5), ep("5B6256"), 1)
			main.draw_set_transform(c + Vector2(-41, 8), 0, Vector2(1, 0.45))
			main.draw_circle(Vector2.ZERO, 25, ep("3B443D"))
			main.draw_set_transform(Vector2.ZERO)
			# A detached door and bonnet fragments remain on the ground, away from the walking aisle.
			main.draw_rect(Rect2(c + Vector2(54, 98), Vector2(39, 17)), ep("5E7464"))
			main.draw_rect(Rect2(c + Vector2(59, 100), Vector2(23, 9)), ep("89A4A0"))
			main.draw_circle(c + Vector2(-160, 18), 13, ep("2B322C"))
			main.draw_circle(c + Vector2(-160, 18), 6, ep("8B8F7D"))
		else:
			# Spilled timber and steel cargo lies between the stopped trucks, off the central passage.
			for i in range(7):
				var p: Vector2 = c + Vector2(91 + i * 11, 118 + i % 3 * 6)
				main.draw_line(p, p + Vector2(34, -5), ep("A29C7D" if i % 2 == 0 else "78694D"), 5)
				main.draw_line(p, p + Vector2(29, -4), ep("C3B799"), 1)
