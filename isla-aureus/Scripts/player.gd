extends CharacterBody2D

const SPEED = 250.0
const JUMP_VELOCITY = -450.0
const FALL_GRAVITY_MULTIPLIER = 1.8 

# --- SPRITES ---
const TEXTURA_TORSO = preload("res://Assets/Conejo_torso.png")
const TEXTURA_MELEE = preload("res://Assets/Conejo_melee.png")

@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo
@onready var _sprite_brazo = $PivoteBrazo/SpriteBrazoArma
@onready var _area_patada = $AreaPatada

# --- REFERENCIAS AL INVENTARIO ---
@onready var _rifle = $PivoteBrazo/Rifle
@onready var _pistola = $PivoteBrazo/Pistola
@onready var _pistola_plasma = $PivoteBrazo/PistolaPlasma
@onready var _rifle_plasma = $PivoteBrazo/RiflePlasma

@onready var armas_en_escena = [_rifle, _pistola, _pistola_plasma, _rifle_plasma]
var armas = [] 
var indice_arma_actual = 0
var _arma_actual = null

const ARMA_SOLTADA = preload("res://Scenes/arma_soltada.tscn")

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _mirando_derecha = true

# --- VARIABLES DE SALUD Y ESCUDO ---
var salud_maxima = 100.0
var salud_actual = 100.0
var escudo_maximo = 150.0
var escudo_actual = 150.0
var _tween_escudo: Tween

# --- VARIABLES DE GRANADAS ---
const ESCENA_GRANADA_FRAG = preload("res://Scenes/granada.tscn")
const ESCENA_GRANADA_PLASMA = preload("res://Scenes/granada_plasma.tscn")

var granadas_frag_actuales = 4
var granadas_plasma_actuales = 2 # Démosle 2 de plasma para probar
var granadas_maximas = 4
var usando_granada_plasma = false # Falso = Fragmentación, Verdadero = Plasma

var fuerza_lanzamiento = 600.0
var cadencia_granada = 1.5
var temporizador_granada = 0.0

# --- VARIABLES DE MELEE (PATADA) ---
var dano_patada = 120.0                  # Suficiente para eliminar de 1 golpe a un Grunt/Gecko
var duracion_patada = 0.35              # Duración visual del sprite de patada
var temporizador_patada = 0.0
var temporizador_bloqueo_disparo = 0.0  # Pausa los disparos por 1.5s

var tiempo_espera_escudo = 4.0      
var tiempo_sin_dano = 0.0           
var velocidad_recarga_escudo = 40.0 

# --- SPRITES AGACHADO ---
const TEXTURA_CROUCH = preload("res://Assets/Conejo_crouch.png")
const TEXTURA_MELEE_CROUCH = preload("res://Assets/Conejo_melee_crouch.png")

const CROUCH_SPEED = 120.0 # Velocidad reducida al agacharse estilo Halo
var _agachado: bool = false

# Posiciones y dimensiones para la colisión y pivote del brazo
@onready var _colision_cuerpo = $CollisionShape2D
var _pos_pivote_stand = Vector2(-1, -1)
var _pos_pivote_crouch = Vector2(-1, 15) # Baja el pivote de las armas

func _ready():
	if Global.hay_datos_guardados:
		global_position = Vector2(Global.pos_x, Global.pos_y)
	armas.append(_rifle)
	armas.append(_pistola)
	_arma_actual = armas[0]
	
	for arma in armas_en_escena:
		arma.hide()
		
	_arma_actual.show()

	await get_tree().process_frame
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
		hud.actualizar_salud_hud(salud_actual, salud_maxima)
		# --- LÍNEA ACTUALIZADA ---
		hud.actualizar_granadas(granadas_frag_actuales, granadas_plasma_actuales, granadas_maximas, usando_granada_plasma)
	
	if _arma_actual.has_method("_actualizar_hud"):
		_arma_actual._actualizar_hud()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			cambiar_arma()
		elif event.keycode == KEY_F:
			ejecutar_patada() # Presionar F activa la patada
		elif event.keycode == KEY_T:
			alternar_granadas() # Presionar T alterna el tipo
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			lanzar_granada()

func ejecutar_patada():
	if temporizador_patada > 0:
		return
		
	temporizador_patada = duracion_patada
	temporizador_bloqueo_disparo = 1.0
	
	# Asignar sprite de patada según el estado
	_sprite_cuerpo.texture = TEXTURA_MELEE_CROUCH if _agachado else TEXTURA_MELEE
	
	var cuerpos = _area_patada.get_overlapping_bodies()
	for cuerpo in cuerpos:
		if cuerpo.is_in_group("enemigos") and cuerpo.has_method("recibir_dano"):
			if "escudo_actual" in cuerpo and cuerpo.escudo_actual > 0:
				cuerpo.recibir_dano(5.0, "Melee")
			else:
				cuerpo.recibir_dano(dano_patada, "Melee")
				
func cambiar_arma():
	_arma_actual.hide()
	indice_arma_actual = (indice_arma_actual + 1) % armas.size()
	_arma_actual = armas[indice_arma_actual]
	_arma_actual.show()
	
	if _arma_actual.has_method("_actualizar_hud"):
		_arma_actual._actualizar_hud()

func _physics_process(delta):
	# Control de temporizadores
	if temporizador_granada > 0:
		temporizador_granada -= delta
		
	if temporizador_bloqueo_disparo > 0:
		temporizador_bloqueo_disparo -= delta
		
	if temporizador_patada > 0:
		temporizador_patada -= delta
		if temporizador_patada <= 0:
			# Restaurar sprite correspondiente al finalizar patada
			_sprite_cuerpo.texture = TEXTURA_CROUCH if _agachado else TEXTURA_TORSO

	# --- CONTROL DE AGACHARSE ---
	var presiona_agacharse = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)
	if presiona_agacharse and is_on_floor():
		if not _agachado:
			_agacharse()
	elif _agachado:
		_desagacharse()
		
	# Gravedad
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta
		else:
			velocity.y += gravity * delta
			
	# Salto
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	_apuntar_al_mouse()

	# Movimiento Horizontal con velocidad según estado
	var vel_actual = CROUCH_SPEED if _agachado else SPEED
	var direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * vel_actual
		if (direction > 0 and not _mirando_derecha) or (direction < 0 and _mirando_derecha):
			_flip_personaje()
	else:
		velocity.x = move_toward(velocity.x, 0, vel_actual)

	# Escudos
	if salud_actual > 0 and escudo_actual < escudo_maximo:
		tiempo_sin_dano += delta 
		if tiempo_sin_dano >= tiempo_espera_escudo:
			escudo_actual += velocidad_recarga_escudo * delta
			if escudo_actual >= escudo_maximo:
				escudo_actual = escudo_maximo
			var hud = get_parent().get_node_or_null("HUD")
			if hud != null:
				hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)

	move_and_slide()

	# Acciones delegadas
	if Input.is_physical_key_pressed(KEY_R):
		_arma_actual.recargar()
		
	# Solo permite disparar si NO está pausado por la patada
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and temporizador_bloqueo_disparo <= 0:
		_arma_actual.intentar_disparar()

func _apuntar_al_mouse():
	var mouse_pos = get_global_mouse_position()
	_pivote_brazo.look_at(mouse_pos)
	var mouse_relativo = get_local_mouse_position()
	
	if mouse_relativo.x < 0:
		_pivote_brazo.scale.y = -1 
	else:
		_pivote_brazo.scale.y = 1

func _flip_personaje():
	_mirando_derecha = not _mirando_derecha
	_sprite_cuerpo.flip_h = not _sprite_cuerpo.flip_h
	_pivote_brazo.position.x = -_pivote_brazo.position.x
	_area_patada.position.x = -_area_patada.position.x # Invertir el área de patada al girar

func recibir_dano(cantidad: float, tipo_dano: String = "Balistica"):
	tiempo_sin_dano = 0.0
	var tenia_escudo = escudo_actual > 0
	
	var multiplicador_escudo = 1.0
	var multiplicador_salud = 1.0
	
	if tipo_dano == "Plasma":
		multiplicador_escudo = 1.5
		multiplicador_salud = 0.5
	elif tipo_dano == "Balistica":
		multiplicador_escudo = 0.5
		multiplicador_salud = 1.5
		
	if escudo_actual > 0:
		var dano_al_escudo = cantidad * multiplicador_escudo
		escudo_actual -= dano_al_escudo
		
		if escudo_actual <= 0:
			var dano_restante_base = abs(escudo_actual) / multiplicador_escudo
			escudo_actual = 0
			salud_actual -= (dano_restante_base * multiplicador_salud)
			_mostrar_efecto_ruptura_escudo()
		else:
			_mostrar_efecto_escudo()
	else:
		salud_actual -= (cantidad * multiplicador_salud)
		
	if salud_actual <= 0:
		salud_actual = 0
		print("¡EL JEFE MAESTRO HA MUERTO!")
			
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
		hud.actualizar_salud_hud(salud_actual, salud_maxima)
		
func recoger_arma(nombre_arma: String, cantidad_municion: int) -> bool:
	if nombre_arma == "Granada":
		if granadas_frag_actuales < granadas_maximas:
			granadas_frag_actuales = min(granadas_frag_actuales + cantidad_municion, granadas_maximas)
			
			var hud = get_parent().get_node_or_null("HUD")
			if hud != null:
				# --- LÍNEA ACTUALIZADA ---
				hud.actualizar_granadas(granadas_frag_actuales, granadas_plasma_actuales, granadas_maximas, usando_granada_plasma)
				hud.mostrar_notificacion("Granada recogida (" + str(granadas_frag_actuales) + "/" + str(granadas_maximas) + ")")
			return true
		return false
	# ... (resto de la función) ...
	for arma in armas:
		if arma.name == nombre_arma:
			if "municion_reserva" in arma:
				arma.municion_reserva += cantidad_municion
				var hud = get_parent().get_node_or_null("HUD")
				if hud != null:
					if arma == _arma_actual and arma.has_method("_actualizar_hud"):
						arma._actualizar_hud()
					hud.mostrar_notificacion("Has recogido munición de " + nombre_arma)
				return true
				
			elif "bateria" in arma:
				if cantidad_municion > arma.bateria:
					arma.bateria = cantidad_municion
					var hud = get_parent().get_node_or_null("HUD")
					if hud != null:
						if arma == _arma_actual and arma.has_method("_actualizar_hud"):
							arma._actualizar_hud()
						hud.mostrar_notificacion("Batería de " + nombre_arma + " recargada")
					return true
				else:
					return false

	var arma_a_equipar = null
	for arma_en_escena in armas_en_escena:
		if arma_en_escena.name == nombre_arma:
			arma_a_equipar = arma_en_escena
			break
			
	if arma_a_equipar != null:
		_tirar_arma_actual_al_suelo()
		armas[indice_arma_actual] = arma_a_equipar
		
		_arma_actual.hide()
		_arma_actual = arma_a_equipar
		_arma_actual.show()
		
		if "municion_reserva" in _arma_actual:
			_arma_actual.municion_reserva = cantidad_municion 
		elif "bateria" in _arma_actual:
			_arma_actual.bateria = cantidad_municion
			
		if _arma_actual.has_method("_actualizar_hud"):
			_arma_actual._actualizar_hud()
			
		var hud = get_parent().get_node_or_null("HUD")
		if hud != null:
			hud.mostrar_notificacion("Arma cambiada por: " + nombre_arma)
		return true
		
	return false

func _tirar_arma_actual_al_suelo():
	var arma_caida = ARMA_SOLTADA.instantiate()
	arma_caida.tipo_arma = _arma_actual.name 
	
	if "municion_reserva" in _arma_actual:
		arma_caida.cantidad_municion = _arma_actual.municion_reserva
	elif "bateria" in _arma_actual:
		arma_caida.cantidad_municion = _arma_actual.bateria
	
	if _arma_actual is Sprite2D:
		arma_caida.textura_arma = _arma_actual.texture
		arma_caida.scale = _arma_actual.scale
	elif _arma_actual.has_node("Sprite2D"):
		var sprite_arma = _arma_actual.get_node("Sprite2D")
		arma_caida.textura_arma = sprite_arma.texture
		arma_caida.scale = sprite_arma.scale
		
	get_tree().current_scene.call_deferred("add_child", arma_caida)
	
	var offset_x = 40.0 if _mirando_derecha else -40.0
	arma_caida.global_position = global_position + Vector2(offset_x, 0)

func alternar_granadas():
	usando_granada_plasma = not usando_granada_plasma
	var tipo = "Plasma" if usando_granada_plasma else "Fragmentación"
	
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		# --- LÍNEA ACTUALIZADA ---
		hud.actualizar_granadas(granadas_frag_actuales, granadas_plasma_actuales, granadas_maximas, usando_granada_plasma)
		hud.mostrar_notificacion("Granada equipada: " + tipo)
		
func lanzar_granada():
	if temporizador_granada > 0:
		return
		
	# Verificar si tenemos munición del tipo seleccionado
	var cantidad_actual = granadas_plasma_actuales if usando_granada_plasma else granadas_frag_actuales
	if cantidad_actual <= 0:
		return
		
	temporizador_granada = cadencia_granada
	
	# Instanciar y restar munición
	var nueva_granada
	if usando_granada_plasma:
		granadas_plasma_actuales -= 1
		cantidad_actual = granadas_plasma_actuales
		nueva_granada = ESCENA_GRANADA_PLASMA.instantiate()
	else:
		granadas_frag_actuales -= 1
		cantidad_actual = granadas_frag_actuales
		nueva_granada = ESCENA_GRANADA_FRAG.instantiate()
	
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_granadas(granadas_frag_actuales, granadas_plasma_actuales, granadas_maximas, usando_granada_plasma)
		
	get_parent().add_child(nueva_granada)
	
	# Lógica física intacta
	var direccion_mouse = (get_global_mouse_position() - global_position).normalized()
	nueva_granada.global_position = _obtener_posicion_segura_granada(direccion_mouse)
	nueva_granada.add_collision_exception_with(self)
	nueva_granada.apply_central_impulse(direccion_mouse * fuerza_lanzamiento)
	
func _mostrar_efecto_escudo():
	if _tween_escudo and _tween_escudo.is_running():
		_tween_escudo.kill()

	modulate = Color(0.2, 0.9, 1.0)
	_tween_escudo = create_tween()
	_tween_escudo.tween_property(self, "modulate", Color.WHITE, 0.4)

func _mostrar_efecto_ruptura_escudo():
	if _tween_escudo and _tween_escudo.is_running():
		_tween_escudo.kill()

	modulate = Color(1.0, 0.2, 0.2)
	_tween_escudo = create_tween()
	_tween_escudo.tween_property(self, "modulate", Color.WHITE, 0.5)

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

func curar_salud_completa() -> bool:
	if salud_actual < salud_maxima:
		salud_actual = salud_maxima
		var hud = get_parent().get_node_or_null("HUD")
		if hud != null:
			hud.actualizar_salud_hud(salud_actual, salud_maxima)
			hud.mostrar_notificacion("Salud restaurada")
		return true
	return false # Si la salud está llena, no lo consume
	
func _agacharse():
	_agachado = true
	# Reducir altura del collider manteniendo los pies en el suelo
	_colision_cuerpo.shape.size = Vector2(35, 60)
	_colision_cuerpo.position = Vector2(0.5, 27.0)
	_pivote_brazo.position = _pos_pivote_crouch
	_area_patada.position.y = 20.0
	
	if temporizador_patada <= 0:
		_sprite_cuerpo.texture = TEXTURA_CROUCH

func _desagacharse():
	_agachado = false
	# Restaurar tamaño de colisión original
	_colision_cuerpo.shape.size = Vector2(35, 103)
	_colision_cuerpo.position = Vector2(0.5, 5.5)
	_pivote_brazo.position = _pos_pivote_stand
	_area_patada.position.y = 0.0
	
	if temporizador_patada <= 0:
		_sprite_cuerpo.texture = TEXTURA_TORSO
