@tool
extends Node2D

## Controla si la flecha apunta hacia la derecha o izquierda
@export var apuntar_a_derecha: bool = true:
	set(valor):
		apuntar_a_derecha = valor
		_actualizar_direccion()

## Ángulo adicional si quieres ajustar la inclinación de la flecha
@export_range(-45.0, 45.0, 1.0) var inclinacion_grados: float = 0.0:
	set(valor):
		inclinacion_grados = valor
		_actualizar_direccion()

@onready var sprite_flecha: Sprite2D = $Flecha

func _ready() -> void:
	_actualizar_direccion()

func _actualizar_direccion() -> void:
	if not is_node_ready() or sprite_flecha == null:
		return
		
	# Voltea la textura horizontalmente
	sprite_flecha.flip_h = not apuntar_a_derecha
	
	# Aplica la inclinación en radianes
	sprite_flecha.rotation = deg_to_rad(inclinacion_grados)
