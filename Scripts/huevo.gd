extends RigidBody2D
## Huevo de avispa: cae y explota al contacto (con mecha de respaldo),
## como las granadas. Daña a todo cuerpo con recibir_dano (jugador,
## reptiles y avispas) y se puede devolver de una patada.

@export var dano_explosion: float = 45.0
@export var tiempo_detonacion: float = 4.0
@export var fuerza_empuje: float = 700.0
@export var fuerza_desvio_melee: float = 900.0
@export var radio_explosion: float = 110.0

@onready var _area_explosion = $AreaExplosion
@onready var audio_explosion: AudioStreamPlayer2D = $AudioExplosion

var _explotada: bool = false

func _ready():
	add_to_group("granadas")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	# Mecha de respaldo por si cae en un hueco sin tocar nada útil.
	var temporizador = get_tree().create_timer(tiempo_detonacion)
	temporizador.timeout.connect(_explotar)

func _on_body_entered(_cuerpo: Node) -> void:
	_explotar()

# Patada del jugador: devuelve el huevo en dirección opuesta.
func ser_desviada(origen: Vector2) -> void:
	if _explotada:
		return
	var direccion := -linear_velocity if linear_velocity.length() > 150.0 else (global_position - origen)
	if direccion.length() < 0.01:
		direccion = Vector2.RIGHT
	direccion = direccion.normalized()
	direccion.y -= 0.35
	direccion = direccion.normalized()
	sleeping = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 12.0 * sign(direccion.x)
	apply_central_impulse(direccion * fuerza_desvio_melee)

# Destello de luz cálida sobre la explosión (para cuevas oscuras).
func _destello_explosion(pos: Vector2, contenedor: Node) -> void:
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 1.0])
	gradiente.colors = PackedColorArray([Color(1, 0.92, 0.7, 1), Color(1, 0.8, 0.5, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradiente
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var luz := PointLight2D.new()
	luz.texture = tex
	luz.color = Color(0.8, 1.0, 0.5)
	luz.energy = 2.0
	luz.texture_scale = 3.0
	contenedor.add_child(luz)
	luz.global_position = pos
	var tween_luz = luz.create_tween()
	tween_luz.tween_property(luz, "energy", 0.0, 0.35)
	tween_luz.tween_callback(luz.queue_free)

func _explotar():
	if _explotada:
		return
	_explotada = true
	if not is_instance_valid(_area_explosion):
		queue_free()
		return
	var cuerpos_afectados = _area_explosion.get_overlapping_bodies()
	for cuerpo in cuerpos_afectados:
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano_explosion, "Explosivo")

		var direccion_impulso = (cuerpo.global_position - global_position).normalized()
		direccion_impulso.y -= 0.5
		direccion_impulso = direccion_impulso.normalized()

		if cuerpo is RigidBody2D and cuerpo != self:
			cuerpo.apply_central_impulse(direccion_impulso * fuerza_empuje)
		elif cuerpo is CharacterBody2D:
			cuerpo.velocity += direccion_impulso * fuerza_empuje

	# --- EFECTO VISUAL ---
	var pos_explosion := global_position
	var efecto_explosion = Polygon2D.new()
	efecto_explosion.color = Color(0.5, 1.0, 0.3, 0.7) # Verdoso de huevo
	efecto_explosion.scale = Vector2(0.1, 0.1) # Inicia pequeño
	# z alto para que el tileset/props no lo tapen según dónde explote.
	efecto_explosion.z_index = 100

	var puntos_circulo = PackedVector2Array()
	for i in range(32):
		var angulo = (float(i) / 32.0) * PI * 2.0
		puntos_circulo.append(Vector2(cos(angulo), sin(angulo)) * radio_explosion)
	efecto_explosion.polygon = puntos_circulo

	var contenedor: Node = get_tree().current_scene
	if contenedor == null:
		contenedor = get_parent()
	contenedor.add_child(efecto_explosion)
	efecto_explosion.global_position = pos_explosion
	_destello_explosion(pos_explosion, contenedor)

	# Tween ligado al efecto: si el efecto se libera, el tween muere con él.
	var tween = efecto_explosion.create_tween()
	# 1. Expansión explosiva rápida (0.08s) con curva de desaceleración
	tween.tween_property(efecto_explosion, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Desvanecimiento a transparente (0.3s)
	tween.tween_property(efecto_explosion, "modulate:a", 0.0, 0.3)
	tween.tween_callback(efecto_explosion.queue_free)

	# --- SONIDO Y ELIMINACIÓN ---
	if audio_explosion and audio_explosion.stream:
		$Sprite2D.hide()
		$CollisionShape2D.set_deferred("disabled", true)
		audio_explosion.play()
		await audio_explosion.finished

	queue_free()
