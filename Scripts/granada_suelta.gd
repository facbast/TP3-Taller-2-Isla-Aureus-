@tool
extends Area2D
## Granada suelta colocable en los niveles: el tipo se elige en el inspector
## (Cargada de fragmentación o Durian de plasma). Se recoge al pasar por
## encima, sin mantener E. Las Durian solo aparecen así: ningún reptil las lanza.

enum TipoGranada {
	CARGADA, # Fragmentación (daño en área)
	DURIAN, # Plasma (se adhiere a enemigos)
}

const TEXTURAS: Dictionary = {
	TipoGranada.CARGADA: preload("res://Assets/Armas/Granada Cargada.png"),
	TipoGranada.DURIAN: preload("res://Assets/Armas/Granada.png"),
}
# Nombre interno que entiende player.recoger_arma() para cada tipo.
const NOMBRES: Dictionary = {
	TipoGranada.CARGADA: "Granada",
	TipoGranada.DURIAN: "Durian",
}
const CANTIDAD_DEFECTO: Dictionary = {
	TipoGranada.CARGADA: 2,
	TipoGranada.DURIAN: 2,
}
const ESCALA_MUESTRA: Dictionary = {
	TipoGranada.CARGADA: Vector2(0.1, 0.1),
	TipoGranada.DURIAN: Vector2(0.1, 0.1),
}

# NOTA: tipo va antes que cantidad a propósito, así al cargar la escena
# el setter ya dejó el valor por defecto antes de aplicar el guardado.
@export var tipo: TipoGranada = TipoGranada.CARGADA:
	set(valor):
		tipo = valor
		if Engine.is_editor_hint():
			cantidad = CANTIDAD_DEFECTO.get(valor, cantidad)
			scale = ESCALA_MUESTRA.get(valor, scale)
			_vista_previa()

@export var cantidad: int = 2

func _ready() -> void:
	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
	_aplicar_textura()

func _on_body_entered(cuerpo: Node2D) -> void:
	if not cuerpo.is_in_group("player"):
		return
	if cuerpo.has_method("recoger_arma"):
		var nombre: String = NOMBRES.get(tipo, "Granada")
		if cuerpo.recoger_arma(nombre, cantidad):
			queue_free()
		# Si no hay lugar (munición llena), el item espera.

func _aplicar_textura() -> void:
	if has_node("Sprite2D"):
		$Sprite2D.texture = TEXTURAS.get(tipo)
		if scale == Vector2.ONE:
			scale = ESCALA_MUESTRA.get(tipo, Vector2.ONE)

# Refresca el sprite en el editor al cambiar el tipo.
func _vista_previa() -> void:
	if not Engine.is_editor_hint() or not has_node("Sprite2D"):
		return
	$Sprite2D.texture = TEXTURAS.get(tipo)
