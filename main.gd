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
var deco: Array = []

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
var hud := Control.new()
var banner := Label.new()


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
	if "--autohost" in args:  # dev shortcut: host + start at once (-- --autohost [--night])
		_host(true)
		sim.action(1, "start", 0)
		if "--night" in args:
			sim.action(1, "skip", 0)
			sim.tick(0.01)
			sim.t = 0.0
			sim.tick(0.01)
			sim.elapsed = 29.5
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
	local_pos = local_pos.limit_length(GameSim.ISLAND)
	local_pos = GameSim.collide(local_pos, 0.4 * T, _doors_open())
	if snap.ph == "night" and not _breach() and not me[19]:  # nobody shelters inside at night (except the Engineer, MEC-15)
		local_pos = GameSim.push_out(local_pos, 0.4 * T)
	send_acc += dt
	if send_acc >= 0.05:
		send_acc = 0.0
		var aim := (get_global_mouse_position() - local_pos).angle()
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


# --- hit feedback (derived from snapshot diffs, no extra network) -------

func _on_snap(d: Dictionary) -> void:
	var same: bool = d.get("ph") == snap.get("ph") and d.get("k") == snap.get("k")
	if same and d.ph in ["day", "dusk", "night"]:  # roamers fight by day too
		var seen := {}
		for e in d.en:
			seen[e[0]] = true
			var old = prev_hp.get(e[0])
			if old != null and e[3] < old:
				_popup(e[2], str(roundi(old - e[3])), NEON_CYAN, 18 if e[1] == GameSim.BOSS else 15)
				flash[e[0]] = 0.1
				_sparks(e[2], 4, Color(1.6, 1.6, 2.0))
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
				_popup(p[2], "-%d" % roundi(old - p[3]), NEON_RED, 15)
				if id == my_id:
					shake = maxf(shake, 7.0)
					hurt = 0.35
	var mine = d.get("ps", {}).get(my_id)
	var old_me = snap.get("ps", {}).get(my_id)
	if mine != null and old_me != null:
		for res in mine[7]:
			var gain: int = mine[7][res] - old_me[7].get(res, 0)
			if gain > 0:
				_popup(mine[2], "+%d %s" % [gain, res], DROP_COL.get(res, Color.WHITE) * 1.6, 14)
	prev_hp.clear()
	prev_pos.clear()
	for e in d.get("en", []):
		prev_hp[e[0]] = e[3]
		prev_pos[e[0]] = e[2]
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
	var ph: String = snap.get("ph", "")
	var in_game := ph in ["day", "dusk", "night", "result"]
	menu_panel.visible = ph == ""
	lobby_panel.visible = ph == "lobby"
	banner.visible = in_game or ph == "lobby"
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
	cam.position = local_pos

	var me = snap.ps.get(my_id)
	var night := 0.0
	if ph == "night":
		night = 1.0
	elif ph == "dusk":
		night = 1.0 - snap.t / GameSim.DUSK
	tint.color = Color.WHITE.lerp(NIGHT_TINT, night)
	my_light.enabled = night > 0
	beacon.enabled = night > 0
	my_light.position = local_pos
	if me != null:  # FML-12: 4 tiles at night, Scout x1.3
		var r := 4.0 * T * (1.3 if me[1] == 0 else 1.0)
		my_light.texture_scale = lerpf(30.0 * T, r, night) * 2.0 / 256.0


func _lobby_ui() -> void:
	var lines := ["LOBBY   -   players join this machine's IP (UDP %d)" % PORT, ""]
	var eng := false
	for id in snap.ps:
		var p = snap.ps[id]
		eng = eng or p[1] == 2
		lines.append("%s %s - %s%s" % ["*" if id == snap.leader else " ", p[0], GameSim.ROLES[p[1]], "  (you)" if id == my_id else ""])
	lines.append("")
	lines.append("Mode: " + GameSim.MODES[snap.mode] + ("" if eng else "   - needs at least one Engineer"))
	if not snap.ps.has(my_id):
		lines.append("Lobby full or match running - you are watching.")
	lobby_text.text = "\n".join(PackedStringArray(lines))
	var leader: bool = my_id == snap.leader
	start_btn.visible = leader
	mode_opt.visible = leader
	if not mode_opt.has_focus():
		mode_opt.selected = snap.mode


# --- world drawing ------------------------------------------------------

func _draw() -> void:
	if not (snap.get("ph", "") in ["day", "dusk", "night", "result"]):
		return
	var font := ThemeDB.fallback_font
	var view := Rect2(local_pos - Vector2(560, 330), Vector2(1120, 660))
	draw_circle(Vector2.ZERO, GameSim.ISLAND + 6 * T, Color("7D6C50"))
	draw_circle(Vector2.ZERO, GameSim.ISLAND, Color("34432F"))
	var safe := _round_rect(GameSim.HALF, GameSim.SAFE_D)  # within 20 tiles of the nearest wall
	draw_colored_polygon(safe, Color("3D4C36"))
	draw_rect(Rect2(-GameSim.HALF - Vector2(2, 2) * T, (GameSim.HALF + Vector2(2, 2) * T) * 2), Color("44464F"))  # stone plaza
	var x0 := floorf(view.position.x / T) * T
	var y0 := floorf(view.position.y / T) * T
	for x in range(int(x0), int(view.end.x), int(T)):
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), Color(0, 0, 0, 0.1), 1)
	for y in range(int(y0), int(view.end.y), int(T)):
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), Color(0, 0, 0, 0.1), 1)
	safe.append(safe[0])
	draw_polyline(safe, Color(0.8, 1, 0.8, 0.15), 2)
	for d in deco:  # ponytail: cosmetic only, no collision yet
		if view.has_point(d[0]):
			_shadow(d[0], d[1])
			if d[2] == 0:
				_blob(d[0], d[1], Color("22332A"))
				draw_circle(d[0] + Vector2(-d[1] * 0.3, -d[1] * 0.3), d[1] * 0.45, Color("2D4334"))
			else:
				_blob(d[0], d[1], Color("4E525C"))
	for i in 3:  # landing pads
		var pp := GameSim.pad_pos(i)
		draw_circle(pp, GameSim.PAD_R, Color(0.2, 0.35, 0.9, 0.12))
		draw_arc(pp, GameSim.PAD_R, 0, TAU, 48, Color(0.4, 0.8, 2.0), 3)
		draw_string_outline(font, pp + Vector2(-8, 9), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 5, INK)
		draw_string(font, pp + Vector2(-8, 9), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.5, 0.8, 1.8))
	for nd in snap.nodes:
		if not view.has_point(nd[1]):
			continue
		var c: Color = RES_COL[nd[0]]
		var r: float = T * (0.25 + 0.05 * nd[2])
		if nd[2] <= 0:
			draw_circle(nd[1], T * 0.2, Color(0, 0, 0, 0.25))
			continue
		_shadow(nd[1], r)
		match nd[0]:
			0:
				_blob(nd[1], r, c)
				draw_arc(nd[1], r * 0.55, 0, TAU, 16, c.darkened(0.4), 2)
			1:
				_blob(nd[1], r, c)
				draw_circle(nd[1] + Vector2(-r * 0.3, -r * 0.3), r * 0.3, c.lightened(0.3))
			2:
				for o in [Vector2(-0.4, 0.1), Vector2(0.4, 0.1), Vector2(0, -0.35)]:
					_blob(nd[1] + o * r, r * 0.5, c)
			3:
				draw_rect(Rect2(nd[1] - Vector2(r, r) - Vector2(2, 2), Vector2(r, r) * 2 + Vector2(4, 4)), INK)
				draw_rect(Rect2(nd[1] - Vector2(r, r), Vector2(r, r) * 2), c)
	var tnow := Time.get_ticks_msec() / 1000.0
	for d in snap.get("drops", []):  # MEC-23: glow, bob, blink in the last 5 s
		if d[3] < 5.0 and fmod(tnow, 0.3) < 0.12:
			continue
		var dc: Color = DROP_COL.get(d[1], Color.WHITE)
		var dp: Vector2 = d[0] + Vector2(0, sin(tnow * 4.0 + d[0].x) * 3.0)
		draw_circle(dp, 12, Color(dc.r * 1.8, dc.g * 1.8, dc.b * 1.8, 0.3))
		_diamond(self, dp, 8, INK)
		_diamond(self, dp, 6, dc)
	# base and doors
	var h := GameSim.HALF
	draw_rect(Rect2(-h - Vector2(6, 6), (h + Vector2(6, 6)) * 2), INK)
	draw_rect(Rect2(-h, h * 2), Color("5B5F6B"))  # wall
	draw_rect(Rect2(-h + Vector2(12, 12), (h - Vector2(12, 12)) * 2), Color("6A6F7C"))  # floor
	for x in range(int(-h.x) + 12, int(h.x) - 12, int(T)):  # floor tiles
		draw_line(Vector2(x, -h.y + 12), Vector2(x, h.y - 12), Color(0, 0, 0, 0.12), 1)
	for y in range(int(-h.y) + 12, int(h.y) - 12, int(T)):
		draw_line(Vector2(-h.x + 12, y), Vector2(h.x - 12, y), Color(0, 0, 0, 0.12), 1)
	draw_rect(Rect2(-T * 0.7, T * 1.0, T * 1.4, T * 0.7), INK)
	draw_rect(Rect2(-T * 0.6, T * 1.05, T * 1.2, T * 0.55), Color("7A5634"))  # workbench
	draw_circle(Vector2.ZERO, T * 0.75, INK)
	draw_circle(Vector2.ZERO, T * 0.65, Color("F2B544"))
	draw_circle(Vector2.ZERO, T * 0.3, Color(2.2, 1.7, 0.7))  # beacon core glows
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for i in 3:
		var dp: Vector2 = GameSim.DOOR_POS[i]
		var dd: Vector2 = GameSim.DOOR_DIR[i]
		var along := Vector2(abs(dd.y), abs(dd.x))  # door runs along the wall
		var dsize := along * 2.4 * T + dd.abs() * (GameSim.WALL_IN + GameSim.WALL_OUT)
		var dc := dp - dd * (GameSim.WALL_IN - GameSim.WALL_OUT) / 2.0  # centre of the wall band
		var dur: float = snap.doors[i]
		var is_open: bool = snap.ph != "night" or dur <= 0
		var col := Color("8FA3B8") if dur > 250 else (Color("F2B544") if dur > 0 else Color("2A0E10"))
		if door_flash[i] > 0:
			col = col.lerp(Color(2, 2, 2), door_flash[i])
		if is_open:  # gap in the wall with two door posts
			draw_rect(Rect2(dc - dsize / 2, dsize), Color("6A6F7C") if dur > 0 else Color("2A0E10"))
			for sgn: float in [-1.0, 1.0]:
				var post := dc + along * sgn * (1.2 * T + 5)
				var ps := along * 10 + dd.abs() * (dsize.x if dd.x != 0 else dsize.y)
				draw_rect(Rect2(post - ps / 2 - Vector2(2, 2), ps + Vector2(4, 4)), INK)
				draw_rect(Rect2(post - ps / 2, ps), col)
		else:
			draw_rect(Rect2(dc - dsize / 2 - Vector2(3, 3), dsize + Vector2(6, 6)), INK)
			draw_rect(Rect2(dc - dsize / 2, dsize), col)
		if i in snap.active:
			var mc := dp + dd * 16
			draw_line(mc - along * 1.4 * T, mc + along * 1.4 * T, NEON_RED * (0.5 + 0.5 * pulse), 3)
		var lp: Vector2 = dp + dd * 1.5 * T + Vector2(-6, 7)
		draw_string_outline(font, lp, GameSim.DOOR_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, INK)
		draw_string(font, lp, GameSim.DOOR_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	for tl in snap.tele:  # boss telegraph: ring fills over 1 s
		draw_circle(tl[0], tl[1], Color(1.0, 0.1, 0.3, 0.16))
		draw_circle(tl[0], tl[1] * (1.0 - tl[2]), Color(1.0, 0.15, 0.3, 0.35))
		draw_arc(tl[0], tl[1], 0, TAU, 48, NEON_RED, 3)
	for e in snap.en:
		var pos: Vector2 = shown_e.get(e[0], e[2])
		if view.has_point(pos):
			_draw_enemy(e, pos)
	for b in snap.proj:
		draw_circle(b, 7, Color(1.6, 1.9, 0.4, 0.35))
		draw_circle(b, 3.5, Color(2.0, 2.2, 0.6))
	for id in snap.ps:
		var p = snap.ps[id]
		if p[5] != 2:
			_draw_player(id, p, local_pos if id == my_id else shown_p.get(id, p[2]), font)
	for f in fx:
		draw_circle(f.pos, f.r * f.life / f.max, f.col)


func _draw_enemy(e: Array, pos: Vector2) -> void:
	var r: float = e[5]
	var ty: int = e[1]
	var body: Color = [Color("5A3570"), Color("6B7A2A"), Color("3B2A44"), Color("4A2C5A")][ty]
	if flash.has(e[0]):
		body = Color(2.0, 2.0, 2.0)
	_shadow(pos, r)
	if ty == GameSim.WRECKER or ty == GameSim.BOSS:  # horns / crown spikes
		for s in ([-0.6, 0.6] if ty == GameSim.WRECKER else [-0.8, -0.4, 0.0, 0.4, 0.8]):
			var tip := pos + Vector2.from_angle(-PI / 2 + s) * r * 1.45
			var b1 := pos + Vector2.from_angle(-PI / 2 + s - 0.25) * r * 0.85
			var b2 := pos + Vector2.from_angle(-PI / 2 + s + 0.25) * r * 0.85
			draw_colored_polygon(PackedVector2Array([b1, tip, b2]), INK)
			draw_colored_polygon(PackedVector2Array([b1.lerp(pos, 0.1), tip.lerp(pos, 0.12), b2.lerp(pos, 0.1)]), Color("C63FA8"))
	_blob(pos, r, body)
	draw_arc(pos, r - 1.5, 0, TAU, 24, Color("D8E03A") if ty == GameSim.SPITTER else Color("C63FA8"), 2)
	# angry cartoon eyes
	for sx in [-1.0, 1.0]:
		var ep := pos + Vector2(sx * r * 0.33, -r * 0.1)
		draw_circle(ep, r * 0.22, Color("E8E3C8"))
		draw_circle(ep + Vector2(sx * -r * 0.04, r * 0.05), r * 0.1, INK)
		draw_line(ep + Vector2(sx * r * 0.25, -r * 0.36), ep + Vector2(-sx * r * 0.2, -r * 0.16), INK, maxf(2.0, r * 0.1))
	if e[3] < e[4] and ty != GameSim.BOSS:
		_bar(pos + Vector2(0, -r - 8), r * 2.2, e[3] / e[4], NEON_RED)


func _draw_player(id: int, p: Array, pos: Vector2, font: Font) -> void:
	var c: Color = ROLE_COL[p[1]]
	var r := T * 0.42
	var aim: float = p[12]
	_shadow(pos, r)
	if p[5] == 1:  # downed: lies flat
		draw_set_transform(pos, 0, Vector2(1.3, 0.6))
		draw_circle(Vector2.ZERO, r + 2.5, INK)
		draw_circle(Vector2.ZERO, r, c.darkened(0.5))
		draw_set_transform(Vector2.ZERO)
	else:
		var tip := pos + Vector2.from_angle(aim) * r * 1.6  # weapon
		draw_line(pos, tip, INK, 7)
		draw_line(pos, tip, Color("B9C2CC"), 3)
		_blob(pos, r, c)
		for sx in [-1.0, 1.0]:  # eyes look where you aim
			var ep := pos + Vector2(sx * r * 0.32, -r * 0.15)
			draw_circle(ep, r * 0.2, Color.WHITE)
			draw_circle(ep + Vector2.from_angle(aim) * r * 0.08, r * 0.1, INK)
		if p[1] == 1:  # Healer green plus (no red cross)
			draw_rect(Rect2(pos + Vector2(-2, r * 0.25), Vector2(4, 10)), Color("3DBE5A"))
			draw_rect(Rect2(pos + Vector2(-5, r * 0.25 + 3), Vector2(10, 4)), Color("3DBE5A"))
	if p[11]:  # melee slash
		draw_arc(pos, 1.35 * T, aim - PI / 4, aim + PI / 4, 16, NEON_CYAN, 5)
		draw_arc(pos, 1.1 * T, aim - PI / 5, aim + PI / 5, 12, Color(1.5, 1.5, 1.5, 0.6), 2)
	if p[20] > 0:
		draw_arc(pos, r + 13, -PI / 2, -PI / 2 + TAU * p[20] / 2.0, 24, Color(2.2, 1.6, 0.5), 4)
	var prog: float = p[14] if p[14] > 0 else (1.0 - p[13] / 2.0 if p[13] > 0 else p[21])
	if prog > 0:
		draw_arc(pos, r + 8, -PI / 2, -PI / 2 + TAU * prog, 24, Color(0.6, 2.0, 0.8), 3)
	if id != my_id:
		_bar(pos + Vector2(0, -r - 10), T, p[3] / p[4], Color("3DBE5A"))
	var label: String = p[0] + ("  DOWN %d" % p[6] if p[5] == 1 else "")
	var lp := pos + Vector2(-2 * T, -r - 16)
	draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 4 * T, 11, 4, INK)
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 4 * T, 11, NEON_RED if p[5] == 1 else Color.WHITE)


func _blob(pos: Vector2, r: float, col: Color) -> void:
	draw_circle(pos, r + 2.5, INK)
	draw_circle(pos, r, col)
	draw_circle(pos + Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1, 1, 1, 0.12))


func _shadow(pos: Vector2, r: float) -> void:
	draw_set_transform(pos + Vector2(0, r * 0.75), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
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

	# area name + phase
	_text(c, Vector2(12, 20), "LIGHTHOUSE OUTPOST", 13, GOLD)
	var tl := "%d:%02d" % [int(maxf(snap.t, 0)) / 60, int(maxf(snap.t, 0)) % 60]
	var phase_line: String = {"day": "DAY %d/5" % snap.k, "dusk": "DUSK", "night": "NIGHT %d/5" % snap.k, "result": "RESULT"}[ph]
	_text(c, Vector2(12, 38), "%s   %s" % [phase_line, tl], 16, Color.WHITE)
	if ph == "day":
		_text(c, Vector2(12, 54), "skip vote %d/%d  (V, after 3:00)" % [snap.votes, snap.need], 11, Color(1, 1, 1, 0.6))
	if snap.ext >= 0:
		_text(c, Vector2(12, 54), "EXTENSION %ds - hold a pad 10 s  %s" % [snap.ext, str(snap.pads.map(func(v): return snappedf(v, 0.1)))], 12, NEON_RED)

	# top centre: generator + doors
	var cx := vs.x / 2
	_panel(c, Rect2(cx - 160, 6, 320, 46))
	var gcol := Color("F2B544").lerp(Color(2.5, 0.5, 0.4), gen_flash / 0.4)
	_text(c, Vector2(cx - 150, 21), "GENERATOR", 11, GOLD)
	_text(c, Vector2(cx + 60, 21), "%d / 1000" % snap.base, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 90)
	c.draw_rect(Rect2(cx - 150, 25, 300, 7), INK)
	c.draw_rect(Rect2(cx - 150, 25, 300 * snap.base / 1000.0, 7), gcol)
	for i in 3:
		var r := Rect2(cx - 150 + i * 102, 36, 96, 12)
		var dur: float = snap.doors[i]
		var col := Color("8FA3B8") if dur > 250 else (Color("F2B544") if dur > 0 else NEON_RED)
		c.draw_rect(r, INK)
		c.draw_rect(Rect2(r.position + Vector2(14, 3), Vector2(78 * dur / 500.0, 6)), col)
		_text(c, r.position + Vector2(2, 11), GameSim.DOOR_NAMES[i], 11, Color.WHITE)
		if i in snap.active:
			c.draw_rect(r.grow(1), NEON_RED * (0.6 + 0.6 * pulse if door_flash[i] > 0 else 0.7), false, 1.5)

	# boss bar
	for e in snap.en:
		if e[1] == GameSim.BOSS:
			var br := Rect2(cx - 230, 66, 460, 10)
			_text(c, Vector2(cx - 230, 62), "NOX-01  JUGGERNAUT", 12, NEON_PINK, HORIZONTAL_ALIGNMENT_CENTER, 460)
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
	_text(c, Vector2(vs.x - 130, ry + 1), "DAMAGE", 10, GOLD)
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
	_text(c, hp_c + Vector2(-40, 8), str(int(me[3])), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 80)
	_text(c, hp_c + Vector2(-40, 24), "/%d" % me[4], 10, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 80)
	var small := [[Color("3B6FB0"), "%d%%" % int(GameSim.ARMOUR[me[9]] * 100)], [Color("2E8B4A"), str(me[7].bandage)]]
	if me[1] == 1:
		small.append([Color("3DBE5A"), "+%d" % me[10]])
	for i in small.size():
		var sc := Vector2(102 + i * 30, vs.y - 24)
		_hex(c, sc, 14, INK)
		_hex(c, sc, 12, small[i][0])
		_text(c, sc + Vector2(-15, 4), small[i][1], 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 30)
	_text(c, Vector2(92, vs.y - 44), GameSim.ROLES[me[1]].to_upper(), 12, ROLE_COL[me[1]])
	if me[5] != 0:
		_text(c, Vector2(0, vs.y / 2 + 40), "DOWN - %ds to bleed out" % me[6] if me[5] == 1 else "DEAD - waiting for a Revival kit", 18, NEON_RED, HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	# bottom right: weapon card
	var wr := Rect2(vs.x - 236, vs.y - 62, 228, 54)
	_panel(c, wr)
	_text(c, wr.position + Vector2(10, 18), GameSim.WEAPONS[me[8]], 14, Color.WHITE)
	for t in 3:
		_diamond(c, wr.position + Vector2(14 + t * 16, 34), 5, GOLD if t <= me[8] else Color(1, 1, 1, 0.15))
	_text(c, wr.position + Vector2(10, 48), "LMB hit  E use  Q bandage  C craft  F door (Eng)", 9, Color(1, 1, 1, 0.55))
	var hint: String = me[16]
	if hint == "" and ph in ["day", "dusk"] and me[5] == 0:
		for nd in snap.nodes:
			if nd[2] > 0 and local_pos.distance_to(nd[1]) <= 1.5 * T:
				var pct := int(me[21] * 100)
				hint = "Gathering %s... %d%%" % [GameSim.RES[nd[0]], pct] if me[21] > 0 else "Hold E (stand still) to gather %s - %d left" % [GameSim.RES[nd[0]], nd[2]]
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
		_text(c, Vector2(0, vs.y - 74), hint, 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	if craft_open:
		var cr := Rect2(vs.x - 300, 190, 290, 22 + GameSim.RECIPES.size() * 18)
		_panel(c, cr)
		_text(c, cr.position + Vector2(10, 16), "WORKBENCH  (number to craft, C close)", 11, GOLD)
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


func _text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_string_outline(font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.9 * col.a))
	ci.draw_string(font, pos, s, align, width, size, col)


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
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while deco.size() < 220:  # trees and rocks in the outer zone, off the door corridors (section 4.3)
		var pos := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, GameSim.ISLAND - 3 * T)
		if GameSim.wall_dist(pos) > GameSim.SAFE_D + 2 * T and not GameSim.in_door_lane(pos, 2.5 * T):
			deco.append([pos, rng.randf_range(0.6, 1.4) * T, 0 if rng.randf() < 0.8 else 1])


func _build_ui() -> void:
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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.add_child(menu_panel)
	center.add_child(lobby_panel)
	menu_panel.add_child(menu)
	lobby_panel.add_child(lobby)
	menu.custom_minimum_size = Vector2(280, 0)

	var title := Label.new()
	title.text = "HOLD 'TIL DAWN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	menu.add_child(title)
	var sub := Label.new()
	sub.text = "Hold the light for five nights."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(sub)
	name_edit.placeholder_text = "Your name"
	name_edit.text = "Player%d" % randi_range(1, 99)
	menu.add_child(name_edit)
	for opt in [role_opt, lobby_role]:
		for r in GameSim.ROLES:
			opt.add_item(r)
	role_opt.selected = 2
	menu.add_child(role_opt)
	ip_edit.text = "127.0.0.1"
	menu.add_child(ip_edit)
	var host_btn := Button.new()
	host_btn.text = "Host (server + play)"
	host_btn.pressed.connect(_host.bind(true))
	menu.add_child(host_btn)
	var join_btn := Button.new()
	join_btn.text = "Join by IP"
	join_btn.pressed.connect(_join)
	menu.add_child(join_btn)
	menu.add_child(status)

	lobby.add_child(lobby_text)
	lobby_role.item_selected.connect(func(i): _act("role", i))
	lobby.add_child(lobby_role)
	for m in GameSim.MODES:
		mode_opt.add_item(m)
	mode_opt.item_selected.connect(func(i): _act("mode", i))
	lobby.add_child(mode_opt)
	start_btn.text = "Start match"
	start_btn.pressed.connect(func(): _act("start"))
	lobby.add_child(start_btn)

	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 86
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 15)
	banner.add_theme_color_override("font_color", Color("F2B544"))
	banner.add_theme_constant_override("outline_size", 5)
	banner.add_theme_color_override("font_outline_color", INK)
	root.add_child(banner)


func _theme() -> Theme:
	var th := Theme.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(0.2, 0.15, 0.07, 0.95)
	for cls in ["Button", "OptionButton", "LineEdit"]:
		th.set_stylebox("normal", cls, sb)
		th.set_stylebox("focus", cls, hov)
		th.set_stylebox("hover", cls, hov)
		th.set_stylebox("pressed", cls, hov)
		th.set_color("font_hover_color", cls, GOLD)
	th.set_stylebox("panel", "PanelContainer", sb)
	th.default_font_size = 14
	return th


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
