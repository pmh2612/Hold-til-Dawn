class_name MinimapUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.Minimap.cs.
# Owner: Mai Thien Ngon. Minimap (top left) so players do not get lost on the island: it shows the part of the
# island around you, and M shows the whole island large. Each landmark is a dot where its structure stands
# (WorldGeometry.LmAt), named in black on the large map, the labels kept apart from each other.
# The ground (sea and shallows, beach, grass, safe zone, woods, hills, pond, swamp, concrete) is drawn once into a
# pixel image; landmark dots, towers, doors, pads, teammates, you and the camera view are drawn on top
# every frame. Walking into a landmark's area shows its name at the top of the screen.
# Enemies are not shown: the GDD only shows what players can see (section 6.1).
const MAP_PX: int = 120
# the ground image has twice the pixels, so the large map stays sharp
const MAP_TEX: int = 360
var map_big = false
# the terrain image, drawn with hard pixels on the linearly filtered HUD
var map_tex
# the landmark you are in, and when you walked into it
var here_now
var here_since: float = -99.0
const MAP_INK: Color = Color("141210")
const MAP_HALO: Color = Color(0.96, 0.93, 0.84, 0.75)

# constants shared with Main
const INK = Main.INK
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

# world half-width covered by the map: the island plus a strip of sea
static func map_reach() -> float:
	return 82.0 * IslandMap.SCALE * float(T)

# world half-width the small map shows round you
const MINI_VIEW: float = 41.0

func toggle_map() -> void:
	map_big = not map_big
	if map_big:
		main.inventory.bag_open = false
		main.craft_open = false
		main.build_menu.close_build()

static func kind_colour(kind) -> Color:
	return Color("F2C27D") if kind == "base" or kind == "titanium" else Color("A8D18A") if kind == "wood" else Color("B3E0A3") if kind == "herb" else Color("E8D6AD") if kind == "stone" else Color("DEADD6") if kind == "swamp" else Color("9BD1D1")

func build_map_texture() -> void:
	var im = Image.create_empty(MAP_TEX, MAP_TEX, false, Image.FORMAT_RGBA8)
	var reach: float = map_reach()
	var per: float = 2 * reach / MAP_TEX
	var half: Vector2 = Vector2(GameSim.HALF)
	var safe: float = float(GameSim.SAFE_D)
	var tile: float = float(T)
	var sc: float = IslandMap.SCALE
	var deep: Color = Color("163346")
	var sand: Color = Color("CDB688")
	var shallow = [Color("1E4256"), Color("27546A"), Color("33707F")]
	var outer: Color = Color("5A6F3A")
	var inner: Color = Color("6E8548")
	var woods: Color = Color("4C6230")
	var floor_: Color = Color("4F4B42")
	var wall_: Color = Color("CFC5AC")
	var terrain = main.geometry
	var shade_box = IslandMap.shade.map(func(s): return main.terrain_view.bounds(s, 0))
	var ground_mask = LandmarkGroundMask.new(terrain, Rect2(Vector2.ONE * -reach, Vector2.ONE * (2 * reach)), 3)
	for y in range(MAP_TEX):
		for x in range(MAP_TEX):
			var p = Vector2((x + 0.5) * per - reach, (y + 0.5) * per - reach)
			var d: float = IslandMap.depth(p)
			var col: Color = Color(0, 0, 0, 0)
			if d < 0:
				col = shallow[2] if d > -2 * sc * tile else shallow[1] if d > -5 * sc * tile else shallow[0] if d > -9 * sc * tile else deep
			elif not IslandMap.on_grass(p):
				col = sand
			elif absf(p.x) < half.x and absf(p.y) < half.y:
				col = wall_ if absf(p.x) > half.x - per or absf(p.y) > half.y - per else floor_
			else:
				col = inner if float(WorldGeometry.wall_dist(p)) < safe else outer
				for i in range(IslandMap.shade.size()):
					if shade_box[i].has_point(p) and IslandMap.in_polygon(IslandMap.shade[i], p):
						col = col.lerp(woods, 0.6)
				for h in IslandMap.hills:
					for k in range(h.rings.size()):
						if p.distance_to(h.top) < 14 * sc * tile and IslandMap.in_polygon(h.rings[k], p):
							col = Color("6E8048").lerp(Color("A49C7E"), float(k) / maxi(1, h.rings.size() - 1))
				if p.distance_to(terrain.swamp_centre) < terrain.swamp_r * 0.85:
					col = Color("55583A")
				for pd in terrain.ponds:
					if IslandMap.in_polygon(pd.edge, p):
						col = Color("3B6A86")
			if d >= 0:
				for soil in WorldGeometry.landmark_soils:
					if not terrain.lm_at.has(soil.id):
						continue
					var coverage: float = WorldLandmarkDetails.soil_coverage(soil, p - terrain.soil_centre(soil))
					if coverage > 0 and ground_mask.can_paint(p, 3, true, false):
						col = col.lerp(terrain.cave_ground_colour(p) if soil.id == 16 else Color(soil.hex), coverage)
			# the rivers, and their bridges across them
			if d >= 0 and IslandMap.in_river(p):
				col = Color("9C7A4E") if IslandMap.on_bridge(p) else shallow[2]
			elif d >= 0 and IslandMap.in_river(p, IslandMap.RIVER_BANK):
				col = Color("6B6A45")
			im.set_pixel(x, y, col)
	for _it1 in terrain.floors:
		var f = _it1[0]
		var surface: Color = Color("A9A79C")
		for site in terrain.lookouts.values():
			if site.deck == f:
				surface = Color("B4B69A" if site.id == 12 else "A8B9B0")
		_build_map_texture_fill(f, surface, im, per, reach)
	for d in IslandMap.docks:
		_build_map_texture_fill(d, Color("8C7150"), im, per, reach)
	map_tex = Cs.init(CanvasTexture.new(), {"diffuse_texture": ImageTexture.create_from_image(im), "texture_filter": CanvasItem.TEXTURE_FILTER_NEAREST})

# local function Fill of the method above
func _build_map_texture_fill(f: Rect2, col: Color, im, per, reach) -> void:
	for py in range(int((f.position.y + reach) / per), int((f.end.y + reach) / per) + 1):
		for px_ in range(int((f.position.x + reach) / per), int((f.end.x + reach) / per) + 1):
			if px_ >= 0 and py >= 0 and px_ < MAP_TEX and py < MAP_TEX:
				im.set_pixel(px_, py, col)

func map_rect(vs) -> Rect2:
	if map_big:
		# 480 HUD units = 720 window pixels = 2 per pixel of the ground image, so it stays crisp
		var s: float = minf(4 * MAP_PX, float(vs.y) - 40)
		return Rect2((float(vs.x) - s) / 2, (float(vs.y) - s) / 2, s, s)
	# top left, where the day and timer were (they moved to the top right)
	return Rect2(10, 10, MAP_PX, MAP_PX)

func draw_minimap(c, vs, me) -> void:
	if map_tex == null:
		if main.deco.size() == 0:
			return
		self.build_map_texture()
	var ci = c
	var r: Rect2 = self.map_rect(vs)
	var big: bool = map_big
	# the small map follows you, kept inside the island's square
	var reach: float = map_reach()
	var view: float = reach if big else MINI_VIEW * float(T)
	var focus: Vector2 = Vector2.ZERO if big else Vector2(main.local_pos).clamp(-Vector2.ONE * (reach - view), Vector2.ONE * (reach - view))
	var scale: float = r.size.x / (2 * view)
	var mid: Vector2 = r.get_center()
	var inside: Rect2 = r.grow(-1)
	var dot: float = 3 if big else 2
	main.panel(c, r.grow(4))
	var texel: float = MAP_TEX / (2 * reach)
	var src = Rect2((focus - Vector2.ONE * view + Vector2.ONE * reach) * texel, Vector2.ONE * (2 * view * texel))
	c.draw_texture_rect_region(map_tex, r, src)
	# camera view
	var ct = main.get_viewport().get_canvas_transform()
	var screen: Vector2 = main.get_viewport_rect().size
	var inv: Transform2D = ct.affine_inverse()
	var a_: Vector2 = _draw_minimap_to(inv * Vector2.ZERO, focus, mid, scale)
	var b: Vector2 = _draw_minimap_to(inv * screen, focus, mid, scale)
	var cam_ = Rect2(a_, b - a_).intersection(r)
	if cam_.has_area():
		c.draw_rect(cam_, Color(1, 1, 1, 0.35), false, 1)
	# landmarks: a dot where each one's structure stands, named on the large map
	self.draw_landmark_dots(ci, inside, _draw_minimap_to.bind(focus, mid, scale), big)
	# Two states only: closed lid / raised lid, with the same warm colour.
	for chest in main.snap.get("sup", []):
		var at: Vector2 = _draw_minimap_to(chest[1], focus, mid, scale)
		if not inside.grow(-5).has_point(at):
			continue
		draw_chest_marker(c, at, 1.0 if big else 0.65, bool(chest[4]))
	# towers
	for tw in main.snap.get("tw", []):
		if not inside.has_point(_draw_minimap_to(tw[1], focus, mid, scale)):
			continue
		var tc: Color = Color("F2B544") if tw[2] > 0 and not tw[3] else Color(0.45, 0.45, 0.5)
		c.draw_rect(Rect2(_draw_minimap_to(tw[1], focus, mid, scale) - Vector2.ONE * dot / 2, Vector2.ONE * dot), tc)
	# landing pads: always on the large map, and during the night 5 extension (FML-13)
	var extension: bool = main.snap.k == 5 and main.snap.ph == "night"
	for i in range(3):
		var pp: Vector2 = _draw_minimap_to(SimWorld.pad_pos(i), focus, mid, scale)
		if not inside.has_point(pp):
			continue
		if big:
			ci.draw_arc(pp, float(GameSim.PAD_R) * scale, 0, TAU, 20, Color("9FD3DB"), 1)
		if extension:
			c.draw_arc(pp, 6 if big else 3, 0, TAU, 16, Color(0.5, 1.2, 2.6), 1)
	# doors: steel, amber when damaged, red when broken; the attacked door blinks
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for i in range(3):
		var dur: float = float(main.snap.doors[i])
		var dc: Color = Color("8FA3B8") if dur > 250 else Color("F2B544") if dur > 0 else Color("E0362C")
		if i in main.snap.active:
			dc = dc.lerp(Color("E0362C"), pulse)
		var dp: Vector2 = _draw_minimap_to(GameSim.DOOR_POS[i], focus, mid, scale)
		if not inside.has_point(dp):
			continue
		c.draw_rect(Rect2(dp - Vector2.ONE * (dot / 2 + 1), Vector2.ONE * (dot + 2)), dc)
	# teammates, then you on top with a pulsing ring
	for id in main.snap.ps:
		if id == main.my_id:
			continue
		var p = main.snap.ps[id]
		if p[5] == 2:
			continue
		var pc: Color = Main.ROLE_COL[p[1]]
		if p[5] != 0:
			pc = pc.darkened(0.5)
		var pp: Vector2 = _draw_minimap_to(main.shown_p.get(id, p[2]), focus, mid, scale)
		if not inside.has_point(pp):
			continue
		c.draw_rect(Rect2(pp - Vector2.ONE * (dot / 2 + 2), Vector2.ONE * (dot + 4)), INK)
		c.draw_rect(Rect2(pp - Vector2.ONE * (dot / 2 + 1), Vector2.ONE * (dot + 2)), pc)
		if big:
			main.text(c, pp + Vector2(-40, -6), Cs.s(p[0]), 8, pc.lightened(0.3), 1, 80)
	if me != null:
		var mp: Vector2 = _draw_minimap_to(main.local_pos, focus, mid, scale)
		c.draw_circle(mp, dot + 1.5 + pulse * 1.5, Color(1, 1, 1, 0.25))
		c.draw_rect(Rect2(mp - Vector2.ONE * (dot / 2 + 2), Vector2.ONE * (dot + 4)), Color.WHITE)
		c.draw_rect(Rect2(mp - Vector2.ONE * (dot / 2 + 1), Vector2.ONE * (dot + 2)), Main.ROLE_COL[me[1]])
	if not big:
		main.text(c, r.position + Vector2(3, 10), "M", 10, Color(1, 1, 1, 0.6), 0, -1.0, true)
		self.draw_here_name(c, vs)

# local function To of the method above
static func draw_chest_marker(c, at: Vector2, s: float, opened: bool) -> void:
	var colour = Color("90979B") if opened else Color("D9B36B")
	c.draw_rect(Rect2(at + Vector2(-5, -3) * s, Vector2(10, 7) * s), Color("171D22"))
	c.draw_rect(Rect2(at + Vector2(-4, -2) * s, Vector2(8, 5) * s), colour)
	c.draw_rect(Rect2(at + Vector2(-5, -6 if opened else -4) * s, Vector2(10, 2) * s), colour)
	c.draw_rect(Rect2(at + Vector2(-1, -2) * s, Vector2(2, 3) * s), Color("4D4936"))

func _draw_minimap_to(p, focus, mid, scale) -> Vector2:
	return (mid + (Vector2(p) - focus) * scale).round()

# where each landmark's label sits on the large map, worked out once per map size
var label_plan = []
var label_plan_for: Rect2 = Rect2()
var label_plan_world

func draw_landmark_dots(ci, inside: Rect2, to, big: bool) -> void:
	var w = main.geometry
	var dr: float = 3.5 if big else 2.0
	for l in IslandMap.landmarks:
		var _c1 = l.id == 1
		var at
		if not _c1:
			at = w.landmark_centre(l.id)
			_c1 = not w.lm_at.has(l.id)
		if _c1:
			continue
		var p: Vector2 = to.call(at)
		if not Cs.has_point(inside.grow(-2), p):
			continue
		ci.draw_circle(p, dr + 1.5, MAP_HALO)
		ci.draw_circle(p, dr, MAP_INK)
	if not big:
		return
	var f = main.font_ui
	var size: int = 10
	if label_plan_for != inside or label_plan.size() == 0 or not is_same(label_plan_world, w):
		label_plan_for = inside
		label_plan_world = w
		label_plan.clear()
		var dots = []
		var order = []
		for l in IslandMap.landmarks:
			var _c2 = l.id == 1
			var at
			if not _c2:
				at = w.landmark_centre(l.id)
				_c2 = not w.lm_at.has(l.id)
			if _c2:
				continue
			var p: Vector2 = to.call(at)
			order.append([p, l.name])
			dots.append(Rect2(p - Vector2.ONE * 5, Vector2.ONE * 10))
		# the base sits in the middle: keep labels off it
		dots.append(Rect2(to.call(Vector2.ZERO) - Vector2.ONE * 14, Vector2.ONE * 28))
		var placed_ = []
		for _it3 in order:
			var p = _it3[0]
			var name = _it3[1]
			var sz: Vector2 = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size) + Vector2(4, 0)
			var h: float = sz.y
			# right, left, above, below, then the corners
			var tries = [Vector2(p.x + 7, p.y - h / 2), Vector2(p.x - 7 - sz.x, p.y - h / 2), Vector2(p.x - sz.x / 2, p.y - 6 - h), Vector2(p.x - sz.x / 2, p.y + 6), Vector2(p.x + 5, p.y - 4 - h), Vector2(p.x - 5 - sz.x, p.y - 4 - h), Vector2(p.x + 5, p.y + 4), Vector2(p.x - 5 - sz.x, p.y + 4)]
			var best: Rect2 = Rect2(tries[0], sz)
			var best_cost: float = 3.4028235e38
			for t0 in tries:
				var box_ = Rect2(t0, sz)
				var cost: float = 0
				for o in placed_:
					if o.intersects(box_):
						cost += o.intersection(box_).get_area() + 50
				for o in dots:
					if o.intersects(box_):
						cost += o.intersection(box_).get_area() + 20
				if not inside.grow(-2).encloses(box_):
					cost += 10000
				if cost < best_cost:
					best_cost = cost
					best = box_
				if cost == 0:
					break
			placed_.append(best)
			label_plan.append([p, best, name])
	for _it4 in label_plan:
		var box_ = _it4[1]
		var name = _it4[2]
		var base: Vector2 = Vector2(box_.position.x + 2, box_.position.y + f.get_ascent(size))
		ci.draw_string_outline(f, base, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 1, Color.BLACK)
		ci.draw_string(f, base, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.BLACK)

# the name of the landmark you just walked into, for a few seconds under the radio line
func draw_here_name(c, vs) -> void:
	var here = main.geometry.near_landmark(Vector2(main.local_pos), 8.0 * IslandMap.SCALE * float(T))
	var now: float = float(main.clock)
	if here != here_now:
		here_now = here
		if here != null:
			here_since = now
	if here_now == null:
		return
	var age: float = now - here_since
	if age > 4.0:
		return
	var a_: float = clampf(age / 0.3, 0, 1) * clampf((4.0 - age) / 0.8, 0, 1)
	# under the radio line, which sits lower at night (the night bar)
	var y: float = 116 + EnemyView.NIGHT_BAR_H if main.snap.get("ph", "") == "night" else 142
	main.text(c, Vector2(0, y), here_now.name.to_upper(), 15, Color(Color.BLACK, a_), 1, vs.x, true)
