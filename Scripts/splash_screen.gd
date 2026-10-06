extends Control

@onready var logo = $TextureRect

var _tween: Tween
var _cambiando_escena: bool = false

func _ready():
	# Inicia el logo completamente transparente
	logo.modulate.a = 0.0
	
	# Secuencia de animación
	_tween = create_tween()
	# 1. Fade In: Transición a visible en 1 segundo
	_tween.tween_property(logo, "modulate:a", 1.0, 1.0)
	# 2. Mantener: Se queda visible durante 1.5 segundos
	_tween.tween_interval(1.5)
	# 3. Fade Out: Se desvanece a transparente en 1 segundo
	_tween.tween_property(logo, "modulate:a", 0.0, 1.0)
	
	# Al finalizar la secuencia completa, cambia de escena
	_tween.finished.connect(_ir_al_menu)

func _input(event):
	if _cambiando_escena:
		return
		
	# Permitir saltar la animación inmediatamente al presionar una tecla o click
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if _tween and _tween.is_running():
			_tween.kill()
		_ir_al_menu()

func _ir_al_menu():
	if _cambiando_escena:
		return
	_cambiando_escena = true
	get_tree().change_scene_to_file("res://Scenes/pantalla_titulo.tscn")
