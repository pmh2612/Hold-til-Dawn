class_name HudLayer
extends Control
## One layer of the in-game HUD (ui/gameplay/hud.tscn). The layers are drawn in their order in the scene,
## each by its own part of Main (ui/gameplay/hud.gd says which). Every layer redraws each frame.
## Owner: Mai Thien Ngon.

@export_enum("overlay", "craft", "status", "minimap", "markers", "hotbar", "build", "bag", "hurt") var layer: String = "status"

var main: Main


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main != null:
		main.hud_ui.draw_layer(self, layer)
