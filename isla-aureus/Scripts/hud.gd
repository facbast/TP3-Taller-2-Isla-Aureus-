extends CanvasLayer

@onready var label_municion = $MarginContainer/LabelMunicion
@onready var label_granadas = $MarginContainer2/LabelGranadas
@onready var barra_escudo: ProgressBar = $MarcoHUD/BarraEscudo
@onready var barra_salud: ProgressBar = $MarcoHUD/BarraSalud

# --- NUEVA REFERENCIA ---
@onready var label_notificacion = $MensajeNotificacion
var _tween_notificacion: Tween

func actualizar_municion(cargador: int, reserva: int):
	label_municion.text = "Munición: " + str(cargador) + " / " + str(reserva)

func actualizar_escudos_hud(valor_actual: float, valor_maximo: float):
	# ... tu código actual ...
	barra_escudo.max_value = valor_maximo
	barra_escudo.value = valor_actual

func actualizar_salud_hud(valor_actual: float, valor_maximo: float):
	# ... tu código actual ...
	barra_salud.max_value = valor_maximo
	barra_salud.value = valor_actual

# --- NUEVA FUNCIÓN PARA NOTIFICACIONES ---
func mostrar_notificacion(mensaje: String):
	label_notificacion.text = mensaje
	label_notificacion.modulate.a = 1.0 # Lo hacemos 100% visible al instante
	
	# Si ya había una notificación desvaneciéndose, la cancelamos para mostrar la nueva
	if _tween_notificacion and _tween_notificacion.is_valid():
		_tween_notificacion.kill()
		
	# Creamos una nueva animación desde el código
	_tween_notificacion = create_tween()
	
	# Le decimos que espere 2.0 segundos con el texto visible
	_tween_notificacion.tween_interval(2.0)
	
	# Y luego, que anime la transparencia ("modulate:a") hasta 0.0, tomando 1.5 segundos en hacerlo
	_tween_notificacion.tween_property(label_notificacion, "modulate:a", 0.0, 1.5)
	
func actualizar_granadas(cantidad: int, maximo: int):
	label_granadas.text = "Granada: " + str(cantidad) + "/" + str(maximo)
