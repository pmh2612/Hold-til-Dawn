class_name PauseMenuUi
extends RefCounted

# Part of Main (main.gd); in the C# version this was ui/menu/Main.PauseMenu.cs.
# Owner: Mai Thien Ngon. Pause state and the Esc key (section 6.3). The pause overlay and the result screen
# (section 2.5) are scenes: ui/menu/pause_screen.tscn and ui/menu/result_screen.tscn.
# A solo match pauses while the overlay is open; a network match will keep running (FTR-04).
var paused = false
static var CONTROLS = ["WASD move  |  Mouse aim  |  LMB attack / use item", "Hold E: gather, repair tower / door, revive", "Chest: hold E 2s + key; drag loot into bag", "1-4 / wheel: select  |  Tab bag  |  G give / drop", "Q bandage  |  RMB flask  |  C workbench / radio", "Engineer: T place tower; LMB confirm; RMB cancel", "F hold: enter base at night  |  V skip-day vote", "M island map (chest icons)  |  Ctrl + wheel zoom", "H show / hide controls  |  Esc pause / close"]

var main: Main

func _init(host: Main) -> void:
	main = host

# Esc closes an open panel first, then toggles the pause overlay.
func escape_key() -> void:
	if main.gameplay_hud.help_open:
		main.gameplay_hud.help_open = false
		return
	if main.minimap.map_big:
		main.minimap.map_big = false
		return
	if main.inventory.bag_open or main.craft_open or main.build_menu.build_open:
		main.inventory.bag_open = false
		main.craft_open = false
		main.build_menu.close_build()
		main.inventory.drag_from = null
		return
	if main.snap.get("ph", "") == "result":
		return
	paused = not paused
