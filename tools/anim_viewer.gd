class_name AnimViewer
extends Node2D
# Owner: Viet Anh. Looks at every sprite animation in art/chars without playing a match:
#   godot --path . tools/AnimViewer.tscn
# The top shows the chosen animation playing in all 8 directions, the bottom every frame of it in one direction.
# The red cross is the anchor (where the game puts the character's feet).
#   Left / Right  character        Up / Down  animation        Z / X  direction of the frame strip
#   Space  pause    , / .  one frame back / forward (paused)    - / +  speed    Esc  quit
# Start somewhere else with  -- --char=wrecker --anim=down  (--shot=file.png saves a screenshot and quits).
static var DIRS = ["right", "down", "left", "up", "down_right", "down_left", "up_left", "up_right"]
static var SPEEDS = [0.125, 0.25, 0.5, 1.0, 2.0]
# a one-shot animation holds its last frame this long before playing again
const HOLD: float = 0.8
var sheets = []
var who: int = 0
var which: int = 0
var strip_dir: int = 1
var speed: int = 3
var paused: bool = false
var t: float = 0.0
var up: float = 0.0
var shot = ""
var sheet_review: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames = null
	var fps = null
	for file in ["chars.json", "bosses.json"]:
		var info = JSON.parse_string(FileAccess.get_file_as_string("res://art/chars/" + file))
		# bosses.json has no idle / run of its own: the bosses use the same columns as chars.json
		if info.has("frames"):
			frames = info["frames"]
			fps = info["fps"]
		var chars = info["chars"]
		for key in chars:
			var value = chars[key]
			var c = value
			var a = c["anchor"]
			var s = Cs.init(Sheet.new(), {"name": str(key), "tex": load("res://art/chars/" + str(key) + ".png"), "size": int(c["size"]), "anchor": Vector2(float(a[0]), float(a[1]))})
			s.resolution = float(c.get("resolution", 1.0))
			# the looping ones (idle, run) are listed at the top of the json, the one-shots under each character
			for n in frames:
				var f = frames[n]
				var r = f
				s.anims.append(Cs.init(Anim.new(), {"name": str(n), "first": int(r[0]), "count": int(r[1]), "fps": float(fps[n]), "loop": true}))
			if c.has("anims"):
				var names = []
				for n in c["anims"]:
					var _unused = c["anims"][n]
					names.append(str(n))
				# attacks first (in the order of the sheet), then down
				var one = c["anims"]
				Cs.sort_cmp(names, func(x, y): return Cs.compare(int(one[x][0]), int(one[y][0])))
				for n in names:
					# Old four-frame tool poses are still used for repairs/item use.
					# The viewer lists the actual six-frame weapon attacks instead.
					if c.has("combat") and n.begins_with("attack_"):
						continue
					var r = one[n]
					s.anims.append(Cs.init(Anim.new(), {"name": n, "first": int(r[0]), "count": int(r[1]), "fps": float(r[2]), "loop": n.begins_with("gather_") or n == "charge_run"}))
			for n in c.get("combat", {}):
				var clip: Dictionary = c.combat[n]
				var attack := Anim.new()
				attack.name = n
				attack.count = int(info.combat.frames)
				attack.fps = float(clip.fps) * GameSim.WEAPON_ATTACK_SPEED
				attack.regions = clip.rows
				for direction in clip.rows:
					for region in direction:
						attack.bounds = attack.bounds.merge(Rect2(-Vector2(region[4], region[5]), Vector2(region[2], region[3])))
				s.anims.append(attack)
			for n in c.get("reactions", {}):
				var clip: Dictionary = c.reactions[n]
				var reaction := Anim.new()
				reaction.name = n
				reaction.count = int(clip.count)
				reaction.fps = float(clip.fps)
				reaction.regions = clip.rows
				for direction in clip.rows:
					for region in direction:
						reaction.bounds = reaction.bounds.merge(Rect2(-Vector2(region[4], region[5]), Vector2(region[2], region[3])))
				s.anims.append(reaction)
			for n in c.get("held", {}):
				var clip: Dictionary = c.held[n]
				var held := Anim.new()
				held.name = n
				held.count = int(clip.count)
				held.fps = float(clip.fps)
				held.loop = true
				held.regions = clip.rows
				for direction in clip.rows:
					for region in direction:
						held.bounds = held.bounds.merge(Rect2(-Vector2(region[4], region[5]), Vector2(region[2], region[3])))
				s.anims.append(held)
			sheets.append(s)
	# start on the first attack of the first character, unless told otherwise
	which = mini(2, sheets[0].anims.size() - 1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--char="):
			who = maxi(0, Cs.find_index(sheets, func(s): return s.name == arg.substr(7)))
		elif arg.begins_with("--anim="):
			which = maxi(0, Cs.find_index(sheets[who].anims, func(a): return a.name == arg.substr(7)))
		elif arg.begins_with("--shot="):
			shot = arg.substr(7)
		elif arg == "--sheet":
			sheet_review = true
		elif arg.begins_with("--dir="):
			strip_dir = clampi(int(arg.substr(6)), 0, 7)
	if not Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--anim=")):
		var attack_index: int = Cs.find_index(sheets[who].anims, func(a): return a.name == "combat_stone_spear")
		if attack_index >= 0:
			which = attack_index

var current:
	get:
		return sheets[who].anims[which]

# the column shown at time T
func frame(a, at: float) -> int:
	var f: int = int(floorf(at * a.fps))
	if a.loop:
		return a.first + (f % a.count + a.count) % a.count
	var cycle: float = a.count / a.fps + HOLD
	f = int(floorf(fposmod(at, cycle) * a.fps))
	return a.first + mini(f, a.count - 1)

func _process(delta: float) -> void:
	if not paused:
		t += delta * SPEEDS[speed]
	queue_redraw()
	up += delta
	if shot != "" and up > 0.5:
		var image := get_viewport().get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
		image.save_png(shot)
		get_tree().quit()

func _unhandled_input(e) -> void:
	var k = e
	if not e is InputEventKey or not k.pressed:
		return
	var s = sheets[who]
	var _sw1 = k.keycode
	if _sw1 == KEY_RIGHT:
		pick(1)
	elif _sw1 == KEY_LEFT:
		pick(-1)
	elif _sw1 == KEY_DOWN:
		which = (which + 1) % s.anims.size()
		t = 0
	elif _sw1 == KEY_UP:
		which = (which - 1 + s.anims.size()) % s.anims.size()
		t = 0
	elif _sw1 == KEY_Z:
		strip_dir = (strip_dir - 1 + 8) % 8
	elif _sw1 == KEY_X:
		strip_dir = (strip_dir + 1) % 8
	elif _sw1 == KEY_SPACE:
		paused = not paused
	elif _sw1 == KEY_PERIOD:
		paused = true
		t += 1.0 / current.fps
	elif _sw1 == KEY_COMMA:
		paused = true
		t = maxf(0, t - 1.0 / current.fps)
	elif _sw1 == KEY_MINUS or _sw1 == KEY_KP_SUBTRACT:
		speed = maxi(0, speed - 1)
	elif _sw1 == KEY_EQUAL or _sw1 == KEY_PLUS or _sw1 == KEY_KP_ADD:
		speed = mini(SPEEDS.size() - 1, speed + 1)
	elif _sw1 == KEY_ESCAPE:
		get_tree().quit()

# another character, keeping the same animation when it has one of that name
func pick(step: int) -> void:
	var was = current.name
	who = (who + step + sheets.size()) % sheets.size()
	var i: int = Cs.find_index(sheets[who].anims, func(a): return a.name == was)
	which = i if i >= 0 else mini(which, sheets[who].anims.size() - 1)
	t = 0

func _draw() -> void:
	if sheet_review and draw_combat_sheet():
		return
	var view = get_viewport_rect().size
	var font = ThemeDB.fallback_font
	var s = sheets[who]
	var a = current
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.13, 0.14, 0.17))
	var pad: float = 12
	var gap: float = 10
	var head: float = 40
	var foot: float = 26
	var logical_size: float = maxf(a.bounds.size.x, a.bounds.size.y) if not a.regions.is_empty() else s.size / s.resolution
	# the bottom strip is a third of the height, the 8 directions get the rest
	var strip_h: float = (view.y - head - foot) * 0.32
	var grid_h: float = view.y - head - foot - strip_h - gap
	var big: float = maxf(.5, minf((view.x - 2 * pad - 3 * gap) / (4 * logical_size), (grid_h - gap - 32) / (2 * logical_size)))
	var small: float = maxf(.5, minf((view.x - 2 * pad - 4 * (a.count - 1)) / (a.count * logical_size), (strip_h - 18) / logical_size))
	var title = "%s  (%s/%s)   %s  [%s..%s]  %s fps  x%s%s" % [s.name, who + 1, sheets.size(), a.name, a.first, a.first + a.count - 1, Cs.s(a.fps), Cs.s(SPEEDS[speed]), "  PAUSED" if paused else ""]
	draw_string(font, Vector2(pad, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var col: int = frame(a, t)
	var cell_w: float = logical_size * big
	var x0: float = floorf((view.x - (4 * cell_w + 3 * gap)) / 2)
	for d in range(8):
		var at = Vector2(x0 + d % 4 * (cell_w + gap), head + d / 4 * (cell_w + 16 + gap))
		cell(s, col, d, at, big, d == strip_dir)
		draw_string(font, at + Vector2(0, cell_w + 13), DIRS[d], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.78, 0.85))
	# every frame of the animation in one direction, the one playing outlined
	var sy: float = view.y - foot - strip_h
	draw_string(font, Vector2(pad, sy + 12), "frames, %s (Z / X)" % [DIRS[strip_dir]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.78, 0.85))
	var sw: float = logical_size * small
	var sx: float = floorf((view.x - (a.count * sw + (a.count - 1) * 4)) / 2)
	for f in range(a.count):
		var at = Vector2(sx + f * (sw + 4), sy + 18)
		cell(s, a.first + f, strip_dir, at, small, a.first + f == col)
	draw_string(font, Vector2(pad, view.y - 8), "Left/Right character   Up/Down animation   Z/X strip direction   Space pause   , . step   - + speed   Esc quit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.58, 0.65))

# Exportable contact sheet of the actual PNG regions, without game effects or overlays.
# -- --char=engineer --sheet --dir=0 --shot=res://.tmp/engineer-attacks.png
func draw_combat_sheet() -> bool:
	var s = sheets[who]
	var attacks: Array = s.anims.filter(func(a): return a.name.begins_with("combat_"))
	if attacks.is_empty():
		return false
	var view: Vector2 = get_viewport_rect().size
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, view), Color("20242B"))
	draw_string(font, Vector2(16, 28), "%s / %s" % [s.name.to_upper(), DIRS[strip_dir]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	var label_width: float = 158
	var cw: float = (view.x - label_width - 12) / 6
	var rh: float = (view.y - 62) / attacks.size()
	var bounds := Rect2()
	for a in attacks:
		for region in a.regions[strip_dir]:
			bounds = bounds.merge(Rect2(-Vector2(region[4], region[5]), Vector2(region[2], region[3])))
	var zoom: float = minf((cw - 10) / bounds.size.x, (rh - 8) / bounds.size.y)
	for pose in range(6):
		draw_string(font, Vector2(label_width + pose * cw + 8, 52), ["Ready", "Draw back", "Extend", "Strike", "Return", "Reset"][pose], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("B4BAC3"))
	for index in range(attacks.size()):
		var a = attacks[index]
		var y: float = 60 + index * rh
		draw_string(font, Vector2(12, y + rh / 2), a.name.trim_prefix("combat_").replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("EAC16C"))
		for pose in range(6):
			var at := Vector2(label_width + pose * cw, y)
			for cy in range(ceili(rh / 8)):
				for cx in range(ceili(cw / 8)):
					draw_rect(Rect2(at + Vector2(cx * 8, cy * 8), Vector2(minf(8, cw - cx * 8), minf(8, rh - cy * 8))), Color("2C313A") if (cx + cy) % 2 else Color("252A32"))
			var foot: Vector2 = at + (Vector2(cw, rh) - bounds.size * zoom) / 2 - bounds.position * zoom
			var region: Array = a.regions[strip_dir][pose]
			var source := Rect2(region[0], region[1], region[2], region[3])
			draw_texture_rect_region(s.tex, Rect2(foot - Vector2(region[4], region[5]) * zoom, source.size * zoom), source)
	return true

# one sheet cell scaled up, on a checkerboard, with the anchor marked
func cell(s, col: int, row: int, at: Vector2, zoom: float, lit: bool) -> void:
	var a = current
	var packed: bool = not a.regions.is_empty()
	var logical_size: float = maxf(a.bounds.size.x, a.bounds.size.y) if packed else s.size / s.resolution
	var w: float = logical_size * zoom
	var q: float = maxf(4, 4 * zoom)
	var y: float = 0
	while y < w:
		var x: float = 0
		while x < w:
			var odd: bool = (int(x / q) + int(y / q)) % 2 == 1
			draw_rect(Rect2(at + Vector2(x, y), Vector2(minf(q, w - x), minf(q, w - y))), Color(0.24, 0.26, 0.3) if odd else Color(0.2, 0.22, 0.26))
			x += q
		y += q
	var p: Vector2 = at + s.anchor / s.resolution * zoom
	if packed:
		# All frames share one foot anchor in the preview, just as they do in game.
		p = at - a.bounds.position * zoom + (Vector2.ONE * logical_size - a.bounds.size) * zoom / 2
		var region: Array = a.regions[row][col]
		var source := Rect2(region[0], region[1], region[2], region[3])
		draw_texture_rect_region(s.tex, Rect2(p - Vector2(region[4], region[5]) * zoom, source.size * zoom), source)
	else:
		draw_texture_rect_region(s.tex, Rect2(at, Vector2(w, w)), Rect2(col * s.size, row * s.size, s.size, s.size))
	var red = Color(1, 0.3, 0.3, 0.8)
	draw_line(p - Vector2(zoom * 2, 0), p + Vector2(zoom * 2, 0), red, 1)
	draw_line(p - Vector2(0, zoom * 2), p + Vector2(0, zoom * 2), red, 1)
	draw_rect(Rect2(at, Vector2(w, w)), Color(1, 0.85, 0.3) if lit else Color(0.35, 0.38, 0.45), false, 2 if lit else 1)

class Anim:
	var name
	var first: int = 0
	var count: int = 0
	var fps: float = 0.0
	var loop: bool = false
	var regions: Array = []
	var bounds := Rect2()

class Sheet:
	var name
	var tex
	var size: int = 0
	var resolution: float = 1.0
	var anchor: Vector2 = Vector2.ZERO
	var anims = []
