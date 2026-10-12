extends CanvasLayer
## Interferencia radial (punto de trama del Nivel 2): una voz desconocida
## se mete en la radio de Roku. Las líneas de la avispa usan caja metálica
## y voz áspera para sorprender al jugador.

signal dialogo_finalizado

@onready var panel = $Panel
@onready var icono_rect = $Panel/IconoPersonaje
@onready var texto_label = $Panel/TextoDialogo
@onready var audio_blip = $AudioBlip

const ICONO_RADIO = preload("res://Assets/Radio.png")
const ICONO_CONEJO = preload("res://Assets/Icono Conejo.png")
const ZUMBIDO_AVISTA = preload("res://SFX/Panal/Zumbido_Suspenso.wav")

# Verde enfermizo para la voz avispa; blanco normal para el resto.
const COLOR_TEXTO_NORMAL := Color.WHITE
const COLOR_TEXTO_AVISPA := Color(0.78, 1.0, 0.55)

var dialogos = [
	{"icono": ICONO_RADIO, "texto": "*Click*", "voz": "radio"},
	{"icono": ICONO_RADIO, "texto": "BZZZBZNBNZMNZNUZZNUUM", "voz": "avispa"},
	{"icono": ICONO_CONEJO, "texto": "!?", "voz": "roku"},
	{"icono": ICONO_CONEJO, "texto": "¿¡Quien eres!?", "voz": "roku"},
	{"icono": ICONO_RADIO, "texto": "BZZZBZBZ-LARGO-BZNZBNZBZBZ-AQUÍ-BBZZMBBMBZZZBM-AHORA", "voz": "avispa"},
	{"icono": ICONO_RADIO, "texto": "*Click*", "voz": "radio"},
	{"icono": ICONO_CONEJO, "texto": "...", "voz": "roku"},
]

var indice_dialogo = 0
var tween_texto: Tween
var velocidad_escritura = 0.03
var _ultimo_caracter: int = 0
var _estilo_normal: StyleBox
var _estilo_metalico: StyleBoxFlat
var _voz_player: AudioStreamPlayer

func _ready():
	add_to_group("dialogos_tutorial")
	_estilo_normal = panel.get_theme_stylebox("panel")
	_estilo_metalico = StyleBoxFlat.new()
	_estilo_metalico.bg_color = Color(0.42, 0.46, 0.51) # Acero
	_estilo_metalico.border_color = Color(0.85, 0.9, 0.95) # Filo claro
	_estilo_metalico.set_border_width_all(3)
	_estilo_metalico.set_corner_radius_all(6)
	_voz_player = AudioStreamPlayer.new()
	_voz_player.name = "VozAvispa"
	_voz_player.stream = ZUMBIDO_AVISTA
	_voz_player.volume_db = -10.0
	add_child(_voz_player)
	hide()

func iniciar_dialogo():
	# Punto de trama: se muestra haya aceptado o no el tutorial.
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

func _es_avispa() -> bool:
	return dialogos[indice_dialogo].get("voz", "radio") == "avispa"

func _reproducir_blip():
	if not (audio_blip and audio_blip.stream):
		return
	if _es_avispa():
		# Voz áspera: bip grave e irregular sobre el colchón de zumbido.
		audio_blip.pitch_scale = randf_range(0.45, 0.65)
	else:
		audio_blip.pitch_scale = randf_range(0.95, 1.05)
	audio_blip.play()

func _mostrar_linea():
	var linea = dialogos[indice_dialogo]
	icono_rect.texture = linea["icono"]
	texto_label.text = linea["texto"]

	if _es_avispa():
		# Caja metálica + texto verdoso + zumbido de fondo: la sorpresa.
		panel.add_theme_stylebox_override("panel", _estilo_metalico)
		texto_label.add_theme_color_override("default_color", COLOR_TEXTO_AVISPA)
		if not _voz_player.playing:
			_voz_player.play()
	else:
		panel.add_theme_stylebox_override("panel", _estilo_normal)
		texto_label.add_theme_color_override("default_color", COLOR_TEXTO_NORMAL)
		_voz_player.stop()

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
	_voz_player.stop()
	get_tree().paused = false
	queue_free()

func _finalizar_dialogo():
	_voz_player.stop()
	get_tree().paused = false
	dialogo_finalizado.emit()
	queue_free()
