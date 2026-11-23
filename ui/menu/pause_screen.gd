class_name PauseScreen
extends Control
## Pause overlay (Esc, section 6.3): the controls and Resume / Leave match. The layout is in
## ui/menu/pause_screen.tscn; the paused state and the Esc key stay in ui/menu/pause_menu.gd.
## Owner: Mai Thien Ngon.

var main: Main


func setup(host: Main) -> void:
	main = host
	%Controls.text = "\n".join(PauseMenuUi.CONTROLS)
	HudLabels.style_title(%Title, main)
	HudLabels.style_text(%Controls, main)
	HudLabels.style_title(%Resume, main)
	HudLabels.style_title(%Leave, main)
	%Resume.pressed.connect(func(): main.pause_menu.paused = false)
	%Leave.pressed.connect(func():
		main.pause_menu.paused = false
		main.back_to_menu("Left the match")
	)


func _process(_delta: float) -> void:
	if main != null:
		visible = main.pause_menu.paused and main.snap.get("ph", "") in ["day", "dusk", "night", "result"]
