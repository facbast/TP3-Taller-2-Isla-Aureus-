extends Area2D
## Trigger de un solo disparo para la interferencia radial del Nivel 2.
## Punto de trama: dispara siempre, haya aceptado o no el tutorial.

@export var dialogo_canvas: CanvasLayer

var _disparado: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo: Node2D) -> void:
	if _disparado:
		return
	if not (cuerpo.is_in_group("player") or cuerpo.is_in_group("Player") or cuerpo.name == "Player"):
		return
	_disparado = true
	set_deferred("monitoring", false)
	if is_instance_valid(dialogo_canvas) and dialogo_canvas.has_method("iniciar_dialogo"):
		dialogo_canvas.iniciar_dialogo()
	else:
		push_warning("TriggerInterferencia: dialogo_canvas no asignado o sin iniciar_dialogo().")
	queue_free()
