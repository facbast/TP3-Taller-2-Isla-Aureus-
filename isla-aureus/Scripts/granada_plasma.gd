extends RigidBody2D

@export var dano_explosion: float = 35.0 # Daño reducido en comparación a la de fragmentación
@export var tiempo_detonacion: float = 2.0 
@export var fuerza_empuje: float = 500.0 

@onready var _area_explosion = $AreaExplosion
var _pegada: bool = false

func _ready():
	add_to_group("granadas")
	
	# Conectamos la señal de colisión para saber cuándo tocamos a alguien
	body_entered.connect(_on_body_entered)
	
	var temporizador = get_tree().create_timer(tiempo_detonacion)
	temporizador.timeout.connect(_explotar)

func _on_body_entered(body):
	# Si ya se pegó a algo, ignoramos nuevas colisiones
	if _pegada:
		return
		
	# Verificamos si es un personaje (jugador o enemigo)
	if body is CharacterBody2D:
		_pegada = true
		
		# Congelamos las físicas de la granada para que deje de rebotar y caer
		set_deferred("freeze", true)
		
		# Movemos la granada para que sea "hija" del personaje que tocó
		call_deferred("_adherir_al_cuerpo", body)

func _adherir_al_cuerpo(objetivo: Node2D):
	# Guardamos la posición global actual
	var posicion_global_actual = global_position
	
	# La quitamos de su padre actual (el nivel) y la ponemos en el objetivo
	get_parent().remove_child(self)
	objetivo.add_child(self)
	
	# Restauramos la posición para que no se teletransporte
	global_position = posicion_global_actual

func _explotar():
	var cuerpos_afectados = _area_explosion.get_overlapping_bodies()
	for cuerpo in cuerpos_afectados:
		if cuerpo.has_method("recibir_dano"):
			# Usamos daño de plasma para que rompa escudos de élites rápidamente
			cuerpo.recibir_dano(dano_explosion, "PlasmaCargado")
			
		var direccion_impulso = (cuerpo.global_position - global_position).normalized()
		direccion_impulso.y -= 0.5 
		direccion_impulso = direccion_impulso.normalized()
		
		if cuerpo is RigidBody2D and cuerpo != self:
			cuerpo.apply_central_impulse(direccion_impulso * fuerza_empuje)
		elif cuerpo is CharacterBody2D:
			cuerpo.velocity += direccion_impulso * fuerza_empuje
			
	# --- EFECTO VISUAL VERDE/PLASMA ---
	var efecto_explosion = Polygon2D.new()
	efecto_explosion.color = Color(0.2, 1.0, 0.2, 0.6) # Verde brillante
	efecto_explosion.global_position = global_position 
	
	var radio_visual = 120.0 # Un poco más pequeña que la fragmentada
	var puntos_circulo = PackedVector2Array()
	for i in range(32):
		var angulo = (float(i) / 32.0) * PI * 2.0
		puntos_circulo.append(Vector2(cos(angulo), sin(angulo)) * radio_visual)
	efecto_explosion.polygon = puntos_circulo
	
	# Si la granada está pegada a un enemigo, su "parent" es el enemigo.
	# Añadimos la explosión al nivel principal para que no desaparezca si el enemigo muere.
	get_tree().current_scene.add_child(efecto_explosion)
	
	var tween = get_tree().create_tween()
	tween.tween_property(efecto_explosion, "modulate:a", 0.0, 0.4) 
	tween.tween_callback(efecto_explosion.queue_free) 
			
	queue_free()
