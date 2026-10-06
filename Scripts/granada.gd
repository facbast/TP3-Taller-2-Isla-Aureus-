extends RigidBody2D

@export var dano_explosion: float = 60.0
@export var tiempo_detonacion: float = 2.0
@export var fuerza_empuje: float = 800.0

@onready var _area_explosion = $AreaExplosion
@onready var audio_explosion: AudioStreamPlayer2D = $AudioExplosion
@onready var audio_lanzamiento: AudioStreamPlayer2D = get_node_or_null("AudioLanzamiento")

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

func _explotar():
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
	var efecto_explosion = Polygon2D.new()
	efecto_explosion.color = Color(1.0, 0.2, 0.2, 0.7)
	efecto_explosion.global_position = global_position
	efecto_explosion.scale = Vector2(0.1, 0.1) # Inicia pequeño
	
	var radio_visual = 150.0 
	var puntos_circulo = PackedVector2Array()
	for i in range(32):
		var angulo = (float(i) / 32.0) * PI * 2.0
		puntos_circulo.append(Vector2(cos(angulo), sin(angulo)) * radio_visual)
	efecto_explosion.polygon = puntos_circulo
	
	get_parent().add_child(efecto_explosion)
	
	var tween = get_tree().create_tween()
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
