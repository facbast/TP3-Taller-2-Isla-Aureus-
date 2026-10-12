extends Area2D
## Trigger de sonido ambiental (ej. zumbido de avispas para dar suspenso
## antes de presentarlas): al entrar el jugador reproduce el sonido
## elegido en el inspector.

enum Sonido {
	ZUMBIDO_SUSPENSE, # Zumbido de avispas previo a presentarlas
}

const SONIDOS: Dictionary = {
	Sonido.ZUMBIDO_SUSPENSE: preload("res://SFX/Panal/Zumbido_Suspenso.wav"),
}

# Qué sonido reproducir (dropdown en el inspector).
@export var sonido: Sonido = Sonido.ZUMBIDO_SUSPENSE
# true = suena una vez y el trigger se libera; false = re-suena al reentrar.
@export var una_sola_vez: bool = true
@export var volumen_db: float = 0.0

var _player: AudioStreamPlayer2D
var _disparado: bool = false

func _ready() -> void:
	_player = AudioStreamPlayer2D.new()
	_player.name = "AudioTrigger"
	_player.stream = SONIDOS.get(sonido)
	_player.volume_db = volumen_db
	add_child(_player)
	if una_sola_vez:
		_player.finished.connect(_on_sonido_terminado)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo: Node2D) -> void:
	if not cuerpo.is_in_group("player"):
		return
	if _player.stream == null:
		push_warning("TriggerSonido: sin stream para el sonido elegido.")
		return
	if una_sola_vez:
		if _disparado:
			return
		_disparado = true
		set_deferred("monitoring", false)
	if not _player.playing:
		_player.play()

func _on_sonido_terminado() -> void:
	queue_free()
