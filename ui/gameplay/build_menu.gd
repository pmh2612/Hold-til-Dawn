class_name BuildMenuUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.BuildMenu.cs.
# Owner: Pham Minh Hieu. T toggles tower placement. Left click confirms; RMB / Esc cancels.
var build_open = false
var build_kind = ""
var build_vert = false
# A placement click stays consumed until release, even after the preview closes.
var placement_click_held: bool = false
# [kind, label, cost text, unlock tier]
static var BUILD_OPTIONS = [["tower", "Tower | 300 HP | 6s", "10 wood + 5 titanium", 2]]

# constants shared with Main
const GOLD = Main.GOLD
const LIFT = Main.LIFT
const NEON_RED = Main.NEON_RED
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

func close_build() -> void:
	build_open = false
	build_kind = ""

func toggle_build() -> void:
	var me = main.snap.ps.get(main.my_id)
	if me == null or me[1] != 2 or me[5] != 0 or me[19]:
		self.note("Engineer only")
		return
	if build_open:
		self.close_build()
		return
	build_open = true
	build_kind = "tower"
	main.minimap.map_big = false
	main.inventory.bag_open = false
	main.craft_open = false

# A short local message in the hint line (no server round trip).
func note(s) -> void:
	local_note = s
	local_note_t = 2.5

var local_note = ""
var local_note_t = 0.0

func build_key(code) -> bool:
	if not build_open:
		return false
	var n: int = int(code - 49)
	if n >= 0 and n < BUILD_OPTIONS.size():
		build_kind = BUILD_OPTIONS[n][0]
		return true
	return false

func build_spot() -> Vector2:
	return main.get_global_mouse_position()

func filter_primary_attack(pressed: bool) -> bool:
	if not pressed:
		placement_click_held = false
	return pressed and not placement_click_held

# Why the selected structure cannot be placed at the cursor, or "" (the server checks again).
func build_problem(me) -> Variant:
	var spot: Vector2 = self.build_spot()
	if spot.distance_to(main.local_pos) > GameSim.BUILD_REACH * T:
		return "Too far away"
	var why = SimTowers.tower_spot_problem(spot, main.geometry)
	if why != "":
		return why
	if main.snap.get("tw", []).size() + main.snap.get("construction", []).size() >= GameSim.MAX_TOWERS:
		return "Tower limit"
	for q in main.snap.ps.values():
		if Vector2(q[2]).distance_to(spot) < 1.1 * T:
			return "Spot occupied"
	if main.snap.get("free_tower", false):
		return ""
	var tier: int = 2
	var cost = GameSim.TOWER_COST
	if tier > main.snap.get("unlock", 0):
		return "Clear night 1" if tier == 1 else "Defeat first boss"
	for res in cost:
		if InventoryUi.carried(me, res) < cost[res]:
			return "Need %d %s" % [cost[res], res]
	return ""

# World space: the green or red ghost of the structure under the cursor.
func draw_build_preview() -> void:
	var me = main.snap.get("ps", {}).get(main.my_id)
	if not build_open or build_kind == "" or me == null:
		return
	var spot: Vector2 = self.build_spot()
	var ok: bool = self.build_problem(me) == ""
	var col: Color = Color(0.3, 1.0, 0.45, 0.45) if ok else Color(1.0, 0.25, 0.25, 0.45)
	if build_kind == "tower":
		main.draw_prop("tower", spot, col)
		main.draw_circle(spot, 0.7 * T, col)
		main.draw_arc(spot, GameSim.TOWER_RANGE, 0, TAU, 64, col, 1.5)
		return
	var half: Vector2 = Vector2(0.5 * T, 1.5 * T) if build_vert else Vector2(1.5 * T, 0.5 * T)
	main.draw_rect(Rect2(spot - half, half * 2), col)

func draw_build_menu(c, vs, me) -> void:
	if not build_open:
		return
	var box_: Rect2 = Rect2(vs.x - 330, 126, 320, 112)
	main.panel(c, box_)
	main.text(c, box_.position + Vector2(10, 16), "TOWER | T: cancel", 10, GOLD, 0, -1.0, true)
	var unlock: int = main.snap.get("unlock", 0)
	for i in range(BUILD_OPTIONS.size()):
		var o = BUILD_OPTIONS[i]
		var locked: bool = o[3] > unlock
		var cost = o[2]
		if o[0] == "tower" and main.snap.get("free_tower", false):
			locked = false
			cost = "free"
		var picked: bool = o[0] == build_kind
		var col: Color = Color(1, 1, 1, 0.35) if locked else GOLD if picked else Color.WHITE
		main.text(c, box_.position + Vector2(10, 38 + i * 18), "%d  %s - %s%s" % [i + 1, o[1], cost, "  LOCKED" if locked else ""], 11, col)
	if build_kind != "":
		var why = self.build_problem(me)
		main.text(c, box_.position + Vector2(10, 100), "LMB: place" if why == "" else why, 11, Color(0.4, 1.0, 0.5) if why == "" else NEON_RED)

# A built wall: [pos, vertical, hp, maxhp, kind] drawn as a raised block with an HP bar once damaged.
func draw_built_wall(w) -> void:
	var pos: Vector2 = Vector2(w[0])
	var half: Vector2 = Vector2(0.5 * T, 1.5 * T) if w[1] else Vector2(1.5 * T, 0.5 * T)
	# art/props/wall_<kind>_<h|v>.png from tools/PixelProps.cs
	main.draw_prop("wall_%s_%s" % [w[4], "v" if w[1] else "h"], pos)
	if w[2] < w[3]:
		main.bar(pos - Vector2(0, half.y + 22), half.x * 1.6, w[2] / w[3], GOLD)

func build_mouse(ev) -> bool:
	if ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		placement_click_held = false
	if not build_open or build_kind == "":
		return false
	if ev.button_index == 2 and ev.pressed:
		close_build()
		return true
	if ev.button_index == 1 and ev.pressed:
		placement_click_held = true
		var me = main.snap.ps.get(main.my_id)
		var why = build_problem(me)
		if why == "":
			main.act("build", ["tower", self.build_spot(), false])
			close_build()
		else:
			note(why)
	return ev.button_index == 1
