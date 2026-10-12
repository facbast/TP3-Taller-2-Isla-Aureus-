extends Area2D
## Trigger genérico de diálogo: se instancia en el nivel y en el inspector
## se elige qué escena de diálogo ejecutar (ej. la interferencia radial).
## La escena de diálogo se instancia al disparar, así el trigger es
## autocontenido como el TriggerSonido.

# Escena del diálogo a ejecutar (arrastrar el .tscn en el inspector).
@export var escena_dialogo: PackedScene
# true = dispara una vez y el trigger se libera; false = re-dispara al reentrar.
@export var una_sola_vez: bool = true

var _disparado: bool = false
var _dialogo: CanvasLayer = null

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo: Node2D) -> void:
	if _disparado:
		return
	if not (cuerpo.is_in_group("player") or cuerpo.is_in_group("Player") or cuerpo.name == "Player"):
		return
	if escena_dialogo == null:
		push_warning("TriggerDialogo: sin escena de diálogo asignada en el inspector.")
		return
	_disparado = true
	set_deferred("monitoring", false)
	# El diálogo vive en la escena actual (sobrevive al trigger).
	if not is_instance_valid(_dialogo):
		_dialogo = escena_dialogo.instantiate() as CanvasLayer
		if _dialogo == null or not _dialogo.has_method("iniciar_dialogo"):
			push_warning("TriggerDialogo: la escena asignada no es un diálogo válido.")
			return
		get_tree().current_scene.add_child(_dialogo)
	_dialogo.iniciar_dialogo()
	if una_sola_vez:
		queue_free()
