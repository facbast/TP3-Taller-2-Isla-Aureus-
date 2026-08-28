extends Area2D

# Cargamos las texturas de las banderas
const BANDERA_ROJA = preload("res://Assets/Flag_Enemy.png")
const BANDERA_VERDE = preload("res://Assets/Flag_Player.png")

@onready var _sprite_bandera = $SpriteBandera
var _activado: bool = false

func _ready():
	# Aseguramos que inicie en rojo
	_sprite_bandera.texture = BANDERA_ROJA
	
	# Conectamos la señal de colisión (si no lo haces desde el editor)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Si ya fue activado, no hacemos nada
	if _activado:
		return
		
	# Si el que entra es el jugador
	if body.is_in_group("player"):
		if _es_seguro_guardar():
			activar_checkpoint()
		else:
			print("No se puede guardar: ¡Hay enemigos en alerta!")
			# Opcional: Aquí podrías llamar a un nodo de la interfaz para mostrar un mensaje al jugador.

func _es_seguro_guardar() -> bool:
	# Obtenemos todos los enemigos en la escena actual
	var enemigos = get_tree().get_nodes_in_group("enemigos")
	
	for enemigo in enemigos:
		# Verificamos si la variable 'es_alerta' existe y es verdadera
		if "es_alerta" in enemigo and enemigo.es_alerta:
			return false # Encontramos al menos un enemigo en alerta, no es seguro
			
	return true # Ningún enemigo está en alerta

func activar_checkpoint():
	_activado = true
	_sprite_bandera.texture = BANDERA_VERDE
	
	# Obtenemos la ruta de la escena actual
	var nivel_actual = get_tree().current_scene.scene_file_path
	
	# Guardamos la posición usando el Autoload Global
	Global.guardar_checkpoint(nivel_actual, global_position)
	print("¡Checkpoint guardado!")
