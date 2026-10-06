extends CharacterBody2D

@export var velocidad: float = 120.0
@export var distancia_deteccion: float = 500.0 
@export var distancia_minima: float = 250.0  
@export var salud: float = 25.0
var salud_maxima: float = 25.0

# --- BARRA DE DAÑO (indicador sobre la cabeza: 10s visible + desvanecido) ---
const BARRA_TIEMPO_VISIBLE: float = 10.0
const BARRA_TIEMPO_FADE: float = 1.0
const BARRA_ANCHO: float = 44.0
const BARRA_ALTO: float = 5.0
const COLOR_SALUD = Color(1.0, 0.85, 0.1)   # Amarillo
const COLOR_VACIO = Color(0.35, 0.05, 0.05) # Rojo oscuro
var _barra_dano_tiempo: float = 0.0

@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo
@onready var _sprite_brazo = $PivoteBrazo/SpriteBrazoArma
@onready var _arma_actual = $PivoteBrazo/PistolaPlasma
@export var mirar_izquierda_al_inicio: bool = false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _jugador: Node2D = null
var _mirando_derecha: bool = true

# --- VARIABLES DE PÁNICO ---
var distancia_peligro_granada: float = 180.0 
var multiplicador_velocidad_panico: float = 1.5 

# --- NUEVAS VARIABLES: LANZAMIENTO DE GRANADAS ---
const ESCENA_GRANADA = preload("res://Scenes/granada.tscn")
var temporizador_granada: float = 6
var distancia_min_lanzar: float = 250.0 # No la tira si estás muy cerca
var distancia_max_lanzar: float = 450.0 # No la tira si estás muy lejos
var fuerza_lanzamiento_granada: float = 500.0

const BALA_ENEMIGA = preload("res://Scenes/bala_enemiga.tscn") 
const ARMA_SOLTADA = preload("res://Scenes/arma_soltada.tscn") 
const TEXTURA_GRANADA = preload("res://Assets/Granada HUD.png")

# --- SISTEMA DE SIGILO Y VISIÓN ---
@export var angulo_vision: float = 70.0    # Apertura en grados del cono
@export var distancia_vision: float = 380.0 # Alcance máximo de la linterna
var es_alerta: bool = false               # Estado de combate activado

# --- VARIABLES DE MIEDO (LÍDER CAÍDO) ---
var esta_aterrado: bool = false
var tiempo_aterrado: float = 0.0

# --- SORPRESA (reacción breve con filtro amarillo antes de alertar/huir) ---
@export var duracion_sorpresa: float = 0.8
var _sorpresa_tiempo: float = 0.0
var _sorpresa_huir: bool = false
var _sorpresa_huida_duracion: float = 4.0
# El cono solo se dibuja patrullando (ni alerta, susto, pánico o sorpresa)
var _cono_visible: bool = false

# --- PATRULLA (deambular cuando está tranquilo) ---
@export var patrullar: bool = true       # Desmarcar para centinelas estáticos
@export var rango_patrulla: float = 150.0 # Píxeles a cada lado del punto de aparición
@export var factor_vel_patrulla: float = 0.35
var _pos_origen_patrulla: Vector2
var _dir_patrulla: float = 1.0

func _ready():
	# Si ya lo derrotamos en esta partida (checkpoint), no reaparece.
	if Global.estaba_eliminado(self):
		queue_free()
		return
	_jugador = get_tree().get_first_node_in_group("player")
	if _jugador == null:
		_jugador = get_parent().get_node_or_null("Player")

	salud_maxima = salud # Referencia para la barra de daño
		
	# Si la casilla está marcada en el Inspector, voltea al enemigo al nacer
	if mirar_izquierda_al_inicio:
		_flip_enemigo()

	_pos_origen_patrulla = global_position
	_dir_patrulla = 1.0 if _mirando_derecha else -1.0
		
func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	# Temporizador de la barra de daño (la muestra 10s y la desvanece)
	if _barra_dano_tiempo > 0.0:
		_barra_dano_tiempo -= delta
		queue_redraw()

	if temporizador_granada > 0:
		temporizador_granada -= delta

	# 1. ESCANEO DE SUPERVIVENCIA (Rastrear granadas)
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
			_sorprender(false)

# (Recuerda restar el tiempo de miedo al inicio del _physics_process)
	if esta_aterrado:
		tiempo_aterrado -= delta
		if tiempo_aterrado <= 0:
			esta_aterrado = false
			_sprite_cuerpo.modulate = Color(1.0, 1.0, 1.0) # Vuelve al color normal

	# Reloj de la sorpresa (corre incluso en pánico; al terminar alerta o huye)
	if _sorpresa_tiempo > 0.0:
		_sorpresa_tiempo -= delta
		if _sorpresa_tiempo <= 0.0:
			_terminar_sorpresa()

	# 2. MÁQUINA DE ESTADOS (Huir vs Combatir)
	_cono_visible = false # Solo la rama de patrulla lo vuelve a encender
	if granada_mas_peligrosa != null:
		# --- ESTADO: PÁNICO ---
		var direccion_escape = sign(global_position.x - granada_mas_peligrosa.global_position.x)
		if direccion_escape == 0:
			direccion_escape = 1 if randf() > 0.5 else -1
			
		velocity.x = direccion_escape * (velocidad * multiplicador_velocidad_panico)
		
		if _jugador != null and is_instance_valid(_jugador):
			_apuntar_al_jugador()

	elif _sorpresa_tiempo > 0.0:
		# --- ESTADO: SORPRESA (clavado y amarillo, sin disparar) ---
		velocity.x = move_toward(velocity.x, 0, velocidad)
			
	elif esta_aterrado and is_instance_valid(_jugador):
		# --- ESTADO: ATERRADO (HUIR DEL JUGADOR) ---
		var direccion_escape = sign(global_position.x - _jugador.global_position.x)
		if direccion_escape == 0:
			direccion_escape = 1 if randf() > 0.5 else -1
			
		velocity.x = direccion_escape * (velocidad * multiplicador_velocidad_panico)
		
		# Hacemos que miren hacia atrás mientras corren (opcional pero divertido)
		var dir_x = _jugador.global_position.x - global_position.x
		if (dir_x < 0 and _mirando_derecha) or (dir_x > 0 and not _mirando_derecha):
			_flip_enemigo()
	
	elif es_alerta and _jugador != null and is_instance_valid(_jugador):
		# --- ESTADO: COMBATE NORMAL (SOLO SI ESTÁ EN ALERTA) ---
		var distancia_jugador = global_position.distance_to(_jugador.global_position)
		var tiene_visibilidad = _tiene_linea_de_vision()
		
		if distancia_jugador < distancia_deteccion:
			_apuntar_al_jugador()
			
			if tiene_visibilidad:
				# Granadas enemigas bloqueadas hasta el tutorial de granadas.
				if Global.enemigos_pueden_usar_granadas() and temporizador_granada <= 0 and distancia_jugador > distancia_min_lanzar and distancia_jugador < distancia_max_lanzar:
					_lanzar_granada()
					temporizador_granada = randf_range(4.0, 8.0)
				
				_arma_actual.intentar_disparar()
			
			# Lógica de kiting (Acercarse o alejarse)
			if distancia_jugador > distancia_minima + 15.0:
				var direccion_x = sign(_jugador.global_position.x - global_position.x)
				velocity.x = direccion_x * velocidad
			elif distancia_jugador < distancia_minima - 15.0:
				var direccion_x = sign(global_position.x - _jugador.global_position.x)
				velocity.x = direccion_x * velocidad
			else:
				velocity.x = move_toward(velocity.x, 0, velocidad)
		else:
			velocity.x = move_toward(velocity.x, 0, velocidad)
	else:
		# --- ESTADO: PATRULLA (tranquilo, sin alerta ni peligros) ---
		_patrullar()
	queue_redraw() # Refresca cono y barra cada frame, sin restos entre estados
	move_and_slide()

func _patrullar():
	_cono_visible = patrullar
	if not patrullar:
		velocity.x = move_toward(velocity.x, 0, velocidad)
		return
	# Rebotar en los límites del rango y en paredes
	if global_position.x > _pos_origen_patrulla.x + rango_patrulla:
		_dir_patrulla = -1.0
	elif global_position.x < _pos_origen_patrulla.x - rango_patrulla:
		_dir_patrulla = 1.0
	if is_on_wall():
		_dir_patrulla = -_dir_patrulla
	# Girar el sprite según la dirección de marcha
	if (_dir_patrulla > 0 and not _mirando_derecha) or (_dir_patrulla < 0 and _mirando_derecha):
		_flip_enemigo()
	velocity.x = _dir_patrulla * (velocidad * factor_vel_patrulla)

# --- NUEVA FUNCIÓN ---
func _lanzar_granada():
	var nueva_granada = ESCENA_GRANADA.instantiate()
	get_parent().add_child(nueva_granada)
	
	var direccion_jugador = (_jugador.global_position - global_position).normalized()
	direccion_jugador.y -= 0.6
	direccion_jugador = direccion_jugador.normalized()
	
	var pos_origen = global_position + Vector2(0, -30)
	var pos_destino = pos_origen + (direccion_jugador * 40.0)
	
	# Raycast para no atravesar paredes al aparecer
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

func _apuntar_al_jugador():
	_pivote_brazo.look_at(_jugador.global_position)
	var direccion_hacia_jugador = _jugador.global_position.x - global_position.x
	
	if direccion_hacia_jugador < 0 and _mirando_derecha:
		_flip_enemigo()
	elif direccion_hacia_jugador > 0 and not _mirando_derecha:
		_flip_enemigo()
		
	if _jugador.global_position.x < global_position.x:
		_pivote_brazo.scale.y = -1
	else:
		_pivote_brazo.scale.y = 1

func _flip_enemigo():
	_mirando_derecha = not _mirando_derecha
	_sprite_cuerpo.flip_h = not _sprite_cuerpo.flip_h
	_pivote_brazo.position.x = -_pivote_brazo.position.x

func recibir_dano(cantidad: float, tipo_dano: String = "Balistica"):
	# --- BAJA INSTANTÁNEA POR SIGILO ---
	if tipo_dano == "Melee" and not es_alerta:
		salud = 0
		Global.registrar_baja_enemigo(self)
		_soltar_arma()
		_intentar_soltar_granada()
		queue_free()
		return

	# Si no estaba en alerta y recibe daño, se entera inmediatamente
	es_alerta = true
	queue_redraw()
	_barra_dano_tiempo = BARRA_TIEMPO_VISIBLE # Mostrar indicador de daño

	var multiplicador_salud = 1.0
	
	if tipo_dano == "Plasma":
		multiplicador_salud = 0.5
	elif tipo_dano == "Balistica":
		multiplicador_salud = 1.5
		
	salud -= (cantidad * multiplicador_salud)
	
	if salud <= 0:
		Global.registrar_baja_enemigo(self)
		_soltar_arma()
		_intentar_soltar_granada()
		queue_free()

func _soltar_arma():
	var arma_caida = ARMA_SOLTADA.instantiate()
	arma_caida.tipo_arma = "PistolaPlasma" 
	
	# --- LA CLAVE PARA LA BATERÍA ---
	if arma_caida.tipo_arma == "PistolaPlasma":
		arma_caida.cantidad_municion = 100 # Carga completa para el plasma
	else:
		arma_caida.cantidad_municion = 5   # Balas por defecto para otras armas
	
	var sprite_arma = _arma_actual.get_node("Sprite2D")
	if sprite_arma:
		arma_caida.textura_arma = sprite_arma.texture
		
		# Heredamos la escala para que no sea gigante
		arma_caida.scale = sprite_arma.scale
		
	get_parent().call_deferred("add_child", arma_caida)
	arma_caida.set_deferred("global_position", global_position)

func _intentar_soltar_granada():
	# randf() genera un valor decimal entre 0.0 y 1.0; <= 0.2 es el 20% (1/5)
	if randf() <= 0.20:
		var granada_caida = ARMA_SOLTADA.instantiate()
		granada_caida.tipo_arma = "Granada"
		granada_caida.cantidad_municion = 1
		granada_caida.textura_arma = TEXTURA_GRANADA
		
		# --- NUEVA LÍNEA: Ajustamos el tamaño para que coincida con tu escena original ---
		granada_caida.scale = Vector2(0.05, 0.05) 
		
		get_parent().call_deferred("add_child", granada_caida)
		granada_caida.set_deferred("global_position", global_position)

func _tiene_linea_de_vision() -> bool:
	if not is_instance_valid(_jugador): 
		return false
	
	var space_state = get_world_2d().direct_space_state
	var parametro_rayo = PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -15), _jugador.global_position + Vector2(0, -15))
	parametro_rayo.exclude = [self]
	
	var resultado = space_state.intersect_ray(parametro_rayo)
	if resultado:
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
	# Haz de linterna: 3 capas anidadas con degradado (brillante en el origen,
	# transparente en el borde) en vez de un triángulo plano.
	# Solo visible patrullando: en alerta, susto, pánico o sorpresa se apaga.
	if _cono_visible:
		var dir_x = 1.0 if _mirando_derecha else -1.0
		var medio_angulo = deg_to_rad(angulo_vision / 2.0)
		var apice = Vector2(0, -15)
		for i in range(3, 0, -1):
			var frac = float(i) / 3.0
			var ang = medio_angulo * frac
			var alfa = 0.20 - 0.10 * frac
			var q1 = apice + Vector2(dir_x * cos(-ang), sin(-ang)) * distancia_vision
			var q2 = apice + Vector2(dir_x * cos(ang), sin(ang)) * distancia_vision
			draw_polygon(
				PackedVector2Array([apice, q1, q2]),
				PackedColorArray([Color(1.0, 0.95, 0.55, alfa), Color(1.0, 0.95, 0.55, 0.0), Color(1.0, 0.95, 0.55, 0.0)])
			)
	_dibujar_barra_dano()

func _dibujar_barra_dano():
	if _barra_dano_tiempo <= 0.0:
		return
	# Se desvanece en el último segundo
	var alpha = clampf(_barra_dano_tiempo / BARRA_TIEMPO_FADE, 0.0, 1.0)
	var origen = Vector2(-BARRA_ANCHO / 2.0, -66.0)
	var fondo = COLOR_VACIO
	fondo.a = alpha
	draw_rect(Rect2(origen, Vector2(BARRA_ANCHO, BARRA_ALTO)), fondo)
	var frac = clampf(salud / maxf(salud_maxima, 1.0), 0.0, 1.0)
	if frac > 0.0:
		var relleno = COLOR_SALUD
		relleno.a = alpha
		draw_rect(Rect2(origen, Vector2(BARRA_ANCHO * frac, BARRA_ALTO)), relleno)

func asustar(duracion: float = 4.0):
	# Si ya está asustado o procesando el susto, no reiniciamos
	if esta_aterrado or _sorpresa_tiempo > 0.0:
		return
	# Primero la sorpresa amarilla, y al terminar arranca la huida
	_sorprender(true, duracion)

# Inicia la sorpresa: filtro amarillo (el mismo de asustado) y quieto.
func _sorprender(huir: bool, duracion_huida: float = 4.0):
	# Sin esto, cada frame en el cono reiniciaría el reloj y nunca alertaría
	if _sorpresa_tiempo > 0.0:
		return
	_sorpresa_huir = huir
	_sorpresa_huida_duracion = duracion_huida
	_sorpresa_tiempo = duracion_sorpresa
	_sprite_cuerpo.modulate = Color(1.0, 1.0, 0.0)
	queue_redraw()

func _terminar_sorpresa():
	_sorpresa_tiempo = 0.0
	if _sorpresa_huir:
		_sorpresa_huir = false
		esta_aterrado = true
		tiempo_aterrado = _sorpresa_huida_duracion
		# Mantiene el amarillo hasta que se le pasa el susto (tick de miedo)
	else:
		es_alerta = true
		_sprite_cuerpo.modulate = Color(1.0, 1.0, 1.0)
		queue_redraw()
		
