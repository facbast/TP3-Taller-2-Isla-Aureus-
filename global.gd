extends Node

const SAVE_PATH = "user://savegame.save"
var hay_datos_guardados: bool = false

# Datos del checkpoint
var ruta_nivel: String = "res://Scenes/main.tscn"
var pos_x: float = 0.0
var pos_y: float = 0.0
var inventario_guardado: Dictionary = {}

# Estados del tutorial
var tutorial_visto: bool = false
var tutorial_aceptado: bool = false # Declarada para evitar el error

# Bajas y objetos ya consumidos (por ruta de nodo, estable entre recargas).
# Solo cuentan cuando se llega a un checkpoint que guarda el progreso:
# - enemigos_derrotados / items_recogidos = confirmados (guardados en archivo).
# - bajas_pendientes / items_pendientes = progreso desde el último checkpoint,
#   aún NO guardado. Se confirma al pisar checkpoint y se descarta al morir
#   o reiniciar, para que esos enemigos/items reaparezcan.
var enemigos_derrotados: Array = []
var items_recogidos: Array = []
var bajas_pendientes: Array = []
var items_pendientes: Array = []

func registrar_baja_enemigo(nodo: Node) -> void:
	var id = str(nodo.get_path())
	if not enemigos_derrotados.has(id) and not bajas_pendientes.has(id):
		bajas_pendientes.append(id)

func registrar_item_recogido(nodo: Node) -> void:
	var id = str(nodo.get_path())
	if not items_recogidos.has(id) and not items_pendientes.has(id):
		items_pendientes.append(id)

func estaba_eliminado(nodo: Node) -> bool:
	var id = str(nodo.get_path())
	return enemigos_derrotados.has(id) or bajas_pendientes.has(id) or items_recogidos.has(id) or items_pendientes.has(id)

# Descarta lo avanzado desde el último checkpoint (muertes y reinicios).
# Los enemigos derrotados y los items recogidos después del último guardado
# vuelven a aparecer; lo confirmado en el archivo no se toca.
func descartar_progreso_no_guardado() -> void:
	bajas_pendientes.clear()
	items_pendientes.clear()
	# Re-sincroniza lo confirmado con el archivo por seguridad.
	if hay_datos_guardados and FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var datos = file.get_var()
		if datos is Dictionary:
			enemigos_derrotados = Array(datos.get("bajas", []))
			items_recogidos = Array(datos.get("items", []))

# Los enemigos solo lanzan granadas después de pisar el trigger del
# tutorial 3, haya aceptado o rechazado el tutorial el jugador.
var granadas_enemigas_desbloqueadas: bool = false

# True si los enemigos pueden lanzar granadas ahora mismo.
func enemigos_pueden_usar_granadas() -> bool:
	return granadas_enemigas_desbloqueadas

# Al reaparecer en un checkpoint, el flag vuelve al último guardado:
# morir después del trigger no puede desbloquearlas antes de él.
func restaurar_flags_checkpoint():
	if not hay_datos_guardados or not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var datos = file.get_var()
	if datos is Dictionary:
		granadas_enemigas_desbloqueadas = datos.get("granadas_desbloqueadas", false)

func _ready():
	cargar_juego()

func guardar_checkpoint(nivel: String, posicion: Vector2, inventario: Dictionary):
	# Al pisar el checkpoint, lo pendiente desde el último guardado
	# pasa a confirmado: solo ahora las bajas/items cuentan de verdad.
	for id in bajas_pendientes:
		if not enemigos_derrotados.has(id):
			enemigos_derrotados.append(id)
	for id in items_pendientes:
		if not items_recogidos.has(id):
			items_recogidos.append(id)
	bajas_pendientes.clear()
	items_pendientes.clear()
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var datos = {
		"nivel": nivel,
		"pos_x": posicion.x,
		"pos_y": posicion.y,
		"inventario": inventario,
		"tutorial_visto": tutorial_visto,
		"tutorial_aceptado": tutorial_aceptado,
		"granadas_desbloqueadas": granadas_enemigas_desbloqueadas,
		"bajas": enemigos_derrotados,
		"items": items_recogidos
	}
	file.store_var(datos)
	
	ruta_nivel = nivel
	pos_x = posicion.x
	pos_y = posicion.y
	inventario_guardado = inventario
	hay_datos_guardados = true

func cargar_juego():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var datos = file.get_var()
		
		if datos is Dictionary:
			ruta_nivel = datos.get("nivel", ruta_nivel)
			pos_x = datos.get("pos_x", pos_x)
			pos_y = datos.get("pos_y", pos_y)
			if datos.has("inventario"):
				inventario_guardado = datos["inventario"]
		tutorial_visto = datos.get("tutorial_visto", false)
		tutorial_aceptado = datos.get("tutorial_aceptado", false)
		granadas_enemigas_desbloqueadas = datos.get("granadas_desbloqueadas", false)
		enemigos_derrotados = Array(datos.get("bajas", []))
		items_recogidos = Array(datos.get("items", []))
		bajas_pendientes.clear()
		items_pendientes.clear()
		hay_datos_guardados = true
	else:
		hay_datos_guardados = false
		bajas_pendientes.clear()
		items_pendientes.clear()
