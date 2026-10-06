extends Area2D

# Cambia esta ruta por la ruta real de tu menú principal
const RUTA_MENU_PRINCIPAL = "res://Scenes/menu_principal.tscn"

func _ready():
	# Conectamos la señal de colisión por código
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Verificamos que quien tocó la bandera sea el jugador
	if body.is_in_group("player"):
		# Usamos tu sistema actual para mostrar el mensaje
		var hud = body.get_parent().get_node_or_null("HUD")
		if hud != null:
			hud.mostrar_notificacion("¡Felicidades por terminar la demo!")
		else:
			print("¡Felicidades por terminar la demo!")
			
		# Desactivamos la colisión de la bandera para que no se active 2 veces
		set_deferred("monitoring", false)


		await get_tree().create_timer(3.5).timeout

		# Fundido a negro con el overlay del HUD antes de volver al título
		if hud != null and hud.has_method("hacer_fade_out"):
			await hud.hacer_fade_out(1.5).finished

		# Cambiamos de escena al menú principal
		get_tree().change_scene_to_file("res://Scenes/pantalla_titulo.tscn")
