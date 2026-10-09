extends CanvasLayer

# --- DICCIONARIO DE TEXTURAS DE ARMAS ---
const TEXTURAS_ARMAS = {
	"Rifle": preload("res://Assets/Armas/Rifle_Balistico.png"),
	"Pistola": preload("res://Assets/Armas/Pistola_Balistica.png"),
	"PistolaPlasma": preload("res://Assets/Armas/Pistola_Plasma.png"),
	"RiflePlasma": preload("res://Assets/Armas/Rifle Plasma.png")
}

# --- NUEVO: TRADUCTOR VISUAL DE NOMBRES ---
const NOMBRES_VISUALES = {
	"RiflePlasma": "Cañón Cítrico",
	"PistolaPlasma": "Pistola Cítrica",
	"Rifle": "Rifle V.I.D.",
	"Pistola": "Pistola Leguminosa",
	"Granada": "Granada Cargada",
	"Fragmentación": "Cargada", # Para el mensaje de alternar granada
	"Plasma": "Espinosa"        # Para el mensaje de alternar granada
}

# --- ANIMACIÓN DE RECARGA (barrido derecha -> izquierda sobre el icono) ---
const SHADER_RECARGA = preload("res://Shaders/recarga_hud.gdshader")
var _mat_recarga: ShaderMaterial
var _tween_recarga: Tween
var _ultima_arma_mostrada: String = ""
var _sin_municion: bool = false
var _calor_arma: float = 0.0

@onready var label_municion = $ContenedorArma/LabelMunicion
@onready var icono_arma = $ContenedorArma/IconoArma

# --- REFERENCIAS DE GRANADAS ---
@onready var icono_frag = $ContenedorGranada/HBoxContainer/IconoFrag
@onready var label_frag = $ContenedorGranada/HBoxContainer/LabelFrag
@onready var icono_plasma = $ContenedorGranada/HBoxContainer/IconoPlasma
@onready var label_plasma = $ContenedorGranada/HBoxContainer/LabelPlasma

@onready var barra_escudo: ProgressBar = $MarcoHUD/BarraEscudo
@onready var barra_salud: ProgressBar = $MarcoHUD/BarraSalud
@onready var label_notificacion = $MensajeNotificacion

var barra_escudo_morada: ProgressBar
var barra_escudo_roja: ProgressBar
var _tween_notificacion: Tween

var _overlay_negro: ColorRect

@onready var marco_hud = $MarcoHUD # Referencia al marco visual
var _tween_alerta_escudo: Tween
var _escudo_vacio: bool = false

@onready var menu_pausa = $MenuPausa
@onready var contenedor_botones = $MenuPausa/VBoxContainer
@onready var panel_controles = $MenuPausa/PanelControles
@onready var btn_musica: TextureButton = $MenuPausa/BtnMusica

# --- REFERENCIAS DE AUDIO DE ESCUDO ---
@onready var audio_peligro: AudioStreamPlayer = $AudioPeligro
@onready var audio_critico: AudioStreamPlayer = $AudioCritico
@onready var audio_recarga: AudioStreamPlayer = $AudioRecarga

# --- CONTROL DE ESTADOS DEL ESCUDO ---
var _escudo_critico: bool = false
var _ultimo_valor_escudo: float = 150.0

func _enter_tree():
	_crear_overlay_negro()

var _alerta_municion_mostrada: bool = false

func _ready():
	add_to_group("hud") # Registrar el nodo en el grupo
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_capas_sobreescudo()
	_material_recarga_init()
	hacer_fade_in(1.0)
	menu_pausa.hide()
	# El botón refleja el estado real del MusicManager (persiste entre escenas).
	btn_musica.set_pressed_no_signal(not MusicManager.musica_activada)
	
	# NUEVO: Conectar señales para bucle automático
	if audio_peligro:
		audio_peligro.finished.connect(_on_audio_peligro_finished)
	if audio_critico:
		audio_critico.finished.connect(_on_audio_critico_finished)
	
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Si estamos en pausa y el jugador está viendo los controles, Esc lo devuelve a los botones
		if get_tree().paused and panel_controles.visible:
			_on_btn_cerrar_controles_pressed()
		else:
			# En cualquier otro caso, alterna la pausa normalmente
			alternar_pausa()

func _crear_overlay_negro():
	if _overlay_negro != null:
		return
		
	_overlay_negro = ColorRect.new()
	_overlay_negro.color = Color.BLACK
	_overlay_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_negro.modulate.a = 1.0  # Nace totalmente negro
	_overlay_negro.z_index = 4096    # Fuerza estar por encima de todo el HUD
	add_child(_overlay_negro)

func hacer_fade_out(duracion: float = 1.0) -> Tween:
	if _overlay_negro == null:
		_crear_overlay_negro()
	var tween = create_tween()
	tween.tween_property(_overlay_negro, "modulate:a", 1.0, duracion)
	return tween

func hacer_fade_in(duracion: float = 1.0) -> Tween:
	if _overlay_negro == null:
		_crear_overlay_negro()
	_overlay_negro.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(_overlay_negro, "modulate:a", 0.0, duracion)
	return tween

func _crear_capas_sobreescudo():
	# Instanciar capas superpuestas directamente en _ready()
	barra_escudo_morada = _instanciar_capa_escudo(Color(0.65, 0.15, 0.9))
	barra_escudo_roja = _instanciar_capa_escudo(Color(0.9, 0.15, 0.2))

func _instanciar_capa_escudo(color_capa: Color) -> ProgressBar:
	var nueva_barra = barra_escudo.duplicate() as ProgressBar
	barra_escudo.get_parent().add_child(nueva_barra)
	
	# Fondo transparente para dejar ver la capa inferior
	var estilo_bg = StyleBoxFlat.new()
	estilo_bg.bg_color = Color(0, 0, 0, 0)
	nueva_barra.add_theme_stylebox_override("background", estilo_bg)
	
	# Relleno del color correspondiente
	var estilo_fill = StyleBoxFlat.new()
	estilo_fill.bg_color = color_capa
	nueva_barra.add_theme_stylebox_override("fill", estilo_fill)
	
	return nueva_barra

# --- FUNCIÓN AUXILIAR PARA DETENER ALARMAS ---
func _detener_alarmas_audio():
	if audio_peligro and audio_peligro.playing:
		audio_peligro.stop()
	if audio_critico and audio_critico.playing:
		audio_critico.stop()

func actualizar_escudos_hud(valor_actual: float, valor_maximo: float):
	# Capa 1: Base (0 a 150)
	barra_escudo.max_value = valor_maximo
	barra_escudo.value = clamp(valor_actual, 0.0, valor_maximo)
	
	# Capa 2: Morada (150 a 300)
	if barra_escudo_morada != null:
		barra_escudo_morada.max_value = valor_maximo
		barra_escudo_morada.value = clamp(valor_actual - valor_maximo, 0.0, valor_maximo)
		
	# Capa 3: Roja (300 a 450)
	if barra_escudo_roja != null:
		barra_escudo_roja.max_value = valor_maximo
		barra_escudo_roja.value = clamp(valor_actual - (valor_maximo * 2.0), 0.0, valor_maximo)

	var porcentaje = valor_actual / valor_maximo
	var subiendo = valor_actual > _ultimo_valor_escudo

	# 1. Escudo Expuesto / Peligro (0%)
	if valor_actual <= 0:
		if not _escudo_vacio:
			_escudo_vacio = true
			_escudo_critico = true
			_iniciar_alerta_escudo()
		
		# Apagamos crítico y mantenemos la alarma de peligro sonando en bucle
		if audio_critico and audio_critico.playing:
			audio_critico.stop()
		if audio_peligro and not audio_peligro.playing:
			audio_peligro.play()

	# 2. Escudo Crítico (20% o menos y > 0%)
	elif porcentaje <= 0.20 and valor_actual > 0:
		if subiendo:
			# Si empezó a recargarse (incluso en rango crítico), cortamos las alarmas de inmediato
			_detener_alarmas_audio()
			if _escudo_vacio:
				_escudo_vacio = false
				_detener_alerta_escudo()
			if audio_recarga and not audio_recarga.playing:
				audio_recarga.play()
		else:
			# Si está recibiendo daño o manteniéndose en nivel crítico
			_escudo_critico = true
			if audio_peligro and audio_peligro.playing:
				audio_peligro.stop()
			if audio_critico and not audio_critico.playing:
				audio_critico.play()

	# 3. Escudo Recargando / Normal (> 20%)
	else:
		if subiendo and (_escudo_vacio or _escudo_critico):
			if audio_recarga and not audio_recarga.playing:
				audio_recarga.play()
		
		_detener_alarmas_audio()
		_escudo_vacio = false
		_escudo_critico = false
		_detener_alerta_escudo()

	_ultimo_valor_escudo = valor_actual
	
	
func actualizar_salud_hud(valor_actual: float, valor_maximo: float):
	barra_salud.max_value = valor_maximo
	barra_salud.value = valor_actual

func actualizar_municion(cargador: int, reserva: int, nombre_arma: String = ""):
	if nombre_arma in TEXTURAS_ARMAS:
		# Al cambiar de arma se corta el barrido anterior y el icono vuelve a la normalidad
		if nombre_arma != _ultima_arma_mostrada:
			_ultima_arma_mostrada = nombre_arma
			_calor_arma = 0.0
			_cancelar_animacion_recarga()
		icono_arma.texture = TEXTURAS_ARMAS[nombre_arma]
	
	var municion_baja: bool = false
	var sin_municion: bool = false

	# Evaluar si la batería (reserva negativa) o las balas están por debajo del umbral
	if reserva < 0:
		label_municion.text = str(cargador) + "%"
		if cargador <= 15:
			municion_baja = true
		if cargador <= 0:
			sin_municion = true
	else:
		label_municion.text = str(cargador) + " / " + str(reserva)
		if (cargador + reserva) <= 15:
			municion_baja = true
		if cargador <= 0 and reserva <= 0:
			sin_municion = true

	# Icono apagado si el arma no puede disparar
	_sin_municion = sin_municion
	_refrescar_tinte_icono()

	# Lanzar la notificación solo la primera vez que se entra en estado crítico
	if municion_baja:
		if not _alerta_municion_mostrada:
			mostrar_notificacion("Munición/Batería baja, mantén E para intercambiar armas")
			_alerta_municion_mostrada = true
	else:
		_alerta_municion_mostrada = false
		
# Oscurece el icono y revela el tono original de derecha a izquierda
# durante "duracion" segundos (lo llaman rifle/pistola al recargar).
func animar_recarga(duracion: float):
	if _mat_recarga == null:
		_material_recarga_init()
	if _tween_recarga and _tween_recarga.is_valid():
		_tween_recarga.kill()
	_mat_recarga.set_shader_parameter("progreso", 0.0)
	label_municion.text = "Recargando..."
	_tween_recarga = create_tween()
	_tween_recarga.tween_property(_mat_recarga, "shader_parameter/progreso", 1.0, maxf(duracion, 0.05))

func _cancelar_animacion_recarga():
	if _tween_recarga and _tween_recarga.is_valid():
		_tween_recarga.kill()
	if _mat_recarga:
		_mat_recarga.set_shader_parameter("progreso", 1.0)

func _material_recarga_init():
	if _mat_recarga == null:
		_mat_recarga = ShaderMaterial.new()
		_mat_recarga.shader = SHADER_RECARGA
	if icono_arma and icono_arma.material != _mat_recarga:
		icono_arma.material = _mat_recarga
		_mat_recarga.set_shader_parameter("progreso", 1.0)

# Lo llama el Cañón Ácido con su calor 0.0-1.0: el icono enrojece
# gradualmente con cada disparo y se enfría igual que el arma.
func set_calor_hud(fraccion: float):
	_calor_arma = clampf(fraccion, 0.0, 1.0)
	_refrescar_tinte_icono()

# Gris sin munición > rojizo por calor > blanco normal.
func _refrescar_tinte_icono():
	if _sin_municion:
		icono_arma.modulate = Color(0.35, 0.35, 0.35)
	elif _calor_arma > 0.0:
		icono_arma.modulate = Color.WHITE.lerp(Color(1.0, 0.45, 0.45), _calor_arma)
	else:
		icono_arma.modulate = Color.WHITE

func mostrar_notificacion(mensaje: String):
	var mensaje_traducido = mensaje
	
	# Filtramos el texto entrante y reemplazamos los nombres internos por los visuales
	for clave in NOMBRES_VISUALES.keys():
		mensaje_traducido = mensaje_traducido.replace(clave, NOMBRES_VISUALES[clave])
		
	# Asignamos el texto ya traducido
	label_notificacion.text = mensaje_traducido
	label_notificacion.modulate.a = 1.0
	
	if _tween_notificacion and _tween_notificacion.is_valid():
		_tween_notificacion.kill()
		
	_tween_notificacion = create_tween()
	_tween_notificacion.tween_interval(2.0)
	_tween_notificacion.tween_property(label_notificacion, "modulate:a", 0.0, 1.5)
	
func actualizar_granadas(frag_cant: int, plasma_cant: int, maximo: int, usando_plasma: bool):
	label_frag.text = "x" + str(frag_cant) + " / " + str(maximo)
	label_plasma.text = "x" + str(plasma_cant) + " / " + str(maximo)
	
	if usando_plasma:
		icono_plasma.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label_plasma.modulate = Color(1.0, 1.0, 1.0, 1.0)
		icono_frag.modulate = Color(1.0, 1.0, 1.0, 0.3)
		label_frag.modulate = Color(1.0, 1.0, 1.0, 0.3)
	else:
		icono_frag.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label_frag.modulate = Color(1.0, 1.0, 1.0, 1.0)
		icono_plasma.modulate = Color(1.0, 1.0, 1.0, 0.3)
		label_plasma.modulate = Color(1.0, 1.0, 1.0, 0.3)

func _iniciar_alerta_escudo():
	# Si ya hay un tween corriendo, lo eliminamos por seguridad
	if _tween_alerta_escudo and _tween_alerta_escudo.is_valid():
		_tween_alerta_escudo.kill()
		
	# Creamos un tween que se repita infinitamente
	_tween_alerta_escudo = create_tween().set_loops()
	
	# Interpola hacia color rojo pálido/intenso en 0.3 segundos
	_tween_alerta_escudo.tween_property(marco_hud, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.3)
	# Vuelve al color original (blanco/sin tinte) en 0.3 segundos
	_tween_alerta_escudo.tween_property(marco_hud, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

func _detener_alerta_escudo():
	if _tween_alerta_escudo and _tween_alerta_escudo.is_valid():
		_tween_alerta_escudo.kill()
		
	# Restauramos el color a la normalidad inmediatamente por si el 
	# parpadeo se interrumpió a la mitad de la animación roja
	if marco_hud:
		marco_hud.modulate = Color(1.0, 1.0, 1.0, 1.0)

func alternar_pausa():
	var nuevo_estado_pausa = not get_tree().paused
	get_tree().paused = nuevo_estado_pausa
	menu_pausa.visible = nuevo_estado_pausa
	
	# Nos aseguramos de resetear la vista cada vez que se abre la pausa
	if nuevo_estado_pausa:
		contenedor_botones.show()
		panel_controles.hide()

func _on_btn_reanudar_pressed():
	alternar_pausa()

func _on_btn_checkpoint_pressed():
	get_tree().paused = false # Siempre quitar la pausa antes de cambiar de escena
	await hacer_fade_out(0.8).finished
	# Volver al checkpoint descarta las bajas/items sin guardar.
	Global.descartar_progreso_no_guardado()
	get_tree().reload_current_scene()
	# Si tienes una lógica de checkpoint global, úsala aquí.

func _on_btn_controles_pressed():
	# Ocultamos los botones y mostramos el panel
	contenedor_botones.hide()
	panel_controles.show()

func _on_btn_menu_pressed():
	await hacer_fade_out(0.8).finished
	get_tree().paused = false
	# Salir al título sin pasar por un checkpoint no confirma nada.
	Global.descartar_progreso_no_guardado()
	get_tree().change_scene_to_file("res://Scenes/pantalla_titulo.tscn") # Ajusta a tu ruta real
	
# --- NUEVA FUNCIÓN para el botón de volver ---
func _on_btn_cerrar_controles_pressed():
	# Ocultamos el panel y volvemos a mostrar los botones
	panel_controles.hide()
	contenedor_botones.show()

# Icono de música del menú de pausa: solo silencia/restaura la música,
# los SFX siguen sonando igual.
func _on_btn_musica_toggled(boton_presionado: bool) -> void:
	MusicManager.set_musica_activada(not boton_presionado)

func _on_audio_peligro_finished():
	# Si el escudo sigue en 0, vuelve a reproducir la alarma de peligro
	if _escudo_vacio:
		audio_peligro.play()

func _on_audio_critico_finished():
	# Si el escudo sigue en nivel crítico (y no vacío), vuelve a reproducir la alarma
	if _escudo_critico and not _escudo_vacio:
		audio_critico.play()
