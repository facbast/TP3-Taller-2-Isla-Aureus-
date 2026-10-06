extends Area2D

@export var dialogo_canvas: CanvasLayer

func _on_body_entered(body: Node2D) -> void:
	print("Trigger Agacharse tocado por: ", body.name, " grupos: ", body.get_groups(), " tutorial_aceptado: ", Global.tutorial_aceptado)
	# El Player está en el grupo "player" (minúscula)
	if not (body.is_in_group("player") or body.is_in_group("Player") or body.name == "Player"):
		print("Trigger Agacharse ignorado: no es el Player")
		return

	set_deferred("monitoring", false)

	if not Global.tutorial_aceptado:
		print("Trigger Agacharse descartado: tutorial no aceptado")
		queue_free()
		return

	if is_instance_valid(dialogo_canvas) and dialogo_canvas.has_method("iniciar_dialogo"):
		print("Trigger Agacharse activa dialogo: ", dialogo_canvas.name)
		dialogo_canvas.iniciar_dialogo()
	else:
		push_warning("TutorialAgacharse: dialogo_canvas no asignado o sin iniciar_dialogo().")

	queue_free()
