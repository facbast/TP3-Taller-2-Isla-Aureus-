extends Area2D

var velocidad: float = 600.0
var es_de_enemigo: bool = false
var dano: float = 50 # Buff: rompe escudos al instante y deja 15 en carne (x0.5 del elite).
@export var tipo_dano: String = "Plasma"
@export var efecto_impacto: PackedScene

@onready var audio_disparo: AudioStreamPlayer2D = get_node_or_null("AudioDisparo")

func _ready():
	body_entered.connect(_on_body_entered)
	
	var notificador = get_node_or_null("VisibleOnScreenNotifier2D")
	if notificador != null:
		notificador.screen_exited.connect(_on_screen_exited)
		
	if audio_disparo and audio_disparo.stream:
		audio_disparo.pitch_scale = 0.85 # Tono más grave y pesado
		audio_disparo.play()

func _physics_process(delta):
	position += transform.x * velocidad * delta

func _on_body_entered(body):
	if es_de_enemigo:
		if body.is_in_group("player"):
			if body.has_method("recibir_dano"):
				body.recibir_dano(dano, tipo_dano)
			_generar_impacto()
			queue_free()
		elif not body.is_in_group("enemigos"):
			_generar_impacto()
			queue_free()
	else:
		if body.is_in_group("enemigos"):
			if body.has_method("recibir_dano"):
				body.recibir_dano(dano, tipo_dano)
			_generar_impacto()
			queue_free()
		elif not body.is_in_group("player"):
			_generar_impacto()
			queue_free()

func _generar_impacto():
	if efecto_impacto:
		var impacto = efecto_impacto.instantiate()
		impacto.global_position = global_position
		get_parent().add_child(impacto)

func _on_screen_exited():
	queue_free()
