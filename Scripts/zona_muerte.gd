extends Area2D
## Death zone (p. ej. pozos sin fondo): lo que cae dentro muere.
## - Jugador y enemigos: daño letal (pasa por su _morir/recibir_dano normal,
##   con fade, respawn en checkpoint y registro de bajas incluido).
## - Objetos rígidos sueltos (granadas, etc.): se eliminan para que no
##   caigan eternamente consumiendo física.

const DANO_LETAL: float = 99999.0

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo: Node2D):
	if cuerpo.is_in_group("player") or cuerpo.is_in_group("enemigos"):
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(DANO_LETAL, "Caida")
	elif cuerpo is RigidBody2D:
		cuerpo.queue_free()
