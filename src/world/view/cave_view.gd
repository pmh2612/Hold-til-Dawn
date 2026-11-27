class_name CaveView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.CaveView.cs.
var cave_roof_world
var cave_roof_alpha: float = 1
var cave_roof_clock: float = 0.0

var cave_roof_opacity: float:
	get:
		return cave_roof_alpha

var cave_interior_active: bool = false

var main: Main

func _init(host: Main) -> void:
	main = host

func hidden_outside_cave(p: Vector2) -> bool:
	return cave_interior_active and not main.geometry.in_cave_floor(p)

func draw_cave_isolation(w) -> void:
	if not cave_interior_active:
		return
	for mask in w.cave_exterior_masks:
		main.terrain_view.fill_static(mask, Color("080C10"), false)

func draw_cave_roof(w, view: Rect2) -> void:
	if not is_same(cave_roof_world, w):
		cave_roof_world = w
		cave_roof_alpha = 1
		cave_roof_clock = float(main.clock)
	var now: float = float(main.clock)
	var dt: float = clampf(now - cave_roof_clock, 0, 0.1)
	cave_roof_clock = now
	var player: Vector2 = Vector2(main.local_pos)
	var inside: bool = w.is_cave_interior(player)
	cave_roof_alpha = move_toward(cave_roof_alpha, 0 if inside else 1, dt * 4)
	if cave_roof_alpha <= 0 or not Rect2(w.cave_centre - WorldGeometry.cave_radii, WorldGeometry.cave_radii * 2).intersects(view):
		return
	var i: int = 0
	for facet in w.cave_roof_facets:
		var centre: Vector2 = Vector2.ZERO
		for point in facet:
			centre += point
		centre /= facet.size()
		var light: float = clampf((w.cave_centre.y - centre.y) / (22 * 32), -0.25, 0.25)
		var rock: Color = Color("7F8475").lightened(light + (i % 5 - 2) * 0.015)
		rock.a = cave_roof_alpha
		main.terrain_view.fill_static(facet, rock)
		i += 1
	var seam: Color = Color("4D594E", cave_roof_alpha * 0.6)
	for band in w.cave_roof_seams:
		main.draw_polyline(band, seam, 2)
	for k in range(1, w.cave_roof.size(), 3):
		var edge: Vector2 = w.cave_roof[k]
		var in_: Vector2 = edge.lerp(w.cave_centre, 0.32)
		main.draw_line(edge, in_ + Vector2(9, -8), Color("4B574B", cave_roof_alpha * 0.75), 2)
		main.draw_line(in_ + Vector2(9, -8), in_ + Vector2(-4, 20), Color("4B574B", cave_roof_alpha * 0.75), 2)

func draw_cave_walls(w, view: Rect2) -> void:
	if not Rect2(w.cave_centre - WorldGeometry.cave_radii, WorldGeometry.cave_radii * 2).intersects(view):
		return
	var i: int = 0
	for _it1 in w.cave_walls:
		var face = _it1[0]
		var cap = _it1[1]
		var facet = _it1[2]
		var strata = _it1[3]
		var crack = _it1[4]
		if not main.terrain_view.bounds(cap, 80).intersects(view):
			i += 1
			continue
		var side: Color = Color("52564F" if i % 3 == 0 else "5D6056")
		var top: Color = Color("8A8979" if i % 3 == 0 else "77786D" if i % 3 == 1 else "9D9987")
		main.terrain_view.fill_static(face, side)
		main.terrain_view.fill_static(cap, top)
		main.terrain_view.fill_static(facet, top.lightened(0.08))
		main.draw_polyline(strata, side.darkened(0.22), 2)
		main.draw_polyline(crack, Color("464C43"), 2)
		main.draw_line(face[4], face[5], Color("3A4239"), 2)
		i += 1
	for side in range(-1, 2, 2):
		var p: Vector2 = w.cave_entrance + Vector2(0, side * WorldCave.MOUTH_HALF_TILES * 32)
		main.draw_line(p + Vector2(-10, -49), p + Vector2(12, -4), Color("B1AA8D"), 3)
