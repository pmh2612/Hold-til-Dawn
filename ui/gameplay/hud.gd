class_name HudUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was in Main.cs.
# Owner: Mai Thien Ngon. The in-game HUD is the scene ui/gameplay/hud.tscn: one HudLayer node per layer, drawn in
# the scene's order (bottom to top), plus the pause and result screens, which are ordinary Control scenes
# (ui/menu/pause_screen.tscn, ui/menu/result_screen.tscn). This file says what each layer draws.

# constants shared with Main
const GOLD = Main.GOLD
const INK = Main.INK
const NEON_RED = Main.NEON_RED
const T = Main.T

var main: Main

func _init(host: Main) -> void:
	main = host

# Hands Main to the layers and screens of the HUD scene (Main.hud).
func setup(hud: Control) -> void:
	for child in hud.get_children():
		if child is HudLayer:
			child.main = main
	hud.get_node("PauseScreen").setup(main)
	hud.get_node("ResultScreen").setup(main)

func draw_layer(c: Control, layer: String) -> void:
	var ph = main.snap.get("ph", "")
	if not ph in ["day", "dusk", "night", "result"]:
		return
	var vs = c.size
	var me = main.snap.ps.get(main.my_id)
	# Crafting keeps the phase clock above the panel and hides the other HUD widgets.
	var crafting: bool = main.craft_open and me != null and ph != "result"
	match layer:
		"overlay":
			# any open panel takes over from the large map (the layers above read map_big)
			if crafting or main.inventory.bag_open or main.craft_open or main.build_menu.build_open:
				main.minimap.map_big = false
			self.draw_overlay(c, ph)
		"craft":
			# (ui/gameplay/craft_panel.gd)
			if crafting:
				main.craft_panel.draw_craft_panel(c, vs)
		"hurt":
			if crafting or me != null:
				self.draw_hurt_flash(c, vs)
		_:
			if crafting:
				if layer == "status":
					main.panel(c, Rect2(vs.x - 244, 6, 238, 42))
					draw_phase_clock(c, vs, ph)
				return
			if layer == "status":
				self.draw_status(c, vs, me, ph)
			elif me == null:
				return
			elif layer == "minimap":
				# top left: minimap (M shows it large)
				main.minimap.draw_minimap(c, vs, me)
			elif layer == "markers":
				# teammates and supplies, pinned to the screen edge when out of view, over the side panels
				# (ui/gameplay/team_markers.gd)
				if not main.minimap.map_big and ph != "result":
					main.team_markers.draw_team_markers(c, main.get_viewport().get_canvas_transform(), Vector2(vs))
			elif layer == "hotbar":
				# the large map covers the hotbar and the hints
				if not main.minimap.map_big:
					main.inventory.draw_hotbar(c, vs, me)
					main.gameplay_hud.draw_interaction_hint(c, vs, me, ph)
					if ph != "result":
						main.gameplay_hud.draw_controls(c, Vector2(vs), me)
			elif layer == "build":
				main.build_menu.draw_build_menu(c, vs, me)
			elif layer == "bag":
				main.inventory.draw_bag(c, vs, me)

# The arrow home and the damage numbers, under every panel.
func draw_overlay(c, ph) -> void:
	var ct = main.get_viewport().get_canvas_transform()
	# (src/world/view/base_arrow.gd)
	if ph != "result":
		main.base_arrow.draw_base_arrow(c, ct)
	for p in main.popups:
		# nothing pops up from inside the base while you are outside (src/world/view/base_fog.gd)
		if main.base_fog_view.hidden_in_base(Vector2(p.pos)):
			continue
		var k: float = float(p.life / 0.8)
		var sp: Vector2 = ct * p.pos + Vector2(0, -36 * (1.0 - k))
		var size = int(p.size * (1.0 + 0.5 * clampf((k - 0.8) * 5.0, 0, 1)))
		var col: Color = p.col
		col.a = clampf(k * 2.0, 0, 1)
		main.text(c, sp - Vector2(30, 0), p.text, size, col, 1, 60)

func draw_phase_clock(c, vs, ph) -> void:
	var tl = "%d:%02d" % [int(maxf(main.snap.t, 0)) / 60, int(maxf(main.snap.t, 0)) % 60]
	var phase_line = {"day": "DAY %d/5" % [main.snap.k], "dusk": "DUSK", "night": "NIGHT %d/5" % [main.snap.k], "result": "RESULT"}[ph]
	main.text(c, Vector2(0, 24), "%s   %s" % [phase_line, tl], 16, Color.WHITE, 2, vs.x - 12, true)
	if ph == "day":
		var vote_hint = "skip %d/%d (V)" % [main.snap.votes, main.snap.need]
		main.text(c, Vector2(0, 40), vote_hint, 11, Color(1, 1, 1, 0.6), 2, vs.x - 12)
	if main.snap.ext >= 0:
		main.text(c, Vector2(0, 40), "EXTENSION %ds" % [main.snap.ext], 12, NEON_RED, 2, vs.x - 12)

# Timer, radio checklist, generator and doors, enemy bars, the team list and your own health.
func draw_status(c, vs, me, ph) -> void:
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	draw_phase_clock(c, vs, ph)
	# Locator radio checklist and assembly progress (day and night).
	if ph != "result" and not main.minimap.map_big:
		main.supplies.draw_supply_row(c, float(vs.x) - 12, 50.0 if main.snap.ext >= 0 else 34.0)
	# top centre: generator + doors (under the large map, which takes the middle of the screen)
	var cx = vs.x / 2
	if not main.minimap.map_big:
		main.panel(c, Rect2(cx - 160, 6, 320, 46))
		# the generator and the doors in red, so their health reads at a glance
		var gcol = Color("E0362C").lerp(Color(2.5, 0.6, 0.5), main.gen_flash / 0.4)
		main.text(c, Vector2(cx - 150, 21), "GENERATOR", 11, GOLD, 0, -1.0, true)
		main.text(c, Vector2(cx + 60, 21), "%d / 1000" % [main.snap.base], 11, Color.WHITE, 2, 90, true)
		c.draw_rect(Rect2(cx - 150, 25, 300, 7), INK)
		c.draw_rect(Rect2(cx - 150, 25, 300 * main.snap.base / 1000.0, 7), gcol)
		for i in 3:
			var r = Rect2(cx - 150 + i * 102, 36, 96, 12)
			var dur: float = float(main.snap.doors[i])
			var col = Color("E0362C")
			c.draw_rect(r, INK)
			c.draw_rect(Rect2(r.position + Vector2(14, 3), Vector2(68 * dur / 500.0, 6)), col)
			# tower icon: lit = a standing tower covers this door (within 12 tiles of it; HUD 3)
			var door_at: Vector2 = Vector2(GameSim.DOOR_POS[i])
			var tws = main.snap.get("tw", []).filter(func(tw): return tw[2] > 0 and Vector2(tw[1]).distance_to(door_at) < 12.0 * T)
			var tcol = Color("F2B544") if not tws.is_empty() else Color(0.4, 0.42, 0.48)
			c.draw_rect(Rect2(r.position + Vector2(87, 4), Vector2(2, 7)), tcol)
			c.draw_rect(Rect2(r.position + Vector2(85, 2), Vector2(6, 3)), tcol)
			main.text(c, r.position + Vector2(2, 11), GameSim.DOOR_NAMES[i], 11, Color.WHITE)
			if i in main.snap.active:
				c.draw_rect(r.grow(1), NEON_RED * (0.6 + 0.6 * pulse if main.door_flash[i] > 0 else 0.7), false, 1.5)
	# night enemies bar and boss bar (AI view); the large map takes the middle of the screen
	if not main.minimap.map_big:
		main.enemy_view.draw_night_bar(c, float(cx))
		main.enemy_view.draw_boss_bar(c, cx)
	# left: team list, under the minimap (top left, ui/gameplay/minimap.gd)
	var y = 160.0
	for id in main.snap.ps:
		var p = main.snap.ps[id]
		var col: Color = Main.ROLE_COL[p[1]]
		main.panel(c, Rect2(8, y - 16, 150, 32))
		c.draw_circle(Vector2(24, y), 12, INK)
		c.draw_circle(Vector2(24, y), 10, col if p[5] == 0 else col.darkened(0.6))
		main.text(c, Vector2(40, y - 3), Cs.s(p[0]) + (" (you)" if id == main.my_id else ""), 11, Color.WHITE)
		if p[5] == 0:
			c.draw_rect(Rect2(40, y + 3, 110, 5), INK)
			c.draw_rect(Rect2(40, y + 3, 110 * p[3] / p[4], 5), Color("3DBE5A"))
		else:
			main.text(c, Vector2(40, y + 11), "DOWN %ds" % [p[6]] if p[5] == 1 else "DEAD", 10, NEON_RED)
		y += 38
	if me == null:
		return
	# bottom left: HP hexagon + small hexes
	var hp_c = Vector2(48, vs.y - 50)
	main.hex(c, hp_c, 38, GOLD)
	main.hex(c, hp_c, 34, INK)
	main.hex(c, hp_c, 31, Color("B3262A").lerp(Color(2.5, 0.4, 0.3), main.hurt / 0.35))
	main.text(c, hp_c + Vector2(-40, 8), Cs.s(int(me[3])), 22, Color.WHITE, 1, 80, true)
	main.text(c, hp_c + Vector2(-40, 24), "/%d" % [me[4]], 10, Color(1, 1, 1, 0.7), 1, 80)
	# beside it: the armour worn (no bag slot), then the bandages and healing flasks carried
	main.inventory.draw_stat_slots(c, Vector2(vs), me)
	main.text(c, Vector2(92, vs.y - 46), GameSim.ROLES[me[1]].to_upper(), 12, Main.ROLE_COL[me[1]], 0, -1.0, true)
	if me[5] != 0:
		main.text(c, Vector2(0, vs.y / 2 + 40), "DOWN  %ds" % [me[6]] if me[5] == 1 else "DEAD", 18, NEON_RED, 1, vs.x, true)

# red screen edges after a hit
func draw_hurt_flash(c, vs) -> void:
	main.survival_feedback.draw_low_health(c, Vector2(vs))
	if main.hurt > 0:
		var a_ = main.hurt / 0.35 * 0.5
		for r in [Rect2(0, 0, vs.x, 14), Rect2(0, vs.y - 14, vs.x, 14), Rect2(0, 0, 14, vs.y), Rect2(vs.x - 14, 0, 14, vs.y)]:
			c.draw_rect(r, Color(0.9, 0.05, 0.05, a_))
