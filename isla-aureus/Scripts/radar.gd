extends Control

@export var rango_deteccion_mundo: float = 800.0  # Distancia máxima en píxeles del mapa que cubre el radar
@export var radio_radar: float = 50.0             # Radio en píxeles de la interfaz del radar

var jugador: Node2D = null

func _process(_delta):
	# Buscar la referencia del jugador si aún no la tiene
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("player")
	
	# Forzar a Godot a redibujar el radar en cada fotograma
	queue_redraw()

func _draw():
	var centro = Vector2(radio_radar, radio_radar)
	
	# 1. Dibujar el fondo del radar (Círculo semitransparente estilo HUD con borde)
	draw_circle(centro, radio_radar, Color(0.148, 0.21, 0.26, 0.6))
	draw_arc(centro, radio_radar, 0, TAU, 32, Color(0.0, 0.523, 0.653, 0.8), 2.0)
	
	# 2. Dibujar al Jugador (Círculo amarillo centrado)
	draw_circle(centro, 4.0, Color.YELLOW)
	
	if jugador == null:
		return
		
	# 3. Dibujar a los Enemigos (Círculos rojos)
	var enemigos = get_tree().get_nodes_in_group("enemigos")
	for enemigo in enemigos:
		if is_instance_valid(enemigo) and enemigo is Node2D:
			# Vector de distancia relativa entre el enemigo y el jugador
			var diferencia_mundo = enemigo.global_position - jugador.global_position
			
			# Escalar la posición real en el juego al tamaño del radar en pantalla
			var pos_radar = diferencia_mundo * (radio_radar / rango_deteccion_mundo)
			
			# Solo dibujar si se encuentra dentro del alcance del radar
			if pos_radar.length() <= radio_radar:
				draw_circle(centro + pos_radar, 3.5, Color.RED)
