class_name SurvivalFeedbackUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/gameplay/Main.SurvivalFeedback.cs.

# constants shared with Main
const GOLD = Main.GOLD

var main: Main

func _init(host: Main) -> void:
	main = host

static func low_health_strength(hp: float, max_hp: float) -> float:
	return clampf((0.6 - hp / maxf(1, max_hp)) / 0.6, 0, 1)

func draw_low_health(c, size: Vector2) -> void:
	var me = main.snap.get("ps", {}).get(main.my_id)
	if me == null or int(me[5]) == 2 or main.snap.get("ph", "") == "result":
		return
	var strength: float = low_health_strength(float(me[3]), float(me[4]))
	if int(me[5]) == 1:
		strength = 1
	if strength <= 0:
		return
	# Six nested bands, constant cost. Steady warning with a slow heartbeat only below 25% HP.
	var beat: float = 0.88 + 0.12 * sin(float(main.clock) * 5) if float(me[3]) < float(me[4]) * 0.25 else 1
	for i in range(5, -1, -1):
		var inset: float = i * (2 + 4 * strength)
		var box_ = Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2)
		c.draw_rect(box_, Color(0.83, 0.035, 0.025, strength * beat * (0.12 + 0.07 * (5 - i))), false, 3 + strength * 3)

func craft_have_local(me, id) -> int:
	var kind: int = GameSim.COMPONENT_IDS.find(id)
	var rescue = main.snap.get("rescue", null)
	return (0 if rescue == null else int(rescue[0][kind])) if kind >= 0 else InventoryUi.carried(me, id)

func draw_construction_ground() -> void:
	for tw in main.snap.get("tw", []):
		draw_dirt_foundation(Vector2(tw[1]), 1)
	for job in main.snap.get("construction", []):
		var at: Vector2 = Vector2(job[0])
		var progress: float = float(job[1])
		draw_dirt_foundation(at, progress)
		main.draw_rect(Rect2(at + Vector2(-24, -38), Vector2(48, 5)), Color("202526"))
		main.draw_rect(Rect2(at + Vector2(-24, -38), Vector2(48 * progress, 5)), Color("E6B257"))
		main.draw_arc(at, 22, 0, TAU * progress, 24, Color("E6B257"), 2)

func draw_dirt_foundation(at: Vector2, progress: float) -> void:
	main.draw_set_transform(at, 0, Vector2(1, 0.65))
	main.draw_circle(Vector2.ZERO, 33, Color("594731"))
	main.draw_circle(Vector2.ZERO, 29, Color("927448"))
	for i in range(12):
		var q: Vector2 = Vector2.from_angle(i * 2.4) * (10 + i % 4 * 4)
		main.draw_rect(Rect2(q.round(), Vector2(4, 2)), Color("AF8E58" if i % 2 == 0 else "755638"))
	main.draw_set_transform(Vector2.ZERO)
