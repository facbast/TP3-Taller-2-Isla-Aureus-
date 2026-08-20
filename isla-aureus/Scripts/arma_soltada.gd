extends Area2D

var cantidad_municion: int = 16 
var tipo_arma: String = "Pistola"
var textura_arma: Texture2D = null

var jugador_cerca = null
var tiempo_manteniendo = 0.0
var tiempo_requerido = 0.4 

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if textura_arma != null:
		$Sprite2D.texture = textura_arma

func _process(delta):
	if jugador_cerca != null:
		if Input.is_physical_key_pressed(KEY_E):
			tiempo_manteniendo += delta
			if tiempo_manteniendo >= tiempo_requerido:
				var recogido = jugador_cerca.recoger_arma(tipo_arma, cantidad_municion)
				if recogido:
					queue_free()
				else:
					# Si la rechazó (ej. batería inferior), reiniciamos el temporizador
					tiempo_manteniendo = 0.0
		else:
			tiempo_manteniendo = 0.0

func _on_body_entered(body):
	if body.is_in_group("player"):
		var ya_tiene_arma = false
		var usa_bateria = false
		
		for arma in body.armas:
			if arma.name == tipo_arma:
				ya_tiene_arma = true
				if "bateria" in arma:
					usa_bateria = true
				break
				
		# Solo absorbemos munición al instante si YA la tiene y NO es de batería
		if ya_tiene_arma and not usa_bateria:
			var recogido = body.recoger_arma(tipo_arma, cantidad_municion)
			if recogido:
				queue_free()
		else:
			# Obligamos al jugador a usar la tecla 'E' para armas nuevas o de energía
			jugador_cerca = body

func _on_body_exited(body):
	if body == jugador_cerca:
		jugador_cerca = null
		tiempo_manteniendo = 0.0
