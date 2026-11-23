class_name WeatherStationView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.WeatherStation.cs.
var weather_roof_world
var weather_roof_alpha: float = 1
var weather_roof_clock: float = 0.0

var weather_interior_active: bool = false

var weather_roof_opacity: float:
	get:
		return weather_roof_alpha

var interior_active: bool:
	get:
		return main.cave_view.cave_interior_active or weather_interior_active

var main: Main

func _init(host: Main) -> void:
	main = host

func hidden_outside_interior(p: Vector2) -> bool:
	return main.cave_view.hidden_outside_cave(p) or weather_interior_active and not main.geometry.weather_room.has_point(p)

func draw_weather_ground(w, view: Rect2) -> void:
	if not w.weather_visibility.grow(80).intersects(view):
		return
	var room: Rect2 = w.weather_room
	if weather_interior_active:
		main.draw_rect(w.weather_visibility, Color("080C10"))
	main.draw_rect(room.grow(9), Color("484F4C"))
	main.draw_rect(room, Color("92958A"))
	var y: float = room.position.y
	while y < room.end.y:
		var x: float = room.position.x
		while x < room.end.x:
			var tile = Rect2(x + 1, y + 1, 30, 30)
			main.draw_rect(tile, Color("A2A497" if LandmarkView.h01(int(x), int(y)) > 0.5 else "989D91"))
			x += 32
		y += 32
	var c: Vector2 = w.weather_centre
	# Worn entrance mat and a desk chair. These are inert room furnishings.
	main.draw_rect(Rect2(c + Vector2(-28, 67), Vector2(56, 33)), Color("5B6658"))
	for i in range(5):
		main.draw_line(c + Vector2(-23, 73 + i * 5), c + Vector2(23, 73 + i * 5), Color("78806A"), 1)
	main.draw_rect(Rect2(c + Vector2(-87, -18), Vector2(23, 21)), Color("484E48"))
	main.draw_rect(Rect2(c + Vector2(-84, -16), Vector2(17, 15)), Color("726C51"))
	main.draw_rect(Rect2(c + Vector2(-84, -22), Vector2(17, 5)), Color("9B9070"))
	main.draw_rect(Rect2(w.weather_entrance + Vector2(-41, -7), Vector2(82, 19)), Color("8A8778"))
	main.draw_line(w.weather_entrance + Vector2(-37, 6), w.weather_entrance + Vector2(37, 6), Color("BBB59A"), 3)

func weather_wall_items(items, view: Rect2) -> void:
	var w = main.geometry
	if main.cave_view.cave_interior_active or not w.weather_visibility.intersects(view):
		return
	var i: int = 0
	while i < w.weather_walls.size():
		var _d1 = w.weather_walls[i]
		var a_ = _d1[0]
		var b = _d1[1]
		items.append([maxf(a_.y, b.y), 14, i])
		i += 1

func draw_weather_wall(index: int) -> void:
	var w = main.geometry
	var _d1 = w.weather_walls[index]
	var a_ = _d1[0]
	var b = _d1[1]
	var lift: Vector2 = Vector2(0, -56)
	main.terrain_view.fill_static(w.weather_wall_faces[index], Color("B5B59E" if index == 0 else "888F80"))
	main.draw_line(a_, b, Color("424E49"), 5)
	main.draw_line(a_ + lift, b + lift, Color("D0CBB0"), 7)
	main.draw_line(a_ + Vector2(0, -18), b + Vector2(0, -18), Color("737E70"), 2)
	for i in range(1, 6):
		var p: Vector2 = a_.lerp(b, i / 6.0).round()
		main.draw_line(p + lift + Vector2(0, 5), p - Vector2(0, 3), Color("939B88"), 1)
	if index == 0:
		var c: Vector2 = w.weather_centre
		# Sealed windows show opaque blue glass, never exterior scenery.
		for side in [-1, 1]:
			var window = Rect2(c + Vector2(side * 88 - 26, -161), Vector2(52, 30))
			main.draw_rect(window.grow(3), Color("555F57"))
			main.draw_rect(window, Color("729699"))
			main.draw_line(window.position + Vector2(26, 0), window.position + Vector2(26, 30), Color("C2C2A5"), 3)
			main.draw_line(window.position + Vector2(3, 6), window.position + Vector2(20, 6), Color("B0C7B9"), 2)
		main.draw_rect(Rect2(c + Vector2(-24, -163), Vector2(48, 33)), Color("DBD4B2"))
		for i in range(4):
			main.draw_line(c + Vector2(-17, -155 + i * 5), c + Vector2(15 - i * 4, -155 + i * 5), Color("7C8B84"), 2)
	if index >= 3:
		var jamb: Vector2 = b if index == 3 else a_
		main.draw_line(jamb, jamb + lift, Color("48594F"), 10)
		main.draw_line(jamb + Vector2(-2, 0), jamb + lift + Vector2(-2, 0), Color("A7AA8C"), 3)

func draw_weather_roof(w, view: Rect2) -> void:
	if not is_same(weather_roof_world, w):
		weather_roof_world = w
		weather_roof_alpha = 1
		weather_roof_clock = float(main.clock)
	var now: float = float(main.clock)
	var dt: float = clampf(now - weather_roof_clock, 0, 0.1)
	weather_roof_clock = now
	weather_roof_alpha = move_toward(weather_roof_alpha, 0 if weather_interior_active else 1, dt * 5)
	if weather_roof_alpha <= 0 or not w.weather_visibility.intersects(view):
		return
	# A raised metal roof covers furniture from outside and peels away on entry.
	var r: Rect2 = Rect2(w.weather_room.position - Vector2(14, 65), w.weather_room.size + Vector2(28, 10))
	var roof: Color = Color("617C72", weather_roof_alpha)
	var seam: Color = Color("405E56", weather_roof_alpha)
	main.draw_rect(r.grow(3), seam)
	main.draw_rect(r, roof)
	var x: float = r.position.x + 7
	while x < r.end.x:
		main.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), seam, 2)
		main.draw_line(Vector2(x + 3, r.position.y), Vector2(x + 3, r.end.y), Color("879B85", weather_roof_alpha), 1)
		x += 16
	main.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color("A2AD90", weather_roof_alpha), 6)
	main.draw_rect(Rect2(r.get_center() + Vector2(70, -28), Vector2(31, 25)), seam)
	for i in range(4):
		main.draw_line(r.get_center() + Vector2(74, -22 + i * 5), r.get_center() + Vector2(96, -22 + i * 5), Color("88998A", weather_roof_alpha), 2)

func draw_weather_isolation(w) -> void:
	if not weather_interior_active:
		return
	var r: Rect2 = w.weather_visibility
	var black: Color = Color("080C10")
	# Overlap the four panels so fractional camera zoom cannot expose a one-pixel seam.
	main.draw_rect(Rect2(-32768, -32768, 65536, r.position.y + 32770), black)
	main.draw_rect(Rect2(-32768, r.end.y - 2, 65536, 32770 - r.end.y), black)
	main.draw_rect(Rect2(-32768, r.position.y - 2, r.position.x + 32769, r.size.y + 4), black)
	main.draw_rect(Rect2(r.end.x - 1, r.position.y - 2, 32769 - r.end.x, r.size.y + 4), black)
	# Fill the narrow apron up to the wall foundations, including the open doorway's outside view.
	main.draw_rect(Rect2(r.position.x, w.weather_room.end.y + 5, r.size.x, r.end.y - w.weather_room.end.y - 5), black)
