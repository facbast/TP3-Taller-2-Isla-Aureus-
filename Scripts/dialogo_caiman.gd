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
	{"icono": ICONO_RADIO, "texto": "Espera..."},
	{"icono": ICONO_CONEJO, "texto": "¿Qué?"},
	{"icono": ICONO_RADIO, "texto": "Detecto una unidad Beta tras esa estructura"},
	{"icono": ICONO_RADIO, "texto": "Igual que tú, ellos poseen lo que llaman \"Cristales Atenea\", que sustraen el daño infligido a su usuario."},
	{"icono": ICONO_CONEJO, "texto": "Genial ¿Cuántas balas pueden aguantar?"},
	{"icono": ICONO_RADIO, "texto": "No hagas la cuenta. La mejor manera de perforar sus escudos es corroer sus cristales usando ácido. Y sus armas tienen de sobra."},
	{"icono": ICONO_RADIO, "texto": "Recoge la Pistola Cítrica que tiró ese gecko, mantén pulsado CLICK IZQUIERDO mientras apuntas al Beta, y el tiro de ácido cargado será suficiente para bajar sus escudos."},
	{"icono": ICONO_RADIO, "texto": "Un consejo, nuestras armas balísticas son más efectivas a la piel expuesta."}
]

func _ready():
	add_to_group("dialogos_tutorial")
	hide()

func iniciar_dialogo():
	if not Global.tutorial_aceptado:
		return
	# Solo puede haber un cuadro visible: el nuevo cancela el anterior.
	_cancelar_otros_dialogos()
	indice_dialogo = 0
	show()
	get_tree().paused = true
	_mostrar_linea()

func _process(_delta):
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
