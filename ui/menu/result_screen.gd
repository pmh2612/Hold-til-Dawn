class_name ResultScreen
extends Control
## Result screen (section 2.5): win or loss with its cause, the night reached and a row per player
## (kills, revives, damage dealt and taken); Back to lobby. The layout is in ui/menu/result_screen.tscn.
## Owner: Mai Thien Ngon.

# column titles and their x in the table
const COLUMNS = [["PLAYER", 0.0], ["ROLE", 190.0], ["KILLS", 290.0], ["REVIVES", 360.0], ["DAMAGE", 440.0], ["TAKEN", 515.0]]
const ROW_H = 22.0

var main: Main
var shown_rows = null


func setup(host: Main) -> void:
	main = host
	HudLabels.style_title(%Title, main)
	HudLabels.style_text(%Cause, main)
	HudLabels.style_text(%Night, main)
	HudLabels.style_title(%Back, main)
	%Back.pressed.connect(func(): main.act("lobby"))


func _process(_delta: float) -> void:
	if main == null:
		return
	var r = main.snap.get("result", null)
	visible = main.snap.get("ph", "") == "result" and r != null
	if not visible:
		shown_rows = null
		return
	var win: bool = r[0]
	%Title.text = "MISSION COMPLETE" if win else "BEACON LOST"
	%Title.add_theme_color_override("font_color", Main.GOLD if win else Main.NEON_RED)
	%Cause.text = r[1]
	%Night.text = "Night %d / 5" % [r[2]]
	var rows = []
	for id in main.snap.ps:
		var p = main.snap.ps[id]
		rows.append([p[1], [p[0], GameSim.ROLES[p[1]], Cs.s(p[17]), Cs.s(p[28]), Cs.s(int(p[18])), Cs.s(int(p[29]))]])
	if rows != shown_rows:
		shown_rows = rows
		_fill_table(rows)


func _fill_table(rows) -> void:
	for child in %Table.get_children():
		child.queue_free()
	for col in COLUMNS:
		_cell(col[0], Vector2(col[1], 18.0), 12, Main.GOLD, true)
	var y: float = 18.0
	for row in rows:
		y += ROW_H
		for i in range(6):
			_cell(row[1][i], Vector2(COLUMNS[i][1], y), 12, Main.ROLE_COL[row[0]] if i == 1 else Color.WHITE, false)


# a table cell whose text baseline sits at `baseline` (as Main.text draws it)
func _cell(s, baseline: Vector2, size: int, col: Color, title: bool) -> void:
	var l = Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if title:
		HudLabels.style_title(l, main)
	else:
		HudLabels.style_text(l, main)
	l.position = baseline - Vector2(0, l.get_theme_font("font").get_ascent(size))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Table.add_child(l)
