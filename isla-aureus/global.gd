extends Node

const SAVE_PATH = "user://savegame.save"
var hay_datos_guardados: bool = false

# Datos del checkpoint
var ruta_nivel: String = "res://Scenes/Nivel1.tscn"
var pos_x: float = 0.0
var pos_y: float = 0.0

func _ready():
	cargar_juego()

func guardar_checkpoint(nivel: String, posicion: Vector2):
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var datos = {
		"nivel": nivel,
		"pos_x": posicion.x,
		"pos_y": posicion.y
	}
	file.store_var(datos)
	
	# Actualizamos las variables en memoria
	ruta_nivel = nivel
	pos_x = posicion.x
	pos_y = posicion.y
	hay_datos_guardados = true

func cargar_juego():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var datos = file.get_var()
		
		ruta_nivel = datos["nivel"]
		pos_x = datos["pos_x"]
		pos_y = datos["pos_y"]
		hay_datos_guardados = true
	else:
		hay_datos_guardados = false
