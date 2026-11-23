class_name HudLabels
extends RefCounted
## The look of Main.text() for Label and Button nodes: Oswald for titles, Noto Sans otherwise, and the same
## dark outline (2 px up to size 12, 3 px under 20, else 4). The font size is set in the scene.
## Owner: Mai Thien Ngon.


static func style_title(c: Control, main: Main) -> void:
	_style(c, main.font_title)


static func style_text(c: Control, main: Main) -> void:
	_style(c, main.font_ui)


static func _style(c: Control, font: Font) -> void:
	c.add_theme_font_override("font", font)
	var size: int = c.get_theme_font_size("font_size")
	c.add_theme_constant_override("outline_size", 2 if size <= 12 else 3 if size < 20 else 4)
	c.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
