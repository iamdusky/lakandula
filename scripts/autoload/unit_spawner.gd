extends Node
## Affordability-checked unit creation. All unit spawning (training queues,
## AI reinforcements, diplomacy rewards) funnels through spawn().

## free_of_charge: cost already paid (e.g. Building queued the unit).
func spawn(scene: PackedScene, world_pos: Vector2, faction: String, free_of_charge := false) -> Unit:
	var unit := scene.instantiate() as Unit
	if unit == null:
		push_error("UnitSpawner: scene %s is not a Unit" % scene.resource_path)
		return null
	if not free_of_charge:
		var cost: Dictionary = unit.data.cost if unit.data != null else {}
		if not ResourceManager.can_afford(faction, cost):
			unit.free()
			EventBus.resource_spend_failed.emit(faction, cost)
			return null
		ResourceManager.spend(faction, cost)
	unit.faction = faction
	unit.position = world_pos
	_units_container().add_child(unit)
	EventBus.unit_spawned.emit(unit)
	return unit


func _units_container() -> Node:
	var scene := get_tree().current_scene
	var container := scene.get_node_or_null("Units")
	return container if container != null else scene
