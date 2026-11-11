extends SceneTree
## Pixel-art sprites of the six GDD characters (tab:characters: CHR-01..03 players, CHR-05..07 enemies),
## following the style guide of GDD ch. 6 (tab:style-guide): 32 x 32 px at tile scale (Wrecker 1.25 tiles = 40 x 40),
## dark outline, limited shading, light from the upper left, GDD palette, a walk cycle in 4 directions
## (left is the mirrored right). Not part of the game. Run: godot --headless --path . -s tools/pixel_chars.gd
## Writes art/chars/<character>.png (1x pixels; the game scales them up without smoothing) and art/chars/chars.json.
## Sheet layout: rows = right, down, left, up; columns = idle 0-1, walk 0-3.
## The PNGs can be repainted by hand (Aseprite, Piskel, ...): the game reads them as they are.
##
## Each body is a pixel map: one letter per pixel, looked up in the character's palette ('.' = empty).
## A character = a body (human / nox / wrecker) + its palette + overlays (gear) drawn on top.

const INK := Color("141019")  # outline, the same ink as the game's cartoon outline
const SHADOW := Color(0, 0, 0, 0.32)

# --- bodies: [top row, rows]; rows are 16 px wide (20 for the Wrecker), centred on the canvas --------

const HUMAN := {
	"size": 32, "feet": 28, "legs": 23, "shadow": 6,
	"split": {"down": [2, 8, 14], "up": [2, 8, 14], "side": [4, 8, 14]},  # [from, middle, to] columns of the two legs
	"down": [6, [
		"....HHHHHHHH....",
		"...HHHHHHHHHH...",
		"..HHHHHHHHHHHh..",
		"..HHHHHHHHHHHh..",
		"..HHSSSSSSSSHh..",
		"..HSSSSSSSSSSh..",
		"..HSSEESSEESSh..",
		"..hSSEESSEESSh..",
		"..hSSSSSSSSSSs..",
		"...sSSSSSSSSs...",
		"....ssSSSSss....",
		"..ccLCCCCCCCcc..",
		"..ccLCCCCCCCcc..",
		"..ccLCCCCCCCcc..",
		"..SSLCCCCCCCSS..",
		"..SSCCCCCCCCSS..",
		"...GGGGGGGGGG...",
		"...PPPPPPPPPp...",
		"...PPPp..PPPp...",
		"...PPPp..PPPp...",
		"...PPPp..PPPp...",
		"...BBBb..BBBb...",
		"..BBBBb..BBBBb..",
	]],
	"up": [6, [
		"....HHHHHHHH....",
		"...HHHHHHHHHH...",
		"..HHHHHHHHHHHh..",
		"..HHHHHHHHHHHh..",
		"..HHHHHHHHHHHh..",
		"..HHHHHHHHHHHh..",
		"..HHHHHHHHHHHh..",
		"..hHHHHHHHHHHh..",
		"..shHHHHHHHHhs..",
		"...shhhhhhhhs...",
		"....ssSSSSss....",
		"..ccLCCCCCCCcc..",
		"..ccLCCCCCCCcc..",
		"..ccLCCCCCCCcc..",
		"..SSLCCCCCCCSS..",
		"..SSCCCCCCCCSS..",
		"...GGGGGGGGGG...",
		"...PPPPPPPPPp...",
		"...PPPp..PPPp...",
		"...PPPp..PPPp...",
		"...PPPp..PPPp...",
		"...BBBb..BBBb...",
		"..BBBBb..BBBBb..",
	]],
	"side": [6, [  # facing right
		".....HHHHHHH....",
		"....HHHHHHHHH...",
		"...HHHHHHHHHHH..",
		"...HHHHHHHHHHH..",
		"...HHHHHHSSSSS..",
		"...HHHHHSSSSSS..",
		"...hHHHHSSSSES..",
		"...hHHHSSSSSES..",
		"...hhHSSSSSSSS..",
		"....hhsSSSSSs...",
		"......sSSSs.....",
		".....cLCCCCc....",
		".....cLCCCCc....",
		".....cLccCCc....",
		".....cLccCCc....",
		".....CCSSCCc....",
		".....GGGGGGG....",
		".....PPPPPPp....",
		".....PPp.PPp....",
		".....PPp.PPp....",
		".....PPp.PPp....",
		".....BBb.BBb....",
		".....BBBB.BBBB..",
	]],
}

const NOX := {  # hunched creature: big low head, no neck, long clawed arms, short legs (never mistaken for a player)
	"size": 32, "feet": 28, "legs": 25, "shadow": 7,
	"split": {"down": [4, 8, 13], "up": [4, 8, 13], "side": [2, 7, 12]},
	"down": [10, [
		"....nMMMMMMn....",
		"...MMNNNNNNNn...",
		"..MNNNNNNNNNNn..",
		".MNNNNNNNNNNNNn.",
		".MNYYNNNNNNYYNn.",
		".NNYYNNNNNNYYNn.",
		".NNNNNNNNNNNNNn.",
		".nNNDTDTTDTDNNn.",
		"MNnNNDDDDDDNNnNn",
		"MNnnNNNNNNNNnnNn",
		"MNn.nNNNNNNNn.Nn",
		"MNn.nNNNNNNNn.Nn",
		"NNn.nNNNNNNNn.Nn",
		"Nn..nNNNNNNNn.nn",
		"AA...nNnnNNn..AA",
		".....nNn.nNn....",
		".....nNn.nNn....",
		"....nnNn.nNnn...",
		"....nnnn.nnnn...",
	]],
	"up": [10, [
		"....nMMMMMMn....",
		"...MMNNNNNNNn...",
		"..MNNNNNNNNNNn..",
		".MNNNNNNNNNNNNn.",
		".MNNNNNNNNNNNNn.",
		".NNNNNNNNNNNNNn.",
		".NNNNNNNNNNNNNn.",
		".nNNNNNNNNNNNNn.",
		"MNnNNNNNNNNNNnNn",
		"MNnnNNNNNNNNnnNn",
		"MNn.nNNNNNNNn.Nn",
		"MNn.nNNNNNNNn.Nn",
		"NNn.nNNNNNNNn.Nn",
		"Nn..nNNNNNNNn.nn",
		"AA...nNnnNNn..AA",
		".....nNn.nNn....",
		".....nNn.nNn....",
		"....nnNn.nNnn...",
		"....nnnn.nnnn...",
	]],
	"side": [10, [  # facing right, head pushed forward
		"...nMMMMMMn.....",
		"..MNNNNNNNNMn...",
		".MNNNNNNNNNNNn..",
		".NNNNNNNNNNNNNn.",
		".NNNNNNNNNNYYNn.",
		".nNNNNNNNNNYYNNn",
		".nNNNNNNNNNNNNNn",
		".nNNNNNNNNNNDTDn",
		"..nNNNNNNNNNNDDn",
		"..nNNNNNNNNNNNn.",
		"..nnNNNNNNNNNNn.",
		"...nNNNNNNNnNNn.",
		"...nNNNNNNn.nNn.",
		"...nNNnnNNn.nNn.",
		"...nNn..nNn.nNn.",
		"...nNn..nNn.AAA.",
		"...nNn..nNn.....",
		"..nnNn.nnNn.....",
		"..nnnn.nnnn.....",
	]],
}

const WRECKER_BODY := {  # 40 x 40: 1.25 tiles, armour plates (R) with magenta seams (A), horns
	"size": 40, "feet": 37, "legs": 32, "shadow": 10,
	"split": {"down": [4, 10, 17], "up": [4, 10, 17], "side": [3, 10, 17]},
	"down": [12, [
		"......A......A......",
		"......AA....AA......",
		".....RrRRRRRRrR.....",
		"....RRRRRRRRRRRr....",
		"...RRRRRRRRRRRRRr...",
		"...NNNNNNNNNNNNNn...",
		"..NNYYYNNNNNNYYYNn..",
		"..NNNNNNNNNNNNNNNn..",
		"..nNNDTDTDTDTDNNNn..",
		".RRRnNDDDDDDDDNnRRR.",
		"RRRRRRNNNNNNNNRRRRRr",
		"ARRRRRRRRRRRRRRRRRrA",
		"NNn.RRRRRRRRRRRr.nNn",
		"NNn.RRRRAARRRRRr.nNn",
		"NNn.RRRRRRRRRRRr.nNn",
		"NNn.rrrrrrrrrrrr.nNn",
		"NNn.nNNNNNNNNNNn.nNn",
		"NNn.nNNNNNNNNNNn.nNn",
		"Nnn..nNNNNNNNNn..nNn",
		"AAA..nNNNnnNNNn..AAA",
		".....nNNn..nNNn.....",
		".....nNNn..nNNn.....",
		".....RRRr..RRRr.....",
		".....nNNn..nNNn.....",
		"....nnNNn..nNNnn....",
		"....nnnnn..nnnnn....",
	]],
	"up": [12, [
		"......A......A......",
		"......AA....AA......",
		".....RrRRRRRRrR.....",
		"....RRRRRRRRRRRr....",
		"...RRRRRRRRRRRRRr...",
		"...NNNNNNNNNNNNNn...",
		"..NNNNNNNNNNNNNNNn..",
		"..NNNNNNNNNNNNNNNn..",
		"..nNNNNNNNNNNNNNNn..",
		".RRRnNNNNNNNNNNnRRR.",
		"RRRRRRRRRRRRRRRRRRRr",
		"ARRRRRRRRRRRRRRRRRrA",
		"NNn.RRRRRAARRRRr.nNn",
		"NNn.RRRRRAARRRRr.nNn",
		"NNn.RRRRRAARRRRr.nNn",
		"NNn.rrrrrrrrrrrr.nNn",
		"NNn.nNNNNNNNNNNn.nNn",
		"NNn.nNNNNNNNNNNn.nNn",
		"Nnn..nNNNNNNNNn..nNn",
		"AAA..nNNNnnNNNn..AAA",
		".....nNNn..nNNn.....",
		".....nNNn..nNNn.....",
		".....RRRr..RRRr.....",
		".....nNNn..nNNn.....",
		"....nnNNn..nNNnn....",
		"....nnnnn..nnnnn....",
	]],
	"side": [12, [  # facing right
		".........A....A.....",
		".........AA...AA....",
		"......RRRRRRRRRr....",
		".....RRRRRRRRRRRr...",
		"....RRRRRRRRRRRRRr..",
		"....NNNNNNNNNNNNNn..",
		"...NNNNNNNNNNNYYYNn.",
		"...NNNNNNNNNNNNNNNn.",
		"...nNNNNNNNNNNNDTDn.",
		"..RRRRnNNNNNNNNNDDn.",
		".RRRRRRRRNNNNNNNNn..",
		".ARRRRRRRRRRRRRRRr..",
		"..RRRRRRRRRRRRRRRr..",
		"..RRRRRRRRRRRnNNNn..",
		"..RRRRRRRRRRRnNNNn..",
		"..nrrrrrrrrrrnNNNn..",
		"...nNNNNNNNNNnNNNn..",
		"...nNNNNNNNNNnNNNn..",
		"....nNNNNNNNNnAAAA..",
		"....nNNNNnNNNn......",
		"....nNNNn.nNNNn.....",
		"....nNNNn.nNNNn.....",
		"....RRRr..RRRRr.....",
		"....nNNNn.nNNNn.....",
		"...nnNNNn.nNNNNn....",
		"...nnnnnn.nnnnnn....",
	]],
}

# --- characters: body, palette (GDD tab:style-guide colours first), gear overlays -------------------

const SKIN_L := {"S": "E9B48A", "s": "C98F66", "E": "1A1418"}
const BOOTS := {"B": "2E2620", "b": "1C1612"}
const NOX_PAL := {"N": "4A2C5A", "n": "2F1B3B", "M": "6B4380", "Y": "E8E3C8", "D": "120A16", "T": "E8E3C8", "A": "C63FA8", "a": "8A2A75"}

const CHARACTERS := {
	"scout": {  # CHR-01: lightly equipped soldier, teal #2BB3B1, bow slung on the back
		"body": "human",
		"pal": {"H": "6B4A2B", "h": "4E3520", "C": "2BB3B1", "L": "6FD9D5", "c": "1E7F7D", "G": "4A3626",
			"P": "5A6B34", "p": "3E4B23", "T": "36C9C6", "W": "7A5634", "w": "E8E3C8", "F": "36C9C6"},
		"over": {
			"down": [9, [  # headband; bow tip beside the shoulder; quiver strap across the chest
				"..TTTTTTTTTTTT..",
				"................",
				"...............W",
				"..............WW",
				"..............W.",
				"..............W.",
				"..............W.",
				"..............W.",
				".....W........W.",
				"......W.......W.",
				".......W......W.",
				"........W.....W.",
				".........W.....W",
			]],
			"up": [9, [  # headband knot; the bow across the back
				"..TTTTTTTTTTTT..",
				".......TT.......",
				".......TT.......",
				"................",
				"..............W.",
				"..............W.",
				".............W..",
				"...........WW...",
				"..........W.....",
				".........W......",
				"........W.......",
				".......W........",
				"......W.........",
				"....WW..........",
			]],
			"side": [9, [
				"...TTTTTTTTTTT..",
				"...TT...........",
				"..TT............",
				"...W............",
				"..Ww............",
				"..Ww............",
				"..Ww............",
				"..Ww............",
				"..Ww............",
				"..Ww............",
				"..Ww............",
				"..Ww............",
				"..Ww............",
				"...W............",
			]],
		},
	},
	"healer": {  # CHR-02: white #F2F2F2 with a green plus #3DBE5A (never a red cross), medical pack, flask
		"body": "human",
		"pal": {"H": "2B1E1A", "h": "1A120F", "S": "A86B45", "s": "82502F", "C": "F2F2F2", "L": "FFFFFF",
			"c": "C3CAD3", "G": "8A96A3", "P": "4A535E", "p": "353C45", "X": "3DBE5A", "K": "F2F2F2", "k": "8A96A3", "Z": "9BE3B0"},
		"over": {
			"down": [14, [
				"..H..........H..",
				"..H..........H..",
				"..H..........H..",
				"..k.........k...",
				"...k.......k....",
				".......X........",
				"......XXX.......",
				".......X........",
				"................",
				"..............Z.",
				"..............Z.",
			]],
			"up": [14, [
				"..hHHHHHHHHHHh..",
				"...HHHHHHHHHH...",
				"....HHHHHHHH....",
				"...kkkkkkkkkk...",
				"...kKKKKKKKKk...",
				"...kKKKXXKKKk...",
				"...kKKXXXXKKk...",
				"...kKKKXXKKKk...",
				"...kkkkkkkkkk...",
			]],
			"side": [14, [  # pack with its plus on the back; green armband
				"...HH...........",
				"...HHH..........",
				"..kkkk..........",
				"..kKKk..........",
				"..kXKk..........",
				"..XXXk.XX.......",
				"..kXKk..........",
				"..kKKk..........",
				"..kkkk..........",
			]],
		},
	},
	"engineer": {  # CHR-03: orange #FF7A1A hi-vis vest, hard hat, hammer always visible, tool pack: the heaviest look
		"body": "human",
		"pal": {"H": "3A2A20", "h": "261A13", "C": "FF7A1A", "L": "FFA65C", "c": "2B3A55", "G": "5A3E26",
			"P": "2B3A55", "p": "1E2A3F", "O": "FF7A1A", "o": "C2560A", "Q": "FFB070", "V": "D9DDE0",
			"M": "8A8F98", "m": "5B5F6B", "W": "7A5634", "D": "3A4250", "Y": "F2B544"},
		"over": {
			"down": [4, [
				".....OOQOO......",
				"...OOOOQOOOO....",
				"..OOOOOQOOOOo...",
				"..OOOOOQOOOOo...",
				"..OOOOOOOOOOo...",
				".oooooooooooooo.",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"MMM.............",
				"MmM.............",
				".W..............",
				".W..VVVVVVVV....",
				".W..............",
				".W..............",
				".W.....YY.......",
				".W..............",
			]],
			"up": [4, [
				"......OOQOO.....",
				"....OOOOQOOOO...",
				"...OOOOOQOOOOo..",
				"...OOOOOQOOOOo..",
				"..OOOOOOOOOOOo..",
				".oooooooooooooo.",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"...DDDDDDDDDD.MM",
				"...DOOOOOOOOD.Mm",
				"...DDDDDDDDDD..W",
				"...DDDDDDDDDD..W",
				"...DDDDDDDDDD..W",
				"...............W",
				"...............W",
			]],
			"side": [4, [
				".....OOOQOO.....",
				"....OOOOQOOOO...",
				"...OOOOOQOOOOo..",
				"...OOOOOQOOOOo..",
				"...OOOOOOOOOOo..",
				"..ooooooooooooo.",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"...DD...........",
				"..DDD...........",
				"..DOD.VVVV......",
				"..DDD...........",
				"..DDD...........",
				"...........MM...",
				".........WWMm...",
				"................",
			]],
		},
	},
	"grunt": {  # CHR-05: NOX body #4A2C5A, magenta #C63FA8 spines and marks, pale eyes #E8E3C8
		"body": "nox",
		"pal": {},
		"over": {
			"down": [8, [  # spine tips above the head; claw marks on the chest
				"....A......A....",
				"....aA....Aa....",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"......A...A.....",
				".......A...A....",
				"........A...A...",
			]],
			"up": [8, [
				"....A......A....",
				"....aA....Aa....",
				"................",
				".......AA.......",
				"......aAAa......",
				"................",
				".......AA.......",
				"......aAAa......",
				"................",
				".......AA.......",
				"......aAAa......",
			]],
			"side": [8, [
				"................",
				"...A..A.........",
				"..aAaaAa........",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"....A.A.........",
			]],
		},
	},
	"spitter": {  # CHR-06: Grunt-sized; glowing acid sac #D8E03A on the back and acid in the mouth (the ranged cue)
		"body": "nox",
		"pal": {"Q": "D8E03A", "q": "F6F9A8", "j": "8F9620"},
		"over": {
			"down": [8, [
				"..........jQQj..",
				".........jQqQQj.",
				".........QQQQQj.",
				".........jQQQj..",
				"................",
				"................",
				"................",
				"................",
				"................",
				".......QQ.......",
				"........Q.......",
				"........Q.......",
			]],
			"up": [11, [
				"................",
				".....jQQQQj.....",
				"....jQqqQQQj....",
				"....QQqQQQQQ....",
				"....QQQQQQQQ....",
				"....jQQQQQQj....",
				".....jQQQQj.....",
			]],
			"side": [8, [
				"..jQQj..........",
				".jQqQQj.........",
				".QQQQQQ.........",
				".jQQQQj.........",
				"..jQQj..........",
				"................",
				"................",
				"................",
				"..............Q.",
				"..............Q.",
			]],
		},
	},
	"wrecker": {  # CHR-07: 1.25 tiles, heavy and armoured: plates with magenta seams, horns
		"body": "wrecker",
		"pal": {"R": "6E5A7A", "r": "463650"},
		"over": {},
	},
}

const BODIES := {"human": HUMAN, "nox": NOX, "wrecker": WRECKER_BODY}
const VIEWS := ["side", "down", "side", "up"]  # sheet rows: right, down, left (mirrored), up


func _init() -> void:
	var out := "res://art/chars"
	DirAccess.make_dir_recursive_absolute(out)
	var info := {"frames": {"idle": [0, 2], "run": [2, 4]}, "fps": {"idle": 2.0, "run": 8.0},
		"dirs": ["right", "down", "left", "up"], "chars": {}}
	for n: String in CHARACTERS:
		var body: Dictionary = BODIES[CHARACTERS[n].body]
		var size: int = body.size
		var sheet := Image.create_empty(size * 6, size * 4, false, Image.FORMAT_RGBA8)
		for row in 4:
			var view: String = VIEWS[row]
			var base := _compose(n, view)
			var frames := [base, _bob(base, body), base, _step(base, body, view, 1), base, _step(base, body, view, -1)]
			for col in 6:
				var f: Image = _finish(frames[col], body)
				if row == 2:
					f.flip_x()
				sheet.blit_rect(f, Rect2i(0, 0, size, size), Vector2i(col * size, row * size))
		sheet.save_png(out.path_join(n + ".png"))
		info.chars[n] = {"size": size, "anchor": [size / 2.0, body.feet + 1]}
		print("drew ", n, " ", size, "x", size)
	var fa := FileAccess.open(out.path_join("chars.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(info, "\t"))
	fa.close()
	quit()


func _compose(n: String, view: String) -> Image:
	var ch: Dictionary = CHARACTERS[n]
	var body: Dictionary = BODIES[ch.body]
	var size: int = body.size
	var pal := {}
	for p: Dictionary in [SKIN_L, BOOTS, NOX_PAL, ch.pal]:
		pal.merge(p, true)
	var im := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var pad: int = (size - (body[view][1][0] as String).length()) / 2
	for layer: Array in [body[view], ch.over.get(view, [0, []])]:
		var top: int = layer[0]
		for r in layer[1].size():
			var line: String = layer[1][r]
			for i in line.length():
				var k := line[i]
				if k == ".":
					continue
				if not pal.has(k):
					push_error("%s %s: no colour for '%s'" % [n, view, k])
					continue
				im.set_pixel(pad + i, top + r, Color(pal[k]))
	return im


func _bob(src: Image, body: Dictionary) -> Image:
	## Idle breath: everything above the legs sinks one pixel.
	var im := src.duplicate() as Image
	var size: int = body.size
	var legs: int = body.legs
	im.fill_rect(Rect2i(0, 0, size, legs), Color(0, 0, 0, 0))
	im.blit_rect(src, Rect2i(0, 0, size, legs), Vector2i(0, 1))
	return im


func _step(src: Image, body: Dictionary, view: String, side: int) -> Image:
	## Walk pose. Front/back views: one foot lifts a pixel. Side view: the legs open into a stride (or cross).
	var im := src.duplicate() as Image
	var size: int = body.size
	var pad: int = (size - (16 if size == 32 else 20)) / 2
	var sp: Array = body.split[view]
	var top: int = body.legs
	var h: int = body.feet + 1 - top
	var a := Rect2i(pad + sp[0], top, sp[1] - sp[0], h)  # left / back leg
	var b := Rect2i(pad + sp[1], top, sp[2] - sp[1], h)  # right / front leg
	im.fill_rect(a, Color(0, 0, 0, 0))
	im.fill_rect(b, Color(0, 0, 0, 0))
	if view == "side":  # side > 0: legs apart; side < 0: legs cross
		im.blend_rect(src, a, a.position + Vector2i(-side, 0))
		im.blend_rect(src, b, b.position + Vector2i(side, 0))
	else:  # the lifted leg loses its top row, so its foot leaves the ground by one pixel
		var lift := a if side > 0 else b
		var stay := b if side > 0 else a
		im.blend_rect(src, stay, stay.position)
		im.blend_rect(src, Rect2i(lift.position + Vector2i(0, 1), lift.size - Vector2i(0, 1)), lift.position)
	return im


func _finish(src: Image, body: Dictionary) -> Image:
	## Dark outline around the silhouette, then a soft ground shadow under the feet.
	var size: int = body.size
	var im := src.duplicate() as Image
	for y in size:
		for x in size:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < size and q.y < size and src.get_pixel(q.x, q.y).a > 0.0:
					im.set_pixel(x, y, INK)
					break
	var cy: float = body.feet + 1.0
	var rx: float = body.shadow
	for y in range(int(cy) - 2, mini(size, int(cy) + 3)):
		for x in size:
			var dx := (x + 0.5 - size / 2.0) / rx
			var dy := (y + 0.5 - cy) / 2.2
			if dx * dx + dy * dy <= 1.0 and im.get_pixel(x, y).a == 0.0:
				im.set_pixel(x, y, SHADOW)
	return im
