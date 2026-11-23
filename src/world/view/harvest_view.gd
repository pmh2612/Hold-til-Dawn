class_name HarvestView
extends RefCounted

# Part of Main (main.gd); in the C# version this was src/world/view/Main.HarvestView.cs.
var harvest_collider_sources = []
var harvest_collider_nodes = []
var harvest_types = {}

var main: Main

func _init(host: Main) -> void:
	main = host

func node_colliders(records) -> Variant:
	if harvest_collider_sources.size() != records.size():
		harvest_collider_sources.clear()
		harvest_types.clear()
		harvest_collider_nodes = []
	var i: int = 0
	while i < records.size():
		var record = records[i]
		if i < harvest_collider_sources.size() and is_same(harvest_collider_sources[i], record):
			i += 1
			continue
		if i < harvest_collider_sources.size():
			harvest_types.erase(Vector2(harvest_collider_sources[i][1]))
		harvest_types[Vector2(record[1])] = int(record[0])
		if i < harvest_collider_sources.size():
			harvest_collider_sources[i] = record
			var node = harvest_collider_nodes[i]
			node["type"] = record[0]
			node["pos"] = record[1]
			node["amount"] = record[2]
			node["radius"] = record[4] if record.size() > 4 else null
		else:
			harvest_collider_sources.append(record)
			harvest_collider_nodes.append(Harvestables.from_snapshot(record))
		i += 1
	return harvest_collider_nodes

func gather_animation(target: Vector2) -> Variant:
	var type = harvest_types.get(target, 0)
	if not harvest_types.has(target):
		return null
	return "gather_wood" if type == 0 else "gather_stone" if type == 1 or type == 3 else "gather_herb" if type == 2 else null
