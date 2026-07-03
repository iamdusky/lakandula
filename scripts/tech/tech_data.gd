class_name TechData
extends Resource
## One research entry. Effects are identified by effect_id and applied in
## TechTree._apply_effect / queried through TechTree's modifier functions.

@export var id := ""
@export var display_name := ""
@export var description := ""
## Age gate: researching AGE_REQUIREMENT techs of the previous age unlocks
## the next age.
@export var age := 1
@export var cost: Dictionary = {}
@export var prerequisites: Array[String] = []
@export var effect_id := ""
