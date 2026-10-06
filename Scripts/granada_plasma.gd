extends RigidBody2D

@export var dano_explosion: float = 35.0
@export var tiempo_detonacion: float = 2.0 
@export var fuerza_empuje: float = 500.0 

@onready var _area_explosion = $AreaExplosion
@onready var audio_explosion: AudioStreamPlayer2D = $AudioExplosion
@onready var audio_pegado: AudioStreamPlayer2D = $AudioPegado
@onready var audio_lanzamiento: AudioStreamPlayer2D = get_node_or_null("AudioLanzamiento")

var _pegada: bool = false

func _ready():
	add_to_group("granadas")
	body_entered.connect(_on_body_entered)
	
	# Reproducir sonido de lanzamiento al instanciar
	if audio_lanzamiento and audio_lanzamiento.stream:
		audio_lanzamiento.play()
	
	# Iniciar el parpadeo de advertencia en color cian/plasma
	_iniciar_indicador_alerta()

	var temporizador = get_tree().create_timer(tiempo_detonacion)
	temporizador.timeout.connect(_explotar)

func _iniciar_indicador_alerta():
	var tween = create_tween()
	# Parpadeo lento inicial (cian brillante)
	tween.tween_property($Sprite2D, "modulate", Color(0.2, 2.5, 2.5), 0.25)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
	tween.tween_property($Sprite2D, "modulate", Color(0.2, 2.5, 2.5), 0.25)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
	
	# Parpadeo rápido final
	tween.tween_property($Sprite2D, "modulate", Color(0.1, 3.5, 3.5), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(0.1, 3.5, 3.5), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(0.0, 4.0, 4.0), 0.05)

func _on_body_entered(body):
	if _pegada:
		return
		
	if body is CharacterBody2D:
		_pegada = true
		
		if audio_pegado and audio_pegado.stream:
			audio_pegado.play()
			
		set_deferred("freeze", true)
		call_deferred("_adherir_al_cuerpo", body)

func _adherir_al_cuerpo(objetivo: Node2D):
	var posicion_global_actual = global_position
	get_parent().remove_child(self)
	objetivo.add_child(self)
	global_position = posicion_global_actual

func _explotar():
	var cuerpos_afectados = _area_explosion.get_overlapping_bodies()
	for cuerpo in cuerpos_afectados:
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano_explosion, "PlasmaCargado")
			
		var direccion_impulso = (cuerpo.global_position - global_position).normalized()
		direccion_impulso.y -= 0.5 
		direccion_impulso = direccion_impulso.normalized()
		
		if cuerpo is RigidBody2D and cuerpo != self:
			cuerpo.apply_central_impulse(direccion_impulso * fuerza_empuje)
		elif cuerpo is CharacterBody2D:
			cuerpo.velocity += direccion_impulso * fuerza_empuje
			
	# --- EFECTO VISUAL PLASMA ---
	var efecto_explosion = Polygon2D.new()
	efecto_explosion.color = Color(0.2, 1.0, 0.2, 0.7)
	efecto_explosion.global_position = global_position 
	efecto_explosion.scale = Vector2(0.1, 0.1) # Inicia pequeño
	
	var radio_visual = 120.0
	var puntos_circulo = PackedVector2Array()
	for i in range(32):
		var angulo = (float(i) / 32.0) * PI * 2.0
		puntos_circulo.append(Vector2(cos(angulo), sin(angulo)) * radio_visual)
	efecto_explosion.polygon = puntos_circulo
	
	get_tree().current_scene.add_child(efecto_explosion)
	
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
