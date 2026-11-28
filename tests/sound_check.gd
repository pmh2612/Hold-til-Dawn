extends Node

var checks := 0
var failed := false
var host: Main

# Exercise the real snapshot consumer and native pause UI without generating the island.
class AudioHost extends Main:
	func _ready() -> void:
		font_ui = ThemeDB.fallback_font
		font_title = ThemeDB.fallback_font
		add_child(sound)
		sound.setup(self)
	func _process(_dt: float) -> void:
		pass
	func _physics_process(_dt: float) -> void:
		pass
	func _draw() -> void:
		pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("FAIL: " + label)
	else:
		print("ok   " + label)

func snapshot() -> Dictionary:
	var p := ["Engineer", 2, Vector2.ZERO, 110, 110, 0, 0, SimInventory.empty_slots(8), "hammer", -1, 0, false, 0, 0, 0, 0, "", 0, 0, false, 0, 0, "idle", Vector2.ZERO, 0, 0, -1, 0, 0, 0, false, 0, -1, -1, 0, 0]
	return {"ph": "day", "k": 1, "ps": {1: p}, "en": [], "base": 1000, "doors": [600, 600, 600], "tw": []}

func event(before: Dictionary, after: Dictionary, expected: String) -> void:
	host.clock += 1
	host.sound.sound_last.clear()
	host.snap = before
	host.sound.from_snap(after)
	check(host.sound.sound_last.has(expected), "snapshot triggers " + expected)

func _ready() -> void:
	host = AudioHost.new()
	add_child(host)
	host.my_id = 1
	host.snap = snapshot()
	var audio: Sound = host.sound
	check(audio.catalog.effects.size() >= 100 and audio.sounds.values().all(func(v): return v is AudioStream and v.get_length() > 0), "all production effects, ambience and scores load")
	check(audio.world_voices.size() == 32 and audio.flat_voices.size() == 10, "effect playback has a fixed voice budget")
	check(audio.channel_streams.values().all(func(s): return s.loop_end > s.loop_begin and s.loop_end > 100), "action loop streams cover their full sample data")
	for name in audio.catalog.music:
		check(audio.sounds["music_" + name].loop == (name not in ["win", "loss"]), name + " has the correct score loop behaviour")
	check(audio.sounds.music_boss.get_length() > 60 and audio.sounds.music_boss != audio.sounds.music_night_early, "boss has a full separate orchestral score")
	for entry in [[0, 0, "chop"], [1, 0, "mine"], [2, 0, "herb"], [3, 0, "mine_metal"], [0, 2, "wood_break"]]:
		host.clock += 1
		audio.sound_last.clear()
		audio.harvest(entry[0], Vector2.ZERO, entry[1])
		check(audio.sound_last.has(entry[2]), "harvest type %d stage %d" % [entry[0], entry[1]])
	var index := audio.world_next
	host.clock += 1
	audio.sfx("hit", Vector2(100000, 0))
	check(audio.world_next == index, "inaudible world effects do not occupy voices")
	audio.sfx("hit", Vector2.ZERO)
	index = audio.world_next
	audio.sfx("hit", Vector2.ZERO)
	check(audio.world_next == index, "repeated hits are throttled")
	var before := snapshot()
	for phase in [["lobby", "day", "start"], ["day", "dusk", "dusk_horn"], ["dusk", "night", "night_gong"], ["night", "day", "dawn"], ["night", "result", "lose"]]:
		var a := before.duplicate(true)
		var b := before.duplicate(true)
		a.ph = phase[0]
		b.ph = phase[1]
		event(a, b, phase[2])
	for change in [[3, 90, "my_hurt"], [5, 1, "downed"], [5, 2, "death"], [11, true, "attack_basic"], [30, true, "haste"]]:
		var after := before.duplicate(true)
		after.ps[1][change[0]] = change[1]
		event(before, after, change[2])
	var after := before.duplicate(true)
	after.ps[1][7][0] = ["wood", 2]
	event(before, after, "pickup")
	after = before.duplicate(true)
	after.ps[1][32] = 9
	after.ps[1][35] = 1
	event(before, after, "chest_open")
	var crafting := before.duplicate(true)
	crafting.ps[1][26] = 8
	crafting.ps[1][27] = 0.99
	event(crafting, before, "craft_done")
	after = before.duplicate(true)
	after.base = 900
	event(before, after, "gen_hit")
	after = before.duplicate(true)
	after.doors[0] = 590
	event(before, after, "door_hit")
	event(after, before, "repair")
	after = before.duplicate(true)
	after.tw = [[0, Vector2.ZERO, 300, false, true, Vector2.ZERO]]
	event(before, after, "build")
	check(audio.sound_last.has("tower_zap"), "tower fire triggers its effect")
	var enemy := [100, GameSim.BOSS, Vector2.ZERO, 100, 100, 32, 0, [], 0, false, false, false]
	after = before.duplicate(true)
	after.en = [enemy]
	event(before, after, "boss_arrival")
	var hurt := after.duplicate(true)
	hurt.en[0][3] = 90
	hurt.en[0][9] = true
	event(after, hurt, "hit_boss")
	check(audio.sound_last.has("boss_swing"), "boss wind-up triggers its effect")
	event(hurt, before, "boss_die")
	host.snap = before
	audio.tick(1.0)
	host.inventory.bag_open = true
	audio.tick(1.0)
	check(audio.sound_last.has("ui_open"), "modular inventory opening plays UI audio")
	host.clock += 1
	host.inventory.bag_open = false
	audio.tick(1.0)
	check(audio.sound_last.has("ui_close"), "modular inventory closing plays UI audio")
	host.snap.ph = "night"
	host.snap.en = [enemy]
	for i in 20:
		audio.tick(0.1)
	check(audio.current_music == "boss" and audio.music_voices[audio.music_target].volume_db > -20 and audio.ambient.amb_night.volume_db > -20, "boss score replaces night music while island ambience continues")
	var voice_count := audio.get_child_count()
	check(voice_count == 56, "effect, channel, ambience and crossfade playback has a fixed player budget")
	check_new_audio(audio)
	check(audio.get_child_count() == voice_count, "all new interactions reuse the existing audio players")
	var pause: PauseScreen = load("res://ui/menu/pause_screen.tscn").instantiate()
	host.add_child(pause)
	pause.setup(host)
	pause.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause.position = Vector2.ZERO
	pause.size = get_viewport().get_visible_rect().size
	host.pause_menu.paused = true
	await get_tree().process_frame
	var rows := pause.get_node("Box/AudioLevels").get_children()
	check(rows.size() == 3, "native pause screen has Master / Effects / Music sliders")
	for i in 3:
		var slider := rows[i].get_node(Sound.BUS[i]) as HSlider
		check(slider != null and is_equal_approx(slider.value, audio.volume[i]), "pause slider binds " + Sound.BUS[i])
	# Persist only in the workspace so this check cannot change the player's saved preferences.
	audio.config_path = "res://.tmp/audio-test.cfg"
	for i in 3:
		var slider := rows[i].get_node(Sound.BUS[i]) as HSlider
		slider.value = 0
		check(is_zero_approx(audio.volume[i]) and AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.BUS[i])), "slider mutes its own bus: " + Sound.BUS[i])
		slider.value = 0.5
		check(is_equal_approx(audio.volume[i], 0.5) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.BUS[i])), "slider restores its own bus: " + Sound.BUS[i])
	var cfg := ConfigFile.new()
	check(cfg.load(audio.config_path) == OK and is_equal_approx(float(cfg.get_value("volume", "Music", -1)), 0.5), "volume settings persist")
	await get_tree().process_frame
	var box: Control = pause.get_node("Box")
	check(Rect2(Vector2.ZERO, pause.size).encloses(box.get_rect()), "pause panel fits the viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.tmp/sound-pause.png")
	# Main._ready was skipped, so its precreated UI and camera nodes were never parented.
	for node in [host.hud, host.cam, host.tint, host.my_light, host.beacon, host.menu_panel, host.role_opt, host.status, host.lobby_panel, host.banner, host.front]:
		if node.get_parent() == null:
			node.free()
	host.free()
	await get_tree().process_frame
	print("SOUND ALL OK: %d checks" % checks if not failed else "SOUND FAILED")
	get_tree().quit(1 if failed else 0)

func check_new_audio(audio: Sound) -> void:
	var base := snapshot()
	for setup_ in [["",1,"menu"],["lobby",1,"menu"],["day",1,"day"],["dusk",2,"night_early"],
		["night",1,"night_early"],["night",2,"night_early"],["night",3,"night_late"],
		["night",4,"night_late"],["night",5,"final"]]:
		var data := base.duplicate(true)
		data.ph = setup_[0]
		data.k = setup_[1]
		check(Sound.music_for(data) == setup_[2], "music direction: %s / %s selects %s" % setup_)
	for won in [false, true]:
		var data := base.duplicate(true)
		data.ph = "result"
		data.result = [won, "", 5]
		check(Sound.music_for(data) == ("win" if won else "loss"), "result screen selects its own one-shot score")
	var data := base.duplicate(true)
	data.ph = "night"
	data.en = [[100,GameSim.BOSS,Vector2.ZERO,100,100,32,0,"",0,false,false,false]]
	check(Sound.music_for(data) == "boss", "boss presence overrides the normal night score")
	data.en.clear()
	check(Sound.music_for(data) == "night_early", "boss death restores the correct night score")
	# Two identical active-swing snapshots still contain two distinct attack events.
	var exact := base.duplicate(true)
	exact.audio = [[1,"bow",Vector2.ZERO,1]]
	audio.last_event_sequence = 0
	host.clock += 1
	host.snap = base
	audio.from_snap(exact)
	var first_voice := audio.flat_next
	check(audio.sound_last.has("bow") and audio.last_event_sequence == 1, "authoritative bow shot is heard")
	host.clock += 1
	audio.from_snap(exact)
	check(audio.flat_next == first_voice, "repeated snapshot never replays a consumed event")
	exact.audio.append([2,"bow",Vector2.ZERO,1])
	host.clock += 1
	audio.from_snap(exact)
	check(audio.sound_last.bow == host.clock and audio.last_event_sequence == 2, "next attack is heard even if the animation boolean remains true")
	exact.audio.append([3,"craft_done",Vector2.ZERO,1])
	host.clock += 1
	audio.from_snap(exact)
	check(audio.sound_last.craft_done == host.clock, "successful craft completion comes from its actual event")
	exact.audio.append([4,"boss_slam",Vector2.ZERO,-101])
	host.clock += 2
	audio.music_duck_until = 0
	audio.from_snap(exact)
	check(audio.sound_last.get("boss_slam", -1) == host.clock and audio.music_duck_until > host.clock and audio.world_priority.has(2), "Ground impact is a critical sound that ducks the music")
	var heard: float = float(audio.sound_last.get("boss_slam", -1))
	host.clock += 1
	audio.from_snap(exact)
	check(audio.sound_last.get("boss_slam", -1) == heard, "Repeated snapshots do not replay the slam impact")
	exact.audio.append([5,"boss_charge",Vector2.ZERO,-101])
	host.clock += 2
	audio.music_duck_until = 0
	audio.from_snap(exact)
	check(audio.sound_last.get("boss_charge", -1) == host.clock and audio.music_duck_until > host.clock and audio.world_priority.has(2), "Juggernaut charge gets a protected voice and ducks the music")
	var charge_heard: float = float(audio.sound_last.get("boss_charge", -1))
	host.clock += 1
	audio.from_snap(exact)
	check(audio.sound_last.get("boss_charge", -1) == charge_heard, "Repeated snapshots do not replay the rush sound")
	var crafting := base.duplicate(true)
	crafting.audio = []
	crafting.ps[1][26] = 8
	crafting.ps[1][27] = .99
	var cancelled := base.duplicate(true)
	cancelled.audio = []
	host.snap = crafting
	audio.sound_last.erase("craft_done")
	audio.from_snap(cancelled)
	check(not audio.sound_last.has("craft_done"), "late craft cancellation never plays a false completion sound")
	# Critical world/quest feedback is independent of visibility and text wording.
	var changed := base.duplicate(true)
	changed.doors[0] = 0
	event(base, changed, "breach")
	changed = base.duplicate(true)
	changed.rescue = [[1,0,0],false,0.,[0,0,0]]
	event(base, changed, "part_found")
	var repaired := changed.duplicate(true)
	repaired.rescue = [[1,1,1],true,0.,[1,1,1]]
	event(changed, repaired, "radio_online")
	var tower := base.duplicate(true)
	tower.tw = [[0,Vector2.ZERO,300,false,false,Vector2.ZERO]]
	changed = tower.duplicate(true)
	changed.tw[0][2] = 0
	event(tower, changed, "tower_break")
	var closed := base.duplicate(true)
	closed.sup = [[7,Vector2.ZERO,false,5,false,0.,0.]]
	changed = closed.duplicate(true)
	changed.sup[0][4] = true
	event(closed, changed, "chest_unlock")
	for activity in ["repair", "revive", "loot", "craft"]:
		var channel := base.duplicate(true)
		channel.ps[1][22] = activity
		channel.ps[1][33] = 7 if activity == "loot" else -1
		channel.ps[1][26] = 8 if activity == "craft" else -1
		host.snap = channel
		audio.tick(.1)
		check(audio.channels[0].playing and audio.channel_names[0] != "", activity + " starts its contextual channel audio")
		host.snap = base
		audio.tick(.1)
		check(audio.channels.all(func(p): return not p.playing), activity + " audio stops immediately on interruption")
	host.snap = base.duplicate(true)
	host.snap.ps[1][22] = "repair"
	audio.tick(.1)
	host.pause_menu.paused = true
	audio.tick(.1)
	check(audio.channels.all(func(p): return not p.playing), "pause immediately stops action loops")
	host.pause_menu.paused = false
	host.snap = base
	# Submitting many inaudible cues must not create players or consume the voice pool.
	var next := audio.world_next
	for i in range(200):
		audio.sfx("hit",Vector2(100000,0))
	check(audio.world_next == next, "large distant battles are culled before voice allocation")
	var sim := GameSim.new()
	for i in range(200):
		SimAudio.emit(sim,"bow",Vector2.ZERO,1)
	check(sim.audio_events.size() == SimAudio.MAX_EVENTS and sim.audio_events[-1][0] == 200, "simulation audio event history stays bounded and ordered")
