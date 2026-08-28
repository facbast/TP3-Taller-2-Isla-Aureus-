extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("curar_salud_completa"):
		if body.curar_salud_completa():
			queue_free() # Se destruye únicamente si el jugador necesitó curarse
