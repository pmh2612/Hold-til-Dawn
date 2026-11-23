class_name NodeBreakView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.NodeBreak.cs.
static var NODE_SPR = ["node_wood", "node_stone", "node_herb", "node_titanium"]
static var NODE_EMPTY = ["stump", "rubble", "herb_cut", "ore_left"]
# Owner: Vu Duc Viet Anh. A resource node breaks bit by bit as it is gathered instead of shrinking: each unit taken
# (5 to a node) swaps in the next broken stage of its sprite (art/nature/<node>_dmg<k>_<variant>.png, drawn by
# tools/PixelHarvestDamage.cs: trunk notches, rock fractures, cut stems), the node jolts, and a burst of chips in
# its colours flies off (wood chips, stone shards, leaves, blue crystal). Each tool contact triggers a short
# highlight and a rigid jolt; five small slots show resource/progress on the worked node only.
# Once empty it shows its remains (stump, rubble, ...) until dawn.
const NODE_FULL: int = 5
const NODE_STAGES: int = 4
var chips = []
var chip_clock: float = 0.0
# what each node held last frame, when it last lost a unit, when it last threw a chip while worked
var node_seen = {}
var node_hit_at = {}
var worked_nodes = {}
var harvest_strikes = {}
var visible_node_amounts = {}
var worked_sprites = {}
# chip colours per node type: wood, stone, herb, titanium
static var CHIP_COLS = [[Color("E0B070"), Color("C08A50"), Color("7A5634"), Color("3A6B45")], [Color("D5DAE1"), Color("A3A8B0"), Color("7D838C")], [Color("9BE37A"), Color("4FB862"), Color("2E7D3E")], [Color("D2E6FF"), Color("7FB0FF"), Color("4A72E6"), Color("A98CFF"), Color("3D415C")]]
# how high above its foot a node is broken into
static var CHIP_FROM = [8.0, 12.0, 6.0, 14.0]

var main: Main

func _init(host: Main) -> void:
	main = host

# the sprite for a node as it stands now; also notices a unit taken since the last frame
func node_sprite(nd, hsh: int) -> Variant:
	var type: int = int(nd[0])
	var pos: Vector2 = Vector2(nd[1])
	var amount: int = int(nd[2])
	var was = node_seen.get(pos, 0)
	if node_seen.has(pos) and amount < was:
		self.burst_chips(type, pos, 18 if amount <= 0 else 10, 1.0)
		node_hit_at[pos] = float(main.clock)
	node_seen[pos] = amount
	visible_node_amounts[pos] = amount
	var custom = Cs.s(nd[3]) if nd.size() > 3 else ""
	if custom.length() > 0:
		var sprite_ = Harvestables.stage_sprite(custom, 5) if amount <= 0 else Harvestables.stage_sprite(custom, NODE_FULL - amount) if amount < NODE_FULL else custom
		if main.spr.has(sprite_):
			return remember_worked_sprite(pos, sprite_)
	if amount <= 0:
		return remember_worked_sprite(pos, Cs.s(main.var_(NODE_EMPTY[type], hsh)))
	var name = Cs.s(NODE_SPR[type])
	var stage: int = clampi(NODE_FULL - amount, 0, NODE_STAGES)
	if stage > 0:
		var broken = name + "_dmg" + str(stage)
		if main.nvar.get(broken, 0) > 0:
			name = broken
	return remember_worked_sprite(pos, Cs.s(main.var_(name, hsh)))

func remember_worked_sprite(pos: Vector2, name) -> Variant:
	if worked_nodes.has(pos):
		worked_sprites[pos] = name
	return name

# Once per frame, time impacts to the contact frame of each character's harvesting animation.
func prepare_harvest_feedback() -> void:
	worked_nodes.clear()
	visible_node_amounts.clear()
	worked_sprites.clear()
	for id in main.snap.ps:
		var p = main.snap.ps[id]
		if Cs.s(p[22]) != "gather":
			continue
		var pos: Vector2 = Vector2(p[23])
		worked_nodes[pos] = maxf(worked_nodes.get(pos, 0.0), float(p[21]))
		var timing = main.anim_state.get(id)
		if timing == null or not Cs.s(timing[0]).begins_with("gather_"):
			continue
		var start: float = float(timing[1])
		var time: float = maxf(0, float(main.clock) - start)
		var skin = Cs.s(Main.ROLE_SKIN[p[1]])
		var anim = main.cinfo.chars[skin].anims[timing[0]]
		var count: int = int(anim[1])
		var frame_: int = int(time * float(anim[2]))
		var cycle: int = frame_ / count
		if frame_ % count < 3:
			continue
		var key_ = Cs.s(id)
		var last = harvest_strikes.get(key_, null)
		if harvest_strikes.has(key_) and last[0] == pos and last[1] == start and last[2] == cycle:
			continue
		harvest_strikes[key_] = [pos, start, cycle]
		var type = main.harvest_view.harvest_types.get(pos, 0)
		if not main.harvest_view.harvest_types.has(pos):
			continue
		node_hit_at[pos] = float(main.clock)
		burst_chips(type, pos, 6 if type == 2 else 8, 0.65)

func node_scale(nd) -> float:
	return 1.0

func node_modulate(nd) -> Color:
	var pos: Vector2 = Vector2(nd[1])
	var age: float = float(main.clock) - node_hit_at.get(pos, -9)
	var light: float = 1 + 0.38 * clampf(1 - age / 0.13, 0, 1)
	return Color(light, light, light, 1)

func node_offset(nd) -> Vector2:
	var pos: Vector2 = Vector2(nd[1])
	var at = node_hit_at.get(pos, 0.0)
	if node_hit_at.has(pos) and float(main.clock) - at < 0.2:
		return Vector2(sin((float(main.clock) - at) * 65) * 2 * (1 - (float(main.clock) - at) / 0.2), 0).round()
	return Vector2.ZERO

func draw_harvest_feedback() -> void:
	for pos in worked_nodes:
		var progress = worked_nodes[pos]
		var amount = visible_node_amounts.get(pos, 0)
		if not visible_node_amounts.has(pos) or amount <= 0 or main.base_fog_view.hidden_in_base(pos):
			continue
		# Five small slots show units left; the next slot empties while E is held.
		var sprite_ = worked_sprites.get(pos, null)
		if not worked_sprites.has(pos):
			continue
		var bounds_: Rect2 = Rect2(main.sprite_rect(sprite_, pos, 1.0))
		var at: Vector2 = Vector2(pos.x - 16, bounds_.position.y - 10).round()
		main.draw_rect(Rect2(at - Vector2.ONE * 2, Vector2(36, 8)), Color("141019"))
		var col: Color = CHIP_COLS[main.harvest_view.harvest_types.get(pos, 0)][0]
		for i in range(NODE_FULL):
			var slot: Vector2 = at + Vector2(i * 7, 0)
			main.draw_rect(Rect2(slot, Vector2(5, 4)), Color("41464B"))
			var fill: float = 1 if i < amount - 1 else 1 - clampf(progress, 0, 1) if i == amount - 1 else 0
			if fill > 0:
				main.draw_rect(Rect2(slot, Vector2(maxf(1, ceilf(5 * fill)), 4)), col)

func burst_chips(type: int, foot: Vector2, n: int, power: float) -> void:
	var cols = CHIP_COLS[clampi(type, 0, CHIP_COLS.size() - 1)]
	var up: float = CHIP_FROM[clampi(type, 0, CHIP_FROM.size() - 1)]
	for i in range(n):
		var ang: float = lerpf(-PI * 0.95, -PI * 0.05, randf())
		var speed: float = lerpf(50.0, 120.0, randf()) * power
		chips.append(Cs.init(Chip.new(), {"pos": foot + Vector2(lerpf(-8.0, 8.0, randf()), -up * lerpf(0.6, 1.2, randf())), "vel": Vector2.from_angle(ang) * speed, "floor_": foot.y + lerpf(-4.0, 8.0, randf()), "age": 0.0, "life": lerpf(0.6, 1.1, randf()), "size": 3 if randf() < 0.3 else 2, "col": cols[int(randi() % cols.size())]}))

# call after the depth-sorted world items
func draw_chips() -> void:
	var now: float = float(main.clock)
	var dt: float = clampf(now - chip_clock, 0.0, 0.1)
	chip_clock = now
	for i in range(chips.size() - 1, -1, -1):
		var c = chips[i]
		c.age += dt
		if c.age >= c.life:
			chips.remove_at(i)
			continue
		if c.pos.y < c.floor_ or c.vel.y < 0:
			c.vel.y += 420.0 * dt
			c.pos += c.vel * dt
		if c.pos.y >= c.floor_ and c.vel.y > 0:
			# a small bounce, then it lies still
			c.pos.y = c.floor_
			c.vel = Vector2(c.vel.x * 0.4, -c.vel.y * 0.3) if absf(c.vel.y) > 60.0 else Vector2.ZERO
		chips[i] = c
		var a_: float = clampf((c.life - c.age) / 0.25, 0.0, 1.0)
		var col = c.col
		col.a = a_
		main.draw_rect(Rect2(c.pos.round(), Vector2(c.size, c.size)), col)

class Chip:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var floor_: float = 0.0
	var age: float = 0.0
	var life: float = 0.0
	var size: float = 0.0
	var col: Color = Color(0, 0, 0, 0)
