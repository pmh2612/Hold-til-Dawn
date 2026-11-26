extends Node

# Audition shipped streams through the real director/mixer. -- --tour records a short automatic review.
class ReviewHost extends Main:
	func _ready() -> void:
		add_child(sound)
		sound.setup(self)
	func _process(_dt: float) -> void: pass
	func _physics_process(_dt: float) -> void: pass
	func _draw() -> void: pass

var host: Main
var status: Label
var cues: OptionButton
var recorder: AudioEffectRecord
var tracks := ["menu", "day", "night_early", "night_late", "boss", "final", "win", "loss"]
var touring := false

func player() -> Array:
	return ["Review",2,Vector2.ZERO,110,110,0,0,SimInventory.empty_slots(8),"hammer",-1,0,false,0,0,0,0,"",0,0,false,0,0,"idle",Vector2.ZERO,0,0,-1,0,0,0,false,0,-1,-1,0,0]

func _ready() -> void:
	host = ReviewHost.new()
	add_child(host)
	host.my_id = 1
	host.snap = {"ph":"", "k":1, "ps":{1:player()}, "en":[], "base":1000, "doors":[600,600,600], "tw":[]}
	# Change the buses for this review only, without saving the player's preferences.
	for i in range(3):
		host.sound.volume[i] = [.7, 1., .6][i]
		host.sound.apply_volume(i)
	var bg := ColorRect.new()
	bg.color = Color("101820")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(32,24)
	box.size = Vector2(880,490)
	box.add_theme_constant_override("separation",12)
	add_child(box)
	status = Label.new()
	status.text = "HOLD 'TIL DAWN / AUDIO REVIEW"
	status.add_theme_font_size_override("font_size",24)
	box.add_child(status)
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for i in range(tracks.size()):
		var button := Button.new()
		button.text = "%d  %s" % [i+1, tracks[i].to_upper().replace("_"," ")]
		button.custom_minimum_size = Vector2(210,56)
		button.pressed.connect(select_track.bind(tracks[i]))
		grid.add_child(button)
	cues = OptionButton.new()
	var names: Array = host.sound.catalog.effects.keys()
	names.sort()
	for cue in names: cues.add_item(cue)
	box.add_child(cues)
	var play := Button.new()
	play.text = "PLAY EFFECT"
	play.pressed.connect(func(): host.sound.sfx(cues.get_item_text(cues.selected), null, -6.))
	box.add_child(play)
	var info := Label.new()
	info.text = "1-8: soundtrack  |  Select an effect, then Play  |  Esc: quit\nMusic blends automatically; boss cues duck the score."
	box.add_child(info)
	if "--tour" in OS.get_cmdline_user_args():
		touring = true
		run_tour()

func _process(dt: float) -> void:
	if host != null:
		host.clock += dt
		host.sound.tick(dt)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			select_track(tracks[event.keycode-KEY_1])

func select_track(track: String) -> void:
	var data := host.snap.duplicate(true)
	data.en = []
	data.erase("result")
	data.k = 1
	data.ph = {"menu":"", "day":"day", "win":"result", "loss":"result"}.get(track,"night")
	if track == "night_late": data.k = 3
	if track == "final": data.k = 5
	if track == "boss": data.en = [[200,GameSim.BOSS,Vector2.ZERO,100,100,32,0,"",0,false,false,false]]
	if track in ["win","loss"]: data.result = [track=="win","",5]
	host.sound.from_snap(data)
	host.snap = data
	status.text = "AUDIO REVIEW / " + track.to_upper().replace("_"," ")

func run_tour() -> void:
	DirAccess.make_dir_recursive_absolute("res://.tmp/audio-refresh/review")
	recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	for track in tracks:
		select_track(track)
		await get_tree().create_timer(3.).timeout
	select_track("day")
	for cue in ["chop", "mine", "mine_metal", "herb", "chest_unlock", "chest_open", "attack_titanium_blade", "bow", "craft_done", "part_found", "radio_online", "breach"]:
		status.text = "AUDIO REVIEW / " + cue
		host.sound.sfx(cue, null, -6., 0., 1)
		await get_tree().create_timer(.8).timeout
	for activity in ["repair", "revive", "loot", "craft"]:
		var p = host.snap.ps[1]
		p[22] = activity
		p[33] = 7 if activity == "loot" else -1
		p[26] = 8 if activity == "craft" else -1
		status.text = "AUDIO REVIEW / " + activity + " channel"
		await get_tree().create_timer(1.6).timeout
		p[22] = "idle"
		await get_tree().create_timer(.2).timeout
	select_track("boss")
	for i in range(7):
		host.sound.sfx("boss_roar_"+str(i),null,-5.,0.,2)
		await get_tree().create_timer(1.8).timeout
	recorder.set_recording_active(false)
	var stream := recorder.get_recording()
	stream.save_to_wav("res://.tmp/audio-refresh/review/game-mix.wav")
	print("AUDIO TOUR OK: " + str(stream.get_length()) + " seconds; " + str(host.sound.get_child_count()) + " fixed players")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0)-1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.tmp/audio-refresh/review/player.png")
	get_tree().quit()
