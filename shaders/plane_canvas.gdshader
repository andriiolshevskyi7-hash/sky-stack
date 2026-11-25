// Plane previews in the 2D screens (hangar, skins): the texture is the plane
// index atlas (PlaneArt); modulate.r = skin / 255, modulate.g = slice shade.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D palette_tex : filter_nearest;

varying flat float skin;
varying float slice_shade;

#include "res://shaders/plane_palette.gdshaderinc"

void vertex() {
	skin = COLOR.r * 255.0;
	slice_shade = COLOR.g;
}

void fragment() {
	vec4 a = texture(TEXTURE, UV);
	if (a.a < 0.5) discard;
	vec4 e;
	vec3 c = plane_color(a, int(round(skin)), palette_tex, e);
	c = c * slice_shade + e.rgb * (e.a > 0.6 && e.a < 0.7 ? 0.5 : 0.0);
	COLOR = vec4(c, 1.0);
}
