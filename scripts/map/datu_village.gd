class_name DatuVillage
extends Node2D
## Neutral barangay — the Utang diplomacy target. Alignment flips via ally();
## each village allied to Mactan raises the income multiplier (+15%,
## ResourceManager listens to EventBus.datu_allied).

enum Alignment { NEUTRAL, ALLIED_MACTAN, ALLIED_SPAIN }

const TEXTURES := {
	Alignment.NEUTRAL: preload("res://assets/gen/village_neutral.png"),
	Alignment.ALLIED_MACTAN: preload("res://assets/gen/village_mactan.png"),
	Alignment.ALLIED_SPAIN: preload("res://assets/gen/village_spain.png"),
}

@export var datu_name := "Datu"

var alignment := Alignment.NEUTRAL

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("datu_villages")
	$NameLabel.text = datu_name


func ally(faction: String) -> void:
	var next := Alignment.NEUTRAL
	match faction:
		"mactan":
			next = Alignment.ALLIED_MACTAN
		"spain":
			next = Alignment.ALLIED_SPAIN
	if next == alignment:
		return
	alignment = next
	_sprite.texture = TEXTURES[alignment]
	EventBus.datu_allied.emit(datu_name, faction)
	EventBus.minimap_ping.emit(global_position)
	match alignment:
		Alignment.ALLIED_MACTAN:
			EventBus.hud_notification.emit("%s pledges his warriors to Mactan!" % datu_name)
		Alignment.ALLIED_SPAIN:
			EventBus.hud_notification.emit("%s has bent the knee to Spain." % datu_name)
		Alignment.NEUTRAL:
			EventBus.hud_notification.emit("%s withdraws to neutrality." % datu_name)
