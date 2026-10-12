extends Area2D
## Trigger final del nivel 1 (boca de la cueva): inicia la conversación
## de salida. Al terminar, funde y cambia a ruta_siguiente.
## Provisorio: lleva al menú principal; apuntar al nivel 2 cuando exista.

@export var dialogo_canvas: CanvasLayer
@export var ruta_siguiente: String = "res://Scenes/pantalla_titulo.tscn"

var _disparado: bool = false

func _ready() -> void:
	if is_instance_valid(dialogo_canvas) and dialogo_canvas.has_signal("dialogo_finalizado"):
		dialogo_canvas.dialogo_finalizado.connect(_on_dialogo_finalizado)

func _on_body_entered(cuerpo: Node2D) -> void:
	if _disparado:
		return
	if not (cuerpo.is_in_group("player") or cuerpo.is_in_group("Player") or cuerpo.name == "Player"):
		return
	_disparado = true
	set_deferred("monitoring", false)
	if is_instance_valid(dialogo_canvas) and dialogo_canvas.has_method("iniciar_dialogo"):
		dialogo_canvas.iniciar_dialogo()
	else:
		push_warning("TriggerFinal: dialogo_canvas no asignado o sin iniciar_dialogo().")
		Global.completar_mision(Global.mision_actual)
		_ir_al_siguiente_nivel()

func _on_dialogo_finalizado() -> void:
	Global.completar_mision(Global.mision_actual)
	_ir_al_siguiente_nivel()

func _ir_al_siguiente_nivel() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hacer_fade_out"):
		await hud.hacer_fade_out(1.5).finished
	# Solo se corta la música si el destino no es otro nivel
	# (entre niveles sigue sonando sin reiniciarse).
	if not _es_escena_de_mision(ruta_siguiente):
		MusicManager.detener_musica()
	get_tree().change_scene_to_file(ruta_siguiente)

func _es_escena_de_mision(ruta: String) -> bool:
	for m in Global.MISIONES:
		if m["escena"] == ruta:
			return true
	return false
