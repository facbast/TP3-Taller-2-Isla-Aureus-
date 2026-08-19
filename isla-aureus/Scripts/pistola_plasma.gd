extends Node2D

const BALA_PLASMA = preload("res://Scenes/bala_plasma.tscn")
const BOLA_PLASMA = preload("res://Scenes/carga_plasma.tscn")

@onready var punto_disparo = $PuntoDisparo

# --- VARIABLES DE BATERÍA ---
var bateria: int = 100
var costo_disparo_normal: int = 1
var costo_disparo_cargado: int = 10

# --- VARIABLES DE DISPARO ---
var cadencia: float = 0.15 
var _tiempo_siguiente_disparo: float = 0.0

# --- LÓGICA DE SOBRECARGA ---
var nivel_carga: float = 0.0
var tiempo_para_sobrecarga: float = 1.0 # 1 segundo para cargar a tope
var esta_cargando: bool = false

func _process(delta):
	# Temporizador normal de cadencia
	if _tiempo_siguiente_disparo > 0:
		_tiempo_siguiente_disparo -= delta

	# Lógica principal del disparo cargado
	if esta_cargando:
		# Verificamos si el jugador SIGUE manteniendo el clic
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if nivel_carga < tiempo_para_sobrecarga:
				nivel_carga += delta
				# Opcional: Aquí podrías hacer que la pistola cambie de color o vibre al cargar
		else:
			# El jugador SOLTÓ el clic: efectuamos el disparo
			_soltar_disparo()

# Esta función es llamada por el jugador cuando hace clic
func intentar_disparar():
	if bateria <= 0:
		return # Arma vacía
		
	# Solo empezamos a cargar si no estamos en enfriamiento y no estamos ya cargando
	if _tiempo_siguiente_disparo <= 0 and not esta_cargando:
		esta_cargando = true
		nivel_carga = 0.0

func _soltar_disparo():
	esta_cargando = false
	_tiempo_siguiente_disparo = cadencia
	
	if nivel_carga >= tiempo_para_sobrecarga and bateria >= costo_disparo_cargado:
		# DISPARO SOBRECARGADO
		bateria -= costo_disparo_cargado
		_instanciar_proyectil(BOLA_PLASMA)
	else:
		# DISPARO NORMAL (Si soltó el clic antes de tiempo)
		bateria -= costo_disparo_normal
		_instanciar_proyectil(BALA_PLASMA)
		
	_actualizar_hud()

func _instanciar_proyectil(escena_proyectil):
	var nuevo_proyectil = escena_proyectil.instantiate()
	
	# Usamos current_scene en lugar de get_parent() para que la bala no siga pegada al arma
	get_tree().current_scene.add_child(nuevo_proyectil)
	
	nuevo_proyectil.global_position = punto_disparo.global_position
	# La bala toma la misma rotación que la pistola apuntando al mouse
	nuevo_proyectil.global_rotation = global_rotation

# La pistola de plasma no usa recargas con "R"
func recargar():
	print("El arma usa una batería interna, no se puede recargar.")

func _actualizar_hud():
	var hud = get_parent().get_parent().get_parent().get_node_or_null("HUD")
	if hud == null:
		hud = get_tree().current_scene.get_node_or_null("HUD")
		
	if hud != null:
		# Mostramos la batería actual. Le enviamos un 0 a la reserva porque no tiene.
		hud.actualizar_municion(bateria, 0)
