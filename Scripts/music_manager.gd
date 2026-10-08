extends Node
## Autoload: gestiona la música de nivel con crossfade.
## - Normal (por defecto, en bucle)
## - Pelea (cuando algún enemigo detecta al jugador)
##
## Uso: al ser Autoload suena de forma persistente entre main.tscn,
## arena_final, muertes (reload) y checkpoints sin reiniciarse.
## Los enemigos ya avisan con su variable `es_alerta`, aquí solo
## se sondea el grupo "enemigos" cada 0.2s.

const MUSICA_NORMAL: AudioStream = preload("res://Music/Placeholder-Normal.wav")
const MUSICA_PELEA: AudioStream = preload("res://Music/Placeholder-Pelea.wav")

## Segundos que se mantiene Pelea después de que el último enemigo
## deje de estar en alerta. Evita parpadeos si matas al último
## enemigo o si hay un hueco de 1 frame al recargar la escena.
@export var tiempo_gracia_salida: float = 4.0
## Duración del fundido entre pistas.
@export var duracion_crossfade: float = 1.5
## Volumen base de la música (los placeholder suelen venir altos).
@export var volumen_base_db: float = -12.0
## Cada cuántos segundos se revisa si hay combate.
@export var intervalo_chequeo: float = 0.2

var _player_normal: AudioStreamPlayer
var _player_pelea: AudioStreamPlayer
var _en_combate: bool = false
var _tiempo_sin_alerta: float = 999.0
var _tiempo_chequeo: float = 0.0
var _tween_fade: Tween = null

func _ready() -> void:
	# La música no se corta con la pausa ni con los cambios de escena.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player_normal = AudioStreamPlayer.new()
	_player_normal.name = "MusicaNormal"
	_player_normal.process_mode = Node.PROCESS_MODE_ALWAYS
	_player_normal.stream = _preparar_loop(MUSICA_NORMAL)
	_player_normal.volume_db = volumen_base_db
	add_child(_player_normal)

	_player_pelea = AudioStreamPlayer.new()
	_player_pelea.name = "MusicaPelea"
	_player_pelea.process_mode = Node.PROCESS_MODE_ALWAYS
	_player_pelea.stream = _preparar_loop(MUSICA_PELEA)
	# Empieza silenciada con el mismo bus que Normal.
	_player_pelea.volume_db = -80.0
	add_child(_player_pelea)

	_player_normal.play()
	_player_pelea.play()

func _process(delta: float) -> void:
	_tiempo_chequeo += delta
	if _tiempo_chequeo < intervalo_chequeo:
		return
	_tiempo_chequeo = 0.0

	if _hay_combate():
		_tiempo_sin_alerta = 0.0
		if not _en_combate:
			_en_combate = true
			_hacer_crossfade(_player_pelea, _player_normal)
	else:
		_tiempo_sin_alerta += intervalo_chequeo
		if _en_combate and _tiempo_sin_alerta >= tiempo_gracia_salida:
			_en_combate = false
			_hacer_crossfade(_player_normal, _player_pelea)

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
	_tween_fade.tween_property(subir, "volume_db", volumen_base_db, duracion_crossfade)
	_tween_fade.tween_property(bajar, "volume_db", -80.0, duracion_crossfade)

## Duplica el stream importado y fuerza bucle completo.
## Así no dependemos de que en la pestaña Import esté puesto
## loop_mode = Forward para los Placeholder-*.wav.
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

# --- API pública por si algún trigger quiere forzar el estado ---

func forzar_pelea() -> void:
	_tiempo_sin_alerta = 0.0
	if not _en_combate:
		_en_combate = true
		_hacer_crossfade(_player_pelea, _player_normal)

func forzar_normal() -> void:
	_en_combate = false
	_tiempo_sin_alerta = 999.0
	_hacer_crossfade(_player_normal, _player_pelea)

func esta_en_combate() -> bool:
	return _en_combate
