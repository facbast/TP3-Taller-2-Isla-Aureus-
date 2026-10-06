extends Area2D

@export var velocidad: float = 400.0
@export var dano: float = 10.0
@export var tiempo_vida: float = 3.0 # Segundos antes de desaparecer si no choca con nada
@export var tipo_dano: String = "Balistica"

var _tiempo_transcurrido: float = 0.0

func _ready():
	# Conectamos la señal de colisión por código para asegurarnos de que funcione
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Mover la bala hacia adelante basándonos en su rotación
	var direccion = Vector2.RIGHT.rotated(rotation)
	position += direccion * velocidad * delta
	
	# Destruir la bala después de un tiempo para evitar lag por exceso de balas perdidas
	_tiempo_transcurrido += delta
	if _tiempo_transcurrido >= tiempo_vida:
		queue_free()

func _on_body_entered(body: Node2D):
	# 1. Si la bala choca con el mismo enemigo que disparó u otro aliado, no hacemos nada
	if body.is_in_group("enemigos"):
		return
		
	# 2. Si la bala choca con el jugador, le aplicamos daño
	if body.is_in_group("player"):
		if body.has_method("recibir_dano"):
			body.recibir_dano(dano, tipo_dano)
	
	# 3. Si choca con el jugador o con cualquier otra cosa (paredes, suelo, etc.), se destruye
	queue_free()
