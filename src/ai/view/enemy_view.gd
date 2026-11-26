class_name EnemyView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/ai/view/Main.EnemyView.cs.
# Owner: Vu Duc Viet Anh. How enemies and bosses look on the client: sprite choice, tint, attack and death
# frames, health bars, boss bar.
# Sprite sheets in art/chars/ belong to Mai Thien Ngon; this file only maps enemy state to them.
static var ENEMY_SKIN = ["grunt", "spitter", "wrecker", "wrecker"]
static var ENEMY_TINT = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
# sprite sheet per boss archetype, in GameSim.BOSS_KINDS order (Juggernaut .. Ironhide)
static var BOSS_SKIN = ["boss_juggernaut", "boss_broodmother", "boss_bio_cannon", "boss_burrower", "boss_gatebreaker", "boss_phantom", "boss_ironhide"]
# boss moves with a wind-up: it holds the first attack frame (arms up) until the move lands
static var BOSS_WIND = {"glow": true, "charge_wind": true, "blow": true, "slam": true, "ambush": true}
# a dead enemy plays its "down" frames where it fell, lies there, then fades (seconds)
const CORPSE_TIME: float = 2.4
# a dead enemy plays its "down" frames where it fell, lies there, then fades (seconds)
const CORPSE_FADE: float = 0.6
# 3x replaces 2x: every boss, including attacks and corpses, is 1.5 times its former size.
# Integer scaling preserves the pixel edges; gameplay collision/reach still use the simulation radius.
const BOSS_DRAW_SCALE: float = 3.0
# what each enemy on screen was last drawn as (by id), so it can fall over where it died
var en_seen = {}
var corpses = []
# bosses holding a wind-up, and when their move landed
var winding = {}
var strike_at = {}

# constants shared with Main
const GOLD = Main.GOLD
const INK = Main.INK
const NEON_PINK = Main.NEON_PINK
const NEON_RED = Main.NEON_RED
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

# Enemies drawn last frame that are gone from the snapshot died (or the night ended under them): they fall.
func note_fallen(shown) -> void:
	for key_ in Array(en_seen.keys()).duplicate():
		var _d1 = en_seen[key_]
		var id = _d1[0]
		var look = _d1[1]
		if not shown.has(id):
			look.at = float(main.clock)
			corpses.append(look)
			en_seen.erase(key_)

# out of a match: nothing carries over to the next one
func forget_fallen() -> void:
	en_seen.clear()
	corpses.clear()
	winding.clear()
	strike_at.clear()

# depth items [foot y, 12, index] for the corpses still showing
func corpse_items(items) -> void:
	Cs.remove_all(corpses, func(c): return float(main.clock) - c.at > CORPSE_TIME)
	var i: int = 0
	while i < corpses.size():
		# under anyone standing on the same spot
		if main.enemy_visible_at(corpses[i].foot, corpses[i].type):
			items.append([corpses[i].foot.y - 1.0, 12, i])
		i += 1

func draw_corpse(i: int) -> void:
	var c = corpses[i]
	var t: float = float(main.clock) - c.at
	var mod_: Color = c.mod
	mod_.a *= clampf((CORPSE_TIME - t) / CORPSE_FADE, 0.0, 1.0)
	main.player_view.char_(c.key, c.skin, c.foot, null, c.s, mod_, false, "idle", "down", t)

# Ground markers of boss moves (BAL-43): circle (slam, surfacing), line (charge) and arc (ambush).
# The inner fill grows as the hit comes closer.
func draw_telegraphs() -> void:
	for tl in main.snap.get("tele", []):
		var pos: Vector2 = Vector2(tl[0])
		# Only bosses create these warnings; the whole team must see them beyond personal sight.
		var r: float = float(tl[1])
		var left: float = float(tl[2])
		var kind = Cs.s(tl[3]) if tl.size() > 3 else "circle"
		if kind == "line":
			var end: Vector2 = Vector2(tl[4])
			var side: Vector2 = (end - pos).normalized().orthogonal() * r
			var quad = [pos + side, end + side, end - side, pos - side]
			main.draw_colored_polygon(quad, Color(1.0, 0.1, 0.3, 0.18))
			var mid: Vector2 = pos.lerp(end, 1.0 - left)
			main.draw_colored_polygon([pos + side, mid + side, mid - side, pos - side], Color(1.0, 0.15, 0.3, 0.3))
			main.draw_polyline([pos + side, end + side, end - side, pos - side, pos + side], NEON_RED, 2)
			continue
		if kind == "arc":
			var ang: float = float(tl[5])
			var half: float = float(tl[6]) / 2
			main.draw_colored_polygon(arc_fan(pos, r, ang, half), Color(1.0, 0.1, 0.3, 0.18))
			main.draw_colored_polygon(arc_fan(pos, r * (1.0 - left), ang, half), Color(1.0, 0.15, 0.3, 0.35))
			main.draw_arc(pos, r, ang - half, ang + half, 24, NEON_RED, 3)
			continue
		main.draw_circle(pos, r, Color(1.0, 0.1, 0.3, 0.16))
		main.draw_circle(pos, r * (1.0 - left), Color(1.0, 0.15, 0.3, 0.35))
		main.draw_arc(pos, r, 0, TAU, 48, NEON_RED, 3)

static func arc_fan(c: Vector2, r: float, ang: float, half: float) -> Variant:
	var pts = Cs.arr(18, Vector2.ZERO)
	pts[0] = c
	for i in range(17):
		pts[i + 1] = c + Vector2.from_angle(ang - half + 2 * half * i / 16.0) * maxf(r, 1.0)
	return pts

func draw_enemy(e, foot) -> void:
	var ty: int = int(e[1])
	var look = Cs.s(e[7]) if e.size() > 7 else ""
	# each boss archetype has its own sheet (art/chars/boss_*.png from tools/PixelBosses.cs)
	var skin = BOSS_SKIN[int(e[6])] if ty == GameSim.BOSS else ENEMY_SKIN[ty]
	var key_ = "e%d" % [e[0]]
	if look == "cloak":
		en_seen.erase(key_)
		# the Phantom is invisible while cloaked; only a faint shimmer gives it away up close
		if main.local_pos.distance_to(foot) < 2.5 * T:
			main.draw_arc(foot - Vector2(0, 16), e[5] * 0.8, 0, TAU, 24, Color(0.8, 0.7, 1.0, 0.18), 2)
		return
	if look == "burrow" or look == "surface":
		# the Burrower underground: a moving dirt mound
		en_seen.erase(key_)
		main.shadow(foot, e[5] * 0.9)
		main.draw_circle(foot - Vector2(0, 3), e[5] * 0.6, Color("5A4632"))
		main.draw_circle(foot - Vector2(0, 6), e[5] * 0.35, Color("7A6046"))
		return
	# the character's own size (the sheet cell has room around it for its attack)
	var size: float = float(main.cinfo.chars[skin].get("body", main.cinfo.chars[skin].size))
	# GDD size in tiles over the sprite's own size: the 40 px Wrecker is drawn 1:1. A boss is drawn much bigger
	# than its body (BOSS_DRAW_SCALE), so it towers over the players but still fits through a door.
	var s: float = BOSS_DRAW_SCALE if ty == GameSim.BOSS else float(e[5] / (0.5 * T) * 32.0 / size)
	var mod_: Color = ENEMY_TINT[ty]
	if ty == GameSim.BOSS:
		mod_ = Color.WHITE
		# wind-ups glow; recovery, stagger and climb-out (the weak windows) look dim
		if look == "glow" or look == "charge_wind" or look == "blow" or look == "slam" or look == "ambush":
			mod_ = mod_.lerp(Color(2.2, 1.6, 0.6), 0.5 + 0.5 * sin(main.clock * 18.0))
		elif look == "recover" or look == "stagger" or look == "climb":
			mod_ = mod_.darkened(0.35)
		elif look == "shown":
			mod_ = mod_.lerp(Color(0.8, 0.7, 1.0), 0.4)
	# Bosses need extra contrast beyond personal light; ordinary enemies keep their usual night tint.
	if main.snap.get("ph", "") == "night":
		mod_ *= 2.2 if ty == GameSim.BOSS else 1.5
		mod_.a = 1.0
	en_seen[key_] = [e[0], Cs.init(Fallen.new(), {"key": key_, "skin": skin, "s": s, "mod": ENEMY_TINT[ty], "foot": Vector2(foot), "type": ty})]
	if main.flash.has(e[0]):
		mod_ = Color(2.0, 2.0, 2.0)
	# attack frames: on each hit or spit (snapshot field 9); a boss holds the wind-up frame through its
	# wind-up and strikes when the move lands
	var play = null
	var play_t: float = 0.0
	var now: float = float(main.clock)
	var start: float = main.anim.swing_start(key_, e.size() > 9 and e[9])
	if ty == GameSim.BOSS and BOSS_WIND.has(look):
		Cs.set_add(winding, key_)
		play = "attack"
	else:
		if winding.erase(key_):
			# straight to the slam (frame 1 of 4 at 10 frames/s)
			strike_at[key_] = now - 0.1
		var sa = strike_at.get(key_, 0.0)
		var from: float = maxf(start, sa if strike_at.has(key_) else -1.0)
		if from >= 0 and now - from < main.anim.anim_length(skin, "attack"):
			play = "attack"
			play_t = now - from
	main.player_view.char_(key_, skin, foot, float(e[8]) if ty == GameSim.BOSS else null, s, mod_, play == "attack", "idle", play, play_t)
	if e.size() > 10 and e[10]:
		var at: Vector2 = Vector2(foot) - Vector2(0, size * s * 0.65)
		main.draw_arc(at, 9.0, 0, TAU, 12, Color("DDD681"), 2.0)
		for i in range(3):
			main.draw_circle(at + Vector2.from_angle(i * TAU / 3 + float(main.clock) * 3) * 9.0, 2.0, Color("FFF3B4"))
	if e.size() > 11 and e[11]:
		main.draw_arc(Vector2(foot), float(e[5]), 0, TAU, 20, Color("83DDD8"), 3.0)
	if e[3] < e[4] and ty != GameSim.BOSS:
		main.bar(foot - Vector2(0, size * 0.7 * s + 4), e[5] * 2.2, e[3] / e[4], NEON_RED)

# --- HUD drawing (screen space) -----------------------------------------
# Night: how many of the night's enemies are down, under the generator panel. It fills as they die; full (and
# the three supplies in) means dawn comes (src/ai/sim_night_spawns.gd).
const NIGHT_BAR_H: float = 30.0

func draw_night_bar(c, cx: float) -> void:
	if main.snap.get("ph", "") != "night":
		return
	var nq = main.snap.get("nq", null)
	if nq == null or int(nq[1]) <= 0:
		return
	var down: int = int(nq[0])
	var all: int = int(nq[1])
	var frac: float = clampf(float(down) / all, 0.0, 1.0)
	var box_ = Rect2(cx - 160, 56, 320, NIGHT_BAR_H - 4)
	var cw = c
	main.panel(cw, box_)
	main.text(cw, Vector2(cx - 150, 70), "NIGHT %d" % [main.snap.k], 11, GOLD, 0, -1.0, true)
	var bar_ = Rect2(cx - 90, 64, 240, 7)
	c.draw_rect(bar_.grow(1), INK)
	c.draw_rect(bar_, Color(0.22, 0.24, 0.3))
	# red while the night still has enemies, green once the last one is down
	var fill: Color = Color("3DBE5A") if frac >= 1.0 else NEON_RED.lerp(Color("F2B544"), frac)
	c.draw_rect(Rect2(bar_.position, Vector2(bar_.size.x * frac, bar_.size.y)), fill)

func draw_boss_bar(c, cx) -> void:
	for e in main.snap.en:
		if e[1] == GameSim.BOSS:
			# below the night bar
			var dy: float = NIGHT_BAR_H if main.snap.get("ph", "") == "night" else 0.0
			var br = Rect2(cx - 230, 66 + dy, 460, 10)
			main.text(c, Vector2(cx - 230, 62 + dy), SimBosses.boss_title(e[6]).to_upper(), 12, NEON_PINK, 1, 460, true)
			c.draw_rect(br.grow(2), INK)
			c.draw_rect(Rect2(br.position, Vector2(br.size.x * e[3] / e[4], br.size.y)), NEON_PINK)
			for x in [br.position.x - 6, br.end.x + 6]:
				main.diamond(c, Vector2(x, br.get_center().y), 8, NEON_PINK)

class Fallen:
	var type: int = -1
	var key
	var skin
	var s: float = 0.0
	var at: float = 0.0
	var mod: Color = Color(0, 0, 0, 0)
	var foot: Vector2 = Vector2.ZERO
