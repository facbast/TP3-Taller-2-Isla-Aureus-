extends CanvasLayer

signal tutorial_aceptado
signal tutorial_omitido

@onready var icono_rect = $Panel/IconoPersonaje
@onready var texto_label = $Panel/TextoDialogo
@onready var opciones_container = $Panel/OpcionesMenu
@onready var btn_si = $Panel/OpcionesMenu/BtnSi
@onready var btn_no = $Panel/OpcionesMenu/BtnNo
@onready var audio_blip = $AudioBlip

const ICONO_RADIO = preload("res://Assets/Radio.png")
const ICONO_CONEJO = preload("res://Assets/Icono Conejo.png")

var indice_dialogo = 0
var tween_texto: Tween
var velocidad_escritura = 0.03
var _ultimo_caracter: int = 0

# Variables para controlar el flujo final
var en_rama_final: bool = false
var respuesta_aceptada: bool = false

var dialogos = [
	{"icono": ICONO_RADIO, "texto": "*Click* Unidad Roku ¿Me copia?"},
	{"icono": ICONO_CONEJO, "texto": "Afirmativo..."},
	{"icono": ICONO_RADIO, "texto": "Soy su comandante, Radamanto Ignacio Ocampo"},
	{"icono": ICONO_CONEJO, "texto": "Hmmm, ¿'Rad. I.O.'?"},
	{"icono": ICONO_RADIO, "texto": "¿Dije algo gracioso, soldado?"},
	{"icono": ICONO_CONEJO, "texto": "No, continúa."},
	{"icono": ICONO_RADIO, "texto": "Tras despertar de tu hipersueño, es probable que hayas perdido algo de memoria. El protocolo me obliga a guiarte por las estrategias de combate básicas si es que no las recuerdas."}
]

# Líneas posteriores según la elección
var dialogos_si = [
	{"icono": ICONO_RADIO, "texto": "Bien, empecemos con lo básico. Desplázate usando las teclas A y D. Pulsa ESPACIO para saltar."},
	{"icono": ICONO_RADIO, "texto": "Para disparar, apunta con el Mouse y haz CLICK IZQUIERDO en tu objetivo. La mayoría de las armas siguen disparando si mantienes el botón apretado."},
	{"icono": ICONO_RADIO, "texto": "Mantén pulsado E para recoger armas del suelo, y pulsa TAB para intercambiar las que tienes a mano. Recarga tu munición pulsando R"}
]

var dialogos_no = [
	{"icono": ICONO_RADIO, "texto": "Recuerda que puedes ver tus controles pulsando ESC y abriendo el menú de controles. ¡Buena suerte, soldado!"}
]

func _ready():
	add_to_group("dialogos_tutorial")
	btn_si.pressed.connect(_on_opcion_si)
	btn_no.pressed.connect(_on_opcion_no)
	opciones_container.hide()

	# 1. Si el jugador ya aceptó el tutorial previamente (al reiniciar/morir):
	if Global.tutorial_aceptado:
		get_tree().paused = false # No pausar el juego
		en_rama_final = true
		respuesta_aceptada = true
		dialogos = dialogos_si
		_mostrar_linea()
	# 2. Si ya vio la introducción pero rechazó las instrucciones:
	elif Global.tutorial_visto:
		queue_free()
		return
	# 3. Primera vez que abre el tutorial:
	else:
		Global.tutorial_visto = true
		get_tree().paused = true # Pausar juego solo la primera vez
		_mostrar_linea()

func _process(_delta):
	if tween_texto and tween_texto.is_running():
		var char_actual = texto_label.visible_characters
		if char_actual > _ultimo_caracter:
			_ultimo_caracter = char_actual
			_reproducir_blip()

	if Input.is_action_just_pressed("ui_accept") and not opciones_container.visible:
		if tween_texto and tween_texto.is_running():
			tween_texto.kill()
			texto_label.visible_ratio = 1.0
		else:
			indice_dialogo += 1
			if indice_dialogo < dialogos.size():
				_mostrar_linea()
			else:
				if en_rama_final:
					_finalizar_tutorial()
				else:
					_mostrar_opciones()

func _reproducir_blip():
	if audio_blip and audio_blip.stream:
		audio_blip.pitch_scale = randf_range(0.95, 1.05)
		audio_blip.play()

func _mostrar_linea():
	var linea = dialogos[indice_dialogo]
	icono_rect.texture = linea["icono"]
	texto_label.text = linea["texto"]
	
	texto_label.visible_characters = 0
	_ultimo_caracter = 0
	
	if tween_texto and tween_texto.is_running():
		tween_texto.kill()
		
	var total_caracteres = linea["texto"].length()
	tween_texto = create_tween()
	var duracion = total_caracteres * velocidad_escritura
	
	tween_texto.tween_property(texto_label, "visible_characters", total_caracteres, duracion)

func _mostrar_opciones():
	icono_rect.texture = ICONO_CONEJO
	texto_label.text = "¿Qué debo responder?"
	texto_label.visible_ratio = 1.0
	opciones_container.show()
	btn_si.grab_focus()

func _on_opcion_si():
	respuesta_aceptada = true
	Global.tutorial_aceptado = true
	_iniciar_rama_dialogo(dialogos_si)

func _on_opcion_no():
	respuesta_aceptada = false
	_iniciar_rama_dialogo(dialogos_no)

func _iniciar_rama_dialogo(nuevos_dialogos: Array):
	opciones_container.hide()
	en_rama_final = true
	dialogos = nuevos_dialogos
	indice_dialogo = 0
	_mostrar_linea()

func cancelar_dialogo():
	# Permite que un diálogo de gatillo lo reemplace (caso del replay sin pausa).
	if tween_texto and tween_texto.is_running():
		tween_texto.kill()
	get_tree().paused = false
	queue_free()

func _finalizar_tutorial():
	get_tree().paused = false
	if respuesta_aceptada:
		tutorial_aceptado.emit()
	else:
		tutorial_omitido.emit()
	queue_free()
