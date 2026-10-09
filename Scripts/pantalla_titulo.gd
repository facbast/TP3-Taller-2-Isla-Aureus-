extends Control

@onready var btn_continuar = $VBoxContainer/BtnContinuar

# --- REFERENCIAS DE PANELES ---
@onready var panel_controles = $PanelControles
@onready var panel_creditos = $PanelCreditos
@onready var transicion = $Transicion

# Evita dobles clics mientras el fundido está en marcha
var _transicionando: bool = false

func _ready():
	# Fundido de entrada al llegar (desde splash, meta o menú de pausa)
	transicion.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(transicion, "modulate:a", 0.0, 1.0)
	# Si no hay un checkpoint guardado, desactivamos el botón de Continuar
	if Global.hay_datos_guardados:
		btn_continuar.disabled = false
	else:
		btn_continuar.disabled = true
		
	# Nos aseguramos de que los paneles inicien ocultos
	if panel_controles:
		panel_controles.hide()
	if panel_creditos:
		panel_creditos.hide()

func _on_btn_nueva_partida_pressed():
	if _transicionando:
		return
	# Si el jugador quiere empezar de cero, borramos el registro temporal
	Global.hay_datos_guardados = false
	# Reiniciamos el estado del tutorial (Global es autoload y persiste entre escenas)
	Global.tutorial_visto = false
	Global.tutorial_aceptado = false
	Global.granadas_enemigas_desbloqueadas = false
	Global.enemigos_derrotados = []
	Global.items_recogidos = []
	Global.bajas_pendientes = []
	Global.items_pendientes = []
	# Limpiamos restos del checkpoint anterior en memoria
	Global.inventario_guardado = {}
	Global.pos_x = 0.0
	Global.pos_y = 0.0
	Global.ruta_nivel = "res://Scenes/main.tscn"
	get_tree().paused = false
	
	# Opcional: Borrar el archivo físico si quieres un reinicio total
	if FileAccess.file_exists(Global.SAVE_PATH):
		var dir = DirAccess.open("user://")
		dir.remove("savegame.save")

	# Fundido de salida y recién entonces cambiamos de escena
	await _fundido_salida()
	# Cambia esto por el nombre exacto de la escena de tu nivel 1
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_btn_continuar_pressed():
	if Global.hay_datos_guardados and not _transicionando:
		get_tree().paused = false
		await _fundido_salida()
		# Cargamos la escena guardada en el checkpoint
		get_tree().change_scene_to_file(Global.ruta_nivel)

# Funde a negro y devuelve el tween por si alguien quiere esperarlo.
func _fundido_salida() -> Tween:
	_transicionando = true
	transicion.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(transicion, "modulate:a", 1.0, 0.8)
	await tween.finished
	return tween

# --- NAVEGACIÓN DE MENÚS Y PANELES ---
func _on_btn_controles_pressed():
	panel_controles.show()

func _on_btn_creditos_pressed():
	panel_creditos.show()

func _on_btn_volver_pressed():
	# Oculta ambos paneles para regresar al menú principal
	panel_controles.hide()
	panel_creditos.hide()
