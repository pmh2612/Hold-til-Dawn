class_name PlayerView
extends RefCounted

# Part of Main (main.gd); in the C# version this was in Main.cs.
# Owner: Mai Thien Ngon.
var slash_t = {}
var combat_info: Dictionary = {}

# constants shared with Main
const CHAR_H = Main.CHAR_H
const INK = Main.INK
const LIFT = Main.LIFT
const NEON_RED = Main.NEON_RED
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

func load_combat_art() -> void:
	combat_info = main.cinfo.get("combat", {})

func combat_animation(skin: String, name_: String) -> Variant:
	var art: Dictionary = main.cinfo.get("chars", {}).get(skin, {})
	return art.get("combat", {}).get(name_, art.get("reactions", {}).get(name_))

# Read the selected stack itself: p[8] only describes weapons and becomes fists for resources/tools.
static func held_item(p: Array) -> String:
	if p.size() <= 25 or int(p[5]) != 0:
		return ""
	var slots: Array = p[7]
	var selected: int = int(p[25])
	if selected < 0 or selected >= slots.size():
		return ""
	var stack = slots[selected]
	return Cs.s(stack[0]) if stack != null and int(stack[1]) > 0 else ""

func draw_player(id, p, foot) -> void:
	var r = T * 0.42
	var aim: float = float(p[12])
	if id == main.my_id:
		aim = (main.get_global_mouse_position() - (main.local_pos - Vector2(0, LIFT))).angle()
	# role ring on the ground, so roles read apart
	main.draw_set_transform(foot, 0, Vector2(1.0, 0.45))
	main.draw_arc(Vector2.ZERO, r * 1.15, 0, TAU, 32, Main.ROLE_COL[p[1]], 2.5)
	main.draw_set_transform(Vector2.ZERO)
	var skin = Cs.s(Main.ROLE_SKIN[p[1]])
	if p[5] == 1:
		# knocked down: falls over once (the sheet's "down" frames), then lies still with the eyes shut
		self.char_(id, skin, foot, null, 1.0, Color(0.85, 0.8, 0.85), false, "idle", "down", main.anim.down_time(id, true))
		return
	if p[5] == 2:
		# dead: lies still, greyed, with a cross over the body
		self.char_(id, skin, foot, null, 1.0, Color(0.5, 0.48, 0.55), false, "idle", "down", main.anim.down_time(id, true) + 10.0)
		var x: Vector2 = Vector2(foot) - Vector2(0, 22)
		main.draw_line(x + Vector2(-4, -4), x + Vector2(4, 4), NEON_RED, 2)
		main.draw_line(x + Vector2(4, -4), x + Vector2(-4, 4), NEON_RED, 2)
		return
	main.anim.down_time(id, false)
	var poison_left: float = float(main.snap.get("poisoned", {}).get(id, 0.0))
	var slow_left: float = float(main.snap.get("slowed", {}).get(id, 0.0))
	var tint: Color = Color.WHITE
	if poison_left > 0.0:
		tint = Color.WHITE.lerp(Color("66F258"), 0.45 + 0.2 * sin(float(main.clock) * 9.0))
		draw_poison_ground(Vector2(foot))
	elif slow_left > 0.0:
		tint = Color.WHITE.lerp(Color("7ADFFF"), 0.42 + 0.15 * sin(float(main.clock) * 7.0))
	var hit = main.anim.hit_reaction(id, p)
	if hit != null:
		main.shadow(Vector2(foot), 10.0)
		if hit[0] in ["stunned", "rooted", "shocked"]:
			var hit_tint: Color = tint.lerp(Color(0.75, 2.0, 2.6), 0.55) if hit[0] == "shocked" else tint
			self.char_(id, skin, Vector2(foot), float(hit[3]), 1.0, hit_tint, false, "idle", "idle", 0.0)
			if poison_left > 0.0:
				draw_poison_bubbles(id, Vector2(foot))
			if slow_left > 0.0:
				draw_frost_shards(id, Vector2(foot))
			if hit[0] == "stunned":
				var head: Vector2 = Vector2(foot) - Vector2(0, 41)
				main.draw_arc(head, 9, 0, TAU, 16, Color("D3AA58"), 1.0)
				for i in range(3):
					var star: Vector2 = head + Vector2(cos(main.clock * 5 + i * TAU / 3) * 10, sin(main.clock * 5 + i * TAU / 3) * 4)
					main.draw_line(star - Vector2(2, 0), star + Vector2(2, 0), Color("FFF1A8"), 2.0)
					main.draw_line(star - Vector2(0, 2), star + Vector2(0, 2), Color("FFF1A8"), 2.0)
			elif hit[0] == "rooted":
				for i in range(4):
					var off_x: float = (i - 1.5) * 6.5
					var h: float = 11.0 if i in [1, 2] else 8.0
					var base_pt: Vector2 = Vector2(foot) + Vector2(off_x, 2.0)
					main.draw_colored_polygon(PackedVector2Array([base_pt - Vector2(3, 0), base_pt + Vector2(3, 0), base_pt + Vector2(off_x * 0.2, -h)]), Color("D6C094"))
			else:
				for i in range(4):
					var a: float = float(main.clock) * 14.0 + i * TAU / 4.0
					var p0: Vector2 = Vector2(foot) - Vector2(0, 18) + Vector2.from_angle(a) * 10.0
					var p1: Vector2 = p0 + Vector2.from_angle(a + 0.9) * 7.0
					main.draw_line(p0, p1, Color(0.7, 2.2, 2.7), 2.0)
			return
		var hit_raw = main.snap.get("hit_reactions", {}).get(id)
		if hit_raw != null and Cs.s(hit_raw[1]) == "pull":
			var drag_back: Vector2 = -Vector2(hit_raw[4]).normalized()
			for i in range(3):
				var off: float = fposmod(float(main.clock) * 18.0 + i * 7.0, 20.0)
				var dust_at: Vector2 = Vector2(foot) + drag_back * (4.0 + off) + Vector2(0, -2.0 - i * 1.5)
				var alpha: float = clampf(1.0 - off / 20.0, 0.0, 0.75)
				main.draw_circle(dust_at, 3.0 - i * 0.5, Color(0.76, 0.71, 0.62, alpha))
		self.char_(id, skin, Vector2(foot) - Vector2(0, hit[2]), float(hit[3]), 1.0, tint, true, hit[0], hit[0], float(hit[1]))
		if poison_left > 0.0:
			draw_poison_bubbles(id, Vector2(foot) - Vector2(0, hit[2]))
		return
	if p[11]:
		slash_t[id] = main.clock
	var fighting: bool = main.clock - slash_t.get(id, -9.0) < 0.4
	if id == main.my_id and Input.is_mouse_button_pressed(1):
		fighting = true
	var activity = p[22] if p.size() > 22 else "idle"
	if p[11]:
		activity = "attack"
	if activity in ["gather", "repair", "revive", "loot"]:
		aim = (p[23] - p[2]).angle()
	# the attack frames of the weapon in hand (src/gameplay/view/anim.gd)
	var attack = main.anim.player_attack(id, p, skin)
	if attack != null and attack.size() > 2:
		aim = float(attack[2])
		fighting = true
	var gather = main.harvest_view.gather_animation(Vector2(p[23])) if activity == "gather" and attack == null else null
	# Reuse each role's own sprite frames for working, rather than leaving the actor idle.
	if attack == null and activity in ["repair", "loot"]:
		gather = "attack_hammer" if activity == "repair" else "gather_herb"
	var _v1 = (attack[0] if attack != null else null)
	var _v2 = (attack[1] if attack != null else null)
	main.tactical_items.draw_haste(id, p, Vector2(foot))
	if attack != null and Cs.s(attack[0]).begins_with("combat_"):
		var weapon: String = Cs.s(attack[0]).trim_prefix("combat_")
		main.tactical_items.draw_attack_range(Vector2(foot), aim, weapon, float(attack[1]) / main.anim.anim_length(skin, attack[0]))
	self.char_(id, skin, foot, aim, 1.0, tint, fighting or activity != "idle", activity, _v1 if _v1 != null else gather, _v2 if _v2 != null else 0.0, gather != null, held_item(p))
	if poison_left > 0.0:
		draw_poison_bubbles(id, Vector2(foot))
	else:
		main.tactical_items.draw_heal_aura(id, p, Vector2(foot))
	if slow_left > 0.0:
		draw_frost_shards(id, Vector2(foot))
	self.draw_activity(foot, aim, activity)

func draw_frost_shards(id, foot: Vector2) -> void:
	var now: float = float(main.clock)
	for i in range(3):
		var a: float = now * 3.0 + float(int(id)) + i * TAU / 3.0
		var at: Vector2 = foot + Vector2(cos(a) * 11.0, -14.0 + sin(a) * 5.0)
		main.draw_colored_polygon(PackedVector2Array([at - Vector2(0, 3), at + Vector2(2.5, 0), at + Vector2(0, 3), at - Vector2(2.5, 0)]), Color(0.65, 1.9, 2.35, 0.9))

func draw_poison_ground(foot: Vector2) -> void:
	var pulse: float = 0.55 + 0.3 * sin(float(main.clock) * 8.0)
	main.draw_set_transform(foot, 0, Vector2(1.0, 0.45))
	main.draw_circle(Vector2.ZERO, T * 0.44, Color(0.32, 0.88, 0.3, 0.24 * pulse))
	main.draw_set_transform(Vector2.ZERO)

func draw_poison_bubbles(id, foot: Vector2) -> void:
	var now: float = float(main.clock)
	var seed_v: float = float(int(id)) * 1.37
	# Rising toxic green bubbles around the character's body.
	for i in range(4):
		var k: float = fposmod(now * 1.2 + i * 0.25 + seed_v, 1.0)
		var x_off: float = sin(now * 3.5 + i * 2.1 + seed_v) * 8.0 + (i - 1.5) * 3.5
		var y_off: float = -4.0 - k * 28.0
		var at: Vector2 = foot + Vector2(x_off, y_off)
		var alpha: float = clampf(sin(k * PI) * 1.3, 0.0, 0.95)
		var r: float = 2.6 - k * 0.8
		main.draw_circle(at, r + 0.8, Color(0.12, 0.42, 0.16, 0.75 * alpha))
		main.draw_circle(at, r, Color(0.45, 0.94, 0.36, alpha))
		main.draw_rect(Rect2((at - Vector2(1, 1)).round(), Vector2(1.5, 1.5)), Color(0.92, 1.0, 0.85, alpha))
	# Two tiny dripping acid drops falling toward the feet.
	for j in range(2):
		var d: float = fposmod(now * 1.6 + j * 0.5 + seed_v, 1.0)
		var at: Vector2 = foot + Vector2((-5.5 if j == 0 else 5.5), -18.0 + d * 17.0)
		main.draw_rect(Rect2(at.round(), Vector2(2, 3)), Color(0.46, 0.92, 0.36, 0.85 * (1.0 - d * 0.5)))

# compass octant (0 = right, counting clockwise on screen) to the sheet row
static var OCT_ROW = [0, 4, 1, 5, 2, 6, 3, 7]

func char_(key_, skin, foot, aim, s, mod_, lock = null, activity = null, play = null, play_t: float = 0.0, loop: bool = false, carried = null) -> void:
	if lock == null: lock = false
	if activity == null: activity = "idle"
	# A pixel-art character: the walk cycle while it moves, idle breathing otherwise.
	# `play` names a one-shot animation of its sheet (an attack, "down") shown `play_t` seconds in; its last
	# frame holds. Knocked down it keeps the direction it last faced.
	# While it walks it faces where it walks (no moonwalking); standing still it faces `aim` (the mouse),
	# and with `lock` (fighting) it faces `aim` even on the move. With aim null (enemies) it faces its walk.
	var m = main.cmove.get(key_)
	if m == null:
		m = [foot, -1.0, PI / 2, -1]
	var step: Vector2 = Vector2(foot - m[0])
	if step.length() > 0.2:
		m[1] = main.clock
		m[2] = step.angle()
	m[0] = foot
	main.cmove[key_] = m
	var tex = main.csheet.get(skin)
	if tex == null:
		return
	var moving: bool = main.clock - m[1] < 0.15
	var anim = "run" if moving else "idle"
	var ang: float = float(m[2] if aim == null or moving and not lock else aim)
	# 8 directions. Sheet rows: right, down, left, up, then down-right, down-left, up-left, up-right.
	# The facing only changes once the angle is well past the edge between two directions, so walking
	# diagonally (two keys) or sliding along a wall never flickers between neighbouring rows.
	var c0 = main.cinfo.chars[skin]
	var combat = null if play == null else combat_animation(Cs.s(skin), Cs.s(play))
	var one = null if play == null else c0.get("anims", {}).get(play, null)
	if combat != null:
		one = [0, combat_info.frames, combat.fps]
	elif play == null and carried != null:
		var hold_name: String = "hold_%s_%s" % ["empty" if carried == "" else carried, anim]
		combat = c0.get("held", {}).get(hold_name)
		if combat != null:
			play = hold_name
			loop = true
			one = [0, combat.count, combat.fps]
	var rows: int = 8 if c0.has("combat") else int(tex.get_height() / c0.size)
	var dir: int = 0
	if rows >= 8:
		var oct: int = wrapi(roundi(ang / (PI / 4.0)), 0, 8)
		var last: int = int(m[3])
		if last >= 0 and one != null and play == "down":
			oct = last
		elif last >= 0 and absf(angle_difference(ang, last * PI / 4.0)) < PI / 8.0 + 0.2:
			oct = last
		m[3] = oct
		dir = OCT_ROW[oct]
	else:
		dir = wrapi(roundi(ang / (PI / 2.0)), 0, 4)
	var state = play if loop else activity if activity != "idle" else anim
	var timing = main.anim_state.get(key_)
	if timing == null or timing[0] != state:
		timing = [state, main.clock]
	main.anim_state[key_] = timing
	var phase_time: float = float(main.clock - timing[1])
	var act_ = Cs.s(activity)
	if act_ in ["heal", "revive", "loot"]:
		foot.y += 2.0
	var fr = main.cinfo.frames[anim]
	# out of step with each other
	var k: int = int(phase_time * main.cinfo.fps[anim]) % int(fr[1])
	if moving and cos(m[2] - ang) < -0.2:
		k = int(fr[1]) - 1 - k
	var f: int = int(fr[0]) + k
	if one != null:
		var count: int = int(one[1])
		var frame_: int = int((phase_time if loop else play_t) * float(one[2]))
		f = int(one[0]) + (frame_ % count if loop else mini(count - 1, frame_))
	if combat != null:
		# One atlas draw contains the body, arms, weapon and depth ordering for this pose.
		var region: Array = combat.rows[dir][f]
		var source := Rect2(region[0], region[1], region[2], region[3])
		var anchor_ := Vector2(region[4], region[5])
		main.draw_texture_rect_region(tex, Rect2(Vector2(foot) - anchor_ * s, source.size * s), source, mod_)
		return
	var c = main.cinfo.chars[skin]
	# Source texels and world units are separate: boss atlases compensate for their 3x
	# drawing scale to match player pixels. The footprint and foot anchor stay fixed.
	var source_size = Vector2(c.size, c.size)
	var resolution: float = float(c.get("resolution", 1.0))
	var size = source_size / resolution
	var anchor = Vector2(c.anchor[0], c.anchor[1]) / resolution
	main.draw_texture_rect_region(tex, Rect2(foot - anchor * s, size * s), Rect2(Vector2(f, dir) * source_size, source_size), mod_)

# How a node looks as it is gathered (broken stages, chips): src/world/view/node_break.gd
func player_ui(id, p, foot, font) -> void:
	var r = T * 0.42
	var pos = foot - Vector2(0, 0 if p[5] == 1 else LIFT)
	if p[20] > 0:
		main.draw_arc(pos, r + 13, -PI / 2, -PI / 2 + TAU * p[20] / 2.0, 24, Color(2.2, 1.6, 0.5), 4)
	var prog: float = float(p[14] if p[14] > 0 else 1.0 - p[13] / 2.0 if p[13] > 0 else 0.0)
	if prog > 0:
		main.draw_arc(pos, r + 8, -PI / 2, -PI / 2 + TAU * prog, 24, Color(0.6, 2.0, 0.8), 3)
	# just above the head
	var top = foot - Vector2(0, (10.0 if p[5] != 0 else CHAR_H) + 2)
	if id != main.my_id and p[5] != 2:
		main.bar(top, T, p[3] / p[4], Color("3DBE5A"))
	var label = Cs.s(p[0]) + ("  DOWN %d" % [p[6]] if p[5] == 1 else "  DEAD" if p[5] == 2 else "")
	var lp = top + Vector2(-2 * T, -6)
	main.draw_string_outline(font, lp, label, 1, 4 * T, 7, 2, INK)
	main.draw_string(font, lp, label, 1, 4 * T, 7, NEON_RED if p[5] != 0 else Color.WHITE)

func draw_activity(foot, aim, activity) -> void:
	# Repair/build motion and its hammer are already drawn by the character sprite.
	if activity == "loot":
		var hand = foot - Vector2(0, 13) + Vector2.from_angle(aim) * 12
		var turn = Vector2.from_angle(main.clock * 10) * 4
		main.draw_line(hand - turn, hand + turn, Color("E7D19B"), 2)
		main.draw_circle(hand + turn, 2, Color("D7B76E"))
	elif activity in ["heal", "revive"]:
		var centre = foot - Vector2(0, 18)
		var pulse = 0.7 + 0.3 * sin(main.clock * 8)
		main.draw_line(centre - Vector2(4, 0), centre + Vector2(4, 0), Color(0.4, 1.8, 0.7, pulse), 3)
		main.draw_line(centre - Vector2(0, 4), centre + Vector2(0, 4), Color(0.4, 1.8, 0.7, pulse), 3)
