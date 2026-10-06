extends Area2D

# 1. Esto va a crear un espacio en el Inspector de Godot para que vincules tu CanvasLayer
@export var dialogo_canvas: CanvasLayer

func _on_body_entered(body: Node2D) -> void:
	# Diagnóstico: mira la pestaña Output al probar
	print("Trigger tocado por: ", body.name, " grupos: ", body.get_groups(), " tutorial_aceptado: ", Global.tutorial_aceptado)
	# 2. Nos aseguramos de que sea el jugador quien toca el área
	# El Player está en el grupo "player" (minúscula, ver player.tscn)
	if not (body.is_in_group("player") or body.is_in_group("Player") or body.name == "Player"):
		print("Trigger ignorado: no es el Player")
		return

	# Evita dobles disparos en el mismo frame
	set_deferred("monitoring", false)

	# Si el jugador omitió el tutorial, el trigger se descarta en silencio
	if not Global.tutorial_aceptado:
		print("Trigger descartado: tutorial no aceptado")
		queue_free()
		return

	# 3. Validamos que el CanvasLayer esté asignado y siga existiendo
	# (puede haber sido liberado si se omitió el tutorial)
	if is_instance_valid(dialogo_canvas) and dialogo_canvas.has_method("iniciar_dialogo"):
		# Llama a la función que muestra el canvas, pausa y arranca el texto
		print("Trigger activa dialogo: ", dialogo_canvas.name)
		dialogo_canvas.iniciar_dialogo()
	else:
		push_warning("TutorialGecko: dialogo_canvas no asignado o liberado.")

	# 4. Destruimos esta área para que el evento ocurra solo una vez
	queue_free()
