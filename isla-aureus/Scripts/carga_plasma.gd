extends Area2D

var velocidad: float = 600
var es_de_enemigo: bool = false
var dano: float = 10.0
@export var tipo_dano: String = "Plasma"

func _ready():
	# Conectamos la señal de colisión por código para asegurar que detecte cuerpos
	body_entered.connect(_on_body_entered)
	
	# Conectamos la señal del notificador de pantalla si existe en la escena
	var notificador = get_node_or_null("VisibleOnScreenNotifier2D")
	if notificador != null:
		notificador.screen_exited.connect(_on_screen_exited)

func _physics_process(delta):
	position += transform.x * velocidad * delta

func _on_body_entered(body):
	# CASO A: La bala la disparó un GECKO / ENEMIGO
	if es_de_enemigo:
		if body.is_in_group("player"):
			if body.has_method("recibir_dano"):
				# Pasamos la variable tipo_dano en lugar de dejarlo vacío
				body.recibir_dano(dano, tipo_dano) 
			queue_free()
		elif not body.is_in_group("enemigos"):
			queue_free()

	# CASO B: La bala la disparó el JUGADOR
	else:
		if body.is_in_group("enemigos"):
			if body.has_method("recibir_dano"):
				# Pasamos la variable tipo_dano en lugar de "Plasma" fijo
				body.recibir_dano(dano, tipo_dano) 
			queue_free()
		elif not body.is_in_group("player"):
			queue_free()

func _on_screen_exited():
	queue_free()
