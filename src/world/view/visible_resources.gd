class_name VisibleResourcesView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.VisibleResources.cs.
var resource_scene_index = SceneIndex.new()
var deco_scene_index = SceneIndex.new()

var main: Main

func _init(host: Main) -> void:
	main = host

class SceneIndex:
	var count: int = -1
	var source
	var cells = {}

	func visible(rows, position_field: int, view: Rect2, fixed_source: bool = false) -> Variant:
		var _yield = []
		if count != rows.size() or fixed_source and not is_same(source, rows):
			count = rows.size()
			source = rows
			cells.clear()
			var i: int = 0
			while i < rows.size():
				var cell = Vector2i((Vector2(rows[i][position_field]) / 256).floor())
				var bucket = cells.get(cell, null)
				if not cells.has(cell):
					bucket = []
					cells[cell] = bucket
				bucket.append(i)
				i += 1
		var lo = Vector2i((view.position / 256).floor())
		var hi = Vector2i((view.end / 256).floor())
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var bucket = cells.get(Vector2i(x, y), null)
				if cells.has(Vector2i(x, y)):
					for i in bucket:
						var row = rows[i]
						if view.has_point(Vector2(row[position_field])):
							_yield.append(row)
							# TODO(cs2gd): yield (iterator method) needs a manual rewrite
		return _yield
