extends RigidBody2D

@export var dano_explosion: float = 60.0
@export var tiempo_detonacion: float = 2.0 # 2 segundos hasta explotar

@onready var _area_explosion = $AreaExplosion

func _ready():
	# Agregamos la granada al grupo para que los enemigos la reconozcan
	add_to_group("granadas")
	
	# Empezamos la cuenta regresiva en cuanto la granada es lanzada
	var temporizador = get_tree().create_timer(tiempo_detonacion)
	temporizador.timeout.connect(_explotar)

func _explotar():
	print("¡BOOM! Explosión de fragmentación.")
	
	# 1. Aplicamos el daño a los cuerpos cercanos
	var cuerpos_afectados = _area_explosion.get_overlapping_bodies()
	for cuerpo in cuerpos_afectados:
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano_explosion, "Explosivo")
			
	# --- 2. CREAMOS EL EFECTO VISUAL (PLACEHOLDER) ---
	var efecto_explosion = Polygon2D.new()
	efecto_explosion.color = Color(1.0, 0.2, 0.2, 0.6) # Rojo con 60% de opacidad
	efecto_explosion.global_position = global_position # Aparece donde está la granada
	
	# Matemáticas para dibujar un círculo perfecto de radio 150 px
	var radio_visual = 150.0 
	var puntos_circulo = PackedVector2Array()
	for i in range(32): # Usamos 32 puntos (vértices) para que se vea suave
		var angulo = (float(i) / 32.0) * PI * 2.0
		puntos_circulo.append(Vector2(cos(angulo), sin(angulo)) * radio_visual)
	efecto_explosion.polygon = puntos_circulo
	
	# Añadimos el dibujo al escenario (fuera de la granada, para que no se borre al instante)
	get_parent().add_child(efecto_explosion)
	
	# Usamos un Tween para desvanecerlo y borrarlo automáticamente
	var tween = get_tree().create_tween()
	# Animamos el canal 'A' (Alfa/Transparencia) hasta 0.0 durante 0.4 segundos
	tween.tween_property(efecto_explosion, "modulate:a", 0.0, 0.4) 
	# Cuando la animación termine, el dibujo se elimina a sí mismo
	tween.tween_callback(efecto_explosion.queue_free) 
			
	# --- 3. ELIMINAMOS LA GRANADA FÍSICA ---
	queue_free()
