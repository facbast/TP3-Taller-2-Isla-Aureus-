extends Area2D

@export var dialogo_canvas: CanvasLayer

func _on_body_entered(body: Node2D) -> void:
	print("Trigger Sigilo tocado por: ", body.name, " grupos: ", body.get_groups(), " tutorial_aceptado: ", Global.tutorial_aceptado)
	# El Player está en el grupo "player" (minúscula)
	if not (body.is_in_group("player") or body.is_in_group("Player") or body.name == "Player"):
		print("Trigger Sigilo ignorado: no es el Player")
		return

	set_deferred("monitoring", false)

	# El caimán despierta pase lo que pase al pisar el trigger.
	# Si esto quedara detrás del chequeo de tutorial_aceptado, rechazar
	# el tutorial lo dejaría dormido (invencible) para siempre.
	var hay_objetivo = false
	for n in get_tree().get_nodes_in_group("enemigos_dormidos_tutorial"):
		if is_instance_valid(n):
			hay_objetivo = true
			break

	if hay_objetivo:
		get_tree().call_group("enemigos_dormidos_tutorial", "despertar_tutorial")

	if not Global.tutorial_aceptado:
		print("Trigger Sigilo descartado: tutorial no aceptado (caimán despierto igual)")
		queue_free()
		return

	# Opción 4: si el caimán objetivo ya no estaba dormido (muerto o ya en
	# combate), la lección no tiene sentido y se descarta en silencio.
	if not hay_objetivo:
		print("Trigger Sigilo descartado: sin objetivo dormido")
		queue_free()
		return

	if is_instance_valid(dialogo_canvas) and dialogo_canvas.has_method("iniciar_dialogo"):
		print("Trigger Sigilo activa dialogo: ", dialogo_canvas.name)
		dialogo_canvas.iniciar_dialogo()
	else:
		push_warning("TutorialSigilo: dialogo_canvas no asignado o sin iniciar_dialogo().")

	queue_free()
