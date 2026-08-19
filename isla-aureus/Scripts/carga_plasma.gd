extends Area2D

var velocidad: float = 600
var dano: float = 60
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
	# Ignoramos si la bala choca con el Jugador usando la etiqueta de grupo
	if body.is_in_group("player"):
		return
		
	# Si el objeto contra el que chocó tiene la función recibir_dano (como el Grunt)
	if body.has_method("recibir_dano"):
		# --- NUEVO: ENVIAMOS EL TIPO DE DAÑO ---
		body.recibir_dano(dano, tipo_dano)
		
	# Se destruye la bala al impactar con un enemigo o con el suelo
	queue_free()

func _on_screen_exited():
	queue_free()
