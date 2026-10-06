shader_type canvas_item;
// Barrido de recarga: con progreso en 0 el icono se ve oscurecido, y el tono
// original se revela avanzando de derecha a izquierda hasta progreso en 1.
uniform float progreso : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color_oscuro : source_color = vec4(0.12, 0.1, 0.16, 1.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (UV.x < 1.0 - progreso) {
		t.rgb = mix(t.rgb, color_oscuro.rgb, 0.8);
	}
	COLOR = t;
}
