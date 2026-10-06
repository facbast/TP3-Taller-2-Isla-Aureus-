extends AnimatableBody2D
## Plataforma flotante que viaja entre dos puntos (ida y vuelta) a velocidad
## constante, arrastrando a quien esté parado encima: jugador, enemigos y
## objetos con física. El punto A es donde la colocas en el editor; el punto B
## se define con "desplazamiento" (relativo al punto A).
##
## Anti-aplastamiento: si la plataforma desciende sobre alguien, lo
## teletransporta al lado libre más cercano; si avanza de costado contra
## alguien, lo sube encima. Las medidas se toman del CollisionShape2D real,
## así que puedes reescalar la plataforma en el editor sin romper nada.

@export var desplazamiento: Vector2 = Vector2(300, 0) ## De A a B: (300, 0) horizontal, (0, -300) vertical hacia arriba
@export var velocidad: float = 80.0                   ## Píxeles por segundo (constante, predecible para saltar)
@export var espera_en_extremos: float = 1.0           ## Pausa en cada extremo antes de volver
@export var empezar_en_b: bool = false               ## Si true, aparece en B y arranca hacia A

@onready var _zona_abajo: Area2D = $ZonaAplastarAbajo
@onready var _zona_izq: Area2D = $ZonaAplastarIzq
@onready var _zona_der: Area2D = $ZonaAplastarDer

var _origen: Vector2
var _destino: Vector2
var _objetivo: Vector2
var _espera: float = 0.0
var _pos_previa: Vector2

# Medidas reales de la tapa sólida (offsets respecto al origen, en píxeles globales).
var _ancho_solido: float = 169.0
var _tope_solido: float = -51.6
var _base_solida: float = -13.2
var _centro_solido_x: float = 0.0

func _ready():
	sync_to_physics = true # Imprescindible: así arrastra a los CharacterBody2D que lleva encima
	_medir_solido()
	_configurar_zonas()
	_origen = global_position
	_destino = _origen + desplazamiento
	if empezar_en_b:
		global_position = _destino
		_objetivo = _origen
	else:
		_objetivo = _destino
	_pos_previa = global_position

func _physics_process(delta):
	if _espera > 0.0:
		_espera -= delta
		_pos_previa = global_position
		return
	global_position = global_position.move_toward(_objetivo, velocidad * delta)
	if global_position.distance_to(_objetivo) < 1.0:
		_objetivo = _origen if _objetivo == _destino else _destino
		_espera = espera_en_extremos
	# Anti-aplastamiento según hacia dónde nos movimos este frame.
	var movimiento = global_position - _pos_previa
	_pos_previa = global_position
	if movimiento.y > 0.0:
		_resolver_aplastamiento_vertical()
	if movimiento.x != 0.0:
		_resolver_aplastamiento_horizontal(signf(movimiento.x))

# Lee el CollisionShape2D real (con su escala) para ubicar tapa y sensores.
func _medir_solido():
	var cs = get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		var tam = (cs.shape as RectangleShape2D).size
		var scx = absf(global_scale.x)
		var scy = absf(global_scale.y)
		_ancho_solido = tam.x * scx
		_centro_solido_x = cs.position.x * scx
		_tope_solido = (cs.position.y - tam.y / 2.0) * scy
		_base_solida = (cs.position.y + tam.y / 2.0) * scy

# Dimensiona y ubica las 3 zonas sensoras a partir de la tapa real.
func _configurar_zonas():
	_ajustar_zona(_zona_abajo, Vector2(_ancho_solido, 28.0), Vector2(_centro_solido_x, _base_solida + 14.0))
	var lado_h = (_base_solida - _tope_solido) + 120.0
	var cy = (_tope_solido + _base_solida) / 2.0
	_ajustar_zona(_zona_izq, Vector2(20.0, lado_h), Vector2(_centro_solido_x - _ancho_solido / 2.0 - 10.0, cy))
	_ajustar_zona(_zona_der, Vector2(20.0, lado_h), Vector2(_centro_solido_x + _ancho_solido / 2.0 + 10.0, cy))

func _ajustar_zona(zona: Area2D, tam: Vector2, pos: Vector2):
	if zona == null:
		return
	var cs = zona.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is RectangleShape2D):
		return
	(cs.shape as RectangleShape2D).size = tam
	cs.position = pos

# La plataforma baja sobre alguien: teletransportarlo al lado libre más cercano.
func _resolver_aplastamiento_vertical():
	for cuerpo in _zona_abajo.get_overlapping_bodies():
		if not (cuerpo is CharacterBody2D):
			continue
		var datos = _mitades_de(cuerpo)
		var hw: float = (datos[1] as Vector2).x
		var a_la_izq: bool = cuerpo.global_position.x < global_position.x + _centro_solido_x
		var x_izq = global_position.x + _centro_solido_x - _ancho_solido / 2.0 - hw - 4.0
		var x_der = global_position.x + _centro_solido_x + _ancho_solido / 2.0 + hw + 4.0
		var candidatos = [x_izq, x_der] if a_la_izq else [x_der, x_izq]
		for x in candidatos:
			var destino = Vector2(x, cuerpo.global_position.y)
			if not datos[0] or _zona_libre(datos[1], destino, cuerpo.get_rid()):
				cuerpo.global_position = destino
				break

# La plataforma avanza de costado contra alguien: subirlo encima.
func _resolver_aplastamiento_horizontal(dir: float):
	var zona = _zona_der if dir > 0.0 else _zona_izq
	for cuerpo in zona.get_overlapping_bodies():
		if not (cuerpo is CharacterBody2D):
			continue
		var datos = _mitades_de(cuerpo)
		var destino = Vector2(cuerpo.global_position.x, global_position.y + _tope_solido - (datos[1] as Vector2).y - 4.0)
		if not datos[0] or _zona_libre(datos[1], destino, cuerpo.get_rid()):
			cuerpo.global_position = destino

# Mitad de la hitbox del cuerpo (con su escala). Devuelve [medible, mitades].
func _mitades_de(cuerpo: Node2D) -> Array:
	var cs = cuerpo.get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		var sc = absf(cuerpo.global_scale.x)
		return [true, (cs.shape as RectangleShape2D).size * sc / 2.0]
	return [false, Vector2(20, 50)]

# ¿Cabe un cuerpo de esas mitades en esa posición sin chocar con el mundo?
func _zona_libre(mitades: Vector2, pos: Vector2, excluir: RID) -> bool:
	var forma = RectangleShape2D.new()
	forma.size = mitades * 2.0
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape = forma
	params.transform = Transform2D(0, pos)
	params.exclude = [excluir]
	params.collision_mask = 1
	var choques = get_world_2d().direct_space_state.intersect_shape(params, 4)
	return choques.is_empty()
