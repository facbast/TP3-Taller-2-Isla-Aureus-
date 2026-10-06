extends Node2D

# Usamos la bala de plasma del jugador (o ajusta la ruta a tu escena de bala)
const BALA_PLASMA = preload("res://Scenes/bala_plasma.tscn") 

# --- ESTADÍSTICAS BÁSICAS ---
@export var cadencia: float = 0.15 
@export var bateria_maxima: float = 100.0
var bateria: float = 100.0
var costo_bateria: float = 1.0
var es_de_enemigo: bool = false # <-- NUEVO: Identificador de bando

# --- SISTEMA DE CALOR ---
@export var calor_por_disparo: float = 12.0
@export var velocidad_enfriamiento: float = 35.0
var calor_actual: float = 0.0
var sobrecalentado: bool = false

var temporizador_disparo: float = 0.0

# --- REFERENCIAS ---
@onready var _punto_disparo = $PuntoDisparo
@onready var _sprite = $Sprite2D

func _ready():
	bateria = bateria_maxima
	
	# Detectamos automáticamente si el arma está en manos de un enemigo o del jugador
	var dueno = get_parent().get_parent()
	if dueno != null and dueno.is_in_group("enemigos"):
		es_de_enemigo = true

func _process(delta):
	if temporizador_disparo > 0:
		temporizador_disparo -= delta
		
	# --- LÓGICA DE ENFRIAMIENTO ---
	if calor_actual > 0:
		calor_actual -= velocidad_enfriamiento * delta
		if calor_actual <= 0:
			calor_actual = 0.0
			if sobrecalentado:
				sobrecalentado = false 
				_sprite.modulate = Color.WHITE

func intentar_disparar():
	if bateria <= 0 or sobrecalentado:
		return 
		
	if temporizador_disparo <= 0:
		_disparar()

func _disparar():
	temporizador_disparo = cadencia
	bateria -= costo_bateria
	
	_actualizar_hud()
	
	calor_actual += calor_por_disparo
	if calor_actual >= 100.0:
		calor_actual = 100.0
		sobrecalentado = true
		_sprite.modulate = Color(1.0, 0.4, 0.4)
		
	var nueva_bala = BALA_PLASMA.instantiate()
	
	# 1. Le asignamos el bando a la bala
	if "es_de_enemigo" in nueva_bala:
		nueva_bala.es_de_enemigo = es_de_enemigo
		
	if "tipo_dano" in nueva_bala:
		nueva_bala.tipo_dano = "Plasma"
		
	get_tree().current_scene.add_child(nueva_bala)
	
	# 2. Excluimos colisión explícita con quien dispara
	var dueno = get_parent().get_parent()
	if dueno and nueva_bala.has_method("add_collision_exception_with"):
		nueva_bala.add_collision_exception_with(dueno)

	nueva_bala.global_position = _punto_disparo.global_position
	
	var direccion_disparo = _punto_disparo.global_transform.x.normalized()
	
	if "direccion" in nueva_bala:
		nueva_bala.direccion = direccion_disparo
		
	if "velocidad" in nueva_bala:
		nueva_bala.velocidad = 600.0 
		
	nueva_bala.global_rotation = direccion_disparo.angle()

func recargar():
	print("El Rifle de Plasma usa batería interna y no se puede recargar.")

func _actualizar_hud():
	# Si el arma le pertenece a un enemigo, no actualizamos el HUD del jugador
	if es_de_enemigo:
		return

	var hud = get_parent().get_node_or_null("HUD")
	if hud == null:
		hud = get_tree().current_scene.get_node_or_null("HUD")
		
	if hud != null:
		hud.actualizar_municion(int(bateria), -1, "RiflePlasma")
