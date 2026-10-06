extends Sprite2D

# Exportamos la escena para elegir desde el Inspector si usa bala de jugador o de enemigo
@export var escena_bala: PackedScene = preload("res://Scenes/bala.tscn")

@onready var _punto_disparo = $PuntoDisparo

# --- VARIABLES DE LA MAGNUM ---
var cadencia_disparo = 1.0 # Más lento, simulando el ritmo semi-automático y el retroceso
var temporizador_disparo = 0.0

var municion_cargador_max = 8 
var municion_cargador = 8
var municion_reserva = 40
var esta_recargando = false  
var tiempo_recarga = 1.2      

var dano_por_bala = 25.0 # Daño altísimo
var dispersion_maxima = 0.0 # Precisión perfecta (sin dispersión)

func _ready():
	# Si quien sostiene el arma NO es el jugador, le damos munición infinita
	if not owner.is_in_group("player"):
		municion_reserva = 9999

func _process(delta):
	temporizador_disparo += delta

func intentar_disparar() -> bool:
	if esta_recargando:
		return false
		
	if municion_cargador > 0:
		if temporizador_disparo >= cadencia_disparo:
			temporizador_disparo = 0.0 
			municion_cargador -= 1
			_efectuar_disparo()
			_actualizar_hud()
			return true 
	else:
		recargar()
		
	return false

func _efectuar_disparo():
	var nueva_bala = escena_bala.instantiate()
	owner.get_parent().add_child(nueva_bala) 
	
	nueva_bala.global_position = _punto_disparo.global_position
	nueva_bala.global_rotation = global_rotation
	
	# Sobrescribimos el daño de la bala con el de esta pistola
	if "dano" in nueva_bala:
		nueva_bala.dano = dano_por_bala

func recargar():
	if esta_recargando or municion_cargador == municion_cargador_max or municion_reserva <= 0:
		return
		
	esta_recargando = true
	
	await get_tree().create_timer(tiempo_recarga).timeout 
	
	var balas_faltantes = municion_cargador_max - municion_cargador
	if municion_reserva >= balas_faltantes:
		municion_cargador += balas_faltantes
		municion_reserva -= balas_faltantes
	else:
		municion_cargador += municion_reserva
		municion_reserva = 0
		
	esta_recargando = false
	_actualizar_hud()

func _actualizar_hud():
	# Solo intentamos tocar el HUD si el dueño del arma es el Jugador
	if owner.is_in_group("player"):
		var hud = owner.get_parent().get_node_or_null("HUD")
		if hud != null:
			hud.actualizar_municion(municion_cargador, municion_reserva, "Pistola")
