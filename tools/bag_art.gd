extends SceneTree

# Offline native pixel icon for the Cargo frame (wood, stone and titanium load frame).
func _initialize() -> void:
	var pal_ = PixelItems.pal(PixelItems.wood, PixelItems.stone, PixelItems.steel, {"B": "D2E6FF", "T": "7FA6F5", "t": "4A6AD8"})
	var rows = ["...BBBBBBBBBB...", "..BT........Tt..", "..BTWWWWWWWWtT..", "..BTwBwwwwBwtT..", "..SSwTvvvvTwSS..", "..ssWBBBBBBWss..", "..BTWWwSSwWWtT..", "..BTwwsSSswwtT..", "..BTvvvqqvvvtT..", "..SSWWWWWWWWSS..", "..ssvvvvvvvvss..", "..BTBBBBBBBBtT..", "..oo........oo.."]
	var image: Image = PixelItems.draw(rows, pal_, PixelItems.icon, PixelItems.icon)
	assert(image.save_png("res://art/items/cargo_frame.png") == OK)
	print("BAG ART OK: one cargo_frame pixel icon")
	quit()
