extends Area2D

@onready var _sprite = $Sprite2D
@onready var _colision = $CollisionShape2D
@onready var _audio_curar = $AudioCurar

func _ready():
	# Si ya lo recogimos en esta partida (checkpoint), no reaparece.
	if Global.estaba_eliminado(self):
		queue_free()
		return
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("curar_salud_completa"):
		if body.curar_salud_completa():
			Global.registrar_item_recogido(self)
			_reproducir_y_destruir()

func _reproducir_y_destruir():
	# Ocultamos la imagen y desactivamos la colisión inmediatamente
	_sprite.hide()
	_colision.set_deferred("disabled", true)
	
	# Reproducimos el sonido y esperamos a que finalice antes de eliminar la escena
	if _audio_curar and _audio_curar.stream:
		_audio_curar.play()
		await _audio_curar.finished
		
	queue_free()
