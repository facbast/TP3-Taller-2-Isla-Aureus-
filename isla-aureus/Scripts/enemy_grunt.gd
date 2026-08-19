extends CharacterBody2D

@export var velocidad: float = 120.0
@export var distancia_deteccion: float = 500.0 
@export var distancia_minima: float = 250.0  
@export var salud: float = 30.0

@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo
@onready var _sprite_brazo = $PivoteBrazo/SpriteBrazoArma
@onready var _arma_actual = $PivoteBrazo/SpriteArma 

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

func _ready():
	_jugador = get_tree().get_first_node_in_group("player")
	if _jugador == null:
		_jugador = get_parent().get_node_or_null("Player")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	# Reducir el tiempo de recarga de la granada
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

	# 2. MÁQUINA DE ESTADOS (Huir vs Combatir)
	if granada_mas_peligrosa != null:
		# --- ESTADO: PÁNICO ---
		var direccion_escape = sign(global_position.x - granada_mas_peligrosa.global_position.x)
		if direccion_escape == 0:
			direccion_escape = 1 if randf() > 0.5 else -1
			
		velocity.x = direccion_escape * (velocidad * multiplicador_velocidad_panico)
		
		if _jugador != null and is_instance_valid(_jugador):
			_apuntar_al_jugador()
			
	elif _jugador != null and is_instance_valid(_jugador):
		# --- ESTADO: COMBATE NORMAL ---
		var distancia_jugador = global_position.distance_to(_jugador.global_position)
		
		if distancia_jugador < distancia_deteccion:
			_apuntar_al_jugador()
			
			# --- DECISIÓN TÁCTICA: ¿Lanzar Granada? ---
			if temporizador_granada <= 0 and distancia_jugador > distancia_min_lanzar and distancia_jugador < distancia_max_lanzar:
				_lanzar_granada()
				# Reseteamos el temporizador con un número aleatorio entre 4 y 8 segundos
				temporizador_granada = randf_range(4.0, 8.0)
			
			# Lógica de kiting (Acercarse o alejarse)
			if distancia_jugador > distancia_minima + 15.0:
				var direccion_x = sign(_jugador.global_position.x - global_position.x)
				velocity.x = direccion_x * velocidad
			elif distancia_jugador < distancia_minima - 15.0:
				var direccion_x = sign(global_position.x - _jugador.global_position.x)
				velocity.x = direccion_x * velocidad
			else:
				velocity.x = move_toward(velocity.x, 0, velocidad)
			
			_arma_actual.intentar_disparar()
			
		else:
			velocity.x = move_toward(velocity.x, 0, velocidad)
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad)

	move_and_slide()

# --- NUEVA FUNCIÓN ---
func _lanzar_granada():
	var nueva_granada = ESCENA_GRANADA.instantiate()
	get_parent().add_child(nueva_granada)
	
	# Calculamos el vector directo hacia el jugador
	var direccion_jugador = (_jugador.global_position - global_position).normalized()
	
	# TRUCO: Le restamos un poco a la Y (hacia arriba en 2D) para que la lance en forma de arco/parábola 
	direccion_jugador.y -= 0.6
	direccion_jugador = direccion_jugador.normalized()
	
	# Hacemos que aparezca frente al enemigo y un poco arriba
	nueva_granada.global_position = global_position + Vector2(0, -30) + (direccion_jugador * 40.0)
	
	# Excepción para que el enemigo no colisione con su propia granada al nacer
	nueva_granada.add_collision_exception_with(self)
	
	# Aplicamos la fuerza física
	nueva_granada.apply_central_impulse(direccion_jugador * fuerza_lanzamiento_granada)

# ... (El resto de tus funciones: _apuntar_al_jugador, _flip_enemigo, recibir_dano y _soltar_arma se mantienen igual) ...

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
	var multiplicador_salud = 1.0
	
	# Ajustamos el daño dependiendo de qué le pegó
	if tipo_dano == "Plasma":
		multiplicador_salud = 0.5 # Resiste el plasma
	elif tipo_dano == "Balistica":
		multiplicador_salud = 1.5 # Débil a las balas
	# Si es "Explosivo" (Granadas), el multiplicador se queda en 1.0 (daño normal)
		
	# Aplicamos el daño modificado a su salud
	salud -= (cantidad * multiplicador_salud)
	
	if salud <= 0:
		_soltar_arma()
		queue_free()

func _soltar_arma():
	var arma_caida = ARMA_SOLTADA.instantiate()
	arma_caida.tipo_arma = "Pistola"
	arma_caida.textura_arma = _arma_actual.texture
	get_parent().call_deferred("add_child", arma_caida)
	arma_caida.global_position = global_position
