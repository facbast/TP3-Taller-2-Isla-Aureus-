extends Area2D

@export_category("Enemigos y Oleadas")
@export var escenas_enemigos: Array[PackedScene] ## Escenas de los enemigos que pueden aparecer
@export var total_oleadas: int = 2
@export var enemigos_por_oleada: int = 4
@export var tiempo_entre_enemigos: float = 0.5

@export_category("Referencias")
@export var barrera_entrada: StaticBody2D
@export var barrera_salida: StaticBody2D
@export var contenedor_spawns: Node2D

var oleada_actual: int = 0
var enemigos_vivos: int = 0
var arena_activa: bool = false

func _ready() -> void:
	# Asegurarnos de que las barreras inicien desactivadas
	if barrera_entrada:
		barrera_entrada.process_mode = PROCESS_MODE_DISABLED
		barrera_entrada.hide()
	if barrera_salida:
		barrera_salida.process_mode = PROCESS_MODE_DISABLED
		barrera_salida.hide()

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if arena_activa:
		return
		
	if body.is_in_group("player") or body.is_in_group("Player") or body.name == "Player":
		_iniciar_arena()

func _iniciar_arena() -> void:
	arena_activa = true
	
	print_tree()
	# Activar las barreras para bloquear al jugador
	if barrera_entrada:
		barrera_entrada.process_mode = PROCESS_MODE_INHERIT
		barrera_entrada.show()
	if barrera_salida:
		barrera_salida.process_mode = PROCESS_MODE_INHERIT
		barrera_salida.show()

	_iniciar_siguiente_oleada()

func _iniciar_siguiente_oleada() -> void:
	oleada_actual += 1
	if oleada_actual > total_oleadas:
		_completar_arena()
		return
	# DETECTAR LA PRIMERA OLEADA Y ENVIAR LA NOTIFICACIÓN
	if oleada_actual == 1:
		get_tree().call_group("hud", "mostrar_notificacion", "EMBOSCADA!")
		
	var puntos_spawn = contenedor_spawns.get_children()
	if puntos_spawn.is_empty() or escenas_enemigos.is_empty():
		push_error("Faltan puntos de spawn o escenas de enemigos asignadas.")
		_completar_arena()
		return

	enemigos_vivos = enemigos_por_oleada

	for i in range(enemigos_por_oleada):
		await get_tree().create_timer(tiempo_entre_enemigos).timeout
		_spawnear_enemigo(puntos_spawn)

func _spawnear_enemigo(puntos_spawn: Array[Node]) -> void:
	# Selecciona un punto de spawn y un tipo de enemigo al azar
	var punto_elegido = puntos_spawn.pick_random() as Node2D
	var escena_elegida = escenas_enemigos.pick_random() as PackedScene
	
	var enemigo = escena_elegida.instantiate() as Node2D
	enemigo.global_position = punto_elegido.global_position
	
	# Detectar cuando el enemigo muera (cuando salga del árbol de escena / sea destruido)
	enemigo.tree_exited.connect(_on_enemigo_derrotado)
	
	get_parent().add_child(enemigo)

func _on_enemigo_derrotado() -> void:
	if not arena_activa:
		return
		
	enemigos_vivos -= 1
	
	# Si se eliminaron todos los enemigos de la oleada actual, pasar a la siguiente
	if enemigos_vivos <= 0:
		_iniciar_siguiente_oleada()

func _completar_arena() -> void:
	arena_activa = false
	
	# Desactivar y ocultar las barreras
	if barrera_entrada:
		barrera_entrada.process_mode = PROCESS_MODE_DISABLED
		barrera_entrada.hide()
	if barrera_salida:
		barrera_salida.process_mode = PROCESS_MODE_DISABLED
		barrera_salida.hide()
