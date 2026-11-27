extends SceneTree

# Offline native pixel icons matching the existing 16px item art.
func _initialize() -> void:
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var cloth := Color("4D8170")
	image.fill_rect(Rect2i(5, 0, 6, 4), Color("252A2D"))
	image.fill_rect(Rect2i(6, 1, 4, 2), Color("B5BBA6"))
	image.fill_rect(Rect2i(2, 4, 12, 11), Color("252A2D"))
	image.fill_rect(Rect2i(3, 5, 10, 9), cloth.darkened(0.25))
	image.fill_rect(Rect2i(3, 3, 10, 5), cloth)
	image.fill_rect(Rect2i(4, 4, 8, 1), cloth.lightened(0.25))
	image.fill_rect(Rect2i(4, 9, 8, 4), cloth)
	for x in [5, 10]:
		image.fill_rect(Rect2i(x, 5, 1, 7), Color("D0B785"))
		image.fill_rect(Rect2i(x, 7, 1, 2), Color("E4D594"))
	for i in range(2):
		image.fill_rect(Rect2i(5 + i * 2, 12, 1, 1), Color("F1DB97"))
	assert(image.save_png("res://art/items/backpack.png") == OK)
	print("BAG ART OK: one backpack pixel icon")
	quit()
