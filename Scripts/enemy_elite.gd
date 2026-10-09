extends CharacterBody2D

const SPEED = 170.0 
const FALL_GRAVITY_MULTIPLIER = 1.8 

# --- ESCUDOS Y SALUD ---
@export var salud_maxima: float = 75.0
var salud_actual: float = 75.0

@export var escudo_maximo: float = 60.0 
var escudo_actual: float = 60.0

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
@onready var _area_golpe = $AreaGolpe
@onready var _colision_golpe = $AreaGolpe/CollisionShape2D
@onready var _anim_golpe = $AnimationPlayer

const ARMA_SOLTADA = preload("res://Scenes/arma_soltada.tscn")

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _mirando_derecha = true
var _jugador = null
var _tween_escudo: Tween 

# --- SISTEMA DE SIGILO Y VISIÓN ---
@export var angulo_vision: float = 70.0    # Apertura en grados del cono
@export var distancia_vision: float = 380.0 # Alcance máximo de la linterna
var es_alerta: bool = false               # Estado de combate activado

# Si está marcado, el enemigo nace "dormido" para el tutorial de sigilo:
# no detecta, no ataca y no recibe daño hasta que el trigger lo despierta.
@export var dormido_hasta_tutorial: bool = false

# --- SORPRESA (reacción breve con filtro amarillo antes de alertar) ---
@export var duracion_sorpresa: float = 0.8
var _sorpresa_tiempo: float = 0.0
# El cono solo se dibuja patrullando (ni alerta, susto, pánico o sorpresa)
var _cono_visible: bool = false

# --- PATRULLA (deambular cuando está tranquilo) ---
@export var patrullar: bool = true       # Desmarcar para centinelas estáticos
@export var rango_patrulla: float = 150.0 # Píxeles a cada lado del punto de aparición
@export var factor_vel_patrulla: float = 0.35
var _pos_origen_patrulla: Vector2
var _dir_patrulla: float = 1.0
# Anti-atasco entre patrulleros: si el bloqueo es otro enemigo, no giramos
# al instante (eso los deja vibrando en el sitio), sino tras un tiempo
# aleatorio para que no se sincronicen y se despeguen.
var _tiempo_bloqueado_aliado: float = 0.0
var _umbral_despegue: float = 0.5

# --- ANIMACIÓN DE CAMINATA (cuadros 0-4 del spritesheet, en bucle) ---
# Los cuadros 7-9 (golpe) se programan aparte cuando toque.
@export var fps_caminar: float = 8.0
const FRAME_QUIETO: int = 0
const FRAMES_CAMINAR: int = 5
var _tiempo_anim_caminar: float = 0.0
# Hombro base (posición del tscn, mirando a la derecha): el balanceo
# de marcha lo toma como referencia cada frame.
var _base_pivote_brazo: Vector2

# --- GOLPE MELEE (aviso rojo + animación Golpe + enfriamiento) ---
@export var distancia_golpe: float = 120.0
@export var dano_golpe: float = 30.0
@export var tiempo_aviso_golpe: float = 0.5
@export var cooldown_golpe: float = 15.0
const COLOR_AVISO_GOLPE := Color(1.0, 0.3, 0.3)
var temporizador_golpe: float = 0.0
var _golpe_fase: int = 0 # 0 libre, 1 aviso quieto en rojo, 2 golpeando
var _tiempo_golpe: float = 0.0
var _base_area_golpe_x: float = 22.0
var _base_colision_golpe_x: float = 35.0

# --- BARRA DE DAÑO (indicador sobre la cabeza: 10s visible + desvanecido) ---
const BARRA_TIEMPO_VISIBLE: float = 10.0
const BARRA_TIEMPO_FADE: float = 1.0
const BARRA_ANCHO: float = 50.0
const BARRA_ALTO: float = 5.0
const COLOR_SALUD = Color(1.0, 0.85, 0.1)   # Amarillo
const COLOR_ESCUDO = Color(0.2, 0.9, 0.9)   # Turquesa
const COLOR_VACIO = Color(0.35, 0.05, 0.05) # Rojo oscuro
var _barra_dano_tiempo: float = 0.0

@export var mirar_izquierda_al_inicio: bool = false

# --- VARIABLES DE EVASIÓN DE GRANADAS ---
@export var distancia_peligro_granada: float = 180.0
@export var multiplicador_velocidad_panico: float = 1.3

func _ready():
	# Si ya lo derrotamos en esta partida (checkpoint), no reaparece.
	if Global.estaba_eliminado(self):
		queue_free()
		return
	salud_actual = salud_maxima
	escudo_actual = escudo_maximo
	_base_pivote_brazo = _pivote_brazo.position
	_base_area_golpe_x = _area_golpe.position.x - _sprite_cuerpo.position.x
	_base_colision_golpe_x = _colision_golpe.position.x
	_anim_golpe.animation_finished.connect(_on_golpe_anim_finished)
	_actualizar_area_golpe()

	if dormido_hasta_tutorial:
		add_to_group("enemigos_dormidos_tutorial")

	# Si la casilla está marcada en el Inspector, voltea al enemigo al nacer
	if mirar_izquierda_al_inicio:
		_flip_personaje()
	_orientar_brazo_adelante()

	_pos_origen_patrulla = global_position
	_dir_patrulla = 1.0 if _mirando_derecha else -1.0

# Llamado por el trigger del tutorial de sigilo al mostrar el diálogo.
func despertar_tutorial():
	dormido_hasta_tutorial = false
	remove_from_group("enemigos_dormidos_tutorial")
	queue_redraw()

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta
		else:
			velocity.y += gravity * delta

	# Dormido: quieto, sin detectar, sin atacar, sin huir de granadas.
	if dormido_hasta_tutorial:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# Temporizador de la barra de daño (la muestra 10s y la desvanece)
	if _barra_dano_tiempo > 0.0:
		_barra_dano_tiempo -= delta
		queue_redraw()

	# Reloj de la sorpresa (al terminar, alerta)
	if _sorpresa_tiempo > 0.0:
		_sorpresa_tiempo -= delta
		if _sorpresa_tiempo <= 0.0:
			_sorpresa_tiempo = 0.0
			es_alerta = true
			_sprite_cuerpo.modulate = Color(1.0, 1.0, 1.0)
			queue_redraw()

	_procesar_recarga_escudo(delta)

	# Cooldown de granada
	if temporizador_granada > 0:
		temporizador_granada -= delta

	# Enfriamiento del golpe melee
	if temporizador_golpe > 0:
		temporizador_golpe -= delta

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
			_sorprender()

	# 2. MÁQUINA DE ESTADOS (Evadir Granada vs Combate Normal)
	_cono_visible = false # Solo la rama de patrulla lo vuelve a encender
	if granada_mas_peligrosa != null:
		# --- ESTADO: HUIR DE GRANADA ---
		var direccion_escape = sign(global_position.x - granada_mas_peligrosa.global_position.x)
		if direccion_escape == 0:
			direccion_escape = 1 if randf() > 0.5 else -1
			
		velocity.x = direccion_escape * (SPEED * multiplicador_velocidad_panico)
		
		if is_instance_valid(_jugador):
			_apuntar_al_jugador()

	elif _sorpresa_tiempo > 0.0:
		# --- ESTADO: SORPRESA (clavado y amarillo, sin disparar) ---
		velocity.x = move_toward(velocity.x, 0, SPEED)

	elif _golpe_fase != 0:
		# --- ESTADO: GOLPE MELEE (aviso rojo + golpe, sin moverse) ---
		_procesar_golpe(delta)

	elif es_alerta and is_instance_valid(_jugador) and _golpe_disponible():
		# --- ATAQUE MELEE (jugador al alcance y golpe cargado) ---
		_iniciar_golpe()

	elif es_alerta and is_instance_valid(_jugador):
		# --- ESTADO DE COMBATE NORMAL ---
		var dist = global_position.distance_to(_jugador.global_position)
		var tiene_visibilidad = _tiene_linea_de_vision()
		
		_apuntar_al_jugador()

		if dist <= distancia_ataque:
			if tiene_visibilidad:
				# Granadas enemigas bloqueadas hasta el tutorial de granadas.
				if Global.enemigos_pueden_usar_granadas() and temporizador_granada <= 0 and dist >= distancia_min_lanzar and dist <= distancia_max_lanzar:
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
		# --- ESTADO: PATRULLA (tranquilo, sin alerta ni peligros) ---
		_patrullar(delta)

	queue_redraw() # Refresca cono y barra cada frame, sin restos entre estados
	_actualizar_animacion_caminar(delta)
	move_and_slide()
	
func _patrullar(delta: float):
	_cono_visible = patrullar
	if not patrullar:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_orientar_brazo_adelante()
		return
	# Rebotar en los límites del rango y en paredes
	if global_position.x > _pos_origen_patrulla.x + rango_patrulla:
		_dir_patrulla = -1.0
	elif global_position.x < _pos_origen_patrulla.x - rango_patrulla:
		_dir_patrulla = 1.0
	if is_on_wall():
		if _choca_con_muro_real():
			_dir_patrulla = -_dir_patrulla
			_tiempo_bloqueado_aliado = 0.0
		else:
			# Solo hay compañeros encima: esperar un poco antes de girar.
			_tiempo_bloqueado_aliado += delta
			if _tiempo_bloqueado_aliado >= _umbral_despegue:
				_dir_patrulla = -_dir_patrulla
				_tiempo_bloqueado_aliado = 0.0
				_umbral_despegue = randf_range(0.35, 0.7)
	else:
		_tiempo_bloqueado_aliado = 0.0
	# Girar el sprite según la dirección de marcha
	if (_dir_patrulla > 0 and not _mirando_derecha) or (_dir_patrulla < 0 and _mirando_derecha):
		_flip_personaje()
	_orientar_brazo_adelante()
	velocity.x = _dir_patrulla * (SPEED * factor_vel_patrulla)

# True si alguna colisión de este frame es con algo que no sea otro enemigo
# (muro, plataforma, jugador, granada...). Solo eso justifica girar al acto.
func _choca_con_muro_real() -> bool:
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i).get_collider()
		if col != null and not col.is_in_group("enemigos"):
			return true
	return false

# Avanza los cuadros 0-4 mientras se desplaza en el suelo; quieto
# (patrulla estática, sorpresa, dormido) vuelve al cuadro 0.
# Además balancea el brazo con cada paso, como el conejo jugador.
func _actualizar_animacion_caminar(delta: float) -> void:
	# Durante el golpe melee manda el AnimationPlayer, no el ciclo de marcha.
	if _golpe_fase != 0:
		return
	if absf(velocity.x) > 20.0 and is_on_floor():
		_tiempo_anim_caminar += delta
		_sprite_cuerpo.frame = int(_tiempo_anim_caminar * fps_caminar) % FRAMES_CAMINAR
	else:
		_tiempo_anim_caminar = 0.0
		_sprite_cuerpo.frame = FRAME_QUIETO
	_sincronizar_brazo_marcha()

func _sincronizar_brazo_marcha() -> void:
	# Rebote por paso (los cuadros 1-3 son el apoyo): el pivote vuelve
	# solo al hombro base cuando el cuerpo está quieto.
	var offset := Vector2.ZERO
	match _sprite_cuerpo.frame:
		1:
			offset = Vector2(1, -2)
		2:
			offset = Vector2(0, -3)
		3:
			offset = Vector2(-1, -2)
	var px := _base_pivote_brazo.x + offset.x
	if not _mirando_derecha:
		px = 2.0 * _sprite_cuerpo.position.x - px
	_pivote_brazo.position = Vector2(px, _base_pivote_brazo.y + offset.y)
	
# Golpe listo: enfriamiento cumplido, jugador al alcance y a la vista.
func _golpe_disponible() -> bool:
	if temporizador_golpe > 0.0 or not is_instance_valid(_jugador):
		return false
	if global_position.distance_to(_jugador.global_position) > distancia_golpe:
		return false
	return _tiene_linea_de_vision()

func _iniciar_golpe() -> void:
	# Mira al jugador, se clava y avisa en rojo (cuerpo y brazos).
	var hacia = sign(_jugador.global_position.x - global_position.x)
	if hacia != 0.0 and ((hacia < 0.0 and _mirando_derecha) or (hacia > 0.0 and not _mirando_derecha)):
		_flip_personaje()
	_orientar_brazo_adelante()
	velocity.x = move_toward(velocity.x, 0, SPEED)
	_golpe_fase = 1
	_tiempo_golpe = 0.0
	_sprite_cuerpo.modulate = COLOR_AVISO_GOLPE
	_pivote_brazo.modulate = COLOR_AVISO_GOLPE

func _procesar_golpe(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED)
	if _golpe_fase != 1:
		return
	_tiempo_golpe += delta
	if _tiempo_golpe >= tiempo_aviso_golpe:
		_golpe_fase = 2
		_ejecutar_golpe()

func _ejecutar_golpe() -> void:
	# Puños fuera: el rifle se oculta durante la animación de Golpe.
	_pivote_brazo.hide()
	_anim_golpe.play("Golpe")
	for cuerpo in _area_golpe.get_overlapping_bodies():
		if cuerpo != self and cuerpo.is_in_group("player") and cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano_golpe, "Melee")

func _on_golpe_anim_finished(nombre: String) -> void:
	if nombre != "Golpe" or _golpe_fase != 2:
		return
	_terminar_golpe()

func _terminar_golpe() -> void:
	_sprite_cuerpo.modulate = Color(1.0, 1.0, 1.0)
	_pivote_brazo.modulate = Color(1.0, 1.0, 1.0)
	_pivote_brazo.show()
	_sprite_cuerpo.frame = FRAME_QUIETO
	_tiempo_anim_caminar = 0.0
	_golpe_fase = 0
	temporizador_golpe = cooldown_golpe

# El área del golpe siempre queda delante, mire a donde mire.
func _actualizar_area_golpe() -> void:
	var lado := 1.0 if _mirando_derecha else -1.0
	_area_golpe.position.x = _sprite_cuerpo.position.x + lado * _base_area_golpe_x
	_colision_golpe.position.x = lado * _base_colision_golpe_x

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
	# Espejamos respecto al centro del sprite (está desplazado a x=18),
	# no respecto al origen: así el pivote cae en el otro hombro.
	_pivote_brazo.position.x = 2.0 * _sprite_cuerpo.position.x - _pivote_brazo.position.x
	_actualizar_area_golpe()

# Fuera de combate el brazo no usa look_at: lo clavamos hacia adelante
# según a dónde mira el cuerpo. El flip solo espeja la posición del
# pivote, así que sin esto el arma conserva la rotación del último
# combate y apunta a cualquier lado al patrullar.
func _orientar_brazo_adelante():
	if _mirando_derecha:
		_pivote_brazo.rotation = 0.0
		_pivote_brazo.scale.y = 1.0
	else:
		_pivote_brazo.rotation = PI
		_pivote_brazo.scale.y = -1.0

# Inicia la sorpresa: filtro amarillo (el mismo de grunt asustado) y quieto.
func _sorprender():
	if _sorpresa_tiempo > 0.0:
		return
	_sorpresa_tiempo = duracion_sorpresa
	_sprite_cuerpo.modulate = Color(1.0, 1.0, 0.0)
	queue_redraw()

func recibir_dano(cantidad: float, tipo_dano: String = "Balistica"):
	# Dormido para el tutorial: los disparos previos no le hacen nada
	# (solo un destello de escudo como feedback) y no lo alertan.
	if dormido_hasta_tutorial:
		_mostrar_efecto_escudo()
		return

	# --- BAJA INSTANTÁNEA POR SIGILO ---
	if tipo_dano == "Melee" and not es_alerta:
		salud_actual = 0
		escudo_actual = 0
		_morir()
		return

	# Rompe el sigilo al ser atacado
	es_alerta = true
	queue_redraw()
	_barra_dano_tiempo = BARRA_TIEMPO_VISIBLE # Mostrar indicador de daño

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
	Global.registrar_baja_enemigo(self)
	_asustar_aliados(500.0) # 500 píxeles de radio para asustar
	_soltar_arma()
	_intentar_soltar_granada()
	queue_free()

func _asustar_aliados(radio: float):
	# Buscamos a todos los nodos en el grupo "enemigos"
	var enemigos = get_tree().get_nodes_in_group("enemigos")
	
	for enemigo in enemigos:
		if is_instance_valid(enemigo) and enemigo != self:
			# Comprobamos si está cerca y si tiene la capacidad de asustarse (es un Grunt)
			if global_position.distance_to(enemigo.global_position) <= radio:
				if enemigo.has_method("asustar"):
					enemigo.asustar(randf_range(3.0, 5.0)) # Huyen entre 3 y 5 segundos
				

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
	arma_caida.set_deferred("global_position", global_position)

func _intentar_soltar_granada():
	if randf() <= 0.35: # Probabilidad del 35%
		var granada_caida = ARMA_SOLTADA.instantiate()
		granada_caida.tipo_arma = "Granada"
		granada_caida.cantidad_municion = 1
		granada_caida.scale = Vector2(0.05, 0.05)
		get_parent().call_deferred("add_child", granada_caida)
		granada_caida.set_deferred("global_position", global_position)

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
	# Escudo (turquesa) arriba, salud (amarilla sobre rojo oscuro) abajo.
	var escudo_origen = Vector2(-BARRA_ANCHO / 2.0, -79.0)
	var salud_origen = Vector2(-BARRA_ANCHO / 2.0, -72.0)
	var frac_escudo = clampf(escudo_actual / maxf(escudo_maximo, 1.0), 0.0, 1.0)
	var frac_salud = clampf(salud_actual / maxf(salud_maxima, 1.0), 0.0, 1.0)
	if frac_escudo > 0.0:
		var escudo_col = COLOR_ESCUDO
		escudo_col.a = alpha
		draw_rect(Rect2(escudo_origen, Vector2(BARRA_ANCHO * frac_escudo, BARRA_ALTO)), escudo_col)
	var fondo = COLOR_VACIO
	fondo.a = alpha
	draw_rect(Rect2(salud_origen, Vector2(BARRA_ANCHO, BARRA_ALTO)), fondo)
	if frac_salud > 0.0:
		var relleno = COLOR_SALUD
		relleno.a = alpha
		draw_rect(Rect2(salud_origen, Vector2(BARRA_ANCHO * frac_salud, BARRA_ALTO)), relleno)
