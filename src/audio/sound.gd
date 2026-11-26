class_name Sound
extends Node

# Assets are prepared offline. The client consumes bounded event IDs, blends two music voices
# and reuses fixed pools. No synthesis, file scanning or player allocation happens during combat.
const AUDIO_CFG := "user://audio.cfg"
const CATALOG := "res://art/audio/catalog.json"
const HEAR_TILES := 24.0
const BUS := ["Master", "Sfx", "Music"]
const BUS_LABEL := ["MASTER", "EFFECTS", "MUSIC"]
const GAP := {"gen_hit": .3, "door_hit": .18, "door_crack": .25, "repair": .22,
	"growl": .12, "hit": .08, "hit_boss": .12, "pickup": .09, "tower_zap": .12,
	"ui_hover": .09, "ping": .5, "breach": 1., "base_alarm": 6.}
const MUSIC_GAIN := {"menu": .65, "day": .7, "night_early": .8, "night_late": .85,
	"boss": 1., "final": .9, "win": .8, "loss": .8}

var m: Main
var config_path := AUDIO_CFG
var volume := [.7, 1., .6]
var sounds := {}
var variants := {}
var variant_last := {}
var catalog := {}
var sound_last := {}
var emitter_last := {}
var enemy_hit_last := {}
var tower_zap_last := {}
var world_voices: Array[AudioStreamPlayer2D] = []
var flat_voices: Array[AudioStreamPlayer] = []
var world_priority: Array[int] = []
var flat_priority: Array[int] = []
var world_next := 0
var flat_next := 0
var music_voices: Array[AudioStreamPlayer] = []
var music_names := ["", ""]
var music_target := -1
var current_music := ""
var music_duck_until := 0.
var ambient := {}
var environment := {}
var environment_left := 0.
var channels: Array[AudioStreamPlayer2D] = []
var channel_owners := [0, 0, 0]
var channel_names := ["", "", ""]
var channel_streams := {}
var heartbeat: AudioStreamPlayer
var last_event_sequence := 0
var step_from := Vector2.ZERO
var step_acc := 0.
var other_steps := {}
var panels_were := ""

func setup(main: Main) -> void:
	m = main
	for i in range(1, BUS.size()):
		if AudioServer.get_bus_index(BUS[i]) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS[i])
	var cfg := ConfigFile.new()
	if cfg.load(config_path) == OK:
		for i in BUS.size():
			volume[i] = clampf(float(cfg.get_value("volume", BUS[i], volume[i])), 0., 1.)
	for i in BUS.size():
		apply_volume(i)
	var limited := false
	for i in range(AudioServer.get_bus_effect_count(0)):
		limited = limited or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	if not limited:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -.8
		limiter.release = .08
		AudioServer.add_bus_effect(0, limiter)
	catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for cue in catalog.effects:
		var streams: Array = []
		for path in catalog.effects[cue]:
			streams.append(load(path))
		variants[cue] = streams
		sounds[cue] = streams[0]
	for cue in catalog.loops:
		sounds[cue] = load(catalog.loops[cue])
		ambient[cue] = make_loop(cue)
	for cue in catalog.music:
		var stream: AudioStreamOggVorbis = load(catalog.music[cue].path)
		stream.loop = bool(catalog.music[cue].loop)
		sounds["music_" + cue] = stream
	for i in 32:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = HEAR_TILES * GameSim.T
		p.attenuation = 1.4
		p.bus = "Sfx"
		add_child(p)
		world_voices.append(p)
		world_priority.append(0)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		flat_voices.append(p)
		flat_priority.append(0)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80
		add_child(p)
		music_voices.append(p)
	for cue in catalog.channels:
		var stream: AudioStreamWAV = sounds[cue].duplicate()
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		channel_streams[cue] = stream
	for i in 3:
		var p := AudioStreamPlayer2D.new()
		p.bus = "Sfx"
		p.max_distance = 10 * GameSim.T
		p.attenuation = 1.6
		p.volume_db = -11
		add_child(p)
		channels.append(p)
	heartbeat = make_loop("heartbeat")
	get_tree().node_added.connect(bind_button)
	select_music("menu")

func bind_button(n: Node) -> void:
	if n is BaseButton:
		n.pressed.connect(func(): sfx("ui_click", null, -12.))
		n.mouse_entered.connect(func():
			if not n.disabled:
				sfx("ui_hover", null, -23.))

func make_loop(cue: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var stream: AudioStream = sounds[cue].duplicate()
	if stream is AudioStreamWAV:
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	else:
		stream.loop = true
	p.stream = stream
	p.volume_db = -80
	p.bus = "Sfx"
	add_child(p)
	return p

# Critical cues can replace cosmetic ones; cosmetic effects cannot evict alarms from a full pool.
func voice_index(voices: Array, priorities: Array[int], start: int, priority: int) -> int:
	for i in range(voices.size()):
		var index := (start + i) % voices.size()
		if not voices[index].playing:
			return index
	var quietest := -1
	var quiet_db := INF
	for i in range(voices.size()):
		if priorities[i] <= priority and voices[i].volume_db < quiet_db:
			quietest = i
			quiet_db = voices[i].volume_db
	return quietest

func sfx(cue: String, at = null, db := -5., pitch_jitter := .045, priority: int = 0, emitter: int = 0) -> void:
	if m == null or not sounds.has(cue):
		return
	if at != null and Vector2(at).distance_squared_to(m.cam.position) > pow(HEAR_TILES * GameSim.T, 2):
		return
	var now := float(m.clock)
	var key := cue + ":" + str(emitter) + (str((Vector2(at) / 64).floor()) if at != null else "ui")
	if now - emitter_last.get(key, -99.) < GAP.get(cue, .04):
		return
	var index := voice_index(world_voices if at != null else flat_voices, world_priority if at != null else flat_priority,
		world_next if at != null else flat_next, priority)
	if index < 0:
		return
	if emitter_last.size() > 512:
		emitter_last.clear()
	emitter_last[key] = now
	sound_last[cue] = now
	var options: Array = variants.get(cue, [sounds[cue]])
	var pick := randi_range(0, options.size() - 1)
	if options.size() > 1 and pick == variant_last.get(cue, -1):
		pick = (pick + 1) % options.size()
	variant_last[cue] = pick
	var player = world_voices[index] if at != null else flat_voices[index]
	player.stream = options[pick]
	player.volume_db = db
	player.pitch_scale = 1. + randf_range(-pitch_jitter, pitch_jitter)
	if at != null:
		player.global_position = at
		world_priority[index] = priority
		world_next = (index + 1) % world_voices.size()
	else:
		flat_priority[index] = priority
		flat_next = (index + 1) % flat_voices.size()
	player.play()
	if priority >= 2:
		music_duck_until = maxf(music_duck_until, now + 1.1)

static func music_for(snap: Dictionary) -> String:
	var ph: String = snap.get("ph", "")
	if ph == "result":
		var outcome = snap.get("result")
		return "win" if outcome != null and outcome[0] else "loss"
	if ph in ["night", "dusk"]:
		if snap.get("en", []).any(func(e): return e[1] == GameSim.BOSS and e[3] > 0):
			return "boss"
		var night: int = int(snap.get("k", 1))
		return "final" if night >= 5 else "night_late" if night >= 3 else "night_early"
	return "day" if ph == "day" else "menu"

func select_music(track: String) -> void:
	if current_music == track or not sounds.has("music_" + track):
		return
	current_music = track
	var next := music_names.find(track)
	if next < 0:
		next = 0 if music_target != 0 else 1
		music_voices[next].stop()
		music_voices[next].stream = sounds["music_" + track]
		music_voices[next].volume_db = -80
		music_names[next] = track
		music_voices[next].play()
	music_target = next

static func fade(p: AudioStreamPlayer, to: float, rate: float) -> void:
	var value := lerpf(db_to_linear(p.volume_db), to, clampf(rate, 0, 1))
	p.volume_db = linear_to_db(maxf(.00001, value))

func mix_loop(p: AudioStreamPlayer, target: float, dt: float) -> void:
	if target > .001 and not p.playing:
		p.play()
	fade(p, target, dt * 1.5)
	if target <= .001 and p.volume_db < -65 and p.playing:
		p.stop()

func tick(dt: float) -> void:
	if m == null:
		return
	var ph: String = m.snap.get("ph", "")
	var paused: bool = m.pause_menu.paused
	select_music(music_for(m.snap))
	for i in range(2):
		var gain: float = MUSIC_GAIN.get(current_music, .7) if i == music_target else 0.
		gain *= (.55 if m.clock < music_duck_until else 1.) * (.45 if paused else 1.)
		fade(music_voices[i], gain, dt * (3. if current_music == "boss" else 1.3))
		if i != music_target and music_voices[i].volume_db < -65 and music_names[i] != "":
			music_voices[i].stop()
			music_names[i] = ""
	environment_left -= dt
	if environment_left <= 0:
		environment_left = .25
		update_environment()
	for cue in ambient:
		mix_loop(ambient[cue], environment.get(cue, 0.) * (.15 if paused else 1.), dt)
	tick_channels(paused)
	var me = m.snap.get("ps", {}).get(m.my_id)
	var playing: bool = ph in ["day", "dusk", "night"] and not paused
	var low: bool = playing and me != null and me[5] == 0 and me[3] > 0 and me[3] / float(me[4]) < .25
	mix_loop(heartbeat, .3 if low else 0., dt)
	var here: Vector2 = m.local_pos
	var moved: float = here.distance_to(step_from) if playing and me != null and me[5] == 0 else 0.
	step_from = here
	if moved > .2 and moved < GameSim.T:
		step_acc += moved
		if step_acc >= .8 * GameSim.T:
			step_acc = 0.
			sfx("step_" + surface_at(here), null, -16., .08)
	elif moved >= GameSim.T or not playing:
		step_acc = 0.
	var flags := [m.inventory.bag_open, m.craft_open, m.build_menu.build_open, m.minimap.map_big, paused, m.gameplay_hud.help_open]
	var panels := str(flags)
	if panels_were != "" and panels != panels_were:
		sfx("ui_open" if flags.any(func(v): return v) else "ui_close", null, -13.)
	panels_were = panels

func update_environment() -> void:
	environment.clear()
	var ph: String = m.snap.get("ph", "")
	if not ph in ["day", "dusk", "night"]:
		return
	var pos: Vector2 = m.local_pos
	var indoors: bool = m.sim != null and (m.geometry.is_cave_interior(pos) or m.geometry.is_weather_interior(pos))
	if indoors:
		environment["amb_cave" if m.geometry.is_cave_interior(pos) else "amb_station"] = .3
	else:
		environment["amb_day"] = .26 if ph == "day" else .1 if ph == "dusk" else 0.
		environment["amb_night"] = .28 if ph == "night" else .12 if ph == "dusk" else 0.
		if m.sim != null:
			environment["amb_coast"] = .4 * clampf(1. - IslandMap.depth(pos) / (14 * GameSim.T), 0., 1.)
			environment["amb_swamp"] = .3 * clampf(1. - pos.distance_to(m.geometry.swamp_centre) / (15 * GameSim.T), 0., 1.)
	environment["amb_base"] = .24 * clampf(1. - pos.length() / (12 * GameSim.T), 0., 1.) if not indoors else 0.
	if ph == "night" and int(m.snap.get("k", 1)) == 5 and m.snap.get("rescue", [[], false])[1]:
		var seconds: float = m.snap.get("t", 500.)
		if seconds <= 45 or m.snap.get("ext", false):
			environment["helicopter"] = lerpf(.12, .55, clampf(1. - seconds / 45., 0., 1.))

func surface_at(pos: Vector2) -> String:
	if m.sim == null:
		return "grass"
	if m.geometry.is_cave_interior(pos) or m.geometry.is_weather_interior(pos) or SimWorld.inside_base(pos):
		return "stone"
	if IslandMap.near_bridge(pos) or IslandMap.on_dock(pos, 0):
		return "wood"
	if m.geometry.compounds.has(13) and Rect2(m.geometry.compounds[13]).has_point(pos):
		return "metal"
	if pos.distance_squared_to(m.geometry.swamp_centre) < pow(9 * GameSim.T, 2):
		return "water"
	return "sand" if IslandMap.depth(pos) < 7 * GameSim.T else "grass"

func activity_cue(id: int, p) -> String:
	if p[5] != 0:
		return ""
	if m.snap.get("construction", []).any(func(job): return int(job[2]) == id):
		return "build_loop"
	match str(p[22]):
		"repair": return "repair_loop"
		"revive": return "revive_loop"
		"loot": return "unlock_loop" if p[33] >= 0 else ""
		"craft":
			if m.snap.get("rescue", [[], false, 0.])[2] > 0 and Vector2(p[23]).distance_squared_to(GameSim.RADIO_POS) < 1:
				return "radio_loop"
			return "craft_loop" if int(p[26]) >= 0 else ""
	return ""

func tick_channels(paused: bool) -> void:
	var candidates: Array = []
	if not paused and m.snap.get("ph", "") in ["day", "dusk", "night"]:
		for id in m.snap.get("ps", {}):
			var p = m.snap.ps[id]
			var cue := activity_cue(id, p)
			var distance: float = Vector2(p[2]).distance_squared_to(m.local_pos)
			if cue != "" and distance < pow(10 * GameSim.T, 2):
				candidates.append([distance, id, cue, p[2]])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(3):
		if i >= candidates.size():
			if channels[i].playing:
				channels[i].stop()
			channel_owners[i] = 0
			channel_names[i] = ""
			continue
		var c = candidates[i]
		if channel_owners[i] != c[1] or channel_names[i] != c[2]:
			channels[i].stop()
			channels[i].stream = channel_streams[c[2]]
			channel_owners[i] = c[1]
			channel_names[i] = c[2]
			channels[i].play()
		channels[i].global_position = c[3]

func apply_volume(i: int) -> void:
	var bus := AudioServer.get_bus_index(BUS[i])
	AudioServer.set_bus_volume_db(bus, -80. if volume[i] <= .001 else linear_to_db(volume[i]))
	AudioServer.set_bus_mute(bus, volume[i] <= .001)

func set_volume(i: int, value: float) -> void:
	volume[i] = clampf(value, 0., 1.)
	apply_volume(i)
	var cfg := ConfigFile.new()
	for j in BUS.size():
		cfg.set_value("volume", BUS[j], volume[j])
	cfg.save(config_path)

func harvest(type: int, pos: Vector2, stage: int) -> void:
	var cue: String = ["wood_break", "crumble", "herb", "metal_break"][clampi(type, 0, 3)] if stage == 2 else ["chop", "mine", "herb", "mine_metal"][clampi(type, 0, 3)]
	sfx(cue, pos, -8. if stage == 0 else -4., .055)

func consume_events(d: Dictionary) -> void:
	for event in d.get("audio", []):
		if int(event[0]) <= last_event_sequence:
			continue
		last_event_sequence = int(event[0])
		var cue: String = "attack_basic" if event[1] == "attack_fists" else event[1]
		var mine: bool = int(event[3]) == m.my_id and int(event[3]) > 0
		var db: float = {"drop_spawn": -18., "arrow_hit": -12., "growl": -9., "empty_bow": -15.}.get(cue, -6.)
		sfx(cue, null if mine else event[2], db, .035, 2 if cue == "boss_warn" else 0, int(event[3]))

func boss_arrival(e) -> void:
	sfx("boss_arrival", null, -4., 0., 3)
	sfx("boss_roar_" + str(e[6]), e[2], -1., .015, 2)

# State changes complement exact events: health, inventories, radio, containers and phase changes.
func from_snap(d: Dictionary) -> void:
	if m == null:
		return
	select_music(music_for(d))
	var old: Dictionary = m.snap
	var ph: String = d.get("ph", "")
	if ph != old.get("ph", "") or d.get("k", 0) != old.get("k", 0):
		enemy_hit_last.clear()
		tower_zap_last.clear()
		other_steps.clear()
		last_event_sequence = int(d.audio[-1][0]) if not d.get("audio", []).is_empty() else 0
		phase_sound(ph, old.get("ph", ""), d)
		for e in d.get("en", []):
			if e[1] == GameSim.BOSS:
				boss_arrival(e)
		return
	if not ph in ["day", "dusk", "night"]:
		return
	consume_events(d)
	var exact: bool = d.has("audio")
	var old_en := {}
	for e in old.get("en", []):
		old_en[e[0]] = e
	var seen := {}
	for e in d.get("en", []):
		var o = old_en.get(e[0])
		seen[e[0]] = true
		if o == null:
			if e[1] == GameSim.BOSS:
				boss_arrival(e)
			continue
		if e[3] < o[3] and m.clock - enemy_hit_last.get(e[0], -9.) > .2:
			enemy_hit_last[e[0]] = m.clock
			sfx("hit_boss" if e[1] == GameSim.BOSS else "hit", e[2], -8.)
		if e[10] and not o[10]:
			sfx("snare", e[2], -8.)
		if not exact and e[9] and not o[9]:
			sfx("boss_swing" if e[1] == GameSim.BOSS else "spit" if e[1] == GameSim.SPITTER else "wrecker_atk" if e[1] == GameSim.WRECKER else "growl", e[2], -6.)
		if e[1] in [GameSim.WRECKER, GameSim.BOSS] and str(e[7]) == "":
			var distance: float = Vector2(e[2]).distance_to(o[2])
			var step_key := "e" + str(e[0])
			if distance < 2 * GameSim.T:
				other_steps[step_key] = other_steps.get(step_key, 0.) + distance
				if other_steps[step_key] >= 1.1 * GameSim.T:
					other_steps[step_key] = 0.
					sfx("step_metal", e[2], -16., .035, 0, -int(e[0])-1)
	for id in old_en:
		if not seen.has(id):
			var e = old_en[id]
			sfx("boss_die" if e[1] == GameSim.BOSS else "enemy_die", null if e[1] == GameSim.BOSS else e[2], -5., .02, 2 if e[1] == GameSim.BOSS else 0)
			enemy_hit_last.erase(id)
			other_steps.erase("e" + str(id))
	if not exact:
		for i in range(old.get("proj", []).size(), d.get("proj", []).size()):
			sfx("spit", d.proj[i][0], -7.)
		for i in range(old.get("tele", []).size(), d.get("tele", []).size()):
			sfx("boss_warn", d.tele[i][0], -5., 0., 2)
	tactical_changes(old, d)
	player_changes(old, d, exact)
	world_changes(old, d)

func player_changes(old: Dictionary, d: Dictionary, exact: bool) -> void:
	for id in d.get("ps", {}):
		var p = d.ps[id]
		var o = old.get("ps", {}).get(id)
		if o == null:
			continue
		var mine: bool = id == m.my_id
		var at = null if mine else p[2]
		if int(p[5]) != int(o[5]):
			sfx("downed" if p[5] == 1 else "death" if p[5] == 2 else "revive", null, -5., 0., 2, id)
		elif p[3] < o[3]:
			sfx("my_hurt" if mine else "hurt", at, -5. if mine else -11., .03, 1, id)
		elif p[3] > o[3] and p[5] == 0:
			sfx("heal", at, -10., .02, 0, id)
		if not exact and p[11] and not o[11]:
			sfx("bow" if p[8] in ["bow", "starter_bow"] else "attack_basic", at, -8.)
		if p[10] < o[10]:
			sfx("flask", at, -8.)
		if p[13] > 0 and o[13] <= 0:
			sfx("herb", at, -13.)
		if p[30] and not o[30]:
			sfx("haste", at, -9.)
		if not exact and o[26] >= 0 and p[26] < 0 and o[27] >= .85:
			sfx("craft_done", at, -6., 0.)
		if p[35] > o[35] and p[32] >= 0:
			sfx("chest_open", at, -6.)
		if p[32] < 0 and o[32] >= 0:
			sfx("chest_close", at, -9.)
		if mine:
			if p[25] != o[25]:
				sfx("equip", null, -15.)
			if p[5] == 1 and p[6] > 0 and p[6] <= 10 and ceili(p[6]) < ceili(o[6]):
				sfx("bleed_tick", null, -12., 0., 2)
			if p[7] != o[7] or p[9] != o[9]:
				sfx("item_move", null, -17.)
				for item in GameSim.RES + ["bandage", "arrow", "bow", "revive", "chest_key"]:
					if InventoryUi.carried(p, item) > InventoryUi.carried(o, item):
						sfx("pickup", null, -15.)
						break
		else:
			var distance: float = Vector2(p[2]).distance_to(o[2])
			if p[5] == 0 and distance < GameSim.T:
				other_steps[id] = other_steps.get(id, 0.) + distance
				if other_steps[id] >= .8 * GameSim.T:
					other_steps[id] = 0.
					sfx("step_" + surface_at(p[2]), p[2], -19., .08, 0, id)

func tactical_changes(old: Dictionary, d: Dictionary) -> void:
	var previous := {}
	for area in old.get("tactical", []):
		previous[str(area[0]) + str(area[1])] = true
	for area in d.get("tactical", []):
		if not previous.has(str(area[0]) + str(area[1])):
			var cue: String = {"blast": "explode", "poison": "poison", "heal": "heal_zone", "trap": "trap_set"}.get(str(area[0]), "")
			if cue != "":
				sfx(cue, area[1], -4. if cue == "explode" else -9.)

func world_changes(old: Dictionary, d: Dictionary) -> void:
	if d.get("base", 0) < old.get("base", 0):
		sfx("gen_hit", Vector2.ZERO, -6.)
		if d.get("base", 1000) < 250:
			sfx("base_alarm", null, -8., 0., 3)
	for i in range(3):
		if d.doors[i] < old.doors[i]:
			sfx("door_crack" if d.doors[i] < .3 * GameSim.DOOR_HP else "door_hit", GameSim.DOOR_POS[i], -6.)
			if d.doors[i] <= 0 and old.doors[i] > 0:
				sfx("breach", null, -5., 0., 3, i)
		elif d.doors[i] > old.doors[i]:
			sfx("repair", GameSim.DOOR_POS[i], -16.)
	var old_towers := {}
	for tw in old.get("tw", []):
		old_towers[tw[0]] = tw
	for tw in d.get("tw", []):
		var before = old_towers.get(tw[0])
		if before == null:
			sfx("build", tw[1], -5.)
		elif before[2] > 0 and tw[2] <= 0:
			sfx("tower_break", tw[1], -4., .025, 1)
		elif tw[2] > before[2]:
			sfx("repair", tw[1], -16.)
		if tw[4] and m.clock - tower_zap_last.get(tw[0], -9.) > .45:
			tower_zap_last[tw[0]] = m.clock
			sfx("tower_zap", tw[1], -14., .05, 0, int(tw[0]))
	var before_rescue = old.get("rescue", [[0,0,0],false,0.,[0,0,0]])
	var rescue = d.get("rescue", [[0,0,0],false,0.,[0,0,0]])
	for i in range(3):
		if rescue[0][i] > before_rescue[0][i]:
			sfx("part_found", null, -6., 0., 2)
		if rescue.size() > 3 and before_rescue.size() > 3 and rescue[3][i] > before_rescue[3][i]:
			sfx("part_install", GameSim.RADIO_POS, -8., 0.)
	if rescue[1] and not before_rescue[1]:
		sfx("radio_online", null, -5., 0., 2)
	var old_chests := {}
	for chest in old.get("sup", []):
		old_chests[chest[0]] = chest
	for chest in d.get("sup", []):
		var before = old_chests.get(chest[0])
		if before != null and chest[4] and not before[4]:
			sfx("chest_unlock", chest[1], -5.)
	if d.get("votes", 0) > old.get("votes", 0):
		sfx("vote", null, -12., 0.)

func phase_sound(ph: String, old_ph: String, d: Dictionary) -> void:
	match ph:
		"day": sfx("start" if old_ph in ["", "lobby"] else "dawn", null, -7., 0., 2)
		"dusk": sfx("dusk_horn", null, -6., 0., 3)
		"night": sfx("night_gong", null, -8., 0., 2)
		"result":
			var r = d.get("result")
			sfx("win" if r != null and r[0] else "lose", null, -9., 0., 3)
