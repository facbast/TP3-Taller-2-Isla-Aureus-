extends RigidBody2D

@export var dano_explosion: float = 60.0
@export var tiempo_detonacion: float = 2.0
@export var fuerza_empuje: float = 800.0
@export var fuerza_desvio_melee: float = 900.0

@onready var _area_explosion = $AreaExplosion
@onready var audio_explosion: AudioStreamPlayer2D = $AudioExplosion
@onready var audio_lanzamiento: AudioStreamPlayer2D = get_node_or_null("AudioLanzamiento")

var _explotada: bool = false

func _ready():
	add_to_group("granadas")
	
	# Reproducir sonido de lanzamiento al instanciar
	if audio_lanzamiento and audio_lanzamiento.stream:
		audio_lanzamiento.play()
		
	# Iniciar el parpadeo de advertencia en rojo
	_iniciar_indicador_alerta()
		
	var temporizador = get_tree().create_timer(tiempo_detonacion)
	temporizador.timeout.connect(_explotar)

func _iniciar_indicador_alerta():
	var tween = create_tween()
	# Parpadeo lento inicial (rojo)
	tween.tween_property($Sprite2D, "modulate", Color(2.5, 0.3, 0.3), 0.25)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
	tween.tween_property($Sprite2D, "modulate", Color(2.5, 0.3, 0.3), 0.25)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
	
	# Parpadeo rápido final justo antes de la detonación
	tween.tween_property($Sprite2D, "modulate", Color(3.5, 0.1, 0.1), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(3.5, 0.1, 0.1), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(4.0, 0.0, 0.0), 0.05)

# Patada del jugador: devuelve la granada en dirección opuesta.
# Solo existe en la frag/cargada; la plasma no la implementa y no se desvía.
func ser_desviada(origen: Vector2) -> void:
	if _explotada:
		return
	# Si venía en vuelo, rebota su trayectoria; si estaba quieta, sale
	# despedida lejos del jugador. La mecha sigue corriendo.
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
	# Se captura la posición ANTES de crear el efecto y se coloca DESPUÉS
	# de añadirlo a la escena: poner global_position antes del add_child
	# dejaba el círculo en el sitio equivocado según el padre.
	var pos_explosion := global_position
	var efecto_explosion = Polygon2D.new()
	efecto_explosion.color = Color(1.0, 0.2, 0.2, 0.7)
	efecto_explosion.scale = Vector2(0.1, 0.1) # Inicia pequeño
	# z alto para que el tileset/props no lo tapen según dónde explote.
	efecto_explosion.z_index = 100

	var radio_visual = 120.0 # Igual que el AreaExplosion (antes 150).
	var puntos_circulo = PackedVector2Array()
	for i in range(32):
		var angulo = (float(i) / 32.0) * PI * 2.0
		puntos_circulo.append(Vector2(cos(angulo), sin(angulo)) * radio_visual)
	efecto_explosion.polygon = puntos_circulo

	var contenedor: Node = get_tree().current_scene
	if contenedor == null:
		contenedor = get_parent()
	contenedor.add_child(efecto_explosion)
	efecto_explosion.global_position = pos_explosion

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
