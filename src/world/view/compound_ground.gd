class_name CompoundGroundView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.CompoundGround.cs.

var main: Main

func _init(host: Main) -> void:
	main = host

func draw_compound_ground(world, view: Rect2) -> void:
	for id in world.compounds:
		var floor_ = world.compounds[id]
		if not floor_.intersects(view):
			continue
		var c: Vector2 = floor_.get_center()
		if id == 6:
			# The exposed foundations still describe the old building's rooms, with an open central corridor.
			var foundation: Color = Color("64675D")
			var scorch: Color = Color("444A43", 0.45)
			main.draw_line(floor_.position + Vector2(8, 25), Vector2(floor_.end.x - 8, floor_.position.y + 25), foundation, 9)
			main.draw_line(floor_.position + Vector2(13, 25), Vector2(floor_.position.x + 13, floor_.end.y - 12), foundation, 8)
			main.draw_line(c + Vector2(32, -72), c + Vector2(32, -15), foundation, 6)
			main.draw_line(c + Vector2(32, -15), c + Vector2(110, -15), foundation, 6)
			main.draw_set_transform(c + Vector2(-79, 3), 0, Vector2(1.5, 0.65))
			main.draw_circle(Vector2.ZERO, 41, scorch)
			main.draw_set_transform(Vector2.ZERO)
			for i in range(23):
				var x: float = -127 + i * 47 % 225
				var y: float = -70 + i * 29 % 150
				var p: Vector2 = c + Vector2(x, y)
				if Cs.has_point(floor_.grow(-9), p):
					main.draw_line(p, p + Vector2(12 + i % 12, 4), Color("575E56"), 1)
					main.draw_line(p + Vector2(12 + i % 12, 4), p + Vector2(15 + i % 12, 11), Color("575E56"), 1)
			# Fallen roof trusses and fragments lie in the side bays, leaving the centre navigable.
			for side in range(-1, 2, 2):
				for i in range(7):
					var p: Vector2 = c + Vector2(side * (60 + i * 17 % 76), -62 + i * 23)
					main.draw_set_transform(p, i * 0.53)
					main.draw_rect(Rect2(-7, -3, 14 + i % 3 * 3, 6), ExpeditionSitesView.ep("A8AB99" if i % 2 == 0 else "75837A"))
					main.draw_line(Vector2(-7, -3), Vector2(7 + i % 3 * 3, -3), ExpeditionSitesView.ep("C5C3AC"), 1)
					main.draw_set_transform(Vector2.ZERO)
			for side in range(-1, 2, 2):
				var a_: Vector2 = c + Vector2(side * 52, -48)
				var b: Vector2 = c + Vector2(side * 140, -10)
				main.draw_line(a_, b, ExpeditionSitesView.ep("4E5F59"), 6)
				main.draw_line(a_ - Vector2(0, 2), b - Vector2(0, 2), ExpeditionSitesView.ep("ABB3A4"), 2)
				for i in range(1, 5):
					var p: Vector2 = a_.lerp(b, i / 5.0)
					main.draw_line(p - Vector2(9, 7), p + Vector2(9, -7), ExpeditionSitesView.ep("8D7560"), 3)
		elif id == 13:
			var paint: Color = Color("CFB46E", 0.7)
			var worn: Color = Color("C8B077", 0.35)
			# Longitudinal forklift aisle, marked loading rectangles and drainage at the seaward edge.
			var lane_y: float = c.y + 6
			var x: float = floor_.position.x + 18
			while x < floor_.end.x - 20:
				main.draw_line(Vector2(x, lane_y), Vector2(x + 15, lane_y), worn, 2)
				x += 28
			for x_2 in [-142.0, 142.0]:
				var bay = Rect2(c + Vector2(x_2 - 99, -135), Vector2(198, 65))
				main.draw_rect(bay, paint, false, 2)
			main.draw_rect(Rect2(c + Vector2(-255, 73), Vector2(197, 55)), paint, false, 2)
			for i in range(7):
				var a_: Vector2 = c + Vector2(-35 + i * 11, 103)
				main.draw_line(a_, a_ + Vector2(18, -19), paint, 3)
			var y: float = floor_.position.y + 20
			while y < floor_.end.y - 12:
				main.draw_rect(Rect2(floor_.end.x - 10, y, 5, 3), Color("4C5552"))
				y += 8
			for side in range(-1, 2, 2):
				for i in range(13):
					var p: Vector2 = c + Vector2(-104 + i * 10, 46 + side * 9 + i % 3)
					main.draw_line(p, p + Vector2(6, 0), Color("515A54", 0.38), 2)
			main.draw_set_transform(c + Vector2(-102, 44), 0, Vector2(1.4, 0.6))
			main.draw_circle(Vector2.ZERO, 15, Color("414B46", 0.5))
			main.draw_set_transform(Vector2.ZERO)
			# Entry inspection lane, drainage and a rolling-gate track inside the expanded perimeter.
			var gate: Vector2 = world.compound_gates[13]
			main.draw_line(gate - Vector2(75, 0), gate + Vector2(75, 0), ExpeditionSitesView.ep("444E4C"), 4)
			main.draw_line(gate - Vector2(75, -5), gate + Vector2(75, 5), ExpeditionSitesView.ep("AFB2A0"), 1)
			for i in range(7):
				var p: Vector2 = c + Vector2(-20 + i * 7, 121)
				main.draw_line(p, p + Vector2(-8, 12), paint, 2)
