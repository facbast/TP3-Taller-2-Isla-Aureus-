extends Control
## Selector de misiones: se abre con Continuar (si hay partida guardada).
## Sin completar → checkpoint más reciente; completada → desde el principio
## sin borrar el progreso. Volver regresa a la pantalla de título.

const TEXTURA_CARTEL = preload("res://Assets/Menu/Cartel.png")
const TEXTURA_HOVER = preload("res://Assets/Menu/Cartel_Hover.png")
const TEXTURA_PRESIONADO = preload("res://Assets/Menu/Cartel_Presionado.png")
const FUENTE_TITULOS = preload("res://Fonts/NeulandOpti-Light.otf")

@onready var lista_misiones = $Centro/VBoxMisiones
@onready var transicion = $Transicion

var _eligiendo: bool = false

func _ready() -> void:
	transicion.modulate.a = 1.0
	var entrada = create_tween()
	entrada.tween_property(transicion, "modulate:a", 0.0, 0.8)
	_construir_botones()

func _construir_botones() -> void:
	for i in range(Global.MISIONES.size()):
		var mision: Dictionary = Global.MISIONES[i]
		var boton := _crear_boton_cartel("BtnMision%d" % (i + 1))
		boton.pressed.connect(_on_mision_elegida.bind(i))
		var texto: String = str(mision.get("nombre", "Misión %d" % (i + 1)))
		if Global.mision_completada(mision["escena"]):
			texto += " ✓"
		_agregar_etiqueta(boton, texto, 38)
		lista_misiones.add_child(boton)
	# Relleno inservible: la tercera misión aún no fue conceptualizada.
	var extra := _crear_boton_cartel("BtnMisionProximamente")
	extra.disabled = true
	extra.modulate = Color(0.65, 0.65, 0.65) # Grisado: se nota inservible
	_agregar_etiqueta(extra, "¡Más Misiones en el juego completo!", 30)
	lista_misiones.add_child(extra)

func _crear_boton_cartel(nombre: String) -> TextureButton:
	var boton := TextureButton.new()
	boton.name = nombre
	boton.custom_minimum_size = Vector2(560, 130)
	boton.texture_normal = TEXTURA_CARTEL
	boton.texture_hover = TEXTURA_HOVER
	boton.texture_pressed = TEXTURA_PRESIONADO
	boton.texture_disabled = TEXTURA_CARTEL
	# TextureButton no tiene expand_mode (eso es de TextureRect):
	# se usa ignore_texture_size para que mande el tamaño mínimo.
	boton.ignore_texture_size = true
	boton.stretch_mode = 0 # STRETCH_SCALE: el cartel llena el botón
	return boton

func _agregar_etiqueta(boton: TextureButton, texto: String, tamano_fuente: int) -> void:
	var etiqueta := Label.new()
	etiqueta.name = "Etiqueta"
	etiqueta.text = texto
	etiqueta.set_anchors_preset(Control.PRESET_FULL_RECT)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_color_override("font_color", Color.WHITE)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 6)
	etiqueta.add_theme_font_override("font", FUENTE_TITULOS)
	etiqueta.add_theme_font_size_override("font_size", tamano_fuente)
	boton.add_child(etiqueta)

func _on_mision_elegida(indice: int) -> void:
	if _eligiendo:
		return
	_eligiendo = true
	var escena: String = Global.MISIONES[indice]["escena"]
	Global.seleccionar_mision(escena, Global.mision_completada(escena))
	await _fundido_salida()
	get_tree().change_scene_to_file(escena)

func _on_btn_volver_pressed() -> void:
	if _eligiendo:
		return
	_eligiendo = true
	await _fundido_salida()
	get_tree().change_scene_to_file("res://Scenes/pantalla_titulo.tscn")

func _fundido_salida() -> Tween:
	transicion.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(transicion, "modulate:a", 1.0, 0.8)
	await tween.finished
	return tween
