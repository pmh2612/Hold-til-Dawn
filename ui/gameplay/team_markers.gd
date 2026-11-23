class_name TeamMarkersUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.TeamMarkers.cs.
# Owner: Mai Thien Ngon. Where your teammates and tonight's supplies are. A teammate on screen gets a marker in
# their role colour over the head; one off screen (or out of sight inside the base) is pinned to the screen edge
# with their name, pointing their way. A dead teammate's marker shows a cross, so you can bring a Revival kit.
# Expedition chest markers stay on the map; their hidden radio parts have no edge pointers.
# in HUD units (the HUD is drawn at 960 x 540 and scaled to the window)
const EDGE_PAD: float = 24.0

# constants shared with Main
const CHAR_H = Main.CHAR_H
const NEON_RED = Main.NEON_RED

var main: Main

func _init(host: Main) -> void:
	main = host

func draw_team_markers(c, ct: Transform2D, vs: Vector2) -> void:
	var screen = Rect2(Vector2.ZERO, vs)
	# inside the HUD: below the generator and night bars, above the hotbar
	var night: bool = main.snap.get("ph", "") == "night"
	var top: float = 66 + EnemyView.NIGHT_BAR_H if night else 66
	var edge = Rect2(EDGE_PAD, top, vs.x - 2 * EDGE_PAD, vs.y - top - 84)
	var mid: Vector2 = vs / 2
	var bob: float = 2.0 * sin(float(main.clock) * 4.0)
	var cw = c
	placed.clear()
	for id in main.snap.ps:
		if id == main.my_id:
			continue
		var p = main.snap.ps[id]
		var state: int = int(p[5])
		var col: Color = Main.ROLE_COL[p[1]]
		var foot: Vector2 = Vector2(main.shown_p.get(id, p[2]))
		var head: Vector2 = ct * (foot - Vector2(0, float(CHAR_H) + 16 if state == 0 else 18))
		var hidden: bool = main.base_fog_view.hidden_in_base(foot)
		if Cs.has_point(screen.grow(-8), head) and not hidden:
			# on screen: a small chevron over the name
			var tip: Vector2 = head + Vector2(0, 2 + bob)
			var chev = [tip, tip + Vector2(-6, -7), tip + Vector2(6, -7)]
			c.draw_colored_polygon(chev, col)
			c.draw_polyline([chev[0], chev[1], chev[2], chev[0]], Color(0.08, 0.07, 0.1), 1.5)
			if state == 2:
				self.dead_cross(c, head + Vector2(0, -16))
			continue
		# off screen: pinned to the edge, pointing at them
		var dir: Vector2 = (head - mid).normalized()
		var at: Vector2 = head if hidden and screen.has_point(head) else spread(edge_point(mid, dir, edge), edge)
		var fill = col if state == 0 else col.darkened(0.45)
		c.draw_circle(at, 11, Color(0.08, 0.07, 0.1, 0.85))
		c.draw_arc(at, 11, 0, TAU, 20, fill, 2.0)
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var nose: Vector2 = at + dir * 17
		c.draw_colored_polygon([nose, at + dir * 10 + side * 6, at + dir * 10 - side * 6], fill)
		if state == 2:
			self.dead_cross(c, at)
		else:
			c.draw_circle(at, 5, fill)
		var name = Cs.s(p[0])
		var lp: Vector2 = at + Vector2(-50, 25)
		main.text(cw, lp, name, 10, fill.lightened(0.25), 1, 100)

# markers already placed this frame, so two never sit on top of each other
var placed = []

# slides an edge marker along its edge until it is clear of the others
func spread(at: Vector2, edge: Rect2) -> Vector2:
	var upright: bool = absf(at.x - edge.position.x) < 1.0 or absf(at.x - edge.end.x) < 1.0
	var along: Vector2 = Vector2.DOWN if upright else Vector2.RIGHT
	for tries in range(12):
		var clear: bool = true
		for p in placed:
			if p.distance_to(at) < 30.0:
				clear = false
				break
		if clear:
			break
		at = (at - along * 30.0).clamp(edge.position, edge.end)
		if tries == 5:
			along = -along
	placed.append(at)
	return at

# where the ray from Mid along Dir leaves the rectangle R
static func edge_point(mid: Vector2, dir: Vector2, r: Rect2) -> Vector2:
	var tx: float = ((r.end.x if dir.x > 0 else r.position.x) - mid.x) / dir.x if absf(dir.x) > 0.0001 else 3.4028235e38
	var ty: float = ((r.end.y if dir.y > 0 else r.position.y) - mid.y) / dir.y if absf(dir.y) > 0.0001 else 3.4028235e38
	return mid + dir * minf(tx, ty)

func dead_cross(c, at: Vector2) -> void:
	var red = NEON_RED
	c.draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), red, 2.5)
	c.draw_line(at + Vector2(4, -4), at + Vector2(-4, 4), red, 2.5)
