extends StaticBody2D
## Hongo trampolín: quien caiga sobre él rebota, más alto cuanto más fuerte
## sea la caída. También impulsa enemigos y objetos rígidos (granadas).
## El sprite hace squash & stretch ("gelatina") en cada rebote.
##
## IMPORTANTE: guarda tu arte como res://Assets/Hongo.png (es la textura
## que referencia la escena). Ajusta los CollisionShape al tamaño real.

@export var multiplicador_caida: float = 1.0  ## Cuánto de la velocidad de caída se devuelve
@export var impulso_extra: float = 250.0     ## Empujón base aunque la caída sea suave
@export var impulso_minimo: float = 450.0    ## Rebote más flojo posible
@export var impulso_maximo: float = 1150.0   ## Tope (equivale a ~2x el salto del jugador)
@export var escala_sprite: Vector2 = Vector2(0.5, 0.5)

@onready var _sprite: Sprite2D = $Sprite
@onready var _zona: Area2D = $ZonaRebote

var _tween_gelatina: Tween

func _ready():
	_sprite.scale = escala_sprite
	_zona.body_entered.connect(_on_cuerpo_en_zona)

func _on_cuerpo_en_zona(cuerpo: Node2D) -> void:
	var vel_caida = _velocidad_caida_de(cuerpo)
	# Solo rebota a quien viene cayendo (o quieto en el aire): quien sube
	# atravesando la zona desde abajo la ignora.
	if vel_caida <= 0.0:
		return
	var impulso = clampf(vel_caida * multiplicador_caida + impulso_extra, impulso_minimo, impulso_maximo)
	_aplicar_rebote(cuerpo, impulso)
	_gelatina()

func _velocidad_caida_de(cuerpo: Node2D) -> float:
	if cuerpo is CharacterBody2D:
		return (cuerpo as CharacterBody2D).velocity.y
	if cuerpo is RigidBody2D:
		return (cuerpo as RigidBody2D).linear_velocity.y
	return 0.0

func _aplicar_rebote(cuerpo: Node2D, impulso: float) -> void:
	if cuerpo is CharacterBody2D:
		(cuerpo as CharacterBody2D).velocity.y = -impulso
	elif cuerpo is RigidBody2D:
		var rb = cuerpo as RigidBody2D
		rb.linear_velocity = Vector2(rb.linear_velocity.x * 0.5, -impulso)

func _gelatina():
	if _tween_gelatina and _tween_gelatina.is_valid():
		_tween_gelatina.kill()
	_sprite.scale = escala_sprite
	_tween_gelatina = create_tween()
	# Aplastar...
	_tween_gelatina.tween_property(_sprite, "scale", escala_sprite * Vector2(1.3, 0.65), 0.08)
	# ...y estirar de vuelta con elasticidad de gelatina.
	_tween_gelatina.tween_property(_sprite, "scale", escala_sprite, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
