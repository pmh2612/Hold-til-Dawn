class_name LandmarkView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.LandmarkView.cs.
# Owner: Vu Duc Viet Anh. What the landmarks of src/world/world_landmarks.gd lay flat on the ground layer: the
# cracked concrete of the Ruined Base and the Container Yard with grass in the joints, the Old Fishing Pier and
# the South Cape platform (sprites from tools/PixelLandmarks.cs), the
# coral reef under the Coral Lookout and the lily pads on the Rainwater Pond. Their standing parts (walls,
# containers, the ship, the bluff...) are depth-sorted scenery like the trees.
const SLAB: Color = Color("8B8D88")
const SLAB_LIT: Color = Color("A2A49E")
const SLAB_JOINT: Color = Color("6C6E6A")
const SLAB_EDGE: Color = Color("55574F")
static var CORAL = [Color("D9788A"), Color("E09A5A"), Color("5FB8A8"), Color("9A7AC8"), Color("E3C46A")]
const LILY: Color = Color("4E8C46")
const LILY_LIT: Color = Color("6FAE5A")

# constants shared with Main
const COLD = Main.COLD
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

static func h01(x: int, y: int) -> float:
	return float((Cs.u32(x * 374761393 + y * 668265263) ^ 0x5bd1e995) % 1000) / 1000.0

func draw_landmark_ground(w, view: Rect2) -> void:
	var tl: float = float(T)
	for _it1 in w.floors:
		var f = _it1[0]
		var drawn = _it1[1]
		if drawn and f.intersects(view):
			draw_slab(f)
	for _it2 in w.lm_ground:
		var p = _it2[0]
		var name = _it2[1]
		if Cs.has_point(view.grow(12 * tl), p):
			main.sprite(name, p, WorldGeometry.LANDMARK_SCALE, COLD)
	var clk: float = float(main.clock)
	main.lookouts.draw_lookout_ground(w, view, clk)
	main.compound_ground.draw_compound_ground(w, view)
	main.expedition_sites.draw_expedition_ground(w, view)
	main.cave_view.draw_cave_walls(w, view)
	main.herb_garden.draw_garden_ground(w, view)
	main.weather_station.draw_weather_ground(w, view)
	main.fishing_pier.draw_fishing_life(w, view, clk)

# a concrete slab: joints every two tiles, a darker edge, cracks and grass growing through
func draw_slab(f: Rect2) -> void:
	var tl: float = float(T)
	main.draw_rect(f.grow(2), SLAB_EDGE)
	main.draw_rect(f, SLAB)
	# a few panels lighter or darker
	var y: float = f.position.y
	while y < f.end.y - 1:
		var x: float = f.position.x
		while x < f.end.x - 1:
			var h: float = h01(int(x), int(y))
			var panel_ = Rect2(x, y, minf(2 * tl, f.end.x - x), minf(2 * tl, f.end.y - y))
			if h > 0.7:
				main.draw_rect(panel_, SLAB_LIT)
			elif h < 0.18:
				main.draw_rect(panel_, Color("7D7F7A"))
			# a crack across the panel
			if h > 0.45 and h < 0.65:
				var a_: Vector2 = panel_.position + Vector2(panel_.size.x * h, 2)
				var b: Vector2 = a_ + Vector2(10 - 20 * h01(int(y), int(x)), panel_.size.y * 0.45)
				var c: Vector2 = b + Vector2(8 * (h - 0.5) * 10, panel_.size.y * 0.4)
				main.draw_line(a_.round(), b.round(), SLAB_JOINT, 1)
				main.draw_line(b.round(), c.round(), SLAB_JOINT, 1)
			x += 2 * tl
		y += 2 * tl
	var x: float = f.position.x + 2 * tl
	while x < f.end.x - 1:
		main.draw_line(Vector2(x, f.position.y).round(), Vector2(x, f.end.y).round(), SLAB_JOINT, 1)
		x += 2 * tl
	y = f.position.y + 2 * tl
	while y < f.end.y - 1:
		main.draw_line(Vector2(f.position.x, y).round(), Vector2(f.end.x, y).round(), SLAB_JOINT, 1)
		y += 2 * tl
	# grass in the joints and along the edge
	for i in range(int(f.size.x * f.size.y / (tl * tl) * 0.8)):
		var hx: float = h01(i, int(f.position.x))
		var hy: float = h01(int(f.position.y), i)
		var edge: bool = i % 3 == 0
		var p: Vector2 = Vector2(f.position.x + hx * f.size.x, f.position.y + 1 if hy > 0.5 else f.end.y - 2) if edge else Vector2(f.position.x + Cs.round_even(hx * f.size.x / (2 * tl)) * 2 * tl, f.position.y + hy * f.size.y)
		if not f.has_point(p):
			continue
		p = p.round()
		main.draw_rect(Rect2(p, Vector2(1, 3)), Color("5F7A3A"))
		main.draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 2)), Color("7A9648"))
		main.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(1, 2)), Color("4C6530"))

func draw_lilies(pd) -> void:
	for i in range(9):
		var p: Vector2 = (pd.centre + Vector2.from_angle(i * 2.3 + 0.6) * pd.radius * (0.35 + 0.07 * i) * Vector2(1.2, 0.85)).round()
		var rr: float = 4 + i % 3
		main.draw_circle(p + Vector2(1, 1), rr, Color(0.05, 0.1, 0.12, 0.35))
		main.draw_circle(p, rr, LILY)
		main.draw_circle(p + Vector2(-1, -1), rr - 2, LILY_LIT)
		# the notch
		main.draw_line(p, p + Vector2.from_angle(i * 1.7) * rr, Color("2F5A75"), 2)
		if i % 4 == 1:
			main.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(3, 2)), Color("F0B8D0"))
			main.draw_rect(Rect2(p + Vector2(0, -3), Vector2(1, 1)), Color("FFF0F6"))
