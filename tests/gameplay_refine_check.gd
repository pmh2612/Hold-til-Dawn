extends Node

var checks: int = 0
var failed: bool = false

# Fix the cursor in world space while exercising the actual Main mouse/input path.
class PlacementMenu extends BuildMenuUi:
	var spot: Vector2
	func _init(host: Main, target: Vector2) -> void:
		super(host)
		spot = target
	func build_spot() -> Vector2:
		return spot

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL: " + label)
		get_tree().quit(1)
		return
	checks += 1
	print("ok   " + label)

func _ready() -> void:
	var s = GameSim.new()
	s.add_player(1, "Engineer", 2)
	s.add_player(2, "Healer", 1)
	s.start_match()
	var p = s.players[1]
	var q = s.players[2]
	SimPhases.dusk(s)
	check(s.towers.all(func(tw): return tw == null) and s.free_tower, "dusk never builds a tower automatically")
	s.phase = "day"
	s.nodes.clear()
	s.enemies.clear()
	s.world.rebuild([], s.towers, [])
	p.pos = s.free_tower_spot(0) + Vector2(0, 80)
	q.pos = GameSim.HALF * -0.5
	var at = s.free_tower_spot(0)
	s.action(1, "build", ["tower", at, false])
	check(s.construction.size() == 1 and s.towers.all(func(tw): return tw == null), "confirming a position starts the six-second channel without an instant tower")
	s.tick_tower_construction(p, 6.1)
	check(s.towers[0] != null and not s.free_tower, "manual construction completes the free tower")
	s.set_count(p, "wood", 20)
	s.set_count(p, "stone", 20)
	for kind in ["wood", "stone"]:
		s.action(1, "build", [kind, p.pos + Vector2(0, 100), false])
	check(s.built_walls.is_empty() and s.count(p, "wood") == 20 and s.count(p, "stone") == 20, "wall building is rejected without spending materials")

	# A nearly expired downed player is inserted first: pausing must not depend on dictionary order.
	p.pos = Vector2(0, -30 * GameSim.T)
	q.pos = p.pos + Vector2(24, 0)
	p.state = 1
	p.bleed = 0.25
	q.inter = true
	for i in range(20):
		s.tick_players(0.1)
	check(p.state == 1 and is_equal_approx(p.bleed, 0.25) and q.revive_p > 0, "reviving pauses even a nearly exhausted bleed timer")
	q.inter = false
	s.tick_players(0.1)
	check(p.bleed < 0.25 and is_zero_approx(q.revive_p), "release resumes bleeding and clears rescue progress")
	q.inter = true
	q.pos += Vector2(300, 0)
	s.tick_players(0.1)
	check(p.bleed < 0.15, "out-of-range helpers cannot freeze bleeding")
	p.bleed = 0.25
	q.pos = p.pos + Vector2(24, 0)
	q.atk = true
	s.tick_players(0.1)
	check(p.bleed < 0.25, "attacking does not count as rescuing")
	q.atk = false
	p.bleed = 0.25
	for i in range(105):
		s.tick_players(0.1)
	check(p.state == 0 and p.hp > 0, "a healer can complete rescue with less than a second of bleed remaining")

	var game = Main.new()
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.snap = s.snapshot()
	game.my_id = 1
	game.local_pos = p.pos
	check(not game.build_menu.build_open, "tower preview starts hidden")
	game.gameplay_hud.gameplay_key(KEY_T)
	check(game.build_menu.build_open and game.build_menu.build_kind == "tower", "T opens tower placement without issuing a build")
	var cancel = InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	game.build_menu.build_mouse(cancel)
	check(not game.build_menu.build_open, "right click cancels placement completely")
	game.snap.ps[1][1] = 1
	game.gameplay_hud.gameplay_key(KEY_T)
	check(not game.build_menu.build_open, "healers cannot open tower placement")
	game.gameplay_hud.gameplay_key(KEY_H)
	check(game.gameplay_hud.help_open and game.inventory.ui_captures_mouse(), "H shows controls and blocks world clicks")
	game.pause_menu.escape_key()
	check(not game.gameplay_hud.help_open and not game.pause_menu.paused, "Esc closes instructions before pausing")
	game.snap.ph = "night"
	check(Main.night_sight_radius(1) == 5 * GameSim.T and Main.night_sight_radius(0) > Main.night_sight_radius(2), "healer / engineer sight grows to five tiles; Scout keeps an advantage")
	check(game.enemy_visible_at(p.pos + Vector2(4.9 * GameSim.T, 0)), "nearby enemies are visible to non-Scouts")
	check(not game.enemy_visible_at(p.pos + Vector2(7.0 * GameSim.T, 0)), "distant enemies remain hidden outside night sight")
	game.snap.ph = "day"
	check(game.enemy_visible_at(p.pos + Vector2(20.0 * GameSim.T, 0)), "daytime enemy visibility is unchanged")

	# Regression: closing placement while the confirming LMB is held used to attack and cancel it.
	s.towers = [null, null, null]
	s.free_tower = true
	s.world.rebuild([], s.towers, [])
	at = s.free_tower_spot(0)
	p.pos = at + Vector2(0, 80)
	p.role = 2
	p.state = 0
	p.inter = false
	p.atk = true
	q.inter = false
	q.pos = Vector2.ZERO
	game.sim = s
	game.geometry = s.world
	game.snap = s.snapshot()
	game.local_pos = p.pos
	game.local_tp = p.tp
	game.pending_inputs.clear()
	# This harness never advances UI frames; hide its initially visible menu/overlay scenes.
	game.front.visible = false
	game.menu_panel.visible = false
	game.lobby_panel.visible = false
	game.hud.visible = false
	game.build_menu = PlacementMenu.new(game, at)
	game.gameplay_hud.gameplay_key(KEY_T)
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._unhandled_input(click)
	check(not game.build_menu.build_open and s.construction.size() == 1 and not p.atk, "placement click starts construction and clears stale attack input")
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "test holds the actual left mouse state")
	for i in range(121):
		game.move(0.05)
		s.tick_players(0.05)
	check(s.towers[0] != null and s.construction.is_empty() and not p.atk, "holding the confirming mouse click for six seconds does not cancel the tower")
	click.pressed = false
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	game.move(0.05)
	click.pressed = true
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	game.move(0.05)
	check(p.atk, "releasing then clicking again restores normal combat")
	click.pressed = false
	Input.parse_input_event(click.duplicate())
	game.queue_free()
	await get_tree().process_frame
	print(("GAMEPLAY REFINE FAILED" if failed else "GAMEPLAY REFINE ALL OK") + ": %d checks" % checks)
	get_tree().quit(1 if failed else 0)
