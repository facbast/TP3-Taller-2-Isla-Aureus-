extends Node
## Autoload: música por sets con crossfade.
## - Set A (Misión 1, primera mitad): loop-a1 normal / loop-a2 pelea.
## - Set Aalt (Misión 1, segunda mitad tras el trigger Burla): alt.
## - Set C (Misión 2, desde la primera emboscada): loop-c1 / loop-c2.
## - Set B (menús antes de una misión): loop-b1 (sin pelea).
##
## La música NO suena en splash hasta que el splash la pide; vive solo
## donde corresponde: menús (B), niveles (su set) y nada entre medio.
## Entre muertes y checkpoints (reload) sigue sin reiniciarse.

const PISTAS := {
	"A": {
		"normal": preload("res://Music/loop-a1.wav"),
		"pelea": preload("res://Music/loop-a2.wav"),
	},
	"Aalt": {
		"normal": preload("res://Music/loop-a1-alt.wav"),
		"pelea": preload("res://Music/loop-a2-alt.wav"),
	},
	"C": {
		"normal": preload("res://Music/loop-c1.wav"),
		"pelea": preload("res://Music/loop-c2.wav"),
	},
	"B": {
		"normal": preload("res://Music/loop-b1.wav"),
	},
}

## Segundos que se mantiene Pelea después de que el último enemigo
## deje de estar en alerta. Evita parpadeos si matas al último
## enemigo o si hay un hueco de 1 frame al recargar la escena.
@export var tiempo_gracia_salida: float = 4.0
## Duración del fundido entre pistas.
@export var duracion_crossfade: float = 1.5
## Volumen base de la música.
@export var volumen_base_db: float = -12.0
## Cada cuántos segundos se revisa si hay combate.
@export var intervalo_chequeo: float = 0.2

var _players: Dictionary = {}
var _set_actual: String = ""
var _en_combate: bool = false
var _tiempo_sin_alerta: float = 999.0
var _tiempo_chequeo: float = 0.0
var _tween_fade: Tween = null
## Música activada o silenciada (los SFX van por otros players y no se tocan).
var musica_activada: bool = true
## True mientras hay un nivel abierto (entre iniciar y detener).
## En menús es false y solo puede sonar el set B.
var _musica_iniciada: bool = false

func _ready() -> void:
	# La música no se corta con la pausa ni con los cambios de escena.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for set_id in PISTAS.keys():
		_players[set_id] = {}
		for modo in (PISTAS[set_id] as Dictionary).keys():
			var p := AudioStreamPlayer.new()
			p.name = "Musica_%s_%s" % [set_id, modo]
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			p.stream = _preparar_loop((PISTAS[set_id] as Dictionary)[modo])
			p.volume_db = -80.0
			add_child(p)
			(_players[set_id] as Dictionary)[modo] = p

	# Sin autoplay: cada contexto arranca su set (menús → B, niveles → suyo).

func _process(delta: float) -> void:
	# Sin nivel abierto, en pausa o con set sin pelea no se sondea combate.
	if not _musica_iniciada or get_tree().paused:
		_tiempo_chequeo = 0.0
		return
	if _set_actual == "" or not (_players.has(_set_actual) and (_players[_set_actual] as Dictionary).has("pelea")):
		_tiempo_chequeo = 0.0
		return
	_tiempo_chequeo += delta
	if _tiempo_chequeo < intervalo_chequeo:
		return
	_tiempo_chequeo = 0.0

	if _hay_combate():
		_tiempo_sin_alerta = 0.0
		if not _en_combate:
			_en_combate = true
			_hacer_crossfade(_player_de(_set_actual, "pelea"), _player_de(_set_actual, "normal"))
	else:
		_tiempo_sin_alerta += intervalo_chequeo
		if _en_combate and _tiempo_sin_alerta >= tiempo_gracia_salida:
			_en_combate = false
			_hacer_crossfade(_player_de(_set_actual, "normal"), _player_de(_set_actual, "pelea"))

func _player_de(set_id: String, modo: String) -> AudioStreamPlayer:
	return _players[set_id][modo] as AudioStreamPlayer

# Pone a sonar el player si estaba detenido (primera vez de cada pista).
func _asegurar_sonando(set_id: String) -> void:
	for modo in (_players[set_id] as Dictionary).keys():
		var p := _player_de(set_id, modo)
		p.stream_paused = false
		if not p.playing:
			p.play()

## True si algún enemigo vivo está en alerta, huyendo, en pánico
## o en plena sorpresa amarilla (0.8s previa a la alerta).
func _hay_combate() -> bool:
	var enemigos = get_tree().get_nodes_in_group("enemigos")
	for enemigo in enemigos:
		if not is_instance_valid(enemigo):
			continue
		# El élite dormido del tutorial de sigilo no cuenta hasta
		# que el trigger lo despierta.
		if "dormido_hasta_tutorial" in enemigo and enemigo.dormido_hasta_tutorial:
			continue
		if "es_alerta" in enemigo and enemigo.es_alerta:
			return true
		# Grunt aterrado tras caer el líder: sigue huyendo = sigue Pelea.
		if "esta_aterrado" in enemigo and enemigo.esta_aterrado:
			return true
		# Sorpresa a medias (el reloj ya corre pero es_alerta aún no).
		if "_sorpresa_tiempo" in enemigo and enemigo._sorpresa_tiempo > 0.0:
			return true
	return false

func _hacer_crossfade(subir: AudioStreamPlayer, bajar: AudioStreamPlayer) -> void:
	if _tween_fade and _tween_fade.is_running():
		_tween_fade.kill()
	_tween_fade = create_tween()
	_tween_fade.set_parallel(true)
	var destino_subir := volumen_base_db if musica_activada else -80.0
	_tween_fade.tween_property(subir, "volume_db", destino_subir, duracion_crossfade)
	_tween_fade.tween_property(bajar, "volume_db", -80.0, duracion_crossfade)

# Cambia de set fundiendo el audible al normal del nuevo. Idempotente:
# si ya suena ese set, solo repara volúmenes y pausa.
func _reproducir_set(nuevo_set: String) -> void:
	_en_combate = false
	_tiempo_sin_alerta = 999.0
	if nuevo_set == "":
		_set_actual = ""
		_aplicar_volumen_actual()
		return
	_asegurar_sonando(nuevo_set)
	var anterior := _player_actual_audible_si_hay()
	_set_actual = nuevo_set
	var destino := _player_de(nuevo_set, "normal")
	if anterior != null and anterior != destino:
		_hacer_crossfade(destino, anterior)
		return
	# Sin nada sonando (o ya era esta pista): fundido de entrada suave.
	if _tween_fade and _tween_fade.is_running():
		_tween_fade.kill()
	_tween_fade = create_tween()
	var volumen := volumen_base_db if musica_activada else -80.0
	_tween_fade.tween_property(destino, "volume_db", volumen, duracion_crossfade)

# El player que está sonando ahora mismo (o null si ninguno).
func _player_actual_audible_si_hay() -> AudioStreamPlayer:
	for set_id in _players.keys():
		for modo in (_players[set_id] as Dictionary).keys():
			var p := _player_de(set_id, modo)
			if p.playing and p.volume_db > -79.0:
				return p
	return null

# Aplica el mute al instante sobre la pista que suena ahora.
func _aplicar_volumen_actual() -> void:
	if _tween_fade and _tween_fade.is_running():
		_tween_fade.kill()
	for set_id in _players.keys():
		for modo in (_players[set_id] as Dictionary).keys():
			(_player_de(set_id, modo) as AudioStreamPlayer).volume_db = -80.0
	if _set_actual == "" or not _players.has(_set_actual):
		return
	var modo_actual := "pelea" if _en_combate and (_players[_set_actual] as Dictionary).has("pelea") else "normal"
	if musica_activada:
		(_player_de(_set_actual, modo_actual) as AudioStreamPlayer).volume_db = volumen_base_db

## Duplica el stream importado y fuerza bucle completo.
func _preparar_loop(original: AudioStream) -> AudioStream:
	if original is AudioStreamWAV:
		var copia := (original as AudioStreamWAV).duplicate() as AudioStreamWAV
		if copia.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			copia.loop_mode = AudioStreamWAV.LOOP_FORWARD
			copia.loop_begin = 0
			# frames totales = duración(s) * mix_rate(Hz).
			var total_frames := int(copia.get_length() * float(copia.mix_rate))
			if total_frames > 0:
				copia.loop_end = total_frames
		return copia
	return original

# --- Ciclo de vida por contexto (la piden menús, player, triggers) ---

## Loop de menús (splash/título/selector). Idempotente.
func iniciar_musica_menu() -> void:
	_musica_iniciada = false
	if _set_actual == "B":
		_aplicar_volumen_actual()
		return
	_reproducir_set("B")

## Arranca el loop al entrar a un nivel según misión y fase. Idempotente:
## en reloads no reinicia la pista (solo garantiza volumen y despausa).
## Misión 2 pre-emboscada arranca en silencio hasta notificar_emboscada.
func iniciar_musica_nivel() -> void:
	_musica_iniciada = true
	for set_id in _players.keys():
		for modo in (_players[set_id] as Dictionary).keys():
			(_player_de(set_id, modo) as AudioStreamPlayer).stream_paused = false
	var set_id := _set_para_mision(Global.mision_actual)
	if set_id == "":
		_set_actual = ""
		_en_combate = false
		_tiempo_sin_alerta = 999.0
		_aplicar_volumen_actual()
		return
	if set_id == _set_actual:
		_aplicar_volumen_actual()
		return
	_reproducir_set(set_id)

func _set_para_mision(mision: String) -> String:
	if mision == Global.ESCENA_MISION_1:
		return "Aalt" if Global.segunda_mitad_m1 else "A"
	for m in Global.MISIONES:
		if m["escena"] == mision:
			# Misión 2: silencio hasta la primera emboscada.
			if mision == Global.MISIONES[1]["escena"]:
				return "C" if Global.emboscada_nivel2 else ""
			return "A"
	return "A"

## El trigger Burla (Misión 1) avanza a la segunda mitad, con o sin tutorial.
func notificar_segunda_mitad() -> void:
	Global.segunda_mitad_m1 = true
	if Global.mision_actual == Global.ESCENA_MISION_1 and _musica_iniciada and _set_actual == "A":
		_reproducir_set("Aalt")

## Una emboscada arrancó: si es Misión 2, entra el set C.
func notificar_emboscada() -> void:
	if Global.mision_actual != Global.MISIONES[1]["escena"]:
		return
	Global.emboscada_nivel2 = true
	if _musica_iniciada and _set_actual != "C":
		_reproducir_set("C")

## Al volver a un menú suena B (ya no hay silencio en menús).
func detener_musica() -> void:
	_musica_iniciada = false
	for set_id in _players.keys():
		for modo in (_players[set_id] as Dictionary).keys():
			(_player_de(set_id, modo) as AudioStreamPlayer).stream_paused = false
	_reproducir_set("B")

## Pausa o reanuda la música junto con el menú de pausa del nivel.
func set_nivel_pausado(pausado: bool) -> void:
	for set_id in _players.keys():
		for modo in (_players[set_id] as Dictionary).keys():
			(_player_de(set_id, modo) as AudioStreamPlayer).stream_paused = pausado

# --- API pública por si algún trigger quiere forzar el estado ---

func forzar_pelea() -> void:
	if not _musica_iniciada or _set_actual == "" or not (_players[_set_actual] as Dictionary).has("pelea"):
		return
	_tiempo_sin_alerta = 0.0
	if not _en_combate:
		_en_combate = true
		_hacer_crossfade(_player_de(_set_actual, "pelea"), _player_de(_set_actual, "normal"))

func forzar_normal() -> void:
	if _set_actual == "" or not _players.has(_set_actual):
		return
	_en_combate = false
	_tiempo_sin_alerta = 999.0
	if (_players[_set_actual] as Dictionary).has("pelea"):
		_hacer_crossfade(_player_de(_set_actual, "normal"), _player_de(_set_actual, "pelea"))
	else:
		_aplicar_volumen_actual()

func esta_en_combate() -> bool:
	return _en_combate

## Silencia o restaura la música (los SFX no se tocan).
func set_musica_activada(activa: bool) -> void:
	musica_activada = activa
	_aplicar_volumen_actual()

## Alterna y devuelve el nuevo estado (true = sonando).
func alternar_musica() -> bool:
	set_musica_activada(not musica_activada)
	return musica_activada
