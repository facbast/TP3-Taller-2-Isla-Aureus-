extends Node
## Autoload: gestiona la música de nivel con crossfade.
## - Normal (por defecto, en bucle)
## - Pelea (cuando algún enemigo detecta al jugador)
##
## La música NO suena en menús (splash, título, selector): arranca con
## iniciar_musica_nivel(), se pausa con set_nivel_pausado() y se corta
## con detener_musica() al volver a un menú. Entre muertes y checkpoints
## (reload) sigue sonando sin reiniciarse.

const MUSICA_NORMAL: AudioStream = preload("res://Music/Placeholder-Normal.wav")
const MUSICA_PELEA: AudioStream = preload("res://Music/Placeholder Jungla.wav")

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
## Música activada o silenciada (los SFX van por otros players y no se tocan).
var musica_activada: bool = true
## True mientras hay un nivel abierto (entre iniciar y detener).
## En menús es false y no suena nada.
var _musica_iniciada: bool = false

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

	# Sin autoplay: la música arranca al entrar a un nivel
	# (ver iniciar_musica_nivel). En splash/título/selector hay silencio.

func _process(delta: float) -> void:
	# Sin nivel abierto o con el juego pausado no se sondea combate:
	# evita crossfades y cambios Normal/Pelea mientras no se escucha.
	if not _musica_iniciada or get_tree().paused:
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
	var destino_subir := volumen_base_db if musica_activada else -80.0
	_tween_fade.tween_property(subir, "volume_db", destino_subir, duracion_crossfade)
	_tween_fade.tween_property(bajar, "volume_db", -80.0, duracion_crossfade)

# Aplica el mute al instante sobre la pista que suena ahora.
func _aplicar_volumen_actual() -> void:
	if _tween_fade and _tween_fade.is_running():
		_tween_fade.kill()
	if not musica_activada:
		_player_normal.volume_db = -80.0
		_player_pelea.volume_db = -80.0
	elif _en_combate:
		_player_pelea.volume_db = volumen_base_db
		_player_normal.volume_db = -80.0
	else:
		_player_normal.volume_db = volumen_base_db
		_player_pelea.volume_db = -80.0

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

## Silencia o restaura la música (los SFX no se tocan).
func set_musica_activada(activa: bool) -> void:
	musica_activada = activa
	_aplicar_volumen_actual()

## Alterna y devuelve el nuevo estado (true = sonando).
func alternar_musica() -> bool:
	set_musica_activada(not musica_activada)
	return musica_activada

# --- Ciclo de vida por nivel (la piden player/hud/triggers) ---

## Arranca el loop al entrar a un nivel. Idempotente: en reloads por
## muerte o checkpoint, si ya suena solo garantiza que no quede pausada
## y respeta el estado Normal/Pelea en curso (no reinicia la pista).
func iniciar_musica_nivel() -> void:
	_musica_iniciada = true
	_player_normal.stream_paused = false
	_player_pelea.stream_paused = false
	if not _player_normal.playing:
		_player_normal.play()
	if not _player_pelea.playing:
		_player_pelea.play()
	_aplicar_volumen_actual()

## Corta la música al volver a un menú (título/selector).
func detener_musica() -> void:
	_musica_iniciada = false
	_en_combate = false
	_tiempo_sin_alerta = 999.0
	if _tween_fade and _tween_fade.is_running():
		_tween_fade.kill()
	_player_normal.stop()
	_player_pelea.stop()

## Pausa o reanuda la música junto con el menú de pausa del nivel.
func set_nivel_pausado(pausado: bool) -> void:
	if not _musica_iniciada:
		return
	_player_normal.stream_paused = pausado
	_player_pelea.stream_paused = pausado
