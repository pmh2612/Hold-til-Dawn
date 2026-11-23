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
	check(audio.sounds.size() == 52 and audio.sounds.values().all(func(v): return v is AudioStreamWAV and v.get_length() > 0), "all 52 branch sound assets load")
	check(audio.world_voices.size() == 32 and audio.flat_voices.size() == 10, "effect playback has a fixed voice budget")
	for name in ["amb_day", "amb_night", "music_day", "music_night", "music_boss"]:
		check(audio.sounds[name].loop_mode != AudioStreamWAV.LOOP_DISABLED, name + " loops")
	check(is_equal_approx(audio.sounds.music_boss.get_length(), audio.sounds.music_night.get_length()), "boss drums match the night music length")
	for entry in [[0, 0, "chop"], [1, 0, "mine"], [2, 0, "herb"], [3, 0, "mine"], [0, 2, "crumble"]]:
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
	for change in [[3, 90, "my_hurt"], [5, 1, "downed"], [5, 2, "death"], [11, true, "swing"], [30, true, "haste"], [28, 1, "revive"]]:
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
	event(before, after, "boss_roar")
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
	check(audio.boss_music.volume_db > -20 and audio.night_amb.volume_db > -20, "night and boss layers fade in")
	check(audio.get_child_count() == 47, "event playback does not allocate additional audio players")
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
