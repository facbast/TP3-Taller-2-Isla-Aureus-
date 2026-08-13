extends CharacterBody2D

@export var velocidad: float = 180.0
@export var distancia_deteccion: float = 250.0
@export var salud: float = 30.0

@onready var _sprite = $Sprite2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _jugador: Node2D = null

func _ready():
	# Buscar al jugador en la escena por grupo o por nombre directo
	_jugador = get_tree().get_first_node_in_group("player")
	if _jugador == null:
		_jugador = get_parent().get_node_or_null("Player")

func _physics_process(delta):
	# Aplicar gravedad para que no flote en el aire
	if not is_on_floor():
		velocity.y += gravity * delta

	if _jugador != null:
		var distancia = global_position.distance_to(_jugador.global_position)
		
		# Si el jugador está dentro del rango de huida
		if distancia < distancia_deteccion:
			# Determinar dirección horizontal opuesta al jugador (-1 si el jugador está a la derecha, 1 a la izquierda)
			var direccion_x = sign(global_position.x - _jugador.global_position.x)
			
			if direccion_x != 0:
				velocity.x = direccion_x * velocidad
				# Voltear el sprite según la dirección hacia la que huye
				_sprite.flip_h = (direccion_x < 0)
			else:
				velocity.x = move_toward(velocity.x, 0, velocidad)
		else:
			# Si el jugador está lejos, se queda quieto
			velocity.x = move_toward(velocity.x, 0, velocidad)
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad)

	move_and_slide()

# Función para ser destruido por las balas
func recibir_dano(cantidad: float):
	salud -= cantidad
	if salud <= 0:
		queue_free()
