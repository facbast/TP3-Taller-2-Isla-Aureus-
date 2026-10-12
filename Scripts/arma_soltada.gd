@tool
extends Area2D
## Item recogible colocable en los niveles: el tipo se elige en el inspector
## (Rifle/Pistola balísticos, Cañón/Pistola ácida, Granada Cargada o Durian).
## La textura y la munición por defecto se ajustan solas al cambiar el tipo;
## textura_arma permite forzar un sprite manual y cantidad_municion afinarla.

enum TipoItem {
	RIFLE_BALISTICO, # Rifle V.I.D.
	PISTOLA_BALISTICA, # Pistola Leguminosa
	CANON_ACIDO, # Cañón Cítrico (RiflePlasma)
	PISTOLA_ACIDA, # Pistola Cítrica (PistolaPlasma)
	GRANADA_CARGADA, # Fragmentación
	DURIAN, # Plasma (se adhiere a enemigos)
}

const TEXTURAS: Dictionary = {
	TipoItem.RIFLE_BALISTICO: preload("res://Assets/Armas/Rifle_Balistico.png"),
	TipoItem.PISTOLA_BALISTICA: preload("res://Assets/Armas/Pistola_Balistica.png"),
	TipoItem.CANON_ACIDO: preload("res://Assets/Armas/Rifle Plasma.png"),
	TipoItem.PISTOLA_ACIDA: preload("res://Assets/Armas/Pistola_Plasma.png"),
	TipoItem.GRANADA_CARGADA: preload("res://Assets/Granada HUD.png"),
	TipoItem.DURIAN: preload("res://Assets/Armas/Durian.png"),
}
# Nombre interno que entiende player.recoger_arma() para cada tipo.
const NOMBRES_ARMA: Dictionary = {
	TipoItem.RIFLE_BALISTICO: "Rifle",
	TipoItem.PISTOLA_BALISTICA: "Pistola",
	TipoItem.CANON_ACIDO: "RiflePlasma",
	TipoItem.PISTOLA_ACIDA: "PistolaPlasma",
	TipoItem.GRANADA_CARGADA: "Granada",
	TipoItem.DURIAN: "Durian",
}
const MUNICION_DEFECTO: Dictionary = {
	TipoItem.RIFLE_BALISTICO: 120,
	TipoItem.PISTOLA_BALISTICA: 24,
	TipoItem.CANON_ACIDO: 100,
	TipoItem.PISTOLA_ACIDA: 100,
	TipoItem.GRANADA_CARGADA: 1,
	TipoItem.DURIAN: 1,
}
# Tamaño de muestra por nombre interno: los sprites vienen en alta
# resolución y a escala 1.0 se ven gigantes. Se aplica solo cuando nadie
# definió escala (ítems colocados desde el inspector); los drops con
# escala propia (gecko, jugador, avispa B...) no se tocan.
const ESCALA_POR_ARMA: Dictionary = {
	"Rifle": Vector2(0.08, 0.08),
	"Pistola": Vector2(0.5, 0.5),
	"RiflePlasma": Vector2(0.08, 0.08),
	"PistolaPlasma": Vector2(0.07, 0.07),
	"Granada": Vector2(0.05, 0.05),
	"Durian": Vector2(0.16, 0.16),
}

# NOTA: tipo_item va antes que cantidad_municion a propósito, así al cargar
# la escena el setter ya dejó el valor por defecto antes de aplicar el
# cantidad_municion guardado.
@export var tipo_item: TipoItem = TipoItem.PISTOLA_BALISTICA:
	set(valor):
		tipo_item = valor
		tipo_arma = NOMBRES_ARMA.get(valor, "Pistola")
		if Engine.is_editor_hint():
			cantidad_municion = MUNICION_DEFECTO.get(valor, cantidad_municion)
			scale = ESCALA_POR_ARMA.get(tipo_arma, scale)
			_vista_previa_textura()

@export var cantidad_municion: int = 16
# Sprite manual: si se deja vacío se usa el del tipo elegido.
@export var textura_arma: Texture2D = null:
	set(valor):
		textura_arma = valor
		_vista_previa_textura()

# Jerarquía de valor (mayor a menor): Rifle > Cañón Cítrico >
# Pistola Cítrica > Pistola Leguminosa. Evita rebajas por accidente:
# con E solo se cambia a un arma de valor igual o mayor.
const VALOR_ARMA: Dictionary = {
	"Rifle": 4,
	"RiflePlasma": 3,
	"PistolaPlasma": 2,
	"Pistola": 1,
}
# Las mejores se recogen más rápido: entre dos ítems solapados gana el
# de mayor valor en vez de arbitrarlo el primer temporizador.
const TIEMPO_POR_VALOR: Dictionary = {
	4: 0.25,
	3: 0.35,
	2: 0.45,
	1: 0.6,
}

# Nombre interno del arma (lo usan los drops de enemigos/jugador).
var tipo_arma: String = "Pistola"

var jugador_cerca = null
var tiempo_manteniendo = 0.0
var tiempo_requerido = 0.4

func _ready():
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	# La textura manual manda; si no hay, se deduce del tipo de arma.
	# Esto también viste los drops que venían sin textura (ej. granadas del élite).
	if textura_arma != null:
		$Sprite2D.texture = textura_arma
	else:
		var automatica := _textura_para_arma(tipo_arma)
		if automatica != null:
			$Sprite2D.texture = automatica
		# Sin escala definida (ítems del inspector a 1.0), se usa la de muestra.
		if scale == Vector2.ONE:
			scale = ESCALA_POR_ARMA.get(tipo_arma, Vector2.ONE)

func _process(delta):
	if jugador_cerca == null:
		return
	if not Input.is_physical_key_pressed(KEY_E):
		tiempo_manteniendo = 0.0
		return
	# Sin restricciones: E siempre intercambia. Entre ítems amontonados,
	# el de mayor valor carga más rápido y gana la pulsación.
	var valor_item: int = VALOR_ARMA.get(tipo_arma, 0)
	tiempo_manteniendo += delta
	if tiempo_manteniendo >= float(TIEMPO_POR_VALOR.get(valor_item, tiempo_requerido)):
		var recogido = jugador_cerca.recoger_arma(tipo_arma, cantidad_municion)
		if recogido:
			queue_free()
		else:
			# Si la rechazó (ej. batería inferior), reiniciamos el temporizador
			tiempo_manteniendo = 0.0

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Las granadas se recogen al instante al pasar por encima.
		if tipo_arma == "Granada" or tipo_arma == "Durian":
			var recogido = body.recoger_arma(tipo_arma, cantidad_municion)
			if recogido:
				queue_free()
			return
		var ya_tiene_arma = false
		var usa_bateria = false

		for arma in body.armas:
			if arma.name == tipo_arma:
				ya_tiene_arma = true
				if "bateria" in arma:
					usa_bateria = true
				break

		# Solo absorbemos munición al instante si YA la tiene y NO es de batería
		if ya_tiene_arma and not usa_bateria:
			var recogido = body.recoger_arma(tipo_arma, cantidad_municion)
			if recogido:
				queue_free()
		else:
			# Obligamos al jugador a usar la tecla 'E' para armas nuevas o de energía
			jugador_cerca = body

func _on_body_exited(body):
	if body == jugador_cerca:
		jugador_cerca = null
		tiempo_manteniendo = 0.0

func _textura_para_arma(nombre: String) -> Texture2D:
	for clave in NOMBRES_ARMA.keys():
		if NOMBRES_ARMA[clave] == nombre:
			return TEXTURAS.get(clave)
	return null

# Refresca el sprite en el editor al cambiar tipo o textura manual.
func _vista_previa_textura() -> void:
	if not Engine.is_editor_hint() or not has_node("Sprite2D"):
		return
	if textura_arma != null:
		$Sprite2D.texture = textura_arma
	else:
		$Sprite2D.texture = TEXTURAS.get(tipo_item)
