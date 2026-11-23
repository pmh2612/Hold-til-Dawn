class_name Harvestables
extends RefCounted
# Every tree, loose rock and herb-like plant scattered over the island is a resource, never a decorative duplicate.
# A landmark's own props (src/world/world_landmarks.gd) are not: they stay as scenery (WorldGeometry.cs).

static func type_of(sprite) -> int:
	for prefix in ["pine_", "lm_palm_", "lm_mangrove_", "lm_log_", "lm_sticks_"]:
		if sprite.begins_with(prefix):
			return 0
	for prefix in ["rock_", "crag_", "lm_shelf_", "lm_fossil_", "lm_cairn_"]:
		if sprite.begins_with(prefix):
			return 1
	for prefix in ["shrub_", "reed_", "lm_broadleaf_", "lm_ginger_", "lm_fern_", "lm_flowers_", "lm_bed_", "lm_pots_"]:
		if sprite.begins_with(prefix):
			return 2
	return -1

static func stage_sprite(sprite, stage: int) -> Variant:
	if stage == 5 and sprite.begins_with("node_titanium_"):
		return "ore_left_0"
	if stage == 5 and sprite.begins_with("node_herb_"):
		return "herb_cut_0"
	var split: int = sprite.rfind("_")
	return sprite.substr(0, split) + ("_empty_" if stage == 5 else "_dmg" + str(stage) + "_") + sprite.substr(split + 1)

static func radius(node) -> float:
	var custom = node.get("radius")
	var _t2
	var _sw1
	if custom != null:
		_t2 = float(custom)
	else:
		_sw1 = int(node.get("type"))
		_t2 = 8 if _sw1 == 0 else 19.84 if _sw1 == 1 else 19.2 if _sw1 == 3 else 0
	return _t2

static func from_snapshot(n) -> Variant:
	return {"type": n[0], "pos": n[1], "amount": n[2], "radius": n[4] if n.size() > 4 else null}

class Site:
	var pos: Vector2
	var sprite
	var type: int
	var radius: float

	func _init(p_pos = Vector2.ZERO, p_sprite = null, p_type = 0, p_radius = 0.0) -> void:
		pos = p_pos
		sprite = p_sprite
		type = p_type
		radius = p_radius

	func create_node() -> Variant:
		return {"type": type, "pos": pos, "amount": 5, "sprite": sprite, "radius": radius, "ambient": true}
