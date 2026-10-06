extends CanvasLayer

# --- DICCIONARIO DE TEXTURAS DE ARMAS ---
const TEXTURAS_ARMAS = {
	"Rifle": preload("res://Assets/Armas/Rifle_Balistico.png"),
	"Pistola": preload("res://Assets/Armas/Pistola_Balistica.png"),
	"PistolaPlasma": preload("res://Assets/Armas/Pistola_Plasma.png"),
	"RiflePlasma": preload("res://Assets/Armas/Rifle Plasma.png")
}

@onready var label_municion = $ContenedorArma/LabelMunicion
@onready var icono_arma = $ContenedorArma/IconoArma

# --- REFERENCIAS DE GRANADAS (ESQUINA INFERIOR DERECHA) ---
@onready var icono_frag = $ContenedorGranada/HBoxContainer/IconoFrag
@onready var label_frag = $ContenedorGranada/HBoxContainer/LabelFrag
@onready var icono_plasma = $ContenedorGranada/HBoxContainer/IconoPlasma
@onready var label_plasma = $ContenedorGranada/HBoxContainer/LabelPlasma

@onready var barra_escudo: ProgressBar = $MarcoHUD/BarraEscudo
@onready var barra_salud: ProgressBar = $MarcoHUD/BarraSalud
@onready var label_notificacion = $MensajeNotificacion

var _tween_notificacion: Tween

func actualizar_municion(cargador: int, reserva: int, nombre_arma: String = ""):
	# Cambiar la imagen del arma si se proporciona el nombre
	if nombre_arma in TEXTURAS_ARMAS:
		icono_arma.texture = TEXTURAS_ARMAS[nombre_arma]
	
	# Si la reserva es negativa, tratamos la munición como porcentaje de batería
	if reserva < 0:
		label_municion.text = str(cargador) + "%"
	else:
		label_municion.text = str(cargador) + " / " + str(reserva)

func actualizar_escudos_hud(valor_actual: float, valor_maximo: float):
	barra_escudo.max_value = valor_maximo
	barra_escudo.value = valor_actual

func actualizar_salud_hud(valor_actual: float, valor_maximo: float):
	barra_salud.max_value = valor_maximo
	barra_salud.value = valor_actual

func mostrar_notificacion(mensaje: String):
	label_notificacion.text = mensaje
	label_notificacion.modulate.a = 1.0
	
	if _tween_notificacion and _tween_notificacion.is_valid():
		_tween_notificacion.kill()
		
	_tween_notificacion = create_tween()
	_tween_notificacion.tween_interval(2.0)
	_tween_notificacion.tween_property(label_notificacion, "modulate:a", 0.0, 1.5)

func actualizar_granadas(frag_cant: int, plasma_cant: int, maximo: int, usando_plasma: bool):
	# 1. Actualizamos los textos de ambas
	label_frag.text = "x" + str(frag_cant) + " / " + str(maximo)
	label_plasma.text = "x" + str(plasma_cant) + " / " + str(maximo)
	
	# 2. Resaltamos la granada equipada y oscurecemos la otra
	if usando_plasma:
		icono_plasma.modulate = Color(1.0, 1.0, 1.0, 1.0) # Opacidad al 100%
		label_plasma.modulate = Color(1.0, 1.0, 1.0, 1.0)
		icono_frag.modulate = Color(1.0, 1.0, 1.0, 0.3)   # Opacidad al 30%
		label_frag.modulate = Color(1.0, 1.0, 1.0, 0.3)
	else:
		icono_frag.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label_frag.modulate = Color(1.0, 1.0, 1.0, 1.0)
		icono_plasma.modulate = Color(1.0, 1.0, 1.0, 0.3)
		label_plasma.modulate = Color(1.0, 1.0, 1.0, 0.3)
