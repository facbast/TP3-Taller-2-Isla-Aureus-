extends CharacterBody2D
## Avispa bombardera (tercer tipo: pelaje verde): mantiene techo vertical
## sobre su objetivo, se desplaza en horizontal para alinearse y deja caer
## huevos que explotan al contacto. Sin aguijón: su peligro es la carga.

const HUEVO = preload("res://Scenes/huevo.tscn")
const SONIDO_LLAMADO = preload("res://SFX/Panal/Llamado_Avispa.wav")

@export var velocidad: float = 150.0
@export var distancia_deteccion: float = 900.0
@export var salud: float = 20.0
# Techo que intenta mantener sobre el objetivo (pixeles por encima).
@export var altura_sobre_objetivo: float = 260.0
# Suelta el huevo solo con esta alineación horizontal.
@export var tolerancia_soltar: float = 70.0
@export var cadencia_huevo: float = 2.4
@export var radio_vagancia: float = 140.0
@export var amplitud_flote: float = 10.0
@export var ritmo_flote: float = 3.0
# El sprite base mira a la izquierda: al moverse a la derecha se espeja.
@export var textura_mira_derecha: bool = false

var salud_maxima: float = 20.0
var es_alerta: bool = false # En caza: también activa la música de pelea

var _objetivo: Node2D = null
var _pos_origen: Vector2
var _tiempo: float = 0.0
var _fase_vagar: float = 0.0
var _tiempo_reevaluar: float = 0.0
var _cd_huevo: float = 0.0
var _flash_dano: float = 0.0
var _muerta: bool = false
var _audio_llamado: AudioStreamPlayer2D

@onready var _sprite_cuerpo = $SpriteCuerpo

func _ready():
	# Si ya la derrotamos en esta partida (checkpoint), no reaparece.
	if not has_meta("es_spawn_arena") and Global.estaba_eliminado(self):
		queue_free()
		return
	_audio_llamado = AudioStreamPlayer2D.new()
	_audio_llamado.name = "AudioLlamado"
	_audio_llamado.stream = SONIDO_LLAMADO
	_audio_llamado.volume_db = -4.0
	add_child(_audio_llamado)
	salud_maxima = salud
	_pos_origen = global_position
	_fase_vagar = randf() * TAU

## La emboscada lo llama tras posicionar el spawn: deriva y correa
## miden desde el marker, no desde el (0,0) previo al posicionado.
func fijar_origen() -> void:
	_pos_origen = global_position

func _physics_process(delta):
	if _muerta:
		return
	_tiempo += delta
	if _cd_huevo > 0.0:
		_cd_huevo -= delta
	if _flash_dano > 0.0:
		_flash_dano -= delta
		if _flash_dano <= 0.0:
			_sprite_cuerpo.modulate = Color.WHITE

	_tiempo_reevaluar -= delta
	if _objetivo == null or _tiempo_reevaluar <= 0.0:
		_tiempo_reevaluar = 0.4
		_buscar_objetivo()

	if is_instance_valid(_objetivo):
		_cazar_techo()
	else:
		_vagar(delta)

	# Flote perpetuo: cabeceo visual sobre el cuerpo (no mueve la colisión).
	_sprite_cuerpo.position.y = sin(_tiempo * ritmo_flote + _fase_vagar) * amplitud_flote
	# El sprite siempre mira hacia donde se dirige.
	if velocity.x > 5.0:
		_sprite_cuerpo.flip_h = not textura_mira_derecha
	elif velocity.x < -5.0:
		_sprite_cuerpo.flip_h = textura_mira_derecha
	move_and_slide()

# El más cercano entre jugador y reptiles (grupo "enemigos"), sin contar
# a otras avispas: no se pican entre ellas.
func _buscar_objetivo() -> void:
	var mejor: Node2D = null
	var tenia_objetivo := is_instance_valid(_objetivo)
	var mejor_dist := distancia_deteccion
	var guerra := Global.combate_facciones_permitido(global_position)
	# Con correa de arena (lejos de su spawn), ignora a los reptiles y
	# vuelve con el jugador para no trabar la oleada fuera de los muros.
	var con_correa := has_meta("es_spawn_arena") \
			and global_position.distance_to(_pos_origen) > Global.LEASH_ARENA
	var candidatos := get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemigos")
	for n in candidatos:
		if n == self or not (n is Node2D) or not is_instance_valid(n):
			continue
		if n.is_in_group("avispas"):
			continue
		if n.get("_esta_muerto") == true:
			continue
		# Sin Roku cerca, los reptiles se ignoran (aún no empieza la guerra).
		if guerra == false and n.is_in_group("enemigos"):
			continue
		if con_correa and n.is_in_group("enemigos"):
			continue
		var d = global_position.distance_to((n as Node2D).global_position)
		if d < mejor_dist:
			if _tiene_linea_de_vision(n as Node2D):
				mejor_dist = d
				mejor = n
	# Histéresis: si no hay nada nuevo en rango pero el actual sigue
	# relativamente cerca y válido (incluido no-muerto), se mantiene la caza.
	if mejor == null and not con_correa and tenia_objetivo and is_instance_valid(_objetivo) \
			and _objetivo.get("_esta_muerto") != true \
			and global_position.distance_to(_objetivo.global_position) <= distancia_deteccion * 1.6:
		mejor = _objetivo
	_objetivo = mejor
	es_alerta = _objetivo != null
	# Llamado solo al detectar (transición sin objetivo → con objetivo),
	# no mientras persigue al mismo.
	if _objetivo != null and not tenia_objetivo:
		_emitir_llamado()

# Solo caza lo que ve: tras un muro el candidato se ignora aunque esté
# en rango (mismo criterio que el cono de los reptiles).
func _tiene_linea_de_vision(nodo: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, nodo.global_position)
	query.exclude = [self]
	var res = space_state.intersect_ray(query)
	if res:
		return res["collider"] == nodo
	return false

func _cazar_techo() -> void:
	# Punto de techo: misma x del objetivo, bien por encima.
	var punto := Vector2(_objetivo.global_position.x, _objetivo.global_position.y - altura_sobre_objetivo)
	var diferencia: Vector2 = punto - global_position
	velocity = Vector2(diferencia.x, diferencia.y * 0.9).limit_length(velocidad)
	# Trepa muros: si algo la frena de frente, sube para pasar por arriba.
	if is_on_wall():
		velocity.y = -velocidad * 1.2
	# Suelta el huevo alineada en horizontal y con cadencia.
	if absf(_objetivo.global_position.x - global_position.x) <= tolerancia_soltar \
			and _cd_huevo <= 0.0:
		_cd_huevo = cadencia_huevo
		_soltar_huevo()

func _soltar_huevo() -> void:
	var huevo = HUEVO.instantiate() as RigidBody2D
	get_parent().add_child(huevo)
	huevo.global_position = global_position + Vector2(0, 30)
	# No choca con quien lo puso (cae limpio a través suyo).
	huevo.add_collision_exception_with(self)
	huevo.linear_velocity = velocity * 0.3 + Vector2(0, 60)

# Sin objetivo: orbita lento el punto de aparición, siempre en el aire.
func _vagar(delta: float) -> void:
	_fase_vagar += 0.45 * delta
	var punto := _pos_origen + Vector2(cos(_fase_vagar), sin(_fase_vagar)) * radio_vagancia
	var diferencia: Vector2 = punto - global_position
	velocity = diferencia.limit_length(velocidad * 0.3)

## La emboscada lo llama al spawnear: entra en caza del jugador de
## inmediato, sin esperar a detectarlo (está encerrado con ella).
func forzar_caza() -> void:
	var jugador = get_tree().get_first_node_in_group("player")
	if is_instance_valid(jugador):
		_objetivo = jugador as Node2D
		es_alerta = true
		_emitir_llamado()

# Grito de caza al detectar enemigo (llamado de avispas).
func _emitir_llamado() -> void:
	if _audio_llamado == null:
		return
	_audio_llamado.pitch_scale = randf_range(0.95, 1.1)
	_audio_llamado.play()

func recibir_dano(cantidad: float, tipo_dano: String = "Balistica"):
	if _muerta:
		return
	# Herida la pone en caza (la música de pelea la cuenta por es_alerta).
	es_alerta = true
	var multiplicador_salud = 1.0
	if tipo_dano == "Plasma":
		multiplicador_salud = 0.5
	elif tipo_dano == "Balistica":
		multiplicador_salud = 1.5
	salud -= cantidad * multiplicador_salud
	_sprite_cuerpo.modulate = Color(1.0, 0.4, 0.4)
	_flash_dano = 0.12
	if salud <= 0:
		_muerta = true
		Global.registrar_baja_enemigo(self)
		# Desvanecido: congela, funde y libera.
		velocity = Vector2.ZERO
		$CollisionShape2D.set_deferred("disabled", true)
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		await tween.finished
		queue_free()
