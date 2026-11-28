class_name PixelItems
extends Node

# ---- tools/PixelItems.cs
# Pixel-art icons for every inventory item (ITM-02..13, resources, bandage, arrows) and the small projectiles,
# in the style of tools/PixelChars.cs: one letter per pixel looked up in a palette, light from the upper left,
# a 1 px dark outline added by the script. Not part of the game.
# Run: godot --headless --path . tools/PixelItems.tscn   (add -- --out=<dir> to preview elsewhere)
# Writes art/items/<item id>.png (20 x 20) and art/fx/<name>.png. The PNGs can be repainted by hand.
static var ink: Color = Color("141019")
const icon: int = 20
static var wood = {"W": "C08A50", "w": "A0703C", "v": "7A5634", "u": "5A3E26", "r": "E0B070"}
static var stone = {"S": "D5DAE1", "s": "A3A8B0", "t": "7D838C", "q": "565B66"}
static var steel = {"M": "EEF4F8", "m": "B4C4D4", "n": "8FA3B8", "o": "5B6B7C"}

static func pal(...parts: Array) -> Variant:
	var all = {}
	for p in parts:
		for kv in Cs.pairs(p):
			all[kv[0]] = kv[1]
	return all
# name -> (rows, palette)
static var items = {"wood": [[".WWWWWWWWW.uu...", ".wwwwwwwwwurru..", ".vvvvvvvvvurru..", "...........uu...", "...WWWWWWWWW.uu.", "...wwwwwwwwwurru", "...vvvvvvvvvurru", ".............uu.", ".WWWWWWWWW.uu...", ".wwwwwwwwwurru..", ".vvvvvvvvvurru..", "...........uu..."], wood], "stone": [["......SSS.......", "....SSSSsst.....", "...SSSssssstt...", "..SSsssssssttq..", "..Sssssssstttq..", "..ssssssttttqq..", "...tttttttqqq...", "....qqqqqqq....."], stone], "herb": [["......G.........", ".....GGg........", "....GGgg..G.....", "....Gggj.GGg....", ".G...gj.GGgg....", "GGg..kj.Ggj.....", "Gggj.k..gj......", ".gjj.k.kj.......", "..jj.kkk........", ".....kk.........", ".....k..........", ".....k.........."], {"G": "9BE37A", "g": "4FB862", "j": "2E7D3E", "k": "6E8A3A"}], "titanium": [["....MMMMMMMMMM..", "...MmmmmmmmmmMbp", "..MmmTTTmmmmmMbp", "..MmmmTmTmmmmMbp", ".nnnnnTnTnnnnnbg", ".nnnnnnnnnnnnnpg", ".oooooooooooooo.", "................", ".....MMMMMMMMMM.", "....MmmmmmmmmMbp", "...nnnnnnnnnnnbg", "...ooooooooooooo"], {"M": "D2E6FF", "m": "7FA6F5", "n": "4A6AD8", "o": "283A8E", "T": "3550B8", "b": "A98CFF", "p": "7C5CE0", "g": "E2D6FF"}], "bandage": [["....BBBBBBBB....", "...BBBBBBBBBbb..", "..BBBBBXXBBbbcc.", "..BBBBXXXXBbbcc.", "..BBBBBXXBBbbcc.", "..bbbbbbbbbbbcc.", "...cccccccccc...", ".............bb.", "..............bb"], {"B": "FFFFFF", "b": "E8E2D0", "c": "B9B4AA", "X": "D9534A"}], "revival_kit": [["......kkkk......", ".....k....k.....", "..GGGGGGGGGGGG..", ".GGGGGGGGGGGGGg.", ".GGGHHGGHHGGGGg.", ".GGHHHHHHHHGGGg.", ".GGHHHHYHHHGGGg.", ".GGGHHYYHHGGGGg.", ".GGGGHHYHGGGGGg.", ".GGGGGHHGGGGGGg.", ".GGGGGGGGGGGGGg.", ".ggggggggggggggd", "..dddddddddddd.."], {"G": "4FA35A", "g": "3E8E4A", "d": "2F6B38", "k": "8FA3B8", "H": "F2F2F2", "Y": "F2B544"}], "base_repair": [["...........P....", "..........PPP...", "...........P....", ".oooooooooooo...", ".nmmmmmmmmmmo...", ".nmmmmmYYmmmo...", ".nmmmmYYmmmmo...", ".nmmmYYYYYmmo...", ".nmmmmmYYmmmo...", ".nmmmmYYmmmmo...", ".nmmmmmmmmmmo...", ".oooooooooooo...", "..qq......qq...."], {"m": "B4C4D4", "n": "8FA3B8", "o": "5B6B7C", "Y": "F2B544", "P": "6CC070", "q": "565B66"}], "arrow": [["............iI..", "...........iiI..", "..........hiI...", ".........h......", "........h.......", ".......h........", "......h.........", ".....h..........", "....h...........", "..FFh...........", "..fFF...........", "..ff............"], {"h": "A0703C", "i": "D5DAE1", "I": "8FA3B8", "F": "D9534A", "f": "E8E3C8"}], "stone_spear": [["............SS..", "...........SSst.", "..........SsstT.", "...........ttT..", "..........w.....", ".........w......", "........w.......", ".......w........", "......w.........", ".....w..........", "....v...........", "...v............", "..v............."], pal(stone, wood, {"T": "565B66"})], "titanium_blade": [["............MM..", "...........MMm..", "..........MMm...", ".........MMm....", "........MMm.....", ".......MMm......", "..YY..MMm.......", "...YYMMm........", "....YYm.........", "...hYY.Y........", "..hh............", ".hh............."], pal(steel, {"Y": "F2B544", "h": "5A3E26"})], "starter_bow": [["...wv...........", "...s.ww.........", "...s..ww........", "...s...ww.......", "...s....w.......", "...s....ww......", "...s.....w......", "...s.....v......", "...s.....w......", "...s....ww......", "...s....w.......", "...s...ww.......", "...s..ww........", "...s.ww.........", "...wv..........."], pal(wood, {"s": "E8E3C8"})], "bow": [["...Mn...........", "...s.uu.........", "...s..uu........", "...s...vu.......", "...s....v.......", "...s....vu......", "...s.....X......", "...s.....X......", "...s.....X......", "...s....vu......", "...s....v.......", "...s...vu.......", "...s..uu........", "...s.uu.........", "...Mn..........."], pal(wood, steel, {"s": "E8E3C8", "X": "D9534A"})], "hammer": [["..MMMMMMMMm.....", "..Mmmmmmmmno....", "..Mmmmmmmmno....", "..ooooooooo.....", "......Wv........", "......Wv........", "......Wv........", "......Wv........", "......Wv........", "......Wv........", "......uu........", "......uu........"], pal(steel, wood)], "light_armour": [vest(false, false), {"L": "C08A50", "l": "8C6A48", "d": "5A3E26", "H": "E0B070", "x": "5A3E26"}], "stone_armour": [vest(true, false), {"L": "A3A8B0", "l": "7D838C", "d": "565B66", "H": "D5DAE1", "x": "565B66"}], "titanium_armour": [vest(false, true), {"L": "B4C4D4", "l": "8FA3B8", "d": "5B6B7C", "H": "EEF4F8", "x": "F2B544"}]}

# One chest-piece shape for the three armours; stone shows plates, titanium shows rivets and a shine.
static func vest(plates: bool, rivets: bool) -> Variant:
	var rows = ["...LL......LL...", "..LLLL....LLLL..", "..LHLLL..LLLLl..", ".LHLLLLLLLLLLLl.", ".LHLLLLLLLLLLLl.", ".lHLLLLLLLLLLll.", "..LLLLLLLLLLLl..", "..LLLLLLLLLLLl..", "..lLLLLLLLLLll..", "..llllllllllll..", "...dddddddddd..."]
	if plates:
		rows[4] = ".LHxxxxxxxxxxLl."
		rows[7] = "..LxxxxxxxxxxL.."
	if rivets:
		rows[3] = ".LHxLLLLLLLLxLl."
		rows[6] = "..LxLLLLLLLLxl.."
	return Array(rows).duplicate()
# Projectiles and effects drawn in the world.
static var fx = {"arrow": [["F..........I.", "fhhhhhhhhhhiI", "F..........I."], {"h": "C08A50", "i": "D5DAE1", "I": "8FA3B8", "F": "D9534A", "f": "E8E3C8"}], "spit": [["..qQQ.", ".QQqQQ", "QQQQQj", ".QQQjj", "..jj.."], {"Q": "D8E03A", "q": "F6F9A8", "j": "8F9620"}], "orb": [["........pPPP......", "......pPWWWWPp....", "..p..pPWWWWWPPp...", "pPP..PWWWWPPPPPk..", ".pPPpPWWPPPPPPPk..", "...pPPPPPPPPPPk...", "....pPPPPPPPpk....", "......pPPPpk......", "........kk........"], {"P": "76FF48", "p": "3BE03B", "W": "F4FFDC", "k": "1E9C2E"}]}

func _ready() -> void:
	add_tactical_art()
	var out = "res://art"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out.path_join("items"))
	DirAccess.make_dir_recursive_absolute(out.path_join("fx"))
	for name in items:
		var art = items[name]
		save(draw(art[0], art[1], icon, icon), out.path_join("items").path_join(name + ".png"))
	for name in fx:
		var art = fx[name]
		var w: int = art[0].map(func(r): return r.length()).max() + 2
		save(draw(art[0], art[1], w, art[0].size() + 2, name != "orb"), out.path_join("fx").path_join(name + ".png"))
	get_tree().quit()

static func save(im, path) -> void:
	im.save_png(path)
	print("drew ", path, " ", im.get_size())

# Centres the pixel map on a W x H canvas and optionally adds the dark outline.
static func draw(rows, pal_, w: int, h: int, outlined: bool = true) -> Variant:
	var im = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var wide: int = rows.map(func(r): return r.length()).max()
	var x0: int = (w - wide) / 2
	var y0: int = (h - rows.size()) / 2
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var k = rows[y][x]
			if k == ".":
				continue
			var hex = pal_.get(k, null)
			if not pal_.has(k):
				push_error("no colour for '%s'" % [Cs.s(k)])
				continue
			im.set_pixel(x0 + x, y0 + y, Color(hex))
	if not outlined:
		return im
	var src = im.duplicate()
	for y in range(h):
		for x in range(w):
			if src.get_pixel(x, y).a > 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixel(q.x, q.y).a > 0:
					im.set_pixel(x, y, ink)
					break
	return im

# ---- tools/PixelTacticalItems.cs
# Uses the same hand-authored pixel maps and outline pass as the existing item art.

static func add_tactical_art() -> void:
	items["long_spear"] = [[".............MM.", "............MMm.", "...........MMm..", "............n...", "...........w....", "..........w.....", ".........w......", "........w.......", ".......w........", "......w.........", ".....w..........", "....w...........", "...v............", "..v.............", ".v..............", "v..............."], pal(wood, steel)]
	items["stun_maul"] = [[".......MMMMMMM..", "......MMMMMMMMm.", "......mMMnnnMMm.", "......mMMnYnMMm.", "......mMMnnnMMm.", ".......nnnnnnn..", ".........w......", "........w.......", ".......w........", "......w.........", ".....w..........", "....v...........", "...v............", "..v............."], pal(wood, steel, {"Y": "68EBE0"})]
	items["vine_trap"] = [["...G......G.....", "..Gg......gG....", "...gGGGGGGg.....", "..Gg......gG....", ".Gg..wwww..gG...", ".Gg.w....w.gG...", "..Ggw....wgG....", "...gwwwwwwg.....", "..Gg......gG....", "...GGggggGG.....", ".....w..w.......", "....w....w......"], pal(wood, {"G": "B7D879", "g": "57894B"})]
	items["poison_flask"] = flask("B7D953", "648E34", "D7EE8C", false)
	items["healing_flask"] = flask("74E5CB", "319A91", "F2FFF1", true)
	items["haste_tonic"] = [[".....wwww.......", ".....vvvv.......", ".....M..M.......", "....MM..MM......", "...MaaaaaaM.....", "...MaaYYaam.....", "...MaYYaaam.....", "...MaYYYYam.....", "...MaaaYaam.....", "...MaaYaaam.....", "....mmmmmm......"], pal(wood, steel, {"a": "EDAA49", "Y": "FFF3B4"})]
	items["explosive_arrow"] = [["............YY..", "...........YRRR.", "..........hRrRR.", ".........h..rr..", "........h.......", ".......h........", "......h.........", ".....h..........", "....h...........", "..FFh...........", "..fFF...........", "..ff............"], {"h": "C08A50", "Y": "FFE490", "R": "F09145", "r": "A84432", "F": "D9534A", "f": "E8E3C8"}]
	items["repair_kit"] = [[".....MMMMMM.....", "....M......m....", "..MMMMMMMMMMMM..", ".Mmmmmmmmmmmmmn.", ".MmmYYmmmmmmYmn.", ".MmmYYmmmmmYYmn.", ".MmmmmYYmmYYmmn.", ".MmmmmmYYYYmmmn.", ".MmmmmmmYYmmmmn.", ".Mmmmmmmmmmmmmn.", "..nnnnnnnnnnnn.."], pal(steel, {"Y": "F5BC65"})]
	fx["explosive_arrow"] = [["F.........YY.", "fhhhhhhhhhRRR", "F.........rr."], {"F": "D9534A", "f": "E8E3C8", "h": "C08A50", "Y": "FFE490", "R": "F09145", "r": "A84432"}]

static func flask(bright, dark, mark, cross: bool) -> Variant:
	var rows = [".....wwww.......", ".....vvvv.......", ".....M..M.......", "....MM..MM......", "...MaaaaaaM.....", "..MaaaXXaaam....", "..MaaXXXXaam....", "..MaaaXXaaam....", "..Maaaaaaaam....", "...mmmmmmmm....."]
	if not cross:
		rows[5] = "..MaaXaaXaam...."
		rows[6] = "..MaaaXXaaam...."
		rows[7] = "..MaaXaaXaam...."
	return [rows, pal(wood, steel, {"a": bright, "m": dark, "X": mark})]
