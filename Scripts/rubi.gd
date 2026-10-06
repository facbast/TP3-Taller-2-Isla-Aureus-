extends Area2D

@onready var _sprite = $Sprite2D
@onready var _colision = $CollisionShape2D
@onready var _audio_rubi = $AudioRubi

func _ready():
	# Si ya lo recogimos en esta partida (checkpoint), no reaparece.
	if Global.estaba_eliminado(self):
		queue_free()
		return

func _on_body_entered(body):
	# Verificamos si lo que tocó el rubí es el jugador
	if body.is_in_group("player") and body.has_method("activar_sobreescudo"):
		# Intentamos activar el sobre-escudo
		var recogido = body.activar_sobreescudo()

		if recogido:
			Global.registrar_item_recogido(self)
			_reproducir_y_destruir()

func _reproducir_y_destruir():
	# Ocultamos el rubí y evitamos que se recoja dos veces
	_sprite.hide()
	_colision.set_deferred("disabled", true)
	
	# Reproducimos el sonido y esperamos a que termine
	if _audio_rubi and _audio_rubi.stream:
		_audio_rubi.play()
		await _audio_rubi.finished
		
	# Si lo recogió con éxito, eliminamos el rubí de la escena
	queue_free()
