extends CharacterBody2D

# Constantes ajustadas para el peso (igual que antes)
const SPEED = 250.0
const JUMP_VELOCITY = -450.0
const FALL_GRAVITY_MULTIPLIER = 1.8 

# REFERENCIAS A LOS NUEVOS NODOS (Godot 4 usas @onready)
# Asegúrate de que los nombres coincidan con los de tu escena
@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo
@onready var _sprite_brazo = $PivoteBrazo/SpriteBrazoArma

# --- REFERENCIAS DE DISPARO ---
const BALA_ESCENA = preload("res://Scenes/bala.tscn") # Asegúrate de que la ruta sea correcta
@onready var _punto_disparo = $PivoteBrazo/PuntoDisparo

var cadencia_disparo = 0.1 # 10 balas por segundo (estilo Rifle de Asalto)
var temporizador_disparo = 0.0

# Obtenemos la gravedad global
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Flag para saber hacia dónde miraba el cuerpo
var _mirando_derecha = true

# --- VARIABLES DE ARMAS (Placeholder Rifle de Asalto) ---
var municion_cargador_max = 60 # El tope del cargador
var municion_cargador = 60
var municion_reserva = 600

var _esta_recargando = false  # Bandera para saber si estamos recargando
var tiempo_recarga = 1.5      # Segundos que tarda la animación de recarga

# --- VARIABLES DE SALUD Y ESCUDO ---
var salud_maxima = 100.0
var salud_actual = 100.0
var escudo_maximo = 100.0
var escudo_actual = 100.0

# --- REGENERACIÓN DE ESCUDO ---
var tiempo_espera_escudo = 4.0      # Segundos sin recibir daño para iniciar recarga
var tiempo_sin_dano = 0.0           # Cronómetro interno
var velocidad_recarga_escudo = 40.0 # Puntos de escudo recuperados por segundo (40 = se llena en 2.5 seg)

func _ready():
	await get_tree().process_frame
	# Inicializamos el HUD apenas carga el juego
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
		hud.actualizar_salud_hud(salud_actual, salud_maxima)
		hud.actualizar_municion(municion_cargador, municion_reserva)

func _physics_process(delta):
	# (1. Lógica de Gravedad y 2. Salto, igual que en el script anterior...)
	# --- CÓDIGO ANTERIOR ---
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * FALL_GRAVITY_MULTIPLIER * delta
		else:
			velocity.y += gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# --- FIN CÓDIGO ANTERIOR ---

	# 3. Manejar el Apuntado Procedimental con el Mouse
	_apuntar_al_mouse()

	# 4. Manejar el Movimiento Horizontal y voltear el cuerpo
	var direction = Input.get_axis("left", "right")
	
	if direction:
		velocity.x = direction * SPEED
		# Si caminamos a la izquierda y mirábamos a la derecha (o viceversa)
		if (direction > 0 and not _mirando_derecha) or (direction < 0 and _mirando_derecha):
			_flip_personaje()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

# --- REGENERACIÓN DE ESCUDO AUTOMÁTICA ---
	# Solo calculamos esto si el jugador está vivo y su escudo no está lleno
	if salud_actual > 0 and escudo_actual < escudo_maximo:
		
		# 1. Sumamos el tiempo que pasó desde el último fotograma
		tiempo_sin_dano += delta 
		
		# 2. Si pasaron los 4 segundos (o el tiempo que configuraste)
		if tiempo_sin_dano >= tiempo_espera_escudo:
			
			# 3. Sumamos escudo basado en la velocidad y el tiempo (delta)
			escudo_actual += velocidad_recarga_escudo * delta
			
			# 4. Asegurarnos de no sobrepasar el máximo (100)
			if escudo_actual >= escudo_maximo:
				escudo_actual = escudo_maximo
				
			# 5. Actualizamos el HUD fotograma a fotograma para ver la barra subir suavemente
			var hud = get_parent().get_node_or_null("HUD")
			if hud != null:
				hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)

	# 5. Ejecutar el movimiento
	move_and_slide()

	# --- SISTEMA DE ARMAS ---
	# Presionar 'R' para recargar
	if Input.is_physical_key_pressed(KEY_R):
		recargar()
		
	# --- SISTEMA DE ARMAS ---
	# Presionar 'R' para recargar
	if Input.is_physical_key_pressed(KEY_R):
		recargar()
		
	# 1. Sumamos tiempo al temporizador constantemente
	temporizador_disparo += delta
		
	# 2. Lógica de disparo real (Mantenido)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _esta_recargando:
		# Verificamos si tenemos balas
		if municion_cargador > 0:
			# Verificamos si ya pasó suficiente tiempo desde la última bala
			if temporizador_disparo >= cadencia_disparo:
				temporizador_disparo = 0.0 # Reiniciamos el temporizador
				municion_cargador -= 1
				
				disparar() # Llamamos a la nueva función que crea la bala
				
				# Actualizamos el HUD
				var hud = get_parent().get_node_or_null("HUD")
				if hud != null:
					hud.actualizar_municion(municion_cargador, municion_reserva)
		else:
			# Si mantienes el gatillo y no hay balas, recarga
			recargar()
			
	# --- PLACEHOLDER DE RECIBIR DAÑO (Clic Derecho) ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		recibir_dano(1.0) # Recibe 1 punto de daño por frame


func _apuntar_al_mouse():
	# get_global_mouse_position() obtiene la coordenada X,Y del mouse en el mundo
	var mouse_pos = get_global_mouse_position()
	
	# La función mágica: el pivote rotará automáticamente para "mirar" al mouse
	_pivote_brazo.look_at(mouse_pos)
	
	# --- AJUSTE DE VOLTEADO VERTICAL DEL ARMA ---
	# Si el pivote rota demasiado y el arma queda "boca abajo" (entre -90 y 90 grados)
	# debemos voltear verticalmente el sprite del arma para que el "arriba" sea arriba.
	
	var rotacion_brazo = _pivote_brazo.global_rotation_degrees
	
	# Ajuste para Godot: detectamos si el mouse está atrás o adelante del personaje
	var mouse_relativo = get_local_mouse_position()
	
	if mouse_relativo.x < 0:
		# Mouse está atrás del personaje
		_sprite_brazo.flip_v = true # Voltear verticalmente el arma
	else:
		# Mouse está adelante del personaje
		_sprite_brazo.flip_v = false

func _flip_personaje():
	# Voltear la bandera
	_mirando_derecha = not _mirando_derecha
	
	# Volteamos el cuerpo
	_sprite_cuerpo.flip_h = not _sprite_cuerpo.flip_h
	
	# MUY IMPORTANTE: Cuando el cuerpo voltea (mira a la izquierda),
	# el pivote del hombro también debe "viajar" al otro lado del torso.
	# Suponiendo que el pivote estaba en X=10 para el hombro derecho...
	# al voltear, debe moverse a X=-10 para el hombro izquierdo (relativo al cuerpo).
	_pivote_brazo.position.x = -_pivote_brazo.position.x

func recibir_dano(cantidad: float):
	tiempo_sin_dano = 0.0
	# Si tenemos escudo, el daño va al escudo
	if escudo_actual > 0:
		escudo_actual -= cantidad
		if escudo_actual < 0:
			# Si el escudo se rompe, el daño sobrante pasa a la salud
			var dano_sobrante = abs(escudo_actual)
			escudo_actual = 0
			salud_actual -= dano_sobrante
	else:
		# Si no hay escudo, el daño va directo a la salud
		salud_actual -= cantidad
		if salud_actual <= 0:
			salud_actual = 0
			print("¡EL JEFE MAESTRO HA MUERTO!")
			
	# Actualizar el HUD
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_escudos_hud(escudo_actual, escudo_maximo)
		hud.actualizar_salud_hud(salud_actual, salud_maxima)

func disparar():
	var nueva_bala = BALA_ESCENA.instantiate()
	
	# Usar get_parent() para que la bala nazca en el escenario (Main)
	get_parent().add_child(nueva_bala)
	
	nueva_bala.global_position = _punto_disparo.global_position
	nueva_bala.global_rotation = _pivote_brazo.global_rotation
	
	
func recargar():
	# Si ya está recargando, o el cargador está lleno, o no hay reserva, cancelamos
	if _esta_recargando or municion_cargador == municion_cargador_max or municion_reserva <= 0:
		return
		
	_esta_recargando = true
	print("Recargando...") # Para que lo veas en la consola
	
	# --- EL TEMPORIZADOR MAGICO DE GODOT 4 ---
	# Esto pausa ESTA función durante 'tiempo_recarga' segundos, pero el juego sigue
	await get_tree().create_timer(tiempo_recarga).timeout 
	
	# Calculamos cuántas balas necesitamos para llenar el cargador
	var balas_faltantes = municion_cargador_max - municion_cargador
	
	if municion_reserva >= balas_faltantes:
		# Hay suficientes balas en reserva para llenarlo al tope
		municion_cargador += balas_faltantes
		municion_reserva -= balas_faltantes
	else:
		# No alcanzan para llenarlo, ponemos las que queden
		municion_cargador += municion_reserva
		municion_reserva = 0
		
	_esta_recargando = false
	print("¡Recarga completa!")
	
	# Actualizamos el HUD
	var hud = get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.actualizar_municion(municion_cargador, municion_reserva)
