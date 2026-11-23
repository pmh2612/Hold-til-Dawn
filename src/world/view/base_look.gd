class_name BaseLookView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.BaseLook.cs.
# Owner: Vu Duc Viet Anh. How the base looks: weathered concrete walls (cream concrete with pilasters, rust runs and moss
# at the foot), the paved stone floor inside, and the warm lamps on the door pillars and the north wall that light it
# at night. The roof seen from outside (src/world/view/base_fog.gd) uses the same concrete for its rim, so walls and
# roof read as one building. All drawn in code, pixel by pixel, with a fixed hash so nothing flickers.
# the base walls are passed to Wall() with this top colour (Main.WallItems); Wall() hands them to ConcreteWall
const BASE_WALL_TOP: Color = Color("8A8F98")
# concrete
const CON_TOP: Color = Color("CFC5AC")
const CON_TOP_D: Color = Color("B4AA90")
const CON_TOP_L: Color = Color("E2D9C3")
const CON_FACE: Color = Color("B5AA90")
const CON_FACE_L: Color = Color("C3B89E")
const CON_FACE_D: Color = Color("968B74")
const CON_PIL: Color = Color("C8BDA3")
const CON_GRIME: Color = Color("7A705C")
const RUST: Color = Color("9C5B33")
const RUST_D: Color = Color("74401F")
const MOSS: Color = Color("6E7B38")
const MOSS_D: Color = Color("55602A")
# paving inside
const PAVE_A: Color = Color("6F6A5E")
const PAVE_B: Color = Color("847E70")
const PAVE_SEAM: Color = Color("4F4B42")
const PAVE_LIT: Color = Color("958F80")
# lamps: wall sconces on the north wall (x positions) and one on top of every door pillar
static var SCONCE_X = [-150.0, 150.0]
const LAMP_LIGHT: Color = Color("FF9A3C")
const LAMP_HOT: Color = Color(2.4, 1.6, 0.6)
const PILASTER_EVERY: int = 96
var base_lamps = []

# constants shared with Main
const INK = Main.INK
const T = Main.T
const WALL_H = Main.WALL_H

var main: Main

func _init(host: Main) -> void:
	main = host

static func hash_(x: int, y: int) -> int:
	# C# int arithmetic: wraps at 32 bits
	var h: int = Cs.i32(x * 374761393 + y * 668265263)
	h = Cs.i32((h ^ (h >> 13)) * 1274126177)
	return (h ^ (h >> 16)) & 0x7fffffff

static func mod(a_: int, m: int) -> int:
	return (a_ % m + m) % m

func px(x: float, y: float, w: float, h: float, c: Color) -> void:
	main.draw_rect(Rect2(x, y, w, h), c)

static func a(c: Color, alpha: float) -> Color:
	c.a = alpha
	return c

# A horizontal wall whose front face looks into the base (the north wall, door B's gate and pillars): under the
# roof, seen from outside, that face is hidden.
func face_under_roof(r: Rect2) -> bool:
	var h: Vector2 = Vector2(GameSim.HALF)
	var c: Vector2 = r.get_center()
	return main.base_fog_view.base_fog > 0.5 and r.size.x >= r.size.y and c.y < 0 and absf(c.x) < h.x

# Same shape as Main.Wall: the top face lifted by Height, the front face below it, ink edges. Hide is how much of the
# front face, from the bottom, is not drawn (-1: all of it when it faces into a roofed base).
func concrete_wall(r: Rect2, height: float, cap: bool, hide: float = -1.0) -> void:
	var top = Rect2(r.position - Vector2(0, height), r.size)
	var f = Rect2(r.position.x, r.end.y - height, r.size.x, height)
	if hide < 0:
		hide = height if self.face_under_roof(r) else 0.0
	var face_end: float = f.end.y - hide
	var face: bool = face_end > f.position.y + 0.5
	if face:
		self.concrete_face(Rect2(f.position, Vector2(f.size.x, face_end - f.position.y)), hide <= 0.0)
	self.concrete_top(top, r.size.x >= r.size.y)
	var bottom: float = face_end if face else top.end.y
	# seen from outside, the wall tops run straight on into the roof (src/world/view/base_fog.gd): no ink
	# line along an edge the roof touches
	var roof: Rect2 = BaseFogView.roof_rect()
	var seam = Color(INK, INK.a * (1.0 - smoothstep(0.0, 1.0, main.base_fog_view.base_fog)))
	main.draw_line(Vector2(top.position.x, top.position.y), Vector2(top.position.x, bottom), _concrete_wall_ink(absf(top.position.x - roof.end.x) < 1.0, seam), 2)
	main.draw_line(Vector2(top.end.x, top.position.y), Vector2(top.end.x, bottom), _concrete_wall_ink(absf(top.end.x - roof.position.x) < 1.0, seam), 2)
	main.draw_line(Vector2(top.position.x, bottom), Vector2(top.end.x, bottom), _concrete_wall_ink(absf(bottom - roof.position.y) < 1.0, seam), 2)
	if cap:
		main.draw_line(top.position, Vector2(top.end.x, top.position.y), _concrete_wall_ink(absf(top.position.y - roof.end.y) < 1.0, seam), 2)
	# the lamps on the inside of the north wall
	if face and hide <= 0.0 and r.size.x >= r.size.y and r.get_center().y < 0 and absf(r.get_center().x) < Vector2(GameSim.HALF).x:
		for sx in SCONCE_X:
			if sx > f.position.x + 6 and sx < f.end.x - 6:
				self.sconce(Vector2(sx, f.position.y + height * 0.45))

# local function Ink of the method above
func _concrete_wall_ink(on_roof: bool, seam) -> Color:
	return seam if on_roof else INK

func concrete_face(f: Rect2, foot: bool) -> void:
	px(f.position.x, f.position.y, f.size.x, f.size.y, CON_FACE)
	# formwork lines
	var y: float = f.position.y + 6
	while y < f.end.y - 2:
		px(f.position.x, y, f.size.x, 1, a(CON_FACE_L, 0.7))
		y += 8.0
	var x0: int = ceili(f.position.x)
	var x1: int = floori(f.end.x)
	var yt: int = roundi(f.position.y)
	var hh: int = maxi(1, roundi(f.size.y))
	for x in range(x0, x1):
		if mod(x, PILASTER_EVERY) == 0:
			# a pilaster: a lighter column standing a little proud of the wall
			px(x - 3, f.position.y, 7, f.size.y, CON_PIL)
			px(x - 3, f.position.y, 1, f.size.y, CON_TOP_L)
			px(x + 3, f.position.y, 1, f.size.y, CON_FACE_D)
		elif mod(x, 32) == 0:
			px(x, f.position.y, 1, f.size.y, a(CON_FACE_D, 0.8))
	for x in range(x0 - mod(x0, 2), x1, 2):
		var h: int = hash_(x, 7)
		var xs: float = maxf(x, f.position.x)
		var w: float = minf(x + 2, f.end.x) - xs
		if w <= 0:
			continue
		if h % 9 == 0:
			# a rust run down from the coping
			var len_: int = mini(hh, 3 + (h >> 4) % 9)
			px(xs, f.position.y, w, len_, a(RUST, 0.55))
			px(xs, f.position.y + len_ - 1, w, 1, a(RUST_D, 0.6))
		if foot and h % 7 == 1:
			# moss and damp at the foot
			var len_: int = mini(hh, 2 + (h >> 6) % 6)
			px(xs, f.end.y - len_, w, len_, a(MOSS, 0.75))
			px(xs, f.end.y - len_, w, 1, a(MOSS_D, 0.6))
		if h % 11 == 3:
			px(xs, yt + (h >> 8) % hh, 1, 1, a(CON_FACE_D, 0.9))
		if h % 23 == 5:
			# a lighter, sun-bleached patch
			px(xs, yt + (h >> 9) % hh, w, 3, a(CON_TOP_L, 0.35))
	# shadow under the coping and grime along the foot
	px(f.position.x, f.position.y, f.size.x, 2, Color(0, 0, 0, 0.18))
	if foot:
		px(f.position.x, f.end.y - 2, f.size.x, 2, a(CON_GRIME, 0.6))

func concrete_top(top: Rect2, horizontal: bool) -> void:
	px(top.position.x, top.position.y, top.size.x, top.size.y, CON_TOP)
	var x0: int = ceili(top.position.x)
	var y0: int = ceili(top.position.y)
	for x in range(x0 - mod(x0, 2), ceili(top.end.x), 2):
		for y in range(y0 - mod(y0, 2), ceili(top.end.y), 2):
			if not top.has_point(Vector2(x, y)):
				continue
			var h: int = hash_(x, y)
			if h % 13 == 0:
				px(x, y, 1, 1, CON_TOP_D)
			elif h % 61 == 1:
				px(x, y, 2, 1, a(MOSS, 0.8))
			elif h % 89 == 2:
				px(x, y, 1, 1, a(RUST, 0.8))
	# the edge toward the camera catches the light, the far edge is worn darker
	px(top.position.x, top.end.y - 1, top.size.x, 1, CON_TOP_L)
	px(top.position.x, top.position.y, top.size.x, 1, CON_TOP_D)
	# pilaster caps, a step proud of the coping
	if horizontal:
		for x in range(x0, ceili(top.end.x)):
			if mod(x, PILASTER_EVERY) == 0 and x > top.position.x + 5 and x < top.end.x - 5:
				px(x - 4, top.position.y - 1, 9, top.size.y + 1, CON_TOP_L)
				px(x - 4, top.position.y - 1, 9, 1, CON_TOP_D)
				px(x + 4, top.position.y, 1, top.size.y, CON_FACE_D)
	else:
		for y in range(y0, ceili(top.end.y)):
			if mod(y, PILASTER_EVERY) == 0 and y > top.position.y + 5 and y < top.end.y - 5:
				px(top.position.x - 1, y - 4, top.size.x + 2, 9, CON_TOP_L)
				px(top.position.x - 1, y + 4, top.size.x + 2, 1, CON_FACE_D)

# A door pillar in the same concrete, taller than the wall, a lamp on top that glows from dusk.
func concrete_pillar(r: Rect2, height: float) -> void:
	# under the roof only the part above the wall shows
	var hide: float = float(WALL_H) if self.face_under_roof(r) else 0.0
	self.concrete_wall(r, height, true, hide)
	var lamp = Rect2((r.get_center() - Vector2(2, height + 1)).round(), Vector2(4, 3))
	main.draw_rect(lamp.grow(1), INK)
	main.draw_rect(lamp, LAMP_HOT if self.lamps_lit() else Color("F2B544"))

func sconce(p: Vector2) -> void:
	p = p.round()
	px(p.x - 2, p.y + 2, 5, 2, INK)
	px(p.x - 2, p.y - 3, 5, 5, INK)
	px(p.x - 1, p.y - 2, 3, 3, LAMP_HOT if self.lamps_lit() else Color("F2B544"))
	if self.lamps_lit():
		# warm light washing down the wall
		px(p.x - 5, p.y + 4, 11, 6, a(LAMP_LIGHT, 0.12))

func lamps_lit() -> bool:
	return main.snap.get("ph", "") in ["dusk", "night"]

# The paved floor inside the walls: big stone slabs in staggered rows, each a slightly different shade, with dark
# joints, a lit top edge and the odd crack.
func draw_base_floor() -> void:
	var h: Vector2 = Vector2(GameSim.HALF)
	var in_: float = float(GameSim.WALL_IN)
	var floor_ = Rect2(-h.x + in_, -h.y + in_, 2 * (h.x - in_), 2 * (h.y - in_))
	px(floor_.position.x, floor_.position.y, floor_.size.x, floor_.size.y, PAVE_SEAM)
	var s: int = 32
	var sh: int = 24
	var row: int = 0
	var y: float = floor_.position.y
	while y < floor_.end.y:
		var off: float = 0.0 if row % 2 == 0 else s / 2
		var x: float = floor_.position.x - off
		while x < floor_.end.x:
			var slab = Rect2(x + 1, y + 1, s - 1, sh - 1).intersection(floor_)
			if not slab.has_area():
				x += s
				continue
			var hs: int = hash_(roundi(x), roundi(y))
			var c: Color = PAVE_A.lerp(PAVE_B, hs % 100 / 100.0)
			main.draw_rect(slab, c)
			px(slab.position.x, slab.position.y, slab.size.x, 1, a(PAVE_LIT, 0.8))
			px(slab.position.x, slab.position.y, 1, slab.size.y, a(PAVE_LIT, 0.5))
			# speckle
			for k in range(6):
				var hk: int = hash_(hs + k, k)
				px(slab.position.x + hk % maxi(1, int(slab.size.x)), slab.position.y + (hk >> 8) % maxi(1, int(slab.size.y)), 1, 1, a(PAVE_SEAM, 0.6))
			if hs % 5 == 0:
				# a crack across the slab
				var p: Vector2 = slab.position + Vector2(4 + (hs >> 4) % 10, 3)
				for k in range(8):
					if not slab.has_point(p):
						break
					px(p.x, p.y, 1, 1, a(PAVE_SEAM, 0.9))
					p += Vector2(1 if hash_(hs, k) % 3 == 0 else 0, 1) + Vector2(1 if hash_(k, hs) % 2 == 0 else 0, 0)
			x += s
		row += 1
		y += sh
	# damp, darker corners and a soft shade along the north wall
	px(floor_.position.x, floor_.position.y, floor_.size.x, 8, Color(0, 0, 0, 0.12))

# --- lamps ---------------------------------------------------------------------
func setup_base_lamps(tex) -> void:
	var spots = []
	for i in range(3):
		for fp in main.door_pillars(i):
			spots.append(Rect2(fp).get_center())
	var north: float = -Vector2(GameSim.HALF).y + float(GameSim.WALL_IN) + 6.0
	for sx in SCONCE_X:
		spots.append(Vector2(sx, north))
	# All eight glows are one light: they never move, so their pools of light are drawn into one texture once.
	# On the GPU every 2D light is worked out for every pixel of the world (it is one big canvas item), so
	# eight small lamps cost more at night than the beacon and your own light together.
	var rad: float = 2.2 * float(T)
	var box_ = Rect2(spots[0], Vector2.ZERO)
	for p in spots:
		box_ = box_.expand(p)
	box_ = box_.grow(rad + 2.0)
	var w: int = ceili(box_.size.x)
	var h: int = ceili(box_.size.y)
	# each pool as the lamp texture drew it (Main.BuildScene: full out to 70% of the radius, then fading)
	var sum = Cs.arr(w * h, 0.0)
	var most: float = 0.0
	for y in range(h):
		for x in range(w):
			var at: Vector2 = box_.position + Vector2(x + 0.5, y + 0.5)
			var s: float = 0.0
			for p in spots:
				var d: float = at.distance_to(p) / rad
				s += 1.0 if d <= 0.7 else maxf(0.0, 1.0 - (d - 0.7) / 0.3)
			sum[y * w + x] = s
			most = maxf(most, s)
	# where pools overlap they add up past 1: the texture holds the sum over this, the energy puts it back
	base_lamp_gain = maxf(1.0, most)
	var bytes = Cs.arr(w * h * 4, 0)
	for i in range(sum.size()):
		var v: int = roundi(clampf(sum[i] / base_lamp_gain, 0.0, 1.0) * 255.0)
		bytes[i * 4] = v
		bytes[i * 4 + 1] = v
		bytes[i * 4 + 2] = v
		bytes[i * 4 + 3] = 255
	var l = PointLight2D.new()
	l.texture = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes))
	l.color = LAMP_LIGHT
	l.energy = 0.9
	l.texture_scale = 1.0
	l.position = box_.position + Vector2(w, h) / 2
	l.enabled = false
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	main.add_child(l)
	base_lamps.append(l)

var base_lamp_gain: float = 1.0

func tick_base_lamps(night: float) -> void:
	for pl in base_lamps:
		pl.enabled = night > 0.05
		pl.energy = 0.75 * night * base_lamp_gain
