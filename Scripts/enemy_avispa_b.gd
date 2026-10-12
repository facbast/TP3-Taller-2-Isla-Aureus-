extends CharacterBody2D
## Avispa artillada (segundo tipo): equipa un arma en el aguijón y dispara
## en horizontal manteniendo distancia. No apunta en vertical: flota hasta
## alinearse con la altura del objetivo. Al morir deja tirada su arma.

enum ArmaEquipada {
	RIFLE, # Rifle V.I.D. (balístico)
	PISTOLA, # Pistola Leguminosa (balística)
	CANON_ACIDO, # Cañón Cítrico (plasma)
	PISTOLA_ACIDA, # Pistola Cítrica (plasma)
}

const NOMBRES_ARMA := {
	ArmaEquipada.RIFLE: "Rifle",
	ArmaEquipada.PISTOLA: "Pistola",
	ArmaEquipada.CANON_ACIDO: "RiflePlasma",
	ArmaEquipada.PISTOLA_ACIDA: "PistolaPlasma",
}
const NODOS_ARMA := {
	ArmaEquipada.RIFLE: "Rifle",
	ArmaEquipada.PISTOLA: "Pistola",
	ArmaEquipada.CANON_ACIDO: "RiflePlasma",
	ArmaEquipada.PISTOLA_ACIDA: "PistolaPlasma",
}
const ARMA_SOLTADA = preload("res://Scenes/arma_soltada.tscn")
const SONIDO_LLAMADO = preload("res://SFX/Panal/Llamado_Avispa.wav")

# Qué arma lleva montada (se elige en el inspector).
@export var arma_equipada: ArmaEquipada = ArmaEquipada.PISTOLA_ACIDA
@export var velocidad: float = 150.0
@export var distancia_deteccion: float = 900.0
@export var salud: float = 20.0
# Banda horizontal que intenta mantener con el objetivo.
@export var distancia_ideal: float = 380.0
@export var banda_distancia: float = 80.0
# Si la diferencia de altura supera esto, flota a alinearse (no dispara).
@export var tolerancia_vertical: float = 28.0
@export var rango_max_disparo: float = 650.0
@export var radio_vagancia: float = 140.0
@export var amplitud_flote: float = 10.0
@export var ritmo_flote: float = 3.0
# El sprite base mira a la izquierda: al moverse a la derecha se espeja.
@export var textura_mira_derecha: bool = false

var salud_maxima: float = 20.0
var es_alerta: bool = false # En caza: también activa la música de pelea

## La emboscada lo llama antes del add_child para sortear el arma
## (colocadas a mano respetan el inspector).
func set_arma_aleatoria() -> void:
	var opciones := [ArmaEquipada.RIFLE, ArmaEquipada.PISTOLA, ArmaEquipada.CANON_ACIDO, ArmaEquipada.PISTOLA_ACIDA]
	arma_equipada = opciones.pick_random()

var _objetivo: Node2D = null
var _arma: Node2D = null
var _mirando_derecha: bool = false
var _pos_origen: Vector2
var _tiempo: float = 0.0
var _fase_vagar: float = 0.0
var _tiempo_reevaluar: float = 0.0
var _flash_dano: float = 0.0
var _muerta: bool = false
var _audio_llamado: AudioStreamPlayer2D

@onready var _sprite_cuerpo = $SpriteCuerpo
@onready var _pivote_brazo = $PivoteBrazo

func _ready():
	# Si ya la derrotamos en esta partida (checkpoint), no reaparece.
	if not has_meta("es_spawn_arena") and Global.estaba_eliminado(self):
		queue_free()
		return
	# Monta el arma elegida y descarta las otras tres.
	for clave in NODOS_ARMA.keys():
		var candidata := get_node_or_null("PivoteBrazo/" + NODOS_ARMA[clave]) as Node2D
		if candidata == null:
			continue
		if int(clave) == int(arma_equipada):
			_arma = candidata
			_arma.show()
		else:
			candidata.queue_free()
	_audio_llamado = AudioStreamPlayer2D.new()
	_audio_llamado.name = "AudioLlamado"
	_audio_llamado.stream = SONIDO_LLAMADO
	_audio_llamado.volume_db = -4.0
	add_child(_audio_llamado)
	salud_maxima = salud
	_pos_origen = global_position
	_fase_vagar = randf() * TAU
	_orientar_brazo_adelante()

## La emboscada lo llama tras posicionar el spawn: deriva y correa
## miden desde el marker, no desde el (0,0) previo al posicionado.
func fijar_origen() -> void:
	_pos_origen = global_position

func _physics_process(delta):
	if _muerta:
		return
	_tiempo += delta
	if _flash_dano > 0.0:
		_flash_dano -= delta
		if _flash_dano <= 0.0:
			_sprite_cuerpo.modulate = Color.WHITE

	_tiempo_reevaluar -= delta
	if _objetivo == null or _tiempo_reevaluar <= 0.0:
		_tiempo_reevaluar = 0.4
		_buscar_objetivo()

	if is_instance_valid(_objetivo):
		_cazar_rango()
	else:
		_vagar(delta)

	# Flote perpetuo: cabeceo visual sobre el cuerpo (no mueve la colisión).
	_sprite_cuerpo.position.y = sin(_tiempo * ritmo_flote + _fase_vagar) * amplitud_flote
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

func _cazar_rango() -> void:
	var diferencia: Vector2 = _objetivo.global_position - global_position
	# Cara al objetivo en horizontal: el arma no apunta en vertical.
	if diferencia.x > 5.0 and not _mirando_derecha:
		_mirando_derecha = true
		_orientar_brazo_adelante()
	elif diferencia.x < -5.0 and _mirando_derecha:
		_mirando_derecha = false
		_orientar_brazo_adelante()
	# El sprite mira al objetivo (no a la velocidad: al mantener distancia
	# la velocidad es ~0 y el flip quedaba congelado al revés).
	_sprite_cuerpo.flip_h = (_mirando_derecha != textura_mira_derecha)
	# Mantiene la banda de distancia en horizontal...
	var vx := 0.0
	var adx := absf(diferencia.x)
	if adx > distancia_ideal + banda_distancia:
		vx = sign(diferencia.x) * velocidad
	elif adx < distancia_ideal - banda_distancia:
		vx = -sign(diferencia.x) * velocidad
	# ...y flota en vertical hasta alinearse con el objetivo.
	var vy := 0.0
	if absf(diferencia.y) > tolerancia_vertical:
		vy = sign(diferencia.y) * velocidad * 0.8
	velocity = Vector2(vx, vy)
	# Trepa muros: si algo la frena de frente, sube para pasar por arriba.
	if is_on_wall():
		velocity.y = -velocidad * 1.2
	# Dispara solo alineada en altura, a rango y a la vista.
	if absf(diferencia.y) <= tolerancia_vertical \
			and diferencia.length() <= rango_max_disparo \
			and _tiene_linea_de_vision(_objetivo) \
			and _arma != null and _arma.has_method("intentar_disparar"):
		_arma.intentar_disparar()

# Sin objetivo: orbita lento el punto de aparición, siempre en el aire.
func _vagar(delta: float) -> void:
	_fase_vagar += 0.45 * delta
	var punto := _pos_origen + Vector2(cos(_fase_vagar), sin(_fase_vagar)) * radio_vagancia
	var diferencia: Vector2 = punto - global_position
	velocity = diferencia.limit_length(velocidad * 0.3)
	# Sin blanco se mira según la marcha.
	if velocity.x > 5.0:
		_mirando_derecha = true
		_sprite_cuerpo.flip_h = not textura_mira_derecha
		_orientar_brazo_adelante()
	elif velocity.x < -5.0:
		_mirando_derecha = false
		_sprite_cuerpo.flip_h = textura_mira_derecha
		_orientar_brazo_adelante()

# El brazo clava el tiro horizontal: misma convención que el gecko
# (rotación 0/PI + espejo vertical) para que el arma nunca quede boca
# abajo y las balas salgan hacia el lado correcto.
func _orientar_brazo_adelante():
	if _mirando_derecha:
		_pivote_brazo.rotation = 0.0
		_pivote_brazo.scale.y = 1.0
	else:
		_pivote_brazo.rotation = PI
		_pivote_brazo.scale.y = -1.0

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
		_soltar_arma()
		queue_free()

# Al caer deja tirada el arma que llevaba, con su munición restante.
# (Las balísticas enemigas usan reserva infinita: el drop se acota a un
# paquete sano para no regalar 9999 balas.)
func _soltar_arma() -> void:
	var caida = ARMA_SOLTADA.instantiate()
	caida.tipo_arma = NOMBRES_ARMA.get(arma_equipada, "PistolaPlasma")
	caida.scale = _arma.scale if _arma != null else Vector2.ONE
	if _arma != null:
		if "municion_reserva" in _arma:
			var tope := 60 if _arma.name == "Rifle" else 24
			caida.cantidad_municion = mini(_arma.municion_reserva, tope)
		elif "bateria" in _arma:
			caida.cantidad_municion = _arma.bateria
	get_parent().call_deferred("add_child", caida)
	caida.set_deferred("global_position", global_position)
