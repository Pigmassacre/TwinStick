shader_type spatial;
// What lies on the floor: rails, rubble, stains, and the dark at the foot of a wall.
render_mode cull_back, specular_disabled, shadows_disabled, depth_draw_never;
#include "res://src/shaders/lit.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform float bands = 7.0;

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * stepped(falloff(ATTENUATION) * pow(ndl, 0.55), FRAGCOORD.xy, bands);
}
