class_name HerbGardenView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.HerbGarden.cs.

var main: Main

func _init(host: Main) -> void:
	main = host

func draw_garden_ground(w, view: Rect2) -> void:
	if not w.garden_bounds.grow(70).intersects(view):
		return
	var rim: Color = Color("776449")
	var soil: Color = Color("514A34")
	var furrow: Color = Color("3C3E2D")
	# Packed, muted earth along the gate and a wide central aisle between six cultivated beds.
	main.draw_rect(Rect2(w.garden_centre + Vector2(-37, -171), Vector2(74, 364)), Color("8B8060"))
	for bed in w.garden_beds:
		main.draw_rect(bed.grow(4), rim)
		main.draw_rect(bed, soil)
		var y: float = bed.position.y + 13
		while y < bed.end.y - 6:
			main.draw_line(Vector2(bed.position.x + 6, y), Vector2(bed.end.x - 6, y + 1), furrow, 2)
			y += 14
		main.draw_line(bed.position, Vector2(bed.end.x, bed.position.y), Color("9D8961"), 3)
		main.draw_line(Vector2(bed.position.x, bed.end.y), bed.end, Color("564A36"), 3)

func garden_fence_items(items, view: Rect2) -> void:
	var w = main.geometry
	if not w.garden_bounds.grow(70).intersects(view) or main.weather_station.interior_active:
		return
	var i: int = 0
	while i < w.garden_fence.size():
		var _d1 = w.garden_fence[i]
		var a_ = _d1[0]
		var b = _d1[1]
		if Rect2(a_.min(b), (b - a_).abs()).grow(64).intersects(view):
			items.append([maxf(a_.y, b.y), 13, i])
		i += 1

func draw_garden_fence(index: int) -> void:
	var _d1 = main.geometry.garden_fence[index]
	var a_ = _d1[0]
	var b = _d1[1]
	var shade: Color = Color("403C2B")
	var wood: Color = Color("84734C")
	var lit: Color = Color("AC9564")
	main.draw_line(a_ + Vector2(0, -17), b + Vector2(0, -17), shade, 6)
	main.draw_line(a_ + Vector2(0, -31), b + Vector2(0, -31), wood, 5)
	for i in range(4):
		var p: Vector2 = a_.lerp(b, i / 3.0).round()
		var h: float = 49 if i == 0 else 36 + (index * 7 + i * 3) % 9
		main.draw_line(p, p + Vector2(2 if i == 2 else 0, -h), shade, 7)
		main.draw_line(p + Vector2(-1, -2), p + Vector2(-1, -h + 3), wood, 4)
		main.draw_line(p + Vector2(-2, -h), p + Vector2(2, -h), lit, 2)
	if index % 3 == 0:
		var p: Vector2 = a_.lerp(b, 0.5)
		main.draw_line(p - Vector2(4, 5), p + Vector2(5, -31), Color("475D36"), 2)
		for i in range(4):
			main.draw_rect(Rect2((p + Vector2(-5 if i % 2 == 0 else 3, -6 - i * 7)).round(), Vector2(7, 3)), Color("65834A"))
