extends Area2D

var velocidad: float = 1200.0
var dano: float = 10.0
@export var tipo_dano: String = "Balistica"
@export var efecto_impacto: PackedScene # Opcional: Escena de chispas/partículas

@onready var audio_disparo: AudioStreamPlayer2D = get_node_or_null("AudioDisparo")

func _ready():
	body_entered.connect(_on_body_entered)
	
	var notificador = get_node_or_null("VisibleOnScreenNotifier2D")
	if notificador != null:
		notificador.screen_exited.connect(_on_screen_exited)
		
	# Reproduce el sonido de disparo al instanciar la bala
	if audio_disparo and audio_disparo.stream:
		audio_disparo.play()

func _physics_process(delta):
	position += transform.x * velocidad * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		return
		
	if body.has_method("recibir_dano"):
		body.recibir_dano(dano, tipo_dano)
		
	_generar_impacto()
	queue_free()

func _generar_impacto():
	if efecto_impacto:
		var impacto = efecto_impacto.instantiate()
		impacto.global_position = global_position
		get_parent().add_child(impacto)

func _on_screen_exited():
	queue_free()
