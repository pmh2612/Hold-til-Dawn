class_name ResultScreen
extends Control
## Result screen (section 2.5): plays a full-screen Victory / Defeat intro animation first,
## then reveals the post-match stats table and Back to lobby button.
## Layout lives in ui/menu/result_screen.tscn.

const COLUMNS = [["PLAYER", 0.0], ["ROLE", 190.0], ["KILLS", 290.0], ["REVIVES", 360.0], ["DAMAGE", 440.0], ["TAKEN", 515.0]]
const ROW_H = 22.0
const INTRO_DURATION: float = 3.0
const STATS_FADE_TIME: float = 0.45
const SKIP_UNLOCK_TIME: float = 0.6

var main: Main
var shown_rows = null
var active: bool = false
var elapsed: float = 0.0
var win_state: bool = false
var cause_text: String = ""
var night_num: int = 1
var intro_layer: Control
var row_nodes: Array = []
var particles: Array = []
var box_base_top: float = -200.0
var box_base_bottom: float = 210.0
var stats_shown_at: float = INTRO_DURATION


func setup(host: Main) -> void:
	main = host
	HudLabels.style_title(%Title, main)
	HudLabels.style_text(%Cause, main)
	HudLabels.style_text(%Night, main)
	HudLabels.style_title(%Back, main)
	%Back.pressed.connect(func(): main.act("lobby"))
	box_base_top = $Box.offset_top
	box_base_bottom = $Box.offset_bottom
	intro_layer = Control.new()
	intro_layer.name = "IntroLayer"
	intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.draw.connect(_draw_intro)
	add_child(intro_layer)


func _gui_input(event: InputEvent) -> void:
	if not visible or not active:
		return
	if elapsed >= SKIP_UNLOCK_TIME and elapsed < stats_shown_at:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_skip_intro()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not active:
		return
	if elapsed >= SKIP_UNLOCK_TIME and elapsed < stats_shown_at:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_skip_intro()
			get_viewport().set_input_as_handled()


func _skip_intro() -> void:
	elapsed = stats_shown_at


func _init_particles(win: bool) -> void:
	particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 202605 if win else 202609
	for i in range(42):
		particles.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"vx": rng.randf_range(-0.04, 0.04),
			"vy": rng.randf_range(-0.22, -0.08) if win else rng.randf_range(0.06, 0.18),
			"sz": rng.randf_range(2.5, 6.0),
			"phase": rng.randf() * TAU,
			"tone": rng.randi_range(0, 2)
		})


func _style_box(win: bool) -> void:
	var border_c := Color(0.85098, 0.662745, 0.290196, 0.9) if win else Color(0.88, 0.24, 0.22, 0.9)
	var box_style: StyleBoxFlat = $Box.get_theme_stylebox("panel").duplicate()
	box_style.border_color = border_c
	$Box.add_theme_stylebox_override("panel", box_style)
	for st_name in ["normal", "hover", "pressed"]:
		var btn_s: StyleBoxFlat = %Back.get_theme_stylebox(st_name).duplicate()
		btn_s.border_color = border_c
		if not win and st_name != "normal":
			btn_s.bg_color = Color(0.88, 0.24, 0.22, 0.32)
		%Back.add_theme_stylebox_override(st_name, btn_s)


func _process(delta: float) -> void:
	if main == null:
		return
	var r = main.snap.get("result", null)
	var should_show: bool = main.snap.get("ph", "") == "result" and r != null
	visible = should_show
	if not visible:
		active = false
		elapsed = 0.0
		shown_rows = null
		row_nodes.clear()
		return
	var win: bool = bool(r[0])
	cause_text = Cs.s(r[1])
	night_num = int(r[2])
	if not active:
		active = true
		elapsed = 0.0
		win_state = win
		stats_shown_at = INTRO_DURATION
		_init_particles(win)
		_style_box(win)
		%Title.text = "VICTORY" if win else "DEFEAT"
		%Title.add_theme_color_override("font_color", Main.GOLD if win else Main.NEON_RED)
		%Cause.text = "MISSION COMPLETE" if win else "BEACON LOST"
		%Night.text = "Night %d / 5" % [night_num]
	elapsed += delta
	var rows = []
	for id in main.snap.ps:
		var p = main.snap.ps[id]
		rows.append([p[1], [p[0], GameSim.ROLES[p[1]], Cs.s(p[17]), Cs.s(p[28]), Cs.s(int(p[18])), Cs.s(int(p[29]))]])
	if rows != shown_rows:
		shown_rows = rows
		_fill_table(rows)
	# Dim backdrop transitions smoothly from cinematic framing to stats background.
	var dim_a: float = clampf(elapsed / 0.45, 0.0, 1.0) * (0.76 if elapsed < stats_shown_at else 0.74)
	$Dim.color = Color(0.05, 0.04, 0.02, dim_a) if win_state else Color(0.06, 0.01, 0.02, dim_a)
	var in_intro: bool = elapsed < stats_shown_at
	intro_layer.visible = elapsed < stats_shown_at + 0.35
	if intro_layer.visible:
		intro_layer.queue_redraw()
	if in_intro:
		$Box.visible = false
		$Box.modulate.a = 0.0
	else:
		var st: float = elapsed - stats_shown_at
		var k: float = ease(clampf(st / STATS_FADE_TIME, 0.0, 1.0), 0.3)
		$Box.visible = true
		$Box.modulate.a = k
		var lift: float = (1.0 - k) * 26.0
		$Box.offset_top = box_base_top + lift
		$Box.offset_bottom = box_base_bottom + lift
		# Cascade player stat rows smoothly after the panel opens.
		for ri in range(row_nodes.size()):
			var rk: float = ease(clampf((st - 0.12 - ri * 0.08) / 0.25, 0.0, 1.0), 0.35)
			for entry in row_nodes[ri]:
				var lbl: Label = entry[0]
				var base_x: float = float(entry[1])
				lbl.modulate.a = rk
				lbl.position.x = base_x - (1.0 - rk) * 14.0
		var back_k: float = clampf((st - 0.25) / 0.25, 0.0, 1.0)
		%Back.modulate.a = back_k
		%Back.disabled = back_k < 0.5


func _fill_table(rows) -> void:
	for child in %Table.get_children():
		child.queue_free()
	row_nodes.clear()
	for col in COLUMNS:
		_cell(col[0], Vector2(col[1], 18.0), 12, Main.GOLD, true)
	var y: float = 18.0
	for row in rows:
		y += ROW_H
		var group: Array = []
		for i in range(6):
			var lbl: Label = _cell(row[1][i], Vector2(COLUMNS[i][1], y), 12, Main.ROLE_COL[row[0]] if i == 1 else Color.WHITE, false)
			group.append([lbl, lbl.position.x])
		row_nodes.append(group)


# a table cell whose text baseline sits at `baseline` (as Main.text draws it)
func _cell(s, baseline: Vector2, size: int, col: Color, title: bool) -> Label:
	var l = Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if title:
		HudLabels.style_title(l, main)
	else:
		HudLabels.style_text(l, main)
	l.position = baseline - Vector2(0, l.get_theme_font("font").get_ascent(size))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Table.add_child(l)
	return l


func _draw_intro() -> void:
	if main == null or not active:
		return
	var vs: Vector2 = size
	if vs.x < 10.0 or vs.y < 10.0:
		return
	var t: float = elapsed
	var fade_in: float = clampf(t / 0.3, 0.0, 1.0)
	var fade_out: float = clampf((stats_shown_at - t) / 0.45, 0.0, 1.0)
	var master_a: float = fade_in * fade_out
	if master_a <= 0.001:
		return
	var center: Vector2 = vs * 0.5
	var lift_out: float = (1.0 - fade_out) * 30.0
	var shake := Vector2.ZERO
	if not win_state and t < 0.55:
		var sh: float = pow(1.0 - t / 0.55, 2.0) * 7.0
		shake = Vector2(sin(t * 78.0) * sh, cos(t * 92.0) * sh * 0.7)
	var origin: Vector2 = center - Vector2(0, 14.0 + lift_out) + shake

	# Cinematic top & bottom letterbox bars sliding into frame.
	var bar_h: float = 34.0 * ease(clampf(t / 0.35, 0.0, 1.0), 0.35) * fade_out
	var bar_col := Color(0.05, 0.04, 0.07, 0.94 * fade_out)
	var trim_col := Color(Main.GOLD, 0.85 * master_a) if win_state else Color(0.88, 0.22, 0.2, 0.85 * master_a)
	intro_layer.draw_rect(Rect2(0, 0, vs.x, bar_h), bar_col)
	intro_layer.draw_rect(Rect2(0, vs.y - bar_h, vs.x, bar_h), bar_col)
	if bar_h > 2.0:
		intro_layer.draw_line(Vector2(0, bar_h), Vector2(vs.x, bar_h), trim_col, 2.0)
		intro_layer.draw_line(Vector2(0, vs.y - bar_h), Vector2(vs.x, vs.y - bar_h), trim_col, 2.0)

	if win_state:
		_draw_victory_backdrop(vs, origin, t, master_a)
	else:
		_draw_defeat_backdrop(vs, origin, t, master_a)

	# Ambient rising golden sparks (Victory) or falling crimson ash (Defeat).
	for pt in particles:
		var px: float = fposmod(float(pt.x) + float(pt.vx) * t + sin(t * 2.0 + float(pt.phase)) * 0.01, 1.0) * vs.x
		var py: float = fposmod(float(pt.y) + float(pt.vy) * t, 1.0) * vs.y
		var flicker: float = 0.55 + 0.45 * sin(t * 7.0 + float(pt.phase))
		var sz: float = float(pt.sz)
		var col: Color
		if win_state:
			col = [Color("FFF4C2"), Color("F2C24F"), Color("D98E2B")][int(pt.tone)]
		else:
			col = [Color("FF5A42"), Color("B8252A"), Color("3A242B")][int(pt.tone)]
		col.a = 0.82 * flicker * master_a
		intro_layer.draw_rect(Rect2(Vector2(px, py).round() - Vector2.ONE * (sz * 0.5), Vector2(sz, sz)), col)

	# Central hexagonal Beacon Emblem (triumphant radiant crest vs cracked dark core).
	var crest_y: float = origin.y - 84.0
	var crest_pos := Vector2(origin.x, crest_y)
	var crest_k: float = clampf((t - 0.12) / 0.42, 0.0, 1.0)
	if crest_k > 0.0:
		var crest_sc: float = _overshoot(crest_k)
		if win_state:
			_draw_victory_crest(crest_pos, crest_sc, t, master_a)
		else:
			_draw_defeat_crest(crest_pos, crest_sc, t, master_a)

	# Expanding horizontal accent band + twin divider lines with diamond tips.
	var rule_k: float = ease(clampf((t - 0.28) / 0.45, 0.0, 1.0), 0.3)
	var half_w: float = 235.0 * rule_k
	var band_y: float = origin.y + 8.0
	if rule_k > 0.02:
		var band_bg := Color(0.06, 0.05, 0.08, 0.72 * master_a * rule_k)
		intro_layer.draw_rect(Rect2(origin.x - half_w - 24.0, band_y - 48.0, (half_w + 24.0) * 2.0, 86.0), band_bg)
		for dy in [-48.0, 38.0]:
			var ly: float = band_y + dy
			intro_layer.draw_line(Vector2(origin.x - half_w, ly), Vector2(origin.x + half_w, ly), Main.INK, 4.0)
			intro_layer.draw_line(Vector2(origin.x - half_w, ly), Vector2(origin.x + half_w, ly), trim_col, 2.0)
			for side in [-1.0, 1.0]:
				var dp := Vector2(origin.x + side * (half_w + 6.0), ly)
				intro_layer.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -5), dp + Vector2(5, 0), dp + Vector2(0, 5), dp + Vector2(-5, 0)]), trim_col)

	# Giant VICTORY / DEFEAT headline with spring slam & metallic sheen.
	var title_k: float = clampf((t - 0.25) / 0.4, 0.0, 1.0)
	if title_k > 0.0:
		var word: String = "VICTORY" if win_state else "DEFEAT"
		var f_title: Font = main.font_title
		var fsize: int = 62
		var sc: float = lerpf(1.55, 1.0, ease(title_k, 0.25)) if win_state else lerpf(1.38, 1.0, ease(title_k, 0.2))
		var drop: float = (1.0 - ease(title_k, 0.25)) * (-26.0 if not win_state else 16.0)
		var ta: float = clampf(title_k * 2.4, 0.0, 1.0) * master_a
		var t_col := Color("FFD66B", ta) if win_state else Color("F24138", ta)
		if win_state and t > 0.75:
			var sheen: float = maxf(0.0, 1.0 - absf(t - 1.25) * 3.0)
			t_col = t_col.lerp(Color("FFFCE0", ta), sheen * 0.65)
		var t_sz: Vector2 = f_title.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var ascent: float = f_title.get_ascent(fsize)
		intro_layer.draw_set_transform(Vector2(origin.x, band_y - 2.0 + drop), 0.0, Vector2(sc, sc))
		var base_pt := Vector2(-t_sz.x * 0.5, ascent * 0.36)
		intro_layer.draw_string_outline(f_title, base_pt + Vector2(0, 3), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 8, Color(Main.INK, 0.95 * ta))
		intro_layer.draw_string(f_title, base_pt, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, t_col)
		intro_layer.draw_set_transform(Vector2.ZERO)

	# Subtitle (MISSION COMPLETE / BEACON LOST + cause + night count).
	var sub_k: float = ease(clampf((t - 0.72) / 0.45, 0.0, 1.0), 0.35)
	if sub_k > 0.0:
		var sa: float = sub_k * master_a
		var sub_y: float = band_y + 66.0 + (1.0 - sub_k) * 12.0
		var sub_head: String = "MISSION COMPLETE" if win_state else "BEACON LOST"
		var sub_col := Color(Main.GOLD, sa) if win_state else Color("FF7A6E", sa)
		main.text(intro_layer, Vector2(0, sub_y), sub_head, 18, sub_col, 1, vs.x, true)
		main.text(intro_layer, Vector2(0, sub_y + 24.0), "NIGHT %d / 5" % [night_num], 12, Color(0.92, 0.92, 0.95, 0.88 * sa), 1, vs.x, false)

	# Gentle skip hint once the reveal lands.
	if t >= 1.0 and t < stats_shown_at - 0.3:
		var hint_a: float = clampf((t - 1.0) / 0.4, 0.0, 1.0) * fade_out * (0.5 + 0.3 * sin(t * 4.5))
		main.text(intro_layer, Vector2(0, vs.y - bar_h - 14.0), "CLICK OR PRESS SPACE FOR STATS", 11, Color(1.0, 1.0, 1.0, hint_a), 1, vs.x, false)


func _draw_victory_backdrop(vs: Vector2, origin: Vector2, t: float, master_a: float) -> void:
	# Radiant rotating dawn light shafts behind the victory emblem.
	var ray_origin := origin - Vector2(0, 62.0)
	var ray_len: float = vs.length() * 0.65
	var rays: int = 12
	var spin: float = t * 0.18
	for i in range(rays):
		var a0: float = spin + float(i) * TAU / float(rays)
		var a1: float = a0 + TAU / float(rays) * 0.42
		var p1: Vector2 = ray_origin + Vector2.from_angle(a0) * ray_len
		var p2: Vector2 = ray_origin + Vector2.from_angle(a1) * ray_len
		var alpha: float = (0.09 if i % 2 == 0 else 0.05) * master_a
		intro_layer.draw_colored_polygon(PackedVector2Array([ray_origin, p1, p2]), Color(1.0, 0.84, 0.4, alpha))
	# Warm sunrise pulse rings expanding on impact.
	if t < 1.3:
		var rk: float = clampf((t - 0.15) / 1.05, 0.0, 1.0)
		if rk > 0.0:
			var r_ring: float = lerpf(32.0, 320.0, ease(rk, 0.35))
			intro_layer.draw_arc(ray_origin, r_ring, 0, TAU, 48, Color(1.0, 0.86, 0.42, (1.0 - rk) * 0.65 * master_a), 3.0)
	# Initial warm flash right when Victory triggers.
	if t < 0.45:
		var fl: float = pow(1.0 - t / 0.45, 2.0)
		intro_layer.draw_rect(Rect2(Vector2.ZERO, vs), Color(1.0, 0.9, 0.58, fl * 0.36))


func _draw_defeat_backdrop(vs: Vector2, origin: Vector2, t: float, master_a: float) -> void:
	# Heavy crimson vignette pulse along screen edges.
	var pulse: float = 0.72 + 0.28 * sin(t * 3.8)
	var edge: float = 36.0
	var edge_col := Color(0.75, 0.06, 0.08, 0.32 * pulse * master_a)
	for rect in [Rect2(0, 0, vs.x, edge), Rect2(0, vs.y - edge, vs.x, edge), Rect2(0, 0, edge, vs.y), Rect2(vs.x - edge, 0, edge, vs.y)]:
		intro_layer.draw_rect(rect, edge_col)
	# Crimson shockwave ring snapping outward from the broken beacon.
	var crack_c := origin - Vector2(0, 62.0)
	if t < 1.1:
		var rk: float = clampf((t - 0.12) / 0.85, 0.0, 1.0)
		if rk > 0.0:
			var r_ring: float = lerpf(28.0, 260.0, ease(rk, 0.3))
			intro_layer.draw_arc(crack_c, r_ring, 0, TAU, 36, Color(0.95, 0.18, 0.18, (1.0 - rk) * 0.6 * master_a), 3.0)
	# Dramatic blood-red hit flash right on Defeat trigger.
	if t < 0.5:
		var fl: float = pow(1.0 - t / 0.5, 2.0)
		intro_layer.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.85, 0.08, 0.08, fl * 0.42))


func _draw_victory_crest(c: Vector2, sc: float, t: float, a: float) -> void:
	var r: float = 36.0 * sc
	intro_layer.draw_circle(c, r * 1.45, Color(1.0, 0.82, 0.35, 0.16 * a))
	_draw_hex(c, r + 5.0, Color(Main.INK, a))
	_draw_hex(c, r + 2.0, Color("FFD86B", a))
	_draw_hex(c, r - 3.0, Color(Main.INK, a))
	_draw_hex(c, r - 6.0, Color("D98E2B", a))
	# Inner 4-point beacon star gleaming at the center.
	var glow_p: float = 0.88 + 0.12 * sin(t * 8.0)
	var sr: float = 20.0 * sc * glow_p
	var sw: float = 6.5 * sc
	var star := PackedVector2Array([
		c + Vector2(0, -sr), c + Vector2(sw, -sw),
		c + Vector2(sr, 0), c + Vector2(sw, sw),
		c + Vector2(0, sr), c + Vector2(-sw, sw),
		c + Vector2(-sr, 0), c + Vector2(-sw, -sw)
	])
	intro_layer.draw_colored_polygon(star, Color("FFF8D6", a))


func _draw_defeat_crest(c: Vector2, sc: float, t: float, a: float) -> void:
	var split_k: float = ease(clampf((t - 0.38) / 0.55, 0.0, 1.0), 0.35)
	var gap: float = split_k * 8.0
	var r: float = 36.0 * sc
	intro_layer.draw_circle(c, r * 1.35, Color(0.85, 0.12, 0.12, 0.18 * a))
	# Left & right fractured halves of the shattered Beacon hex.
	for side in [-1.0, 1.0]:
		var off := Vector2(side * gap, side * split_k * 2.5)
		var pts := PackedVector2Array()
		var start_i: int = 3 if side < 0.0 else 0
		for j in range(4):
			var ang: float = -PI * 0.5 + float((start_i + j) % 6) * (TAU / 6.0)
			pts.append(c + off + Vector2.from_angle(ang) * (r + 3.0))
		intro_layer.draw_colored_polygon(pts, Color(Main.INK, a))
		var inner := PackedVector2Array()
		for j in range(4):
			var ang: float = -PI * 0.5 + float((start_i + j) % 6) * (TAU / 6.0)
			inner.append(c + off + Vector2.from_angle(ang) * (r - 2.0))
		intro_layer.draw_colored_polygon(inner, Color("8C1B20", a))
		var core := PackedVector2Array()
		for j in range(4):
			var ang: float = -PI * 0.5 + float((start_i + j) % 6) * (TAU / 6.0)
			core.append(c + off + Vector2.from_angle(ang) * (r - 7.0))
		intro_layer.draw_colored_polygon(core, Color("2B1117", a))
	# Glowing crimson fracture lightning down the split.
	var crack := PackedVector2Array([
		c + Vector2(-2, -r * 0.95), c + Vector2(6, -r * 0.35),
		c + Vector2(-5, r * 0.1), c + Vector2(5, r * 0.55), c + Vector2(-1, r * 0.95)
	])
	intro_layer.draw_polyline(crack, Color(Main.INK, a), 5.0)
	intro_layer.draw_polyline(crack, Color("FF5244", (0.75 + 0.25 * sin(t * 14.0)) * a), 2.4)


func _draw_hex(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		pts.append(c + Vector2.from_angle(-PI * 0.5 + float(i) * (TAU / 6.0)) * r)
	intro_layer.draw_colored_polygon(pts, col)


static func _overshoot(k: float) -> float:
	if k < 0.7:
		return lerpf(0.25, 1.12, ease(k / 0.7, 0.35))
	return lerpf(1.12, 1.0, (k - 0.7) / 0.3)
