extends Node2D

const BALA_PLASMA = preload("res://Scenes/bala_plasma.tscn")
const BOLA_PLASMA = preload("res://Scenes/carga_plasma.tscn")

@onready var punto_disparo = $PuntoDisparo
@onready var audio_carga = $AudioCarga
# --- VARIABLES DE BATERÍA ---
var bateria: int = 100
var costo_disparo_normal: int = 1
var costo_disparo_cargado: int = 10

# --- VARIABLES DE DISPARO ---
var cadencia: float = 0.25 
var _tiempo_siguiente_disparo: float = 0.0
var es_de_enemigo: bool = false
# --- LÓGICA DE SOBRECARGA ---
var nivel_carga: float = 0.0
var tiempo_para_sobrecarga: float = 1.0 # 1 segundo para cargar a tope
var esta_cargando: bool = false

# Barra de carga visual sobre el jugador (solo cuando el jugador usa el arma).
var _es_jugador: bool = false
var _jugador: Node2D
var _barra_carga: ColorRect
const ANCHO_BARRA: float = 100.0
const ALTO_BARRA: float = 8.0

func _ready():
	# Auto-detectamos si el arma pertenece a un enemigo buscando en la jerarquía
	var dueno = get_parent().get_parent()
	if dueno != null and dueno.is_in_group("enemigos"):
		es_de_enemigo = true
	_es_jugador = dueno != null and dueno.is_in_group("player")
	_jugador = dueno

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
				if audio_carga:
					audio_carga.play()
			
				queue_redraw() # <-- ACTUALIZA EL DIBUJO CADA FRAME
				if _es_jugador:
					_actualizar_barra_carga()
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
		if _es_jugador:
			_crear_barra_carga()

func _soltar_disparo():
	esta_cargando = false
	_tiempo_siguiente_disparo = cadencia
	queue_redraw() # <-- BORRA EL CÍRCULO AL DISPARAR
	if _es_jugador:
		_destruir_barra_carga()
	
	if nivel_carga >= tiempo_para_sobrecarga and bateria >= costo_disparo_cargado:
		bateria -= costo_disparo_cargado
		_instanciar_proyectil(BOLA_PLASMA, "PlasmaCargado") 
	else:
		bateria -= costo_disparo_normal
		_instanciar_proyectil(BALA_PLASMA, "Plasma") 
		
	_actualizar_hud()

# Modificamos la función para que acepte un segundo argumento (el texto)
func _instanciar_proyectil(escena_proyectil, tipo_de_ataque: String):
	var nuevo_proyectil = escena_proyectil.instantiate()
	
	# Le informamos al proyectil quién lo disparó
	if "es_de_enemigo" in nuevo_proyectil:
		nuevo_proyectil.es_de_enemigo = es_de_enemigo
	if "bando" in nuevo_proyectil:
		var dueno_bando = get_parent().get_parent()
		if dueno_bando != null and dueno_bando.is_in_group("avispas"):
			nuevo_proyectil.bando = "avispas"
		
	# --- NUEVO: ASIGNAMOS EL TIPO DE DAÑO ---
	if "tipo_dano" in nuevo_proyectil:
		nuevo_proyectil.tipo_dano = tipo_de_ataque
		
	get_tree().current_scene.add_child(nuevo_proyectil)
	nuevo_proyectil.global_position = punto_disparo.global_position
	nuevo_proyectil.global_rotation = global_rotation
# La pistola de plasma no usa recargas con "R"
func recargar():
	print("El arma usa una batería interna, no se puede recargar.")

func _actualizar_hud():
	# --- NUEVO: Si el arma es de un enemigo, abortamos la actualización ---
	if es_de_enemigo:
		return 
		
	var hud = get_parent().get_parent().get_parent().get_node_or_null("HUD")
	if hud == null:
		hud = get_tree().current_scene.get_node_or_null("HUD")
		
	if hud != null:
		# Mostramos la batería actual. Le enviamos un -1 a la reserva porque no tiene.
		hud.actualizar_municion(int(bateria), -1, "PistolaPlasma")
		
func _draw():
	if esta_cargando and nivel_carga > 0:
		# Define el tamaño máximo que alcanzará la bola de luz
		var radio_maximo = 12.0 
		
		# Calcula el porcentaje de carga (de 0.0 a 1.0)
		var porcentaje_carga = clamp(nivel_carga / tiempo_para_sobrecarga, 0.0, 1.0)
		var radio_actual = radio_maximo * porcentaje_carga
		
		# Dibuja el círculo en la posición del PuntoDisparo
		# Color: (Rojo, Verde, Azul, Transparencia). 1,1,0 es amarillo brillante.
		draw_circle(punto_disparo.position, radio_actual, Color(1.0, 1.0, 0.2, 0.8))

# Crea la barra de carga amarilla limón sobre el jugador.
func _crear_barra_carga() -> void:
	if _barra_carga != null:
		return
	_barra_carga = ColorRect.new()
	_barra_carga.name = "BarraCargaPlasma"
	_barra_carga.color = Color(1.0, 1.0, 0.0, 1.0) # Amarillo limón
	_barra_carga.size = Vector2(0, ALTO_BARRA)
	_barra_carga.position = Vector2(-ANCHO_BARRA / 2, -40) # Sobre la cabeza del jugador
	if _jugador != null:
		_jugador.add_child(_barra_carga)

# Actualiza el ancho de la barra según el porcentaje de carga.
func _actualizar_barra_carga() -> void:
	if _barra_carga == null:
		return
	var porcentaje = clamp(nivel_carga / tiempo_para_sobrecarga, 0.0, 1.0)
	_barra_carga.size = Vector2(ANCHO_BARRA * porcentaje, ALTO_BARRA)

# Elimina la barra de carga cuando termina el disparo.
func _destruir_barra_carga() -> void:
	if _barra_carga != null:
		_barra_carga.queue_free()
		_barra_carga = null
