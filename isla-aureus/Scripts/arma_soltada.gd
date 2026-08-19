extends Area2D

var tipo_arma: String = "Pistola"
var municion_contenida: int = 16 
var textura_arma: Texture2D = null

var _jugador: Node2D = null
var _tiempo_mantenido: float = 0.0
var _tiempo_necesario: float = 0.5 

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if textura_arma != null:
		$Sprite2D.texture = textura_arma

func _process(delta):
	# Si el jugador está sobre el arma (y no recogió la munición automáticamente)
	if _jugador != null:
		if Input.is_physical_key_pressed(KEY_E):
			_tiempo_mantenido += delta
			if _tiempo_mantenido >= _tiempo_necesario:
				_intercambiar_arma()
		else:
			_tiempo_mantenido = 0.0

func _on_body_entered(body):
	if body.is_in_group("player"):
		# 1. Al tocarla, intentamos absorber la munición de inmediato
		if body.has_method("recoger_arma"):
			var recogio_municion = body.recoger_arma(tipo_arma, municion_contenida)
			
			if recogio_municion:
				# Si ya teníamos el arma, absorbemos las balas y esta desaparece
				queue_free()
				return 
				
		# 2. Si NO teníamos el arma, se queda en el suelo y preparamos la lógica para intercambiarla
		_jugador = body

func _on_body_exited(body):
	if body == _jugador:
		_jugador = null
		_tiempo_mantenido = 0.0

func _intercambiar_arma():
	# (Aquí programaremos el intercambio de armas más adelante)
	print("¡Has intercambiado tu arma por la ", tipo_arma, "!")
	queue_free()
