extends Node

const SAVE_PATH = "user://savegame.save"
var hay_datos_guardados: bool = false

# --- MISIONES (selector de niveles) ---
const MISIONES := [
	{"id": "mision1", "nombre": "1: Repaso en la Jungla", "escena": "res://Scenes/main.tscn"},
	{"id": "mision2", "nombre": "2: Secreto Meloso", "escena": "res://Scenes/Nivel2.tscn"},
]
const ESCENA_MISION_1 := "res://Scenes/main.tscn"
var mision_actual: String = ESCENA_MISION_1
var misiones_completadas: Array = []
# Último checkpoint guardado de cada misión (por escena).
var checkpoints: Dictionary = {}
# Replay desde cero sin borrar el archivo: el working arranca limpio y el
# snapshot guardado queda intacto hasta pisar otro checkpoint.
var inicio_fresco_mision: bool = false
# Evita que al cambiar de misión se sobreescriba el snapshot con una
# sesión de replay que aún no guardó nada.
var sesion_desde_cero: bool = false

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
	if sesion_desde_cero or not checkpoints.has(mision_actual):
		# Sesión fresca (reinicio/replay sin checkpoint nuevo) o misión sin
		# snapshot (primera visita): se vuelve al inicio del nivel, NO a un
		# checkpoint viejo ni a la coordenada (0,0).
		_reset_working()
		inicio_fresco_mision = true
		return
	# Re-sincroniza lo confirmado con el checkpoint de la misión actual.
	if hay_datos_guardados:
		if checkpoints.has(mision_actual):
			_restaurar_snapshot(checkpoints[mision_actual])
		elif FileAccess.file_exists(SAVE_PATH):
			# Respaldo para partidas viejas sin diccionario por misión.
			var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
			var datos = file.get_var()
			if datos is Dictionary:
				enemigos_derrotados = Array(datos.get("bajas", []))
				items_recogidos = Array(datos.get("items", []))

# Los enemigos solo lanzan granadas después de pisar el trigger del
# tutorial 3, haya aceptado o rechazado el tutorial el jugador.
var granadas_enemigas_desbloqueadas: bool = false
# Fase musical: segunda mitad de la Misión 1 (set Aalt tras el trigger Burla)
# y Misión 2 con emboscada ya activada (set C). Viajan en el snapshot.
var segunda_mitad_m1: bool = false
var emboscada_nivel2: bool = false

# True si los enemigos pueden lanzar granadas ahora mismo.
# El bloqueo tutorial solo rige en la Misión 1: del Nivel 2 en adelante
# los reptiles siempre pueden usarlas (su trigger ya no existe ahí).
func enemigos_pueden_usar_granadas() -> bool:
	if granadas_enemigas_desbloqueadas:
		return true
	return mision_actual != ESCENA_MISION_1

# Distancia a la que Roku debe estar para que reptiles y avispas peleen
# entre ellos: evita que la guerra termine antes de que llegue a verla.
const RADIO_COMBATE_FACCIONES := 700.0
# Correa de emboscada: un spawn de arena que se aleja esto de su punto de
# aparición deja de cazar al bando contrario y vuelve con el jugador
# (si no, persiguen avispas fuera de los muros y la oleada no cierra).
const LEASH_ARENA := 800.0

# Combate entre bandos permitido solo con el jugador cerca. El jugador
# siempre es objetivo válido; esto solo filtra reptil-vs-avispa.
func combate_facciones_permitido(pos: Vector2) -> bool:
	for j in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(j) and (j as Node2D).global_position.distance_to(pos) <= RADIO_COMBATE_FACCIONES:
			return true
	return false

# Throttle global de voces enemigas (geckos y caimanes no se enciman).
var ultima_voz_msec: int = 0
const PAUSA_CORO_VOCES_MSEC := 1500

func puede_emitir_voz() -> bool:
	return Time.get_ticks_msec() - ultima_voz_msec >= PAUSA_CORO_VOCES_MSEC

func marcar_voz() -> void:
	ultima_voz_msec = Time.get_ticks_msec()

# Al reaparecer en un checkpoint, el flag vuelve al último guardado:
# morir después del trigger no puede desbloquearlas antes de él.
func restaurar_flags_checkpoint():
	if not hay_datos_guardados:
		return
	if checkpoints.has(mision_actual):
		granadas_enemigas_desbloqueadas = checkpoints[mision_actual].get("granadas_desbloqueadas", granadas_enemigas_desbloqueadas)
		return
	if not FileAccess.file_exists(SAVE_PATH):
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
	ruta_nivel = nivel
	pos_x = posicion.x
	pos_y = posicion.y
	inventario_guardado = inventario
	hay_datos_guardados = true
	# Pisar un checkpoint valida la sesión (ya no es replay sin guardar).
	sesion_desde_cero = false
	_snapshot_checkpoint()
	escribir_archivo()

# Guarda el working actual como snapshot de la misión en curso.
func _snapshot_checkpoint() -> void:
	checkpoints[mision_actual] = {
		"pos_x": pos_x,
		"pos_y": pos_y,
		"inventario": inventario_guardado.duplicate(true),
		"tutorial_visto": tutorial_visto,
		"tutorial_aceptado": tutorial_aceptado,
		"granadas_desbloqueadas": granadas_enemigas_desbloqueadas,
		"segunda_mitad": segunda_mitad_m1,
		"emboscada_n2": emboscada_nivel2,
		"bajas": enemigos_derrotados.duplicate(),
		"items": items_recogidos.duplicate(),
	}

# Carga el snapshot de una misión al working actual.
func _aplicar_snapshot_mision(escena: String) -> void:
	if not checkpoints.has(escena):
		return
	_restaurar_snapshot(checkpoints[escena])

func _restaurar_snapshot(snap: Dictionary) -> void:
	pos_x = snap.get("pos_x", 0.0)
	pos_y = snap.get("pos_y", 0.0)
	inventario_guardado = (snap.get("inventario", {}) as Dictionary).duplicate(true)
	tutorial_visto = snap.get("tutorial_visto", tutorial_visto)
	tutorial_aceptado = snap.get("tutorial_aceptado", tutorial_aceptado)
	granadas_enemigas_desbloqueadas = snap.get("granadas_desbloqueadas", granadas_enemigas_desbloqueadas)
	segunda_mitad_m1 = snap.get("segunda_mitad", segunda_mitad_m1)
	emboscada_nivel2 = snap.get("emboscada_n2", emboscada_nivel2)
	enemigos_derrotados = Array(snap.get("bajas", []))
	items_recogidos = Array(snap.get("items", []))

# Working limpio para arrancar una misión desde el principio.
func _reset_working() -> void:
	pos_x = 0.0
	pos_y = 0.0
	inventario_guardado = {}
	enemigos_derrotados = []
	items_recogidos = []
	bajas_pendientes = []
	items_pendientes.clear()

func escribir_archivo() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var datos = {
		"nivel": ruta_nivel,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"inventario": inventario_guardado,
		"tutorial_visto": tutorial_visto,
		"tutorial_aceptado": tutorial_aceptado,
		"granadas_desbloqueadas": granadas_enemigas_desbloqueadas,
		"bajas": enemigos_derrotados,
		"items": items_recogidos,
		"mision_actual": mision_actual,
		"misiones_completadas": misiones_completadas,
		"checkpoints": checkpoints,
	}
	file.store_var(datos)

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
			mision_actual = datos.get("mision_actual", datos.get("nivel", ESCENA_MISION_1))
			misiones_completadas = Array(datos.get("misiones_completadas", []))
			checkpoints = (datos.get("checkpoints", {}) as Dictionary).duplicate(true)
			if checkpoints.is_empty():
				# Migración de partidas viejas: el checkpoint único pasa a
				# ser el snapshot de su misión.
				_snapshot_checkpoint()
			else:
				_aplicar_snapshot_mision(mision_actual)
		bajas_pendientes.clear()
		items_pendientes.clear()
		sesion_desde_cero = false
		inicio_fresco_mision = false
		hay_datos_guardados = true
	else:
		hay_datos_guardados = false
		bajas_pendientes.clear()
		items_pendientes.clear()

# --- API del selector de misiones ---

func mision_completada(escena: String) -> bool:
	return misiones_completadas.has(escena)

func checkpoint_de(escena: String) -> Dictionary:
	return (checkpoints.get(escena, {}) as Dictionary).duplicate(true)

# Fija la misión en curso según la escena cargada (red de seguridad al
# entrar por cualquier vía: menú, continuar o prueba directa).
func fijar_mision_por_escena(ruta_escena: String) -> void:
	for m in MISIONES:
		if m["escena"] == ruta_escena:
			mision_actual = ruta_escena
			ruta_nivel = ruta_escena
			return

# Entrar a una misión desde el selector.
# desde_cero = replay de misión completada: arranca limpia en memoria,
# el archivo y su snapshot quedan intactos hasta otro checkpoint.
func seleccionar_mision(escena: String, desde_cero: bool) -> void:
	if not sesion_desde_cero:
		_snapshot_checkpoint()
		if hay_datos_guardados:
			escribir_archivo()
	mision_actual = escena
	ruta_nivel = escena
	if desde_cero:
		_reset_working()
		inicio_fresco_mision = true
		sesion_desde_cero = true
		# Replay limpio: la fase musical vuelve al inicio de esa misión.
		if escena == ESCENA_MISION_1:
			segunda_mitad_m1 = false
		if escena == MISIONES[1]["escena"]:
			emboscada_nivel2 = false
	else:
		sesion_desde_cero = false
		if checkpoints.has(escena):
			_aplicar_snapshot_mision(escena)
			inicio_fresco_mision = false
		else:
			_reset_working()
			inicio_fresco_mision = true

# Pasar el TriggerFin: marca la misión y persiste todo.
func completar_mision(escena: String) -> void:
	mision_actual = escena
	if not misiones_completadas.has(escena):
		misiones_completadas.append(escena)
	sesion_desde_cero = false
	_snapshot_checkpoint()
	hay_datos_guardados = true
	escribir_archivo()
