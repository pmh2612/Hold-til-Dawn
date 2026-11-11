extends Node2D
## Client + network glue: menu, lobby, input, drawing and hit feedback.
## Server rules live in game.gd (GameSim). The server owns state; clients only own their own movement.
## Look: dark top-down cartoon world, thick outlines, neon VFX with 2D glow, floating damage numbers.
## Dedicated server: godot --headless --path . -- --server

const PORT := 7777
const T := GameSim.T
const ROLE_COL := [Color("2BB3B1"), Color("F2F2F2"), Color("FF7A1A")]
const RES_COL := [Color("A0703C"), Color("9AA0A8"), Color("3DBE5A"), Color("C9834A")]
const DROP_COL := {"wood": Color("A0703C"), "stone": Color("9AA0A8"), "herb": Color("3DBE5A"), "metal": Color("C9834A"), "bandage": Color("F2F2F2")}
const GOLD := Color("D9A94A")
const INK := Color("141019")  # cartoon outline
const PANEL := Color(0.06, 0.07, 0.1, 0.86)
const NEON_CYAN := Color(0.6, 1.8, 2.2)  # >1 = glows (rendering/viewport/hdr_2d)
const NEON_PINK := Color(2.2, 0.5, 1.9)
const NEON_RED := Color(2.4, 0.4, 0.3)
const NIGHT_TINT := Color(0.09, 0.1, 0.2)

# 2.5D look: sprites baked from Quaternius 3D models (CC0) by tools/bake_nature.gd
const NATURE := "res://art/nature/"
const SPR := T / 32.0  # sprites are baked as pixel art at 32 px per tile: one sprite pixel = one game pixel
const WALL_H := 0.9 * T  # drawn height of the base walls
const LIFT := 0.6 * T  # a player's body centre sits this far above its feet
# Cold, bleak offshore island (GDD 4.3 / 5.1): only pines and dead trees, grey rock outcrops, dry grass.
# No broad-leaf trees, no flowers. Each resource has a look of its own so it is never mistaken for scenery.
const PINES := ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
const DEAD := ["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const BUSHES := ["Bush_Common"]
const SCATTER := ["Grass_Wispy_Short", "Grass_Wispy_Tall", "Grass_Common_Short", "Grass_Wispy_Short",
	"Grass_Wispy_Tall", "Pebble_Round_1", "Pebble_Round_3", "Pebble_Square_2", "Pebble_Square_4", "Pebble_Round_5"]
const COLD := Color(0.8, 0.88, 0.92)  # cool, less saturated scenery; resource nodes stay untinted and pop
const NODE_SPR := [["Pine_1", "Pine_3", "Pine_5"], ROCKS, ["Fern_1", "Mushroom_Laetiporus"], ["Rock_Medium_2", "Rock_Medium_3"]]  # wood, stone, herb, metal
const NODE_SCALE := [0.6, 0.85, 0.95, 0.8]  # a wood node is a young tree, smaller than the forest
const NODE_TINT := [Color.WHITE, Color.WHITE, Color.WHITE, Color(1.3, 0.78, 0.5)]  # metal = copper-tinted rock
# Characters: Kenney "Animated Characters Survivors" (CC0) baked to 8-direction sheets by tools/bake_chars.gd
const CHARS := "res://art/chars/"  # 32x32 pixel art (Wrecker 40x40) from tools/pixel_chars.gd, GDD style guide
const CHAR_H := 24.0  # height of a person's sprite above the feet, in pixels
const ROLE_SKIN := ["scout", "healer", "engineer"]  # CHR-01..03
const ENEMY_SKIN := ["grunt", "spitter", "wrecker", "wrecker"]  # CHR-05..07; a boss is a big tinted Wrecker until the 7 specimens are drawn
const ENEMY_TINT := [Color.WHITE, Color.WHITE, Color.WHITE, Color(1.2, 0.85, 1.25)]
const ZOOMS := [2, 3, 4]  # mouse-wheel zoom steps: screen pixels per art pixel (3 at 1440 x 810 = 15 x 8 tiles in view)
# Fonts (SIL OFL 1.1, fonts/): Pixelify Sans for all text, Jersey 10 for titles, timers and big numbers
const FONT_UI := "res://fonts/PixelifySans.ttf"
const FONT_TITLE := "res://fonts/Jersey10-Regular.ttf"
const TITLE_SCALE := 1.45  # Jersey 10 is tall and narrow: drawn larger to match Pixelify Sans
const PROPS := "res://art/props/"  # base props, towers and pads in pixel art (tools/pixel_props.gd)
const WORKBENCH := Vector2(0, 1.6 * T)  # where the workbench stands inside the base
const LIGHTHOUSE := Vector2(0, 0.3 * T)
const LIGHTHOUSE_SCALE := 2.0
const TOWER_SCALE := 2.0  # standing, wrecked and placement preview share the same size
# Solid things a player walks around (feet circles). Grass, pebbles, bushes and herbs stay walk-through.
const BODY_R := 0.3 * T  # a player's feet
const TREE_R := 0.3 * T  # trunk, times the tree's scale
const ROCK_R := 0.75 * T  # times the rock's scale
const NODE_R := [0.25 * T, 0.62 * T, 0.0, 0.6 * T]  # wood (young tree), stone, herb (walk-through), metal
const ENEMY_BODY := 0.6  # times the enemy's radius: small enough that every enemy still reaches you to hit

var sim: GameSim  # only on the server
var snap := {}
var my_id := 0
var local_pos := Vector2.ZERO
var local_tp := -1
var send_acc := 0.0
var frame := 0

# client-side presentation state
var shown_e := {}
var shown_p := {}
var prev_hp := {}
var prev_pos := {}
var prev_php := {}
var flash := {}
var fx: Array = []
var popups: Array = []
var shake := 0.0
var hurt := 0.0
var gen_flash := 0.0
var door_flash := [0.0, 0.0, 0.0]
var craft_open := false
var deco: Array = []  # [pos, sprite, scale, tint]: trees, rocks and bushes
var solids: Array = []  # [pos, radius]: trees, rocks, the lighthouse and workbench (bushes and grass are not solid)
var scatter: Array = []  # [pos, sprite, scale]: flat grass, flowers, pebbles
var spr := {}  # sprite name -> [Texture2D, anchor px]
var nvar := {}  # model name -> number of turned variants baked
var ground_tex := NoiseTexture2D.new()
var csheet := {}  # character -> Texture2D: rows right, down, left, up; columns idle 0-1, walk 0-3
var cinfo := {}  # chars.json: frames {anim: [first column, count]}, fps, chars {name: {size, anchor}}
var cmove := {}  # character key -> [last foot, clock when it last moved, facing angle]
var slash_t := {}  # player id -> clock of its last melee slash (it faces its aim for a moment after)
var zoom_i := 1  # index into ZOOMS
var font_ui: Font
var font_title: Font
var prop := {}  # name -> [Texture2D, anchor px]
var tower_lights: Array = []  # one warm PointLight2D per door (MEC-28)
var shot_path := ""  # dev: -- --shot=<file.png> [--shot-at=<s>] [--at=<x>,<y> tiles]
var shot_at := 4.0
var shot_pos = null
var clock := 0.0

var cam := Camera2D.new()
var tint := CanvasModulate.new()
var my_light := PointLight2D.new()
var beacon := PointLight2D.new()
var menu_panel := PanelContainer.new()
var menu := VBoxContainer.new()
var name_edit := LineEdit.new()
var role_opt := OptionButton.new()
var ip_edit := LineEdit.new()
var status := Label.new()
var lobby_panel := PanelContainer.new()
var lobby := VBoxContainer.new()
var lobby_text := Label.new()
var lobby_role := OptionButton.new()
var mode_opt := OptionButton.new()
var start_btn := Button.new()
var bot_row := HBoxContainer.new()
var hud := Control.new()
var banner := Label.new()
var front := Control.new()
var roster: Array = []
var lobby_hint := Label.new()
var lobby_count := Label.new()
var role_cards: Array = []
var bot_buttons: Array[Button] = []
var portraits := {}
const ROLE_INFO := [
	["FAST & FEARLESS", "Move faster. Strike faster.\nScout the island and lead the fight."],
	["KEEP THEM STANDING", "Healing flasks and faster revives.\nBring your crew home alive."],
	["BUILD THE LAST DEFENCE", "Build towers. Repair the base.\nKeep the beacon burning."]
]


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_back_to_menu.bind("Could not connect"))
	multiplayer.server_disconnected.connect(_back_to_menu.bind("Server stopped"))
	if DisplayServer.get_name() == "headless" or "--server" in OS.get_cmdline_user_args():
		_host(false)
		return
	_build_scene()
	_build_ui()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			shot_at = a.substr(10).to_float()
		elif a.begins_with("--at="):
			var xy := a.substr(5).split(",")
			shot_pos = Vector2(xy[0].to_float(), xy[1].to_float()) * T
	if "--autohost" in args or "--autolobby" in args:  # --autolobby previews the crew screen without starting.
		_host(true)
		var nb := 2
		for a in args:
			if a.begins_with("--bots="):
				nb = a.substr(7).to_int()
		for i in nb:
			sim.action(1, "add_bot", 0)
		if "--autolobby" not in args:
			sim.action(1, "start", 0)
		if "--night" in args:
			sim.action(1, "skip", 0)
			sim.tick(0.01)
			sim.t = 0.0
			sim.tick(0.01)
			sim.elapsed = maxf(0.0, GameSim.FIRST_WAVE_DELAY - 0.5)
	elif "--autojoin" in args:  # dev shortcut: join 127.0.0.1 and start when leader
		_join()


# --- network ------------------------------------------------------------

func _host(play: bool) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 5) != OK:
		status.text = "UDP port %d is busy" % PORT
		return
	multiplayer.multiplayer_peer = peer
	sim = GameSim.new()
	if play:
		my_id = 1
		sim.add_player(1, _name(), role_opt.selected)
	else:
		print("Hold 'til Dawn dedicated server on UDP %d" % PORT)


func _join() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip_edit.text.strip_edges(), PORT) != OK:
		status.text = "Bad address"
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Connecting..."


func _on_connected() -> void:
	my_id = multiplayer.get_unique_id()
	c_join.rpc_id(1, _name(), role_opt.selected)


func _on_peer_left(id: int) -> void:
	if sim:
		sim.remove_player(id)


func _back_to_menu(why: String) -> void:
	multiplayer.multiplayer_peer = null
	sim = null
	snap = {}
	my_id = 0
	status.text = why


@rpc("any_peer", "call_remote", "reliable")
func c_join(pname: String, role: int) -> void:
	if sim:
		sim.add_player(multiplayer.get_remote_sender_id(), pname, role)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_input(pos: Vector2, aim: float, atk: bool, inter: bool, ent: bool, tp: int) -> void:
	if sim:
		sim.input(multiplayer.get_remote_sender_id(), pos, aim, atk, inter, ent, tp)


@rpc("any_peer", "call_remote", "reliable")
func c_action(kind: String, arg: Variant) -> void:
	if sim:
		sim.action(multiplayer.get_remote_sender_id(), kind, arg)


@rpc("authority", "call_remote", "unreliable_ordered")
func s_snap(d: Dictionary) -> void:
	_on_snap(d)


func _act(kind: String, arg: Variant = 0) -> void:
	if sim:
		sim.action(my_id, kind, arg)
	elif my_id != 0:
		c_action.rpc_id(1, kind, arg)


func _physics_process(dt: float) -> void:
	if sim:
		sim.tick(dt)
		frame += 1
		if frame % 3 == 0:  # 20 Hz snapshots
			var d := sim.snapshot()
			if not multiplayer.get_peers().is_empty():
				s_snap.rpc(d)
			if my_id == 1:
				_on_snap(d)
	if my_id != 0 and snap.has("ps"):
		_move(dt)


func _move(dt: float) -> void:
	var me = snap.ps.get(my_id)
	if me == null:
		return
	if me[15] != local_tp:  # server teleported us
		local_tp = me[15]
		local_pos = me[2]
	var playing: bool = snap.ph in ["day", "dusk", "night"]
	if playing and me[5] == 0:
		var dir := Vector2(_key(KEY_D) - _key(KEY_A), _key(KEY_S) - _key(KEY_W))
		local_pos += dir.normalized() * GameSim.SPEED * (1.2 if me[1] == 0 else 1.0) * dt
		local_pos = _bump(local_pos, BODY_R)
	local_pos = local_pos.limit_length(GameSim.ISLAND)
	local_pos = GameSim.collide(local_pos, 0.4 * T, _doors_open())
	if snap.ph == "night" and not _breach() and not me[19]:  # nobody shelters inside at night (except the Engineer, MEC-15)
		local_pos = GameSim.push_out(local_pos, 0.4 * T)
	send_acc += dt
	if send_acc >= 0.05:
		send_acc = 0.0
		var aim := (get_global_mouse_position() - (local_pos - Vector2(0, LIFT))).angle()  # from the body, not the feet
		var atk := playing and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var inter := playing and Input.is_physical_key_pressed(KEY_E)
		var ent := playing and Input.is_physical_key_pressed(KEY_F)
		if sim:
			sim.input(my_id, local_pos, aim, atk, inter, ent, local_tp)
		else:
			c_input.rpc_id(1, local_pos, aim, atk, inter, ent, local_tp)


func _unhandled_input(ev: InputEvent) -> void:
	if my_id == 0 or not snap.has("ph"):
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.physical_keycode:
			KEY_Q:
				_act("bandage")
			KEY_T:
				_act("tower")
			KEY_V:
				_act("vote")
			KEY_C:
				craft_open = not craft_open
			KEY_F9:
				_act("skip")
			KEY_ESCAPE:
				_back_to_menu("Left the match")
			_:
				var n: int = ev.physical_keycode - KEY_1
				if craft_open and n >= 0 and n < GameSim.RECIPES.size():
					_act("craft", n)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_act("flask", get_global_mouse_position())
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_i = clampi(zoom_i + (1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)


# --- hit feedback (derived from snapshot diffs, no extra network) -------

func _on_snap(d: Dictionary) -> void:
	var same: bool = d.get("ph") == snap.get("ph") and d.get("k") == snap.get("k")
	if same and d.ph in ["day", "dusk", "night"]:  # roamers fight by day too
		var seen := {}
		for e in d.en:
			seen[e[0]] = true
			var old = prev_hp.get(e[0])
			if old != null and e[3] < old:
				var body: Vector2 = e[2] - Vector2(0, e[5])  # 2.5D: hits land on the body, not the feet
				_popup(body, str(roundi(old - e[3])), NEON_CYAN, 18 if e[1] == GameSim.BOSS else 15)
				flash[e[0]] = 0.1
				_sparks(body, 4, Color(1.6, 1.6, 2.0))
		for id in prev_pos:
			if not seen.has(id):
				_sparks(prev_pos[id], 16, NEON_PINK, 260.0)
		if d.base < snap.base:
			gen_flash = 0.4
			shake = maxf(shake, 2.0)
		for i in 3:
			if d.doors[i] < snap.doors[i]:
				door_flash[i] = 0.4
			elif d.doors[i] > snap.doors[i]:  # hammer sparks while a door is repaired
				_sparks(GameSim.DOOR_POS[i], 3, Color(2.2, 1.7, 0.6), 90.0)
	if same:
		for id in d.ps:
			var p = d.ps[id]
			var old = prev_php.get(id)
			if old != null and p[3] < old:
				_popup(p[2] - Vector2(0, LIFT), "-%d" % roundi(old - p[3]), NEON_RED, 15)
				if id == my_id:
					shake = maxf(shake, 7.0)
					hurt = 0.35
	var mine = d.get("ps", {}).get(my_id)
	var old_me = snap.get("ps", {}).get(my_id)
	if mine != null and old_me != null:
		for res in mine[7]:
			var gain: int = mine[7][res] - old_me[7].get(res, 0)
			if gain > 0:
				_popup(mine[2] - Vector2(0, LIFT), "+%d %s" % [gain, res], DROP_COL.get(res, Color.WHITE) * 1.6, 14)
	prev_hp.clear()
	prev_pos.clear()
	for e in d.get("en", []):
		prev_hp[e[0]] = e[3]
		prev_pos[e[0]] = e[2] - Vector2(0, e[5])
	prev_php.clear()
	for id in d.get("ps", {}):
		prev_php[id] = d.ps[id][3]
	snap = d


func _popup(pos: Vector2, text: String, col: Color, size: int) -> void:
	popups.append({"pos": pos + Vector2(randf_range(-10, 10), -20), "text": text, "col": col, "size": size, "life": 0.8})


func _sparks(pos: Vector2, n: int, col: Color, speed := 160.0) -> void:
	for i in n:
		if fx.size() < 400:
			fx.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * speed,
				"life": 0.45, "max": 0.45, "col": col, "r": randf_range(2.0, 4.5)})


# --- per-frame ----------------------------------------------------------

func _process(dt: float) -> void:
	if sim and my_id == 0:
		return  # dedicated server draws nothing
	clock += dt
	var ph: String = snap.get("ph", "")
	var in_game := ph in ["day", "dusk", "night", "result"]
	menu_panel.visible = ph == ""
	lobby_panel.visible = ph == "lobby"
	banner.visible = in_game
	front.visible = not in_game
	if front.visible:
		front.queue_redraw()
		_layout_frontend()
	var me_now = snap.get("ps", {}).get(my_id)
	if ph != "day" and ph != "dusk" and not (ph == "night" and me_now != null and me_now[19]):
		craft_open = false
	banner.text = snap.get("msg", "")
	if ph == "lobby":
		_lobby_ui()
		if "--autojoin" in OS.get_cmdline_user_args() and my_id == snap.leader and snap.ps.has(my_id):
			_act("start")
	hud.queue_redraw()
	queue_redraw()
	if shot_path != "" and clock >= shot_at:
		_capture_shot(shot_path)
		shot_path = ""
	if not in_game:
		return

	var a := minf(1.0, dt * 15.0)
	var ne := {}
	for e in snap.en:
		ne[e[0]] = shown_e.get(e[0], e[2]).lerp(e[2], a)
	shown_e = ne
	for id in snap.ps:
		shown_p[id] = shown_p.get(id, snap.ps[id][2]).lerp(snap.ps[id][2], a)
	for id in flash.keys():
		flash[id] -= dt
		if flash[id] <= 0:
			flash.erase(id)
	var damp := pow(0.02, dt)
	for f in fx:
		f.pos += f.vel * dt
		f.vel *= damp
		f.life -= dt
	fx = fx.filter(func(f): return f.life > 0)
	for p in popups:
		p.life -= dt
	popups = popups.filter(func(p): return p.life > 0)
	hurt = maxf(0.0, hurt - dt)
	gen_flash = maxf(0.0, gen_flash - dt)
	for i in 3:
		door_flash[i] = maxf(0.0, door_flash[i] - dt)
	shake = move_toward(shake, 0.0, dt * 30.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	cam.position = local_pos - Vector2(0, LIFT)
	# zoom so one art pixel covers a whole number of screen pixels: crisp pixel art at any window size
	var ws := Vector2(DisplayServer.window_get_size())
	var sc := minf(ws.x / 960.0, ws.y / 540.0)  # the canvas_items stretch scale
	cam.zoom = Vector2.ONE * maxf(1.0, ZOOMS[zoom_i] / sc)
	if shot_pos != null and clock > 0.5:
		local_pos = shot_pos
		shot_pos = null
	var me = snap.ps.get(my_id)
	var night := 0.0
	if ph == "night":
		night = 1.0
	elif ph == "dusk":
		night = 1.0 - snap.t / GameSim.DUSK
	tint.color = Color.WHITE.lerp(NIGHT_TINT, night)
	my_light.enabled = night > 0
	beacon.enabled = night > 0
	for l: PointLight2D in tower_lights:
		l.enabled = false
	for tw in snap.get("tw", []):
		var l: PointLight2D = tower_lights[tw[0]]
		l.enabled = night > 0 and tw[2] > 0  # the light goes out the moment the tower falls
		l.position = tw[1]
		l.energy = randf_range(0.45, 1.0) if tw[2] < 0.3 * GameSim.TOWER_HP else 1.0
	my_light.position = local_pos
	if me != null:  # FML-12: 4 tiles at night, Scout x1.3
		var r := 4.0 * T * (1.3 if me[1] == 0 else 1.0)
		my_light.texture_scale = lerpf(30.0 * T, r, night) * 2.0 / 256.0


func _lobby_ui() -> void:
	var eng := false
	var ids: Array = snap.ps.keys()
	for i in roster.size():
		var row: Dictionary = roster[i]
		var occupied := i < ids.size()
		row.icon.visible = occupied
		if occupied:
			var id: int = ids[i]
			var p: Array = snap.ps[id]
			eng = eng or p[1] == 2
			row.name.text = p[0] + ("  / YOU" if id == my_id else "")
			row.meta.text = GameSim.ROLES[p[1]] + ("  ·  AI teammate" if id < 0 else "  ·  Connected")
			row.badge.text = "LEADER" if id == snap.leader else ("BOT" if id < 0 else "CREW")
			row.badge.add_theme_color_override("font_color", ROLE_COL[p[1]])
			row.icon.texture = _portrait(p[1])
			row.name.modulate = Color.WHITE
		else:
			row.name.text = "Open crew slot"
			row.name.modulate = Color("64788A")
			row.meta.text = "Invite a friend or add a bot"
			row.badge.text = "%02d" % (i + 1)
			row.badge.add_theme_color_override("font_color", Color("435768"))
	lobby_count.text = "%d / 5 CREW" % ids.size()
	lobby_text.text = snap.get("msg", "")
	var leader: bool = my_id == snap.leader
	start_btn.text = "START EXPEDITION  >" if leader else "WAITING FOR LEADER"
	start_btn.disabled = not leader or not eng
	lobby_hint.text = "Crew ready. Hold the light together." if eng else "An Engineer is required to start."
	lobby_hint.modulate = Color("89A498") if eng else Color("F2B544")
	if not snap.ps.has(my_id):
		lobby_hint.text = "Lobby full or match running. Rejoin later."
	lobby_role.disabled = not snap.ps.has(my_id)
	if snap.ps.has(my_id) and not lobby_role.has_focus():
		lobby_role.selected = snap.ps[my_id][1]
	mode_opt.disabled = not leader
	bot_row.visible = leader
	bot_buttons[0].disabled = ids.size() >= 5
	bot_buttons[1].disabled = not ids.any(func(id): return id < 0)
	if not mode_opt.has_focus():
		mode_opt.selected = snap.mode
	_update_role_cards()


func _capture_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.linear_to_srgb()
	img.save_png(path)
	get_tree().quit()


# --- world drawing (2.5D) -------------------------------------------------
# The rules stay flat 2D (game.gd). Only the look is 2.5D: ground first, then everything with
# height (trees, rocks, walls, enemies, players) sorted by the y of its foot, back to front,
# so nearer things cover farther ones. Walls are drawn with a top face and a front face.

func _draw() -> void:
	if not (snap.get("ph", "") in ["day", "dusk", "night", "result"]):
		return
	var font := ThemeDB.fallback_font
	var view := Rect2(local_pos - Vector2(560, 330), Vector2(1120, 660)).grow(3 * T)
	var h := GameSim.HALF

	# ground layer: flat, nothing here hides anything
	draw_rect(view.grow(4 * T), Color("2E5266"))  # sea
	draw_circle(Vector2.ZERO, GameSim.ISLAND + 6 * T, Color("C9B48A"))  # beach (GDD sand)
	draw_circle(Vector2.ZERO, GameSim.ISLAND + 0.6 * T, Color("8C8E5E"))
	var isle := PackedVector2Array()
	for i in 96:
		isle.append(Vector2.from_angle(i * TAU / 96) * GameSim.ISLAND)
	_ground(isle, Color("66784C") * 1.15)  # outer zone grass, darker
	var safe := _round_rect(h, GameSim.SAFE_D)  # within 20 tiles of the nearest wall
	_ground(safe, Color("7A8B5C") * 1.15)  # GDD day grass
	safe.append(safe[0])
	draw_polyline(safe, Color(1, 1, 0.8, 0.12), 2)
	draw_rect(Rect2(-h - Vector2(2, 2) * T, (h + Vector2(2, 2) * T) * 2), Color("8A8F98"))  # concrete plaza
	for s in scatter:
		if view.has_point(s[0]):
			_sprite(s[1], s[0], s[2], COLD)
	for i in 3:  # landing pads
		var pp := GameSim.pad_pos(i)
		_prop("pad", pp)
		if snap.k == 5 and snap.ph == "night":  # extraction: edge lamps blink, the hold timer fills the ring (FML-13)
			var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			for j in 8:
				draw_rect(Rect2(pp + Vector2.from_angle(j * TAU / 8.0) * 117.0 - Vector2(2, 2), Vector2(4, 4)), Color(0.5, 1.2, 2.6) * (0.6 + blink))
			if snap.pads[i] > 0:
				draw_arc(pp, 108, -PI / 2, -PI / 2 + TAU * snap.pads[i] / 10.0, 64, Color(0.6, 2.0, 0.8), 6)
	draw_rect(Rect2(-h, h * 2), Color("6A6F7C"))  # base floor
	for x in range(int(-h.x) + 12, int(h.x) - 12, int(T)):
		draw_line(Vector2(x, -h.y + 12), Vector2(x, h.y - 12), Color(0, 0, 0, 0.12), 1)
	for y in range(int(-h.y) + 12, int(h.y) - 12, int(T)):
		draw_line(Vector2(-h.x + 12, y), Vector2(h.x - 12, y), Color(0, 0, 0, 0.12), 1)
	for tl in snap.tele:  # boss telegraph on the ground: ring fills over 1 s
		draw_circle(tl[0], tl[1], Color(1.0, 0.1, 0.3, 0.16))
		draw_circle(tl[0], tl[1] * (1.0 - tl[2]), Color(1.0, 0.15, 0.3, 0.35))
		draw_arc(tl[0], tl[1], 0, TAU, 48, NEON_RED, 3)

	# depth layer: [foot y, kind, ...], drawn back to front
	var items := []
	if cmove.size() > 400:  # forget dead enemies now and then
		cmove.clear()
	for e in snap.en:
		var pos: Vector2 = shown_e.get(e[0], e[2])
		if view.has_point(pos):
			items.append([pos.y, 2, e, pos])
	for id in snap.ps:
		var p = snap.ps[id]
		if p[5] != 2:
			var pos: Vector2 = local_pos if id == my_id else shown_p.get(id, p[2])
			items.append([pos.y, 3, id, p, pos])
	for d in deco:
		if view.has_point(d[0]):
			items.append([d[0].y, 0, d[1], d[0], d[2], d[3]])
	for nd in snap.nodes:
		if view.has_point(nd[1]):
			var names: Array = NODE_SPR[nd[0]]
			var hsh := int(absf(nd[1].x * 7.0 + nd[1].y * 13.0))
			var n := _var(names[hsh % names.size()], hsh / 7)
			var mod: Color = NODE_TINT[nd[0]]
			var s: float = NODE_SCALE[nd[0]]
			if nd[2] <= 0:  # gathered out until dawn: smaller, but still opaque
				s *= 0.7
			items.append([nd[1].y, 0, n, nd[1], s, mod])
	for r: Rect2 in GameSim.walls([true, true, true]):  # wall pieces with the three door gaps
		_wall_items(items, r, WALL_H, Color("8A8F98"), Color("5B5F6B"))
	for i in 3:
		var dur: float = snap.doors[i]
		var gap := _door_gap(i)
		if dur <= 0:  # broken: rubble
			items.append([gap.end.y, 7, gap])
		elif snap.ph == "night":  # closed slab, coloured by durability
			var col := Color("8FA3B8") if dur > 250 else Color("F2B544")
			if door_flash[i] > 0:
				col = col.lerp(Color(2, 2, 2), door_flash[i])
			_wall_items(items, gap, WALL_H * 0.8, col, col.darkened(0.45))
	items.append([WORKBENCH.y, 6, "workbench", WORKBENCH])
	items.append([LIGHTHOUSE.y, 6, "lighthouse", LIGHTHOUSE])  # the old lighthouse carries the beacon (GDD 5.1)
	for tw in snap.get("tw", []):  # defence towers (AGT-12)
		items.append([tw[1].y, 9, tw])
	var me_b = snap.ps.get(my_id)  # MEC-11: green preview where the Engineer would place a tower (drawn just behind them)
	if me_b != null and me_b[1] == 2 and me_b[5] == 0 and not me_b[19]:
		var slot := GameSim.tower_slot(local_pos)
		if slot >= 0 and not snap.get("tw", []).any(func(tw): return tw[0] == slot):
			items.append([local_pos.y - 0.5, 6, "tower", local_pos, Color(0.6, 1.6, 0.7, 0.45)])
	for i in 3:  # lamp pillars on both sides of every door
		for fp: Rect2 in _door_pillars(i):
			items.append([fp.end.y, 8, fp])
	for b in snap.proj:
		items.append([b.y, 4, b])
	for d in snap.get("drops", []):
		items.append([d[0].y, 5, d])
	items.sort_custom(func(a, b): return a[0] < b[0])

	var tnow := Time.get_ticks_msec() / 1000.0
	for it in items:
		match it[1]:
			0:
				_sprite(it[2], it[3], it[4], it[5])
			1:
				_wall(it[2], it[3], it[4], it[5], it[6])
			2:
				_draw_enemy(it[2], it[3])
			3:
				_draw_player(it[2], it[3], it[4])
			4:
				_shadow(it[2] + Vector2(0, -4), 5)
				draw_circle(it[2] - Vector2(0, LIFT), 7, Color(1.6, 1.9, 0.4, 0.35))
				draw_circle(it[2] - Vector2(0, LIFT), 3.5, Color(2.0, 2.2, 0.6))
			5:
				var d: Array = it[2]
				if d[3] < 5.0 and fmod(tnow, 0.3) < 0.12:  # MEC-23: blink in the last 5 s
					continue
				var dc: Color = DROP_COL.get(d[1], Color.WHITE)
				var dp: Vector2 = d[0] - Vector2(0, 10 + sin(tnow * 4.0 + d[0].x) * 3.0)
				_shadow(d[0] - Vector2(0, 6), 7)
				draw_circle(dp, 12, Color(dc.r * 1.8, dc.g * 1.8, dc.b * 1.8, 0.3))
				_diamond(self, dp, 8, INK)
				_diamond(self, dp, 6, dc)
			6:
				_prop(it[2], it[3], it[4] if it.size() > 4 else Color.WHITE)
			8:
				_pillar(it[2])
			9:
				_draw_tower(it[2])
			7:
				var g: Rect2 = it[2]
				for k in 5:
					var c := g.position + Vector2(fmod(k * 13.7, g.size.x), fmod(k * 29.3, g.size.y))
					_box(Rect2(c - Vector2(5, 4), Vector2(10, 8)), 5.0, Color("4A2226"))

	# overlays: always readable, never hidden by depth
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for i in 3:
		var dp: Vector2 = GameSim.DOOR_POS[i]
		var dd: Vector2 = GameSim.DOOR_DIR[i]
		var along := Vector2(abs(dd.y), abs(dd.x))
		if i in snap.active:
			var mc := dp + dd * 16
			draw_line(mc - along * 1.4 * T, mc + along * 1.4 * T, NEON_RED * (0.5 + 0.5 * pulse), 3)
		var lp: Vector2 = dp + dd * 1.5 * T + Vector2(-6, 7) - Vector2(0, WALL_H)
		draw_string_outline(font_title, lp, GameSim.DOOR_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, INK)
		draw_string(font_title, lp, GameSim.DOOR_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	for id in snap.ps:
		var p = snap.ps[id]
		if p[5] != 2:
			_player_ui(id, p, local_pos if id == my_id else shown_p.get(id, p[2]), font)
	for f in fx:
		draw_circle(f.pos, f.r * f.life / f.max, f.col)


func _draw_enemy(e: Array, foot: Vector2) -> void:
	var ty: int = e[1]
	var size: float = cinfo.chars[ENEMY_SKIN[ty]].size
	var s: float = e[5] / (0.5 * T) * 32.0 / size  # GDD size in tiles over the sprite's own size: the 40 px Wrecker is drawn 1:1
	var mod: Color = ENEMY_TINT[ty]
	if flash.has(e[0]):
		mod = Color(2.0, 2.0, 2.0)
	_char("e%d" % e[0], ENEMY_SKIN[ty], foot, null, s, mod)
	if e[3] < e[4] and ty != GameSim.BOSS:
		_bar(foot - Vector2(0, size * 0.7 * s + 4), e[5] * 2.2, e[3] / e[4], NEON_RED)


func _draw_player(id: int, p: Array, foot: Vector2) -> void:
	var r := T * 0.42
	var aim: float = p[12]
	if id == my_id:  # own aim straight from the mouse, not the server's echo
		aim = (get_global_mouse_position() - (local_pos - Vector2(0, LIFT))).angle()
	draw_set_transform(foot, 0, Vector2(1.0, 0.45))  # role ring on the ground, so roles read apart
	draw_arc(Vector2.ZERO, r * 1.15, 0, TAU, 32, ROLE_COL[p[1]], 2.5)
	draw_set_transform(Vector2.ZERO)
	if p[5] == 1:  # downed: lies flat on the ground (GDD readability rule), greyed out
		draw_set_transform(foot + Vector2(14, -4), -PI / 2)  # turned on its side, body centred on the feet
		_char("d%d" % id, ROLE_SKIN[p[1]], Vector2.ZERO, PI / 2, 1.0, Color(0.6, 0.55, 0.6))
		draw_set_transform(Vector2.ZERO)
		return
	if p[11]:
		slash_t[id] = clock
	var fighting: bool = clock - float(slash_t.get(id, -9.0)) < 0.4
	if id == my_id and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fighting = true
	_char(id, ROLE_SKIN[p[1]], foot, aim, 1.0, Color.WHITE, fighting)
	if p[11]:  # melee slash
		var pos := foot - Vector2(0, LIFT)
		draw_arc(pos, 1.35 * T, aim - PI / 4, aim + PI / 4, 16, NEON_CYAN, 5)
		draw_arc(pos, 1.1 * T, aim - PI / 5, aim + PI / 5, 12, Color(1.5, 1.5, 1.5, 0.6), 2)


func _char(key: Variant, skin: String, foot: Vector2, aim: Variant, s: float, mod: Color, lock := false) -> void:
	## A pixel-art character: the walk cycle while it moves, idle breathing otherwise.
	## While it walks it faces where it walks (no moonwalking); standing still it faces `aim` (the mouse),
	## and with `lock` (fighting) it faces `aim` even on the move. With aim null (enemies) it faces its walk.
	var m: Array = cmove.get(key, [foot, -1.0, PI / 2])
	var step: Vector2 = foot - m[0]
	if step.length() > 0.2:
		m[1] = clock
		m[2] = step.angle()
	m[0] = foot
	cmove[key] = m
	var tex: Texture2D = csheet.get(skin)
	if tex == null:
		return
	var moving: bool = clock - m[1] < 0.15
	var anim := "run" if moving else "idle"
	var ang: float = m[2] if aim == null or (moving and not lock) else aim
	var dir := posmod(roundi(ang / (PI / 2.0)), 4)  # rows: right, down, left, up
	var fr: Array = cinfo.frames[anim]
	var k: int = int((clock + (absi(hash(key)) % 97) * 0.13) * cinfo.fps[anim]) % int(fr[1])  # out of step with each other
	if moving and cos(m[2] - ang) < -0.2:  # backing off while fighting: legs step backwards
		k = int(fr[1]) - 1 - k
	var f: int = int(fr[0]) + k
	var c: Dictionary = cinfo.chars[skin]
	var size := Vector2(c.size, c.size)
	var anchor := Vector2(c.anchor[0], c.anchor[1])
	draw_texture_rect_region(tex, Rect2(foot - anchor * s, size * s), Rect2(Vector2(f, dir) * size, size), mod)


func _player_ui(id: int, p: Array, foot: Vector2, font: Font) -> void:
	var r := T * 0.42
	var pos := foot - Vector2(0, 0 if p[5] == 1 else LIFT)
	if p[20] > 0:
		draw_arc(pos, r + 13, -PI / 2, -PI / 2 + TAU * p[20] / 2.0, 24, Color(2.2, 1.6, 0.5), 4)
	var prog: float = p[14] if p[14] > 0 else (1.0 - p[13] / 2.0 if p[13] > 0 else p[21])
	if prog > 0:
		draw_arc(pos, r + 8, -PI / 2, -PI / 2 + TAU * prog, 24, Color(0.6, 2.0, 0.8), 3)
	var top := foot - Vector2(0, (10.0 if p[5] == 1 else CHAR_H) + 2)  # just above the head
	if id != my_id:
		_bar(top, T, p[3] / p[4], Color("3DBE5A"))
	var label: String = p[0] + ("  DOWN %d" % p[6] if p[5] == 1 else "")
	var lp := top + Vector2(-2 * T, -6)
	draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 4 * T, 7, 2, INK)
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 4 * T, 7, NEON_RED if p[5] == 1 else Color.WHITE)


func _bump(pos: Vector2, r: float) -> Vector2:
	## Keeps the local player's feet out of trees, rocks, the lighthouse and workbench, resource nodes
	## (not herbs), towers and enemies; it slides around them. Walls come after this, so a wall always wins.
	for o in solids:
		var c: Vector2 = o[0]
		if absf(c.x - pos.x) < 2 * T and absf(c.y - pos.y) < 2 * T:
			pos = _push(pos, r, c, o[1])
	for nd in snap.get("nodes", []):
		if nd[2] > 0 and NODE_R[nd[0]] > 0:
			pos = _push(pos, r, nd[1], NODE_R[nd[0]])
	for tw in snap.get("tw", []):
		pos = _push(pos, r, tw[1], 0.35 * T * TOWER_SCALE)
	for e in snap.get("en", []):
		pos = _push(pos, r, shown_e.get(e[0], e[2]), e[5] * ENEMY_BODY)
	return pos


static func _push(pos: Vector2, r: float, c: Vector2, cr: float) -> Vector2:
	var d := pos - c
	var need := r + cr
	if d.length_squared() >= need * need:
		return pos
	return c + (d.normalized() if d.length() > 0.01 else Vector2.DOWN) * need


func _var(n: String, k: int) -> String:
	return "%s_%d" % [n, absi(k) % maxi(1, nvar.get(n, 1))]


func _ground(pts: PackedVector2Array, col: Color) -> void:
	var uv := PackedVector2Array()
	for p in pts:
		uv.append(p / 512.0)  # the noise tile repeats every 16 tiles
	draw_colored_polygon(pts, col, uv, ground_tex)


func _sprite_rect(n: String, pos: Vector2, s: float) -> Rect2:
	var sp = spr.get(n)
	if sp == null:
		return Rect2(pos, Vector2.ZERO)
	return Rect2(pos - sp[1] * SPR * s, (sp[0] as Texture2D).get_size() * SPR * s)


func _sprite(n: String, pos: Vector2, s: float, mod := Color.WHITE) -> void:
	var sp = spr.get(n)
	if sp != null:
		draw_texture_rect(sp[0], _sprite_rect(n, pos, s), false, mod)


func _door_gap(i: int) -> Rect2:
	var h := GameSim.HALF
	var th := GameSim.WALL_IN + GameSim.WALL_OUT
	var g := GameSim.DOOR_GAP
	return [Rect2(-h.x - GameSim.WALL_OUT, -g, th, 2 * g), Rect2(-g, -h.y - GameSim.WALL_OUT, 2 * g, th),
		Rect2(h.x - GameSim.WALL_IN, -g, th, 2 * g)][i]


func _wall_items(items: Array, r: Rect2, height: float, top: Color, face: Color) -> void:
	## A horizontal wall is one item. A vertical wall is cut into 1-tile pieces so a player
	## beside it sorts correctly against each piece; the pieces join into one wall.
	if r.size.y <= r.size.x:
		items.append([r.end.y, 1, r, height, top, face, true])
		return
	var lo := maxf(r.position.y, -GameSim.HALF.y + GameSim.WALL_IN)  # corners belong to the long walls
	var hi := minf(r.end.y, GameSim.HALF.y - GameSim.WALL_IN)
	var y := lo
	while y < hi - 0.5:
		var piece := Rect2(r.position.x, y, r.size.x, minf(T, hi - y))
		items.append([piece.end.y, 1, piece, height, top, face, y == lo and lo > -GameSim.HALF.y + GameSim.WALL_IN + 0.5])
		y += T


func _wall(r: Rect2, height: float, top: Color, face: Color, cap: bool) -> void:
	var t := Rect2(r.position - Vector2(0, height), r.size)  # top face, lifted
	var f := Rect2(r.position.x, r.end.y - height, r.size.x, height)  # front face, toward the camera
	draw_rect(f, face)
	var row := 0
	for y in range(int(f.position.y), int(f.end.y), 7):  # pixel-art concrete blocks: courses with staggered joints
		draw_rect(Rect2(f.position.x, y, f.size.x, 1), face.darkened(0.3))
		var x0 := int(f.position.x) - int(f.position.x) % 16 + (8 if row % 2 else 0)
		for x in range(x0, int(f.end.x), 16):
			if x > f.position.x:
				draw_rect(Rect2(x, y, 1, minf(7.0, f.end.y - y)), face.darkened(0.3))
		draw_rect(Rect2(f.position.x, y + 1, f.size.x, 1), face.lightened(0.08))
		row += 1
	draw_rect(t, top)
	for x in range(int(t.position.x) - int(t.position.x) % 4, int(t.end.x), 4):  # speckled top, like weathered concrete
		for y in range(int(t.position.y) - int(t.position.y) % 4, int(t.end.y), 4):
			if (x * 7 + y * 13) % 11 == 0 and t.has_point(Vector2(x, y)):
				draw_rect(Rect2(x, y, 1, 1), top.darkened(0.18))
	draw_line(Vector2(t.position.x, f.position.y), Vector2(t.end.x, f.position.y), top.lightened(0.3), 1)
	draw_line(Vector2(t.position.x, t.position.y), Vector2(t.position.x, r.end.y), INK, 2)
	draw_line(Vector2(t.end.x, t.position.y), Vector2(t.end.x, r.end.y), INK, 2)
	draw_line(Vector2(t.position.x, r.end.y), Vector2(t.end.x, r.end.y), INK, 2)
	if cap:
		draw_line(t.position, Vector2(t.end.x, t.position.y), INK, 2)


func _box(r: Rect2, height: float, col: Color) -> void:
	var t := Rect2(r.position - Vector2(0, height), r.size)
	draw_rect(Rect2(t.position, Vector2(r.size.x, r.size.y + height)).grow(2), INK)
	draw_rect(Rect2(r.position.x, r.end.y - height, r.size.x, height), col.darkened(0.4))
	draw_rect(t, col)


func _prop(n: String, pos: Vector2, mod := Color.WHITE) -> void:
	## A pixel-art prop with its ground anchor on pos, snapped to whole pixels.
	var p = prop.get(n)
	if p != null:
		var scale := 1.0
		if n == "lighthouse":
			scale = LIGHTHOUSE_SCALE
		elif n in ["tower", "tower_wreck"]:
			scale = TOWER_SCALE
		var texture: Texture2D = p[0]
		draw_texture_rect(texture, Rect2((pos - p[1] * scale).round(), texture.get_size() * scale), false, mod)


func _door_pillars(i: int) -> Array:
	## Footprints of the two lamp pillars at the ends of door i's opening.
	var g := _door_gap(i)
	if i == 1:  # north door: the wall runs left-right
		return [Rect2(g.position.x - 10, g.position.y - 1, 10, g.size.y + 2), Rect2(g.end.x, g.position.y - 1, 10, g.size.y + 2)]
	return [Rect2(g.position.x - 1, g.position.y - 10, g.size.x + 2, 10), Rect2(g.position.x - 1, g.end.y, g.size.x + 2, 10)]


func _pillar(r: Rect2) -> void:
	## A door pillar: taller than the wall, with a lamp on top that glows from dusk.
	var hgt := WALL_H + 10.0
	_wall(r, hgt, Color("A3A8B0"), Color("6A6F7C"), true)
	var lamp := Rect2((r.get_center() - Vector2(2, hgt + 1)).round(), Vector2(4, 3))
	draw_rect(lamp.grow(1), INK)
	draw_rect(lamp, Color(2.4, 1.7, 0.6) if snap.ph in ["dusk", "night"] else Color("F2B544"))


func _draw_tower(tw: Array) -> void:
	## Defence tower (AGT-12): [door, pos, hp, wrecked, has target, target pos].
	var pos: Vector2 = tw[1]
	var hp: float = tw[2]
	var up := hp > 0
	var mod := Color.WHITE
	if up and hp < 0.3 * GameSim.TOWER_HP and fmod(clock, 0.5) < 0.12:  # flickers below 30% HP (MEC-28)
		mod = Color(0.65, 0.65, 0.75)
	_prop("tower" if up else "tower_wreck", pos, mod)
	if up and tw[4] and fmod(clock, 0.25) < 0.1:  # firing: tracer from the gun to the target
		var tgt: Vector2 = tw[5] - Vector2(0, 12)
		draw_line(pos + Vector2(11, -46) * TOWER_SCALE, tgt, Color(2.4, 1.8, 0.7), 1.5)
		draw_circle(tgt, 3, Color(2.4, 1.8, 0.7))
	if hp < GameSim.TOWER_HP:
		_bar(pos - Vector2(0, (64 if up else 26) * TOWER_SCALE), T * 1.2 * TOWER_SCALE, hp / GameSim.TOWER_HP, Color("F2B544") if up else NEON_RED)


func _blob(pos: Vector2, r: float, col: Color) -> void:
	draw_circle(pos, r + 2.5, INK)
	draw_circle(pos, r, col)
	draw_circle(pos + Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1, 1, 1, 0.12))


func _shadow(pos: Vector2, r: float) -> void:
	draw_set_transform(pos, 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)


func _round_rect(half: Vector2, r: float) -> PackedVector2Array:
	## Outline of the base rectangle grown by r (a rectangle with corners rounded by r).
	var pts := PackedVector2Array()
	for c in [[Vector2(half.x, half.y), 0.0], [Vector2(-half.x, half.y), PI / 2], [Vector2(-half.x, -half.y), PI], [Vector2(half.x, -half.y), PI * 1.5]]:
		for i in 9:
			pts.append(c[0] + Vector2.from_angle(c[1] + i * PI / 16) * r)
	return pts


func _bar(center: Vector2, w: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(center - Vector2(w / 2 + 1, 3), Vector2(w + 2, 6)), INK)
	draw_rect(Rect2(center - Vector2(w / 2, 2), Vector2(w * clampf(frac, 0, 1), 4)), col)


# --- HUD drawing (screen space) -----------------------------------------

func _draw_hud() -> void:
	var ph: String = snap.get("ph", "")
	if not (ph in ["day", "dusk", "night", "result"]):
		return
	var c := hud
	var vs := c.size
	var me = snap.ps.get(my_id)
	var ct := get_viewport().get_canvas_transform()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)

	for p in popups:  # floating damage numbers
		var k: float = p.life / 0.8
		var sp: Vector2 = ct * p.pos + Vector2(0, -36 * (1.0 - k))
		var size := int(p.size * (1.0 + 0.5 * clampf((k - 0.8) * 5.0, 0, 1)))
		var col: Color = p.col
		col.a = clampf(k * 2.0, 0, 1)
		_text(c, sp - Vector2(30, 0), p.text, size, col, HORIZONTAL_ALIGNMENT_CENTER, 60)

	# phase + timer
	var tl := "%d:%02d" % [int(maxf(snap.t, 0)) / 60, int(maxf(snap.t, 0)) % 60]
	var phase_line: String = {"day": "DAY %d/5" % snap.k, "dusk": "DUSK", "night": "NIGHT %d/5" % snap.k, "result": "RESULT"}[ph]
	_text(c, Vector2(12, 24), "%s   %s" % [phase_line, tl], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	if ph == "day":
		_text(c, Vector2(12, 40), "skip vote %d/%d  (V, anytime)" % [snap.votes, snap.need], 11, Color(1, 1, 1, 0.6))
	if snap.ext >= 0:
		_text(c, Vector2(12, 40), "EXTENSION %ds - hold a pad 10 s  %s" % [snap.ext, str(snap.pads.map(func(v): return snappedf(v, 0.1)))], 12, NEON_RED)

	# top centre: generator + doors
	var cx := vs.x / 2
	_panel(c, Rect2(cx - 160, 6, 320, 46))
	var gcol := Color("F2B544").lerp(Color(2.5, 0.5, 0.4), gen_flash / 0.4)
	_text(c, Vector2(cx - 150, 21), "GENERATOR", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	_text(c, Vector2(cx + 60, 21), "%d / 1000" % snap.base, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 90, true)
	c.draw_rect(Rect2(cx - 150, 25, 300, 7), INK)
	c.draw_rect(Rect2(cx - 150, 25, 300 * snap.base / 1000.0, 7), gcol)
	for i in 3:
		var r := Rect2(cx - 150 + i * 102, 36, 96, 12)
		var dur: float = snap.doors[i]
		var col := Color("8FA3B8") if dur > 250 else (Color("F2B544") if dur > 0 else NEON_RED)
		c.draw_rect(r, INK)
		c.draw_rect(Rect2(r.position + Vector2(14, 3), Vector2(68 * dur / 500.0, 6)), col)
		var tws: Array = snap.get("tw", []).filter(func(tw): return tw[0] == i)  # tower icon: lit = a standing tower (HUD 3)
		var tcol := Color("F2B544") if not tws.is_empty() and tws[0][2] > 0 else Color(0.4, 0.42, 0.48)
		c.draw_rect(Rect2(r.position + Vector2(87, 4), Vector2(2, 7)), tcol)
		c.draw_rect(Rect2(r.position + Vector2(85, 2), Vector2(6, 3)), tcol)
		_text(c, r.position + Vector2(2, 11), GameSim.DOOR_NAMES[i], 11, Color.WHITE)
		if i in snap.active:
			c.draw_rect(r.grow(1), NEON_RED * (0.6 + 0.6 * pulse if door_flash[i] > 0 else 0.7), false, 1.5)

	# boss bar
	for e in snap.en:
		if e[1] == GameSim.BOSS:
			var br := Rect2(cx - 230, 66, 460, 10)
			_text(c, Vector2(cx - 230, 62), "NOX-01  JUGGERNAUT", 12, NEON_PINK, HORIZONTAL_ALIGNMENT_CENTER, 460, true)
			c.draw_rect(br.grow(2), INK)
			c.draw_rect(Rect2(br.position, Vector2(br.size.x * e[3] / e[4], br.size.y)), NEON_PINK)
			for x in [br.position.x - 6, br.end.x + 6]:
				_diamond(c, Vector2(x, br.get_center().y), 8, NEON_PINK)

	# left: team list
	var y := 120.0
	for id in snap.ps:
		var p = snap.ps[id]
		var col: Color = ROLE_COL[p[1]]
		_panel(c, Rect2(8, y - 16, 150, 32))
		c.draw_circle(Vector2(24, y), 12, INK)
		c.draw_circle(Vector2(24, y), 10, col if p[5] == 0 else col.darkened(0.6))
		_text(c, Vector2(40, y - 3), p[0] + (" (you)" if id == my_id else ""), 11, Color.WHITE)
		if p[5] == 0:
			c.draw_rect(Rect2(40, y + 3, 110, 5), INK)
			c.draw_rect(Rect2(40, y + 3, 110 * p[3] / p[4], 5), Color("3DBE5A"))
		else:
			_text(c, Vector2(40, y + 11), "DOWN %ds" % p[6] if p[5] == 1 else "DEAD - Revival kit", 10, NEON_RED)
		y += 38

	# top right: resources + damage ranking
	if me != null:
		var inv: Dictionary = me[7]
		var rx := vs.x - 130
		_panel(c, Rect2(rx - 8, 6, 130, 84))
		var i := 0
		for res in GameSim.RES:
			c.draw_circle(Vector2(rx + 6, 20 + i * 18), 6, INK)
			c.draw_circle(Vector2(rx + 6, 20 + i * 18), 5, RES_COL[i])
			_text(c, Vector2(rx + 18, 25 + i * 18), "%s  x%d" % [res, inv[res]], 12, Color.WHITE)
			i += 1
	var ranks: Array = snap.ps.keys()
	ranks.sort_custom(func(a, b): return snap.ps[a][18] > snap.ps[b][18])
	var top: float = maxf(1.0, snap.ps[ranks[0]][18]) if ranks.size() > 0 else 1.0
	var ry := 104.0
	_panel(c, Rect2(vs.x - 138, ry - 12, 130, 18 + ranks.size() * 16))
	_text(c, Vector2(vs.x - 130, ry + 1), "DAMAGE", 10, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	for n in ranks.size():
		var p = snap.ps[ranks[n]]
		var yy := ry + 14 + n * 16
		_text(c, Vector2(vs.x - 130, yy), "%dP" % (n + 1), 10, NEON_RED if n == 0 else Color.WHITE)
		c.draw_rect(Rect2(vs.x - 108, yy - 7, 50 * p[18] / top, 6), ROLE_COL[p[1]])
		_text(c, Vector2(vs.x - 54, yy), str(int(p[18])), 10, Color.WHITE)

	if me == null:
		return
	# bottom left: HP hexagon + small hexes
	var hp_c := Vector2(48, vs.y - 50)
	_hex(c, hp_c, 38, GOLD)
	_hex(c, hp_c, 34, INK)
	_hex(c, hp_c, 31, Color("B3262A").lerp(Color(2.5, 0.4, 0.3), hurt / 0.35))
	_text(c, hp_c + Vector2(-40, 8), str(int(me[3])), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 80, true)
	_text(c, hp_c + Vector2(-40, 24), "/%d" % me[4], 10, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 80)
	var small := [[Color("3B6FB0"), "%d%%" % int(GameSim.ARMOUR[me[9]] * 100)], [Color("2E8B4A"), str(me[7].bandage)]]
	if me[1] == 1:
		small.append([Color("3DBE5A"), "+%d" % me[10]])
	for i in small.size():
		var sc := Vector2(102 + i * 30, vs.y - 24)
		_hex(c, sc, 14, INK)
		_hex(c, sc, 12, small[i][0])
		_text(c, sc + Vector2(-15, 4), small[i][1], 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 30)
	_text(c, Vector2(92, vs.y - 44), GameSim.ROLES[me[1]].to_upper(), 12, ROLE_COL[me[1]], HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	if me[5] != 0:
		_text(c, Vector2(0, vs.y / 2 + 40), "DOWN - %ds to bleed out" % me[6] if me[5] == 1 else "DEAD - waiting for a Revival kit", 18, NEON_RED, HORIZONTAL_ALIGNMENT_CENTER, vs.x, true)

	# bottom right: weapon card
	var wr := Rect2(vs.x - 236, vs.y - 62, 228, 54)
	_panel(c, wr)
	_text(c, wr.position + Vector2(10, 18), GameSim.WEAPONS[me[8]], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	for t in 3:
		_diamond(c, wr.position + Vector2(14 + t * 16, 34), 5, GOLD if t <= me[8] else Color(1, 1, 1, 0.15))
	_text(c, wr.position + Vector2(10, 48), "LMB hit  E use  Q heal  C craft  F door  T tower", 9, Color(1, 1, 1, 0.55))
	var hint: String = me[16]
	var gathering_hint := false
	if hint == "" and me[1] == 2 and me[5] == 0 and not me[19]:  # MEC-11 / MEC-28 tower feedback for the Engineer
		var tws: Array = snap.get("tw", [])
		for tw in tws:
			if local_pos.distance_to(tw[1]) <= 1.5 * T:
				var tcap: float = GameSim.TOWER_HP * (0.3 if tw[3] else 1.0)
				hint = ("Tower at door %s: %d / %d" % [GameSim.DOOR_NAMES[tw[0]], tw[2], tcap]) + \
					("   |   hold E to repair (wood %d)" % me[7].wood if tw[2] < tcap else "")
				break
		var slot := GameSim.tower_slot(local_pos)
		if hint == "" and slot >= 0 and not tws.any(func(tw): return tw[0] == slot):
			if snap.get("free_tower", false):
				hint = "T: place the free tower at door %s" % GameSim.DOOR_NAMES[slot]
			elif snap.unlock < 2:
				hint = "More towers unlock after the first boss"
			else:
				hint = "T: build a tower at door %s (10 wood + 5 metal)" % GameSim.DOOR_NAMES[slot]
	if hint == "" and ph in ["day", "dusk"] and me[5] == 0:
		for nd in snap.nodes:
			if nd[2] > 0 and local_pos.distance_to(nd[1]) <= 1.5 * T:
				var pct := int(me[21] * 100)
				hint = "Gathering %s... %d%%" % [GameSim.RES[nd[0]], pct] if me[21] > 0 else "Hold E (stand still) to gather %s - %d left" % [GameSim.RES[nd[0]], nd[2]]
				gathering_hint = true
				break
	if hint == "" and ph in ["day", "dusk", "night"] and me[1] == 2 and me[5] == 0 and not me[19] \
			and not GameSim.inside_base(local_pos):  # MEC-12 door repair feedback
		for i in 3:
			if local_pos.distance_to(GameSim.DOOR_POS[i]) > 1.5 * T:
				continue
			var dn: String = GameSim.DOOR_NAMES[i]
			var cap: float = GameSim.DOOR_HP * (0.3 if snap.broken[i] else 1.0)
			var dur: float = snap.doors[i]
			if dur >= cap:
				hint = "Door %s is at full durability (%d)" % [dn, dur]
			elif snap.broken[i] and snap.inside_en:
				hint = "Door %s is broken - clear the enemies inside before repairing" % dn
			elif me[7].wood <= 0:
				hint = "Need wood to repair door %s (1 wood per 10 durability)" % dn
			elif Input.is_physical_key_pressed(KEY_E):
				hint = ("Repair interrupted by a hit on door %s!" % dn) if snap.dpause[i] else ("Repairing door %s  %d / %d" % [dn, dur, cap])
			else:
				hint = "Hold E to repair door %s  %d / %d  (wood %d)" % [dn, dur, cap, me[7].wood]
			if ph == "night" and dur > 0:
				hint += "   |   hold F to enter"
			break
	if hint == "" and ph == "night" and me[1] == 2 and me[5] == 0:
		if me[19]:
			hint = "Inside the base: C craft  -  hold F at a door to leave"
		else:
			for i in 3:
				if snap.doors[i] > 0 and local_pos.distance_to(GameSim.DOOR_POS[i]) <= 2.0 * T:
					hint = "Hold F (stand still) to enter the base"
	if hint != "":
		if gathering_hint:
			c.draw_string(font_ui, Vector2(0, vs.y - 74), hint, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 13, Color.BLACK)
		else:
			_text(c, Vector2(0, vs.y - 74), hint, 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	if craft_open:
		var cr := Rect2(vs.x - 300, 190, 290, 22 + GameSim.RECIPES.size() * 18)
		_panel(c, cr)
		_text(c, cr.position + Vector2(10, 16), "WORKBENCH  (number to craft, C close)", 11, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		for i in GameSim.RECIPES.size():
			var r: Array = GameSim.RECIPES[i]
			var cost := []
			for res in r[1]:
				cost.append("%d %s" % [r[1][res], res])
			var locked: bool = r[2] > snap.unlock
			var line := "%d  %s - %s%s" % [i + 1, r[0], ", ".join(PackedStringArray(cost)), "  [Eng]" if r[5] else ""]
			_text(c, cr.position + Vector2(10, 34 + i * 18), line + ("  LOCKED" if locked else ""), 11, Color(1, 1, 1, 0.35) if locked else Color.WHITE)

	if hurt > 0:  # red screen-edge flash
		var a := hurt / 0.35 * 0.5
		for r in [Rect2(0, 0, vs.x, 14), Rect2(0, vs.y - 14, vs.x, 14), Rect2(0, 0, 14, vs.y), Rect2(vs.x - 14, 0, 14, vs.y)]:
			c.draw_rect(r, Color(0.9, 0.05, 0.05, a))


func _text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, title := false) -> void:
	## HUD text with a dark outline; title = Jersey 10 (headings, timer, big numbers), otherwise Pixelify Sans.
	var font := font_title if title else font_ui
	var fs := roundi(size * TITLE_SCALE) if title else size
	var ol := 2 if fs <= 12 else (3 if fs < 20 else 4)  # thin outline on small text, so pixel letters stay open
	ci.draw_string_outline(font, pos, s, align, width, fs, ol, Color(0, 0, 0, 0.9 * col.a))
	ci.draw_string(font, pos, s, align, width, fs, col)


func _panel(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, PANEL)
	ci.draw_rect(r, GOLD * Color(1, 1, 1, 0.7), false, 1.5)


func _hex(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(center + Vector2.from_angle(deg_to_rad(60 * i - 90)) * r)
	ci.draw_colored_polygon(pts, col)


func _diamond(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]), col)


# --- setup --------------------------------------------------------------

func _build_scene() -> void:
	RenderingServer.set_default_clear_color(Color("0E1726"))  # sea
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(tint)
	add_child(cam)
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color.BLACK)
	g.add_point(0.7, Color.WHITE)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	my_light.texture = tex
	beacon.texture = tex
	beacon.color = Color("F2B544")
	beacon.texture_scale = GameSim.HALF.x * 4.0 / 256.0
	add_child(my_light)
	add_child(beacon)
	for i in 3:  # tower lights: warm, 6 tiles, seen by every player (BAL-12, MEC-28)
		var tl := PointLight2D.new()
		tl.texture = tex
		tl.color = Color("F2B544")
		tl.texture_scale = GameSim.TOWER_LIGHT * 2.0 / 256.0
		tl.enabled = false
		tl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tl.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED  # the scene repeats its ground texture; a light must not tile
		add_child(tl)
		tower_lights.append(tl)
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NATURE + "index.json"))
	for n: String in idx:
		spr[n] = [load(NATURE + n + ".png"), Vector2(idx[n][0], idx[n][1])]
		var base := n.rsplit("_", true, 1)  # "Pine_2_1" = model Pine_2, turned variant 1
		nvar[base[0]] = maxi(nvar.get(base[0], 0), base[1].to_int() + 1)
	cinfo = JSON.parse_string(FileAccess.get_file_as_string(CHARS + "chars.json"))
	for n: String in cinfo.chars:
		csheet[n] = load(CHARS + n + ".png")
	var pj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROPS + "props.json"))
	for n: String in pj:
		prop[n] = [load(PROPS + n + ".png"), Vector2(pj[n][0], pj[n][1])]
	var fn := FastNoiseLite.new()  # light/dark patches so the grass is not one flat colour
	fn.frequency = 0.018
	fn.fractal_octaves = 3
	var ramp := Gradient.new()  # four flat tones with hard steps: pixel-art ground, like the sprites
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.55, 0.75])
	ramp.colors = PackedColorArray([Color(0.87, 0.89, 0.85), Color(0.92, 0.94, 0.9), Color(0.96, 0.97, 0.94), Color(1.0, 1.0, 0.97)])
	ground_tex.width = 512
	ground_tex.height = 512
	ground_tex.seamless = true
	ground_tex.noise = fn
	ground_tex.color_ramp = ramp
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # the whole world is pixel art: no smoothing when scaled up
	my_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # light falloff stays soft
	beacon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	my_light.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	beacon.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# outer zone (GDD 4.3): "tree clusters and rock outcrops", off the 3-tile door corridors
	var outer := func(p: Vector2) -> bool:
		return GameSim.wall_dist(p) > GameSim.SAFE_D + 2 * T and not GameSim.in_door_lane(p, 2.5 * T) \
			and p.length() < GameSim.ISLAND - 2 * T
	var ring := func() -> Vector2:
		return Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(GameSim.HALF.x + GameSim.SAFE_D, GameSim.ISLAND - 4 * T)
	for c in 44:  # pine stands, a few dead trees among them
		var centre: Vector2 = ring.call()
		for k in rng.randi_range(4, 10):
			var p := centre + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 5.5 * T)
			if outer.call(p):
				var pool: Array = DEAD if rng.randf() < 0.2 else PINES
				deco.append([p, _var(pool[rng.randi() % pool.size()], rng.randi()), rng.randf_range(0.8, 1.2), COLD])
	for c in 24:  # rock outcrops
		var centre: Vector2 = ring.call()
		for k in rng.randi_range(3, 6):
			var p := centre + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 2.2 * T)
			if outer.call(p):
				deco.append([p, _var(ROCKS[rng.randi() % ROCKS.size()], rng.randi()), rng.randf_range(0.8, 1.6), COLD])
	for i in 40:  # lone dead trees on the open ground
		var p: Vector2 = ring.call()
		if outer.call(p):
			deco.append([p, _var(DEAD[rng.randi() % DEAD.size()], rng.randi()), rng.randf_range(0.8, 1.1), COLD])
	for i in 400:  # the safe zone stays open grass (GDD 4.3): only a few low bushes
		var pos := Vector2.from_angle(rng.randf() * TAU) * GameSim.ISLAND * sqrt(rng.randf())
		var wd := GameSim.wall_dist(pos)
		if wd > 3 * T and wd < GameSim.SAFE_D and not GameSim.in_door_lane(pos, 2.5 * T) and rng.randf() < 0.12:
			deco.append([pos, _var(BUSHES[0], rng.randi()), rng.randf_range(0.6, 0.9), COLD])
	while scatter.size() < 1400:
		var pos := Vector2.from_angle(rng.randf() * TAU) * GameSim.ISLAND * sqrt(rng.randf())
		if not GameSim.inside_base(pos, 2.6 * T):
			scatter.append([pos, _var(SCATTER[rng.randi() % SCATTER.size()], rng.randi()), rng.randf_range(0.8, 1.2)])
	scatter.sort_custom(func(a, b): return a[0].y < b[0].y)
	for d in deco:
		var n: String = d[1]
		if not n.begins_with("Bush"):
			solids.append([d[0], (ROCK_R if n.begins_with("Rock") else TREE_R) * float(d[2])])
	solids.append([LIGHTHOUSE + Vector2(0, -3) * LIGHTHOUSE_SCALE, 11.0 * LIGHTHOUSE_SCALE])
	for x in [-10.0, 0.0, 10.0]:  # the workbench is wide: three small circles along it
		solids.append([WORKBENCH + Vector2(x, -4), 7.0])


func _build_ui() -> void:
	var ui_var := FontVariation.new()  # Pixelify Sans is a variable font: a little bolder reads better on the dark HUD
	ui_var.base_font = load(FONT_UI)
	ui_var.variation_opentype = {"wght": 560}
	font_ui = ui_var
	font_title = load(FONT_TITLE)
	ThemeDB.fallback_font = font_ui  # every Control and world label
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	ui.add_child(root)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	root.add_child(hud)
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.draw.connect(_draw_frontend)
	root.add_child(front)
	front.add_child(menu_panel)
	front.add_child(lobby_panel)
	menu_panel.add_child(menu)
	lobby_panel.add_child(lobby)
	menu.add_theme_constant_override("separation", 8)
	lobby.add_theme_constant_override("separation", 8)
	lobby_panel.add_theme_stylebox_override("panel", _ui_style(Color("0D1823"), Color("3C505A"), 1, 16))
	menu.add_child(_ui_label("YOUR WATCH BEGINS HERE", 10, GOLD))
	menu.add_child(_ui_label("Join the watch", 32, Color.WHITE, true))
	menu.add_child(_ui_label("CALLSIGN", 10, Color("8499AC")))
	name_edit.placeholder_text = "Your name"
	name_edit.text = "Player%d" % randi_range(1, 99)
	name_edit.max_length = 16
	menu.add_child(name_edit)
	for opt in [role_opt, lobby_role]:
		for r in GameSim.ROLES:
			opt.add_item(r)
	role_opt.selected = 2
	menu.add_child(_ui_label("CHOOSE YOUR ROLE", 10, Color("8499AC")))
	menu.add_child(role_opt)
	menu.add_child(_role_card(role_opt))
	var host_btn := _ui_button("HOST A CREW  >", true)
	host_btn.pressed.connect(_host.bind(true))
	menu.add_child(host_btn)
	var divider := HBoxContainer.new()
	divider.add_theme_constant_override("separation", 10)
	for i in 3:
		if i == 1:
			divider.add_child(_ui_label("OR JOIN FRIENDS", 10, Color("8499AC")))
		else:
			var line := HSeparator.new()
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			divider.add_child(line)
	menu.add_child(divider)
	var join_row := HBoxContainer.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Host IP address"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.custom_minimum_size.x = 0
	join_row.add_child(ip_edit)
	var join_btn := _ui_button("JOIN  >")
	join_btn.custom_minimum_size.x = 76
	join_btn.pressed.connect(_join)
	join_row.add_child(join_btn)
	menu.add_child(join_row)
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color("F2B544"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 16
	menu.add_child(status)
	role_opt.item_selected.connect(func(_i): _update_role_cards())

	var lobby_header := HBoxContainer.new()
	var lobby_titles := VBoxContainer.new()
	lobby_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_titles.add_child(_ui_label("EXPEDITION / CREW ASSEMBLY", 10, GOLD))
	lobby_titles.add_child(_ui_label("Nobody holds alone.", 30, Color.WHITE, true))
	lobby_header.add_child(lobby_titles)
	lobby_count = _ui_label("0 / 5 CREW", 12, Color("9CB9B2"))
	lobby_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lobby_header.add_child(lobby_count)
	lobby.add_child(lobby_header)
	lobby.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	lobby.add_child(columns)
	var crew := VBoxContainer.new()
	crew.custom_minimum_size.x = 408
	crew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew.add_theme_constant_override("separation", 7)
	columns.add_child(crew)
	crew.add_child(_ui_label("THE CREW", 10, Color("8499AC")))
	for i in 5:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _ui_style(Color("152330"), Color("2C4050"), 1, 6))
		card.custom_minimum_size.y = 40
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", 1)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pname := _ui_label("Open crew slot", 13)
		var meta := _ui_label("Invite a friend or add a bot", 10, Color("8499AC"))
		names.add_child(pname)
		names.add_child(meta)
		row.add_child(names)
		var badge := _ui_label("", 10, GOLD)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
		crew.add_child(card)
		roster.append({"icon": icon, "name": pname, "meta": meta, "badge": badge})
	crew.add_child(_ui_label("Invite friends using your host's IP address.", 11, Color("8499AC")))
	var setup := VBoxContainer.new()
	setup.custom_minimum_size.x = 248
	setup.add_theme_constant_override("separation", 8)
	columns.add_child(setup)
	setup.add_child(_ui_label("YOUR ROLE", 10, Color("8499AC")))
	lobby_role.item_selected.connect(func(i): _act("role", i))
	setup.add_child(lobby_role)
	setup.add_child(_role_card(lobby_role))
	setup.add_child(_ui_label("DIFFICULTY", 10, Color("8499AC")))
	for m in GameSim.MODES:
		mode_opt.add_item(m)
	mode_opt.item_selected.connect(func(i): _act("mode", i))
	setup.add_child(mode_opt)
	for b in [["Add bot", "add_bot"], ["Remove bot", "remove_bot"]]:  # bot teammates fill empty slots (max 5 players)
		var bb := _ui_button(b[0])
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.pressed.connect(_act.bind(b[1]))
		bot_row.add_child(bb)
		bot_buttons.append(bb)
	setup.add_child(bot_row)
	lobby_hint.add_theme_font_size_override("font_size", 11)
	setup.add_child(lobby_hint)
	_style_primary(start_btn)
	start_btn.custom_minimum_size.y = 38
	start_btn.pressed.connect(func(): _act("start"))
	setup.add_child(start_btn)
	lobby.add_child(HSeparator.new())
	var bottom := HBoxContainer.new()
	lobby_text.add_theme_font_size_override("font_size", 11)
	lobby_text.add_theme_color_override("font_color", Color("F2B544"))
	lobby_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(lobby_text)
	var leave := _ui_button("<  LEAVE CREW")
	leave.pressed.connect(_back_to_menu.bind("Left the lobby"))
	bottom.add_child(leave)
	lobby.add_child(bottom)
	_update_role_cards()

	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 86
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_override("font", font_title)
	banner.add_theme_font_size_override("font_size", 24)
	banner.add_theme_color_override("font_color", Color("F2B544"))
	banner.add_theme_constant_override("outline_size", 5)
	banner.add_theme_color_override("font_outline_color", INK)
	root.add_child(banner)


func _theme() -> Theme:
	var th := Theme.new()
	var sb := _ui_style(Color("111E2A"), Color("344957"), 1, 9)
	var hov := _ui_style(Color("203444"), Color("8AA6AE"), 1, 9)
	var focus := _ui_style(Color(0, 0, 0, 0), GOLD, 2, 9)
	for cls in ["Button", "OptionButton", "LineEdit"]:
		th.set_stylebox("normal", cls, sb)
		th.set_stylebox("focus", cls, focus)
		th.set_stylebox("hover", cls, hov)
		th.set_stylebox("pressed", cls, hov)
		th.set_stylebox("disabled", cls, _ui_style(Color("101B25"), Color("263541"), 1, 9))
		th.set_color("font_hover_color", cls, GOLD)
		th.set_color("font_disabled_color", cls, Color("607483"))
	th.set_stylebox("panel", "PanelContainer", _ui_style(Color("0D1823"), Color("3C505A"), 1, 20))
	th.set_color("font_placeholder_color", "LineEdit", Color("627989"))
	th.set_stylebox("panel", "PopupMenu", _ui_style(Color("111E2A"), Color("526D78"), 1, 8))
	th.set_stylebox("hover", "PopupMenu", hov)
	var line := StyleBoxLine.new()
	line.color = Color("2A3C49")
	line.thickness = 1
	th.set_stylebox("separator", "HSeparator", line)
	th.default_font = font_ui
	th.default_font_size = 13
	return th


func _ui_style(bg: Color, border: Color, width: int, padding: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(padding)
	return sb


func _ui_label(value: String, size: int, col := Color.WHITE, title := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", col)
	if title:
		label.add_theme_font_override("font", font_title)
	return label


func _ui_button(value: String, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 32
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		_style_primary(button)
	return button


func _style_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _ui_style(Color("D9A94A"), Color("F1CC76"), 1, 10))
	button.add_theme_stylebox_override("hover", _ui_style(Color("F1CC76"), Color("FFE4A3"), 1, 10))
	button.add_theme_stylebox_override("pressed", _ui_style(Color("B98A35"), Color("F1CC76"), 1, 10))
	button.add_theme_color_override("font_color", Color("14212C"))
	button.add_theme_color_override("font_hover_color", Color("14212C"))
	button.add_theme_color_override("font_pressed_color", Color("14212C"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _portrait(role: int) -> AtlasTexture:
	if portraits.has(role):
		return portraits[role]
	var atlas := AtlasTexture.new()
	atlas.atlas = csheet[ROLE_SKIN[role]]
	atlas.region = Rect2(0, 32, 32, 32)  # first idle frame, facing the camera
	portraits[role] = atlas
	return atlas


func _role_card(option: OptionButton) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _ui_style(Color("152530"), Color("2B4552"), 1, 9))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 3)
	var heading := _ui_label("", 10, GOLD)
	var detail := _ui_label("", 11, Color("9AAEBB"))
	words.add_child(heading)
	words.add_child(detail)
	row.add_child(words)
	role_cards.append({"option": option, "icon": icon, "heading": heading, "detail": detail, "role": -1})
	return panel


func _update_role_cards() -> void:
	for card in role_cards:
		var role: int = card.option.selected
		if card.role == role:
			continue
		card.role = role
		card.icon.texture = _portrait(role)
		card.heading.text = ROLE_INFO[role][0]
		card.heading.add_theme_color_override("font_color", ROLE_COL[role])
		card.detail.text = ROLE_INFO[role][1]


func _layout_frontend() -> void:
	var vs := front.size
	menu_panel.position = Vector2(vs.x - 368, maxf(66, (vs.y - menu_panel.size.y) / 2.0 + 4))
	menu_panel.size.x = 328
	lobby_panel.size.x = minf(856, vs.x - 64)
	lobby_panel.position = Vector2((vs.x - lobby_panel.size.x) / 2.0, maxf(64, (vs.y - lobby_panel.size.y) / 2.0 + 8))


func _front_sprite(n: String, at: Vector2, scale: float, col: Color) -> void:
	if not spr.has(n):
		return
	var tex: Texture2D = spr[n][0]
	front.draw_texture_rect(tex, Rect2(at - spr[n][1] * scale, tex.get_size() * scale), false, col)


func _draw_frontend() -> void:
	var c := front
	var vs := c.size
	var w := vs.x
	var h := vs.y
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color("0B1420"))
	# A quiet sea and distant islands, drawn in the same hard-edged language as the sprites.
	c.draw_rect(Rect2(0, h * 0.48, w, h * 0.52), Color("102230"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.55), Vector2(w * 0.15, h * 0.38), Vector2(w * 0.23, h * 0.5), Vector2(w * 0.4, h * 0.34), Vector2(w * 0.59, h * 0.55)]), Color("152936"))
	for i in 38:
		var x := fmod(i * 139.0 + clock * (3 + i % 3), w)
		var y := h * 0.52 + fmod(i * 43.0, h * 0.48)
		c.draw_line(Vector2(x, y), Vector2(x + 12 + i % 5 * 8, y), Color(0.3, 0.5, 0.57, 0.12), 1)
	var moon := Vector2(w * 0.47, h * 0.25)
	c.draw_circle(moon, 38, Color(0.58, 0.72, 0.76, 0.035))
	c.draw_circle(moon, 27, Color("A0B4B8"))
	c.draw_circle(moon + Vector2(10, -7), 25, Color("0B1420"))
	# A small island vignette uses the actual in-game lighthouse and nature art.
	var foot := Vector2(w * 0.32, h * 0.88)
	c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-200, 9), foot + Vector2(-125, -23), foot + Vector2(4, -33), foot + Vector2(130, -12), foot + Vector2(190, 11), foot + Vector2(90, 32), foot + Vector2(-95, 29)]), Color("1A3037"))
	var lamp := foot + Vector2(0, -159)
	var sweep := sin(clock * 0.25) * 30
	c.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(240, -105 + sweep), lamp + Vector2(245, -12 + sweep)]), Color(0.92, 0.72, 0.32, 0.055))
	c.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(-245, -70 - sweep), lamp + Vector2(-245, -8 - sweep)]), Color(0.92, 0.72, 0.32, 0.04))
	_front_sprite("Pine_3_1", foot + Vector2(-112, -15), 0.85, Color("577276"))
	_front_sprite("DeadTree_1_1", foot + Vector2(106, -5), 0.75, Color("52656A"))
	if prop.has("lighthouse"):
		var p: Array = prop.lighthouse
		var tex: Texture2D = p[0]
		c.draw_texture_rect(tex, Rect2(foot - p[1] * 2.4, tex.get_size() * 2.4), false, Color("B1C0BD"))
	c.draw_circle(lamp, 14, Color(1.0, 0.7, 0.25, 0.05))
	c.draw_circle(lamp, 4, Color("F3CC76"))
	for i in 10:
		var spark := foot + Vector2(sin(i * 7.2 + clock * 0.3) * 150, -fmod(i * 29 + clock * 9, 150))
		c.draw_rect(Rect2(spark, Vector2(2, 2)), Color(0.85, 0.72, 0.4, 0.18 + 0.12 * sin(clock + i)))
	# Masthead and footer frame both connection and crew screens.
	c.draw_rect(Rect2(32, 25, 20, 24), GOLD)
	c.draw_rect(Rect2(40, 29, 4, 13), Color("14212C"))
	c.draw_rect(Rect2(37, 33, 10, 4), Color("14212C"))
	_text(c, Vector2(62, 36), "HOLD 'TIL DAWN", 15, Color("D6DFDD"), HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	_text(c, Vector2(62, 49), "CO-OP SURVIVAL / ISLAND WATCH", 9, Color("6F8A99"))
	_text(c, Vector2(w - 215, 36), "THE LONG NIGHT AWAITS", 10, Color("8DA4AC"))
	for i in 5:
		c.draw_rect(Rect2(w - 105 + i * 14, 44, 8, 3), GOLD if i == 0 else Color("334955"))
	if menu_panel.visible:
		_text(c, Vector2(40, 181), "HOLD 'TIL", 72, Color("E7E4D8"), HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		_text(c, Vector2(40, 251), "DAWN", 90, GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)


func _name() -> String:
	return name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Player"


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


func _doors_open() -> Array:  # open by day; at night only a broken door lets anyone through
	var night: bool = snap.get("ph", "") == "night"
	return snap.doors.map(func(d): return not night or d <= 0)


func _breach() -> bool:
	for d in snap.doors:
		if d <= 0:
			return true
	return false
