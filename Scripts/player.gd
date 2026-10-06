extends CharacterBody2D

const SPEED = 310.0
const JUMP_VELOCITY = -550.0
const FALL_GRAVITY_MULTIPLIER = 1.8 

# --- SPRITES ---
const TEXTURA_SPRITESHEET = preload("res://Assets/SPRITESHEET_PLAYER.png")
const TEXTURA_MELEE = preload("res://Assets/Conejo_melee.png")

@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo
@onready var _sprite_brazo = $PivoteBrazo/SpriteBrazoArma
@onready var _area_patada = $AreaPatada

@onready var _anim_player = $AnimationPlayer
var _estaba_en_el_aire = false

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

const CROUCH_SPEED = 150.0 
var _agachado: bool = false
var _tecla_agacharse_presionada: bool = false # <--- NUEVA VARIABLE

# Posiciones y dimensiones para la colisión y pivote del brazo
@onready var _colision_cuerpo = $CollisionShape2D
var _pos_pivote_stand = Vector2(-1, -1)
var _pos_pivote_crouch = Vector2(-1, 15) # Baja el pivote de las armas

var _esta_muerto: bool = false

@onready var audio_salto = $AudioSalto
@onready var audio_muerte = $AudioMuerte

@onready var camara = $Camera2D
var desplazamiento_maximo_camara = 60.0 # Ajusta este valor para mayor o menor lejanía


func _ready():
	if Global.hay_datos_guardados:
		global_position = Vector2(Global.pos_x, Global.pos_y)
		Global.restaurar_flags_checkpoint()
		
		# --- NUEVO: RESTAURAR INVENTARIO ---
		if Global.inventario_guardado.size() > 0:
			var inv = Global.inventario_guardado
			salud_actual = inv["salud"]
			escudo_actual = inv["escudo"]
			granadas_frag_actuales = inv["frag"]
			granadas_plasma_actuales = inv["plasma"]
			
			armas.clear() # Limpiamos las armas por defecto
			for arma_nodo in armas_en_escena:
				# Si el arma está en nuestro guardado, la agregamos
				if inv["municion"].has(arma_nodo.name):
					armas.append(arma_nodo)
					if "municion_reserva" in arma_nodo:
						arma_nodo.municion_reserva = inv["municion"][arma_nodo.name]
					elif "bateria" in arma_nodo:
						arma_nodo.bateria = inv["municion"][arma_nodo.name]
						
					if arma_nodo.name == inv["arma_activa"]:
						_arma_actual = arma_nodo
			
			indice_arma_actual = armas.find(_arma_actual)
		else:
			# Lógica por defecto si guardó antes de implementar este sistema
			armas.append(_rifle)
			armas.append(_pistola)
			_arma_actual = armas[0]
	else:
		armas.append(_rifle)
		armas.append(_pistola)
		_arma_actual = armas[0]
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
	if _esta_muerto:
		return
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
	
	# Reproducimos la animación en lugar de cambiar la textura
	_anim_player.play("Patear")
	
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
	if _esta_muerto:
		return
	# Control de temporizadores
	if temporizador_granada > 0:
		temporizador_granada -= delta
		
	if temporizador_bloqueo_disparo > 0:
		temporizador_bloqueo_disparo -= delta
		
	if temporizador_patada > 0:
		temporizador_patada -= delta
		# Eliminamos la línea que restauraba la textura aquí, 
		# ya que el AnimationPlayer maneja los cuadros visuales.

# --- CONTROL DE AGACHARSE (TOGGLE) ---
	var presiona_agacharse = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)
	
	# Solo evaluamos si la tecla se está presionando AHORA y no en el frame anterior
	if presiona_agacharse and not _tecla_agacharse_presionada:
		_tecla_agacharse_presionada = true # Registramos el toque
		
		if is_on_floor():
			if not _agachado:
				# Si está de pie, se agacha
				_agacharse()
			else:
				# Si ya está agachado, intenta ponerse de pie
				if _puede_desagacharse():
					_desagacharse()
					
	elif not presiona_agacharse:
		# Reseteamos el seguro cuando el jugador suelta la tecla
		_tecla_agacharse_presionada = false
	
	# Gravedad
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta
		else:
			velocity.y += gravity * delta
			
	# --- Salto ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		audio_salto.play()
		if not _agachado: # Solo animamos el salto si NO está agachado
			_anim_player.play("Saltar") 

	_apuntar_al_mouse()
	_sincronizar_brazos()
	# --- Movimiento Horizontal ---
	var vel_actual = CROUCH_SPEED if _agachado else SPEED
	var direction = Input.get_axis("left", "right")
	
	if direction:
		velocity.x = direction * vel_actual
		# El giro del torso ya no depende del movimiento:
		# lo maneja _apuntar_al_mouse() según el lado del mouse.
			
		# Solo reproducimos "Correr" si está en el suelo, NO está pateando, 
		# NO está aterrizando y NO está agachado.
		if is_on_floor() and temporizador_patada <= 0 and _anim_player.current_animation != "Aterrizar" and not _agachado:
			_anim_player.play("Correr")
	else:
		velocity.x = move_toward(velocity.x, 0, vel_actual)
		if is_on_floor() and temporizador_patada <= 0 and _anim_player.current_animation == "Correr":
			_anim_player.stop()
			
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

# 1. Guardamos el estado ANTES de aplicar el movimiento físico
	_estaba_en_el_aire = not is_on_floor()

	# 2. Calculamos las colisiones y el nuevo estado del personaje
	move_and_slide()
	
	# 3. Comprobamos INMEDIATAMENTE si acaba de tocar el suelo
	if is_on_floor() and _estaba_en_el_aire:
		_anim_player.play("Aterrizar")

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

	# El torso (y la patada) miran al lado del mouse, sin importar
	# hacia dónde se mueve el jugador.
	var quiere_mirar_derecha = mouse_relativo.x >= 0.0
	if quiere_mirar_derecha != _mirando_derecha:
		_flip_personaje()

	if mouse_relativo.x < 0:
		_pivote_brazo.scale.y = -1 
	else:
		_pivote_brazo.scale.y = 1
		
	# --- NUEVO: Desplazamiento dinámico de la cámara ---
	var direccion_camara = mouse_relativo.normalized()
	# Multiplicar por 0.15 suaviza la distancia para que el cursor no arrastre la cámara al instante
	var distancia_camara = min(mouse_relativo.length() * 0.15, desplazamiento_maximo_camara) 
	camara.offset = direccion_camara * distancia_camara
	

func _flip_personaje():
	_mirando_derecha = not _mirando_derecha
	_sprite_cuerpo.flip_h = not _sprite_cuerpo.flip_h
	
	# --- NUEVO: Compensar el espacio vacío del spritesheet ---
	if _mirando_derecha:
		_sprite_cuerpo.position.x = -60.0 # Posición original
	else:
		# Empujamos el sprite hacia la izquierda. 
		# Puedes ajustar este número si los brazos aún no encajan perfectamente.
		_sprite_cuerpo.position.x = -140.0 
		
	_area_patada.scale.x = -_area_patada.scale.x

func recibir_dano(cantidad: float, tipo_dano: String = "Balistica"):
	if _esta_muerto:
		return
		
	tiempo_sin_dano = 0.0
	
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
		
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
		hud.actualizar_salud_hud(salud_actual, salud_maxima)

	if salud_actual <= 0:
		salud_actual = 0
		_morir()

func _morir():
	if _esta_muerto:
		return
	_esta_muerto = true
	
	audio_muerte.play()
	
	# Detener movimiento e invisibilizar armas
	velocity = Vector2.ZERO
	_pivote_brazo.hide()
	
	# Desactivar colisiones defensivamente
	_colision_cuerpo.set_deferred("disabled", true)
	
	# Notificación y fundido a negro desde el HUD
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		if hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("¡HAS MUERTO!")
		if hud.has_method("hacer_fade_out"):
			hud.hacer_fade_out(1.2)
	
	# Desvanecimiento del sprite del jugador
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	
	# Esperar a que la pantalla se vuelva totalmente negra
	await get_tree().create_timer(1.3).timeout
	
	# Recargar la escena (al iniciar, el HUD ejecutará hacer_fade_in automáticamente)
	get_tree().reload_current_scene()
	
	
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
	# Reducir altura del collider
	_colision_cuerpo.shape.size = Vector2(35, 60)
	_colision_cuerpo.position = Vector2(0.5, 27.0)
	_area_patada.position.y = 20.0
	
	if temporizador_patada <= 0:
		_anim_player.stop() # Detenemos otras animaciones
		_sprite_cuerpo.frame = 7 # Frame de estar quieto
		_sprite_cuerpo.scale = Vector2(0.15, 0.075) # Lo aplastamos a la mitad
		_sprite_cuerpo.position.y = -11.0 # Lo bajamos al suelo (Solo eje Y)

func _desagacharse():
	_agachado = false
	# Restaurar tamaño de colisión
	_colision_cuerpo.shape.size = Vector2(35, 103)
	_colision_cuerpo.position = Vector2(0.5, 5.5)
	_area_patada.position.y = 0.0
	
	if temporizador_patada <= 0:
		_sprite_cuerpo.frame = 7
		_sprite_cuerpo.scale = Vector2(0.15, 0.15) # Escala original
		_sprite_cuerpo.position.y = -79.0 # Altura original (Solo eje Y)
		
func activar_sobreescudo() -> bool:
	# El escudo base es 150, le sumamos 2 capas extra (300 más), llegando a 450
	var sobreescudo_total = escudo_maximo + (escudo_maximo * 2) 
	
	# Solo lo recogemos si no estamos ya al máximo de sobre-escudo
	if escudo_actual < sobreescudo_total:
		escudo_actual = sobreescudo_total
		_mostrar_efecto_escudo() # Reutilizamos tu efecto azul para dar un feedback visual
		
		var hud = get_parent().get_node_or_null("HUD")
		if hud != null:
			# Pasamos los valores al HUD. La barra se mantendrá llena al 100% 
			# hasta que el escudo caiga por debajo de su máximo normal.
			hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
			hud.mostrar_notificacion("¡Sobre-escudo activado!")
		return true
		
	return false # Si ya tiene el sobre-escudo a tope, no consume el rubí

func _puede_desagacharse() -> bool:
	var space_state = get_world_2d().direct_space_state
	
	# Calculamos dónde está la cabeza agachado (y_inicio) y dónde estará de pie (y_fin)
	var y_inicio = global_position.y - 3.0
	var y_fin = global_position.y - 48.0 # Le damos un par de píxeles de margen
	
	# Posiciones X: Izquierda, Centro y Derecha del cuerpo del conejo
	var posiciones_x = [
		global_position.x - 16.0, 
		global_position.x + 0.5,  
		global_position.x + 17.0  
	]
	
	# Disparamos un rayo por cada posición
	for x in posiciones_x:
		var origen = Vector2(x, y_inicio)
		var destino = Vector2(x, y_fin)
		
		var query = PhysicsRayQueryParameters2D.create(origen, destino, collision_mask, [get_rid()])
		var resultado = space_state.intersect_ray(query)
		
		# Si un solo rayo devuelve información, significa que chocó contra el techo
		if resultado:
			return false 
			
	# Si los 3 rayos llegaron hasta arriba sin chocar, hay espacio seguro
	return true

func _sincronizar_brazos():
	# 1. Definimos la altura base (agachado o de pie)
	var base_y = _pos_pivote_crouch.y if _agachado else _pos_pivote_stand.y
	var base_x = _pos_pivote_stand.x # La posición X original (-1)
	
	var offset_x = 0.0
	var offset_y = 0.0
	
	# 2. Leemos el frame actual del Sprite para sincronizar el movimiento
	match _sprite_cuerpo.frame:
		# Frames de Correr (Simula el rebote de los pasos)
		1, 4: offset_y = -2.0
		2, 5: offset_y = -4.0
		3, 6: offset_y = -1.0
		
		# Frames de Saltar y Aterrizar
		8, 9: offset_y = -4.0
		10, 11: offset_y = 2.0
		
		# Frames de Patear (Acompaña la inclinación del cuerpo hacia adelante)
		15: 
			offset_x = 3.0
			offset_y = 1.0
		16: 
			offset_x = 6.0
			offset_y = 2.0
			
	# 3. Aplicamos la posición Y final
	_pivote_brazo.position.y = base_y + offset_y
	
	# 4. Aplicamos la posición X respetando la dirección a la que mira
	if _mirando_derecha:
		_pivote_brazo.position.x = base_x + offset_x
	else:
		_pivote_brazo.position.x = -base_x - offset_x
