class_name TacticalCraftPreview
extends Main
# Real craft panel and world effects at the normal logical viewport size.
var stage: int = 0
var warm_frames: int = 0
var capturing: bool = false
var finished: bool = false
var selected = [15, 2, 6]

func _ready() -> void:
	# try (GDScript has no exceptions; the body runs unguarded)
	super._ready()
	for child in get_children():
		var item = child
		if child is CanvasItem:
			item.visible = false
		var layer = child
		if child is CanvasLayer:
			layer.visible = false
	cam.enabled = false
	material = Cs.init(CanvasItemMaterial.new(), {"light_mode": CanvasItemMaterial.LIGHT_MODE_UNSHADED})
	tint.color = Color.WHITE
	var review_hud = hud
	var ui_root = review_hud.get_parent()
	for child in ui_root.get_children():
		var item = child
		if child is CanvasItem:
			item.visible = child == review_hud
	ui_root.visible = true
	review_hud.visible = true
	ui_root.get_parent().visible = true
	sim = GameSim.new()
	sim.add_player(1, "Crafter", 2)
	sim.start_match()
	sim.unlock = 2
	var p = sim.players[1]
	p.pos = GameSim.WORKBENCH_POS + Vector2(0, 24)
	for id in ["wood", "stone", "herb", "titanium"]:
		sim.set_count(p, id, 30)
	my_id = 1
	local_pos = p.pos
	snap = sim.snapshot()
	craft_open = true
	for t in range(3):
		craft_panel.select_craft_tier(t)
		var cards = craft_panel.craft_choices()
		for i in cards:
			var a: Rect2 = craft_panel.craft_card(Vector2(960, 540), i)
			if a.end.x > craft_detail_right_edge():
				Cs.fail("Card exceeds recipe column")
				return
			for j in cards:
				if i != j and a.intersects(craft_panel.craft_card(Vector2(960, 540), j)):
					Cs.fail("Overlapping recipe cards")
					return
	DirAccess.make_dir_recursive_absolute("res://.tmp/tactical-craft")
	print("TACTICAL CRAFT LAYOUT OK: 16 equipment and maintenance cards in 3 tabs")
	if DisplayServer.get_name() == "headless":
		finished = true
		get_tree().quit()
	# catch (Exception E) dropped

func craft_detail_right_edge() -> float:
	return craft_panel.craft_panel_rect(Vector2(960, 540)).position.x + 20 + craft_panel.craft_panel_rect(Vector2(960, 540)).size.x * 0.54

func _physics_process(delta: float) -> void:
	pass

func _process(delta: float) -> void:
	if finished or capturing:
		return
	var review_hud = hud
	review_hud.visible = stage < 3
	if stage < 3:
		craft_panel.select_craft_tier(stage)
		craft_panel.craft_sel = selected[stage]
		review_hud.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if finished or capturing:
		return
	# try (GDScript has no exceptions; the body runs unguarded)
	draw_rect(Rect2(0, 0, 960, 540), Color("293631"))
	clock = 1.5
	if stage < 3:
		# DrawHud's real Control / CanvasLayer draws the panel, as it does during play.
		pass
	else:
		snap.tactical = [["poison", Vector2(240, 270), 3.0], ["heal", Vector2(480, 270), 3.0], ["trap", Vector2(680, 270), 100.0], ["blast", Vector2(800, 270), 0.25]]
		tactical_items.draw_tactical_areas()
		draw_string(ThemeDB.fallback_font, Vector2(36, 40), "EXPEDITION LOOT / support gear and world effects", 20)
		for i in range(GameSim.CHEST_SUPPORT.size()):
			var id = GameSim.CHEST_SUPPORT[i]
			var pos: Vector2 = Vector2(40 + i * 84, 440)
			inventory.draw_item_icon(self, id, pos, 3.0)
			draw_string(ThemeDB.fallback_font, pos + Vector2(-42, 52), id.replace("_", " "), 10)
		var p = snap.ps[1]
		p[8] = "long_spear"
		p[11] = true
		p[12] = 0.0
		player_view.draw_player(2, p, Vector2(140, 150))
		p[8] = "stun_maul"
		player_view.draw_player(3, p, Vector2(380, 150))
	warm_frames += 1
	if warm_frames < 12:
		return
	capturing = true
	await RenderingServer.frame_post_draw
	var shot = get_viewport().get_texture().get_image()
	shot.save_png("res://.tmp/tactical-craft/preview-%s.png" % [stage])
	stage += 1
	warm_frames = 0
	capturing = false
	if stage == 4:
		print("TACTICAL CRAFT RENDER OK")
		finished = true
		get_tree().quit()
	# catch (Exception E) dropped
