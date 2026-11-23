class_name BaseArrowView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.BaseArrow.cs.
# Owner: Vu Duc Viet Anh. Outside the base a small arrow circles your character and always points at the base
# (its centre, the lighthouse), so you never lose your way home.
# how far from the character's centre the arrow sits, in screen pixels
const BASE_ARROW_R: float = 62.0
const BASE_ARROW_COL: Color = Color(1.0, 0.78, 0.32)

# constants shared with Main
const INK = Main.INK
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

func draw_base_arrow(c, ct: Transform2D) -> void:
	var me = main.snap.ps.get(main.my_id)
	if me == null or int(me[5]) == 2 or SimWorld.inside_base(main.local_pos):
		return
	var to: Vector2 = -main.local_pos
	var dist: float = to.length()
	if dist < 1.0:
		return
	var dir: Vector2 = to / dist
	# the character's middle on screen (the feet are at LocalPos)
	var mid: Vector2 = ct * (main.local_pos + Vector2(0, -14))
	# fade in as you walk away from the walls, so it does not sit on top of the base right outside a door
	var near: float = clampf((dist - Vector2(GameSim.HALF).length()) / (4.0 * T), 0.35, 1.0)
	var tip: Vector2 = mid + dir * (BASE_ARROW_R + 9.0)
	var back: Vector2 = mid + dir * (BASE_ARROW_R - 7.0)
	var side: Vector2 = Vector2(-dir.y, dir.x)
	# a gentle pulse along its direction
	var bob: float = 2.5 * sin(float(main.clock) * 4.0)
	tip += dir * bob
	back += dir * bob
	var head = [tip, back + side * 9.0, back + dir * 4.0, back - side * 9.0]
	var rim = Cs.arr(head.size() + 1, Vector2.ZERO)
	Cs.copy_to(head, rim, 0)
	rim[head.size()] = head[0]
	var col = BASE_ARROW_COL
	col.a = near
	var ink = INK
	ink.a = 0.85 * near
	c.draw_colored_polygon(head, col)
	c.draw_polyline(rim, ink, 2.0)
