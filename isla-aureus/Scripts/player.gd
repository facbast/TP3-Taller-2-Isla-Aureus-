extends CharacterBody2D

const SPEED = 250.0
const JUMP_VELOCITY = -450.0
const FALL_GRAVITY_MULTIPLIER = 1.8 

@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo
@onready var _sprite_brazo = $PivoteBrazo/SpriteBrazoArma

# --- NUEVAS REFERENCIAS AL INVENTARIO ---
@onready var _rifle = $PivoteBrazo/Rifle
@onready var _pistola = $PivoteBrazo/Pistola
@onready var _pistola_plasma = $PivoteBrazo/PistolaPlasma

var armas = []
var indice_arma_actual = 0
var _arma_actual = null # Ahora esta variable será dinámica

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _mirando_derecha = true

# --- VARIABLES DE SALUD Y ESCUDO ---
var salud_maxima = 100.0
var salud_actual = 100.0
var escudo_maximo = 100.0
var escudo_actual = 100.0

# --- VARIABLES DE GRANADAS ---
const ESCENA_GRANADA = preload("res://Scenes/granada.tscn")
var granadas_actuales = 4
var granadas_maximas = 4
var fuerza_lanzamiento = 600.0 # Qué tan fuerte la arroja

var tiempo_espera_escudo = 4.0      
var tiempo_sin_dano = 0.0           
var velocidad_recarga_escudo = 40.0 

func _ready():
	# Inicializamos el inventario y configuramos el arma inicial
	armas = [_rifle, _pistola, _pistola_plasma]
	_arma_actual = armas[indice_arma_actual]
	
	_rifle.show()
	_pistola.hide()

	await get_tree().process_frame
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
		hud.actualizar_salud_hud(salud_actual, salud_maxima)
		hud.actualizar_granadas(granadas_actuales, granadas_maximas)
	
	# El arma actual actualiza el HUD con su propia munición
	if _arma_actual.has_method("_actualizar_hud"):
		_arma_actual._actualizar_hud()

# --- SISTEMA DE ENTRADA (INPUT) INDEPENDIENTE ---
func _unhandled_input(event):
	# Cambio de armas con TAB
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			cambiar_arma()
			
	# Lanzamiento de granada con Clic Derecho
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			lanzar_granada()

func cambiar_arma():
	# 1. Ocultamos el arma que tenemos actualmente en las manos
	_arma_actual.hide()
	
	# 2. Pasamos a la siguiente arma (si estamos en la 1, volvemos a la 0)
	indice_arma_actual = (indice_arma_actual + 1) % armas.size()
	_arma_actual = armas[indice_arma_actual]
	
	# 3. Mostramos la nueva arma
	_arma_actual.show()
	
	# 4. Le decimos a la nueva arma que envíe sus datos de munición a la interfaz
	if _arma_actual.has_method("_actualizar_hud"):
		_arma_actual._actualizar_hud()

func _physics_process(delta):
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

	# Movimiento Horizontal
	var direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		if (direction > 0 and not _mirando_derecha) or (direction < 0 and _mirando_derecha):
			_flip_personaje()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

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

	# Acciones delegadas al arma actual
	if Input.is_physical_key_pressed(KEY_R):
		_arma_actual.recargar()
		
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_arma_actual.intentar_disparar()
			
	# DAÑO PLACEHOLDER
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		recibir_dano(1.0) 

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

func recibir_dano(cantidad: float, tipo_dano: String = "Balistica"):
	tiempo_sin_dano = 0.0
	
	# Definimos los multiplicadores base
	var multiplicador_escudo = 1.0
	var multiplicador_salud = 1.0
	
	# Ajustamos según el tipo de arma
	if tipo_dano == "Plasma":
		multiplicador_escudo = 2.0
		multiplicador_salud = 0.5
	elif tipo_dano == "Balistica":
		multiplicador_escudo = 0.5
		multiplicador_salud = 1.5
		
	# Aplicamos el daño a los escudos
	if escudo_actual > 0:
		var dano_al_escudo = cantidad * multiplicador_escudo
		escudo_actual -= dano_al_escudo
		
		# Si el escudo se rompe, el daño sobrante pasa a la salud
		if escudo_actual < 0:
			# Normalizamos el daño sobrante de vuelta a su valor original
			var dano_restante_base = abs(escudo_actual) / multiplicador_escudo
			escudo_actual = 0
			# Y lo aplicamos a la salud con el multiplicador correspondiente
			salud_actual -= (dano_restante_base * multiplicador_salud)
	else:
		# Si ya no hay escudo, todo el daño va a la salud
		salud_actual -= (cantidad * multiplicador_salud)
		
	if salud_actual <= 0:
		salud_actual = 0
		print("¡EL JEFE MAESTRO HA MUERTO!")
			
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
		hud.actualizar_salud_hud(salud_actual, salud_maxima)
		
func recoger_arma(nombre_arma: String, cantidad_municion: int) -> bool:
	for arma in armas:
		if arma.name == nombre_arma: 
			arma.municion_reserva += cantidad_municion
			
			var hud = get_parent().get_node_or_null("HUD")
			if hud != null:
				# 1. Actualizamos los números si tenemos el arma en las manos
				if arma == _arma_actual and arma.has_method("_actualizar_hud"):
					arma._actualizar_hud()
				
				# 2. ENVIAMOS LA NOTIFICACIÓN AL HUD
				var texto_mensaje = "Has recogido " + str(cantidad_municion) + " de munición de " + nombre_arma
				hud.mostrar_notificacion(texto_mensaje)
				
			return true 
			
	return false

func lanzar_granada():
	if granadas_actuales <= 0:
		return # Sin granadas no hacemos nada
		
	granadas_actuales -= 1
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_granadas(granadas_actuales, granadas_maximas)
		
	var nueva_granada = ESCENA_GRANADA.instantiate()
	get_parent().add_child(nueva_granada)
	
	# 1. Calculamos la dirección del mouse primero
	var direccion_mouse = (get_global_mouse_position() - global_position).normalized()
	
	# 2. Hacemos que aparezca un poco más arriba (-30 en Y) y separada del jugador (+40 px)
	nueva_granada.global_position = global_position + Vector2(0, -30) + (direccion_mouse * 40.0)
	
	# 3. EXCEPCIÓN DE COLISIÓN: La granada ignorará el cuerpo de este jugador al nacer
	nueva_granada.add_collision_exception_with(self)
	
	# 4. Le aplicamos el impulso físico
	nueva_granada.apply_central_impulse(direccion_mouse * fuerza_lanzamiento)
