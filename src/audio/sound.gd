class_name Sound
extends Node

# Sound for Main (main.gd). Effects, ambience and music are WAVs in art/sfx made by tools/sound_gen.gd (replace any
# of them with a recorded file of the same name). They are played from snapshot diffs, the same way Main.on_snap
# derives hit popups, so the network carries nothing extra. World sounds are positional (AudioStreamPlayer2D,
# heard up to HEAR_TILES from the camera); UI, phase changes and your own hurt / downed sounds are flat. Day and
# night ambience loop underneath and cross-fade with the phase, and so does the music (day theme, night theme,
# plus a drum layer synced to the night theme while a boss is up). Harvest strikes come from NodeBreakView.
# Adapted from branch sound (63e8bde) for demo1's modular client and native pause scene.
# Volumes: three sliders in the pause overlay, saved to user://audio.cfg.

const HEAR_TILES := 24.0
const AUDIO_CFG := "user://audio.cfg"
const SFX_DIR := "res://art/sfx/"
# bus 0 is Master; Sfx and Music are added at start-up
const BUS := ["Master", "Sfx", "Music"]
const BUS_LABEL := ["MASTER", "EFFECTS", "MUSIC"]
# minimum seconds between two plays of the same sound (anything not listed: 0.03 s)
const GAP := {"gen_hit": 0.35, "door_hit": 0.22, "repair": 0.18, "growl": 0.12, "hurt": 0.1, "my_hurt": 0.15,
	"pickup": 0.06, "step": 0.12, "tower_zap": 0.08, "ping": 0.4}

var m: Main
var config_path := AUDIO_CFG
var volume := [0.7, 1.0, 0.6]
var sounds := {}
var sound_last := {}
# tower beams hurt every tick: at most one hit sound per enemy every 0.2 s
var enemy_hit_last := {}
var tower_zap_last := {}
var world_voices: Array[AudioStreamPlayer2D] = []
var flat_voices: Array[AudioStreamPlayer] = []
var world_next := 0
var flat_next := 0
var day_amb: AudioStreamPlayer
var night_amb: AudioStreamPlayer
var day_music: AudioStreamPlayer
var night_music: AudioStreamPlayer
var boss_music: AudioStreamPlayer
var step_from := Vector2.ZERO
var step_acc := 0.0
var panels_were := ""


func setup(main: Main) -> void:
	m = main
	for i in range(1, BUS.size()):
		if AudioServer.get_bus_index(BUS[i]) >= 0:
			continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS[i])
	var cfg := ConfigFile.new()
	if cfg.load(config_path) == OK:
		for i in BUS.size():
			volume[i] = clampf(float(cfg.get_value("volume", BUS[i], volume[i])), 0.0, 1.0)
	for i in BUS.size():
		apply_volume(i)
	for f in DirAccess.get_files_at(SFX_DIR):
		# exported games list the .import files, the editor the .wav files
		var name := f.trim_suffix(".import")
		if name.ends_with(".wav") and not sounds.has(name.get_basename()):
			sounds[name.get_basename()] = load(SFX_DIR + name)
	for i in 32:
		var v := AudioStreamPlayer2D.new()
		v.max_distance = HEAR_TILES * GameSim.T
		v.attenuation = 1.6
		v.bus = "Sfx"
		add_child(v)
		world_voices.append(v)
	for i in 10:
		var v := AudioStreamPlayer.new()
		v.bus = "Sfx"
		add_child(v)
		flat_voices.append(v)
	day_amb = make_loop("amb_day", "Sfx")
	night_amb = make_loop("amb_night", "Sfx")
	day_music = make_loop("music_day", "Music")
	# started together and the same length, so the boss drums stay on the night theme's beat
	night_music = make_loop("music_night", "Music")
	boss_music = make_loop("music_boss", "Music")
	# every Godot button in the menus and lobby clicks, including ones made after this
	get_tree().node_added.connect(func(n):
		if n is BaseButton:
			n.pressed.connect(func(): sfx("ui_click")))


func make_loop(name: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = sounds.get(name)
	p.volume_db = -80.0
	p.bus = bus
	add_child(p)
	if p.stream != null:
		p.play()
	return p


# at == null plays flat (UI, your own body); otherwise at that world position
func sfx(name: String, at = null, db := 0.0, pitch_jitter := 0.06) -> void:
	if m == null or world_voices.is_empty() or flat_voices.is_empty():
		return
	var stream = sounds.get(name)
	if stream == null:
		return
	var now := float(m.clock)
	if now - sound_last.get(name, -9.0) < GAP.get(name, 0.03):
		return
	if at != null and Vector2(at).distance_squared_to(m.cam.position) > pow(HEAR_TILES * GameSim.T, 2):
		return
	sound_last[name] = now
	var pitch := 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if at != null:
		var v := world_voices[world_next]
		world_next = (world_next + 1) % world_voices.size()
		v.stream = stream
		v.global_position = at
		v.volume_db = db
		v.pitch_scale = pitch
		v.play()
	else:
		var v := flat_voices[flat_next]
		flat_next = (flat_next + 1) % flat_voices.size()
		v.stream = stream
		v.volume_db = db
		v.pitch_scale = pitch
		v.play()


# once per frame: ambience and music mix, your footsteps, panel open/close clicks
func tick(dt: float) -> void:
	if m == null:
		return
	var ph: String = m.snap.get("ph", "")
	var boss: bool = ph == "night" and m.snap.get("en", []).any(func(e): return e[1] == GameSim.BOSS)
	var day: float = {"day": 1.0, "dusk": 0.6, "": 0.5, "lobby": 0.5}.get(ph, 0.0)
	var night: float = {"night": 1.0, "dusk": 0.35}.get(ph, 0.0)
	fade(day_amb, day * 0.55, dt * 0.8)
	fade(night_amb, night * 0.6, dt * 0.8)
	fade(day_music, {"day": 0.45, "dusk": 0.2, "": 0.4, "lobby": 0.4}.get(ph, 0.0), dt * 0.5)
	fade(night_music, {"night": 0.5, "dusk": 0.15}.get(ph, 0.0), dt * 0.5)
	fade(boss_music, 0.65 if boss else 0.0, dt * (1.5 if boss else 0.4))

	var me = m.snap.get("ps", {}).get(m.my_id)
	var walking: bool = me != null and int(me[5]) == 0 and ph in ["day", "dusk", "night"] and not m.pause_menu.paused
	var here: Vector2 = m.local_pos
	var moved := here.distance_to(step_from) if walking else 0.0
	step_from = here
	if moved > 0.2 and moved < GameSim.T:
		step_acc += moved
		if step_acc > 0.85 * GameSim.T:
			step_acc = 0.0
			sfx("step", null, -14.0, 0.15)

	var panels := "%s%s%s%s%s" % [bool(m.inventory.bag_open), bool(m.craft_open), bool(m.build_menu.build_open), bool(m.minimap.map_big), bool(m.pause_menu.paused)]
	if panels_were != "" and panels != panels_were:
		var flags := [m.inventory.bag_open, m.craft_open, m.build_menu.build_open, m.minimap.map_big, m.pause_menu.paused]
		sfx("ui_open" if flags.any(func(v): return v) else "ui_close", null, -6.0)
	panels_were = panels


static func fade(p: AudioStreamPlayer, to: float, rate: float) -> void:
	var now := db_to_linear(p.volume_db)
	p.volume_db = linear_to_db(lerpf(now, to, minf(1.0, rate)) + 0.0001)


func apply_volume(i: int) -> void:
	var bus := AudioServer.get_bus_index(BUS[i])
	AudioServer.set_bus_volume_db(bus, -80.0 if volume[i] <= 0.001 else linear_to_db(volume[i]))
	AudioServer.set_bus_mute(bus, volume[i] <= 0.001)


# Native sliders in PauseScreen call this; no separate mouse capture or drawing layer.
func set_volume(i: int, value: float) -> void:
	volume[i] = clampf(value, 0.0, 1.0)
	apply_volume(i)
	var cfg := ConfigFile.new()
	for j in BUS.size():
		cfg.set_value("volume", BUS[j], volume[j])
	cfg.save(config_path)


# stage 0 a tool strike, 1 a unit taken, 2 the node used up
func harvest(type: int, pos: Vector2, stage: int) -> void:
	var name: String = "crumble" if stage == 2 else {0: "chop", 2: "herb"}.get(type, "mine")
	sfx(name, pos, -4.0 if stage == 0 else 0.0, 0.1)


# --- events from snapshot diffs (called by Main.on_snap before snap is replaced) ---
func from_snap(d) -> void:
	if m == null:
		return
	var old = m.snap
	var ph: String = d.get("ph", "")
	var old_ph: String = old.get("ph", "")
	if ph != old_ph:
		enemy_hit_last.clear()
		tower_zap_last.clear()
		phase_sound(ph, old_ph, d)
		return
	if not ph in ["day", "dusk", "night"] or d.get("k") != old.get("k"):
		return
	var now := float(m.clock)

	# enemies: hurt, rooted / stunned, attack wind-up, appear (boss roar), gone
	var old_en := {}
	for e in old.get("en", []):
		old_en[e[0]] = e
	var seen := {}
	for e in d.get("en", []):
		var id = e[0]
		seen[id] = true
		var pos: Vector2 = e[2]
		var is_boss: bool = e[1] == GameSim.BOSS
		var o = old_en.get(id)
		if o == null:
			if is_boss:
				sfx("boss_roar", pos, 4.0, 0.02)
			continue
		if e[3] < o[3] and now - enemy_hit_last.get(id, -9.0) > 0.2:
			enemy_hit_last[id] = now
			sfx("hit_boss" if is_boss else "hit", pos, -2.0)
		# rooted by a vine trap or stunned by the maul
		if e[10] and not o[10]:
			sfx("snare", pos, -3.0)
		if e[9] and not o[9]:
			sfx("boss_swing" if is_boss else ("wrecker_atk" if e[1] == GameSim.WRECKER else "growl"), pos, 2.0 if is_boss else -5.0)
	for id in old_en:
		if seen.has(id):
			continue
		enemy_hit_last.erase(id)
		var o = old_en[id]
		sfx("boss_die" if o[1] == GameSim.BOSS else "enemy_die", o[2], -2.0)

	# new spit and boss telegraphs are appended at the end of their lists
	var proj = d.get("proj", [])
	for i in range(old.get("proj", []).size(), proj.size()):
		sfx("spit", proj[i][0], -4.0)
	var tele = d.get("tele", [])
	for i in range(old.get("tele", []).size(), tele.size()):
		sfx("boss_warn", tele[i][0], 0.0, 0.02)

	# tactical areas and vine traps: [kind, pos, seconds left, owner]
	var old_tac := {}
	for a in old.get("tactical", []):
		old_tac[str(a[0]) + str(a[1])] = true
	for a in d.get("tactical", []):
		if old_tac.has(str(a[0]) + str(a[1])):
			continue
		match str(a[0]):
			"blast": sfx("explode", a[1], 2.0)
			"poison": sfx("poison", a[1], -3.0)
			"heal": sfx("heal_zone", a[1], -3.0)
			"trap": sfx("trap_set", a[1], -3.0)

	# players: downed / died / back up, hurt, attacks, flasks, haste, crafts, chests
	var arrows = d.get("arrows", [])
	var old_ps = old.get("ps", {})
	for id in d.ps:
		var p = d.ps[id]
		var o = old_ps.get(id)
		if o == null:
			continue
		var mine: bool = id == m.my_id
		var at = null if mine else p[2]
		if int(p[5]) != int(o[5]):
			sfx("downed" if p[5] == 1 else ("death" if p[5] == 2 else "revive"), at, 0.0 if mine else -3.0, 0.0)
		elif p[3] < o[3]:
			sfx("my_hurt" if mine else "hurt", at, -2.0 if mine else -6.0)
		if p[11] and not o[11]:
			var shot := false
			for a in arrows:
				if Vector2(a[0]).distance_to(p[2]) < 1.5 * GameSim.T:
					shot = true
					break
			sfx("bow" if shot else "swing", at, -4.0 if mine else -8.0)
		if int(p[10]) < int(o[10]):
			sfx("flask", at, -4.0)
		if p[30] and not o[30]:
			sfx("haste", at, -3.0)
		if int(o[26]) >= 0 and int(p[26]) < 0 and float(o[27]) >= 0.85:
			sfx("craft_done", at, -3.0, 0.0)
		if p.size() > 35 and int(p[35]) > int(o[35]) and int(p[32]) >= 0:
			sfx("chest_open", at, -3.0)
		if int(p[28]) > int(o[28]):
			sfx("revive", at, -3.0, 0.0)

	# your bag filling up (gathered units, drops, chest loot)
	var me_new = d.ps.get(m.my_id)
	var me_old = old_ps.get(m.my_id)
	if me_new != null and me_old != null:
		for res in ["wood", "stone", "herb", "titanium", "bandage", "arrow"]:
			if InventoryUi.carried(me_new, res) > InventoryUi.carried(me_old, res):
				sfx("pickup", null, -10.0, 0.1)
				break

	# base: generator and doors hit, doors repaired
	if d.get("base", 0) < old.get("base", 0):
		sfx("gen_hit", Vector2.ZERO)
	for i in 3:
		if d.doors[i] < old.doors[i]:
			sfx("door_hit", GameSim.DOOR_POS[i], -2.0)
		elif d.doors[i] > old.doors[i]:
			sfx("repair", GameSim.DOOR_POS[i], -6.0)

	# walls and towers going up / coming down; towers firing
	var walls = d.get("walls", [])
	var old_walls: int = old.get("walls", []).size()
	var tw = d.get("tw", [])
	if walls.size() > old_walls:
		sfx("build", walls[-1][0])
	elif walls.size() < old_walls:
		sfx("crumble", null, -8.0)
	if tw.size() > old.get("tw", []).size():
		sfx("build", tw[-1][1])
	for t in tw:
		if t[4] and now - tower_zap_last.get(t[0], -9.0) > 0.45:
			tower_zap_last[t[0]] = now
			sfx("tower_zap", t[1], -10.0, 0.1)

	# a new radio line or vote
	var msg: String = d.get("msg", "")
	if msg != "" and msg != old.get("msg", ""):
		sfx("ping", null, -12.0, 0.0)
	if d.get("votes", 0) != old.get("votes", 0):
		sfx("ui_click", null, -4.0, 0.0)


func phase_sound(ph: String, old_ph: String, d) -> void:
	match ph:
		"day": sfx("start" if old_ph == "lobby" else "dawn", null, -2.0, 0.0)
		"dusk": sfx("dusk_horn", null, -2.0, 0.0)
		"night": sfx("night_gong", null, 0.0, 0.0)
		"result":
			var r = d.get("result")
			sfx("win" if r != null and r[0] else "lose", null, 0.0, 0.0)
