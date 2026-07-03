class_name KutaMactanBuilding
extends Building
## The main fortress of Mactan. Its destruction is Spain's primary victory
## condition (VictoryManager polls the "kuta" group from Milestone 7).


func _ready() -> void:
	super()
	add_to_group("kuta")


func _on_destroyed() -> void:
	EventBus.hud_notification.emit("The Kuta has fallen!")
