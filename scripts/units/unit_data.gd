class_name UnitData
extends Resource
## Stat sheet for a unit type. Behavior lives in scripts/units/, stats in
## resources/units/*.tres so balancing never touches code.

@export var display_name := "Unit"
@export var max_health := 60.0
@export var speed := 140.0
@export var damage := 10.0
## Flat damage reduction; attacks always deal at least 1. Bypassed by
## ignore_armor attacks (Juramentado's Matay) and poison.
@export var armor := 0.0
@export var attack_range := 28.0
@export var attack_interval := 1.0
@export var sight_range := 300.0
@export var cost: Dictionary = {}
@export var train_time := 5.0

## terrain_type -> multiplier; anything missing defaults to 1.0
@export var terrain_speed: Dictionary = {}
@export var terrain_damage: Dictionary = {}

@export var ability_name := ""
@export var ability_cooldown := 10.0

## Passive units (Fraile, Babaylan, training dummy) never auto-acquire
## targets and are never auto-acquired — they must be attacked deliberately.
@export var passive := false
