extends Control

@onready var btn_continuar = $VBoxContainer/BtnContinuar

func _ready():
	# Si no hay un checkpoint guardado, desactivamos el botón de Continuar
	if Global.hay_datos_guardados:
		btn_continuar.disabled = false
	else:
		btn_continuar.disabled = true

func _on_btn_nueva_partida_pressed():
	# Si el jugador quiere empezar de cero, borramos el registro temporal
	Global.hay_datos_guardados = false
	
	# Opcional: Borrar el archivo físico si quieres un reinicio total
	if FileAccess.file_exists(Global.SAVE_PATH):
		var dir = DirAccess.open("user://")
		dir.remove("savegame.save")
		
	# Cambia esto por el nombre exacto de la escena de tu nivel 1
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_btn_continuar_pressed():
	if Global.hay_datos_guardados:
		# Cargamos la escena guardada en el checkpoint
		get_tree().change_scene_to_file(Global.ruta_nivel)
