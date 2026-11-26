class_name FrontEndUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was in Main.cs.
# Owner: Mai Thien Ngon.
# Fonts (GDD table 6.1, SIL OFL 1.1, fonts/): Noto Sans for text, Oswald for titles, the timer and big numbers.
# Both are variable fonts; the UI is drawn at the window's resolution, so letters stay sharp (not pixel-scaled).
const FONT_UI = "res://fonts/NotoSans.ttf"
const FONT_TITLE = "res://fonts/Oswald.ttf"
var menu = VBoxContainer.new()
var name_edit = LineEdit.new()
var lobby = VBoxContainer.new()
var lobby_text = Label.new()
var lobby_role = OptionButton.new()
var mode_opt = OptionButton.new()
var start_btn = Button.new()
var bot_row = HBoxContainer.new()
var roster = []
var lobby_hint = Label.new()
var lobby_count = Label.new()
var role_cards = []
var bot_buttons = []
var portraits = {}
var audio_credits: AcceptDialog
static var ROLE_INFO = [["MOBILITY", "Fast movement & attacks"], ["SUPPORT", "Fast healing & revives"], ["DEFENCE", "Towers & repairs"]]

# constants shared with Main
const GOLD = Main.GOLD
const INK = Main.INK

var main: Main

func _init(host: Main) -> void:
	main = host

func lobby_ui() -> void:
	var eng = false
	var ids = main.snap.ps.keys()
	for i in roster.size():
		var row = roster[i]
		var occupied = i < ids.size()
		row.icon.visible = occupied
		if occupied:
			var id: int = int(ids[i])
			var p = main.snap.ps[id]
			eng = eng or p[1] == 2
			row.name.text = Cs.s(p[0]) + ("  / YOU" if id == main.my_id else "")
			row.meta.text = Cs.s(GameSim.ROLES[p[1]]) + ("  ·  AI teammate" if id < 0 else "  ·  You")
			row.badge.text = "LEADER" if id == main.snap.leader else "BOT" if id < 0 else "CREW"
			row.badge.add_theme_color_override("font_color", Main.ROLE_COL[p[1]])
			row.icon.texture = self.portrait(p[1])
			row.name.modulate = Color.WHITE
		else:
			row.name.text = "Empty slot"
			row.name.modulate = Color("64788A")
			row.meta.text = "Add bot"
			row.badge.text = "%02d" % [i + 1]
			row.badge.add_theme_color_override("font_color", Color("435768"))
	lobby_count.text = "%d / 5 CREW" % [ids.size()]
	lobby_text.text = main.snap.get("msg", "")
	var leader: bool = main.my_id == main.snap.leader
	start_btn.text = "START  >" if leader else "WAITING FOR LEADER"
	start_btn.disabled = not leader or not eng
	lobby_hint.text = "Ready" if eng else "Need Engineer"
	lobby_hint.modulate = Color("89A498") if eng else Color("F2B544")
	if not main.snap.ps.has(main.my_id):
		lobby_hint.text = "Lobby full."
	lobby_role.disabled = not main.snap.ps.has(main.my_id)
	if main.snap.ps.has(main.my_id) and not lobby_role.has_focus():
		lobby_role.selected = main.snap.ps[main.my_id][1]
	mode_opt.disabled = not leader
	bot_row.visible = leader
	bot_buttons[0].disabled = ids.size() >= 5
	bot_buttons[1].disabled = not ids.any(func(id): return id < 0)
	if not mode_opt.has_focus():
		mode_opt.selected = main.snap.mode
	self.update_role_cards()

func build_ui() -> void:
	# variable fonts: a semi-bold weight reads better over the dark HUD and the busy ground
	var wght: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	var ui_var = Cs.init(FontVariation.new(), {"base_font": load(FONT_UI)})
	ui_var.variation_opentype = {wght: 600}
	main.font_ui = ui_var
	var title_var = Cs.init(FontVariation.new(), {"base_font": load(FONT_TITLE)})
	title_var.variation_opentype = {wght: 600}
	main.font_title = title_var
	# every Control and world label
	ThemeDB.fallback_font = main.font_ui
	var ui = CanvasLayer.new()
	main.add_child(ui)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = self.theme()
	ui.add_child(root)
	main.hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The HUD and the menus filter linearly: the UI is drawn at 960 x 540 and scaled 1.5x, and nearest filtering
	# made every glyph land on a different screen pixel (letters jumping up and down, uneven gaps).
	# Pixel-art textures drawn here keep their hard pixels through Pixel() and TextureRect filters.
	main.hud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	main.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the HUD layers and the pause / result screens (ui/gameplay/hud.tscn)
	main.hud_ui.setup(main.hud)
	root.add_child(main.hud)
	main.front.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	main.front.draw.connect(func():
		var signal_args = []
		draw_frontend()
	)
	root.add_child(main.front)
	main.front.add_child(main.menu_panel)
	main.front.add_child(main.lobby_panel)
	main.menu_panel.add_child(menu)
	main.lobby_panel.add_child(lobby)
	menu.add_theme_constant_override("separation", 8)
	lobby.add_theme_constant_override("separation", 8)
	main.lobby_panel.add_theme_stylebox_override("panel", self.ui_style(Color("0D1823"), Color("3C505A"), 1, 16))
	menu.add_child(self.ui_label("NEW GAME", 32, Color.WHITE, true))
	menu.add_child(self.ui_label("CALLSIGN", 10, Color("8499AC")))
	name_edit.placeholder_text = "Your name"
	name_edit.text = "Player%d" % [randi_range(1, 99)]
	name_edit.max_length = 16
	menu.add_child(name_edit)
	for opt in [main.role_opt, lobby_role]:
		for r in GameSim.ROLES:
			opt.add_item(r)
	main.role_opt.selected = 2
	menu.add_child(self.ui_label("ROLE", 10, Color("8499AC")))
	menu.add_child(main.role_opt)
	menu.add_child(self.role_card(main.role_opt))
	var play_btn = self.ui_button("PLAY  >", true)
	play_btn.pressed.connect(func():
		var signal_args = []
		main.start_local()
	)
	menu.add_child(play_btn)
	var credits_btn = self.ui_button("AUDIO CREDITS")
	credits_btn.custom_minimum_size.y = 26
	credits_btn.add_theme_font_size_override("font_size", 11)
	credits_btn.pressed.connect(show_audio_credits)
	menu.add_child(credits_btn)
	main.status.add_theme_font_size_override("font_size", 11)
	main.status.add_theme_color_override("font_color", Color("F2B544"))
	main.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var component3 = main.status.custom_minimum_size
	component3.y = 16
	main.status.custom_minimum_size = component3
	menu.add_child(main.status)
	main.role_opt.item_selected.connect(func(a0):
		var signal_args = [a0]
		self.update_role_cards()
	)
	var lobby_header = HBoxContainer.new()
	var lobby_titles = VBoxContainer.new()
	lobby_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_titles.add_child(self.ui_label("CREW", 30, Color.WHITE, true))
	lobby_header.add_child(lobby_titles)
	lobby_count = self.ui_label("0 / 5 CREW", 12, Color("9CB9B2"))
	lobby_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lobby_header.add_child(lobby_count)
	lobby.add_child(lobby_header)
	lobby.add_child(HSeparator.new())
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	lobby.add_child(columns)
	var crew = VBoxContainer.new()
	var component4 = crew.custom_minimum_size
	component4.x = 408
	crew.custom_minimum_size = component4
	crew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew.add_theme_constant_override("separation", 7)
	columns.add_child(crew)
	crew.add_child(self.ui_label("THE CREW", 10, Color("8499AC")))
	for i in 5:
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", self.ui_style(Color("152330"), Color("2C4050"), 1, 6))
		var component5 = card.custom_minimum_size
		component5.y = 40
		card.custom_minimum_size = component5
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		card.add_child(row)
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var names = VBoxContainer.new()
		names.add_theme_constant_override("separation", 1)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pname = self.ui_label("Empty slot", 13)
		var meta = self.ui_label("Add bot", 10, Color("8499AC"))
		names.add_child(pname)
		names.add_child(meta)
		row.add_child(names)
		var badge = self.ui_label("", 10, GOLD)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
		crew.add_child(card)
		roster.append({"icon": icon, "name": pname, "meta": meta, "badge": badge})
	var setup = VBoxContainer.new()
	var component6 = setup.custom_minimum_size
	component6.x = 248
	setup.custom_minimum_size = component6
	setup.add_theme_constant_override("separation", 8)
	columns.add_child(setup)
	setup.add_child(self.ui_label("YOUR ROLE", 10, Color("8499AC")))
	lobby_role.item_selected.connect(func(a0):
		var signal_args = [a0]
		main.act("role", signal_args[0])
	)
	setup.add_child(lobby_role)
	setup.add_child(self.role_card(lobby_role))
	setup.add_child(self.ui_label("DIFFICULTY", 10, Color("8499AC")))
	for m in GameSim.MODES:
		mode_opt.add_item(m)
	mode_opt.item_selected.connect(func(a0):
		var signal_args = [a0]
		main.act("mode", signal_args[0])
	)
	setup.add_child(mode_opt)
	for b in [["Add bot", "add_bot"], ["Remove bot", "remove_bot"]]:
		var bb = self.ui_button(b[0])
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.pressed.connect(func():
			var signal_args = []
			main.act(b[1])
		)
		bot_row.add_child(bb)
		bot_buttons.append(bb)
	setup.add_child(bot_row)
	lobby_hint.add_theme_font_size_override("font_size", 11)
	setup.add_child(lobby_hint)
	self.style_primary(start_btn)
	var component7 = start_btn.custom_minimum_size
	component7.y = 38
	start_btn.custom_minimum_size = component7
	start_btn.pressed.connect(func():
		var signal_args = []
		main.act("start")
	)
	setup.add_child(start_btn)
	lobby.add_child(HSeparator.new())
	var bottom = HBoxContainer.new()
	lobby_text.add_theme_font_size_override("font_size", 11)
	lobby_text.add_theme_color_override("font_color", Color("F2B544"))
	lobby_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(lobby_text)
	var leave = self.ui_button("<  LEAVE")
	leave.pressed.connect(func():
		var signal_args = []
		main.back_to_menu("Left the lobby")
	)
	bottom.add_child(leave)
	lobby.add_child(bottom)
	self.update_role_cards()
	main.banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	main.banner.offset_top = 86
	main.banner.horizontal_alignment = 1
	main.banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.banner.add_theme_font_override("font", main.font_title)
	main.banner.add_theme_font_size_override("font_size", 24)
	main.banner.add_theme_color_override("font_color", Color("F2B544"))
	main.banner.add_theme_constant_override("outline_size", 5)
	main.banner.add_theme_color_override("font_outline_color", INK)
	root.add_child(main.banner)

func theme() -> Variant:
	var th = Theme.new()
	var sb = self.ui_style(Color("111E2A"), Color("344957"), 1, 9)
	var hov = self.ui_style(Color("203444"), Color("8AA6AE"), 1, 9)
	var focus = self.ui_style(Color(0, 0, 0, 0), GOLD, 2, 9)
	for cls in ["Button", "OptionButton", "LineEdit"]:
		th.set_stylebox("normal", cls, sb)
		th.set_stylebox("focus", cls, focus)
		th.set_stylebox("hover", cls, hov)
		th.set_stylebox("pressed", cls, hov)
		th.set_stylebox("disabled", cls, self.ui_style(Color("101B25"), Color("263541"), 1, 9))
		th.set_color("font_hover_color", cls, GOLD)
		th.set_color("font_disabled_color", cls, Color("607483"))
	th.set_stylebox("panel", "PanelContainer", self.ui_style(Color("0D1823"), Color("3C505A"), 1, 20))
	th.set_color("font_placeholder_color", "LineEdit", Color("627989"))
	th.set_stylebox("panel", "PopupMenu", self.ui_style(Color("111E2A"), Color("526D78"), 1, 8))
	th.set_stylebox("hover", "PopupMenu", hov)
	var line = StyleBoxLine.new()
	line.color = Color("2A3C49")
	line.thickness = 1
	th.set_stylebox("separator", "HSeparator", line)
	th.default_font = main.font_ui
	th.default_font_size = 13
	return th

func ui_style(bg, border, width, padding) -> Variant:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(padding)
	return sb

func ui_label(value, size, col = null, title = null) -> Variant:
	if col == null: col = Color.WHITE
	if title == null: title = false
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", col)
	if title:
		label.add_theme_font_override("font", main.font_title)
	return label

func ui_button(value, primary = null) -> Variant:
	if primary == null: primary = false
	var button = Button.new()
	button.text = value
	var component8 = button.custom_minimum_size
	component8.y = 32
	button.custom_minimum_size = component8
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		self.style_primary(button)
	return button

func show_audio_credits() -> void:
	if audio_credits == null:
		audio_credits = AcceptDialog.new()
		audio_credits.title = "Audio credits"
		audio_credits.dialog_text = "Vault — Alexandr Zhelanov (CC BY 3.0)\nApocalyptic Loops G / D — RUOK (CC BY 4.0)\nBlackmoor Colossus — Matthew Pablo (CC BY 3.0)\nAmbience of a Fallen Age — Umplix (CC0)\nDetermined Pursuit / Bittersweet — Emma_MA (CC0)\nFoley — Kenney (CC0)\nBeacon Home / creature & island sound design — original game audio\n\nScores: loudness-adjusted, Ogg conversion. Foley: edited and layered.\nFull sources and licences: art/audio/CREDITS.md\nopengameart.org · kenney.nl\ncreativecommons.org/licenses/by/3.0\ncreativecommons.org/licenses/by/4.0"
		main.add_child(audio_credits)
	audio_credits.popup_centered(Vector2i(690, 360))

func style_primary(button) -> void:
	button.add_theme_stylebox_override("normal", self.ui_style(Color("D9A94A"), Color("F1CC76"), 1, 10))
	button.add_theme_stylebox_override("hover", self.ui_style(Color("F1CC76"), Color("FFE4A3"), 1, 10))
	button.add_theme_stylebox_override("pressed", self.ui_style(Color("B98A35"), Color("F1CC76"), 1, 10))
	button.add_theme_color_override("font_color", Color("14212C"))
	button.add_theme_color_override("font_hover_color", Color("14212C"))
	button.add_theme_color_override("font_pressed_color", Color("14212C"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func portrait(role) -> Variant:
	if portraits.has(role):
		return portraits[role]
	var atlas = AtlasTexture.new()
	atlas.atlas = main.csheet[Main.ROLE_SKIN[role]]
	# first idle frame, facing the camera: the body in the middle of its sheet cell (row 1)
	var c = main.cinfo.chars[Main.ROLE_SKIN[role]]
	var cell: float = float(c.size)
	var body: float = float(c.get("body", c.size))
	var pad: float = (cell - body) / 2.0
	atlas.region = Rect2(pad, cell + pad, body, body)
	portraits[role] = atlas
	return atlas

func role_card(option) -> Variant:
	var panel_ = PanelContainer.new()
	panel_.add_theme_stylebox_override("panel", self.ui_style(Color("152530"), Color("2B4552"), 1, 9))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel_.add_child(row)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var words = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 3)
	var heading = self.ui_label("", 10, GOLD)
	var detail = self.ui_label("", 11, Color("9AAEBB"))
	words.add_child(heading)
	words.add_child(detail)
	row.add_child(words)
	role_cards.append({"option": option, "icon": icon, "heading": heading, "detail": detail, "role": -1})
	return panel_

func update_role_cards() -> void:
	for card in role_cards:
		var role: int = int(card.option.selected)
		if card.role == role:
			continue
		card.role = role
		card.icon.texture = self.portrait(role)
		card.heading.text = ROLE_INFO[role][0]
		card.heading.add_theme_color_override("font_color", Main.ROLE_COL[role])
		card.detail.text = ROLE_INFO[role][1]

func layout_frontend() -> void:
	var vs = main.front.size
	main.menu_panel.position = Vector2(vs.x - 368, maxf(66, (vs.y - main.menu_panel.size.y) / 2.0 + 4))
	var component9 = main.menu_panel.size
	component9.x = 328
	main.menu_panel.size = component9
	var component10 = main.lobby_panel.size
	component10.x = minf(856, vs.x - 64)
	main.lobby_panel.size = component10
	main.lobby_panel.position = Vector2((vs.x - main.lobby_panel.size.x) / 2.0, maxf(64, (vs.y - main.lobby_panel.size.y) / 2.0 + 8))

func front_sprite(n, at, scale, col) -> void:
	if not main.spr.has(n):
		return
	var tex = main.spr[n][0]
	main.front.draw_texture_rect(main.pixel(tex), Rect2(at - main.spr[n][1] * scale, tex.get_size() * scale), false, col)

func draw_frontend() -> void:
	var c = main.front
	var vs = c.size
	var w = vs.x
	var h = vs.y
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color("0B1420"))
	# A quiet sea and distant islands, drawn in the same hard-edged language as the sprites.
	c.draw_rect(Rect2(0, h * 0.48, w, h * 0.52), Color("102230"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.55), Vector2(w * 0.15, h * 0.38), Vector2(w * 0.23, h * 0.5), Vector2(w * 0.4, h * 0.34), Vector2(w * 0.59, h * 0.55)]), Color("152936"))
	for i in 38:
		var x = fmod(i * 139.0 + main.clock * (3 + i % 3), w)
		var y = h * 0.52 + fmod(i * 43.0, h * 0.48)
		c.draw_line(Vector2(x, y), Vector2(x + 12 + i % 5 * 8, y), Color(0.3, 0.5, 0.57, 0.12), 1)
	var moon = Vector2(w * 0.47, h * 0.25)
	c.draw_circle(moon, 38, Color(0.58, 0.72, 0.76, 0.035))
	c.draw_circle(moon, 27, Color("A0B4B8"))
	c.draw_circle(moon + Vector2(10, -7), 25, Color("0B1420"))
	# A small island vignette uses the actual in-game lighthouse and nature art.
	var foot = Vector2(w * 0.32, h * 0.88)
	c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-200, 9), foot + Vector2(-125, -23), foot + Vector2(4, -33), foot + Vector2(130, -12), foot + Vector2(190, 11), foot + Vector2(90, 32), foot + Vector2(-95, 29)]), Color("1A3037"))
	# the lamp sits 7 px below the top of the lighthouse sprite
	var lamp = foot - Vector2(0, (main.prop.lighthouse[1].y - 7) * 2.4) if main.prop.has("lighthouse") else foot + Vector2(0, -159)
	var sweep = sin(main.clock * 0.25) * 30
	c.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(240, -105 + sweep), lamp + Vector2(245, -12 + sweep)]), Color(0.92, 0.72, 0.32, 0.055))
	c.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(-245, -70 - sweep), lamp + Vector2(-245, -8 - sweep)]), Color(0.92, 0.72, 0.32, 0.04))
	self.front_sprite("pine_2", foot + Vector2(-112, -15), 2.4, Color("577276"))
	self.front_sprite("pine_3", foot + Vector2(106, -5), 2.4, Color("52656A"))
	if main.prop.has("lighthouse"):
		var p = main.prop.lighthouse
		var tex = p[0]
		c.draw_texture_rect(main.pixel(tex), Rect2(foot - p[1] * 2.4, tex.get_size() * 2.4), false, Color("B1C0BD"))
	c.draw_circle(lamp, 14, Color(1.0, 0.7, 0.25, 0.05))
	c.draw_circle(lamp, 4, Color("F3CC76"))
	for i in 10:
		var spark = foot + Vector2(sin(i * 7.2 + main.clock * 0.3) * 150, -fmod(i * 29 + main.clock * 9, 150))
		c.draw_rect(Rect2(spark, Vector2(2, 2)), Color(0.85, 0.72, 0.4, 0.18 + 0.12 * sin(main.clock + i)))
	# Masthead and footer frame both connection and crew screens.
	c.draw_rect(Rect2(32, 25, 20, 24), GOLD)
	c.draw_rect(Rect2(40, 29, 4, 13), Color("14212C"))
	c.draw_rect(Rect2(37, 33, 10, 4), Color("14212C"))
	main.text(c, Vector2(62, 36), "HOLD 'TIL DAWN", 15, Color("D6DFDD"), 0, -1, true)
	main.text(c, Vector2(62, 49), "SURVIVAL", 9, Color("6F8A99"))
	for i in 5:
		c.draw_rect(Rect2(w - 105 + i * 14, 44, 8, 3), GOLD if i == 0 else Color("334955"))
	if main.menu_panel.visible:
		main.text(c, Vector2(40, 160), "HOLD 'TIL", 60, Color("E7E4D8"), 0, -1, true)
		main.text(c, Vector2(40, 240), "DAWN", 76, GOLD, 0, -1, true)

func get_player_name() -> Variant:
	return name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Player"
