extends Node2D
## Foco dorado colocable para zonas de miel del Nivel 2: genera su halo
## radial por código (sin assets) y baña la cueva en luz cálida.
## Instanciar donde las paredes amarillentas/naranjas deban brillar.

@export var color_luz: Color = Color(1.0, 0.8, 0.45)
@export var energia: float = 1.1
# Radio aproximado del halo en pixeles.
@export var radio: float = 400.0

func _ready() -> void:
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradiente.colors = PackedColorArray([
		Color(1, 0.93, 0.65, 0.9),
		Color(1, 0.85, 0.5, 0.45),
		Color(1, 0.78, 0.4, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradiente
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var luz := PointLight2D.new()
	luz.name = "LuzMiel"
	luz.texture = tex
	luz.color = color_luz
	luz.energy = energia
	luz.texture_scale = maxf(radio / 128.0, 0.5)
	add_child(luz)
	# Halo visible también sin sistema de sombras: suma calidez al tileset.
	var halo := Sprite2D.new()
	halo.name = "HaloMiel"
	halo.texture = tex
	halo.modulate = Color(color_luz.r, color_luz.g, color_luz.b, 0.35)
	halo.scale = Vector2.ONE * maxf(radio / 128.0, 0.5)
	add_child(halo)
