extends CanvasLayer

@onready var label_municion = $MarginContainer/LabelMunicion
@onready var barra_escudo: ProgressBar = $MarcoHUD/BarraEscudo
@onready var barra_salud: ProgressBar = $MarcoHUD/BarraSalud

# Función para la munición (la que ya teníamos)
func actualizar_municion(cargador: int, reserva: int):
	label_municion.text = "Munición: " + str(cargador) + " / " + str(reserva)

# Nuevas funciones para Escudo y Salud
func actualizar_escudos_hud(valor_actual: float, valor_maximo: float):
	barra_escudo.max_value = valor_maximo
	barra_escudo.value = valor_actual

func actualizar_salud_hud(valor_actual: float, valor_maximo: float):
	barra_salud.max_value = valor_maximo
	barra_salud.value = valor_actual
