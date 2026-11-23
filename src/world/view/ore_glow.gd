class_name OreGlowView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.OreGlow.cs.
# Owner: Vu Duc Viet Anh. Titanium nodes are dark rocks grown with blue crystals (tools/PixelNature.cs). Over the
# node the game draws its crystal layer (art/nature/node_titanium_glow_<k>.png) with a slow breathing light, and
# now and then a crystal tip (the pure white pixels of that layer) twinkles.
const ORE_NODE = "node_titanium_"
const ORE_GLOW = "node_titanium_glow_"
var ore_tips = {}

var main: Main

func _init(host: Main) -> void:
	main = host

# call right after drawing a nature sprite; does nothing for anything but a titanium node
func draw_ore_glow(n, pos: Vector2, s: float) -> void:
	if not n.begins_with(ORE_NODE) or n.begins_with(ORE_GLOW):
		return
	var gn = ORE_GLOW + n.substr(ORE_NODE.length())
	var sp = main.spr.get(gn)
	if sp == null:
		return
	var tex = sp[0]
	var r: Rect2 = Rect2(main.sprite_rect(gn, pos, s))
	var now: float = float(main.clock)
	var seed_: float = pos.x * 0.37 + pos.y * 0.61
	var pulse: float = 0.5 + 0.5 * sin(now * 1.8 + seed_)
	main.draw_texture_rect(tex, r, false, Color(1.1, 1.25, 1.7, 0.06 + 0.2 * pulse))
	var tips = self.ore_tips_of(gn, tex)
	var px_: float = r.size.x / tex.get_width()
	for k in range(tips.size()):
		# each tip flashes for a moment once every few seconds, out of step with the others
		var phase: float = fposmod(now * 0.45 + seed_ * 0.13 + k * 0.37, 1.0)
		if phase > 0.12:
			continue
		var a_: float = sin(phase / 0.12 * PI)
		var at: Vector2 = r.position + (tips[k] + Vector2(0.5, 0.5)) * px_
		var hot = Color(1.8, 2.0, 2.6, a_)
		var soft = Color(1.2, 1.4, 2.2, a_ * 0.5)
		var arm: float = Cs.round_even(1.0 + 2.0 * a_)
		main.draw_rect(Rect2((at - Vector2(0.5, 0.5)).round(), Vector2.ONE), hot)
		main.draw_rect(Rect2((at + Vector2(-0.5 - arm, -0.5)).round(), Vector2(arm, 1)), soft)
		main.draw_rect(Rect2((at + Vector2(0.5, -0.5)).round(), Vector2(arm, 1)), soft)
		main.draw_rect(Rect2((at + Vector2(-0.5, -0.5 - arm)).round(), Vector2(1, arm)), soft)
		main.draw_rect(Rect2((at + Vector2(-0.5, 0.5)).round(), Vector2(1, arm)), soft)

func ore_tips_of(gn, tex) -> Variant:
	var tips = ore_tips.get(gn, null)
	if ore_tips.has(gn):
		return tips
	var list = []
	var im = tex.get_image()
	if im != null:
		if im.is_compressed():
			im.decompress()
		for y in range(im.get_height()):
			for x in range(im.get_width()):
				var c: Color = im.get_pixel(x, y)
				if c.a > 0.99 and c.r > 0.99 and c.g > 0.99 and c.b > 0.99:
					list.append(Vector2(x, y))
	tips = Array(list).duplicate()
	ore_tips[gn] = tips
	return tips
