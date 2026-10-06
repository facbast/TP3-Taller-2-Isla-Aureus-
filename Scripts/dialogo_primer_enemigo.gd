extends CanvasLayer

signal dialogo_finalizado

@onready var icono_rect = $Panel/IconoPersonaje
@onready var texto_label = $Panel/TextoDialogo
@onready var audio_blip = $AudioBlip

const ICONO_RADIO = preload("res://Assets/Radio.png")
const ICONO_CONEJO = preload("res://Assets/Icono Conejo.png")

var indice_dialogo = 0
var tween_texto: Tween
var velocidad_escritura = 0.03
var _ultimo_caracter: int = 0

var dialogos = [
	{"icono": ICONO_CONEJO, "texto": "¿Quién era ese gecko?"},
	{"icono": ICONO_RADIO, "texto": "Pertenece a la Armada Reptiliana. Estos se dividen en una jerarquía de cuatro especies."},
	{"icono": ICONO_RADIO, "texto": "Los gecko son los \"Delta\", los más débiles, así que no dudes en enfrentarlos de frente."}
]

func _ready():
	add_to_group("dialogos_tutorial")
	hide() # Escondemos el canvas al iniciar el nivel
	# No hacemos queue_free aquí: en _ready el jugador aún no respondió
	# al DialogoTutorial, así que tutorial_aceptado todavía es false.
	# El trigger (TutorialGecko) decide si debe mostrarse o descartarse.

# FUNCIÓN QUE LLAMA EL ÁREA
func iniciar_dialogo():
	if not Global.tutorial_aceptado:
		return
	# Solo puede haber un cuadro visible: el nuevo cancela el anterior.
	_cancelar_otros_dialogos()
	indice_dialogo = 0
	show() # Mostramos el canvas
	get_tree().paused = true
	_mostrar_linea()

# ... (El resto de tus funciones _process, _reproducir_blip, _mostrar_linea y _finalizar_dialogo quedan exactamente igual)

func _process(_delta):
	# Si el diálogo está oculto (aún no se activó el trigger), no consumir input.
	# Sin esto, saltar con ESPACIO (ui_accept) de camino al trigger avanzaba
	# el índice y hacía queue_free antes de mostrarse.
	if not visible:
		return
	if tween_texto and tween_texto.is_running():
		var char_actual = texto_label.visible_characters
		if char_actual > _ultimo_caracter:
			_ultimo_caracter = char_actual
			_reproducir_blip()

	if Input.is_action_just_pressed("ui_accept"):
		if tween_texto and tween_texto.is_running():
			tween_texto.kill()
			texto_label.visible_ratio = 1.0
		else:
			indice_dialogo += 1
			if indice_dialogo < dialogos.size():
				_mostrar_linea()
			else:
				_finalizar_dialogo()

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
	tween_texto.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var duracion = total_caracteres * velocidad_escritura
	
	tween_texto.tween_property(texto_label, "visible_characters", total_caracteres, duracion)

func _cancelar_otros_dialogos():
	for n in get_tree().get_nodes_in_group("dialogos_tutorial"):
		if n != self and is_instance_valid(n) and n.has_method("cancelar_dialogo"):
			n.cancelar_dialogo()

func cancelar_dialogo():
	# Cierre silencioso: no emite señal, el nuevo diálogo toma la pantalla.
	if tween_texto and tween_texto.is_running():
		tween_texto.kill()
	get_tree().paused = false
	queue_free()

func _finalizar_dialogo():
	get_tree().paused = false
	dialogo_finalizado.emit()
	queue_free()
