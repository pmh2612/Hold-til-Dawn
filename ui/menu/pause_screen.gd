class_name PauseScreen
extends Control
## Pause overlay (Esc, section 6.3): audio settings and Resume / Leave match. The layout is in
## ui/menu/pause_screen.tscn; the paused state and the Esc key stay in ui/menu/pause_menu.gd.
## Owner: Mai Thien Ngon.

var main: Main


func setup(host: Main) -> void:
	main = host
	HudLabels.style_title(%Title, main)
	HudLabels.style_title(%Resume, main)
	HudLabels.style_title(%Leave, main)
	setup_audio()
	%Resume.pressed.connect(func(): main.pause_menu.paused = false)
	%Leave.pressed.connect(func():
		main.pause_menu.paused = false
		main.back_to_menu("Left the match")
	)


func setup_audio() -> void:
	var levels := VBoxContainer.new()
	levels.name = "AudioLevels"
	levels.position = Vector2(26, 60)
	levels.size = Vector2(388, 88)
	levels.add_theme_constant_override("separation", 4)
	$Box.add_child(levels)
	for i in Sound.BUS.size():
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 24
		levels.add_child(row)
		var label := Label.new()
		label.text = Sound.BUS_LABEL[i]
		label.custom_minimum_size.x = 80
		label.add_theme_font_size_override("font_size", 11)
		HudLabels.style_text(label, main)
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = Sound.BUS[i]
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.value = main.sound.volume[i]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var percent := Label.new()
		percent.custom_minimum_size.x = 42
		percent.text = "%d%%" % roundi(slider.value * 100)
		percent.add_theme_font_size_override("font_size", 11)
		HudLabels.style_text(percent, main)
		row.add_child(percent)
		slider.value_changed.connect(func(value):
			main.sound.set_volume(i, value)
			percent.text = "%d%%" % roundi(value * 100)
		)


func _process(_delta: float) -> void:
	if main != null:
		visible = main.pause_menu.paused and main.snap.get("ph", "") in ["day", "dusk", "night", "result"]
