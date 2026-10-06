extends Area2D

# Configuración del checkpoint
@export var radio_seguridad: float = 800.0
@export var nombre_nivel: String = "res://Scenes/main.tscn"

# Nueva variable para la bandera verde
@export var textura_activada: Texture2D 

# Referencia al nodo de la imagen
@onready var sprite_bandera = $SpriteBandera

var fue_activado: bool = false

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo):
	if cuerpo.is_in_group("player") and not fue_activado:
		var hud = cuerpo.get_parent().get_node_or_null("HUD")
		
		# Validar si hay peligro cerca antes de proceder
		if _hay_peligro_cerca():
			if hud != null and hud.has_method("mostrar_notificacion"):
				hud.mostrar_notificacion("Hay enemigos cerca, no se puede guardar")
			return

		# Lectura segura del arma activa
		var nombre_arma_activa = ""
		if "_arma_actual" in cuerpo and cuerpo._arma_actual != null:
			nombre_arma_activa = cuerpo._arma_actual.name

		# Empaquetar estado del jugador
		var estado_jugador = {
			"salud": cuerpo.salud_actual,
			"escudo": cuerpo.escudo_actual,
			"frag": cuerpo.granadas_frag_actuales,
			"plasma": cuerpo.granadas_plasma_actuales,
			"arma_activa": nombre_arma_activa,
			"municion": {}
		}
		
		if "armas" in cuerpo:
			for arma in cuerpo.armas:
				if "municion_reserva" in arma:
					estado_jugador["municion"][arma.name] = arma.municion_reserva
				elif "bateria" in arma:
					estado_jugador["municion"][arma.name] = arma.bateria
					
		# Le pasamos el diccionario a Global
		Global.guardar_checkpoint(nombre_nivel, global_position, estado_jugador)
		fue_activado = true 

		# Feedback visual en el mapa y en el HUD
		if textura_activada != null and sprite_bandera != null:
			sprite_bandera.texture = textura_activada

		if hud != null and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("¡Progreso Guardado!")

func _hay_peligro_cerca() -> bool:
	var enemigos = get_tree().get_nodes_in_group("enemigos")
	for enemigo in enemigos:
		if is_instance_valid(enemigo) and "es_alerta" in enemigo and enemigo.es_alerta:
			var distancia = global_position.distance_to(enemigo.global_position)
			if distancia <= radio_seguridad:
				return true 
	return false
