extends CharacterBody2D
## Avispa (primer tipo: pelaje amarillo, ojos morados). Flota perpetuamente
## a la deriva; si detecta al objetivo más cercano (jugador o reptil) lo
## persigue y lo aguijonea en melee. El aguijón es más efectivo en la piel
## expuesta (salud) que contra escudos.

@export var velocidad: float = 170.0
@export var distancia_deteccion: float = 900.0
@export var salud: float = 20.0
@export var dano_aguijon: float = 12.0
@export var rango_aguijon: float = 95.0
@export var cadencia_aguijon: float = 1.1
@export var radio_vagancia: float = 140.0
@export var amplitud_flote: float = 10.0
@export var ritmo_flote: float = 3.0
# El sprite base mira a la izquierda: al moverse a la derecha se espeja.
@export var textura_mira_derecha: bool = false

const SONIDO_LLAMADO = preload("res://SFX/Panal/Llamado_Avispa.wav")

var salud_maxima: float = 20.0
var es_alerta: bool = false # En caza: también activa la música de pelea

var _objetivo: Node2D = null
var _pos_origen: Vector2
var _tiempo: float = 0.0
var _fase_vagar: float = 0.0
var _cd_aguijon: float = 0.0
var _flash_dano: float = 0.0
var _muerta: bool = false
var _audio_llamado: AudioStreamPlayer2D
# Reevalúa el blanco cada tanto: cambia a lo hostil más cercano aunque
# ya cazara otra cosa (si no, fijado el primero ignoraría al resto).
var _tiempo_reevaluar: float = 0.0

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

func _physics_process(delta):
	if _muerta:
		return
	_tiempo += delta
	if _cd_aguijon > 0.0:
		_cd_aguijon -= delta
	if _flash_dano > 0.0:
		_flash_dano -= delta
		if _flash_dano <= 0.0:
			_sprite_cuerpo.modulate = Color.WHITE

	_tiempo_reevaluar -= delta
	if _objetivo == null or _tiempo_reevaluar <= 0.0:
		_tiempo_reevaluar = 0.4
		_buscar_objetivo()

	if is_instance_valid(_objetivo):
		_cazar(delta)
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
		var d = global_position.distance_to((n as Node2D).global_position)
		if d < mejor_dist:
			if _tiene_linea_de_vision(n as Node2D):
				mejor_dist = d
				mejor = n
	# Histéresis: si no hay nada nuevo en rango pero el actual sigue
	# relativamente cerca y válido (incluido no-muerto), se mantiene la caza.
	if mejor == null and tenia_objetivo and is_instance_valid(_objetivo) \
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

func _cazar(_delta: float) -> void:
	var destino: Vector2 = _objetivo.global_position
	var diferencia: Vector2 = destino - global_position
	var distancia := diferencia.length()
	var direccion := diferencia.normalized() if distancia > 1.0 else Vector2.ZERO
	if distancia > rango_aguijon and not _toca_al_objetivo():
		velocity = direccion * velocidad
	else:
		# Encima del objetivo: presiona y aguijonea con cadencia.
		velocity = direccion * velocidad * 0.25
		if _cd_aguijon <= 0.0:
			_cd_aguijon = cadencia_aguijon
			velocity = direccion * velocidad * 2.2 # Embestida del aguijón
			if _objetivo.has_method("recibir_dano"):
				_objetivo.recibir_dano(dano_aguijon, "Aguijon")
	# Trepa muros: si algo la frena de frente (dato del move anterior),
	# sube para pasar por arriba volando en vez de vibrar contra la pared.
	if is_on_wall():
		velocity.y = -velocidad * 1.2

# Contacto físico con el objetivo (dato del move anterior): los cuerpos
# grandes chocan antes de entrar en rango numérico, y sin esto la avispa
# empujaría sin aguijonear nunca.
func _toca_al_objetivo() -> bool:
	if not is_instance_valid(_objetivo):
		return false
	for i in range(get_slide_collision_count()):
		if get_slide_collision(i).get_collider() == _objetivo:
			return true
	return false

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
		queue_free()
