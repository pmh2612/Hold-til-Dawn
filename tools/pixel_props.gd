extends SceneTree
## Pixel-art props for the base (GDD 4.3 / 5.1 / 6): the old lighthouse that carries the beacon, the workbench,
## the defence tower (AGT-12) standing and wrecked, and the helicopter landing pad (FML-13).
## Same rules as the characters: 1 px = 1 game px, GDD palette, light from the upper left, 1 px dark outline.
## Not part of the game. Run: godot --headless --path . -s tools/pixel_props.gd
## Writes art/props/<name>.png and art/props/props.json ({name: [anchor_x, anchor_y]}, the pixel on the ground point).
## The PNGs are plain pixel art and can be repainted by hand.

const INK := Color("141019")
const SHADOW := Color(0.04, 0.06, 0.1, 0.38)
const CONCRETE := [Color("A3A8B0"), Color("8A8F98"), Color("6A6F7C")]  # light, mid, dark (GDD concrete #8A8F98)
const STEEL := [Color("B4C4D4"), Color("8FA3B8"), Color("5B6B7C")]  # GDD door steel #8FA3B8
const RED := [Color("D9534A"), Color("B8322E"), Color("7E2320")]
const WHITE := [Color("FFFFFF"), Color("E8E3D8"), Color("B9B4AA")]
const WOOD := [Color("C08A50"), Color("A0703C"), Color("7A5634"), Color("5A3E26")]
const AMBER := Color("F2B544")  # GDD beacon amber
const GLOW := Color("FFF1B8")
const DARK := Color("2B2F36")

var props := {}


func _init() -> void:
	var out := "res://art/props"
	DirAccess.make_dir_recursive_absolute(out)
	_save(out, "lighthouse", _lighthouse(), Vector2(14, 73))
	_save(out, "workbench", _workbench(), Vector2(17, 22))
	_save(out, "tower", _tower(false), Vector2(13, 57))
	_save(out, "tower_wreck", _tower(true), Vector2(13, 57))
	_save(out, "pad", _pad(), Vector2(128, 128))
	var fa := FileAccess.open(out.path_join("props.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(props, "\t"))
	fa.close()
	quit()


func _save(out: String, n: String, im: Image, anchor: Vector2) -> void:
	im.save_png(out.path_join(n + ".png"))
	props[n] = [anchor.x, anchor.y]
	print("drew ", n, " ", im.get_size())


# --- the props ---------------------------------------------------------------

func _lighthouse() -> Image:
	## The old lighthouse at the heart of Lighthouse Outpost; its lamp is the beacon (GDD 5.1).
	var im := Image.create_empty(28, 76, false, Image.FORMAT_RGBA8)
	_shadow(im, Vector2(19, 72), 12, 3)
	_block(im, Rect2i(2, 66, 24, 8), CONCRETE)  # plinth
	for y in range(22, 66):  # tapered tower in red and white bands
		var half := 6 + int(3.0 * (y - 22) / 43.0)
		var band: Array = RED if ((65 - y) / 9) % 2 == 0 else WHITE
		for x in range(14 - half, 14 + half):
			var c: Color = band[1]
			if x < 14 - half + 2:
				c = band[0]
			elif x >= 14 + half - 3:
				c = band[2]
			im.set_pixel(x, y, c)
	im.fill_rect(Rect2i(12, 58, 4, 8), Color("2B2024"))  # door
	im.fill_rect(Rect2i(13, 40, 2, 3), Color("2B2024"))  # window
	im.fill_rect(Rect2i(4, 18, 20, 1), Color("5B5F6B"))  # gallery rail
	im.fill_rect(Rect2i(4, 21, 20, 1), Color("3A3F48"))
	for x in range(4, 24, 3):
		im.fill_rect(Rect2i(x, 19, 1, 2), Color("3A3F48"))
	im.fill_rect(Rect2i(9, 9, 10, 9), AMBER)  # lamp room
	im.fill_rect(Rect2i(12, 11, 4, 4), GLOW)
	for x in [9, 18]:
		im.fill_rect(Rect2i(x, 9, 1, 9), Color("3A3F48"))
	for r in 5:  # red dome
		im.fill_rect(Rect2i(8 + r, 8 - r, 12 - 2 * r, 1), RED[1] if r > 0 else RED[2])
	im.fill_rect(Rect2i(9, 7, 2, 1), RED[0])
	im.fill_rect(Rect2i(13, 2, 2, 2), Color("3A3F48"))
	_outline(im)
	return im


func _workbench() -> Image:
	## The team's workbench (crafting, MEC-10): planks, legs, a vise, hammer and saw, a red tool box.
	var im := Image.create_empty(34, 24, false, Image.FORMAT_RGBA8)
	_shadow(im, Vector2(20, 22), 14, 2)
	im.fill_rect(Rect2i(2, 15, 3, 7), WOOD[3])  # legs
	im.fill_rect(Rect2i(29, 15, 3, 7), WOOD[3])
	im.fill_rect(Rect2i(4, 18, 25, 1), WOOD[3])
	im.fill_rect(Rect2i(1, 6, 32, 6), WOOD[1])  # top
	im.fill_rect(Rect2i(1, 6, 32, 1), WOOD[0])
	for x in [11, 22]:
		im.fill_rect(Rect2i(x, 6, 1, 6), WOOD[2])
	im.fill_rect(Rect2i(1, 12, 32, 3), WOOD[2])  # front edge
	im.fill_rect(Rect2i(3, 3, 5, 3), STEEL[2])  # vise
	im.fill_rect(Rect2i(4, 2, 3, 1), STEEL[1])
	im.fill_rect(Rect2i(12, 8, 7, 1), WOOD[3])  # hammer
	im.fill_rect(Rect2i(19, 6, 2, 4), STEEL[1])
	im.fill_rect(Rect2i(23, 8, 7, 2), STEEL[0])  # saw
	for x in range(23, 30, 2):
		im.set_pixel(x, 10, STEEL[2])
	im.fill_rect(Rect2i(25, 2, 6, 4), RED[1])  # tool box
	im.fill_rect(Rect2i(26, 1, 4, 1), RED[2])
	_outline(im)
	return im


func _tower(wreck: bool) -> Image:
	## Defence tower (AGT-12): concrete footing, steel lattice mast, platform, floodlight (amber) and a small gun.
	var im := Image.create_empty(26, 60, false, Image.FORMAT_RGBA8)
	_shadow(im, Vector2(17, 56), 11, 3)
	_block(im, Rect2i(3, 50, 20, 8), CONCRETE)
	var top := 32 if wreck else 20
	for y in range(top, 50):  # two legs leaning in, cross braces every 10 rows
		var t := float(y - 20) / 30.0
		var l := int(lerpf(9, 6, t))
		var r := int(lerpf(16, 19, t))
		im.fill_rect(Rect2i(l, y, 2, 1), STEEL[1])
		im.fill_rect(Rect2i(r, y, 2, 1), STEEL[2])
		var k := (y - 20) % 10
		im.set_pixel(l + 2 + int((r - l - 2) * k / 10.0), y, STEEL[2])
		im.set_pixel(r - 1 - int((r - l - 2) * k / 10.0), y, STEEL[2])
	if wreck:  # snapped mast, the head lies on the ground, dead lamp, debris
		im.fill_rect(Rect2i(9, 29, 2, 3), STEEL[2])
		im.fill_rect(Rect2i(15, 30, 3, 2), STEEL[2])
		_block(im, Rect2i(16, 51, 9, 6), [Color("6E7682"), Color("5B6B7C"), Color("3A4250")])
		im.fill_rect(Rect2i(17, 53, 4, 2), Color("3A3530"))
		for p in [Vector2i(1, 55), Vector2i(4, 57), Vector2i(22, 49)]:
			im.fill_rect(Rect2i(p.x, p.y, 2, 2), CONCRETE[2])
	else:
		im.fill_rect(Rect2i(4, 15, 18, 5), Color("3A4250"))  # platform
		im.fill_rect(Rect2i(4, 15, 18, 1), STEEL[1])
		im.fill_rect(Rect2i(8, 6, 10, 9), STEEL[2])  # head
		im.fill_rect(Rect2i(8, 6, 10, 1), STEEL[0])
		im.fill_rect(Rect2i(10, 8, 6, 4), AMBER)  # floodlight
		im.fill_rect(Rect2i(11, 9, 3, 2), GLOW)
		im.fill_rect(Rect2i(18, 10, 6, 2), DARK)  # gun
		im.fill_rect(Rect2i(12, 2, 1, 4), Color("3A3F48"))  # antenna
		im.set_pixel(12, 1, RED[0])
	_outline(im)
	return im


func _pad() -> Image:
	## Landing pad (FML-13): 8 tiles across, dark asphalt, amber ring, white H, blue edge lamps.
	var n := 256
	var im := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= 126:
				var col := Color("3A3F48")
				if d > 122:
					col = Color("2B2F36")
				elif d > 104 and d <= 112:
					col = AMBER if int(atan2(y - c.y, x - c.x) / TAU * 32.0 + 32) % 2 == 0 else Color("2B2F36")  # dashed ring
				elif (x * 7 + y * 13) % 23 == 0:
					col = Color("444955")  # grit
				im.set_pixel(x, y, col)
	var w := WHITE[1]
	im.fill_rect(Rect2i(96, 72, 18, 112), w)  # H
	im.fill_rect(Rect2i(142, 72, 18, 112), w)
	im.fill_rect(Rect2i(114, 119, 28, 18), w)
	for i in 8:  # edge lamps
		var p := c + Vector2.from_angle(i * TAU / 8.0) * 117.0
		im.fill_rect(Rect2i(int(p.x) - 2, int(p.y) - 2, 4, 4), Color("4FA3FF"))
	_outline(im)
	return im


# --- helpers ---------------------------------------------------------------

func _block(im: Image, r: Rect2i, shades: Array) -> void:
	## A lit box: light left edge and top, dark right edge.
	im.fill_rect(r, shades[1])
	im.fill_rect(Rect2i(r.position.x, r.position.y, 2, r.size.y), shades[0])
	im.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 1), shades[0])
	im.fill_rect(Rect2i(r.end.x - 2, r.position.y + 1, 2, r.size.y - 1), shades[2])


func _shadow(im: Image, c: Vector2, rx: float, ry: float) -> void:
	## Ground shadow to the lower right, like the baked trees (sun from the upper left).
	for y in im.get_height():
		for x in im.get_width():
			var d := Vector2((x + 0.5 - c.x) / rx, (y + 0.5 - c.y) / ry)
			if d.length_squared() <= 1.0:
				im.set_pixel(x, y, SHADOW)


func _outline(im: Image) -> void:
	var src := im.duplicate() as Image
	for y in im.get_height():
		for x in im.get_width():
			if _solid(src, x, y):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _solid(src, x + d.x, y + d.y):
					im.set_pixel(x, y, INK)
					break


func _solid(im: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height() and im.get_pixel(x, y).a > 0.6
