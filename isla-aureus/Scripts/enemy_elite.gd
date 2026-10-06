extends CharacterBody2D

const SPEED = 170.0 
const FALL_GRAVITY_MULTIPLIER = 1.8 

# --- ESCUDOS Y SALUD ---
@export var salud_maxima: float = 100.0
var salud_actual: float = 100.0

@export var escudo_maximo: float = 100.0 
var escudo_actual: float = 100.0

var tiempo_espera_escudo: float = 5 
var tiempo_sin_dano: float = 0.0
var velocidad_recarga_escudo: float = 35.0

# --- RANGOS TÁCTICOS DE COMBATE ---
@export var distancia_ataque: float = 420.0
@export var distancia_minima: float = 200.0 

# --- LANZAMIENTO DE GRANADAS ---
const ESCENA_GRANADA = preload("res://Scenes/granada.tscn")
var temporizador_granada: float = 5.0
var distancia_min_lanzar: float = 200.0
var distancia_max_lanzar: float = 450.0
var fuerza_lanzamiento_granada: float = 520.0

# --- REFERENCIAS A NODOS ---
@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo
@onready var _arma_actual = $PivoteBrazo/RiflePlasma

const ARMA_SOLTADA = preload("res://Scenes/arma_soltada.tscn")

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _mirando_derecha = true
var _jugador = null
var _tween_escudo: Tween 

# --- SISTEMA DE SIGILO Y VISIÓN ---
@export var angulo_vision: float = 70.0    # Apertura en grados del cono
@export var distancia_vision: float = 380.0 # Alcance máximo de la linterna
var es_alerta: bool = false               # Estado de combate activado

@export var mirar_izquierda_al_inicio: bool = false

# --- VARIABLES DE EVASIÓN DE GRANADAS ---
@export var distancia_peligro_granada: float = 180.0
@export var multiplicador_velocidad_panico: float = 1.3

func _ready():
	salud_actual = salud_maxima
	escudo_actual = escudo_maximo

	# Si la casilla está marcada en el Inspector, voltea al enemigo al nacer
	if mirar_izquierda_al_inicio:
		_flip_personaje()

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta
		else:
			velocity.y += gravity * delta

	_procesar_recarga_escudo(delta)

	# Cooldown de granada
	if temporizador_granada > 0:
		temporizador_granada -= delta

	if not is_instance_valid(_jugador):
		_buscar_jugador()

	# 1. ESCANEO DE SUPERVIVENCIA (Rastrear granadas cercanas)
	var granadas = get_tree().get_nodes_in_group("granadas")
	var granada_mas_peligrosa: Node2D = null
	var distancia_mas_corta = distancia_peligro_granada

	for g in granadas:
		if is_instance_valid(g):
			var dist = global_position.distance_to(g.global_position)
			if dist < distancia_mas_corta:
				distancia_mas_corta = dist
				granada_mas_peligrosa = g

	# Una granada cercana activa la alerta inmediatamente
	if granada_mas_peligrosa != null:
		es_alerta = true

	# --- SISTEMA DE SIGILO Y DETECCIÓN ---
	if not es_alerta:
		queue_redraw()
		if _detectar_jugador_en_cono():
			es_alerta = true

	# 2. MÁQUINA DE ESTADOS (Evadir Granada vs Combate Normal)
	if granada_mas_peligrosa != null:
		# --- ESTADO: HUIR DE GRANADA ---
		var direccion_escape = sign(global_position.x - granada_mas_peligrosa.global_position.x)
		if direccion_escape == 0:
			direccion_escape = 1 if randf() > 0.5 else -1
			
		velocity.x = direccion_escape * (SPEED * multiplicador_velocidad_panico)
		
		if is_instance_valid(_jugador):
			_apuntar_al_jugador()

	elif es_alerta and is_instance_valid(_jugador):
		# --- ESTADO DE COMBATE NORMAL ---
		var dist = global_position.distance_to(_jugador.global_position)
		var tiene_visibilidad = _tiene_linea_de_vision()
		
		_apuntar_al_jugador()

		if dist <= distancia_ataque:
			if tiene_visibilidad:
				if temporizador_granada <= 0 and dist >= distancia_min_lanzar and dist <= distancia_max_lanzar:
					_lanzar_granada()
					temporizador_granada = randf_range(5.0, 9.0)

				if _arma_actual.has_method("intentar_disparar"):
					_arma_actual.intentar_disparar()

			# Kiting / Posicionamiento
			if dist < distancia_minima:
				var dir_huida = (global_position - _jugador.global_position).normalized()
				velocity.x = dir_huida.x * SPEED
			elif dist > distancia_minima + 60.0:
				var dir_avance = (_jugador.global_position - global_position).normalized()
				velocity.x = dir_avance.x * (SPEED * 0.7)
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
func _lanzar_granada():
	if not is_instance_valid(_jugador): return

	var nueva_granada = ESCENA_GRANADA.instantiate()
	get_parent().add_child(nueva_granada)
	
	var direccion_jugador = (_jugador.global_position - global_position).normalized()
	direccion_jugador.y -= 0.6
	direccion_jugador = direccion_jugador.normalized()
	
	var pos_origen = global_position + Vector2(0, -30)
	var pos_destino = pos_origen + (direccion_jugador * 40.0)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(pos_origen, pos_destino)
	query.exclude = [self]
	var res = space_state.intersect_ray(query)
	
	if res:
		nueva_granada.global_position = res.position - (direccion_jugador * 5.0)
	else:
		nueva_granada.global_position = pos_destino

	nueva_granada.add_collision_exception_with(self)
	nueva_granada.apply_central_impulse(direccion_jugador * fuerza_lanzamiento_granada)
	
func _procesar_recarga_escudo(delta):
	if escudo_actual < escudo_maximo:
		tiempo_sin_dano += delta
		if tiempo_sin_dano >= tiempo_espera_escudo:
			escudo_actual = min(escudo_actual + velocidad_recarga_escudo * delta, escudo_maximo)

func _buscar_jugador():
	var jugadores = get_tree().get_nodes_in_group("player")
	if jugadores.size() > 0:
		_jugador = jugadores[0]

func _apuntar_al_jugador():
	if not _jugador: return
	
	var pos_objetivo = _jugador.global_position + Vector2(0, -20)
	_pivote_brazo.look_at(pos_objetivo)

	var dir_x = pos_objetivo.x - global_position.x
	if (dir_x > 0 and not _mirando_derecha) or (dir_x < 0 and _mirando_derecha):
		_flip_personaje()

	var pos_relativa = to_local(pos_objetivo)
	if pos_relativa.x < 0:
		_pivote_brazo.scale.y = -1
	else:
		_pivote_brazo.scale.y = 1

func _flip_personaje():
	_mirando_derecha = not _mirando_derecha
	_sprite_cuerpo.flip_h = not _sprite_cuerpo.flip_h
	_pivote_brazo.position.x = -_pivote_brazo.position.x

func recibir_dano(cantidad: float, tipo_dano: String = "Balistica"):
	# --- BAJA INSTANTÁNEA POR SIGILO ---
	if tipo_dano == "Melee" and not es_alerta:
		salud_actual = 0
		escudo_actual = 0
		_morir()
		return

	# Rompe el sigilo al ser atacado
	es_alerta = true
	queue_redraw()

	tiempo_sin_dano = 0.0
	var tenia_escudo = escudo_actual > 0

	# --- REGLA ESPECIAL: RUPTURA INSTANTÁNEA DE ESCUDOS ---
	if tenia_escudo and (tipo_dano == "PlasmaCargado" or tipo_dano == "Explosivo"):
		escudo_actual = 0
		_mostrar_efecto_ruptura_escudo()

	# Multiplicadores base
	var mult_escudo = 1.0
	var mult_salud = 1.0

	# --- ASIGNACIÓN DE MULTIPLICADORES ---
	match tipo_dano:
		"Plasma":
			mult_escudo = 2.0
			mult_salud = 0.5
		"PlasmaCargado":
			mult_salud = 0.5  
		"Explosivo":
			mult_salud = 1.5  
		"Balistica", _:
			mult_escudo = 0.5 
			mult_salud = 1.5  

	# --- APLICACIÓN DEL DAÑO ---
	if escudo_actual > 0:
		escudo_actual -= cantidad * mult_escudo
		if escudo_actual <= 0:
			var sobrante = abs(escudo_actual) / mult_escudo
			escudo_actual = 0
			salud_actual -= sobrante * mult_salud
			_mostrar_efecto_ruptura_escudo()
	else:
		salud_actual -= cantidad * mult_salud

	if tenia_escudo and escudo_actual > 0:
		_mostrar_efecto_escudo()

	if salud_actual <= 0:
		salud_actual = 0
		_morir()

func _mostrar_efecto_escudo():
	if _tween_escudo and _tween_escudo.is_running():
		_tween_escudo.kill()

	modulate = Color(0.2, 0.9, 1.0)
	_tween_escudo = create_tween()
	_tween_escudo.tween_property(self, "modulate", Color.WHITE, 0.5)

func _morir():
	_soltar_arma()
	_intentar_soltar_granada()
	queue_free()

func _soltar_arma():
	var arma_caida = ARMA_SOLTADA.instantiate()
	arma_caida.tipo_arma = "RiflePlasma"
	if "bateria" in _arma_actual:
		arma_caida.cantidad_municion = _arma_actual.bateria
	else:
		arma_caida.cantidad_municion = 100

	var sprite = _arma_actual.get_node_or_null("Sprite2D")
	if sprite:
		arma_caida.textura_arma = sprite.texture
		arma_caida.scale = sprite.scale

	get_parent().call_deferred("add_child", arma_caida)
	arma_caida.global_position = global_position

func _intentar_soltar_granada():
	if randf() <= 0.35: # Probabilidad del 35%
		var granada_caida = ARMA_SOLTADA.instantiate()
		granada_caida.tipo_arma = "Granada"
		granada_caida.cantidad_municion = 1
		granada_caida.scale = Vector2(0.05, 0.05)
		get_parent().call_deferred("add_child", granada_caida)
		granada_caida.global_position = global_position + Vector2(randf_range(-15.0, 15.0), 0)

func _mostrar_efecto_ruptura_escudo():
	if _tween_escudo and _tween_escudo.is_running():
		_tween_escudo.kill()

	# Parpadeo en color rojo brillante para indicar la ruptura
	modulate = Color(1.0, 0.2, 0.2)
	_tween_escudo = create_tween()
	_tween_escudo.tween_property(self, "modulate", Color.WHITE, 0.5)

func _tiene_linea_de_vision() -> bool:
	if not is_instance_valid(_jugador): 
		return false
	
	var space_state = get_world_2d().direct_space_state
	# Lanzamos un rayo desde el enemigo hacia el centro del jugador
	var parametro_rayo = PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -15), _jugador.global_position + Vector2(0, -15))
	parametro_rayo.exclude = [self] # Ignorar la colisión del propio enemigo
	
	var resultado = space_state.intersect_ray(parametro_rayo)
	if resultado:
		# Solo hay línea de visión si el rayo impacta directamente al jugador (y no a una pared)
		return resultado.collider == _jugador
	
	return false

func _obtener_posicion_segura_granada(direccion: Vector2) -> Vector2:
	var pos_centro = global_position + Vector2(0, -15) # Centro del torso
	var pos_deseada = pos_centro + (direccion * 35.0)  # Distancia de lanzamiento
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(pos_centro, pos_deseada)
	query.exclude = [self] # Ignorar al tirador
	
	var res = space_state.intersect_ray(query)
	if res:
		# Si hay una pared en medio, la hace nacer justo antes de la colisión
		return res.position - (direccion * 6.0)
	
	return pos_deseada

func _detectar_jugador_en_cono() -> bool:
	if not is_instance_valid(_jugador): 
		return false
	
	var dist = global_position.distance_to(_jugador.global_position)
	if dist > distancia_vision:
		return false
		
	# Dirección en la que mira el enemigo
	var dir_frente = Vector2.RIGHT if _mirando_derecha else Vector2.LEFT
	var dir_hacia_jugador = (_jugador.global_position - global_position).normalized()
	
	# Cálculo del ángulo entre la mirada y el jugador
	var angulo = rad_to_deg(dir_frente.angle_to(dir_hacia_jugador))
	if abs(angulo) <= (angulo_vision / 2.0):
		return _tiene_linea_de_vision() # Verifica que no haya muros de por medio
		
	return false

func _draw():
	# Dibuja el cono de visión visual mientras esté desenfocado / sin alerta
	if not es_alerta:
		var dir_x = 1.0 if _mirando_derecha else -1.0
		var medio_angulo = deg_to_rad(angulo_vision / 2.0)
		var p1 = Vector2(dir_x * cos(-medio_angulo), sin(-medio_angulo)) * distancia_vision
		var p2 = Vector2(dir_x * cos(medio_angulo), sin(medio_angulo)) * distancia_vision
		
		draw_polygon(
			PackedVector2Array([Vector2(0, -15), Vector2(0, -15) + p1, Vector2(0, -15) + p2]), 
			PackedColorArray([Color(1.0, 0.9, 0.2, 0.15)]) # Amarillo translúcido
		)
