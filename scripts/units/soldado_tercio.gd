class_name SoldadoTercio
extends Unit
## Heavy Spanish pike infantry. Pike formation: +25% damage while at least
## two other Soldados stand within formation distance. Nearly useless in
## jungle (terrain modifiers in soldado_tercio.tres).

const PIKE_RADIUS := 70.0
const PIKE_BONUS := 1.25
const PIKE_REQUIRED := 2


func _ready() -> void:
	super()
	add_to_group("soldados")


func _perform_attack(target: Node2D) -> void:
	var nearby := 0
	for node in get_tree().get_nodes_in_group("soldados"):
		var soldado := node as Unit
		if soldado != null and soldado != self and soldado.state != State.DEAD \
				and global_position.distance_to(soldado.global_position) <= PIKE_RADIUS:
			nearby += 1
	var damage := current_damage()
	if nearby >= PIKE_REQUIRED:
		damage *= PIKE_BONUS
	target.take_damage(damage, self)
