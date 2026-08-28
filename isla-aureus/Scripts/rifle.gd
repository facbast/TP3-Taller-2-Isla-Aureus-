extends Sprite2D

const BALA_ESCENA = preload("res://Scenes/bala.tscn")
@onready var _punto_disparo = $PuntoDisparo

# --- VARIABLES DEL ARMA ---
var cadencia_disparo = 0.1 
var temporizador_disparo = 0.0

var municion_cargador_max = 60 
var municion_cargador = 60
var municion_reserva = 600
var esta_recargando = false  
var tiempo_recarga = 1.5      

# --- NUEVAS VARIABLES TÁCTICAS ---
var dano_por_bala = 4.0 # Daño reducido (antes era 10). Se requieren más balas para matar.
var dispersion_maxima = 4.5 # Grados de desviación máxima de la bala

func _process(delta):
	temporizador_disparo += delta

func intentar_disparar() -> bool:
	if esta_recargando:
		return false
		
	if municion_cargador > 0:
		if temporizador_disparo >= cadencia_disparo:
			temporizador_disparo = 0.0 
			municion_cargador -= 1
			_efectuar_disparo()
			_actualizar_hud()
			return true 
	else:
		recargar()
		
	return false

func _efectuar_disparo():
	var nueva_bala = BALA_ESCENA.instantiate()
	owner.get_parent().add_child(nueva_bala) 
	
	nueva_bala.global_position = _punto_disparo.global_position
	
	# --- SISTEMA DE DISPERSIÓN ---
	# 1. Convertimos los grados a radianes (Godot usa radianes para rotar matemáticamente)
	var dispersion_radianes = deg_to_rad(dispersion_maxima)
	
	# 2. Obtenemos un ángulo aleatorio entre negativo (arriba) y positivo (abajo)
	var variacion_aleatoria = randf_range(-dispersion_radianes, dispersion_radianes)
	
	# 3. Sumamos ese error aleatorio a la rotación perfecta del arma
	nueva_bala.global_rotation = global_rotation + variacion_aleatoria
	
	# --- SISTEMA DE DAÑO DINÁMICO ---
	# Le decimos a la bala que su daño ya no es el de por defecto, sino el de este rifle
	nueva_bala.dano = dano_por_bala

func recargar():
	if esta_recargando or municion_cargador == municion_cargador_max or municion_reserva <= 0:
		return
		
	esta_recargando = true
	
	await get_tree().create_timer(tiempo_recarga).timeout 
	
	var balas_faltantes = municion_cargador_max - municion_cargador
	if municion_reserva >= balas_faltantes:
		municion_cargador += balas_faltantes
		municion_reserva -= balas_faltantes
	else:
		municion_cargador += municion_reserva
		municion_reserva = 0
		
	esta_recargando = false
	_actualizar_hud()

func _actualizar_hud():
	var hud = owner.get_parent().get_node_or_null("HUD")
	if hud == null:
		hud = get_tree().current_scene.get_node_or_null("HUD")
		
	if hud != null:
		hud.actualizar_municion(municion_cargador, municion_reserva, "Rifle")
