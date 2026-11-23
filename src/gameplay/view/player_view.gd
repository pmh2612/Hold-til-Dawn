class_name PlayerView
extends RefCounted

# Part of Main (main.gd); in the C# version this was in Main.cs.
# Owner: Mai Thien Ngon.
var slash_t = {}

# constants shared with Main
const CHAR_H = Main.CHAR_H
const INK = Main.INK
const LIFT = Main.LIFT
const NEON_RED = Main.NEON_RED
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

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
	var gather = main.harvest_view.gather_animation(Vector2(p[23])) if activity == "gather" and attack == null else null
	# Reuse each role's own sprite frames for working, rather than leaving the actor idle.
	if attack == null and activity in ["repair", "loot"]:
		gather = "attack_hammer" if activity == "repair" else "gather_herb"
	var _v1 = (attack[0] if attack != null else null)
	var _v2 = (attack[1] if attack != null else null)
	self.char_(id, skin, foot, aim, 1.0, Color.WHITE, fighting or activity != "idle", activity, _v1 if _v1 != null else gather, _v2 if _v2 != null else 0.0, gather != null)
	self.draw_activity(foot, aim, activity)
	main.tactical_items.draw_tactical_weapon(id, p, Vector2(foot), aim)

# compass octant (0 = right, counting clockwise on screen) to the sheet row
static var OCT_ROW = [0, 4, 1, 5, 2, 6, 3, 7]

func char_(key_, skin, foot, aim, s, mod_, lock = null, activity = null, play = null, play_t: float = 0.0, loop: bool = false) -> void:
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
	var one = null if play == null else c0.get("anims", {}).get(play, null)
	var rows: int = int(tex.get_height() / c0.size)
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
	var c = main.cinfo.chars[skin]
	var size = Vector2(c.size, c.size)
	var anchor = Vector2(c.anchor[0], c.anchor[1])
	main.draw_texture_rect_region(tex, Rect2(foot - anchor * s, size * s), Rect2(Vector2(f, dir) * size, size), mod_)

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
